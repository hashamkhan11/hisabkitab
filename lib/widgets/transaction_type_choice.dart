import 'package:flutter/material.dart';
import 'package:hisabshare/theme/app_theme.dart';

/// One side of the Mila/Diya (received/given) picker used everywhere a
/// transaction's direction is chosen. Pairing an icon, a bold Roman Urdu
/// label and a plain-language subtitle removes the ambiguity a bare
/// "Send"/"Receive" chip left users guessing about.
class TransactionTypeChoice extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const TransactionTypeChoice({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.bg,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? bg : c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : c.border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: .15) : c.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: selected ? color : c.textMuted, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : c.textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color.withValues(alpha: .85) : c.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
