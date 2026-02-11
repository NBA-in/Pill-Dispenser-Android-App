import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/data/models/dispenser_model.dart';

class CompartmentGuideWidget extends StatefulWidget {
  final ScheduleModel schedule;
  final bool readOnly;
  final Function(int dayIndex, String type, DoseTimeModel currentDose)? onSlotTap;

  const CompartmentGuideWidget({
    super.key, 
    required this.schedule,
    this.readOnly = false,
    this.onSlotTap,
  });

  @override
  State<CompartmentGuideWidget> createState() => _CompartmentGuideWidgetState();
}

class _CompartmentGuideWidgetState extends State<CompartmentGuideWidget> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(1.5), // Day label
              1: FlexColumnWidth(1),   // Morning
              2: FlexColumnWidth(1),   // Lunch
              3: FlexColumnWidth(1),   // Night
            },
            children: const [
              TableRow(
                children: [
                   SizedBox(), // Empty above Day
                   Center(child: Icon(Icons.wb_twilight, color: AppColors.primary)), // M -> Sunrise
                   Center(child: Icon(Icons.wb_sunny, color: Colors.orange)),        // L -> Sun
                   Center(child: Icon(Icons.nightlight_round, color: Colors.indigo)), // N -> Moon
                ],
              ),
            ],
          ),
        ),
        
        // List of Days
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.schedule.days.length, 
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, dayIndex) {
            final daySchedule = widget.schedule.days[dayIndex];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FlexColumnWidth(1.5), 
                  1: FlexColumnWidth(1),   
                  2: FlexColumnWidth(1),   
                  3: FlexColumnWidth(1),   
                },
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          "Day ${dayIndex + 1}", 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                      ),
                      _buildSlot(dayIndex, "morning", daySchedule.morning),
                      _buildSlot(dayIndex, "lunch", daySchedule.lunch),
                      _buildSlot(dayIndex, "night", daySchedule.night),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlot(int dayIndex, String type, DoseTimeModel dose) {
    final key = "${dayIndex}_$type";
    final isEnabled = dose.enabled;

    return InkWell(
      onTap: () {
        if (widget.onSlotTap != null) {
          widget.onSlotTap!(dayIndex, type, dose);
        }
      },
      child: Column(
        children: [
          // Slot Circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnabled ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: isEnabled ? AppColors.primary : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isEnabled 
               ? const Icon(Icons.check, color: Colors.white, size: 22)
               : Icon(
                   type == 'morning' ? Icons.wb_twilight :
                   type == 'lunch' ? Icons.wb_sunny : Icons.nightlight_round,
                   color: Colors.grey.withOpacity(0.5), 
                   size: 20
                 ),
          ),
          
          const SizedBox(height: 4),

          // Time Label
          Text(
            TimeOfDay(hour: dose.hour, minute: dose.minute).format(context),
            style: TextStyle(
              fontSize: 10,
              color: isEnabled ? Colors.black87 : Colors.grey,
              fontWeight: isEnabled ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
