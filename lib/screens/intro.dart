import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import './login.dart';

class IntroScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "Welcome to MoneyLog",
          body: "Easily record and analyze your daily expenses.",
          image: Center(child: Image.asset("assets/MoneyLog (1)-2.png", height: 200)),
        ),
        PageViewModel(
          title: "Set Budget Goals",
          body: "Plan your budget and stay within your limits.",
          image: Center(child: Image.asset("assets/MoneyLog (1)-2.png", height: 200)),
        ),
        PageViewModel(
          title: "Secure & Easy",
          body: "Your data is safe, and logging in is simple.",
          image: Center(child: Image.asset("assets/MoneyLog (1)-2.png", height: 200)),
        ),
      ],
      onDone: () => _goToLogin(context),
      onSkip: () => _goToLogin(context),
      showSkipButton: true,
      skip: Text("Skip"),
      next: Icon(Icons.arrow_forward),
      done: Text("Get Started", style: TextStyle(fontWeight: FontWeight.bold)),
      dotsDecorator: DotsDecorator(
        size: Size(10.0, 10.0),
        activeSize: Size(22.0, 10.0),
        activeColor: Colors.blue,
        color: Colors.grey,
        spacing: EdgeInsets.symmetric(horizontal: 4.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
  }
}
