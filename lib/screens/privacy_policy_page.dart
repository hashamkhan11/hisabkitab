import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''Privacy Policy

1. What We Collect

We may collect the following data:
Your name, email, and phone number (via Firebase Auth)
Contacts and transaction data saved by you
Shared contact info
Notifications data
Device tokens (for local notifications)

2. How We Use Your Data

We use your data to:
Display your contacts and transactions
Enable sharing features
Process payments via third-party providers

3. Data Sharing

We do not sell your personal data. Your data may be shared only:
With users you explicitly share data with
With Firebase (for backend services)
With payment providers if you initiate a transaction

4. Data Security

We use Firebase Authentication and Firestore security rules to protect your data. Access is controlled strictly based on your login and permissions.

5. Your Rights

You can:
Access or delete your data by contacting support
Revoke shared contact access
Uninstall the app to stop data collection

6. Changes to This Policy

We may update this Privacy Policy from time to time. We encourage you to review it periodically.

''',
          ),
        ),
      ),
    );
  }
}
                        