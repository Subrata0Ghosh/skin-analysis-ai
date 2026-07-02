class ScanIssue {
  final String label; // e.g. Redness, Acne, Dark Circle, Fine Lines, Enlarged Pores
  final String type; // redness, acne, circles, wrinkles, pores, oiliness
  final double x; // relative x coordinate (0.0 to 1.0)
  final double y; // relative y coordinate (0.0 to 1.0)
  final double radius; // relative overlay radius
  final String severity; // Mild, Moderate, Severe
  final String description;

  ScanIssue({
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    required this.radius,
    required this.severity,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'type': type,
      'x': x,
      'y': y,
      'radius': radius,
      'severity': severity,
      'description': description,
    };
  }

  factory ScanIssue.fromMap(Map<String, dynamic> map) {
    return ScanIssue(
      label: map['label'] ?? '',
      type: map['type'] ?? '',
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      severity: map['severity'] ?? 'Mild',
      description: map['description'] ?? '',
    );
  }
}

class SkinScan {
  final String id;
  final String uid;
  final DateTime dateTime;
  final String imagePath;
  final int overallScore; // 0 to 100 (higher is healthier)
  final int skinAge;
  final String skinType;
  final Map<String, int> detailScores; // e.g., {'redness': 85, ...}
  final List<ScanIssue> issues;
  final List<String> recommendations;

  // Qoves Aesthetics metrics
  final double symmetryScore; // 0 to 100
  final List<double> verticalThirds; // e.g. [0.33, 0.33, 0.34]
  final double jawlineAngle; // degrees, e.g. 122.5
  final double cheekboneSymmetry; // 0 to 100

  SkinScan({
    required this.id,
    required this.uid,
    required this.dateTime,
    required this.imagePath,
    required this.overallScore,
    required this.skinAge,
    required this.skinType,
    required this.detailScores,
    required this.issues,
    required this.recommendations,
    required this.symmetryScore,
    required this.verticalThirds,
    required this.jawlineAngle,
    required this.cheekboneSymmetry,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'dateTime': dateTime.toIso8601String(),
      'imagePath': imagePath,
      'overallScore': overallScore,
      'skinAge': skinAge,
      'skinType': skinType,
      'detailScores': detailScores,
      'issues': issues.map((e) => e.toMap()).toList(),
      'recommendations': recommendations,
      'symmetryScore': symmetryScore,
      'verticalThirds': verticalThirds,
      'jawlineAngle': jawlineAngle,
      'cheekboneSymmetry': cheekboneSymmetry,
    };
  }

  factory SkinScan.fromMap(Map<String, dynamic> map) {
    return SkinScan(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      dateTime: DateTime.parse(map['dateTime'] ?? DateTime.now().toIso8601String()),
      imagePath: map['imagePath'] ?? '',
      overallScore: map['overallScore'] ?? 80,
      skinAge: map['skinAge'] ?? 25,
      skinType: map['skinType'] ?? 'Normal',
      detailScores: Map<String, int>.from(map['detailScores']?.map(
            (k, v) => MapEntry<String, int>(k, v as int),
          ) ??
          {}),
      issues: List<ScanIssue>.from(
        (map['issues'] as List? ?? []).map((x) => ScanIssue.fromMap(x as Map<String, dynamic>)),
      ),
      recommendations: List<String>.from(map['recommendations'] ?? []),
      symmetryScore: (map['symmetryScore'] ?? 90.0).toDouble(),
      verticalThirds: List<double>.from((map['verticalThirds'] ?? [0.33, 0.33, 0.34]).map((x) => (x as num).toDouble())),
      jawlineAngle: (map['jawlineAngle'] ?? 122.0).toDouble(),
      cheekboneSymmetry: (map['cheekboneSymmetry'] ?? 92.0).toDouble(),
    );
  }
}
