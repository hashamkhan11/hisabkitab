import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hisabshare/providers/current_user_provider.dart';
import 'package:hisabshare/theme/app_theme.dart';

/// Avatar + greeting + notification bell, shared by every top-level tab
/// (Dashboard, Categories) so they read as one app rather than a set of
/// screens bolted together.
class AppHeader extends StatelessWidget {
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  const AppHeader({required this.onOpenProfile, required this.onOpenNotifications, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        GestureDetector(
          onTap: onOpenProfile,
          child: Consumer<CurrentUserProvider>(
            builder: (context, userProvider, _) {
              final imageUrl = userProvider.user?['image_url'] as String?;
              return CircleAvatar(
                radius: 22,
                backgroundColor: c.accentSoft,
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(imageUrl) as ImageProvider
                    : null,
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? Icon(Icons.person_rounded, color: c.accentStrong)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Consumer<CurrentUserProvider>(
            builder: (context, userProvider, _) {
              final name = (userProvider.user?['username'] as String?)?.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back', style: TextStyle(color: c.textMuted, fontSize: 12)),
                  Text(
                    (name == null || name.isEmpty) ? 'HisabShare' : name,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ),
        GestureDetector(
          onTap: onOpenNotifications,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.notifications_rounded, color: c.textMuted, size: 20),
          ),
        ),
      ],
    );
  }
}
