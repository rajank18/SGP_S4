import 'package:flutter/material.dart';
import 'package:moneylog/screens/homepage.dart';
import 'package:moneylog/screens/intro.dart';
import 'package:moneylog/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/signup.dart';
import './screens/login.dart';
import 'package:moneylog/config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await EnvConfig.load();
  
  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
  
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
          return snapshot.data == true ? const IntroScreen() : const AuthRedirectScreen();
        },
      ),
    );
  }
}

Future<bool> checkFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  bool firstLaunch = prefs.getBool("first_launch") ?? true;
  if (firstLaunch) {
    await prefs.setBool("first_launch", false);
  }
  return firstLaunch;
}

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
          if (session != null) {
            return const HomePage(); 
          } else {
            return const SignUpPage(); 
          }
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}