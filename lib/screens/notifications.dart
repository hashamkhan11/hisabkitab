
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hisabshare/repositories/notification_repository.dart';

class NotificationPage extends StatelessWidget {
  final VoidCallback onBackToHome;

  const NotificationPage({required this.onBackToHome, Key? key}) : super(key: key);

  Future<void> acceptTransaction(Map<String, dynamic> data, String docId) async {
    final receiverId = FirebaseAuth.instance.currentUser!.uid;

    try {
      if (data['transactionId'] == null || (data['transactionId'] as String).isEmpty) {
        return; // function yahin se exit ho jayega
      }
      final String receiverCategoryId = data['receiverCategoryId'];
      final String receiverContactId = data['receiverContactId'];
      final String senderId = data['senderId'];
      final String senderTransactionId = data['senderTransactionId'];
      final String senderCategoryId = data['senderCategoryId'];
      final String senderContactId = data['senderContactId'];

      //  Update receiver’s transaction status
      final receiverTxnRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('categories')
          .doc(receiverCategoryId)
          .collection('contacts')
          .doc(receiverContactId)
          .collection('transactions')
          .doc(data['transactionId']);

      await receiverTxnRef.update({'status': 'accepted'});

      //  Update sender’s transaction status
      final senderTxnRef = FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .collection('categories')
          .doc(senderCategoryId)
          .collection('contacts')
          .doc(senderContactId)
          .collection('transactions')
          .doc(senderTransactionId);

      await senderTxnRef.update({'status': 'accepted'});

      //  Update notification
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .doc(docId);

      await notificationRef.update({
        'isRead': true,
        'status': 'accepted',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
    }
  }
  Future<void> rejectTransaction(Map<String, dynamic> data) async {
    try {
      final pendingId = data['pendingTransactionId'];
      final senderTransactionId = data['senderTransactionId'];
      final senderId = data['senderId'];
      final senderCategoryId = data['senderCategoryId'];
      final senderContactId = data['senderContactId'];

      // 1) Update pendingTransaction status → rejected
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid) // receiver
          .collection('categories')
          .doc(data['receiverCategoryId'])
          .collection('contacts')
          .doc(data['receiverContactId'])
          .collection('pendingTransactions')
          .doc(pendingId)
          .update({'status': 'rejected'});

      // 2) Update sender’s transaction → rejected
      if (senderTransactionId != null &&
          senderCategoryId != null &&
          senderContactId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId) // sender user
            .collection('categories')
            .doc(senderCategoryId)
            .collection('contacts')
            .doc(senderContactId)
            .collection('transactions')
            .doc(senderTransactionId)
            .update({'status': 'rejected'});
      }

    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    final userId = user.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackToHome,
        ),
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? const Color(0xFF89BE4F),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all, color: Colors.white),
            onPressed: () async {
              await NotificationRepository.markAllRead(userId);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationRepository.notificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading notifications'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final title = data['title'] ?? 'No Title';
              final body = data['body'] ?? 'No Body';
              final timestamp = data['timestamp'] as Timestamp?;
              final time = timestamp != null
                  ? DateFormat('MMM d, yyyy • hh:mm a').format(timestamp.toDate())
                  : '';

              final isRead = data['isRead'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: isRead ? 2 : 5,
                color: isRead ? Colors.white : Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () async {
                    if (!isRead) {
                      await docs[index].reference.update({'isRead': true});
                    }
                  },
                  leading: Icon(
                    Icons.notifications,
                    color: data['status'] == 'rejected'
                        ? Colors.red
                        : (isRead ? Colors.green : Colors.blue),
                    size: 28,
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(body, style: TextStyle(color: Colors.black.withOpacity(0.8))),
                      const SizedBox(height: 4),
                      Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                       if (data['type'] == 'transaction_request') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await acceptTransaction(data, docId);
                              },
                              child: const Text("Accept", style: TextStyle(color: Colors.black)),
                            ),

                            TextButton(
                              onPressed: () async {
                                //  only call rejectTransaction
                                await rejectTransaction(data);

                                // update notification doc only
                                await docs[index].reference.update({
                                  'isRead': true,
                                  'status': 'rejected',
                                  'message': 'You rejected transaction request',
                                });
                              },
                              child: const Text("Reject", style: TextStyle(color: Colors.red)),
                            )
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

