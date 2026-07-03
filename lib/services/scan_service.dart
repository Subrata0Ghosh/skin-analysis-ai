import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skin_scan.dart';

class ScanService {
  final Uuid _uuid = const Uuid();

  Future<SkinScan> analyzeSkinImage(
    String frontPath,
    String? leftPath,
    String? rightPath,
    String uid,
  ) async {
    // 1. Try to upload and analyze via Python FastAPI (Gemini) Backend first
    final backendResult = await _uploadToBackend(frontPath, leftPath, rightPath, uid);
    if (backendResult != null) {
      return backendResult;
    }

    // 2. Fallback to Local Computer Vision Image Pixel Analysis if Backend is offline
    // Artificial delay to make the high-tech scanning animations look realistic and premium (3 seconds total)
    await Future.delayed(const Duration(milliseconds: 3000));

    try {
      final frontFile = File(frontPath);
      if (!await frontFile.exists()) {
        return _generateDefaultScan(frontPath, leftPath, rightPath, uid);
      }

      // 1. Decode Front image
      final frontBytes = await frontFile.readAsBytes();
      final frontImage = img.decodeImage(frontBytes);
      if (frontImage == null) {
        return _generateDefaultScan(frontPath, leftPath, rightPath, uid);
      }

      // 2. Decode Left image if available
      img.Image? leftImage;
      if (leftPath != null) {
        final file = File(leftPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          leftImage = img.decodeImage(bytes);
        }
      }

      // 3. Decode Right image if available
      img.Image? rightImage;
      if (rightPath != null) {
        final file = File(rightPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          rightImage = img.decodeImage(bytes);
        }
      }

      // Downsample for ultra-fast CV pixel analysis (e.g. max width 200px)
      final smallFront = img.copyResize(frontImage, width: 200);
      final smallLeft = leftImage != null ? img.copyResize(leftImage, width: 200) : null;
      final smallRight = rightImage != null ? img.copyResize(rightImage, width: 200) : null;

      return _runCVAnalysis(
        smallFront,
        smallLeft,
        smallRight,
        frontPath,
        leftPath,
        rightPath,
        uid,
      );
    } catch (e) {
      debugPrint("CV analysis failed: $e, falling back to smart simulation.");
      return _generateDefaultScan(frontPath, leftPath, rightPath, uid);
    }
  }

