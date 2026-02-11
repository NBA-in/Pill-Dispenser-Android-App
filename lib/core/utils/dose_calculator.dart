import '../../features/dispenser/data/models/dispenser_model.dart';

class DoseCalculator {
  static DateTime? getNextDoseTime(ScheduleModel schedule, int currentDay) {
    final now = DateTime.now();
    final List<DateTime> candidates = [];

    // Check today (currentDay) and subsequent days up to Day 5
    // Note: 'currentDay' is 1-indexed (1 to 5)
    // We treat 'now' as being part of 'currentDay'.
    // Doses for 'currentDay' happen 'today'.
    // Doses for 'currentDay + 1' happen 'tomorrow', etc.

    for (int i = currentDay - 1; i < schedule.days.length; i++) {
       final daySchedule = schedule.days[i];
       final daysFromNow = i - (currentDay - 1);
       final dateBase = now.add(Duration(days: daysFromNow));

       void addCandidate(DoseTimeModel dose) {
         if (dose.enabled) {
            final dt = DateTime(dateBase.year, dateBase.month, dateBase.day, dose.hour, dose.minute);
            if (dt.isAfter(now)) {
               candidates.add(dt);
            }
         }
       }
       
       addCandidate(daySchedule.morning);
       addCandidate(daySchedule.lunch);
       addCandidate(daySchedule.night);
    }
    
    // If no doses found in remaining cycle, maybe look at cycle restart?
    // Usually these devices stop after Day 5. Let's assume stop.
    // So candidates list is sufficient.

    if (candidates.isEmpty) return null;

    candidates.sort();
    return candidates.first;
  }

  static String getTimeUntil(DateTime target) {
    final now = DateTime.now();
    final diff = target.difference(now);
    
    if (diff.isNegative) return "Now";

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }
}
