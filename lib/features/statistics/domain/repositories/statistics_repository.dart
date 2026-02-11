import '../../../dispenser/data/models/dose_history_model.dart';

abstract class StatisticsRepository {
  Future<Map<String, dynamic>> getDailyStats(String dispenserId, DateTime date);
  Future<List<DoseHistoryModel>> getRecentDoses(String dispenserId, int limit);
  // Adherence Rate: Taken / (Taken + Missed) * 100
  Future<double> calculateAdherence(String dispenserId, {DateTime? start, DateTime? end});
  
  // Charts
  Future<Map<int, int>> getWeeklyAdherence(String dispenserId); // Day index (0-6) -> Count
  Future<List<Map<String, dynamic>>> getBatteryHistory(String dispenserId); // List of {date, level}
}