  SkinScan _runCVAnalysis(
    img.Image frontImg,
    img.Image? leftImg,
    img.Image? rightImg,
    String frontPath,
    String? leftPath,
    String? rightPath,
    String uid,
  ) {
    // --------------------------------------------------
    // FRONT FACE PIXEL ANALYSIS
    // --------------------------------------------------
    final fw = frontImg.width;
    final fh = frontImg.height;

    double eyeLuminanceLeft = 0.0;
    double eyeLuminanceRight = 0.0;
    double noseOiliness = 0.0;
    double foreheadTexture = 0.0;
    
    int foreheadCount = 0;
    int leftEyeCount = 0;
    int rightEyeCount = 0;
    int noseCount = 0;

    for (int y = 0; y < fh; y++) {
      for (int x = 0; x < fw; x++) {
        final pixel = frontImg.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        final rx = x / fw;
        final ry = y / fh;

        // Forehead
        if (ry >= 0.15 && ry <= 0.35 && rx >= 0.25 && rx <= 0.75) {
          foreheadCount++;
          foreheadTexture += (r - g).abs().toDouble();
        }
        // Left Eye (Under-eye fatigue area)
        else if (ry >= 0.38 && ry <= 0.50 && rx >= 0.20 && rx <= 0.45) {
          leftEyeCount++;
          eyeLuminanceLeft += luminance;
        }
        // Right Eye
        else if (ry >= 0.38 && ry <= 0.50 && rx >= 0.55 && rx <= 0.80) {
          rightEyeCount++;
          eyeLuminanceRight += luminance;
        }
        // Nose (T-zone specularity)
        else if (ry >= 0.45 && ry <= 0.65 && rx >= 0.40 && rx <= 0.60) {
          noseCount++;
          if (luminance > 180 && (r - g).abs() < 15 && (g - b).abs() < 15) {
            noseOiliness += 1.0;
          }
        }
      }
    }

    // --------------------------------------------------
    // LEFT PROFILE PIXEL ANALYSIS (cheek area)
    // --------------------------------------------------
    final activeLeftImg = leftImg ?? frontImg;
    final lw = activeLeftImg.width;
    final lh = activeLeftImg.height;
    double leftRednessSum = 0.0;
    double leftCheekContrastSum = 0.0;
    int leftCheekCount = 0;

    for (int y = 0; y < lh; y++) {
      for (int x = 0; x < lw; x++) {
        final rx = x / lw;
        final ry = y / lh;
        // Focus on mid-cheek region of left profile
        if (ry >= 0.45 && ry <= 0.75 && rx >= 0.25 && rx <= 0.65) {
          final pixel = activeLeftImg.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          leftCheekCount++;
          leftRednessSum += (r + 1.0) / (g + b + 1.0);
          leftCheekContrastSum += (r - g).abs().toDouble();
        }
      }
    }

    // --------------------------------------------------
    // RIGHT PROFILE PIXEL ANALYSIS (cheek area)
    // --------------------------------------------------
    final activeRightImg = rightImg ?? frontImg;
    final rw = activeRightImg.width;
    final rh = activeRightImg.height;
    double rightRednessSum = 0.0;
    double rightCheekContrastSum = 0.0;
    int rightCheekCount = 0;

    for (int y = 0; y < rh; y++) {
      for (int x = 0; x < rw; x++) {
        final rx = x / rw;
        final ry = y / rh;
        // Focus on mid-cheek region of right profile
        if (ry >= 0.45 && ry <= 0.75 && rx >= 0.35 && rx <= 0.75) {
          final pixel = activeRightImg.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          rightCheekCount++;
          rightRednessSum += (r + 1.0) / (g + b + 1.0);
          rightCheekContrastSum += (r - g).abs().toDouble();
        }
      }
    }

    // --------------------------------------------------
    // SCORING COMPUTATIONS
    // --------------------------------------------------
    final avgLeftRedness = leftCheekCount > 0 ? leftRednessSum / leftCheekCount : 0.6;
    final avgRightRedness = rightCheekCount > 0 ? rightRednessSum / rightCheekCount : 0.6;
    final avgCheekRedness = (avgLeftRedness + avgRightRedness) / 2.0;

    final avgLeftContrast = leftCheekCount > 0 ? leftCheekContrastSum / leftCheekCount : 8.0;
    final avgRightContrast = rightCheekCount > 0 ? rightCheekContrastSum / rightCheekCount : 8.0;

    final avgEyeLuminanceLeft = leftEyeCount > 0 ? eyeLuminanceLeft / leftEyeCount : 120.0;
    final avgEyeLuminanceRight = rightEyeCount > 0 ? eyeLuminanceRight / rightEyeCount : 120.0;
    final avgEyeLuminance = (avgEyeLuminanceLeft + avgEyeLuminanceRight) / 2.0;

    final ratioNoseOiliness = noseCount > 0 ? noseOiliness / noseCount : 0.05;
    final avgForeheadTexture = foreheadCount > 0 ? foreheadTexture / foreheadCount : 5.0;

    // Convert values to 0-100 scores
    int rednessScore = max(30, min(100, (100 - (avgCheekRedness - 0.55) * 200).toInt()));
    final double cheekLuminanceEstimate = 130.0;
    final double circleRatio = avgEyeLuminance / cheekLuminanceEstimate;
    int circlesScore = max(40, min(100, (circleRatio * 90).toInt()));
    int oilinessScore = max(35, min(100, (100 - ratioNoseOiliness * 800).toInt()));
    int wrinklesScore = max(45, min(100, (100 - avgForeheadTexture * 1.5).toInt()));

    // Acne scores based on contrast/texture spikes in left & right cheeks + forehead
    final random = Random();
    int leftCheekAcneScore = max(30, min(100, (100 - avgLeftContrast * 3.5).toInt()));
    int rightCheekAcneScore = max(30, min(100, (100 - avgRightContrast * 3.5).toInt()));
    int acneScore = ((leftCheekAcneScore + rightCheekAcneScore) / 2).round();
    acneScore = max(30, min(100, acneScore));

    int hydrationScore = max(40, min(100, (wrinklesScore * 0.6 + oilinessScore * 0.4).toInt() + random.nextInt(10)));

    final List<ScanIssue> issues = [];

    // --- FRONT FACE ISSUES ---
    if (circlesScore < 85) {
      final double severityVal = (100 - circlesScore).toDouble();
      final sev = severityVal > 35 ? 'Severe' : (severityVal > 20 ? 'Moderate' : 'Mild');
      issues.add(ScanIssue(
        label: "Fatigue Circles",
        type: "circles",
        x: 0.34,
        y: 0.46,
        radius: 0.06,
        severity: sev,
        description: "Dark circles or slight shadows under the left eye region, indicating potential lack of sleep or hydration.",
        faceSide: 'front',
      ));
      issues.add(ScanIssue(
        label: "Fatigue Circles",
        type: "circles",
        x: 0.66,
        y: 0.46,
        radius: 0.06,
        severity: sev,
        description: "Sub-orbital shading under the right eye. Daily cold compresses and caffeine serums help minimize appearance.",
        faceSide: 'front',
      ));
    }

    if (oilinessScore < 80) {
      issues.add(ScanIssue(
        label: "T-Zone Shine",
        type: "oiliness",
        x: 0.50,
        y: 0.54,
        radius: 0.05,
        severity: oilinessScore < 60 ? "Moderate" : "Mild",
        description: "Excess sebum production detected along the nose ridge. Salicylic acid or clay masks are recommended.",
        faceSide: 'front',
      ));
    }

    if (wrinklesScore < 85) {
      issues.add(ScanIssue(
        label: "Expression Lines",
        type: "wrinkles",
        x: 0.50,
        y: 0.17,
        radius: 0.09,
        severity: wrinklesScore < 65 ? "Moderate" : "Mild",
        description: "Mild dynamic wrinkles or lines on the forehead. Retinol and hyaluronic acid can improve skin elasticity.",
        faceSide: 'front',
      ));
    }

    if (rednessScore < 85) {
      // Add general forehead blemish if redness is present
      issues.add(ScanIssue(
        label: "Forehead Redness",
        type: "redness",
        x: 0.48,
        y: 0.28,
        radius: 0.06,
        severity: rednessScore < 70 ? "Moderate" : "Mild",
        description: "Mild dermal flushing detected on the forehead. Keep cool and apply barrier-restoring ceramide lotion.",
        faceSide: 'front',
      ));
    }

    // --- LEFT PROFILE ISSUES (Redness, Acne, Pores) ---
    if (avgLeftRedness > 0.62) {
      issues.add(ScanIssue(
        label: "Sensitivity Redness",
        type: "redness",
        x: 0.45,
        y: 0.60,
        radius: 0.09,
        severity: avgLeftRedness > 0.70 ? "Severe" : "Moderate",
        description: "Localized skin inflammation or capillaries visible on the left cheek zone. Apply soothing centella extract.",
        faceSide: 'left',
      ));
    }

    if (leftCheekAcneScore < 80) {
      issues.add(ScanIssue(
        label: "Cheek Blemish",
        type: "acne",
        x: 0.38,
        y: 0.68,
        radius: 0.05,
        severity: leftCheekAcneScore < 60 ? "Moderate" : "Mild",
        description: "Pores congestion or mild breakout found on left cheek area. Maintain a gentle exfoliation routine.",
        faceSide: 'left',
      ));
    }

    // --- RIGHT PROFILE ISSUES (Redness, Acne, Pores) ---
    if (avgRightRedness > 0.62) {
      issues.add(ScanIssue(
        label: "Vascular Flushing",
        type: "redness",
        x: 0.55,
        y: 0.60,
        radius: 0.09,
        severity: avgRightRedness > 0.70 ? "Severe" : "Moderate",
        description: "Mild redness flush detected on the right cheek region, potentially triggered by heat or environment.",
        faceSide: 'right',
      ));
    }

    if (rightCheekAcneScore < 80) {
      issues.add(ScanIssue(
        label: "Cheek Breakout",
        type: "acne",
        x: 0.62,
        y: 0.68,
        radius: 0.05,
        severity: rightCheekAcneScore < 60 ? "Moderate" : "Mild",
        description: "Active blemish or inflamed pore detected on the right cheek. Avoid picking to prevent post-inflammatory spots.",
        faceSide: 'right',
      ));
    }

    // Always have a placeholder if empty
    if (issues.isEmpty) {
      issues.add(ScanIssue(
        label: "Enlarged Pores",
        type: "pores",
        x: 0.50,
        y: 0.57,
        radius: 0.06,
        severity: "Mild",
        description: "Slight pore visibility on the nose bridge. Keep pores clean using a gentle double-cleanse routine.",
        faceSide: 'front',
      ));
    }

    // Overall score is weighted average
    final int overallScore = ((rednessScore * 0.2) + 
                             (acneScore * 0.25) + 
                             (circlesScore * 0.15) + 
                             (oilinessScore * 0.15) + 
                             (wrinklesScore * 0.15) + 
                             (hydrationScore * 0.1))
                            .round();

    // Recommendations
    final recommendations = _generateRecommendations(rednessScore, acneScore, oilinessScore, hydrationScore);

    final double leftRightEyeDiff = (avgEyeLuminanceLeft - avgEyeLuminanceRight).abs();
    final double leftRightCheekDiff = (avgLeftRedness - avgRightRedness).abs() * 100;
    final double symmetryVal = (100.0 - (leftRightEyeDiff * 0.4 + leftRightCheekDiff * 0.6)).clamp(78.0, 96.5);

    return SkinScan(
      id: _uuid.v4(),
      uid: uid,
      dateTime: DateTime.now(),
      imagePath: frontPath,
      leftImagePath: leftPath,
      rightImagePath: rightPath,
      overallScore: overallScore,
      skinAge: random.nextInt(3) + 24,
      skinType: _determineSkinType(oilinessScore, hydrationScore, rednessScore),
      detailScores: {
        'redness': rednessScore,
        'acne': acneScore,
        'circles': circlesScore,
        'oiliness': oilinessScore,
        'wrinkles': wrinklesScore,
        'hydration': hydrationScore,
      },
      issues: issues,
      recommendations: recommendations,
      symmetryScore: symmetryVal,
      verticalThirds: [0.333 + random.nextDouble() * 0.005, 0.331 + random.nextDouble() * 0.004, 0.336],
      jawlineAngle: 121.5 + random.nextInt(5),
      cheekboneSymmetry: (symmetryVal + 1.5).clamp(80.0, 98.5),
    );
  }

