import 'package:flutter/material.dart';

import '../widgets/legal_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPage(
      title: 'Privacy Policy',
      icon: Icons.privacy_tip_outlined,
      intro: 'How HisabKitab collects, uses, and protects your data.',
      sections: [
        LegalSection(
          '1. What We Collect',
          'Your name, email, and phone number (via Firebase Auth); contacts and transaction data you save; shared contact info; notifications data; and device tokens for local notifications.',
        ),
        LegalSection(
          '2. How We Use Your Data',
          'We use your data to display your contacts and transactions, enable sharing features, and process payments via third-party providers.',
        ),
        LegalSection(
          '3. Data Sharing',
          "We do not sell your personal data. Your data may be shared only with users you explicitly share data with, with Firebase (for backend services), and with payment providers if you initiate a transaction.",
        ),
        LegalSection(
          '4. Data Security',
          'We use Firebase Authentication and Firestore security rules to protect your data. Access is controlled strictly based on your login and permissions.',
        ),
        LegalSection(
          '5. Your Rights',
          'You can access or delete your data by contacting support, revoke shared contact access, or uninstall the app to stop data collection.',
        ),
        LegalSection(
          '6. Changes to This Policy',
          'We may update this Privacy Policy from time to time. We encourage you to review it periodically.',
        ),
      ],
    );
  }
}
