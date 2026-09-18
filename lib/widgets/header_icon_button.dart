import 'package:flutter/material.dart';
import 'package:hisabshare/theme/app_theme.dart';

/// A rounded-square icon button (avatar/notification-bell style) used in
/// place of stock [IconButton]s wherever a screen needs an action in its
/// app bar, so every screen's chrome reads as the same design system.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final Color? bgColor;

  const HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconColor,
    this.bgColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final disabled = onTap == null;
    final button = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: disabled ? c.surfaceAlt : (bgColor ?? c.surface),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Icon(
            icon,
            size: 20,
            color: disabled ? c.textMuted.withValues(alpha: .4) : (iconColor ?? c.textMuted),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
