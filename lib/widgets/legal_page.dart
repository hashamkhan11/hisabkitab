import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One numbered section of a legal document (heading + body paragraph).
class LegalSection {
  final String heading;
  final String body;

  const LegalSection(this.heading, this.body);
}

/// Shared scaffold for Privacy Policy / Terms of Use style screens: a themed
/// icon header followed by clearly separated, readable sections, replacing a
/// single unformatted text block.
class LegalPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String intro;
  final List<LegalSection> sections;

  const LegalPage({
    required this.title,
    required this.icon,
    required this.intro,
    required this.sections,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, color: c.accentStrong, size: 30),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(intro, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, height: 1.4)),
          const SizedBox(height: 24),
          for (final section in sections)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.textColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: TextStyle(color: c.textMuted, fontSize: 13.5, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
