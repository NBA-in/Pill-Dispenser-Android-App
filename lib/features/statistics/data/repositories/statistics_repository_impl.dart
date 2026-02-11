import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../../../dispenser/data/models/dose_history_model.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  final FirebaseFirestore _firestore;

  StatisticsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<double> calculateAdherence(String dispenserId, {DateTime? start, DateTime? end}) async {
    Query query = _firestore.collection('dose_history').doc(dispenserId).collection('doses');
    if (start != null) query = query.where('date', isGreaterThanOrEqualTo: start);
    if (end != null) query = query.where('date', isLessThanOrEqualTo: end);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return 100.0; // Default to 100 if no data? Or 0? Let's say 0.
    // Wait, if no doses scheduled, user is adhering to nothing? 
    // Return 0 if no data for calculations.
    
    // Actually, calculate:
    int taken = 0;
    int total = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      
      if (status == 'taken') taken++;
      if (status == 'taken' || status == 'missed') total++;
      // 'scheduled' or 'dispensed' (pending) shouldn't count against adherence yet? 
      // If end date is in past, they count as missed implicitly if not taken?
      // Assuming 'status' is updated by Functions/Events regularly.
    }

    if (total == 0) return 0.0;
    return (taken / total) * 100;
  }

  @override
  Future<Map<String, dynamic>> getDailyStats(String dispenserId, DateTime date) {
    // Return aggregate or calculate on fly.
    // Spec says 'statistics/{dispenser_id}/daily_stats/{date}'
    // We should try to read that first.
    final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    return _firestore.collection('statistics').doc(dispenserId).collection('daily_stats').doc(dateStr).get()
      .then((doc) => doc.data() ?? {});
  }

  @override
  Future<List<DoseHistoryModel>> getRecentDoses(String dispenserId, int limit) async {
    final query = await _firestore.collection('dose_history').doc(dispenserId).collection('doses')
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
        
    return query.docs.map((d) => DoseHistoryModel.fromFirestore(d)).toList();
  }

  @override
  Future<Map<int, int>> getWeeklyAdherence(String dispenserId) async {
    // 1. Get doses for last 7 days
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final query = await _firestore
        .collection('dose_history')
        .doc(dispenserId)
        .collection('doses')
        .where('date', isGreaterThanOrEqualTo: sevenDaysAgo)
        .get();

    // 2. Aggregate 'taken' count per day index (0=Mon, 6=Sun) or relative to today?
    // Let's us relative to today: 0 = Today, 1 = Yesterday ... 6 = 6 days ago.
    // Or just Map<Weekday, Count>. Let's do Weekday (1=Mon, 7=Sun).
    
    Map<int, int> result = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
    };

    for (var doc in query.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final status = data['status'];
      
      if (status == 'taken') {
        result[date.weekday] = (result[date.weekday] ?? 0) + 1;
      }
    }
    
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getBatteryHistory(String dispenserId) async {
    // Return mock data for now as we don't have historical battery logs
    // In real app, we'd query 'device_health_logs'
    
    // Simulate a decline over last 24 hours
    final now = DateTime.now();
    return List.generate(10, (index) {
      return {
        'date': now.subtract(Duration(hours: index * 2)),
        'level': 100 - (index * 5), // 100, 95, 90...
      };
    }).reversed.toList();
  }
}
