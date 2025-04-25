import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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
  String? profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("No user logged in");
        return;
      }

      // First check if user exists in users table
      final userCheck = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .single();

      if (userCheck == null) {
        print("User not found in users table");
        return;
      }

      // Fetch user data with retry
      int retryCount = 0;
      Map<String, dynamic>? userResponse;
      while (retryCount < 3) {
        try {
          userResponse = await supabase
              .from('users')
              .select('name, email, profile_image_url')
              .eq('id', user.id)
              .single();
          break;
        } catch (e) {
          retryCount++;
          if (retryCount == 3) {
            print('Failed to fetch user data after 3 retries');
            throw e;
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (userResponse == null) {
        throw Exception('Failed to fetch user data');
      }

      // Fetch budgets with retry
      retryCount = 0;
      List<dynamic>? budgetResponse;
      while (retryCount < 3) {
        try {
          budgetResponse = await supabase
              .from('budgets')
              .select('amount')
              .eq('user_id', user.id);
          break;
        } catch (e) {
          retryCount++;
          if (retryCount == 3) {
            print('Failed to fetch budget data after 3 retries');
            throw e;
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }

      double budgetSum = 0.0;
      if (budgetResponse != null && budgetResponse.isNotEmpty) {
        budgetSum = budgetResponse.fold<double>(
            0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));
      }

      if (mounted) {
        setState(() {
          userName = userResponse?['name'] ?? "No Name";
          userEmail = userResponse?['email'] ?? "No Email";
          totalBudget = budgetSum;
          profileImageUrl = userResponse?['profile_image_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName; // Simplified file path

      try {
        // For web platform, we need to handle the file differently
        final bytes = await image.readAsBytes();
        final storage = supabase.storage;
        final bucket = storage.from('user-images');
        await bucket.uploadBinary(filePath, bytes);

        // Get public URL - Using the correct Supabase URL format
        final imageUrl = 'https://xexwvjehrpjjyuvxtfnm.supabase.co/storage/v1/object/public/user-images/$fileName';

        // Update user profile with new image URL
        await supabase
            .from('users')
            .update({'profile_image_url': imageUrl})
            .eq('id', user.id);

        setState(() {
          profileImageUrl = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully')),
        );
      } catch (error) {
        print('Error uploading image: $error'); // For debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $error')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $error')),
      );
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
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.green),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 246, 246, 246),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            )
          : Center(
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
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.green,
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl!)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                                    style: const TextStyle(fontSize: 30, color: Colors.white),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: _uploadProfileImage,
                              ),
                            ),
                          ),
                        ],
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