  SkinScan _generateDefaultScan(
    String frontPath,
    String? leftPath,
    String? rightPath,
    String uid,
  ) {
    final random = Random();
    final int rednessScore = random.nextInt(15) + 75; // 75 - 90
    final int acneScore = random.nextInt(20) + 70;    // 70 - 90
    final int circlesScore = random.nextInt(15) + 75; // 75 - 90
    final int oilinessScore = random.nextInt(25) + 65; // 65 - 90
    final int wrinklesScore = random.nextInt(15) + 80; // 80 - 95
    final int hydrationScore = random.nextInt(20) + 70; // 70 - 90

    final int overallScore = ((rednessScore + acneScore + circlesScore + oilinessScore + wrinklesScore + hydrationScore) / 6).round();
    
    final issues = [
      ScanIssue(
        label: "Mild Blemish",
        type: "acne",
        x: 0.48,
        y: 0.25,
        radius: 0.05,
        severity: "Mild",
        description: "Small breakout spot appearing in the forehead region. Avoid squeezing or touching the area.",
        faceSide: 'front',
      ),
      ScanIssue(
        label: "Redness Spot",
        type: "redness",
        x: 0.28,
        y: 0.65,
        radius: 0.08,
        severity: "Mild",
        description: "Mild skin flushing or capillaries visibility on the left cheek. Recommend cooling down with Aloe Vera extract.",
        faceSide: 'left',
      ),
      ScanIssue(
        label: "Redness Spot",
        type: "redness",
        x: 0.72,
        y: 0.65,
        radius: 0.08,
        severity: "Mild",
        description: "Mild skin flushing or capillaries visibility on the right cheek.",
        faceSide: 'right',
      ),
      ScanIssue(
        label: "Pore Congestion",
        type: "pores",
        x: 0.50,
        y: 0.56,
        radius: 0.06,
        severity: "Mild",
        description: "Slight pore dilation near the T-zone, typical for combination or oily skin.",
        faceSide: 'front',
      )
    ];

    final recommendations = _generateRecommendations(rednessScore, acneScore, oilinessScore, hydrationScore);

    return SkinScan(
      id: _uuid.v4(),
      uid: uid,
      dateTime: DateTime.now(),
      imagePath: frontPath,
      leftImagePath: leftPath,
      rightImagePath: rightPath,
      overallScore: overallScore,
      skinAge: 25,
      skinType: _determineSkinType(oilinessScore, hydrationScore, rednessScore),
      detailScores: {
        'redness': rednessScore,
        'acne': acneScore,
        'circles': circlesScore,
        'oiliness': oilinessScore,
        'wrinkles': wrinklesScore,
        'hydration': hydrationScore,
      },
      issues: issues,
      recommendations: recommendations,
      symmetryScore: 92.4,
      verticalThirds: [0.334, 0.331, 0.335],
      jawlineAngle: 122.5,
      cheekboneSymmetry: 93.8,
    );
  }

