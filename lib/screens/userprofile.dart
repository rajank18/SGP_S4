import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class userprofile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return Center(
      child: Text(
        user != null ? "Welcome To Money Log ${user.email}" : "No user logged in",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

