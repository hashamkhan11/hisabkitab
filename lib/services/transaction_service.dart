import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionService {
  static Stream<List<Map<String, dynamic>>> transactionStream({
    required String uid,
    required String categoryId,
    required String contactId,
    bool filterAccepted = false,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions');

    if (filterAccepted) {
      query = query.where('status', isEqualTo: 'accepted');
    }
    return query
        .orderBy('date', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        String finalType = data['type'] ?? '';
        if (filterAccepted) {
          if (finalType == "Send") {
            finalType = "Receive";
          } else if (finalType == "Receive") {
            finalType = "Send";
          }
        }
        return {
          'id': doc.id,
          'date': (data['date'] as Timestamp).toDate(),
          'type': data['type'],
          'credit': data['credit'] ?? 0,
          'note': data['note'] ?? '',
          'status': data['status'] ?? '',
        };
      }).toList();
    });
  }

  static Future<DocumentReference<Map<String, dynamic>>> createSenderTransaction({
    required String currentUserId,
    required String categoryId,
    required String contactId,
    String? sharedUserId,
    String? sharedCategoryId,
    String? receiverContactId,
    required Map<String, dynamic> transaction,
  }) async {
    // Add to Sender's Transactions
    final senderTxnRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .add({
      'date': transaction['date'],
      'type': transaction['type'],
      'credit': transaction['credit'],
      'note': transaction['note'] ?? "",
      'timestamp': FieldValue.serverTimestamp(),

      // Sender info
      'transactionId': '',
      'userId': currentUserId,
      'senderId': currentUserId,
      'senderCategoryId': categoryId,
      'senderContactId': contactId,

      // Receiver info
      'receiverUserId': sharedUserId,
      'receiverCategoryId': sharedCategoryId,
      'receiverContactId': receiverContactId,

      // Shared structure
      'sharedUserId': null,
      'sharedCategoryId': categoryId,
      'status': 'pending',
    });
    //  transactionId update
    await senderTxnRef.update({'transactionId': senderTxnRef.id});

    return senderTxnRef;
  }

  static Future<void> fanOutToSharedUsers({
    required String currentUserId,
    required String categoryId,
    required String contactId,
    required DocumentReference<Map<String, dynamic>> senderTxnRef,
    required Map<String, dynamic> transaction,
  }) async {
    final senderSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    final senderName = senderSnap.data()?['name'] ?? 'Unknown';

    //  Loop over all shared users → Add to PENDING + Notification
    final sharedWithSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('sharedWith')
        .get();

    // helper function to reverse type
    String reversedType(String type) {
      return type == 'Send' ? 'Receive' : 'Send';
    }

    for (var doc in sharedWithSnapshot.docs) {
      final sharedUserId = doc['uid'];
      final sharedCategoryId = doc['categoryId']; //accept k lye
      final receiverContactId = doc['receiverContactId'];
      //  Add to PENDING (receiver side)
      // Make a doc with ID first
      final pendingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(sharedUserId)
          .collection('categories')
          .doc(sharedCategoryId)
          .collection('contacts')
          .doc(receiverContactId)
          .collection('transactions')
          .doc();

      // Create transaction data
      final pendingData = {
        'transactionId': pendingRef.id, //  already available
        'date': transaction['date'],
        'type': reversedType(transaction['type']),
        'typeOriginal': transaction['type'],
        'credit': transaction['credit'],
        'userId': sharedUserId,
        'senderId': currentUserId,
        'sharedCategoryId': sharedCategoryId,
        'receiverContactId': receiverContactId,
        'receiverCategoryId': sharedCategoryId,
        'sharedUserId': sharedUserId,
        'status': 'pending',
        'senderTransactionId': senderTxnRef.id,
        'senderCategoryId': categoryId,
        'senderContactId': contactId,
      };
      await pendingRef.set(pendingData);

      await pendingRef.update({'transactionId': pendingRef.id});

      //  Add Notification (receiver side, senderName)
      String notificationBody;

      if (transaction['type'].toString().toLowerCase() == 'send') {
        notificationBody = 'You received Rs.${transaction['credit']} from $senderName.';
      } else if (transaction['type'].toString().toLowerCase() == 'receive') {
        notificationBody = 'You sent Rs.${transaction['credit']} to $senderName.';
      } else {
        notificationBody = 'Transaction of Rs.${transaction['credit']} with $senderName.';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(sharedUserId)
          .collection('notifications')
          .add({
        'title': 'Payment Request',
        'body': notificationBody,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'type': 'transaction_request',
        'transactionId': pendingRef.id,
        'pendingTransactionId': pendingRef.id,
        'sharedCategoryId': sharedCategoryId,
        'receiverContactId': receiverContactId,
        'senderId': currentUserId,
        'senderName': senderName,
        'senderTransactionId': senderTxnRef.id,
        'senderCategoryId': categoryId,
        'senderContactId': contactId,
        'receiverCategoryId': sharedCategoryId,
      });
    }
  }

  // Not called from any UI yet — no delete-transaction feature exists in the
  // app today. Carried over unwired from the original file (Phase 2 cleanup).
  static Future<void> deleteTransaction({
    required String uid,
    required String categoryId,
    required String contactId,
    required String transactionId,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  static double calculateBalance(List<Map<String, dynamic>> txns) {
    double balance = 0.0;
    for (var tx in txns) {
      double amount = tx['credit'] ?? 0.0;
      if (tx['type'] == 'Receive') {
        balance += amount;
      } else if (tx['type'] == 'Send') {
        balance -= amount;
      }
    }
    return balance;
  }
}
