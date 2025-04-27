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
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('App initialization started');

  // Load environment variables
  await EnvConfig.load();

  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Initialize the notification service
  await NotificationService.init();
  print('Notification service initialized');

  // Start notification timer
  Timer.periodic(const Duration(minutes: 1), (timer) {
    NotificationService.showExpenseNotification();
  });

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
