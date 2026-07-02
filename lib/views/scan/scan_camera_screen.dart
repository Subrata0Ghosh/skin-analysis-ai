import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants/colors.dart';
import 'scanning_loading_screen.dart';

// -----------------------------------------------------------------------------
// Face state enum - drives all UI messaging & feedback
// -----------------------------------------------------------------------------
enum _FaceState {
  noFace,     // No face detected at all
  tooFar,     // Face found but too small / too far
  tooClose,   // Face too large / too close
  outOfOval,  // Face is not centered inside the oval guide
  turnLeft,   // Head yawed right -> tell user to turn left
  turnRight,  // Head yawed left  -> tell user to turn right
  lookUp,     // Chin down -> tell user to look up
  lookDown,   // Forehead down -> tell user to look down
  tiltHead,   // Z-roll too extreme -> tell user to straighten head
  good,       // Perfect - ready to capture
}

// -----------------------------------------------------------------------------
// Scan step enum - Front, Left, and Right face captures
// -----------------------------------------------------------------------------
enum _ScanStep {
  front,
  leftSide,
  rightSide,
}

// -----------------------------------------------------------------------------
// ScanCameraScreen - Real ML Kit face detection, animated oval guide,
// vibration on bad alignment, auto-capture when face is correct.
// -----------------------------------------------------------------------------
class ScanCameraScreen extends StatefulWidget {
  final VoidCallback onScanCompleted;
  const ScanCameraScreen({super.key, required this.onScanCompleted});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen>
    with TickerProviderStateMixin {
  // -- Camera -----------------------------------------------------------------
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraError = false;
  String _cameraErrorMsg = '';
  bool _isFrontCamera = true;

  // -- ML Kit face detector --------------------------------------------------
  late final FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  int _frameCounter = 0;

  // -- Multi-Step Capture State -----------------------------------------------
  _ScanStep _currentStep = _ScanStep.front;
  String? _frontImagePath;
  String? _leftImagePath;
  String? _rightImagePath;

  // -- Face state -------------------------------------------------------------
  _FaceState _faceState = _FaceState.noFace;
  bool _isCapturing = false;
  int _goodFrames = 0;
  static const int _requiredGoodFrames = 18; // ~0.6 s at 30 fps / every 3rd frame
  double _captureProgress = 0.0;
  int _vibrationCooldown = 0;

  // -- Face Tracking Mesh Offset (Real-time dynamic locking) ------------------
  double _meshOffsetX = 0.0;
  double _meshOffsetY = 0.0;
  double _meshScale = 1.0;
  double _meshYaw = 0.0;
  double _meshPitch = 0.0;
  double _meshRoll = 0.0;

  // -- Animations -------------------------------------------------------------
  late AnimationController _pulseCtrl;
  late AnimationController _laserCtrl;
  late AnimationController _borderCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _laserAnim;
  late Animation<double> _borderGlowAnim;

  // -----------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.12,         // at least 12% of image width
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initAnimations();
    _initCamera();
  }

