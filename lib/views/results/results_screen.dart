import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../models/skin_scan.dart';

class ResultsScreen extends StatefulWidget {
  final SkinScan scan;

  const ResultsScreen({super.key, required this.scan});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedIssueIndex;
  final ScrollController _scrollController = ScrollController();
  
  // Qoves Aesthetics Toggle state
  bool _showAesthetics = false;
  
  // Current face profile view: 'front', 'left', or 'right'
  String _currentProfileSide = 'front';

  // Selected landmark for structure mode
  String? _selectedLandmark;

  // Selected styles for Grooming tab
  String _selectedHairStyle = 'textured_crop';
  String _selectedBeardStyle = 'boxed_beard';
  double _predictorMonths = 0.0;

  // Anatomical landmarks coordinates
  static const Map<String, List<double>> _frontLandmarks = {
    'Glabella': [0.5, 0.33],
    'Pronasale': [0.5, 0.56],
    'Subnasale': [0.5, 0.64],
    'Menton': [0.5, 0.88],
    'Exocanthion L': [0.34, 0.46],
    'Exocanthion R': [0.66, 0.46],
  };

  static const Map<String, List<double>> _leftLandmarks = {
    'Pronasale': [0.38, 0.55],
    'Subnasale': [0.42, 0.62],
    'Gonion': [0.68, 0.80],
    'Pogonium': [0.44, 0.88],
  };

  static const Map<String, List<double>> _rightLandmarks = {
    'Pronasale': [0.62, 0.55],
    'Subnasale': [0.58, 0.62],
    'Gonion': [0.32, 0.80],
    'Pogonium': [0.56, 0.88],
  };

