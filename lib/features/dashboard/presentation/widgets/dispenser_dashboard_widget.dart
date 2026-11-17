import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dose_calculator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../dispenser/data/models/dispenser_model.dart';
import '../../../dispenser/data/models/dose_history_model.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../dispenser/presentation/screens/refill_wizard_screen.dart';

class DispenserDashboardWidget extends ConsumerStatefulWidget {
  final DispenserModel dispenser;
  final bool isCaregiver;

  const DispenserDashboardWidget({
    super.key, 
    required this.dispenser,
    this.isCaregiver = false,
  });

  @override
  ConsumerState<DispenserDashboardWidget> createState() => _DispenserDashboardWidgetState();
}

class _DispenserDashboardWidgetState extends ConsumerState<DispenserDashboardWidget> {
  Timer? _timer;
  Future<List<DoseHistoryModel>>? _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref.read(dispenserRepositoryProvider).getDoseHistory(widget.dispenser.id);
    // Update UI every second to refresh countdown and handle 5-sec drop message
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextDose = DoseCalculator.getNextDoseTime(
        widget.dispenser.schedule, 
        widget.dispenser.currentState.operational.currentDay,
        dosesRemaining: widget.dispenser.currentState.operational.dosesRemaining,
    );
    final isReady = widget.dispenser.currentState.operational.doseReady; 
    
    final now = DateTime.now();
    bool isDropping = false;
    bool isLessThanMinute = false;
    int secondsLeft = 0;
    
    if (nextDose != null) {
       final diff = nextDose.difference(now);
       if (diff.isNegative && diff.inSeconds >= -5) {
          isDropping = true;
       } else if (!diff.isNegative && diff.inMinutes < 1) {
          isLessThanMinute = true;
          secondsLeft = diff.inSeconds;
       }
    }

