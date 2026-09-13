import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hisabshare/screens/home.dart';
import 'package:hisabshare/screens/login.dart';
import 'package:hisabshare/theme/app_theme.dart';

void main() {
  runApp(HisabShareApp());
}

class HisabShareApp extends StatelessWidget {
  const HisabShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AuthGate();
  }
}

/// Restores an already-verified, already-signed-in session on cold start.
/// Without this check, every fresh process start (e.g. after force-stop)
/// dropped straight to the Welcome/Login screen even though Firebase still
/// had a valid persisted session - it just was never asked.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user != null && user.emailVerified) {
          return Homepage(onThemeToggle: (_) {}, isDarkMode: false);
        }
        return const HisabShareHomePage();
      },
    );
  }
}

class HisabShareHomePage extends StatelessWidget {
  const HisabShareHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/logo.png',
                  height: 110,
                  width: 110,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'HisabShare',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track shared expenses, effortlessly',
                style: TextStyle(fontSize: 15, color: c.textMuted),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: 220,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: const Text('Get started', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
