import 'package:flutter/material.dart';

import '../repositories/contact_repository.dart';
import '../theme/app_theme.dart';

class SharedUserInfoBottomSheet extends StatefulWidget {
  final String contactId;
  final Map<String, dynamic> sharedUser;

  const SharedUserInfoBottomSheet({
    required this.contactId,
    required this.sharedUser,
    super.key,
  });

  @override
  State<SharedUserInfoBottomSheet> createState() =>
      _SharedUserInfoBottomSheetState();
}

class _SharedUserInfoBottomSheetState
    extends State<SharedUserInfoBottomSheet> {
  late final String? uidToRemove;

  @override
  void initState() {
    super.initState();
    uidToRemove = widget.sharedUser['uid'];
  }

  Future<void> _removeSharedUser() async {
    if (uidToRemove == null) {
      Navigator.of(context).pop("failed");
      return;
    }

    try {
      await ContactRepository.unshare(
        contactId: widget.contactId,
        sharedUserId: uidToRemove!,
      );
      if (!mounted) return;
      Navigator.of(context).pop("removed");
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop("failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, color: c.accentStrong, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Shared User Info', style: Theme.of(context).textTheme.titleLarge),
            Divider(height: 30, thickness: 1, color: c.border),
            _infoRow(context, Icons.person_outline_rounded, widget.sharedUser['username'] ?? 'N/A'),
            const SizedBox(height: 12),
            _infoRow(context, Icons.mail_outline_rounded, widget.sharedUser['email'] ?? 'N/A'),
            const SizedBox(height: 12),
            _infoRow(context, Icons.phone_outlined, widget.sharedUser['mobileNo'] ?? 'N/A'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _removeSharedUser,
                icon: const Icon(Icons.person_remove_rounded, size: 18),
                label: const Text('Remove access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.danger,
                  foregroundColor: c.onAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String value) {
    final c = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 14.5, color: c.textColor)),
        ),
      ],
    );
  }
}
