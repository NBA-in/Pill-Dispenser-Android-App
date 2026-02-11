import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/statistics_providers.dart';

class StatisticsScreen extends ConsumerWidget {
  final String dispenserId;
  const StatisticsScreen({super.key, required this.dispenserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherenceAsync = ref.watch(adherenceRateProvider(dispenserId));
    final weeklyAsync = ref.watch(weeklyAdherenceProvider(dispenserId));
    final batteryAsync = ref.watch(batteryHistoryProvider(dispenserId));

    return Scaffold(
      appBar: AppBar(title: const Text("Statistics & Adherence")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Overall Adherence Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text("Overall Adherence", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: adherenceAsync.when(
                        data: (rate) => Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: rate,
                                    color: AppColors.primary,
                                    radius: 25,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: (100 - rate).toDouble(),
                                    color: Colors.grey[300],
                                    radius: 25,
                                    showTitle: false,
                                  ),
                                ],
                                sectionsSpace: 0,
                                centerSpaceRadius: 60,
                              ),
                            ),
                            Center(
                              child: Text(
                                "${rate.toStringAsFixed(1)}%",
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        error: (e,s) => Text("Error: $e"),
                        loading: () => const CircularProgressIndicator(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Weekly Adherence (Bar Chart)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Weekly Doses Taken", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                       height: 200,
                       child: weeklyAsync.when(
                         data: (data) => BarChart(
                           BarChartData(
                             gridData: const FlGridData(show: false),
                             titlesData: FlTitlesData(
                               leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                               bottomTitles: AxisTitles(
                                 sideTitles: SideTitles(
                                   showTitles: true,
                                   getTitlesWidget: (val, meta) {
                                     const days = ['M','T','W','T','F','S','S'];
                                     final index = val.toInt() - 1; 
                                     if (index >= 0 && index < 7) return Text(days[index]);
                                     return const Text('');
                                   },
                                 ),
                               ),
                               topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                               rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                             ),
                             borderData: FlBorderData(show: false),
                             barGroups: [
                               for (int i=1; i<=7; i++)
                                 BarChartGroupData(
                                   x: i,
                                   barRods: [
                                     BarChartRodData(
                                        toY: (data[i] ?? 0).toDouble(),
                                        color: AppColors.secondary,
                                        width: 16,
                                        borderRadius: BorderRadius.circular(4),
                                     )
                                   ]
                                 )
                             ]
                           ),
                         ),
                         error: (e,s) => Text("Error: $e"),
                         loading: () => const Center(child: CircularProgressIndicator()),
                       ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Battery History (Line Chart)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Battery Health (Last 24h)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                       height: 200,
                       child: batteryAsync.when(
                         data: (history) {
                            if (history.isEmpty) return const Text("No data");
                            return LineChart(
                               LineChartData(
                                 gridData: const FlGridData(show: true, drawVerticalLine: false),
                                 titlesData: const FlTitlesData(
                                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Time labels tricky without formatting
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                 ),
                                 borderData: FlBorderData(show: false),
                                 lineBarsData: [
                                   LineChartBarData(
                                     spots: history.asMap().entries.map((e) {
                                        return FlSpot(e.key.toDouble(), (e.value['level'] as int).toDouble());
                                     }).toList(),
                                     isCurved: true,
                                     color: AppColors.success,
                                     barWidth: 3,
                                     dotData: const FlDotData(show: false),
                                     belowBarData: BarAreaData(show: true, color: AppColors.success.withAlpha(51)),
                                   )
                                 ],
                                 minY: 0,
                                 maxY: 100,
                               ),
                            );
                         },
                         error: (e,s) => Text("Error: $e"),
                         loading: () => const Center(child: CircularProgressIndicator()),
                       ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
