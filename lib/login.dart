import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/Models/Forgot_password.dart';
import 'package:hisabshare/services/data-service.dart';
import 'package:hisabshare/signup.dart';
import 'package:hisabshare/screens/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController(); // email or mobile
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getEmailFromMobile(String mobileNo) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('mobileNo', isEqualTo: mobileNo)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['email'];
      }
    } catch (e) {
      debugPrint("Error fetching email from mobile: $e");
    }
    return null;
  }

  void _login() async {
    String identifier = _identifierController.text.trim();
    String password = _passwordController.text.trim();

    // Empty field checks
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email or mobile number.')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a password.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String emailToUse = identifier;

      // If it's mobile number, fetch email
      if (!identifier.contains('@')) {
        String? fetchedEmail = await _getEmailFromMobile(identifier);
        if (fetchedEmail == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect email or password.')),
          );
          return;
        }
        emailToUse = fetchedEmail;
      }

      await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

     /* final uid = _auth.currentUser!.uid;   //loading at login
      final dataService = DataService();
      final appData = await dataService.loadUserData(uid);
      print("### Loaded data: $appData"); */

      if (!_auth.currentUser!.emailVerified) {
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email before logging in.')),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Homepage(
            onThemeToggle: (value) {},
            isDarkMode: false,
          ),
        ),
      );
       /* print("UID: $uid");     //for loading at login
      print("AppData after load: $appData");
      if (appData != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Homepage(
              onThemeToggle: (value) {},
              isDarkMode: false,
              appData: appData, // ab safe hai
            ),
          ),
        );
      } else {
        print("No data found for this user!");
      }*/

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful!')),
      );
    } on FirebaseAuthException catch (e) {
      //  Handle ALL known FirebaseAuth errors with friendly text
      const incorrectCredCodes = [
        'wrong-password',
        'user-not-found',
        'invalid-email',
        'invalid-credential',
      ];

      if (incorrectCredCodes.contains(e.code)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect email or password.')),
        );
      } else if (e.code == 'too-many-requests') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Too many attempts. Please try again later.')),
        );
      } else {
        //
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Please try again.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                // Email or Mobile Field
                TextField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    hintText: 'Email or Mobile Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ForgotPassword()),
      );
    },
    child: const Text(
      'Forget password',
      style: TextStyle(color: Color.fromARGB(255, 137, 190, 79)),
    ),
  ),
),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 137, 190, 79),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Need to create an account? '),
                    GestureDetector(
                      onTap: _navigateToSignup,
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                         color: Color.fromARGB(255, 137, 190, 79),
                        // color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
