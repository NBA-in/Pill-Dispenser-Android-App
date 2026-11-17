import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../providers/statistics_providers.dart';

class StatisticsScreen extends ConsumerWidget {
  final String dispenserId;
  const StatisticsScreen({super.key, required this.dispenserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherenceAsync = ref.watch(adherenceRateProvider(dispenserId));
    final weeklyAsync = ref.watch(weeklyAdherenceProvider(dispenserId));
    final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

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

            // Device Voltage Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Device Voltage", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Current hardware power level", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    dispenserAsync.when(
                      data: (dispenser) {
                        if (dispenser == null) return const Text("Unknown");
                        final voltage = dispenser.currentState.battery.voltage;
                        return Row(
                          children: [
                            Icon(Icons.bolt, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text("${voltage.toStringAsFixed(2)} V", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => const Text("Error loading"),
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
