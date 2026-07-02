import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/scan_service.dart';
import '../results/results_screen.dart';

class ScanningLoadingScreen extends StatefulWidget {
  final String imagePath;
  final VoidCallback onScanCompleted;

  const ScanningLoadingScreen({
    super.key,
    required this.imagePath,
    required this.onScanCompleted,
  });

  @override
  State<ScanningLoadingScreen> createState() => _ScanningLoadingScreenState();
}

class _ScanningLoadingScreenState extends State<ScanningLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final List<String> _scanLogs = [
    "Initializing neural network model...",
    "Aligning face landmarks & cropping regions...",
    "Analyzing forehead expression lines...",
    "Evaluating cheek vascular redness...",
    "Detecting sub-orbital fatigue shading...",
    "Measuring T-zone sebum specularity...",
    "Compiling reports & recommendations..."
  ];

  int _logIndex = 0;
  Timer? _logTimer;
  late ScanService _scanService;

  @override
  void initState() {
    super.initState();
    _scanService = ScanService();

    // Laser vertical scanning animation
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    // Rotate log statements every 400ms
    _logTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (_logIndex < _scanLogs.length - 1) {
        setState(() {
          _logIndex++;
        });
      }
    });

    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    // Call service to run image processing
    final scanResult = await _scanService.analyzeSkinImage(
      widget.imagePath,
      authService.currentUid!,
    );

    // Save scan to database / preferences
    await storageService.saveSkinScan(scanResult);

    // Trigger home reload
    widget.onScanCompleted();

    if (mounted) {
      // Route directly to results screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(scan: scanResult),
        ),
      );
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _logTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Header
              const Text(
                "ANALYZING SKIN LAYERS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryGold,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "AuraSkin AI engine is processing your image",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              
              // Face image scanning panel
              Expanded(
                child: Center(
                  child: Container(
                    height: 360,
                    width: 270,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // User Face Image
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.6,
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // High-tech scanning grid background
                        Positioned.fill(
                          child: GridPaper(
                            color: AppColors.primaryGold.withValues(alpha: 0.04),
                            interval: 20,
                            subdivisions: 1,
                          ),
                        ),

                        // Laser Scanner animation line
                        AnimatedBuilder(
                          animation: _laserController,
                          builder: (context, child) {
                            return Positioned(
                              top: _laserAnimation.value * 360,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryGold.withValues(alpha: 0.8),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Corner borders (HUD style)
                        _buildHUDCorner(top: 10, left: 10, angleX: 1, angleY: 1),
                        _buildHUDCorner(top: 10, right: 10, angleX: -1, angleY: 1),
                        _buildHUDCorner(bottom: 10, left: 10, angleX: 1, angleY: -1),
                        _buildHUDCorner(bottom: 10, right: 10, angleX: -1, angleY: -1),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Console log output
              Container(
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.terminal_outlined, color: AppColors.primaryGold, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "PROCESSING LOG",
                          style: TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _logIndex + 1,
                        itemBuilder: (context, index) {
                          final isLatest = index == _logIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  isLatest ? Icons.chevron_right : Icons.check_circle_outline,
                                  size: 14,
                                  color: isLatest ? AppColors.primaryGold : AppColors.accentSage,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _scanLogs[index],
                                    style: TextStyle(
                                      color: isLatest ? Colors.white : Colors.white60,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHUDCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double angleX,
    required double angleY,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: 16,
        height: 16,
        child: CustomPaint(
          painter: HUDCornerPainter(angleX: angleX, angleY: angleY),
        ),
      ),
    );
  }
}

class HUDCornerPainter extends CustomPainter {
  final double angleX;
  final double angleY;

  HUDCornerPainter({required this.angleX, required this.angleY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Draw corner bracket lines
    if (angleX > 0) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
    }

    if (angleY > 0) {
      path.lineTo(angleX > 0 ? 0 : size.width, size.height);
    } else {
      path.lineTo(angleX > 0 ? 0 : size.width, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
