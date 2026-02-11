import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/data/models/dose_history_model.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';

class DoseHistoryScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const DoseHistoryScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends ConsumerState<DoseHistoryScreen> {
  late Future<List<DoseHistoryModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref.read(dispenserRepositoryProvider).getDoseHistory(widget.dispenserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dose History")),
      body: FutureBuilder<List<DoseHistoryModel>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }
          
          final doses = snapshot.data ?? [];
          if (doses.isEmpty) {
            return const Center(child: Text("No dose history found"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doses.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final dose = doses[index];
              return ListTile(
                leading: _buildStatusIcon(dose.status),
                title: Text("${_capitalize(dose.doseType)} Dose"),
                subtitle: Text(dose.date != null 
                    ? DateFormat('MMM d, h:mm a').format(dose.date!.toDate())
                    : "Date unknown"),
                trailing: Chip(
                  label: Text(dose.status.toUpperCase()),
                  backgroundColor: _getStatusColor(dose.status).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getStatusColor(dose.status), fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Icon _buildStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'taken': return const Icon(Icons.check_circle, color: AppColors.success);
      case 'missed': return const Icon(Icons.cancel, color: AppColors.error);
      case 'dispensed': return const Icon(Icons.outbox, color: AppColors.warning);
      default: return const Icon(Icons.schedule, color: Colors.grey);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'taken': return AppColors.success;
      case 'missed': return AppColors.error;
      case 'dispensed': return AppColors.warning;
      default: return Colors.grey;
    }
  }

  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';
}
