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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.show_chart, color: AppColors.textMuted, size: 40),
            SizedBox(height: 12),
            Text(
              "Not enough scans yet",
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "Complete at least 2 scans to view trends.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Sort scans ascending by date for chronological charting
    final sortedScans = List<SkinScan>.from(scans)..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    // Take the last 6 scans to keep the chart clean
    final displayScans = sortedScans.length > 6 
        ? sortedScans.sublist(sortedScans.length - 6) 
        : sortedScans;

    final spots = List.generate(displayScans.length, (index) {
      return FlSpot(index.toDouble(), displayScans[index].overallScore.toDouble());
    });

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border.withValues(alpha: 0.4),
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
                      value.toInt().toString(),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
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
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (displayScans.length - 1).toDouble(),
          minY: 40,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primaryGold,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppColors.background,
                    strokeColor: AppColors.primaryGold,
                    strokeWidth: 2,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primaryGold.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
