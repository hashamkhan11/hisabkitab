/*import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  final String id;
  final String name;

  Contact({required this.id, required this.name});

  factory Contact.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }
}*/
