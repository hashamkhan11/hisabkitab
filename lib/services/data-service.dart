import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/model.dart';
import '../Models/model_data.dart';

class DataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    print(" Fetching user for UID: $uid");
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      print(" User not found for UID: $uid");
      return null;
    }

    final categories = await getCategories(uid);
    print(" User fetched: ${doc.data()?['name']}, Categories: ${categories.length}");
    return UserModel.fromMap(doc.id, doc.data()!, categories);
  }

  Future<AppData?> loadUserData(String uid) async {
    print(" Loading full AppData for UID: $uid");
    final user = await getUser(uid);
    if (user == null) {
      print("️ No user data found for UID: $uid");
      return null;
    }

    final categories = await getCategories(uid);
    List<ContactModel> allContacts = [];
    List<TransactionModel> allTransactions = [];
    List<ShareWithModel> allShareWith = [];

    for (var cat in categories) {
      final contacts = await getContacts(uid, cat.id);
      allContacts.addAll(contacts);

      for (var contact in contacts) {
        final tx = await getTransactions(uid, cat.id, contact.id);
        allTransactions.addAll(tx);

        final sw = await getShareWith(uid, cat.id, contact.id);
        allShareWith.addAll(sw);
      }
    }

    final notifications = await getNotifications(uid);
    final pendingTx = await getPendingTransactions(uid);

    final appData = AppData(
      user: user,
      categories: categories,
      contacts: allContacts,
      transactions: allTransactions,
      shareWith: allShareWith,
      pendingTransactions: pendingTx,
      notifications: notifications,
    );

    print(" AppData loaded: $appData");
    return appData;
  }

  Future<List<CategoryModel>> getCategories(String uid) async {
    print(" Fetching categories for UID: $uid");
    final snapshot = await _db.collection('users').doc(uid).collection('categories').get();
    List<CategoryModel> categories = [];
    for (var doc in snapshot.docs) {
      final contacts = await getContacts(uid, doc.id);
      categories.add(CategoryModel.fromMap(doc.id, doc.data(), contacts));
    }
    print(" Categories fetched: ${categories.length}");
    return categories;
  }

  Future<List<ContactModel>> getContacts(String uid, String categoryId) async {
    print("Fetching contacts for UID: $uid, Category: $categoryId");
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .get();
    print(" Contacts fetched: ${snapshot.docs.length}");
    return snapshot.docs.map((doc) => ContactModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<List<TransactionModel>> getTransactions(String uid, String categoryId, String contactId) async {
    print(" Fetching transactions for UID: $uid, Category: $categoryId, Contact: $contactId");
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();
    print(" Transactions fetched: ${snapshot.docs.length}");
    return snapshot.docs.map((doc) => TransactionModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<List<ShareWithModel>> getShareWith(String uid, String categoryId, String contactId) async {
    print(" Fetching shareWith for UID: $uid, Category: $categoryId, Contact: $contactId");
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('shareWith')
        .get();
    print(" ShareWith fetched: ${snapshot.docs.length}");
    return snapshot.docs.map((doc) => ShareWithModel.fromMap(doc.data())).toList();
  }

  Future<List<NotificationModel>> getNotifications(String uid) async {
    print("Fetching notifications for UID: $uid");
    final snapshot = await _db.collection('users').doc(uid).collection('notifications').orderBy('timestamp', descending: true).get();
    print(" Notifications fetched: ${snapshot.docs.length}");
    return snapshot.docs.map((doc) => NotificationModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<List<PendingTransactionModel>> getPendingTransactions(String uid) async {
    print("🔹 Fetching pending transactions for UID: $uid");
    final snapshot = await _db.collection('users').doc(uid).collection('pendingTransactions').orderBy('date', descending: true).get();
    print("✅ Pending transactions fetched: ${snapshot.docs.length}");
    return snapshot.docs.map((doc) => PendingTransactionModel.fromMap(doc.id, doc.data())).toList();
  }
}
