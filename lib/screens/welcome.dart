import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hisabshare/screens/login.dart';

void main() {
  runApp(HisabShareApp());
}

class HisabShareApp extends StatelessWidget {
  const HisabShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HisabShareHomePage(),
    );
  }
}

class HisabShareHomePage extends StatelessWidget {
  const HisabShareHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Define a consistent background color
    final backgroundColor = Color.fromARGB(255, 210, 246, 193);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Container
              Container(
                color: backgroundColor,
                padding: EdgeInsets.all(24),
                child: Image.asset(
                  'assets/logo.png',
                  height: 130, // increased size
                  width: 130, // optional, for square container
                ),
              ),

              SizedBox(height: 10),

              // Title
              Text(
                'HisabShare',

                style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.black),
                /* GoogleFonts.playfairDisplay
                 (
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
               ), */
              ),

              SizedBox(height: 40),

              // Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF89BE4F), // darker green button
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/*class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFB58B6A),
        title: Text('Login'),
      ),
      body: Center(
        child: Text(
          'Welcome to Login Screen!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}*/
