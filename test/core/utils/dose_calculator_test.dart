import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pill_dispenser_app/core/utils/dose_calculator.dart';
import 'package:pill_dispenser_app/features/dispenser/data/models/dispenser_model.dart';

void main() {
  group('DoseCalculator', () {
    test('getNextDoseTime returns correct time for today', () {
      // Setup a schedule
      final today = DateTime.now();
      // Use hour+1.
      final futureHour = (today.hour + 1) % 24;
      
      final schedule = ScheduleModel(
        morning: DoseTimeModel(enabled: true, hour: futureHour, minute: 0),
        lunch: const DoseTimeModel(enabled: false, hour: 12, minute: 0),
        night: const DoseTimeModel(enabled: false, hour: 20, minute: 0),
      );

      final next = DoseCalculator.getNextDoseTime(schedule);
      expect(next, isNotNull);
      expect(next!.hour, futureHour);
    });

    test('getNextDoseTime returns null if no enabled doses', () {
      final schedule = ScheduleModel(
        morning: const DoseTimeModel(enabled: false, hour: 8, minute: 0),
        lunch: const DoseTimeModel(enabled: false, hour: 12, minute: 0),
        night: const DoseTimeModel(enabled: false, hour: 20, minute: 0),
      );

      final next = DoseCalculator.getNextDoseTime(schedule);
      expect(next, isNull);
    });
  });
}