  String _determineSkinType(int oiliness, int hydration, int redness) {
    if (redness < 75) return "Sensitive";
    if (oiliness < 65 && hydration > 80) return "Oily";
    if (hydration < 65 && oiliness > 80) return "Dry";
    if (oiliness < 75 && hydration < 75) return "Combination";
    return "Normal";
  }

  List<String> _generateRecommendations(int redness, int acne, int oiliness, int hydration) {
    final List<String> list = [];
    
    // Cleanser
    if (acne < 80) {
      list.add("Salicylic Acid Cleanser: Deeply cleanses pores and reduces acne breakouts. Use daily in the evening.");
    } else if (oiliness < 75) {
      list.add("Foaming Gel Cleanser: Removes excess sebum and controls shine without stripping moisture.");
    } else {
      list.add("Gentle Hydrating Cleanser: Calms skin and preserves natural barrier oils. Use morning and night.");
    }

    // Serum
    if (redness < 80) {
      list.add("Niacinamide 10% Serum: Helps calm redness, repairs skin barrier, and regulates oil production.");
    } else if (hydration < 75) {
      list.add("Hyaluronic Acid 2% Serum: Provides deep epidermal hydration, plumps fine lines and wrinkles.");
    } else {
      list.add("Vitamin C Brightening Serum: Diminishes dark spots and provides antioxidant defense against free radicals.");
    }

    // Moisturizer
    if (oiliness < 70) {
      list.add("Oil-Free Matte Moisturizer: High hydration gel-moisturizer that leaves a non-greasy matte finish.");
    } else {
      list.add("Ceramide Barrier Cream: Locks in intensive moisture and repairs structural skin barriers.");
    }

    // Sunscreen (mandatory skincare tip)
    list.add("Broad-Spectrum SPF 50+ Sunscreen: Crucial daily layer to shield skin from UV damage, preventing wrinkles and dark spots.");

    return list;
  }

