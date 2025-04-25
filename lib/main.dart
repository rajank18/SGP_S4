import 'package:flutter/material.dart';
import 'package:moneylog/screens/homepage.dart';
import 'package:moneylog/screens/intro.dart';
import 'package:moneylog/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/signup.dart';
import './screens/login.dart';
import 'package:moneylog/config/env_config.dart';
import 'package:moneylog/services/notification_service.dart';
import 'package:workmanager/workmanager.dart';
// Import dart:async for Timer if needed, but Workmanager is preferred for background tasks
// import 'dart:async';

// Callback dispatcher for Workmanager
@pragma('vm:entry-point') // Mandatory for Workmanager
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    // Show the expense reminder notification
    NotificationService.showExpenseNotification();
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await EnvConfig.load();

  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Initialize the notification service
  await NotificationService.init();

  // Initialize Workmanager
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set to false for production
  );

  // Register periodic task for expense reminder
  // Frequency set to 2 minutes (120 seconds)
  Workmanager().registerPeriodicTask(
    "expenseReminderTask", // Unique task name
    "expenseReminder", // Task identifier
    frequency: Duration(seconds: 1), // Set to 2 minutes
    // Constraints can be added here if needed (e.g., networkType: NetworkType.connected)
  );

  // Removed NotificationScheduler as Workmanager handles background tasks
  // NotificationScheduler.start(); // Start notification scheduler

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
      },
      home: FutureBuilder<bool>(
        future: checkFirstLaunch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // Redirect based on first launch status
          return snapshot.data == true ? const IntroScreen() : const AuthRedirectScreen();
        },
      ),
    );
  }
}

// Check if the app is launched for the first time
Future<bool> checkFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  bool firstLaunch = prefs.getBool("first_launch") ?? true;
  if (firstLaunch) {
    await prefs.setBool("first_launch", false);
  }
  return firstLaunch;
}

// Redirects user based on authentication state
class AuthRedirectScreen extends StatelessWidget {
  const AuthRedirectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final session = snapshot.data?.session;
          // If user is logged in, go to HomePage, otherwise go to SignUpPage
          if (session != null) {
            return const HomePage();
          } else {
            return const SignUpPage();
          }
        }
        // Show loading indicator while checking auth state
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

// Removed NotificationScheduler as Workmanager is used for periodic tasks
/*
class NotificationScheduler {
  static Timer? _timer;

  static void start() {
    // Timer set to 2 minutes (120 seconds)
    _timer = Timer.periodic(Duration(seconds: 120), (timer) {
      NotificationService.showExpenseNotification(); // Trigger expense notification
    });
  }

  static void stop() {
    _timer?.cancel();
  }
}
*/
