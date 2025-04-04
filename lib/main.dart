import 'package:flutter/material.dart';
import 'package:moneylog/screens/homepage.dart';
import 'package:moneylog/screens/intro.dart';
import 'package:moneylog/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/signup.dart';
import './screens/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xexwvjehrpjjyuvxtfnm.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhleHd2amVocnBqanl1dnh0Zm5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4NDkyMzgsImV4cCI6MjA1NzQyNTIzOH0.O6WkTxqJLoU7fdUiSW4LSJdhQs-ln-mFwupJXgttkns', 
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
      },
      home: FutureBuilder<bool>(
        future: checkFirstLaunch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == true ? IntroScreen() : AuthRedirectScreen();
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
            return HomePage(); 
          } else {
            return SignUpPage(); 
          }
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}