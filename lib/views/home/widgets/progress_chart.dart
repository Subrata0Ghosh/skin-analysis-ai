import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../models/skin_scan.dart';

class ProgressChart extends StatelessWidget {
  final List<SkinScan> scans;

  const ProgressChart({super.key, required this.scans});

  @override
  Widget build(BuildContext context) {
    if (scans.length < 2) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.insights_rounded, color: AppColors.textMuted, size: 36),
            SizedBox(height: 12),
            Text(
              "Gathering historical trends...",
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              "Perform 2 scans to view your health timeline.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    // Sort scans chronologically
    final sortedScans = List<SkinScan>.from(scans)..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    // Take the last 6 scans to keep the chart clean
    final displayScans = sortedScans.length > 6 
        ? sortedScans.sublist(sortedScans.length - 6) 
        : sortedScans;

    // Line 1: Skin Score
    final skinSpots = List.generate(displayScans.length, (index) {
      return FlSpot(index.toDouble(), displayScans[index].overallScore.toDouble());
    });

    // Line 2: Symmetry Score
    final symmetrySpots = List.generate(displayScans.length, (index) {
      return FlSpot(index.toDouble(), displayScans[index].symmetryScore.toDouble());
    });

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Skin Index", AppColors.primaryGold),
              const SizedBox(width: 24),
              _buildLegendItem("Face Symmetry", AppColors.accentSage),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 15,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.35),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            "${value.toInt()}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < displayScans.length) {
                          final dateStr = DateFormat('dd/MM').format(displayScans[index].dateTime);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dateStr,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 24,
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xE60F0F16),
                    tooltipBorder: const BorderSide(color: AppColors.border),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        final isSkin = barSpot.barIndex == 0;
                        final label = isSkin ? "Skin Score" : "Symmetry";
                        final color = isSkin ? AppColors.primaryGold : AppColors.accentSage;
                        return LineTooltipItem(
                          "$label: ${flSpot.y.toInt()}%",
                          TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (displayScans.length - 1).toDouble(),
                minY: 40,
                maxY: 100,
                lineBarsData: [
                  // Line 1: Skin Score
                  LineChartBarData(
                    spots: skinSpots,
                    isCurved: true,
                    color: AppColors.primaryGold,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.background,
                          strokeColor: AppColors.primaryGold,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGold.withValues(alpha: 0.22),
                          AppColors.primaryGold.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Line 2: Symmetry Score
                  LineChartBarData(
                    spots: symmetrySpots,
                    isCurved: true,
                    color: AppColors.accentSage,
                    barWidth: 3.0,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.background,
                          strokeColor: AppColors.accentSage,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentSage.withValues(alpha: 0.15),
                          AppColors.accentSage.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              )
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
