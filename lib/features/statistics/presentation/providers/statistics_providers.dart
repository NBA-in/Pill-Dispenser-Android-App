import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/statistics_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/statistics_repository_impl.dart';

final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepositoryImpl();
});

final weeklyAdherenceProvider = FutureProvider.family<Map<int, int>, String>((ref, dispenserId) async {
  return ref.read(statisticsRepositoryProvider).getWeeklyAdherence(dispenserId);
});

final batteryHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, dispenserId) async {
  return ref.read(statisticsRepositoryProvider).getBatteryHistory(dispenserId);
});

// Added missing provider
final adherenceRateProvider = FutureProvider.family<double, String>((ref, dispenserId) async {
  return ref.read(statisticsRepositoryProvider).calculateAdherence(dispenserId);
});
