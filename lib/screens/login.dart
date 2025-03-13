import 'package:flutter/material.dart';
import 'package:moneylog/screens/homepage.dart';
import 'package:moneylog/screens/signup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import './signup.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.session != null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => HomePage()));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Invalid email or password")));
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 38, 38, 38),
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
                  SizedBox(height: 30),
                  // Logo with black background
                  Container(
                    padding: EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/MoneyLog (1)-2.png', // Add your logo here
                      height: 180,
                    ),
                  ),
                  SizedBox(height: 30),
                  // Login Card
                  Padding(
                    padding: EdgeInsets.all(11.0),
                    child: Card(
                      elevation: 8.0,
                      color: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 20),
                            TextField(
                              controller: _emailController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: "Email",
                                labelStyle: TextStyle(color: Colors.grey),
                                prefixIcon:
                                    Icon(Icons.email, color: Colors.green),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: TextStyle(color: Colors.grey),
                                prefixIcon:
                                    Icon(Icons.lock, color: Colors.green),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                              ),
                              obscureText: true,
                            ),
                            SizedBox(height: 24),
                            _isLoading
                                ? CircularProgressIndicator(color: Colors.green)
                                : ElevatedButton(
                                    onPressed: _signIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 50, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30.0),
                                      ),
                                    ),
                                    child: Text(
                                      "Login",
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.white),
                                    ),
                                  ),
                            SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  _createFadeRoute(
                                      SignUpPage())), // Use fade transition
                              child: Text(
                                "Don't have an account? Sign Up",
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
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

// Custom Painter for Background Animation
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
    transitionDuration:
        Duration(milliseconds: 300), // Adjust duration as needed
  );
}