    ref.listen<AsyncValue<void>>(dispenserControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${next.error}"), backgroundColor: AppColors.error),
        );
      } else if (!next.isLoading && next.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Command Sent"), backgroundColor: AppColors.success),
        );
      }
    });

    final actionState = ref.watch(dispenserControllerProvider);
    final isActionLoading = actionState.isLoading;

    final currState = widget.dispenser.currentState; // Helper to shorten access

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(dispenserProvider(widget.dispenser.id));
        setState(() {
          _historyFuture = ref.read(dispenserRepositoryProvider).getDoseHistory(widget.dispenser.id);
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HEADER CARD
          Card(
            color: currState.connectivity.wifiConnected ? AppColors.primaryContainer : AppColors.error.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                   Icon(
                     currState.connectivity.wifiConnected ? Icons.wifi : Icons.wifi_off,
                     color: currState.connectivity.wifiConnected ? AppColors.primary : AppColors.error,
                   ),
                   const SizedBox(width: 16),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         widget.dispenser.deviceName,
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                       ),
                       Text(
                         currState.connectivity.wifiConnected ? AppConstants.onlineText : AppConstants.offlineText,
                         style: TextStyle(
                           color: currState.connectivity.wifiConnected ? AppColors.primary : AppColors.error,
                         ),
                       ),
                     ],
                   ),
                   const Spacer(),
                   Icon(Icons.battery_full, color: _getBatteryColor(currState.battery.percent.toInt())),
                   const SizedBox(width: 4),
                   Text("${currState.battery.percent.toInt()}%"),
                ],
              ),
            ),
          ),
          if (currState.operational.currentDay == 4 || currState.operational.currentDay == 5) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.deepOrange.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Refill Reminder ⚠️",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "The pill dispenser is currently on Day ${currState.operational.currentDay}. Please refill the dispenser soon to avoid missing any scheduled doses.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                    if (widget.isCaregiver) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RefillWizardScreen(
                                  dispenserId: widget.dispenser.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.autorenew, size: 16),
                          label: const Text("Refill Now"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepOrange.shade800,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // COUNTDOWN OR STATUS
          Center(
             child: Container(
               width: 260,
               height: 260,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 gradient: isDropping 
                     ? LinearGradient(colors: [AppColors.primary, AppColors.primary.withAlpha(200)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                     : isReady 
                         ? LinearGradient(colors: [AppColors.error, AppColors.error.withAlpha(200)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                         : const LinearGradient(colors: [Colors.white, Color(0xFFF0F5FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                 border: Border.all(
                   color: isDropping ? AppColors.primary : (isReady ? AppColors.error : AppColors.primary),
                   width: 5,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.1),
                     blurRadius: 20,
                     spreadRadius: 5,
                   )
                 ]
               ),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   if (isDropping) ...[
                      const Icon(Icons.info_outline, size: 50, color: Colors.white),
                      const SizedBox(height: 8),
                      const Text(
                        "Medicine dropped\nplease do have it",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                   ] else if (isReady) ...[
                      const Icon(Icons.medication, size: 60, color: Colors.white),
                      const Text(
                        "TAKE\nMEDICINE",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                   ] else if (nextDose != null) ...[
                      const Icon(Icons.timer, size: 40, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                         isLessThanMinute ? "${secondsLeft}s" : DoseCalculator.getTimeUntil(nextDose),
                         style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Text("Until next dose", style: TextStyle(color: Colors.grey)),
                      Text(
                        _formatTime12Hour(nextDose.hour, nextDose.minute),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: widget.isCaregiver
                            ? () => _showDaySelectorDialog(context, ref, currState.operational.currentDay)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Day ${currState.operational.currentDay}",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              if (widget.isCaregiver) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                              ],
                            ],
                          ),
                        ),
                      ),
                   ] else ...[
                      const Icon(Icons.check_circle_outline, size: 60, color: AppColors.success),
                      const Text("All Done", style: TextStyle(fontSize: 24, color: AppColors.success)),
                      const Text("No doses scheduled", style: TextStyle(color: Colors.grey)),
                   ]
                 ],
               ),
             ),
          ),



          // TODAY'S SCHEDULE
          const Text("Today's Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildTodaysSchedule(currState.operational.currentDay),
          const SizedBox(height: 24),

          // RECENT HISTORY
          const Text("Recent History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<DoseHistoryModel>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("No recent history found.", style: TextStyle(color: Colors.grey));
              }
              
              final now = DateTime.now();
              final startOfDay = DateTime(now.year, now.month, now.day);
              
              final recentItems = snapshot.data!.where((item) {
                if (item.takenTime == null) return false;
                final dt = item.takenTime!.toDate();
                return dt.isAfter(startOfDay) || dt.isAtSameMomentAs(startOfDay);
              }).toList();
              if (recentItems.isEmpty) {
                return const Text("No history recorded for today yet.", style: TextStyle(color: Colors.grey));
              }

              return Column(
                children: recentItems.map((item) {
                  final timeStr = item.takenTime != null 
                    ? _formatTime12Hour(item.takenTime!.toDate().hour, item.takenTime!.toDate().minute)
                    : "Unknown";
                    
                  Color statusColor = Colors.grey;
                  IconData statusIcon = Icons.help_outline;
                  if (item.status == 'TAKEN') {
                    statusColor = AppColors.success;
                    statusIcon = Icons.check_circle;
                  } else if (item.status == 'MISSED') {
                    statusColor = AppColors.error;
                    statusIcon = Icons.cancel;
                  } else if (item.status == 'DISPENSED') {
                    statusColor = AppColors.warning;
                    statusIcon = Icons.medication;
                  }
                  
                  return Card(
                    child: ListTile(
                      leading: Icon(statusIcon, color: statusColor),
                      title: Text("${item.doseType} Dose"),
                      subtitle: Text("Time: $timeStr"),
                      trailing: Text(item.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ACTIONS SECTION
          const Text("Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
               if (widget.isCaregiver)
                 ActionChip(
                   avatar: const Icon(Icons.edit_calendar),
                   label: const Text("Edit Schedule"),
                   onPressed: () {
                     context.push('/schedule/${widget.dispenser.id}');
                   },
                 )
               else
                 ActionChip(
                   avatar: const Icon(Icons.calendar_month),
                   label: const Text("View Schedule"),
                   onPressed: () {
                     context.push('/view-schedule/${widget.dispenser.id}');
                   },
                 ),
               ActionChip(
                 avatar: const Icon(Icons.history),
                 label: const Text("History"),
                 onPressed: () {
                   context.push('/history/${widget.dispenser.id}');
                 },
               ),
               ActionChip(
                 avatar: const Icon(Icons.analytics),
                 label: const Text("Stats"),
                 onPressed: () {
                   context.push('/stats/${widget.dispenser.id}');
                 },
               ),

               if (widget.isCaregiver)
                 ActionChip(
                   avatar: const Icon(Icons.autorenew),
                   label: const Text("Refill"),
                   onPressed: () {
                     Navigator.of(context).push(
                       MaterialPageRoute(builder: (_) => RefillWizardScreen(dispenserId: widget.dispenser.id)),
                     );
                   },
                 ),
            ],
          ),

          // MANUAL DISPENSE / TAKE CONFIRMATION
           if (isReady && !widget.isCaregiver) ...[
             const SizedBox(height: 24),
             ElevatedButton.icon(
               onPressed: isActionLoading ? null : () {
                  ref.read(dispenserControllerProvider.notifier).markDoseTaken(widget.dispenser.id);
               }, 
               icon: isActionLoading 
                  ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white)) 
                  : const Icon(Icons.check),
               label: const Text(AppConstants.takeMedicineAction),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.success,
                 padding: const EdgeInsets.symmetric(vertical: 16),
               ),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  
  Color _getBatteryColor(int percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTodaysSchedule(int currentDay) {
    if (widget.dispenser.schedule.days.isEmpty) return const SizedBox.shrink();
    int index = currentDay - 1;
    if (index < 0 || index >= widget.dispenser.schedule.days.length) return const SizedBox.shrink();

    final daySchedule = widget.dispenser.schedule.days[index];

    List<Widget> doses = [];
    if (daySchedule.morning.enabled) {
      doses.add(_buildDoseChip("Morning", daySchedule.morning.hour, daySchedule.morning.minute, Icons.wb_sunny, Colors.orange));
    }
    if (daySchedule.lunch.enabled) {
      doses.add(_buildDoseChip("Lunch", daySchedule.lunch.hour, daySchedule.lunch.minute, Icons.restaurant, Colors.green));
    }
    if (daySchedule.night.enabled) {
      doses.add(_buildDoseChip("Night", daySchedule.night.hour, daySchedule.night.minute, Icons.nights_stay, Colors.indigo));
    }

    if (doses.isEmpty) {
      return const Text("No doses scheduled for today.", style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: doses,
    );
  }

  Widget _buildDoseChip(String label, int hour, int minute, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text("$label (${_formatTime12Hour(hour, minute)})"),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.5)),
    );
  }

  void _showDaySelectorDialog(BuildContext context, WidgetRef ref, int currentDay) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Force Change Day"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final day = index + 1;
              final isCurrent = day == currentDay;
              return ListTile(
                title: Text("Day $day"),
                trailing: isCurrent ? const Icon(Icons.check, color: AppColors.primary) : null,
                selected: isCurrent,
                onTap: () async {
                  Navigator.of(context).pop();
                  
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Switching to Day $day..."), duration: const Duration(seconds: 1)),
                  );

                  try {
                    await ref.read(dispenserControllerProvider.notifier)
                        .forceSetDay(widget.dispenser.id, day);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Successfully switched day"), backgroundColor: AppColors.success),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  String _formatTime12Hour(int hour, int minute) {
    final period = hour >= 12 ? "PM" : "AM";
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return "$hour12:$minuteStr $period";
  }
}