  // -----------------------------------------------------------------------------
  void _initAnimations() {
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _laserCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _borderCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _laserAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _laserCtrl, curve: Curves.easeInOut));
    _borderGlowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _borderCtrl, curve: Curves.easeInOut));
  }

  // -----------------------------------------------------------------------------
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setCameraError('No cameras found on this device.');
        return;
      }
      final targetLens = _isFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final targetCamera = cameras.firstWhere(
        (c) => c.lensDirection == targetLens,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium, // Medium = good perf for ML processing
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = false;
      });
      await _cameraController!.startImageStream(_processFrame);
    } catch (e) {
      _setCameraError('Camera error: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraController == null || !_cameraReady || _isCapturing) return;

    setState(() {
      _cameraReady = false;
    });

    try {
      // 1. Stop and dispose current camera controller
      await _cameraController!.stopImageStream().catchError((_) {});
      await _cameraController!.dispose();
      _cameraController = null;

      // 2. Toggle lens direction
      _isFrontCamera = !_isFrontCamera;

      // 3. Re-initialize
      await _initCamera();
    } catch (e) {
      _setCameraError('Error switching camera: $e');
    }
  }

  void _setCameraError(String msg) {
    if (mounted) setState(() { _cameraError = true; _cameraErrorMsg = msg; });
  }

  // -----------------------------------------------------------------------------
  // Process every 3rd frame with ML Kit - real face detection
  // -----------------------------------------------------------------------------
  Future<void> _processFrame(CameraImage cameraImage) async {
    _frameCounter++;
    if (_frameCounter % 3 != 0) return; // process every 3rd frame
    if (_isProcessingFrame || _isCapturing) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _toInputImage(cameraImage);
      if (inputImage == null) { _isProcessingFrame = false; return; }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) { _isProcessingFrame = false; return; }

      _evaluateFaces(faces, cameraImage.width, cameraImage.height);
    } catch (e) {
      // Silently ignore frame errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  // Map of device orientations to raw angle degrees
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // -----------------------------------------------------------------------------
  // Convert CameraImage -> ML Kit InputImage
  // -----------------------------------------------------------------------------
  InputImage? _toInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    // Determine correct rotation compensating for sensor and device orientation
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation != null) {
        if (camera.lensDirection == CameraLensDirection.front) {
          // Front-facing camera: mirror and add
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          // Back-facing camera
          rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
    }
    final imageRotation = rotation ?? InputImageRotation.rotation0deg;

    // Concatenate all planes into a single byte array for standard NV21/YUV420_888 formats
    final builder = BytesBuilder();
    for (final plane in image.planes) {
      builder.add(plane.bytes);
    }
    final bytes = builder.takeBytes();

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? 
        (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // Evaluate detected faces and update state based on current step
  // -----------------------------------------------------------------------------
  void _evaluateFaces(List<Face> faces, int rawW, int rawH) {
    _FaceState newState;

    // Compensate for sensor rotation swap (Android front sensor is rotated 90/270)
    final int imgW = rawH; // e.g. 480
    final int imgH = rawW; // e.g. 720

    if (faces.isEmpty) {
      newState = _FaceState.noFace;
    } else {
      // Take the largest face (most likely the user's face)
      final face = faces.reduce(
        (a, b) => (a.boundingBox.width * a.boundingBox.height) >
                (b.boundingBox.width * b.boundingBox.height)
            ? a
            : b,
      );

      final bbox = face.boundingBox;
      final faceRatio = bbox.width / imgW;

      // -- Size check --------------------------------------------------------
      if (faceRatio < 0.30) {
        newState = _FaceState.tooFar;
      } else if (faceRatio > 0.85) {
        newState = _FaceState.tooClose;
      } else {
        // -- Centering check --------------------------------------------------
        final double faceCenterX = (bbox.left + bbox.width / 2) / imgW;
        final double faceCenterY = (bbox.top + bbox.height / 2) / imgH;

        if ((faceCenterX - 0.5).abs() > 0.12 || (faceCenterY - 0.5).abs() > 0.12) {
          newState = _FaceState.outOfOval;
        } else {
          // -- Angle checks based on current scan step --------------------------
          final yaw = face.headEulerAngleY ?? 0.0;   // left(-) / right(+)
          final pitch = face.headEulerAngleX ?? 0.0; // down(-) / up(+)
          final roll = face.headEulerAngleZ ?? 0.0;  // tilt

          if (_currentStep == _ScanStep.front) {
            // Front expects face centered straight
            if (yaw.abs() > 14) {
              newState = yaw > 0 ? _FaceState.turnRight : _FaceState.turnLeft;
            } else if (pitch.abs() > 18) {
              newState = pitch < 0 ? _FaceState.lookUp : _FaceState.lookDown;
            } else if (roll.abs() > 18) {
              newState = _FaceState.tiltHead;
            } else {
              newState = _FaceState.good;
            }
          } else if (_currentStep == _ScanStep.leftSide) {
            // Left side profile expects user to turn head to the physical right (which is screen left)
            if (yaw < 15) {
              newState = _FaceState.turnLeft;  // Tell user to turn to the left of the screen <-
            } else if (yaw > 45) {
              newState = _FaceState.turnRight; // Too far right, turn back right of the screen
            } else if (pitch.abs() > 22) {
              newState = pitch < 0 ? _FaceState.lookUp : _FaceState.lookDown;
            } else if (roll.abs() > 22) {
              newState = _FaceState.tiltHead;
            } else {
              newState = _FaceState.good;
            }
          } else {
            // Right side profile expects user to turn head to the physical left (which is screen right)
            if (yaw > -15) {
              newState = _FaceState.turnRight; // Tell user to turn to the right of the screen ->
            } else if (yaw < -45) {
              newState = _FaceState.turnLeft;  // Too far left, turn back left of the screen
            } else if (pitch.abs() > 22) {
              newState = pitch < 0 ? _FaceState.lookUp : _FaceState.lookDown;
            } else if (roll.abs() > 22) {
              newState = _FaceState.tiltHead;
            } else {
              newState = _FaceState.good;
            }
          }
        }
      }
    }

    double targetX = 0.0;
    double targetY = 0.0;
    double targetScale = 1.0;
    double targetYaw = 0.0;
    double targetPitch = 0.0;
    double targetRoll = 0.0;

    if (faces.isNotEmpty) {
      final face = faces.first;
      final yaw = face.headEulerAngleY ?? 0.0;
      final pitch = face.headEulerAngleX ?? 0.0;
      final roll = face.headEulerAngleZ ?? 0.0;
      final bbox = face.boundingBox;
      final faceRatio = bbox.width / imgW;

      targetX = -yaw * 1.8;
      targetY = -pitch * 1.8;
      targetScale = (faceRatio / 0.45).clamp(0.6, 1.4);
      targetYaw = yaw;
      targetPitch = pitch;
      targetRoll = roll;
    }

    setState(() {
      _faceState = newState;
      _meshOffsetX = _meshOffsetX * 0.72 + targetX * 0.28;
      _meshOffsetY = _meshOffsetY * 0.72 + targetY * 0.28;
      _meshScale = _meshScale * 0.72 + targetScale * 0.28;
      _meshYaw = _meshYaw * 0.72 + targetYaw * 0.28;
      _meshPitch = _meshPitch * 0.72 + targetPitch * 0.28;
      _meshRoll = _meshRoll * 0.72 + targetRoll * 0.28;

      if (newState == _FaceState.good) {
        _goodFrames++;
        _captureProgress = (_goodFrames / _requiredGoodFrames).clamp(0.0, 1.0);
        _vibrationCooldown = 0;
      } else {
        _goodFrames = 0;
        _captureProgress = 0.0;
        // Vibration triggers only on actual face misalignments (not on "noFace")
        if (newState != _FaceState.noFace) {
          _doVibrate();
        } else {
          _vibrationCooldown = 0; // reset cooldown so next misalignment registers instantly
        }
      }
    });

    if (_goodFrames >= _requiredGoodFrames && !_isCapturing) {
      _captureAndProcess();
    }
  }

  // -----------------------------------------------------------------------------
  // Status message & color based on face state & current capture step
  // -----------------------------------------------------------------------------
  ({String text, Color color, IconData icon}) get _statusInfo {
    switch (_faceState) {
      case _FaceState.noFace:
        return (
          text: _currentStep == _ScanStep.front
              ? 'Position your face in the oval'
              : _currentStep == _ScanStep.leftSide
                  ? 'Turn face to the right (Left Profile)'
                  : 'Turn face to the left (Right Profile)',
          color: Colors.white60,
          icon: Icons.face_outlined,
        );
      case _FaceState.tooFar:
        return (
          text: 'Move closer to the camera',
          color: AppColors.primaryGold,
          icon: Icons.zoom_in_rounded,
        );
      case _FaceState.tooClose:
        return (
          text: 'Move further from the camera',
          color: AppColors.primaryGold,
          icon: Icons.zoom_out_rounded,
        );
      case _FaceState.outOfOval:
        return (
          text: 'Center your face inside the oval guide',
          color: AppColors.accentRose,
          icon: Icons.filter_center_focus_rounded,
        );
      case _FaceState.turnLeft:
        final showLeft = _isFrontCamera;
        return (
          text: showLeft
              ? (_currentStep == _ScanStep.rightSide
                  ? 'Turn face further to the left'
                  : 'Turn your face back to the left')
              : (_currentStep == _ScanStep.leftSide
                  ? 'Turn face further to the right'
                  : 'Turn your face back to the right'),
          color: AppColors.accentRose,
          icon: showLeft ? Icons.rotate_left_rounded : Icons.rotate_right_rounded,
        );
      case _FaceState.turnRight:
        final showRight = _isFrontCamera;
        return (
          text: showRight
              ? (_currentStep == _ScanStep.leftSide
                  ? 'Turn face further to the right'
                  : 'Turn your face back to the right')
              : (_currentStep == _ScanStep.rightSide
                  ? 'Turn face further to the left'
                  : 'Turn your face back to the left'),
          color: AppColors.accentRose,
          icon: showRight ? Icons.rotate_right_rounded : Icons.rotate_left_rounded,
        );
      case _FaceState.lookUp:
        return (
          text: 'Look straight ahead - chin up',
          color: AppColors.accentRose,
          icon: Icons.arrow_upward_rounded,
        );
      case _FaceState.lookDown:
        return (
          text: 'Lower your chin slightly',
          color: AppColors.accentRose,
          icon: Icons.arrow_downward_rounded,
        );
      case _FaceState.tiltHead:
        return (
          text: 'Straighten your head',
          color: AppColors.accentRose,
          icon: Icons.straighten_rounded,
        );
      case _FaceState.good:
        final profileName = _currentStep == _ScanStep.front
            ? 'Front'
            : _currentStep == _ScanStep.leftSide
                ? 'Left Profile'
                : 'Right Profile';
        return (
          text: _goodFrames >= _requiredGoodFrames
              ? 'Capturing $profileName...'
              : 'Hold still - scanning $profileName!',
          color: AppColors.accentSage,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }

  bool get _isFaceGood => _faceState == _FaceState.good;

  // -----------------------------------------------------------------------------
  // Vibration - throttled, skips when face is good
  // -----------------------------------------------------------------------------
  void _doVibrate() {
    if (_vibrationCooldown > 0) { _vibrationCooldown--; return; }
    _vibrationCooldown = 30; // ~3 second cooldown (every 3rd frame processed)
    Vibration.vibrate(duration: 140, amplitude: 160);
  }

  // -----------------------------------------------------------------------------
  // Auto-capture from live camera for Front -> Left -> Right
  // -----------------------------------------------------------------------------
  Future<void> _captureAndProcess() async {
    if (_isCapturing || !_cameraReady || _cameraController == null) return;
    setState(() => _isCapturing = true);
    try {
      await _cameraController!.stopImageStream();
      final XFile photo = await _cameraController!.takePicture();
      await _cropToOval(photo.path);

      if (_currentStep == _ScanStep.front) {
        _frontImagePath = photo.path;
        setState(() {
          _currentStep = _ScanStep.leftSide;
          _isCapturing = false;
          _goodFrames = 0;
          _captureProgress = 0.0;
        });
        await _cameraController!.startImageStream(_processFrame);
      } else if (_currentStep == _ScanStep.leftSide) {
        _leftImagePath = photo.path;
        setState(() {
          _currentStep = _ScanStep.rightSide;
          _isCapturing = false;
          _goodFrames = 0;
          _captureProgress = 0.0;
        });
        await _cameraController!.startImageStream(_processFrame);
      } else {
        _rightImagePath = photo.path;
        // All 3 profiles captured! Navigate to loading analysis screen
        await _navigateToLoading(
          _frontImagePath!,
          leftPath: _leftImagePath!,
          rightPath: _rightImagePath!,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCapturing = false; _goodFrames = 0; });
        _cameraController?.startImageStream(_processFrame);
      }
    }
  }

  // -----------------------------------------------------------------------------
  Future<void> _pickFromGallery() async {
    if (_isCapturing) return;
    final picker = ImagePicker();
    // Track picked paths to prevent reuse
    final usedPaths = <String>{};

    // -- Helper: styled error dialog -----------------------------------
    Future<void> showErrorDialog(String title, String message, {Color borderColor = const Color(0xFFE57373)}) async {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor.withValues(alpha: 0.40), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: borderColor, size: 36),
                const SizedBox(height: 14),
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(message,
                    style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: borderColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -- Helper: step instruction dialog ------------------------------
    Future<bool> showStepDialog(int step, String title, String subtitle, IconData icon, {String? refImagePath}) async {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                      ),
                      child: Text('STEP $step OF 3',
                          style: TextStyle(color: AppColors.primaryGoldLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Icon(icon, color: AppColors.primaryGold, size: 30),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5),
                    textAlign: TextAlign.center),
                // Show reference thumbnail for steps 2 & 3
                if (refImagePath != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(refImagePath), width: 52, height: 52, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.primaryGold, size: 14),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Must be the SAME person as your front photo above.',
                                  style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Open Gallery',
                            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return result == true;
    }

    // -- Helper: preview confirmation dialog after picking -------------
    Future<bool> showPreviewDialog(String imagePath, int step, String stepLabel, {String? refImagePath}) async {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Confirm $stepLabel Photo',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                // Show reference (step 1) vs selected side by side for steps 2 & 3
                if (refImagePath != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Front Ref', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(refImagePath), height: 110, fit: BoxFit.cover),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            Text(stepLabel, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(imagePath), height: 110, fit: BoxFit.cover),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Confirm: Is this the SAME person as the front photo?',
                      style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  // Step 1: just show the selected image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(imagePath), height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  const Text('Is your face clearly visible and well-lit?',
                      style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Pick Different', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentSage,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Use This Photo',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return result == true;
    }

    // -- Helper: face validation loading + check -----------------------
    Future<bool> validateFace(String path, String stepLabel) async {
      // Show loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40, height: 40,
                  child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2.5),
                ),
                SizedBox(height: 16),
                Text('Verifying face...', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text('Please wait', style: TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
        ),
      );

      final inputImage = InputImage.fromFilePath(path);
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          enableTracking: false,
          minFaceSize: 0.05,
        ),
      );
      List<Face> faces = [];
      try {
        faces = await detector.processImage(inputImage);
      } catch (_) {
        faces = [];
      } finally {
        await detector.close();
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (faces.isEmpty) {
        if (mounted) {
          await showErrorDialog(
            'No Face Detected',
            'The selected "$stepLabel" photo doesn\'t contain a clear human face.\n\nPlease choose a well-lit, clearly visible face photo.',
            borderColor: AppColors.accentRose,
          );
        }
        return false;
      }
      return true;
    }

    // -- Pick + full validate one step --------------------------------
    Future<String?> pickStep(
      int step,
      String title,
      String subtitle,
      IconData icon,
      String stepLabel, {
      String? refImagePath,
    }) async {
      while (true) {
        // Show step instruction dialog
        final confirmed = await showStepDialog(step, title, subtitle, icon, refImagePath: refImagePath);
        if (!confirmed || !mounted) return null;

        // Open gallery
        XFile? photo;
        try {
          photo = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 90,
          );
        } catch (_) {
          return null;
        }
        if (photo == null || !mounted) return null;

        // (1) Duplicate check
        if (usedPaths.contains(photo.path)) {
          await showErrorDialog(
            'Duplicate Image',
            'You already used this photo for a previous step.\n\nPlease select a DIFFERENT photo for the $stepLabel view.',
            borderColor: AppColors.primaryGold,
          );
          continue; // loop back to pick again
        }

        // (2) Preview confirmation dialog
        final previewOk = await showPreviewDialog(photo.path, step, stepLabel, refImagePath: refImagePath);
        if (!mounted) return null;
        if (!previewOk) continue; // user tapped "Pick Different" - loop back

        // (3) Face validation
        final hasFace = await validateFace(photo.path, stepLabel);
        if (!mounted) return null;
        if (!hasFace) continue; // no face - loop back

        // All checks passed
        usedPaths.add(photo.path);
        return photo.path;
      }
    }

    // -- Step 1: Front ------------------------------------------------
    final frontPath = await pickStep(
      1,
      'Front Face Photo',
      'Select a clear, front-facing photo. Your whole face must be visible.',
      Icons.face_retouching_natural_rounded,
      'Front',
    );
    if (frontPath == null || !mounted) return;

    // -- Step 2: Left Profile -----------------------------------------
    final leftPath = await pickStep(
      2,
      'Left Profile Photo',
      'Turn face to the LEFT. Must be the SAME person as the front photo.',
      Icons.turn_left_rounded,
      'Left Profile',
      refImagePath: frontPath,
    );
    if (leftPath == null || !mounted) return;

    // -- Step 3: Right Profile ----------------------------------------
    final rightPath = await pickStep(
      3,
      'Right Profile Photo',
      'Turn face to the RIGHT. Must be the SAME person as the front photo.',
      Icons.turn_right_rounded,
      'Right Profile',
      refImagePath: frontPath,
    );
    if (rightPath == null || !mounted) return;

    // -- All validated - navigate -------------------------------------
    setState(() => _isCapturing = true);
    await _navigateToLoading(frontPath, leftPath: leftPath, rightPath: rightPath);
  }

  Future<void> _useDemoFace() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final data = await rootBundle.load('assets/images/sample_face.png');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/demo_face.png');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        await _navigateToLoading(file.path, leftPath: file.path, rightPath: file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showSnack('Demo failed: $e');
      }
    }
  }

  Future<void> _navigateToLoading(
    String frontPath, {
    required String leftPath,
    required String rightPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isCapturing = false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, secondaryAnim) => ScanningLoadingScreen(
          imagePath: frontPath,
          leftImagePath: leftPath,
          rightImagePath: rightPath,
          onScanCompleted: widget.onScanCompleted,
        ),
        transitionsBuilder: (_, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _cropToOval(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return;

      final photoW = image.width;
      final photoH = image.height;

      double cropW;
      double cropH;

      if (photoH > photoW) {
        // Portrait photo (common camera orientation)
        cropW = photoW * 0.72; // oval width is ~72% of width
        cropH = cropW * 1.36;  // aspect ratio is 1.36
        if (cropH > photoH) {
          cropH = photoH.toDouble();
          cropW = cropH / 1.36;
        }
      } else {
        // Landscape photo
        cropH = photoH * 0.72;
        cropW = cropH / 1.36;
      }

      final left = ((photoW - cropW) / 2).round();
      final top = ((photoH - cropH) / 2).round();
      final width = cropW.round();
      final height = cropH.round();

      // Perform fast native crop using image library
      final croppedImage = img.copyCrop(
        image,
        x: left,
        y: top,
        width: width,
        height: height,
      );

      // Save the cropped image back to disk overwriting original
      final croppedBytes = img.encodeJpg(croppedImage, quality: 90);
      await File(filePath).writeAsBytes(croppedBytes);
    } catch (e) {
      debugPrint('Error cropping image to oval: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    setState(() => _isCapturing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.cardBgSecondary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _laserCtrl.dispose();
    _borderCtrl.dispose();
    _faceDetector.close();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ovalW = size.width * 0.70;
    final ovalH = ovalW * 1.36;

    final si = _statusInfo;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera preview / placeholder
          _buildCameraLayer(size),

          // 2. Dark vignette overlay with oval cutout
          _OvalCutoutOverlay(ovalWidth: ovalW, ovalHeight: ovalH),

          // 3. Animated oval border (gold or green)
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_borderGlowAnim, _pulseAnim]),
              builder: (ctx, child) => SizedBox(
                width: ovalW,
                height: ovalH,
                child: CustomPaint(
                  painter: _OvalBorderPainter(
                    color: _isFaceGood
                        ? AppColors.accentSage
                        : _faceState == _FaceState.noFace
                            ? AppColors.primaryGold
                            : AppColors.accentRose,
                    glowOpacity: _borderGlowAnim.value,
                    progress: _captureProgress,
                  ),
                ),
              ),
            ),
          ),

          // 4. Laser line (only when face is good)
          if (_isFaceGood)
            Center(
              child: AnimatedBuilder(
                animation: _laserAnim,
                builder: (ctx, child) => SizedBox(
                  width: ovalW,
                  height: ovalH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(
                        Radius.elliptical(ovalW / 2, ovalH / 2)),
                    child: CustomPaint(
                      painter: _LaserPainter(progress: _laserAnim.value),
                    ),
                  ),
                ),
              ),
            ),

          // 4.5. High-tech 3D face mesh overlay (only visible when camera is ready)
          if (_cameraReady && !_isCapturing)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _OvalClipper(width: ovalW, height: ovalH),
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (ctx, child) => CustomPaint(
                      painter: _FaceMeshPainter(
                        pulseValue: _pulseAnim.value,
                        yaw: _meshYaw,
                        pitch: _meshPitch,
                        roll: _meshRoll,
                        offset: Offset(_meshOffsetX, _meshOffsetY),
                        scale: _meshScale,
                        ovalWidth: ovalW,
                        ovalHeight: ovalH,
                        color: _isFaceGood
                            ? AppColors.accentSage
                            : _faceState == _FaceState.noFace
                                ? AppColors.primaryGold.withValues(alpha: 0.22)
                                : AppColors.accentRose.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 5. Corner brackets
          Center(
            child: SizedBox(
              width: ovalW + 22,
              height: ovalH + 22,
              child: CustomPaint(
                painter: _CornerBracketPainter(
                  color: _isFaceGood
                      ? AppColors.accentSage
                      : AppColors.primaryGold.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),

          // 5.5. High-tech Telemetry HUD labels in background corners
          _buildHUDTelemetry(ovalW, ovalH),

          // 6. Direction arrows/guides overlay when face alignment is incorrect
          if (!_isFaceGood && _faceState != _FaceState.noFace)
            Center(
              child: SizedBox(
                width: ovalW,
                height: ovalH,
                child: _DirectionGuideOverlay(
                  state: _faceState,
                  isFrontCamera: _isFrontCamera,
                ),
              ),
            ),

          // 7. Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // 7.5. Stepper indicator showing scan progress (Front, Left, Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: _buildStepIndicator(),
          ),

          // 8. Face-state alert banner
          if (!_isFaceGood && _cameraReady && !_isCapturing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130, // moved down to prevent overlaying the stepper
              left: 20,
              right: 20,
              child: _FaceAlertBanner(state: _faceState, message: si.text),
            ),

          // 9. Status bubble (bottom of oval)
          Positioned(
            bottom: 225,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _StatusBubble(
                  key: ValueKey(_faceState),
                  text: si.text,
                  color: si.color,
                  icon: si.icon,
                ),
              ),
            ),
          ),

          // 10. Bottom control panel
          _buildBottomPanel(),

          // 11. Capturing overlay
          if (_isCapturing) _buildCapturingOverlay(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------------
  Widget _buildCameraLayer(Size size) {
    if (_cameraError) {
      return Container(
        color: const Color(0xFF080810),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_rounded,
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                    size: 60),
                const SizedBox(height: 16),
                Text(_cameraErrorMsg,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Use gallery or demo face below',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }
    if (!_cameraReady || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryGold.withValues(alpha: 0.55),
              strokeWidth: 1.5),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------------
  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _GlassIconButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('FACE  SCANNER',
                      style: TextStyle(
                        color: AppColors.primaryGoldLight,
                        fontSize: 11,
                        letterSpacing: 3.5,
                        fontWeight: FontWeight.w700,
                      )),
                  SizedBox(height: 2),
                  Text('AI Skin Analysis',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIconButton(
                    icon: Icons.flip_camera_android_rounded,
                    onTap: () => _toggleCamera(),
                  ),
                  const SizedBox(width: 8),
                  _GlassIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: () => _showGuideBottomSheet(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuideBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87.withValues(alpha: 0.7),
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F16).withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI SCAN GUIDE',
                style: TextStyle(
                  color: AppColors.primaryGoldLight,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Optimize alignment for high-fidelity skin diagnostic scans',
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _TipItem(
                icon: Icons.face_retouching_natural_rounded,
                title: '3-Direction Scanning',
                desc: 'Start front-facing, then turn your face in the direction of the on-screen flow arrows.',
              ),
              const _TipItem(
                icon: Icons.wb_sunny_rounded,
                title: 'Even Facial Lighting',
                desc: 'Shadows or uneven lighting may affect diagnostic scores. Ensure high, even frontal ambient light.',
              ),
              const _TipItem(
                icon: Icons.remove_red_eye_rounded,
                title: 'Remove Accessories',
                desc: 'Taking off glasses or hats ensures clear scan regions for cheek, nose & forehead layers.',
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primaryGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue to Scanner',
                  style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------------
  Widget _buildBottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5), blurRadius: 28)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Detection dot indicator & warnings
              if (_cameraReady && !_isCapturing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (ctx, child) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isFaceGood
                              ? AppColors.accentSage
                              : _faceState == _FaceState.noFace
                                  ? Colors.white30
                                  : AppColors.accentRose,
                          boxShadow: [
                            BoxShadow(
                              color: (_isFaceGood
                                      ? AppColors.accentSage
                                      : AppColors.accentRose)
                                  .withValues(alpha: _pulseAnim.value * 0.8),
                              blurRadius: 8,
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFaceGood
                          ? 'Face aligned - auto capturing'
                          : _faceState == _FaceState.noFace
                              ? 'Waiting for face...'
                              : 'Adjust position',
                      style: TextStyle(
                        color: _isFaceGood
                            ? AppColors.accentSage
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 11, color: Colors.white24),
                    SizedBox(width: 4),
                    Text(
                      'Ensure glasses, mask, and hair are cleared',
                      style: TextStyle(color: Colors.white24, fontSize: 9.5, letterSpacing: 0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Progress bar
              if (_captureProgress > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _captureProgress,
                    minHeight: 3,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accentSage),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Shutter Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Gallery Button
                  GestureDetector(
                    onTap: _isCapturing ? null : _pickFromGallery,
                    child: SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: const Icon(Icons.photo_library_outlined, color: Colors.white70, size: 20),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Gallery',
                            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Large Shutter Button (Manual Shutter fallback)
                  GestureDetector(
                    onTap: (_isCapturing || !_cameraReady) ? null : _captureAndProcess,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_isCapturing || !_cameraReady)
                                  ? Colors.white24
                                  : Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isCapturing || !_cameraReady)
                                  ? Colors.white12
                                  : AppColors.primaryGold,
                              boxShadow: [
                                if (!_isCapturing && _cameraReady)
                                  BoxShadow(
                                    color: AppColors.primaryGold.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: (_isCapturing || !_cameraReady)
                                    ? Colors.white24
                                    : AppColors.textDark,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currentStep == _ScanStep.front
                              ? 'Capture Front'
                              : _currentStep == _ScanStep.leftSide
                                  ? 'Capture Left'
                                  : 'Capture Right',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // 3. Demo Face Button
                  GestureDetector(
                    onTap: _isCapturing ? null : _useDemoFace,
                    child: SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white70, size: 20),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Demo Face',
                            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------------
  Widget _buildCapturingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                  color: AppColors.primaryGold, strokeWidth: 2),
            ),
            const SizedBox(height: 24),
            Text(
              'Analysing Image Quality',
              style: TextStyle(
                  color: AppColors.primaryGoldLight,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            const Text(
              'Checking lighting, sharpness & skin tone',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // High-tech telemetry HUD helpers
  // -----------------------------------------------------------------------------
  Widget _buildHUDTelemetry(double ovalW, double ovalH) {
    if (!_cameraReady || _isCapturing) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top HUD line
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHUDTag('DEPTH: 1.8mm', Icons.stacked_line_chart),
                  _buildHUDTag('AUTO-EXPOSURE', Icons.wb_auto),
                ],
              ),
              const Spacer(),
              // Bottom HUD line
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHUDTag('AI-LENS: ON', Icons.psychology_outlined),
                  _buildHUDTag('SENSITIVITY: GOLD', Icons.shutter_speed_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHUDTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryGoldLight, size: 10),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // Stepper UI helper methods for Front -> Left -> Right
  // -----------------------------------------------------------------------------
  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          _buildStepNode(
            step: _ScanStep.front,
            label: 'Front',
            isActive: _currentStep == _ScanStep.front,
            isCompleted: _currentStep == _ScanStep.leftSide || _currentStep == _ScanStep.rightSide,
          ),
          _buildStepConnector(isCompleted: _currentStep == _ScanStep.leftSide || _currentStep == _ScanStep.rightSide),
          _buildStepNode(
            step: _ScanStep.leftSide,
            label: 'Left Side',
            isActive: _currentStep == _ScanStep.leftSide,
            isCompleted: _currentStep == _ScanStep.rightSide,
          ),
          _buildStepConnector(isCompleted: _currentStep == _ScanStep.rightSide),
          _buildStepNode(
            step: _ScanStep.rightSide,
            label: 'Right Side',
            isActive: _currentStep == _ScanStep.rightSide,
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required _ScanStep step,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = isActive
        ? AppColors.primaryGold
        : isCompleted
            ? AppColors.accentSage
            : Colors.white24;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? AppColors.accentSage.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: color,
              width: isActive ? 2.5 : 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: AppColors.accentSage)
                : Text(
                    step == _ScanStep.front ? '1' : step == _ScanStep.leftSide ? '2' : '3',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.textPrimary : Colors.white30,
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.only(bottom: 12),
        color: isCompleted ? AppColors.accentSage : Colors.white12,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Direction guide overlay - animated visual feedback for face alignment
// -----------------------------------------------------------------------------
class _DirectionGuideOverlay extends StatefulWidget {
  final _FaceState state;
  final bool isFrontCamera;
  const _DirectionGuideOverlay({
    required this.state,
    required this.isFrontCamera,
  });

  @override
  State<_DirectionGuideOverlay> createState() => _DirectionGuideOverlayState();
}

class _DirectionGuideOverlayState extends State<_DirectionGuideOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) => CustomPaint(
        painter: _DirectionGuidePainter(
          state: widget.state,
          animationValue: _ctrl.value,
          isFrontCamera: widget.isFrontCamera,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DirectionGuidePainter extends CustomPainter {
  final _FaceState state;
  final double animationValue;
  final bool isFrontCamera;

  const _DirectionGuidePainter({
    required this.state,
    required this.animationValue,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentRose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final bool drawLeft = (state == _FaceState.turnLeft && isFrontCamera) ||
                          (state == _FaceState.turnRight && !isFrontCamera);

    if (drawLeft) {
      // 3 chevrons flowing left
      for (int i = 0; i < 3; i++) {
        final t = (animationValue + i / 3.0) % 1.0;
        final dx = cx - 15 - (t * 80);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        paint.color = AppColors.accentRose.withValues(alpha: opacity * 0.85);
        _drawChevronLeft(canvas, Offset(dx, cy), 24, paint);
      }
    } else if (state == _FaceState.turnLeft || state == _FaceState.turnRight) {
      // 3 chevrons flowing right
      for (int i = 0; i < 3; i++) {
        final t = (animationValue + i / 3.0) % 1.0;
        final dx = cx + 15 + (t * 80);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        paint.color = AppColors.accentRose.withValues(alpha: opacity * 0.85);
        _drawChevronRight(canvas, Offset(dx, cy), 24, paint);
      }
    } else if (state == _FaceState.lookUp) {
      // 3 chevrons flowing up (indicating to tilt chin up)
      for (int i = 0; i < 3; i++) {
        final t = (animationValue + i / 3.0) % 1.0;
        final dy = cy - 25 - (t * 65);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        paint.color = AppColors.accentRose.withValues(alpha: opacity * 0.85);
        _drawChevronUp(canvas, Offset(cx, dy), 24, paint);
      }
    } else if (state == _FaceState.lookDown) {
      // 3 chevrons flowing down (indicating to tilt chin down)
      for (int i = 0; i < 3; i++) {
        final t = (animationValue + i / 3.0) % 1.0;
        final dy = cy + 25 + (t * 65);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        paint.color = AppColors.accentRose.withValues(alpha: opacity * 0.85);
        _drawChevronDown(canvas, Offset(cx, dy), 24, paint);
      }
    } else if (state == _FaceState.tiltHead) {
      // Rotate indicators
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: 75, height: 75);
      final angleStart = -math.pi / 4 + (animationValue * math.pi / 2);
      paint.color = AppColors.accentRose.withValues(alpha: 0.75);
      canvas.drawArc(rect, angleStart, math.pi / 2, false, paint);
      canvas.drawArc(rect, angleStart + math.pi, math.pi / 2, false, paint);
    } else if (state == _FaceState.tooFar) {
      // Concentric dashed guide lines collapsing inward to prompt user to get closer
      final t = animationValue;
      final ovalW1 = size.width * (1.0 + (1.0 - t) * 0.25);
      final ovalH1 = ovalW1 * 1.36;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: ovalW1, height: ovalH1);
      
      paint.color = AppColors.primaryGold.withValues(alpha: (t * 0.6).clamp(0.0, 1.0));
      paint.strokeWidth = 1.8;
      _drawDashedOval(canvas, rect, paint);
    } else if (state == _FaceState.tooClose) {
      // Concentric dashed guide lines expanding outward to prompt user to step back
      final t = animationValue;
      final ovalW1 = size.width * (0.85 + t * 0.25);
      final ovalH1 = ovalW1 * 1.36;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: ovalW1, height: ovalH1);
      
      paint.color = AppColors.primaryGold.withValues(alpha: ((1.0 - t) * 0.6).clamp(0.0, 1.0));
      paint.strokeWidth = 1.8;
      _drawDashedOval(canvas, rect, paint);
    }
  }

  void _drawChevronLeft(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx + size / 2, center.dy - size / 2)
      ..lineTo(center.dx - size / 2, center.dy)
      ..lineTo(center.dx + size / 2, center.dy + size / 2);
    canvas.drawPath(path, paint);
  }

  void _drawChevronRight(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - size / 2, center.dy - size / 2)
      ..lineTo(center.dx + size / 2, center.dy)
      ..lineTo(center.dx - size / 2, center.dy + size / 2);
    canvas.drawPath(path, paint);
  }

  void _drawChevronUp(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - size / 2, center.dy + size / 2)
      ..lineTo(center.dx, center.dy - size / 2)
      ..lineTo(center.dx + size / 2, center.dy + size / 2);
    canvas.drawPath(path, paint);
  }

  void _drawChevronDown(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - size / 2, center.dy - size / 2)
      ..lineTo(center.dx, center.dy + size / 2)
      ..lineTo(center.dx + size / 2, center.dy - size / 2);
    canvas.drawPath(path, paint);
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addOval(rect);
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final len = math.min(dashWidth, pathMetric.length - distance);
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + len),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DirectionGuidePainter old) =>
      old.state != state || old.animationValue != animationValue;
}

// -----------------------------------------------------------------------------
// Face state alert banner (slides in from top)
// -----------------------------------------------------------------------------
class _FaceAlertBanner extends StatefulWidget {
  final _FaceState state;
  final String message;
  const _FaceAlertBanner({required this.state, required this.message});

  @override
  State<_FaceAlertBanner> createState() => _FaceAlertBannerState();
}

class _FaceAlertBannerState extends State<_FaceAlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _bannerColor {
    switch (widget.state) {
      case _FaceState.noFace:
        return Colors.white24;
      case _FaceState.tooFar:
      case _FaceState.tooClose:
        return AppColors.primaryGold;
      default:
        return AppColors.accentRose;
    }
  }

  IconData get _bannerIcon {
    switch (widget.state) {
      case _FaceState.noFace: return Icons.face_outlined;
      case _FaceState.tooFar: return Icons.zoom_in_rounded;
      case _FaceState.tooClose: return Icons.zoom_out_rounded;
      case _FaceState.outOfOval: return Icons.filter_center_focus_rounded;
      case _FaceState.turnLeft: return Icons.rotate_left_rounded;
      case _FaceState.turnRight: return Icons.rotate_right_rounded;
      case _FaceState.lookUp: return Icons.arrow_upward_rounded;
      case _FaceState.lookDown: return Icons.arrow_downward_rounded;
      case _FaceState.tiltHead: return Icons.straighten_rounded;
      case _FaceState.good: return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _bannerColor;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 20)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_bannerIcon, color: c, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Status bubble (animated switch)
// -----------------------------------------------------------------------------
class _StatusBubble extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _StatusBubble(
      {super.key, required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Oval cutout overlay painter
// -----------------------------------------------------------------------------
class _OvalCutoutOverlay extends StatelessWidget {
  final double ovalWidth, ovalHeight;
  const _OvalCutoutOverlay(
      {required this.ovalWidth, required this.ovalHeight});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter:
            _CutoutPainter(ovalWidth: ovalWidth, ovalHeight: ovalHeight),
        child: const SizedBox.expand(),
      );
}

class _CutoutPainter extends CustomPainter {
  final double ovalWidth, ovalHeight;
  const _CutoutPainter({required this.ovalWidth, required this.ovalHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final oval = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: ovalWidth,
          height: ovalHeight));
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlay, oval),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.70)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_CutoutPainter old) =>
      old.ovalWidth != ovalWidth || old.ovalHeight != ovalHeight;
}

// -----------------------------------------------------------------------------
// Oval border with glow + progress arc
// -----------------------------------------------------------------------------
class _OvalBorderPainter extends CustomPainter {
  final Color color;
  final double glowOpacity;
  final double progress;
  const _OvalBorderPainter(
      {required this.color,
      required this.glowOpacity,
      required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Glow
    canvas.drawOval(
      rect,
      Paint()
        ..color = color.withValues(alpha: glowOpacity * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Border
    canvas.drawOval(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        rect.deflate(1),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppColors.accentSage
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_OvalBorderPainter old) =>
      old.color != color ||
      old.glowOpacity != glowOpacity ||
      old.progress != progress;
}

// -----------------------------------------------------------------------------
// Laser scan line (visible only when face is good)
// -----------------------------------------------------------------------------
class _LaserPainter extends CustomPainter {
  final double progress;
  const _LaserPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 24, size.width, 48),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accentSage.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, y - 24, size.width, 48)),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accentSage.withValues(alpha: 0.5),
            AppColors.accentSage.withValues(alpha: 0.9),
            AppColors.accentSage.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, y, size.width, 1.5))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LaserPainter old) => old.progress != progress;
}

// -----------------------------------------------------------------------------
// Corner brackets
// -----------------------------------------------------------------------------
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  const _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), p);
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), p);
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), p);
    canvas.drawLine(
        Offset(size.width - len, size.height),
        Offset(size.width, size.height), p);
    canvas.drawLine(
        Offset(size.width, size.height - len),
        Offset(size.width, size.height), p);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.color != color;
}

