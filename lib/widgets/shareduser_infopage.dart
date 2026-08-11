import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SharedUserInfoBottomSheet extends StatefulWidget {
  final String contactId;
  final String categoryId;
  final Map<String, dynamic> sharedUser;

  const SharedUserInfoBottomSheet({
    required this.contactId,
    required this.categoryId,
    required this.sharedUser,
    Key? key,
  }) : super(key: key);

  @override
  State<SharedUserInfoBottomSheet> createState() =>
      _SharedUserInfoBottomSheetState();
}

class _SharedUserInfoBottomSheetState
    extends State<SharedUserInfoBottomSheet> {
  late final String? userId;
  late final String? uidToRemove;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    uidToRemove = widget.sharedUser['uid'];
  }
Future<void> _removeSharedUser() async {
  if (uidToRemove == null || userId == null) {
    Navigator.of(context).pop("failed");
    return;
  }

  if (uidToRemove == userId) {
    Navigator.of(context).pop("failed");
    return;
  }
  try {
    // Step 1: Delete from sender's sharedWith
    final sharedWithPath =
        'users/$userId/categories/${widget.categoryId}/contacts/${widget.contactId}/sharedWith/$uidToRemove';
    await FirebaseFirestore.instance.doc(sharedWithPath).delete();
    debugPrint(" Deleted sharedWith doc from sender side: $sharedWithPath");

    // Step 2: Delete reversed contact from any category of the receiver
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uidToRemove)
        .collection('categories')
        .get();

    bool foundAndDeleted = false;

    for (var cat in categoriesSnapshot.docs) {
      final contactsQuery = await cat.reference
          .collection('contacts')
          .where('originalContactId', isEqualTo: widget.contactId)
          .get();

      for (var doc in contactsQuery.docs) {
        await doc.reference.delete();
        debugPrint(" Deleted reversed contact from receiver side: ${doc.reference.path}");
        foundAndDeleted = true;
      }
    }

    if (!foundAndDeleted) {
      debugPrint("️ No reversed contact found with originalContactId = ${widget.contactId}");
    }

    Navigator.of(context).pop("removed"); // Notify parent: success
  } catch (e) {
    debugPrint(" Error during access removal: $e");
    Navigator.of(context).pop("failed"); // Notify parent: failure
  }
}

 /* Future<void> _removeSharedUser() async {
    if (uidToRemove == null || userId == null) {
      Navigator.of(context).pop("failed");
      return;
    }

    if (uidToRemove == userId) {
      Navigator.of(context).pop("failed");
      return;
    }

    try {
      // Delete from sender's sharedWith
      final sharedWithPath =
          'users/$userId/categories/${widget.categoryId}/contacts/${widget.contactId}/sharedWith/$uidToRemove';
      await FirebaseFirestore.instance.doc(sharedWithPath).delete();
      debugPrint(" Deleted sharedWith doc from sender side: $sharedWithPath");

      // Delete reversed contact from receiver side
      final receiverCategoryId =
          widget.sharedUser['categoryId'] ?? widget.categoryId;

      final reversedQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uidToRemove)
          .collection('categories')
          .doc(receiverCategoryId)
          .collection('contacts')
          .where('originalContactId', isEqualTo: widget.contactId)
          .get();

      for (var doc in reversedQuery.docs) {
        await doc.reference.delete();
        debugPrint(
            " Deleted reversed contact from receiver side: ${doc.reference.path}");
      }

      Navigator.of(context).pop("removed"); //  Signal success to parent
    } catch (e) {
      debugPrint(" Error during access removal: $e");
      Navigator.of(context).pop("failed"); //  Signal failure to parent
    }
  }*/

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
