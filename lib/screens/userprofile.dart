import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './login.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final supabase = Supabase.instance.client;
  String userName = "";
  String userEmail = "";
  double totalBudget = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final userResponse = await supabase
          .from('users')
          .select('name, email')
          .eq('id', user.id)
          .single();

      final budgetResponse = await supabase
          .from('budgets')
          .select('amount')
          .eq('user_id', user.id);

      double budgetSum = budgetResponse.isNotEmpty
          ? budgetResponse.fold<double>(
              0.0, (sum, item) => sum + (item['amount'] as double))
          : 0.0;

      setState(() {
        userName = userResponse['name'] ?? "No Name";
        userEmail = userResponse['email'] ?? "No Email";
        totalBudget = budgetSum;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () {
            Navigator.pop(context); // 👈 This takes user back
          },
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.green),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 246, 246, 246),
      body: Center(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.black,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                    style: const TextStyle(fontSize: 30, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  userEmail,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  "Total Budget",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  " ${totalBudget.toStringAsFixed(2)} ₹",
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent),
                  onPressed: () async {
                    await supabase.auth.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text("Sign Out"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
