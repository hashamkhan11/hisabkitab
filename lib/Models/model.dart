import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? id, email, name, username, mobileNo, imageUrl;
  DateTime? createdAt;
  List<CategoryModel>? categories;

  UserModel({
    this.id,
    this.email,
    this.name,
    this.username,
    this.mobileNo,
    this.imageUrl,
    this.createdAt,
    this.categories,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> data, List<CategoryModel> categories) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      mobileNo: data['mobileNo'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      categories: categories,
    );
  }
}

class CategoryModel {
   String id;
   String name;
   String title;
   int color;
   int icon;
   String iconFontFamily;
   String? iconFontPackage;
   DateTime createdAt;
   List<ContactModel> contacts;

  CategoryModel({
    required this.id,
    required this.name,
    required this.title,
    required this.color,
    required this.icon,
    required this.iconFontFamily,
    this.iconFontPackage,
    required this.createdAt,
    required this.contacts,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> data, List<ContactModel> contacts) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      color: data['color'] ?? 0,
      icon: data['icon'] ?? 0,
      iconFontFamily: data['iconFontFamily'] ?? '',
      iconFontPackage: data['iconFontPackage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      contacts: contacts,
    );
  }
}
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime timestamp;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.timestamp,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      isRead: data['isRead'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

class ContactModel {
  final String id;
  final String name;
  final String email;
  final String mobileNo;
  final String address;
  final String category;
  final DateTime createdAt;

  final String? originalContactId;
  final SharedByModel? sharedBy;
  final String? sharedCategoryId;
  final String? sharedUserId;

  ContactModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobileNo,
    required this.address,
    required this.category,
    required this.createdAt,
    this.originalContactId,
    this.sharedBy,
    this.sharedCategoryId,
    this.sharedUserId,
  });

  factory ContactModel.fromMap(String id, Map<String, dynamic> data) {
    return ContactModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      mobileNo: data['mobileNo'] ?? '',
      address: data['address'] ?? '',
      category: data['category'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),

      // Receiver-side extra fields
      originalContactId: data['originalContactId'],
      sharedCategoryId: data['sharedCategoryId'],
      sharedUserId: data['sharedUserId'],
      sharedBy: data['sharedBy'] != null
          ? SharedByModel.fromMap(data['sharedBy'])
          : null,
    );
  }
}
class SharedByModel {
  final String name;
  final String email;
  final String mobileNo;
  final String imageUrl;

  SharedByModel({
    required this.name,
    required this.email,
    required this.mobileNo,
    required this.imageUrl,
  });

  factory SharedByModel.fromMap(Map<String, dynamic> data) {
    return SharedByModel(
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      mobileNo: data['mobileNo'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}
class TransactionModel {
  final String id;
  final double credit;
  final String note;
  final DateTime date;
  final String? sharedCollectionId;
  final String? pendingTransactionId;
  final String status;

  TransactionModel({
    required this.id,
    required this.credit,
    required this.note,
    required this.date,
    this.sharedCollectionId,
    this.pendingTransactionId,
    required this.status,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      credit: (data['credit'] ?? 0).toDouble(),
      note: data['note'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      sharedCollectionId: data['sharedCategoryId'],
      pendingTransactionId: data['pendingTransactionId'],
      status: data['status'] ?? 'completed',
    );
  }
}
class ShareWithModel {
  final String uid;
  final String name;
  final String email;
  final String mobileNo;
  final String imageUrl;
  final String categoryId;
  final String contactId;
  final String receiverContactId;
  final DateTime sharedAt;

  ShareWithModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.mobileNo,
    required this.imageUrl,
    required this.categoryId,
    required this.contactId,
    required this.receiverContactId,
    required this.sharedAt,
  });

  factory ShareWithModel.fromMap(Map<String, dynamic> data) {
    return ShareWithModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      mobileNo: data['mobileNo'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      categoryId: data['categoryId'] ?? '',
      contactId: data['contactId'] ?? '',
      receiverContactId: data['receiverContactId'] ?? '',
      sharedAt: (data['sharedAt'] as Timestamp).toDate(),
    );
  }
}
class PendingTransactionModel {
  final String id;
  final double credit;
  final DateTime date;
  final String senderId;
  final String senderCategoryId;
  final String senderContactId;
  final String senderTransactionId;
  final String receiverCategoryId;
  final String receiverContactId;
  final String sharedCategoryId;
  final String sharedUserId;
  final String type;          // "Send"
  final String typeOriginal;  // "Receive"
  final String status;        // pending / accepted / rejected

  PendingTransactionModel({
    required this.id,
    required this.credit,
    required this.date,
    required this.senderId,
    required this.senderCategoryId,
    required this.senderContactId,
    required this.senderTransactionId,
    required this.receiverCategoryId,
    required this.receiverContactId,
    required this.sharedCategoryId,
    required this.sharedUserId,
    required this.type,
    required this.typeOriginal,
    required this.status,
  });

  factory PendingTransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return PendingTransactionModel(
      id: id,
      credit: (data['credit'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      senderId: data['senderId'] ?? '',
      senderCategoryId: data['senderCategoryId'] ?? '',
      senderContactId: data['senderContactId'] ?? '',
      senderTransactionId: data['senderTransactionId'] ?? '',
      receiverCategoryId: data['receiverCategoryId'] ?? '',
      receiverContactId: data['receiverContactId'] ?? '',
      sharedCategoryId: data['sharedCategoryId'] ?? '',
      sharedUserId: data['sharedUserId'] ?? '',
      type: data['type'] ?? '',
      typeOriginal: data['typeOriginal'] ?? '',
      status: data['status'] ?? '',
    );
  }
}