// -----------------------------------------------------------------------------
// Glass icon button
// -----------------------------------------------------------------------------
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      );
}



// -----------------------------------------------------------------------------
// Guide dialog tip item
// -----------------------------------------------------------------------------
class _TipItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _TipItem({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryGold, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
}

// -----------------------------------------------------------------------------
// Futuristic face wireframe locking mesh painter (3D warped perspective)
// -----------------------------------------------------------------------------
class _FaceMeshPainter extends CustomPainter {
  final double pulseValue;
  final double yaw;
  final double pitch;
  final double roll;
  final Offset offset;
  final double scale;
  final double ovalWidth;
  final double ovalHeight;
  final Color color;

  const _FaceMeshPainter({
    required this.pulseValue,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.offset,
    required this.scale,
    required this.ovalWidth,
    required this.ovalHeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();

    // 1. Shift the canvas coordinate origin to face lock center
    canvas.translate(cx + offset.dx, cy + offset.dy);

    // 2. Rotate mesh by user's head roll
    final rollRad = roll * math.pi / 180;
    canvas.rotate(rollRad);

    // 3. Scale mesh by user's distance ratio
    canvas.scale(scale);

    final w = ovalWidth;
    final h = ovalHeight;

    // 4. Perspective shifts for nose/mouth features based on head orientation
    // yawShift dictates horizontal shift. If yaw > 0 (face turns right -> screen left)
    final yawShift = -yaw * (w * 0.007);
    // pitchShift dictates vertical offset. If pitch > 0 (face looks up)
    final pitchShift = -pitch * (h * 0.0065);

    // Cheek width squashing based on perspective angle
    final double compressFactor = (yaw.abs() * 0.008).clamp(0.0, 0.42);
    final double leftWidthScale = yaw > 0 ? (1.0 + compressFactor * 0.4) : (1.0 - compressFactor);
    final double rightWidthScale = yaw > 0 ? (1.0 - compressFactor) : (1.0 + compressFactor * 0.4);

    // Dynamic 3D perspective node locations inside oval viewport coordinates
    final nodes = {
      'forehead': Offset(yawShift * 0.25, -h * 0.28 + pitchShift * 0.15),
      'nose_bridge': Offset(yawShift * 0.65, -h * 0.05 + pitchShift * 0.45),
      'nose_tip': Offset(yawShift * 1.15, h * 0.06 + pitchShift * 1.05),
      'eye_l': Offset(-w * 0.18 * leftWidthScale + yawShift * 0.15, -h * 0.12),
      'eye_r': Offset(w * 0.18 * rightWidthScale + yawShift * 0.15, -h * 0.12),
      'cheek_l': Offset(-w * 0.28 * leftWidthScale, h * 0.08 + pitchShift * 0.25),
      'cheek_r': Offset(w * 0.28 * rightWidthScale, h * 0.08 + pitchShift * 0.25),
      'mouth_l': Offset(-w * 0.12 * leftWidthScale + yawShift * 0.75, h * 0.20 + pitchShift * 0.75),
      'mouth_r': Offset(w * 0.12 * rightWidthScale + yawShift * 0.75, h * 0.20 + pitchShift * 0.75),
      'chin': Offset(yawShift * 0.45, h * 0.32 + pitchShift * 0.85),
    };

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.15 + pulseValue * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.5 + pulseValue * 0.45)
      ..style = PaintingStyle.fill;

    void connect(String n1, String n2) {
      if (nodes.containsKey(n1) && nodes.containsKey(n2)) {
        canvas.drawLine(nodes[n1]!, nodes[n2]!, linePaint);
      }
    }

    // Connect nodes with futuristic triangulation mesh lines
    connect('forehead', 'eye_l');
    connect('forehead', 'eye_r');
    connect('eye_l', 'eye_r');
    connect('eye_l', 'nose_bridge');
    connect('eye_r', 'nose_bridge');
    connect('nose_bridge', 'nose_tip');
    connect('eye_l', 'cheek_l');
    connect('eye_r', 'cheek_r');
    connect('nose_tip', 'cheek_l');
    connect('nose_tip', 'cheek_r');
    connect('cheek_l', 'mouth_l');
    connect('cheek_r', 'mouth_r');
    connect('nose_tip', 'mouth_l');
    connect('nose_tip', 'mouth_r');
    connect('mouth_l', 'mouth_r');
    connect('mouth_l', 'chin');
    connect('mouth_r', 'chin');
    connect('cheek_l', 'chin');
    connect('cheek_r', 'chin');

    // Draw nodes & halo pulsing rings around structural points
    nodes.forEach((key, pt) {
      if (key == 'forehead' || key == 'cheek_l' || key == 'cheek_r' || key == 'chin') {
        canvas.drawCircle(
          pt,
          3.0 + pulseValue * 5.0,
          Paint()
            ..color = color.withValues(alpha: (1.0 - pulseValue) * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
      canvas.drawCircle(pt, 2.5, dotPaint);
    });

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FaceMeshPainter old) =>
      old.pulseValue != pulseValue ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.roll != roll ||
      old.offset != offset ||
      old.scale != scale ||
      old.ovalWidth != ovalWidth ||
      old.ovalHeight != ovalHeight ||
      old.color != color;
}

// -----------------------------------------------------------------------------
// Custom clipper to restrict face mesh drawing boundaries to the central oval
// -----------------------------------------------------------------------------
class _OvalClipper extends CustomClipper<Path> {
  final double width;
  final double height;
  const _OvalClipper({required this.width, required this.height});

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: width,
        height: height,
      ));
  }

  @override
  bool shouldReclip(_OvalClipper oldClipper) =>
      oldClipper.width != width || oldClipper.height != height;
}

