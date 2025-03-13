import 'package:flutter/material.dart';
import 'package:moneylog/screens/homepage.dart';
import 'package:moneylog/screens/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './screens/signup.dart';
import './screens/login.dart';
 // Your SignUp Page
 // Your Home Page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xexwvjehrpjjyuvxtfnm.supabase.co', // Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhleHd2amVocnBqanl1dnh0Zm5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4NDkyMzgsImV4cCI6MjA1NzQyNTIzOH0.O6WkTxqJLoU7fdUiSW4LSJdhQs-ln-mFwupJXgttkns', // Replace with your Supabase Anon Key
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoneyLog',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthRedirectScreen(),
      routes: {
        '/signup': (context) => SignUpPage(),
        '/home': (context) => HomePage(), // Ensure HomePage exists
        '/login': (context) => LoginPage(),
      },
    );
  }
}

class AuthRedirectScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final session = snapshot.data?.session;
          if (session != null) {
            return HomePage(); // User is logged in
          } else {
            return SignUpPage(); // User is not logged in
          }
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
