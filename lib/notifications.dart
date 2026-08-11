
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatelessWidget {
  final VoidCallback onBackToHome;

  const NotificationPage({required this.onBackToHome, Key? key}) : super(key: key);

  /*Future<void> acceptTransaction(Map<String, dynamic> data, String docId) async {
    final receiverId = FirebaseAuth.instance.currentUser!.uid;

    try {
      print("===========  ACCEPT TRANSACTION START ===========");
      print("   Current Receiver UID: $receiverId");
      print("   Data received in function:");
      print("   transactionId: ${data['transactionId']}");
      print("   sharedCategoryId (sender): ${data['sharedCategoryId']}");
      print("   receiverCategoryId: ${data['receiverCategoryId']}");
      print("   receiverContactId: ${data['receiverContactId']}");
      print("   senderId: ${data['senderId']}");
      print("   date: ${data['date']}");
      print("   typeOriginal: ${data['typeOriginal']}");
      print("   credit: ${data['credit']}");
      print("   note: ${data['note']}");

      // Determine correct type (use original from sender)
     // final String finalType = data['typeOriginal'] ?? data['type'];
      // Determine correct type for receiver
      String finalType = "";
      if (data['typeOriginal'] == "Send") {
        finalType = "Receive";
      } else if (data['typeOriginal'] == "Receive") {
        finalType = "Send";
      } else {
        finalType = data['typeOriginal'] ?? "Send";
      }

      // Path where transaction will be saved
      final transactionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('categories')
          .doc(data['receiverCategoryId'])
          .collection('contacts')
          .doc(data['receiverContactId'])
          .collection('transactions')
          .doc();

      print("  Transaction will be saved at:");
      print("   users/$receiverId/categories/${data['receiverCategoryId']}/contacts/${data['receiverContactId']}/transactions/${transactionRef.id}");

      await transactionRef.set({
        'date': data['date'],
        'type': finalType, // sender's original type
        'credit': data['credit'],
        'note': data['note'] ?? "",
        'senderId': data['senderId'],
        'userId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print(" Transaction saved successfully!");

      //  Remove from pendingTransactions
      final pendingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('categories')
          .doc(data['receiverCategoryId'])
          .collection('contacts')
          .doc(data['receiverContactId'])
          .collection('pendingTransactions')
          .doc(data['transactionId']);

      print(" Pending transaction will be deleted from:");
      print(" users/$receiverId/categories/${data['receiverCategoryId']}/contacts/${data['receiverContactId']}/pendingTransactions/${data['transactionId']}");

      await pendingRef.delete();
      print("️ Pending transaction ${data['transactionId']} removed");

      // Mark notification as read
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .doc(docId);

      print(" Notification $docId will be updated as read");
      await notificationRef.update({
        'isRead': true,
        'status': 'accepted',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      print(" Notification $docId marked as read ");

      //  Local Notification for receiver
      String notifyMsg = finalType == "Send"
          ? "You sent Rs.${data['credit']}."
          : "You received Rs.${data['credit']}.";

     /* await NotificationService().showNotification(
        title: 'Transaction Accepted',
        body: notifyMsg,
      );*/

      print("===========  ACCEPT TRANSACTION END ===========");
    } catch (e) {
      print(" Error accepting transaction: $e");
    }
  }*/
  /*Future<void> acceptTransaction(Map<String, dynamic> data, String docId) async {
    final receiverId = FirebaseAuth.instance.currentUser!.uid;

    try {
      print("===========  ACCEPT TRANSACTION START ===========");
      print(" Current Receiver UID: $receiverId");
      print(" Data received in function:");
      print("   transactionId: ${data['transactionId']}");
      print("   sharedCategoryId (sender): ${data['sharedCategoryId']}");
      print("   receiverCategoryId: ${data['receiverCategoryId']}");
      print("   receiverContactId: ${data['receiverContactId']}");
      print("   senderId: ${data['senderId']}");
      print("   date: ${data['date']}");
      print("   typeOriginal: ${data['typeOriginal']}");
      print("   credit: ${data['credit']}");
      print("   note: ${data['note']}");

      // Path to where we are saving transaction
      final transactionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('categories')
          .doc(data['receiverCategoryId'])
          .collection('contacts')
          .doc(data['receiverContactId'])
          .collection('transactions')
          .doc();

      print(" Transaction will be saved at:");
      print("   users/$receiverId/categories/${data['receiverCategoryId']}/contacts/${data['receiverContactId']}/transactions/${transactionRef.id}");

      await transactionRef.set({
        'date': data['date'],
        'type': data['typeOriginal'],
        'credit': data['credit'],
        'note': data['note'] ?? "",
        'senderId': data['senderId'],
        'userId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("Transaction saved successfully!");

      //  Remove from pendingTransactions
      final pendingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('categories')
          .doc(data['receiverCategoryId'])
          .collection('contacts')
          .doc(data['receiverContactId'])
          .collection('pendingTransactions')
          .doc(data['transactionId']);

      print("Pending transaction will be deleted from:");
      print("   users/$receiverId/categories/${data['receiverCategoryId']}/contacts/${data['receiverContactId']}/pendingTransactions/${data['transactionId']}");

      await pendingRef.delete();
      print("️ Pending transaction ${data['transactionId']} removed");

      //  Mark notification as read
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .doc(docId);

      print(" Notification $docId will be updated as read");
      await notificationRef.update({'isRead': true});
      print(" Notification $docId marked as read");

      print("===========  ACCEPT TRANSACTION END ===========");
    } catch (e) {
      print(" Error accepting transaction: $e");
    }
  }*/

  Future<void> acceptTransaction(Map<String, dynamic> data, String docId) async {
    final receiverId = FirebaseAuth.instance.currentUser!.uid;

    try {
      print("===========  ACCEPT TRANSACTION START ===========");
      print("Receiver UID: $receiverId");
      print("transactionId: ${data['transactionId']}");
      if (data['transactionId'] == null || (data['transactionId'] as String).isEmpty) {
        print(" Cannot accept transaction → transactionId is null/empty.");
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
      print(" Receiver transaction ${data['transactionId']} marked accepted");

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
      print(" Sender transaction $senderTransactionId marked accepted");

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
      print(" Notification $docId updated to accepted");

      print("===========  ACCEPT TRANSACTION END ===========");
    } catch (e) {
      print(" Error accepting transaction: $e");
    }
  }
  Future<void> rejectTransaction(Map<String, dynamic> data) async {
    try {
      final pendingId = data['pendingTransactionId'];
      final senderTransactionId = data['senderTransactionId'];
      final senderId = data['senderId'];
      final senderCategoryId = data['senderCategoryId'];
      final senderContactId = data['senderContactId'];

      print("------ DEBUG REJECT ------");
      print("pendingId           : $pendingId");
      print("senderTransactionId : $senderTransactionId");
      print("senderId            : $senderId");
      print("senderCategoryId    : $senderCategoryId");
      print("senderContactId     : $senderContactId");

      print("Trying to update path:");
      print("users/${FirebaseAuth.instance.currentUser!.uid}/categories/${data['receiverCategoryId']}/contacts/${data['receiverContactId']}/pendingTransactions/$pendingId");


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

      print(" Transaction rejected successfully");

    } catch (e) {
      print(" Error rejecting transaction: $e");
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
              final unread = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('notifications')
                  .where('isRead', isEqualTo: false)
                  .get();

              for (var doc in unread.docs) {
                await doc.reference.update({'isRead': true});
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
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
                 /* leading: Icon(
                    Icons.notifications,
                    color: isRead ? Colors.green : Colors.blue,
                    size: 28,
                  ),*/
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
                     /* if (data['type'] == 'transaction_request') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => acceptTransaction(data, docId),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Accept', style: TextStyle(color: Colors.black),),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => rejectTransaction(data, docId),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Reject'),
                            ),
                          ],
                        )
                      ], */
                       if (data['type'] == 'transaction_request') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                print(" Accept button clicked");

                                await acceptTransaction(data, docId);

                                print(" Transaction accepted successfully");
                              },
                              child: const Text("Accept", style: TextStyle(color: Colors.black)),
                            ),

                            /* TextButton(
                              onPressed: () async {
                                print(" Accept button clicked");

                                final pendingId = data['pendingTransactionId'];
                                final senderId = data['senderId'];
                                final sharedCategoryId = data['sharedCategoryId'];
                                final receiverContactId = data['receiverContactId'];
                              //  final receiverCategoryId = data['receiverCategoryId'];

                                print("Adding to: users/$userId/categories/$sharedCategoryId/contacts/$receiverContactId/transactions");
                                print(" pendingId: $pendingId");
                                print(" senderId: $senderId");
                                print(" sharedCategoryId: $sharedCategoryId");
                                print(" receiverContactId: $receiverContactId");

                                final pendingDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('categories')
                                    .doc(sharedCategoryId) // old working
                                   // .doc(receiverCategoryId)  //new try
                                    .collection('contacts')
                                    .doc(receiverContactId)
                                    .collection('pendingTransactions')
                                    .doc(pendingId)
                                    .get();

                                if (pendingDoc.exists) {
                                  final tx = pendingDoc.data()!;
                                  print(" Pending transaction data: $tx");

                                  // Add to receiver's transactions

                                  String finalType = "";
                                  if (tx['type'] == "Send") {
                                    finalType = "Receive";
                                  } else if (tx['type'] == "Receive") {
                                    finalType = "Send";
                                  } else {
                                    finalType = tx['type'] ?? "Send";
                                  }
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .collection('categories')
                                      .doc(sharedCategoryId)  // old working on rejection
                                     // .doc(receiverCategoryId) //new
                                      .collection('contacts')
                                      .doc(receiverContactId)
                                      .collection('transactions')
                                      .add({
                                    'date': tx['date'],
                                    'type': finalType,
                                    'credit': tx['credit'],
                                    'senderId': tx['senderId'],
                                    'receiverId': userId,
                                    'note': tx['note'] ?? "",
                                  });

                                  print(" Transaction added to receiver’s ledger");

                                  // Remove from pending
                                  await pendingDoc.reference.delete();
                                  print("️ Pending transaction removed");

                                  await docs[index].reference.update({
                                    'isRead': true,
                                    'status': 'accepted',
                                    'message': 'You accepted Rs.${tx['credit']} from ${tx['senderId']}',
                                  });

                                  print(" Notification updated as accepted");
                                } else {
                                  print(" Pending transaction NOT found for id: $pendingId");
                                }
                              },
                              child: const Text("Accept", style: TextStyle(color: Colors.black),),
                            ), */

                            TextButton(
                              onPressed: () async {
                                final pendingId = data['pendingTransactionId'];
                                final senderTransactionId = data['senderTransactionId'];
                                final senderId = data['senderId'];
                                final senderCategoryId = data['senderCategoryId'];
                                final senderContactId = data['senderContactId'];

                                print("------ DEBUG TRANSACTION DATA ------");
                                print("pendingId           : $pendingId");
                                print("senderTransactionId : $senderTransactionId");
                                print("senderId            : $senderId");
                                print("senderCategoryId    : $senderCategoryId");
                                print("senderContactId     : $senderContactId");
                                print("-----------------------------------");

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


                            /* TextButton(
                              onPressed: () async {
                                print("----------$TextButton");
                                final pendingId = data['pendingTransactionId'];

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('pendingTransactions')
                                    .doc(pendingId)
                                    .delete();

                                await docs[index].reference.update({
                                  'isRead': true,
                                  'status': 'rejected',
                                  'message': 'You rejected transaction request',
                                });
                              },
                              child: const Text("Reject", style: TextStyle(color: Colors.red)),
                            ), */
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

