import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hisabshare/repositories/notification_repository.dart';
import 'package:hisabshare/services/transaction_service.dart';

class NotificationPage extends StatelessWidget {
  final VoidCallback onBackToHome;

  const NotificationPage({required this.onBackToHome, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              await NotificationRepository.markAllRead();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationRepository.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading notifications'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final data = items[index];
              final id = data['id'] as String;
              final title = data['title'] ?? 'No Title';
              final body = data['body'] ?? 'No Body';
              final createdAt = data['created_at'] as String?;
              final time = createdAt != null
                  ? DateFormat('MMM d, yyyy • hh:mm a').format(DateTime.parse(createdAt))
                  : '';

              final isRead = data['is_read'] == true;

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
                      await NotificationRepository.markRead(id);
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
                                final transactionId = data['transaction_id'] as String?;
                                if (transactionId == null) return;
                                try {
                                  await TransactionService.acceptTransaction(transactionId);
                                } catch (_) {}
                              },
                              child: const Text("Accept", style: TextStyle(color: Colors.black)),
                            ),
                            TextButton(
                              onPressed: () async {
                                final transactionId = data['transaction_id'] as String?;
                                if (transactionId == null) return;
                                try {
                                  await TransactionService.rejectTransaction(transactionId);
                                } catch (_) {}
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
