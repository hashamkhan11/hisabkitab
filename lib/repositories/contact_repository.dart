import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralizes Firestore access for `users/{uid}/categories/{categoryId}/contacts`.
class ContactRepository {
  static Future<String?> addContact({
    required String categoryId,
    required String categoryName,
    required Map<String, dynamic> newContact,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final name = newContact['name'];
    if (name is! String || name.isEmpty) return null;

    final contactDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc();

    final generatedId = contactDocRef.id;

    await contactDocRef.set({
      'id': generatedId,
      'name': name,
      'mobileNo': newContact['mobileNo'] ?? '',
      'email': newContact['email'] ?? '',
      'address': newContact['address'] ?? '',
      'category': categoryName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return generatedId;
  }

  static Future<void> deleteContact({
    required String categoryId,
    required String contactId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }
}
