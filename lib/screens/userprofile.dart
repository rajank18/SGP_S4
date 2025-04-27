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

class _UserProfileState extends State<UserProfile> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String userName = "";
  String userEmail = "";
  double totalBudget = 0.0;
  String? profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
    _fetchUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 0,
                  backgroundColor: Colors.black,
                  pinned: true,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.green),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text('Profile', style: TextStyle(color: Colors.green)),
                ),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Profile Section
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.green.withOpacity(0.1),
                                Colors.black,
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              // Profile Image
                              GestureDetector(
                                onTap: _uploadProfileImage,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 2,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.black,
                                        backgroundImage: profileImageUrl != null
                                            ? NetworkImage(profileImageUrl!)
                                            : null,
                                        child: profileImageUrl == null
                                            ? Text(
                                                userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                                                style: const TextStyle(fontSize: 32, color: Colors.white),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.edit, size: 18, color: Colors.green),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              // Name and Email
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Center(
                                          child: Text(
                                            userName,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () async {
                                              final newName = await showDialog<String>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: Colors.grey[900],
                                                  title: const Text("Edit Name", style: TextStyle(color: Colors.white)),
                                                  content: TextField(
                                                    controller: _nameController,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: InputDecoration(
                                                      labelText: "Name",
                                                      labelStyle: const TextStyle(color: Colors.grey),
                                                      enabledBorder: const UnderlineInputBorder(
                                                        borderSide: BorderSide(color: Colors.grey),
                                                      ),
                                                      focusedBorder: const UnderlineInputBorder(
                                                        borderSide: BorderSide(color: Colors.green),
                                                      ),
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                      ),
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
                                            child: const Icon(Icons.edit, size: 18, color: Colors.green),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      userEmail,
                                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Budget Section
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Total Budget",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "₹ ${totalBudget.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                          child: Column(
                            children: [
                              // Contact Support
                              SizedBox(
                                width: 150,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final Uri emailLaunchUri = Uri(
                                      scheme: 'mailto',
                                      path: 'kingrkr999@gmail.com',
                                      query: Uri.encodeFull('subject=App Support&body=Hello, I need help with...'),
                                    );

                                    if (await canLaunchUrl(emailLaunchUri)) {
                                      await launchUrl(emailLaunchUri, mode: LaunchMode.platformDefault);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Could not open email app")),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.email, color: Colors.white, size: 18),
                                  label: const Text(
                                    "Contact Us",
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 146, 146, 228),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12,),
                              // Sign Out Button
                              SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await supabase.auth.signOut();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LoginPage()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Sign Out",
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Delete Account Button
                              SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: _deleteAccount,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Delete Account",
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
