import 'package:flutter/material.dart';

import '../repositories/contact_repository.dart';

class SharedUserInfoBottomSheet extends StatefulWidget {
  final String contactId;
  final Map<String, dynamic> sharedUser;

  const SharedUserInfoBottomSheet({
    required this.contactId,
    required this.sharedUser,
    Key? key,
  }) : super(key: key);

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
      Navigator.of(context).pop("removed");
    } catch (e) {
      Navigator.of(context).pop("failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.blue),
            const SizedBox(height: 10),
            const Text(
              "Shared User Info",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 30, thickness: 1.2),
            _infoRow("👤 Name", widget.sharedUser['username'] ?? 'N/A'),
            const SizedBox(height: 10),
            _infoRow("📧 Email", widget.sharedUser['email'] ?? 'N/A'),
            const SizedBox(height: 10),
            _infoRow("📞 Mobile", widget.sharedUser['mobileNo'] ?? 'N/A'),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _removeSharedUser,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text("Remove Access"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF89BE4F),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
