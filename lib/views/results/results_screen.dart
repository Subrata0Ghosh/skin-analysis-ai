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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTapFace(TapUpDetails details, BoxConstraints constraints) {
    if (_showAesthetics) return; // Hotspots only interact in Skin Care mode

    final double rx = details.localPosition.dx / constraints.maxWidth;
    final double ry = details.localPosition.dy / constraints.maxHeight;

    int closestIndex = -1;
    double minDistance = 9999.0;

    for (int i = 0; i < widget.scan.issues.length; i++) {
      final issue = widget.scan.issues[i];
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
                            // Captured Face Image
                            Positioned.fill(
                              child: widget.scan.imagePath.startsWith('assets/')
                                  ? Image.asset(widget.scan.imagePath, fit: BoxFit.cover)
                                  : Image.file(File(widget.scan.imagePath), fit: BoxFit.cover),
                            ),
                            
                            // Custom Painter overlay: switch depending on toggle
                            Positioned.fill(
                              child: _showAesthetics
                                  ? CustomPaint(
                                      painter: AestheticsPainter(scan: widget.scan),
                                    )
                                  : CustomPaint(
                                      painter: HotspotPainter(
                                        issues: widget.scan.issues,
                                        selectedIndex: _selectedIssueIndex,
                                      ),
                                    ),
                            ),
                            
                            // Visual hint to tap spots / view grid
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
                                          ? "Symmetry & proportion grid active" 
                                          : "Tap highlights on image to view details", 
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
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
                Tab(text: _showAesthetics ? "Sculpting" : "Routine"),
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
                _showAesthetics ? _buildSculptingTab() : _buildRoutineTab(),
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
    final issues = widget.scan.issues;
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

  // TAB 3 (AESTHETICS ALTERNATE): Qoves Sculpting / Face Toning Routine
  Widget _buildSculptingTab() {
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
      {
        'title': 'Forward Head Posture Fix',
        'desc': 'Roll shoulders back, tuck chin inwards (creating double-chin position) and hold 5s. Re-aligns cervical spine to resolve jaw sagging.'
      }
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fitness_center_outlined, color: AppColors.accentSage, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise['title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise['desc']!,
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

  AestheticsPainter({required this.scan});

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

    // 1. Draw Sagittal Facial Midline (Vertical dotted line representation)
    _drawDashedLine(canvas, Offset(w * 0.5, 0), Offset(w * 0.5, h), dashPaint);

    // 2. Draw Horizontal eye level alignment axis (y = 0.46)
    _drawDashedLine(canvas, Offset(0, h * 0.46), Offset(w, h * 0.46), dashPaint);
    // Eye landmarks indicators
    canvas.drawCircle(Offset(w * 0.34, h * 0.46), 6, goldPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.46), 6, goldPaint);

    // 3. Draw Vertical Thirds (Hairline, Brows y=0.33, Nose y=0.64, Chin y=0.88)
    final double yBrow = h * 0.33;
    final double yNose = h * 0.64;
    final double yChin = h * 0.88;

    canvas.drawLine(Offset(0, yBrow), Offset(w, yBrow), goldPaint);
    canvas.drawLine(Offset(0, yNose), Offset(w, yNose), goldPaint);
    canvas.drawLine(Offset(0, yChin), Offset(w, yChin), goldPaint);

    // Ratios labels text
    final textStyle = TextStyle(
      color: AppColors.primaryGold,
      fontSize: 9,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.black54,
    );

    _drawText(canvas, Offset(8, yBrow - 14), "UPPER THIRD: ${(scan.verticalThirds[0]*100).toStringAsFixed(1)}%", textStyle);
    _drawText(canvas, Offset(8, yNose - 14), "MID THIRD: ${(scan.verticalThirds[1]*100).toStringAsFixed(1)}%", textStyle);
    _drawText(canvas, Offset(8, yChin - 14), "LOWER THIRD: ${(scan.verticalThirds[2]*100).toStringAsFixed(1)}%", textStyle);

    // 4. Draw Mandibular Jawline Angle wireframe contour
    // Left jaw outline
    final jawLeftStart = Offset(w * 0.22, h * 0.55);
    final jawLeftCorner = Offset(w * 0.28, h * 0.78);
    final jawLeftChin = Offset(w * 0.5, yChin);
    canvas.drawLine(jawLeftStart, jawLeftCorner, goldPaint);
    canvas.drawLine(jawLeftCorner, jawLeftChin, goldPaint);

    // Right jaw outline
    final jawRightStart = Offset(w * 0.78, h * 0.55);
    final jawRightCorner = Offset(w * 0.72, h * 0.78);
    canvas.drawLine(jawRightStart, jawRightCorner, goldPaint);
    canvas.drawLine(jawRightCorner, jawLeftChin, goldPaint);

    // Draw Jawline Angle Label text
    _drawText(canvas, Offset(w * 0.16, h * 0.81), "JAW: ${scan.jawlineAngle.toStringAsFixed(1)}°", textStyle);
    _drawText(canvas, Offset(w * 0.62, h * 0.81), "JAW: ${scan.jawlineAngle.toStringAsFixed(1)}°", textStyle);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
