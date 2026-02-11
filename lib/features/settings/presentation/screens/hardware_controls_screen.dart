import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../dispenser/data/models/rfid_tag_model.dart';

class HardwareControlsScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const HardwareControlsScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<HardwareControlsScreen> createState() => _HardwareControlsScreenState();
}

class _HardwareControlsScreenState extends ConsumerState<HardwareControlsScreen> {
  bool _isProcessing = false;

  Future<void> _sendCommand(String command, {Map<String, dynamic>? payload}) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(commandRepositoryProvider).sendCommand(
        widget.dispenserId,
        command,
        payload: payload,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Command '$command' sent successfully"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteTag(String tagId) async {
    try {
      await ref.read(dispenserRepositoryProvider).deleteRFIDTag(widget.dispenserId, tagId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tag deleted"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting tag: $e"), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Assuming we'll add a provider for streamRFIDTags. 
    // Since it's not in dispenser_providers.dart yet, I'll access repo directly or we can add a provider.
    // For now, let's use a StreamBuilder with the repository method.
    final rfidStream = ref.watch(dispenserRepositoryProvider).streamRFIDTags(widget.dispenserId);

    return Scaffold(
      appBar: AppBar(title: const Text("Hardware Controls")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Controls Section
          const Text("Device Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _ControlRow(
                    title: "Force Dispense",
                    description: "Dispense one dose immediately",
                    action: FilledButton.icon(
                      onPressed: _isProcessing ? null : () => _sendCommand('DISPENSE_NOW'),
                      icon: const Icon(Icons.medication),
                      label: const Text("Dispense"),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                    ),
                  ),
                  const Divider(),
                  _ControlRow(
                    title: "Latch Control",
                    description: "Unlock/Lock the device lid",
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: _isProcessing ? null : () => _sendCommand('UNLOCK_LATCH'),
                          child: const Text("Unlock"),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _isProcessing ? null : () => _sendCommand('LOCK_LATCH'),
                          child: const Text("Lock"),
                        ),
                      ],
                    ),
                  ),
                   const Divider(),
                  _ControlRow(
                    title: "System",
                    description: "Restart the device",
                    action: OutlinedButton.icon(
                       onPressed: _isProcessing ? null : () => _sendCommand('REBOOT'),
                       icon: const Icon(Icons.restart_alt),
                       label: const Text("Reboot"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // RFID Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("RFID Tags", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton.filledTonal(
                onPressed: _isProcessing ? null : () => _sendCommand('LEARN_RFID', payload: {'timeout': 30}),
                icon: const Icon(Icons.add),
                tooltip: "Add New Tag",
              )
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<RFIDTagModel>>(
            stream: rfidStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              final tags = snapshot.data ?? [];
              
              if (tags.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text("No RFID tags found. Click + to add one.")),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.nfc),
                      title: Text(tag.name),
                      subtitle: Text("ID: ${tag.id}\nAdded: ${tag.createdAt.toString().split('.')[0]}"),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () => _deleteTag(tag.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final String title;
  final String description;
  final Widget action;

  const _ControlRow({required this.title, required this.description, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}
