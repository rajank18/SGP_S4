import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'login.dart'; // Import your login page

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;
    try {
      // Create User in Supabase Auth
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Get User ID
      final userId = response.user?.id;
      if (userId == null) throw "Sign-up failed!";

      // Insert into 'users' table
      await supabase.from('users').insert({
        'id': userId,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Navigate to Home Page (Replace with your route)
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 38, 38, 38),
      body: Stack(
        children: [
          // Background with sparkles and flowing lines
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height),
                painter: BackgroundPainter(animation: _animation.value),
              );
            },
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Logo with black background
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/MoneyLog (1)-2.png', // Add your logo here
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Sign Up Card
                  Padding(
                    padding: const EdgeInsets.all(11.0),
                    child: Card(
                      elevation: 8.0,
                      color: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Name",
                                  labelStyle: const TextStyle(color: Colors.grey),
                                  prefixIcon:
                                      const Icon(Icons.person, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.green),
                                  ),
                                ),
                                validator: (value) =>
                                    value!.isEmpty ? "Enter your name" : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Email",
                                  labelStyle: const TextStyle(color: Colors.grey),
                                  prefixIcon:
                                      const Icon(Icons.email, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.green),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) => value!.contains('@')
                                    ? null
                                    : "Enter a valid email",
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  labelStyle: const TextStyle(color: Colors.grey),
                                  prefixIcon:
                                      const Icon(Icons.lock, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.green),
                                  ),
                                ),
                                obscureText: true,
                                validator: (value) => value!.length >= 6
                                    ? null
                                    : "Password must be 6+ chars",
                              ),
                              const SizedBox(height: 24),
                              if (_errorMessage != null)
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              const SizedBox(height: 16),
                              _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.green)
                                  : ElevatedButton(
                                      onPressed: _signUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 50, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                        ),
                                      ),
                                      child: const Text(
                                        "Sign Up",
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.white),
                                      ),
                                    ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    _createFadeRoute(
                                        const LoginPage())), // Use fade transition
                                child: const Text(
                                  "Already have an account? Log in",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Background Animation (Same as Login Page)
class BackgroundPainter extends CustomPainter {
  final double animation;

  BackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    final random = Random();

    // Draw flowing lines
    for (int i = 0; i < 20; i++) {
      final x = size.width * random.nextDouble();
      final y = size.height * random.nextDouble();
      final dx = size.width * random.nextDouble();
      final dy = size.height * random.nextDouble();
      canvas.drawLine(Offset(x, y), Offset(dx, dy), paint);
    }

    // Draw sparkles
    for (int i = 0; i < 50; i++) {
      final x = size.width * random.nextDouble();
      final y = size.height * random.nextDouble();
      final radius = 2 * random.nextDouble();
      canvas.drawCircle(Offset(x, y), radius, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Fade Transition
Route _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300), // Adjust duration as needed
  );
}