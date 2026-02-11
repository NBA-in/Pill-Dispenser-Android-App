import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';

class CaregiverListScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const CaregiverListScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<CaregiverListScreen> createState() => _CaregiverListScreenState();
}

class _CaregiverListScreenState extends ConsumerState<CaregiverListScreen> {
  late Future<Map<String, List<Map<String, dynamic>>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _usersFuture = ref.read(dispenserRepositoryProvider).getLinkedUsers(widget.dispenserId);
    });
  }

  Future<void> _removeUser(String userId, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove User?"),
        content: const Text("This user will lose access to the dispenser. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dispenserRepositoryProvider).removeUser(widget.dispenserId, userId, role);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User removed")));
           _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
        }
      }
    }
  }

  void _showAddInfo() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Add Caregiver"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("To add a caregiver, verify they have the app installed."),
            const SizedBox(height: 16),
            const Text("Share this Device ID with them:"),
            const SizedBox(height: 8),
            SelectableText(widget.dispenserId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            const Text("They should select 'Caregiver' role and enter this ID or scan the QR code during setup."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isCaregiver = authState.value?.role == UserRole.caregiver;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Users"),
        actions: [
          if (isCaregiver)
            IconButton(onPressed: _showAddInfo, icon: const Icon(Icons.person_add))
        ],
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }
          
          final data = snapshot.data ?? {};
          final patient = data['patient'] ?? [];
          final caregivers = data['caregivers'] ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader("Patient"),
              if (patient.isEmpty) 
                const ListTile(title: Text("No linked patient", style: TextStyle(color: Colors.grey)))
              else 
                ...patient.map((u) => _buildUserTile(u, true, isCaregiver)),
                
              const SizedBox(height: 24),
              _buildSectionHeader("Caregivers"),
              if (caregivers.isEmpty)
                const ListTile(title: Text("No other caregivers", style: TextStyle(color: Colors.grey)))
              else
                ...caregivers.map((u) => _buildUserTile(u, false, isCaregiver)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isPatient, bool canEdit) {
    final userId = user['user_id'] ?? 'Unknown';
    
    return Card(
      child: ListTile(
        leading: Icon(isPatient ? Icons.elderly : Icons.family_restroom, color: isPatient ? AppColors.secondary : Colors.orange),
        title: Text(userId, overflow: TextOverflow.ellipsis), // Displaying ID for now
        subtitle: Text(isPatient ? "Primary User" : "Caregiver"),
        trailing: (canEdit && !isPatient) // Patients usually can't be removed easily, or policy decision
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                onPressed: () => _removeUser(userId, isPatient ? 'patient' : 'caregiver'),
              )
            : null,
      ),
    );
  }
}