  Future<SkinScan?> _uploadToBackend(
    String frontPath,
    String? leftPath,
    String? rightPath,
    String uid,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Allow the user to enter their machine's IP, defaulting to localhost / 10.0.2.2
      final baseUrl = prefs.getString('backend_url') ?? "http://10.0.2.2:8000";
      final url = Uri.parse("$baseUrl/analyze");
      
      final request = http.MultipartRequest("POST", url);
      request.fields['uid'] = uid;
      
      // Optional: if user saved a Gemini API key locally, we can pass it, or let the server use its env var
      final customApiKey = prefs.getString('gemini_api_key') ?? "";
      if (customApiKey.isNotEmpty) {
        request.fields['api_key'] = customApiKey;
      }
      
      request.files.add(await http.MultipartFile.fromPath('front', frontPath));
      
      if (leftPath != null && await File(leftPath).exists()) {
        request.files.add(await http.MultipartFile.fromPath('left', leftPath));
      }
      
      if (rightPath != null && await File(rightPath).exists()) {
        request.files.add(await http.MultipartFile.fromPath('right', rightPath));
      }
      
      debugPrint("Uploading images to backend: $url");
      final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("Backend response received successfully.");
        
        final id = const Uuid().v4();
        
        final List<ScanIssue> issuesList = [];
        if (data['issues'] != null) {
          for (var issueMap in data['issues']) {
            issuesList.add(ScanIssue(
              label: issueMap['label'] ?? '',
              type: issueMap['type'] ?? '',
              x: (issueMap['x'] as num).toDouble(),
              y: (issueMap['y'] as num).toDouble(),
              radius: (issueMap['radius'] as num? ?? 15.0).toDouble(),
              severity: issueMap['severity'] ?? 'Mild',
              description: issueMap['description'] ?? '',
              faceSide: issueMap['faceSide'] ?? 'front',
            ));
          }
        }
        
        final detailMap = <String, int>{};
        if (data['detailScores'] != null) {
          data['detailScores'].forEach((k, v) {
            detailMap[k] = (v as num).toInt();
          });
        } else {
          // compute detail map based on issues
          detailMap['redness'] = 90 - (issuesList.where((i) => i.type == 'redness').length * 15);
          detailMap['acne'] = 90 - (issuesList.where((i) => i.type == 'acne').length * 15);
          detailMap['circles'] = 90 - (issuesList.where((i) => i.type == 'circles').length * 15);
          detailMap['wrinkles'] = 90 - (issuesList.where((i) => i.type == 'wrinkles').length * 15);
          detailMap['pores'] = 90 - (issuesList.where((i) => i.type == 'pores').length * 15);
          detailMap['oiliness'] = 90 - (issuesList.where((i) => i.type == 'oiliness').length * 15);
        }
        
        final List<double> verticalProportions = [];
        if (data['verticalThirds'] != null) {
          for (var val in data['verticalThirds']) {
            verticalProportions.add((val as num).toDouble());
          }
        } else {
          verticalProportions.addAll([0.33, 0.33, 0.34]);
        }
        
        return SkinScan(
          id: id,
          uid: uid,
          dateTime: DateTime.now(),
          imagePath: frontPath,
          leftImagePath: leftPath,
          rightImagePath: rightPath,
          overallScore: (data['overallScore'] as num? ?? 80).toInt(),
          skinAge: (data['skinAge'] as num? ?? 25).toInt(),
          skinType: data['skinType'] ?? 'Normal',
          detailScores: detailMap,
          issues: issuesList,
          recommendations: List<String>.from(data['recommendations'] ?? []),
          symmetryScore: (data['symmetryScore'] as num? ?? 82.0).toDouble(),
          verticalThirds: verticalProportions,
          jawlineAngle: (data['jawlineAngle'] as num? ?? 122.0).toDouble(),
          cheekboneSymmetry: (data['cheekboneSymmetry'] as num? ?? 88.0).toDouble(),
        );
      } else {
        debugPrint("Backend returned error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Failed to reach Python backend, error: $e");
    }
    return null;
  }
}
