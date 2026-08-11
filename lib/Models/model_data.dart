import 'model.dart';

class AppData {
  final UserModel user;
  final List<CategoryModel> categories;
  final List<ContactModel> contacts;
  final List<TransactionModel> transactions;
  final List<ShareWithModel> shareWith;
  final List<PendingTransactionModel> pendingTransactions;
  final List<NotificationModel> notifications;

  AppData({
    required this.user,
    required this.categories,
    required this.contacts,
    required this.transactions,
    required this.shareWith,
    required this.pendingTransactions,
    required this.notifications,
  });

  @override
  String toString() {
    return '''
    AppData(
      user: ${user.name}, 
      categories: ${categories.length}, 
      contacts: ${contacts.length}, 
      transactions: ${transactions.length}, 
      shareWith: ${shareWith.length},
      notifications: ${notifications.length}, 
      pendingTx: ${pendingTransactions.length}
    )
    ''';
  }
}
