import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './login.dart'; // Redirect to login after logout

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home Page"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              final supabase = Supabase.instance.client;
              await supabase.auth.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
            },
          )
        ],
      ),
      body: Center(
        child: Text(
          "Welcome to MoneyLog! 🎉",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