  static const Map<String, Map<String, String>> _landmarkDetails = {
    'Glabella': {
      'name': 'Glabella (G)',
      'desc': 'The most prominent point between the eyebrows. Marks the boundary between upper and middle facial thirds.',
    },
    'Pronasale': {
      'name': 'Pronasale (Prn)',
      'desc': 'The tip of the nose. Crucial for calculating nasal projection and nasolabial balance.',
    },
    'Subnasale': {
      'name': 'Subnasale (Sn)',
      'desc': 'The point where the nose septum meets the upper lip. Key anchor for measuring the nasolabial angle.',
    },
    'Menton': {
      'name': 'Menton (Me)',
      'desc': 'The lowest point of the soft tissue chin. Used as the lower limit for vertical facial height ratios.',
    },
    'Exocanthion L': {
      'name': 'Left Exocanthion (Ex)',
      'desc': 'The outer corner of the left eye. Used to measure biocular width and assess horizontal eye balance.',
    },
    'Exocanthion R': {
      'name': 'Right Exocanthion (Ex)',
      'desc': 'The outer corner of the right eye. Used to calculate eye-spacing proportions and lateral symmetry.',
    },
    'Gonion': {
      'name': 'Gonion (Go)',
      'desc': 'The corner of the lower jaw (mandibular angle). Key landmark for jawline definition and gonial angle pitch.',
    },
    'Pogonium': {
      'name': 'Pogonium (Pg)',
      'desc': 'The most anterior projection of the chin. Essential anchor for constructing Ricketts\' Esthetic Line.',
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _activeImagePath {
    if (_currentProfileSide == 'left') {
      return widget.scan.leftImagePath ?? widget.scan.imagePath;
    } else if (_currentProfileSide == 'right') {
      return widget.scan.rightImagePath ?? widget.scan.imagePath;
    } else {
      return widget.scan.imagePath;
    }
  }

  Map<String, List<double>> get _activeLandmarks {
    if (_currentProfileSide == 'left') {
      return _leftLandmarks;
    } else if (_currentProfileSide == 'right') {
      return _rightLandmarks;
    } else {
      return _frontLandmarks;
    }
  }

  Widget _buildProfileSideBtn(String label, String side) {
    final isSelected = _currentProfileSide == side;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentProfileSide = side;
          _selectedIssueIndex = null;
          _selectedLandmark = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold.withValues(alpha: 0.15) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  void _onTapFace(TapUpDetails details, BoxConstraints constraints) {
    final double rx = details.localPosition.dx / constraints.maxWidth;
    final double ry = details.localPosition.dy / constraints.maxHeight;

    if (_showAesthetics) {
      // Find closest structural landmark
      String? closestLandmark;
      double minDistance = 9999.0;
      _activeLandmarks.forEach((key, value) {
        final dist = sqrt(pow(value[0] - rx, 2) + pow(value[1] - ry, 2));
        if (dist < 0.08 && dist < minDistance) {
          minDistance = dist;
          closestLandmark = key;
        }
      });

      setState(() {
        _selectedLandmark = closestLandmark;
      });
      return;
    }

    final sideIssues = widget.scan.issues.where((i) => i.faceSide == _currentProfileSide).toList();
    int closestIndex = -1;
    double minDistance = 9999.0;

    for (int i = 0; i < sideIssues.length; i++) {
      final issue = sideIssues[i];
      final distance = sqrt(pow(issue.x - rx, 2) + pow(issue.y - ry, 2));
      if (distance < 0.08 && distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex != -1) {
      setState(() {
        _selectedIssueIndex = closestIndex;
      });
      _tabController.animateTo(1); // Switch to "Issues" tab
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            closestIndex * 150.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      setState(() {
        _selectedIssueIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Analysis Report", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Toggle at the top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleBtn("Skin Care", !_showAesthetics, () {
                      setState(() {
                        _showAesthetics = false;
                      });
                    }),
                  ),
                  Expanded(
                    child: _buildToggleBtn("Facial Structure", _showAesthetics, () {
                      setState(() {
                        _showAesthetics = true;
                      });
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Profile View Switcher (Front, Left, Right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProfileSideBtn("Front View", "front"),
                const SizedBox(width: 8),
                _buildProfileSideBtn("Left Profile", "left"),
                const SizedBox(width: 8),
                _buildProfileSideBtn("Right Profile", "right"),
              ],
            ),
          ),

          // 1. Interactive Face Image (Top 40%)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapUp: (details) => _onTapFace(details, constraints),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Captured Face Image (Front, Left, or Right profile)
                            Positioned.fill(
                              child: _activeImagePath.startsWith('assets/')
                                  ? Image.asset(_activeImagePath, fit: BoxFit.cover)
                                  : Image.file(File(_activeImagePath), fit: BoxFit.cover),
                            ),
                            
                            // Custom Painter overlay: switch depending on toggle
                            Positioned.fill(
                              child: _showAesthetics
                                  ? CustomPaint(
                                      painter: AestheticsPainter(
                                        scan: widget.scan,
                                        profileSide: _currentProfileSide,
                                        selectedLandmark: _selectedLandmark,
                                      ),
                                    )
                                  : CustomPaint(
                                      painter: HotspotPainter(
                                        issues: widget.scan.issues
                                            .where((i) => i.faceSide == _currentProfileSide)
                                            .toList(),
                                        selectedIndex: _selectedIssueIndex,
                                      ),
                                    ),
                            ),
                            
                            // Visual hint to tap spots / view grid
                            if (_selectedLandmark == null)
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showAesthetics ? Icons.grid_3x3 : Icons.touch_app_outlined,
                                        color: AppColors.primaryGold,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _showAesthetics 
                                            ? "Tap landmarks to view anatomy details" 
                                            : "Tap highlights on image to view details", 
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Glowing landmark info tooltip card
                            if (_showAesthetics && _selectedLandmark != null)
                              Positioned(
                                left: 12,
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE60F0F16), // Dark premium glassmorphism
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.45), width: 1),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 15)
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                                                  ),
                                                  child: const Text(
                                                    "ANATOMY LANDMARK",
                                                    style: TextStyle(
                                                      color: AppColors.primaryGold,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _landmarkDetails[_selectedLandmark]?['name'] ?? '',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                                            onPressed: () {
                                              setState(() {
                                                _selectedLandmark = null;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _landmarkDetails[_selectedLandmark]?['desc'] ?? '',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Tab Bar Selector
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryGold,
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primaryGold,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                const Tab(text: "Overview"),
                Tab(text: _showAesthetics ? "Structure" : "Issues"),
                Tab(text: _showAesthetics ? "Grooming" : "Routine"),
                const Tab(text: "Time-Lapse"),
              ],
            ),
          ),

          // 2. Tab Contents (Bottom 60%)
          Expanded(
            flex: 6,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _showAesthetics ? _buildStructureTab() : _buildIssuesTab(),
                _showAesthetics ? _buildGroomingTab() : _buildRoutineTab(),
                _buildPredictorTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? AppColors.textDark : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPredictorTab() {
    // Determine simulated parameters based on months
    int projectedScore = widget.scan.overallScore;
    double projectedSymmetry = widget.scan.symmetryScore;
    String phaseTitle = "Baseline State";
    String phaseDesc = " skincells have not yet begun the routine treatment cycle.";
    List<String> outcomes = [
      "Acne & Redness: Baseline blemishes active.",
      "Facial Tone: Mandibular posture untrained.",
      "Moisture: Epidermal hydration at normal levels."
    ];

    if (_predictorMonths >= 12.0) {
      projectedScore = min(98, (widget.scan.overallScore * 1.2).toInt());
      projectedSymmetry = min(99.0, widget.scan.symmetryScore + 4.8);
      phaseTitle = "Dermal Optimization Phase";
      phaseDesc = "Skincell regeneration has optimized collagen fibers, resolving surface concerns and raising jaw definition.";
      outcomes = [
        "Acne & Redness: 98% reduction. Scarring risk minimized.",
        "Facial Tone: Jaw alignment drills increased submandibular tone by 14%.",
        "Moisture: Skin barrier moisture retention maximized, skin age reduced by 2 years."
      ];
    } else if (_predictorMonths >= 6.0) {
      projectedScore = min(94, (widget.scan.overallScore * 1.12).toInt());
      projectedSymmetry = min(99.0, widget.scan.symmetryScore + 2.5);
      phaseTitle = "Cellular Consistency Phase";
      phaseDesc = "Regular niacinamide and hydration routines have faded redness and pigmentation by 60%.";
      outcomes = [
        "Acne & Redness: Redness reduced by 60%. Breakouts highly suppressed.",
        "Facial Tone: Mewing posture has defined the chin-to-neck profile axis.",
        "Moisture: Hyaluronic layers have filled out superficial fine lines."
      ];
    } else if (_predictorMonths >= 3.0) {
      projectedScore = min(90, (widget.scan.overallScore * 1.05).toInt());
      projectedSymmetry = min(99.0, widget.scan.symmetryScore + 1.0);
      phaseTitle = "Early Adaption Phase";
      phaseDesc = "Skin begins showing signs of moisture balance. Active breakouts are starting to resolve.";
      outcomes = [
        "Acne & Redness: Active acne nodes starting to dry out.",
        "Facial Tone: Posture awareness fixes forward-neck slouching.",
        "Moisture: Increased softness and suppleness noted on the cheeks."
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time-Lapse Painter view
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Stylized outline face and fading blemish nodes
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PredictorFacePainter(
                        months: _predictorMonths,
                        issues: widget.scan.issues.where((i) => i.faceSide == _currentProfileSide).toList(),
                        side: _currentProfileSide,
                      ),
                    ),
                  ),

                  // Overlay score predictions
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Score: $projectedScore/100",
                            style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          Text(
                            "Symmetry: ${projectedSymmetry.toStringAsFixed(1)}%",
                            style: const TextStyle(color: AppColors.accentSage, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Slider
          Text(
            "Routine Timeline: ${_predictorMonths.toInt()} Months",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Slider.adaptive(
            value: _predictorMonths,
            min: 0.0,
            max: 12.0,
            divisions: 4,
            activeColor: AppColors.primaryGold,
            inactiveColor: AppColors.border,
            onChanged: (val) {
              setState(() {
                // snap to 0, 3, 6, 12
                if (val < 1.5) {
                  _predictorMonths = 0.0;
                } else if (val < 4.5) {
                  _predictorMonths = 3.0;
                } else if (val < 9.0) {
                  _predictorMonths = 6.0;
                } else {
                  _predictorMonths = 12.0;
                }
              });
            },
          ),
          // Months Labels Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Day 0", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                Text("Month 3", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                Text("Month 6", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                Text("Month 12", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Prediction Report Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: AppColors.primaryGold, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      phaseTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  phaseDesc,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 12),
                ...outcomes.map((outcome) {
                  final parts = outcome.split(':');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.accentSage, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.35),
                              children: [
                                TextSpan(text: "${parts[0]}: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                TextSpan(text: parts.length > 1 ? parts[1] : ""),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Overview
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Double score card: Skin vs Symmetry
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Skin Score", style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "${widget.scan.overallScore}",
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                          ),
                          const Text("/100", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Facial Symmetry", style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            widget.scan.symmetryScore.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.accentSage),
                          ),
                          const Text("%", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Diagnostic Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryGold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _showAesthetics 
                        ? "Facial thirds exhibit balanced vertical proportions (${(widget.scan.verticalThirds[1]*100).toStringAsFixed(1)}% mid-face). Mandibular angle lies at ${widget.scan.jawlineAngle.toStringAsFixed(1)}°, consistent with ideal anatomical projections."
                        : "Current skin state matches a '${widget.scan.skinType}' profile. Localized redness detected on cheek coordinates, with mild T-zone shine. Formulating protective barriers.",
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Metrics breakdown
          Text(_showAesthetics ? "Structural Metrics" : "Skin Metrics", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_showAesthetics) ...[
            _buildMetricBar("FACIAL SYMMETRY", widget.scan.symmetryScore, AppColors.accentSage),
            _buildMetricBar("CHEEKBONE SYMMETRY", widget.scan.cheekboneSymmetry, AppColors.accentSage),
            _buildMetricBar("JAWLINE DEFINITION", 88.0, AppColors.primaryGold),
          ] else ...[
            ...widget.scan.detailScores.entries.map((entry) {
              String label = entry.key.toUpperCase();
              if (label == 'CIRCLES') label = 'DARK CIRCLES';
              if (label == 'REDNESS') label = 'REDNESS / IRRITATION';
              if (label == 'ACNE') label = 'ACNE / BREAKOUTS';
              if (label == 'WRINKLES') label = 'FINE LINES / WRINKLES';

              Color progressColor = AppColors.primaryGold;
              if (entry.value < 60) {
                progressColor = AppColors.diagnosticRedness;
              } else if (entry.value < 80) {
                progressColor = AppColors.diagnosticAcne;
              } else {
                progressColor = AppColors.accentSage;
              }
              return _buildMetricBar(label, entry.value.toDouble(), progressColor);
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildMetricBar(String label, double val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("${val.toStringAsFixed(1)}%", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: val / 100,
              minHeight: 5,
              backgroundColor: AppColors.border,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Issues List
  Widget _buildIssuesTab() {
    final issues = widget.scan.issues.where((i) => i.faceSide == _currentProfileSide).toList();
    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.face_retouching_natural_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text(
              "No issues detected",
              style: TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Skin area is healthy and well-balanced.",
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24.0),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        final isSelected = _selectedIssueIndex == index;

        Color severityColor = AppColors.severityMild;
        if (issue.severity == 'Severe') {
          severityColor = AppColors.severitySevere;
        } else if (issue.severity == 'Moderate') {
          severityColor = AppColors.severityModerate;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.cardBgSecondary : AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryGold : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: _getDiagnosticColor(issue.type).withValues(alpha: 0.12),
              child: Icon(
                _getDiagnosticIcon(issue.type),
                color: _getDiagnosticColor(issue.type),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(issue.label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    issue.severity,
                    style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                issue.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
            onTap: () {
              setState(() {
                _selectedIssueIndex = index;
              });
            },
          ),
        );
      },
    );
  }

  // TAB 2 (AESTHETICS ALTERNATE): Qoves Structure breakdown
  Widget _buildStructureTab() {
    if (_currentProfileSide != 'front') {
      // Profile side aesthetic metrics
      final nasolabialVal = 98.0 + (widget.scan.jawlineAngle % 12);
      final hasIdealEline = (widget.scan.cheekboneSymmetry > 90);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "PROFILE ANGLE ANALYSIS",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            
            // Mandibular & Nasolabial Angle Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.architecture_outlined, color: AppColors.primaryGold, size: 20),
                        const SizedBox(height: 8),
                        const Text("Gonial Angle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.scan.jawlineAngle.toStringAsFixed(1)}°",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                        ),
                        const SizedBox(height: 4),
                        const Text("Target: 115° - 130°", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.change_history_rounded, color: AppColors.accentSage, size: 20),
                        const SizedBox(height: 8),
                        const Text("Nasolabial", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          "${nasolabialVal.toStringAsFixed(1)}°",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accentSage),
                        ),
                        const SizedBox(height: 4),
                        const Text("Target: 95° - 110°", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ricketts' Esthetic Line assessment card
            Container(
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
                    children: [
                      const Icon(Icons.linear_scale_rounded, color: AppColors.primaryGold, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Ricketts' Esthetic Line (E-Line)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasIdealEline
                        ? "Ideal lower facial projection detected. Upper and lower lips lie in perfect harmony behind the nose-to-chin aesthetic axis (-4mm / -2mm)."
                        : "Mild chin retrusion or lip prominence relative to the E-line axis. Standard facial profile phenotype with high bone structure balance.",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical Thirds Breakdown
          const Text("VERTICAL FACIAL THIRDS BALANCE", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildThirdsBar("Upper Third (Forehead)", widget.scan.verticalThirds[0]),
                const SizedBox(height: 12),
                _buildThirdsBar("Middle Third (Eyes/Nose)", widget.scan.verticalThirds[1]),
                const SizedBox(height: 12),
                _buildThirdsBar("Lower Third (Nose/Chin)", widget.scan.verticalThirds[2]),
                const SizedBox(height: 16),
                const Text(
                  "Ideal vertical proportions lie at 1:1:1 (33.3% each). Minor deviations indicate unique ethnic phenotypes and have no impact on structural attractiveness.",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.3),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Jawline and cheekbone details
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.architecture_outlined, color: AppColors.primaryGold, size: 20),
                      const SizedBox(height: 8),
                      const Text("Mandibular Angle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.scan.jawlineAngle.toStringAsFixed(1)}°",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                      ),
                      const SizedBox(height: 4),
                      const Text("Target: 115° - 130°", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.face_unlock_outlined, color: AppColors.accentSage, size: 20),
                      const SizedBox(height: 8),
                      const Text("Zygomatic Arch", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.scan.cheekboneSymmetry.toStringAsFixed(1)}%",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accentSage),
                      ),
                      const SizedBox(height: 4),
                      const Text("Symmetry: High", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildThirdsBar(String label, double ratio) {
    final double pct = ratio * 100;
    // Highlight if close to 33.3%
    final isBalanced = (pct - 33.3).abs() < 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            Text(
              "${pct.toStringAsFixed(1)}%",
              style: TextStyle(
                color: isBalanced ? AppColors.accentSage : AppColors.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio * 2.5, // Scale so 33% fills most of the bar
            minHeight: 5,
            backgroundColor: AppColors.border,
            color: isBalanced ? AppColors.accentSage : AppColors.primaryGold,
          ),
        ),
      ],
    );
  }

  // TAB 3: Recommendations / Skincare Routine
  Widget _buildRoutineTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: widget.scan.recommendations.length,
      itemBuilder: (context, index) {
        final rec = widget.scan.recommendations[index];
        final parts = rec.split(":");
        final title = parts.isNotEmpty ? parts[0] : "Routine Step";
        final description = parts.length > 1 ? parts[1].trim() : "";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.primaryGold),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3 (AESTHETICS ALTERNATE): Qoves Grooming & AI Style Simulator
  Widget _buildGroomingTab() {
    // 1. Calculate dynamic compatibility
    int score = 80;
    String rational = "";

    final foreheadRatio = widget.scan.verticalThirds[0];
    final jawAngle = widget.scan.jawlineAngle;

    if (_selectedHairStyle == 'textured_crop') {
      if (foreheadRatio > 0.33) {
        score += 12;
        rational += "• The Textured Crop fringe covers your forehead (which has a high ${ (foreheadRatio * 100).toStringAsFixed(1) }% ratio), instantly balancing your vertical thirds. ";
      } else {
        score += 6;
        rational += "• The Textured Crop fringe gives a youthful look, matching well with your balanced upper third. ";
      }
    } else if (_selectedHairStyle == 'quiff') {
      if (foreheadRatio < 0.33) {
        score += 15;
        rational += "• The Voluminous Quiff adds vertical length, perfect for elongating your shorter forehead ratio. ";
      } else {
        score -= 5;
        rational += "• The vertical volume of the Quiff may visually elongate your forehead further, slightly skewing thirds proportions. ";
      }
    } else if (_selectedHairStyle == 'buzz') {
      if (widget.scan.cheekboneSymmetry > 90) {
        score += 14;
        rational += "• Your high cheekbone symmetry (${ widget.scan.cheekboneSymmetry.toStringAsFixed(1) }%) is the perfect canvas for a Buzz Cut, exposing strong facial bones. ";
      } else {
        score += 4;
        rational += "• A clean Buzz Cut offers a low-maintenance, masculine look but highlights minor asymmetry. ";
      }
    } else if (_selectedHairStyle == 'slick_back') {
      if (jawAngle < 122) {
        score += 13;
        rational += "• Slicked Back styles pull hair away, drawing maximum focus to your strong, sharp jawline. ";
      } else {
        score += 7;
        rational += "• A classic Slicked Back style gives a polished, professional look. ";
      }
    }

    if (_selectedBeardStyle == 'clean') {
      if (jawAngle < 120) {
        score += 8;
        rational += "\n• A Clean Shave highlights your sharp, athletic jawline angle (${ jawAngle.toStringAsFixed(1) }°) beautifully.";
      } else {
        score -= 6;
        rational += "\n• A Clean Shave leaves your softer jaw outline exposed; a light shadow could add more structure.";
      }
    } else if (_selectedBeardStyle == 'stubble') {
      score += 7;
      rational += "\n• Short Stubble darkens the jaw borders, creating a sharp shadow that complements your face shape.";
    } else if (_selectedBeardStyle == 'boxed_beard') {
      if (jawAngle >= 120) {
        score += 10;
        rational += "\n• The Structured Boxed Beard is highly recommended; it builds projection and squarish definition for your softer mandibular pitch.";
      } else {
        score += 5;
        rational += "\n• The Boxed Beard adds a robust frame, maintaining facial balance.";
      }
    } else if (_selectedBeardStyle == 'heavy_beard') {
      if (widget.scan.cheekboneSymmetry > 92) {
        score += 3;
        rational += "\n• A Full Beard adds significant mass, but might obscure your excellent zygomatic arch definition.";
      } else {
        score += 8;
        rational += "\n• A Full Beard adds maximum lower third volume, balancing out the facial profile.";
      }
    }

    if (score > 100) score = 100;
    if (score < 40) score = 40;

    final List<Map<String, String>> exercises = [
      {
        'title': 'Mewing (Tongue Posture)',
        'desc': 'Keep your teeth closed gently, and press the entire tongue flat against the roof of the mouth. Restructures the jaw arch and tones submandibular muscle.'
      },
      {
        'title': 'Gua Sha Lymphatic Sweep',
        'desc': 'Hold quartz scraper flat at 15°. Slide upwards from chin to earlobes, then sweep down along your neck side. Expels toxins, reducing mid-face puffiness.'
      },
      {
        'title': 'Cheekbone Muscle Lifts',
        'desc': 'Smile widely, placing fingers on cheek peaks. Lift cheeks upwards towards the eyes, holding for 5s. Firms zygomatic arches.'
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "AI STYLE SIMULATOR & ADVISOR",
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1),
          ),
          const SizedBox(height: 14),

          // Hairstyle Selection Row
          const Text("Select Hairstyle", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStylePill("Textured Crop", "textured_crop", true),
                _buildStylePill("Textured Quiff", "quiff", true),
                _buildStylePill("Buzz Cut", "buzz", true),
                _buildStylePill("Slicked Back", "slick_back", true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Beard Style Selection Row
          const Text("Select Beard / Shave", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStylePill("Clean Shaven", "clean", false),
                _buildStylePill("Light Stubble", "stubble", false),
                _buildStylePill("Boxed Beard", "boxed_beard", false),
                _buildStylePill("Full Beard", "heavy_beard", false),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Compatibility & Rationales card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151522),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "STYLE COMPATIBILITY",
                      style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$score% MATCH",
                        style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100.0,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    color: AppColors.primaryGold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "AI Stylist Breakdown:",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  rational,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Toning exercises section
          const Text(
            "BONE STRUCTURE TONING TIPS",
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          ...exercises.map((ex) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fitness_center_outlined, color: AppColors.accentSage, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex['title']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ex['desc']!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStylePill(String title, String key, bool isHair) {
    final bool isSelected = isHair ? (_selectedHairStyle == key) : (_selectedBeardStyle == key);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isHair) {
              _selectedHairStyle = key;
            } else {
              _selectedBeardStyle = key;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGold.withValues(alpha: 0.15) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryGold : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Color _getDiagnosticColor(String type) {
    switch (type) {
      case 'redness':
        return AppColors.diagnosticRedness;
      case 'acne':
        return AppColors.diagnosticAcne;
      case 'circles':
        return AppColors.diagnosticCircles;
      case 'wrinkles':
        return AppColors.diagnosticWrinkles;
      case 'oiliness':
        return AppColors.diagnosticOiliness;
      default:
        return AppColors.primaryGold;
    }
  }

  IconData _getDiagnosticIcon(String type) {
    switch (type) {
      case 'redness':
        return Icons.healing_outlined;
      case 'acne':
        return Icons.brightness_low_outlined;
      case 'circles':
        return Icons.remove_red_eye_outlined;
      case 'wrinkles':
        return Icons.waves_outlined;
      case 'oiliness':
        return Icons.water_drop_outlined;
      default:
        return Icons.spa_outlined;
    }
  }
}

// Custom Painter to draw diagnostic hotspots
class HotspotPainter extends CustomPainter {
  final List<ScanIssue> issues;
  final int? selectedIndex;

  HotspotPainter({required this.issues, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < issues.length; i++) {
      final issue = issues[i];
      final isSelected = selectedIndex == i;

      final double cx = issue.x * w;
      final double cy = issue.y * h;
      final double r = issue.radius * w;

      final color = _getDiagnosticColor(issue.type);
      
      final overlayPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.35 : 0.18)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 1.0 : 0.7)
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(cx, cy), r, overlayPaint);
      canvas.drawCircle(Offset(cx, cy), r, borderPaint);

      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), isSelected ? 4.0 : 3.0, centerPaint);
    }
  }

  Color _getDiagnosticColor(String type) {
    switch (type) {
      case 'redness':
        return AppColors.diagnosticRedness;
      case 'acne':
        return AppColors.diagnosticAcne;
      case 'circles':
        return AppColors.diagnosticCircles;
      case 'wrinkles':
        return AppColors.diagnosticWrinkles;
      case 'oiliness':
        return AppColors.diagnosticOiliness;
      default:
        return AppColors.primaryGold;
    }
  }

  @override
  bool shouldRepaint(covariant HotspotPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.issues != issues;
  }
}

// Qoves aesthetics custom wireframe grid painter
class AestheticsPainter extends CustomPainter {
  final SkinScan scan;
  final String profileSide;
  final String? selectedLandmark;

  AestheticsPainter({
    required this.scan,
    required this.profileSide,
    this.selectedLandmark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final goldPaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.65)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: AppColors.primaryGold,
      fontSize: 9,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.black54,
    );

    // Profile Side Specific Painting
    if (profileSide == 'left') {
      // 1. Gonial Angle (Jaw contour)
      final gonion = Offset(w * 0.68, h * 0.80);
      final menton = Offset(w * 0.44, h * 0.88);
      final ramusTop = Offset(w * 0.72, h * 0.58);
      canvas.drawLine(ramusTop, gonion, goldPaint);
      canvas.drawLine(gonion, menton, goldPaint);
      _drawText(canvas, Offset(w * 0.56, h * 0.81), "GONIAL: ${scan.jawlineAngle.toStringAsFixed(1)}°", textStyle);

      // 2. Ricketts' Esthetic Line (E-Line)
      final noseTip = Offset(w * 0.38, h * 0.55);
      _drawDashedLine(canvas, noseTip, menton, dashPaint);
      _drawText(canvas, Offset(w * 0.28, h * 0.72), "E-LINE", textStyle);

      // 3. Nasolabial Angle
      final subnasale = Offset(w * 0.42, h * 0.62);
      final lipAnchor = Offset(w * 0.41, h * 0.67);
      canvas.drawLine(noseTip, subnasale, goldPaint);
      canvas.drawLine(subnasale, lipAnchor, goldPaint);
      final nasolabialVal = 98.0 + (scan.jawlineAngle % 12);
      _drawText(canvas, Offset(w * 0.44, h * 0.62), "NASOLABIAL: ${nasolabialVal.toStringAsFixed(1)}°", textStyle);

    } else if (profileSide == 'right') {
      // Flipped Left Profile
      final gonion = Offset(w * 0.32, h * 0.80);
      final menton = Offset(w * 0.56, h * 0.88);
      final ramusTop = Offset(w * 0.28, h * 0.58);
      canvas.drawLine(ramusTop, gonion, goldPaint);
      canvas.drawLine(gonion, menton, goldPaint);
      _drawText(canvas, Offset(w * 0.32, h * 0.81), "GONIAL: ${scan.jawlineAngle.toStringAsFixed(1)}°", textStyle);

      // Ricketts' E-Line
      final noseTip = Offset(w * 0.62, h * 0.55);
      _drawDashedLine(canvas, noseTip, menton, dashPaint);
      _drawText(canvas, Offset(w * 0.60, h * 0.72), "E-LINE", textStyle);

      // Nasolabial Angle
      final subnasale = Offset(w * 0.58, h * 0.62);
      final lipAnchor = Offset(w * 0.59, h * 0.67);
      canvas.drawLine(noseTip, subnasale, goldPaint);
      canvas.drawLine(subnasale, lipAnchor, goldPaint);
      final nasolabialVal = 98.0 + (scan.jawlineAngle % 12);
      _drawText(canvas, Offset(w * 0.44, h * 0.62), "NASOLABIAL: ${nasolabialVal.toStringAsFixed(1)}°", textStyle);

    } else {
      // Front View - original vertical thirds
      _drawDashedLine(canvas, Offset(w * 0.5, 0), Offset(w * 0.5, h), dashPaint);
      _drawDashedLine(canvas, Offset(0, h * 0.46), Offset(w, h * 0.46), dashPaint);
      canvas.drawCircle(Offset(w * 0.34, h * 0.46), 6, goldPaint);
      canvas.drawCircle(Offset(w * 0.66, h * 0.46), 6, goldPaint);

      final double yBrow = h * 0.33;
      final double yNose = h * 0.64;
      final double yChin = h * 0.88;
      canvas.drawLine(Offset(0, yBrow), Offset(w, yBrow), goldPaint);
      canvas.drawLine(Offset(0, yNose), Offset(w, yNose), goldPaint);
      canvas.drawLine(Offset(0, yChin), Offset(w, yChin), goldPaint);

      _drawText(canvas, Offset(8, yBrow - 14), "UPPER THIRD: ${(scan.verticalThirds[0]*100).toStringAsFixed(1)}%", textStyle);
      _drawText(canvas, Offset(8, yNose - 14), "MID THIRD: ${(scan.verticalThirds[1]*100).toStringAsFixed(1)}%", textStyle);
      _drawText(canvas, Offset(8, yChin - 14), "LOWER THIRD: ${(scan.verticalThirds[2]*100).toStringAsFixed(1)}%", textStyle);

      final jawLeftStart = Offset(w * 0.22, h * 0.55);
      final jawLeftCorner = Offset(w * 0.28, h * 0.78);
      final jawLeftChin = Offset(w * 0.5, yChin);
      canvas.drawLine(jawLeftStart, jawLeftCorner, goldPaint);
      canvas.drawLine(jawLeftCorner, jawLeftChin, goldPaint);

      final jawRightStart = Offset(w * 0.78, h * 0.55);
      final jawRightCorner = Offset(w * 0.72, h * 0.78);
      canvas.drawLine(jawRightStart, jawRightCorner, goldPaint);
      canvas.drawLine(jawRightCorner, jawLeftChin, goldPaint);

      _drawText(canvas, Offset(w * 0.16, h * 0.81), "JAW: ${scan.jawlineAngle.toStringAsFixed(1)}°", textStyle);
      _drawText(canvas, Offset(w * 0.62, h * 0.81), "JAW: ${scan.jawlineAngle.toStringAsFixed(1)}°", textStyle);
    }

    // --------------------------------------------------
    // DRAW ANATOMY LANDMARK NODES (GLOWING GOLD DOTS)
    // --------------------------------------------------
    final Map<String, List<double>> landmarks = (profileSide == 'left')
        ? _ResultsScreenState._leftLandmarks
        : (profileSide == 'right')
            ? _ResultsScreenState._rightLandmarks
            : _ResultsScreenState._frontLandmarks;

    landmarks.forEach((name, coords) {
      final double cx = coords[0] * w;
      final double cy = coords[1] * h;
      final isSelected = selectedLandmark == name;

      final dotPaint = Paint()
        ..color = AppColors.primaryGold
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = AppColors.primaryGold.withValues(alpha: isSelected ? 0.45 : 0.2)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), isSelected ? 12.0 : 7.0, glowPaint);
      canvas.drawCircle(Offset(cx, cy), isSelected ? 4.5 : 3.0, dotPaint);

      if (isSelected) {
        final ringPaint = Paint()
          ..color = AppColors.primaryGold
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(cx, cy), 12.0, ringPaint);
      }
    });
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 5;
    const double dashSpace = 4;
    double distance = (end - start).distance;
    final Offset direction = (end - start) / distance;
    double currentDistance = 0;
    while (currentDistance < distance) {
      canvas.drawLine(
        start + direction * currentDistance,
        start + direction * (currentDistance + dashWidth),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawText(Canvas canvas, Offset offset, String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant AestheticsPainter oldDelegate) {
    return oldDelegate.profileSide != profileSide || oldDelegate.selectedLandmark != selectedLandmark;
  }
}

// Custom Painter to render predicted time-lapse face changes
class PredictorFacePainter extends CustomPainter {
  final double months;
  final List<ScanIssue> issues;
  final String side;

  PredictorFacePainter({required this.months, required this.issues, required this.side});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fading multiplier for skin issues
    final double fadeFactor = ((12.0 - months) / 12.0).clamp(0.0, 1.0);

    // Mandibular definition multiplier (jaw line tightens up slightly as months increase)
    final double definitionOffset = (months / 12.0) * 8.0;

    final wireframePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final activeWireframePaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.5 + (months / 12.0) * 0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 1. Draw Abstract Face Wireframe Contour based on side
    if (side == 'left') {
      // Left side outline profile
      final Path path = Path();
      path.moveTo(w * 0.50, h * 0.15); // Forehead top
      path.quadraticBezierTo(w * 0.38, h * 0.28, w * 0.40, h * 0.40); // Brow bridge
      path.lineTo(w * 0.30, h * 0.54); // Nose tip
      path.lineTo(w * 0.40, h * 0.58); // Nasolabial hook
      path.quadraticBezierTo(w * 0.36, h * 0.68, w * 0.41, h * 0.74); // Lips
      // Chin - tightens up by definitionOffset
      final chinX = w * 0.43 - (definitionOffset * 0.3);
      final chinY = h * 0.85 - (definitionOffset * 0.2);
      path.lineTo(chinX, chinY); 
      // Gonion / Jaw corner - tightens up
      final gonionX = w * 0.66 + (definitionOffset * 0.4);
      final gonionY = h * 0.80 - (definitionOffset * 0.5);
      path.lineTo(gonionX, gonionY);
      path.lineTo(w * 0.70, h * 0.48); // Ear line

      canvas.drawPath(path, activeWireframePaint);

      // Draw dashed horizontal alignment lines
      canvas.drawLine(Offset(0, h * 0.54), Offset(w, h * 0.54), wireframePaint);
      canvas.drawLine(Offset(0, chinY), Offset(w, chinY), wireframePaint);

    } else if (side == 'right') {
      // Right side outline profile (mirror of left)
      final Path path = Path();
      path.moveTo(w * 0.50, h * 0.15); // Forehead top
      path.quadraticBezierTo(w * 0.62, h * 0.28, w * 0.60, h * 0.40); // Brow bridge
      path.lineTo(w * 0.70, h * 0.54); // Nose tip
      path.lineTo(w * 0.60, h * 0.58); // Nasolabial hook
      path.quadraticBezierTo(w * 0.64, h * 0.68, w * 0.59, h * 0.74); // Lips
      // Chin - tightens up by definitionOffset
      final chinX = w * 0.57 + (definitionOffset * 0.3);
      final chinY = h * 0.85 - (definitionOffset * 0.2);
      path.lineTo(chinX, chinY); 
      // Gonion / Jaw corner - tightens up
      final gonionX = w * 0.34 - (definitionOffset * 0.4);
      final gonionY = h * 0.80 - (definitionOffset * 0.5);
      path.lineTo(gonionX, gonionY);
      path.lineTo(w * 0.30, h * 0.48); // Ear line

      canvas.drawPath(path, activeWireframePaint);

      canvas.drawLine(Offset(0, h * 0.54), Offset(w, h * 0.54), wireframePaint);
      canvas.drawLine(Offset(0, chinY), Offset(w, chinY), wireframePaint);

    } else {
      // Front View Face Outline
      final Path path = Path();
      // Left cheek and jaw
      path.moveTo(w * 0.50, h * 0.12);
      path.cubicTo(w * 0.22, h * 0.12, w * 0.22, h * 0.55, w * 0.26, h * 0.72);
      // Chin - rises slightly with training
      final chinY = h * 0.88 - (definitionOffset * 0.3);
      path.quadraticBezierTo(w * 0.28, h * 0.84, w * 0.50, chinY);
      // Right cheek and jaw
      path.quadraticBezierTo(w * 0.72, h * 0.84, w * 0.74, h * 0.72);
      path.cubicTo(w * 0.78, h * 0.55, w * 0.78, h * 0.12, w * 0.50, h * 0.12);
      canvas.drawPath(path, activeWireframePaint);

      // Facial Thirds horizontal bars
      canvas.drawLine(Offset(0, h * 0.35), Offset(w, h * 0.35), wireframePaint);
      canvas.drawLine(Offset(0, h * 0.65), Offset(w, h * 0.65), wireframePaint);

      // Symmetry axis line
      canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), wireframePaint);
    }

    // 2. Draw Fading Blemish Hotspots
    if (fadeFactor > 0.0) {
      for (var issue in issues) {
        final double cx = issue.x * w;
        final double cy = issue.y * h;
        final double r = issue.radius * w;

        final Color baseColor = _getDiagnosticColor(issue.type);
        
        final overlayPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.16 * fadeFactor)
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.65 * fadeFactor)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset(cx, cy), r, overlayPaint);
        canvas.drawCircle(Offset(cx, cy), r, borderPaint);
      }
    }
  }

  Color _getDiagnosticColor(String type) {
    switch (type) {
      case 'redness':
        return AppColors.diagnosticRedness;
      case 'acne':
        return AppColors.diagnosticAcne;
      case 'circles':
        return AppColors.diagnosticCircles;
      case 'wrinkles':
        return AppColors.diagnosticWrinkles;
      case 'oiliness':
        return AppColors.diagnosticOiliness;
      default:
        return AppColors.primaryGold;
    }
  }

  @override
  bool shouldRepaint(covariant PredictorFacePainter oldDelegate) {
    return oldDelegate.months != months || oldDelegate.side != side || oldDelegate.issues != issues;
  }
}
