import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/dispenser_providers.dart';

class RefillScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const RefillScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<RefillScreen> createState() => _RefillScreenState();
}

class _RefillScreenState extends ConsumerState<RefillScreen> {
  // Track checklist
  final List<bool> _compartmentsFilled = List.filled(15, false);
  bool _isLoading = false;

  Future<void> _completeRefill() async {
    if (_compartmentsFilled.contains(false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please confirm all compartments are filled.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(dispenserRepositoryProvider);
      
      // Update State: Reset counters
      await repo.updateCurrentState(widget.dispenserId, {
        'doses_remaining': 15,
        'current_day': 1,
        'refill_mode_active': false,
        'dose_ready': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Refill Complete! Device Reset."), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Refill Assistant")),
      body: Column(
        children: [
           Padding(
             padding: const EdgeInsets.all(16),
             child: Card(
               color: AppColors.primaryContainer,
               child: const Padding(
                 padding: EdgeInsets.all(16.0),
                 child: Text(
                   "Please fill each compartment as indicated. Ensure correct medication for Morning, Lunch, and Night slots.",
                   style: TextStyle(fontSize: 16),
                 ),
               ),
             ),
           ),
           Expanded(
             child: ListView.builder(
               itemCount: 5, // 5 Days
               padding: const EdgeInsets.symmetric(horizontal: 16),
               itemBuilder: (context, dayIndex) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text("Day ${dayIndex + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildCheckItem(dayIndex * 3 + 0, "Morning"),
                        _buildCheckItem(dayIndex * 3 + 1, "Lunch"),
                        _buildCheckItem(dayIndex * 3 + 2, "Night"),
                      ],
                    ),
                  );
               },
             ),
           ),
           Padding(
             padding: const EdgeInsets.all(16),
             child: SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: _isLoading ? null : _completeRefill,
                 icon: const Icon(Icons.check_circle),
                 label: const Text("Confirm Refill Complete"),
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   textStyle: const TextStyle(fontSize: 18),
                 ),
               ),
             ),
           )
        ],
      ),
    );
  }

  Widget _buildCheckItem(int index, String label) {
    return CheckboxListTile(
      value: _compartmentsFilled[index],
      onChanged: (val) {
        setState(() {
          _compartmentsFilled[index] = val ?? false;
        });
      },
      title: Text("Slot ${index + 1}: $label"),
      secondary: const Icon(Icons.medical_services_outlined),
    );
  }
}
