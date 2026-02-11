import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/registration_screen.dart';
import 'features/auth/presentation/screens/role_selection_screen.dart';
import 'features/dashboard/presentation/screens/patient_dashboard_screen.dart';
import 'features/dashboard/presentation/screens/caregiver_dashboard_screen.dart';
import 'features/dispenser/presentation/screens/device_setup_screen.dart';
import 'features/schedule/presentation/screens/schedule_screen.dart';
import 'features/schedule/presentation/screens/view_schedule_screen.dart';
import 'features/dashboard/presentation/screens/dispenser_detail_screen.dart';
import 'features/dispenser/presentation/screens/refill_screen.dart';
import 'features/dashboard/presentation/screens/dose_history_screen.dart';
import 'features/settings/presentation/screens/device_settings_screen.dart';
import 'features/settings/presentation/screens/caregiver_list_screen.dart';
import 'features/statistics/presentation/screens/statistics_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.toString() == '/login' || state.uri.toString() == '/register';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        // Redirect based on role
        if (authState.value?.role == UserRole.caregiver) {
          return '/caregiver';
        }
        return '/patient';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/patient',
        builder: (context, state) => const PatientDashboardScreen(),
      ),
      GoRoute(
        path: '/caregiver',
        builder: (context, state) => const CaregiverDashboardScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const DeviceSetupScreen(),
      ),
      GoRoute(
        path: '/schedule/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return ScheduleScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/view-schedule/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return ViewScheduleScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/dispenser/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           // reuse PatientDashboardScreen logic but specifically for this ID?
           // PatientDashboardScreen currently takes no args and uses user.linkedDispensers.first.
           // I should create a DispenserDetailScreen that takes ID.
           return DispenserDetailScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/refill/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return RefillScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return DoseHistoryScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/settings/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return DeviceSettingsScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/stats/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return StatisticsScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/settings/caregivers/:id',
        builder: (context, state) {
           final id = state.pathParameters['id']!;
           return CaregiverListScreen(dispenserId: id);
        },
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
    ],
  );
});
