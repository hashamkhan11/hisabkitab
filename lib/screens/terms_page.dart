import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''Terms and Conditions

1. Introduction

Welcome to HisabShare App. By using our app, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.

2. Use of the App

You must be at least 13 years old or have parental consent to use this app.
You are responsible for maintaining the confidentiality of your login credentials.
Do not use the app for illegal or unauthorized purposes.

3. User Content

You are responsible for any content you submit (e.g., contacts, transactions). Do not share data that is illegal, offensive, or violates others' privacy.

4. Sharing and Permissions

You may share your contacts and transaction history with other users.
Once shared, the recipient may view data as permitted.
You can revoke access at any time.

5. Account Termination

We reserve the right to suspend or delete your account if we suspect misuse, fraud, or violations of these terms.

6. Limitation of Liability

We are not liable for any data loss, service interruption, or damages arising from your use of the app.

7. Changes

We may update these Terms and Conditions at any time. Continued use of the app implies acceptance of the revised terms.

''',
          ),
        ),
      ),
    );
  }
}
