import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/repositories/user_repository.dart';
import 'package:hisabshare/screens/forgot_password.dart';
import 'package:hisabshare/screens/signup.dart';
import 'package:hisabshare/screens/home.dart';
import 'package:hisabshare/theme/app_theme.dart';

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
      return await UserRepository.lookupEmailByMobile(mobileNo);
    } catch (e) {
      debugPrint("Error fetching email from mobile: $e");
    }
    return null;
  }

  Future<void> _login() async {
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
        if (!mounted) return;
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
      if (!mounted) return;

      if (!_auth.currentUser!.emailVerified) {
        await _auth.signOut();
        if (!mounted) return;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful!')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final c = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.account_balance_wallet_rounded, color: c.accentStrong, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Log in to keep track of your ledgers', style: TextStyle(color: c.textMuted)),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      hintText: 'Email or mobile number',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ForgotPassword()),
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                            )
                          : const Text('Log in'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: c.textMuted)),
                      GestureDetector(
                        onTap: _navigateToSignup,
                        child: Text(
                          'Sign up',
                          style: TextStyle(color: c.accentStrong, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
