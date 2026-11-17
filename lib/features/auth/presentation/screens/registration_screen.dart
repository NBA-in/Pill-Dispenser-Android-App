import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_providers.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _patientFormKey = GlobalKey<FormState>();
  final _caregiverFormKey = GlobalKey<FormState>();

  // Patient Controllers
  final _patientEmailController = TextEditingController();
  final _patientPasswordController = TextEditingController();
  final _patientConfirmPasswordController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _patientPhoneController = TextEditingController();

  // Caregiver Controllers
  final _caregiverEmailController = TextEditingController();
  final _caregiverPasswordController = TextEditingController();
  final _caregiverConfirmPasswordController = TextEditingController();
  final _caregiverNameController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();


  GlobalKey<FormState> get _formKey => _selectedRole == UserRole.patient ? _patientFormKey : _caregiverFormKey;
  TextEditingController get _emailController => _selectedRole == UserRole.patient ? _patientEmailController : _caregiverEmailController;
  TextEditingController get _passwordController => _selectedRole == UserRole.patient ? _patientPasswordController : _caregiverPasswordController;
  TextEditingController get _confirmPasswordController => _selectedRole == UserRole.patient ? _patientConfirmPasswordController : _caregiverConfirmPasswordController;
  TextEditingController get _nameController => _selectedRole == UserRole.patient ? _patientNameController : _caregiverNameController;
  TextEditingController get _phoneController => _selectedRole == UserRole.patient ? _patientPhoneController : _caregiverPhoneController;

  
  UserRole _selectedRole = UserRole.patient;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _patientEmailController.dispose();
    _patientPasswordController.dispose();
    _patientConfirmPasswordController.dispose();
    _patientNameController.dispose();
    _patientPhoneController.dispose();

    _caregiverEmailController.dispose();
    _caregiverPasswordController.dispose();
    _caregiverConfirmPasswordController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();

    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authControllerProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _selectedRole,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final errorMsg = next.error.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
      // Success triggers authState change -> router redirect
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Who are you?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.patient,
                      label: Text("Patient"),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: UserRole.caregiver,
                      label: Text("Caregiver"),
                      icon: Icon(Icons.favorite),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (Set<UserRole> newSelection) {
                    setState(() {
                      _selectedRole = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+91 ',
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Required";
                    final regex = RegExp(r'^[6-9]\d{9}$');
                    if (!regex.hasMatch(v.trim())) {
                      return "Enter a valid 10-digit Indian phone number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => !v!.contains('@') ? "Invalid email" : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Required";
                    if (v != _passwordController.text) return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: isLoading ? null : _handleRegister,
                  child: isLoading
                      ? CircularProgressIndicator.adaptive(backgroundColor: Theme.of(context).colorScheme.onPrimary)
                      : const Text("Create Account"),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.push('/role-selection');
                        },
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text("Sign up with Google"),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () {
                        context.go('/login');
                      },
                      child: const Text("Sign In"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
