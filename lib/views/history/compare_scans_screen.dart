import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../models/skin_scan.dart';

class CompareScansScreen extends StatefulWidget {
  final List<SkinScan> scans;

  const CompareScansScreen({super.key, required this.scans});

  @override
  State<CompareScansScreen> createState() => _CompareScansScreenState();
}

class _CompareScansScreenState extends State<CompareScansScreen> {
  late SkinScan _scanBefore;
  late SkinScan _scanAfter;
  double _swipeRatio = 0.5;

  @override
  void initState() {
    super.initState();
    // Default: Before is oldest scan, After is latest scan
    final sorted = List<SkinScan>.from(widget.scans)..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _scanBefore = sorted.first;
    _scanAfter = sorted.last;
  }

  @override
  Widget build(BuildContext context) {
    final beforeDate = DateFormat('MMM dd, yyyy').format(_scanBefore.dateTime);
    final afterDate = DateFormat('MMM dd, yyyy').format(_scanAfter.dateTime);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Scan Comparison", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown Pickers for Before / After
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Before", style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _buildScanDropdown(
                        selectedScan: _scanBefore,
                        onChanged: (scan) {
                          if (scan != null) {
                            setState(() {
                              _scanBefore = scan;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("After", style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      _buildScanDropdown(
                        selectedScan: _scanAfter,
                        onChanged: (scan) {
                          if (scan != null) {
                            setState(() {
                              _scanAfter = scan;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Visual Swipe Comparison Slider Card
            Container(
              height: 380,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final double width = constraints.maxWidth;
                      setState(() {
                        _swipeRatio = (details.localPosition.dx / width).clamp(0.0, 1.0);
                      });
                    },
                    child: Stack(
                      children: [
                        // Image A (Before) - Fills background
                        Positioned.fill(
                          child: _scanBefore.imagePath.startsWith('assets/')
                              ? Image.asset(_scanBefore.imagePath, fit: BoxFit.cover)
                              : Image.file(File(_scanBefore.imagePath), fit: BoxFit.cover),
                        ),
                        
                        // Label Before (Left)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.black54,
                            child: Text("BEFORE: $beforeDate", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),

                        // Image B (After) - Wrapped in ClipRect
                        Positioned.fill(
                          child: ClipRect(
                            clipper: SliderClipper(_swipeRatio),
                            child: _scanAfter.imagePath.startsWith('assets/')
                                ? Image.asset(_scanAfter.imagePath, fit: BoxFit.cover)
                                : Image.file(File(_scanAfter.imagePath), fit: BoxFit.cover),
                          ),
                        ),
                        
                        // Label After (Right)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: AppColors.primaryGold.withValues(alpha: 0.85),
                            child: Text("AFTER: $afterDate", style: const TextStyle(color: AppColors.textDark, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),

                        // Slider dividing line
                        Positioned(
                          left: _swipeRatio * constraints.maxWidth - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2.2,
                            color: AppColors.primaryGold,
                          ),
                        ),

                        // Slider circular drag handle
                        Positioned(
                          left: _swipeRatio * constraints.maxWidth - 16,
                          top: constraints.maxHeight / 2 - 16,
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryGold,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.swap_horiz, color: AppColors.textDark, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // Statistics Changes Summary Card
            Text("Progress Analysis", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildComparisonStatRow(
                    label: "Overall Skin Health",
                    beforeVal: _scanBefore.overallScore,
                    afterVal: _scanAfter.overallScore,
                    isPercentage: false,
                  ),
                  const Divider(color: AppColors.border),
                  ..._scanBefore.detailScores.keys.map((key) {
                    final bVal = _scanBefore.detailScores[key] ?? 100;
                    final aVal = _scanAfter.detailScores[key] ?? 100;
                    
                    String title = key.toUpperCase();
                    if (title == 'CIRCLES') title = 'DARK CIRCLES';
                    if (title == 'REDNESS') title = 'REDNESS / IRRITATION';
                    if (title == 'ACNE') title = 'ACNE / BREAKOUTS';
                    if (title == 'WRINKLES') title = 'WRINKLES & LINES';

                    return Column(
                      children: [
                        _buildComparisonStatRow(
                          label: title,
                          beforeVal: bVal,
                          afterVal: aVal,
                          isPercentage: true,
                        ),
                        const Divider(color: AppColors.border, height: 16),
                      ],
                    );
                  }).toList()..removeLast(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanDropdown({
    required SkinScan selectedScan,
    required ValueChanged<SkinScan?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SkinScan>(
          value: selectedScan,
          dropdownColor: AppColors.cardBgSecondary,
          isExpanded: true,
          items: widget.scans.map((scan) {
            final dateStr = DateFormat('dd/MM/yyyy').format(scan.dateTime);
            return DropdownMenuItem<SkinScan>(
              value: scan,
              child: Text(
                "$dateStr (Score: ${scan.overallScore})",
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildComparisonStatRow({
    required String label,
    required int beforeVal,
    required int afterVal,
    required bool isPercentage,
  }) {
    final diff = afterVal - beforeVal;
    String diffText = "";
    Color diffColor = AppColors.textMuted;
    
    // In skin scores, higher is better
    if (diff > 0) {
      diffText = "+$diff";
      diffColor = AppColors.severityMild; // Green for positive improvement
    } else if (diff < 0) {
      diffText = "$diff";
      diffColor = AppColors.severitySevere; // Red for drop
    } else {
      diffText = "Stable";
      diffColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Row(
            children: [
              Text(
                "$beforeVal${isPercentage ? '%' : ''}",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12, decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: AppColors.textMuted, size: 12),
              const SizedBox(width: 8),
              Text(
                "$afterVal${isPercentage ? '%' : ''}",
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                alignment: Alignment.centerRight,
                child: Text(
                  diffText,
                  style: TextStyle(color: diffColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// Clipper for side-by-side slider overlay
class SliderClipper extends CustomClipper<Rect> {
  final double ratio;

  SliderClipper(this.ratio);

  @override
  Rect getClip(Size size) {
    // Reveal B image from left up to width * ratio
    return Rect.fromLTRB(size.width * ratio, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant SliderClipper oldClipper) {
    return oldClipper.ratio != ratio;
  }
}
