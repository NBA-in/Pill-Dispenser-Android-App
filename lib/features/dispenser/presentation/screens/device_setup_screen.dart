import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../setup/presentation/screens/qr_code_scanner_screen.dart';

class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final _deviceIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _wifiSsidController = TextEditingController();
  final _wifiPassController = TextEditingController();

  @override
  void dispose() {
    _deviceIdController.dispose();
    _nameController.dispose();
    _wifiSsidController.dispose();
    _wifiPassController.dispose();
    super.dispose();
  }

  Future<void> _handlePair() async {
    if (_deviceIdController.text.trim().isEmpty) return;

    await ref.read(deviceSetupControllerProvider.notifier)
        .pairDevice(
          _deviceIdController.text.trim(),
          deviceName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        );
  }

  Future<void> _scanQR() async {
    // Navigate to QR Scanner
    // We can use the existing widget or push a route. 
    // Since it's a widget, we can push MaterialPageRoute.
    final scannedCode = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const QRCodeScannerScreen())
    );

    if (scannedCode != null && scannedCode is String) {
      setState(() {
        _deviceIdController.text = scannedCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(deviceSetupControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${next.error}"), backgroundColor: AppColors.error),
        );
      } else if (!next.isLoading && next.hasValue) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Device Paired Successfully!"), backgroundColor: AppColors.success),
        );
        // Navigate to Dashboard
        final role = ref.read(authStateProvider).value?.role;
        if (role == UserRole.patient) {
           context.go('/patient');
        } else {
           context.go('/caregiver');
        }
      }
    });

    final state = ref.watch(deviceSetupControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text("Setup Device")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.router, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              "Pair your Smart Pill Dispenser",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Scan the QR code on your device or enter the Device ID manually.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // Scan Button
            OutlinedButton.icon(
              onPressed: isLoading ? null : _scanQR,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan QR Code"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
            ),
            
            const SizedBox(height: 24),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.all(8.0), child: Text("OR")), Expanded(child: Divider())]),
            const SizedBox(height: 24),

            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: "Device ID",
                hintText: "Enter ID manually (e.g. PILL-001)",
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
             TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Device Name (Optional)",
                hintText: "e.g. Mom's Dispenser",
                prefixIcon: Icon(Icons.edit),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Mock WiFi Config
            ExpansionTile(
              title: const Text("WiFi Configuration (Optional)"),
              leading: const Icon(Icons.wifi),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _wifiSsidController,
                    decoration: const InputDecoration(
                      labelText: "WiFi SSID",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _wifiPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "WiFi Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40), // Replaces Spacer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handlePair,
                child: isLoading 
                    ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white))
                    : const Text("Connect Device"),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
