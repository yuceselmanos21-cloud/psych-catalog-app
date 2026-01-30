import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Test sonuçları için grafik widget'ı
class TestResultChart extends StatelessWidget {
  final List<int> scaleAnswers; // 1-5 arası skala cevapları
  final List<String> textAnswers; // Metin cevapları
  final bool isDark;

  const TestResultChart({
    super.key,
    required this.scaleAnswers,
    this.textAnswers = const [],
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (scaleAnswers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Skala cevaplarının dağılımını hesapla
    final Map<int, int> distribution = {};
    for (int i = 1; i <= 5; i++) {
      distribution[i] = scaleAnswers.where((a) => a == i).length;
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cevap Dağılımı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: scaleAnswers.length.toDouble(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.deepPurple,
                      tooltipRoundedRadius: 8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                      left: BorderSide(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: distribution.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: _getColorForScale(entry.key),
                          width: 30,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('1', _getColorForScale(1)),
                const SizedBox(width: 16),
                _buildLegendItem('2', _getColorForScale(2)),
                const SizedBox(width: 16),
                _buildLegendItem('3', _getColorForScale(3)),
                const SizedBox(width: 16),
                _buildLegendItem('4', _getColorForScale(4)),
                const SizedBox(width: 16),
                _buildLegendItem('5', _getColorForScale(5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForScale(int scale) {
    switch (scale) {
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade600;
      case 4:
        return Colors.lightGreen.shade400;
      case 5:
        return Colors.green.shade400;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

/// Test sonuçları için pasta grafiği (cevap tipi dağılımı)
class TestAnswerTypeChart extends StatelessWidget {
  final int scaleCount;
  final int textCount;
  final int multipleChoiceCount;
  final bool isDark;

  const TestAnswerTypeChart({
    super.key,
    required this.scaleCount,
    required this.textCount,
    required this.multipleChoiceCount,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = scaleCount + textCount + multipleChoiceCount;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soru Tipi Dağılımı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (scaleCount > 0)
                      PieChartSectionData(
                        value: scaleCount.toDouble(),
                        title: '${((scaleCount / total) * 100).toStringAsFixed(0)}%',
                        color: Colors.blue,
                        radius: 60,
                        titleStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (textCount > 0)
                      PieChartSectionData(
                        value: textCount.toDouble(),
                        title: '${((textCount / total) * 100).toStringAsFixed(0)}%',
                        color: Colors.green,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (multipleChoiceCount > 0)
                      PieChartSectionData(
                        value: multipleChoiceCount.toDouble(),
                        title: '${((multipleChoiceCount / total) * 100).toStringAsFixed(0)}%',
                        color: Colors.orange,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (scaleCount > 0)
                  _buildLegendItem('Skala', Colors.blue, scaleCount),
                if (textCount > 0)
                  _buildLegendItem('Metin', Colors.green, textCount),
                if (multipleChoiceCount > 0)
                  _buildLegendItem('Çoktan Seçmeli', Colors.orange, multipleChoiceCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
