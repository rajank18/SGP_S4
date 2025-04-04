import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import './login.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Set entire screen background to black
      body: IntroductionScreen(
        globalBackgroundColor: Colors.black, // Ensures navbar area is black
        pages: [
          PageViewModel(
            title: "Welcome to MoneyLog",
            body: "Easily record and analyze your daily expenses.",
            image: Center(
              child: Image.asset(
                "assets/MoneyLog (1)-2.png",
                height: 200,
                width: 200,
              ),
            ),
            decoration: PageDecoration(
              pageColor: Colors.black, // Page background black
              titleTextStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White title text
              ),
              bodyTextStyle: TextStyle(
                fontSize: 18,
                color: Colors.grey[400], // Light gray body text
              ),
              imagePadding: EdgeInsets.all(20),
            ),
          ),
          PageViewModel(
            title: "Set Budget Goals",
            body: "Plan your budget and stay within your limits.",
            image: Center(
              child: Image.asset(
                "assets/budget.jpg",
                height: 200,
                width: 200,
              ),
            ),
            decoration: PageDecoration(
              pageColor: Colors.black,
              titleTextStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              bodyTextStyle: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
              imagePadding: EdgeInsets.all(20),
            ),
          ),
          PageViewModel(
            title: "Secure & Easy",
            body: "Your data is safe, and logging in is simple.",
            image: Center(
              child: Image.asset(
                "assets/MoneyLog (1)-2.png",
                height: 200,
              ),
            ),
            decoration: PageDecoration(
              pageColor: Colors.black,
              titleTextStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              bodyTextStyle: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
              imagePadding: EdgeInsets.all(20),
            ),
          ),
        ],
        onDone: () => _goToLogin(context),
        onSkip: () => _goToLogin(context),
        showSkipButton: true,
        skip: Text(
          "Skip",
          style: TextStyle(color: Colors.white), // White skip button
        ),
        next: Icon(
          Icons.arrow_forward,
          color: Colors.white, // White next icon
        ),
        done: Text(
          "Get Started",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white, // White done button
          ),
        ),
        dotsDecorator: DotsDecorator(
          size: Size(10.0, 10.0),
          activeSize: Size(22.0, 10.0),
          activeColor: Colors.green, // Green active dot
          color: Colors.grey, // Grey inactive dots
          spacing: EdgeInsets.symmetric(horizontal: 4.0),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
        ),
      ),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }
}
// kingrkr999@gmail.com