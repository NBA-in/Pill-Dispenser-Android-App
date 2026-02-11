import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notifications/notification_service.dart';
import 'router.dart';
import 'features/dispenser/presentation/controllers/notification_sync_manager.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence
  try {
    // enablePersistence is deprecated/removed in v6+. Use settings instead.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
     debugPrint("Persistence Init Error: $e");
  }

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('app_settings'); // Global settings box

  // Initialize Notifications
  try {
     final notificationService = NotificationService();
     await notificationService.initialize();
  } catch (e) {
     debugPrint("Notification Init Error: $e");
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate Notification Sync
    ref.watch(notificationSyncLogicProvider);
    
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CFP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Supports dark mode
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
      ],
    );
  }
}