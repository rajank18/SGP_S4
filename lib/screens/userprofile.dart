import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import './login.dart';
import 'package:url_launcher/url_launcher.dart';

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
      if (user == null) return;

      final userCheck = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .single();

      if (userCheck == null) return;

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
          if (retryCount == 3) throw e;
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (userResponse == null) throw Exception('Failed to fetch user data');

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
          if (retryCount == 3) throw e;
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}'), backgroundColor: Colors.red),
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
      final filePath = fileName;

      final bytes = await image.readAsBytes();
      final bucket = supabase.storage.from('user-images');
      await bucket.uploadBinary(filePath, bytes);

      final imageUrl = 'https://xexwvjehrpjjyuvxtfnm.supabase.co/storage/v1/object/public/user-images/$fileName';

      await supabase.from('users').update({'profile_image_url': imageUrl}).eq('id', user.id);

      setState(() {
        profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $error')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Show confirmation dialog before deleting account
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Are you sure?"),
          content: const Text(
            "This action will permanently delete your account and all associated data. Do you want to proceed?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete Account", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // Delete user from the 'users' table
        await supabase.from('users').delete().eq('id', user.id);

        // Sign out the user from Supabase Auth
        await supabase.auth.signOut();

        // Navigate to the login page after deleting the account
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController _nameController = TextEditingController(text: userName);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile', style: TextStyle(color: Colors.green)),
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.black,
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl!)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                                    style: const TextStyle(fontSize: 36, color: Colors.white),
                                  )
                                : null,
                          ),
                          Positioned(
  bottom: 0,
  right: 0,
  child: IconButton(
    icon: const Icon(Icons.edit, size: 16, color: Colors.greenAccent),
    onPressed: _uploadProfileImage,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
  ),
),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Stack(
                    children: [
                      Center(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Colors.greenAccent),
                          onPressed: () async {
                            final newName = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Edit Name"),
                                content: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(labelText: "Name"),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, _nameController.text),
                                    child: const Text("Update"),
                                  ),
                                ],
                              ),
                            );
                            if (newName != null && newName.trim().isNotEmpty) {
                              final user = supabase.auth.currentUser;
                              if (user != null) {
                                await supabase.from('users').update({'name': newName}).eq('id', user.id);
                                setState(() {
                                  userName = newName;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Name updated successfully')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.grey),

                  const SizedBox(height: 24),
                  const Text(
                    "Total Budget",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹ ${totalBudget.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.grey),

                  const SizedBox(height: 12),
                  // Contact Us with background
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'kingrkr999@gmail.com',
                          query: Uri.encodeFull('subject=App Support&body=Hello, I need help with...'),
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Could not open email app")),
                          );
                        }
                      },
                      child: const Text(
                        "Contact Us",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const SizedBox(height: 24),

                  // Delete Account button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: _deleteAccount,
                    child: const Text(
                      "Delete Account",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),

                  const Spacer(),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: () async {
                      await supabase.auth.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      "Sign Out",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
