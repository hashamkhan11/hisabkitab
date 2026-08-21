import '../services/api_client.dart';

/// Centralizes contact + contact-sharing access against the Laravel API
/// (`/api/categories/{categoryId}/contacts`, `/api/contacts/{contactId}/...`).
///
/// Contacts stay plain `Map<String,dynamic>` (matching the API's snake_case
/// JSON shape directly) rather than a model class, since the rest of the app
/// (`detail.dart`, `contact_detail.dart`) already treats contacts as raw maps
/// throughout and no `ContactModel` exists.
class ContactRepository {
  /// Each contact map includes a computed `balance` plus `total_receive`/
  /// `total_send` (category-scoped gross sums, for summary cards).
  static Future<List<Map<String, dynamic>>> listContacts(String categoryId) async {
    final data = await ApiClient.instance.get('/categories/$categoryId/contacts') as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> addContact({
    required String categoryId,
    required String name,
    String? mobileNo,
    String? email,
    String? address,
  }) async {
    final data = await ApiClient.instance.post('/categories/$categoryId/contacts', body: {
      'name': name,
      if (mobileNo != null) 'mobile_no': mobileNo,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> deleteContact(String contactId) async {
    await ApiClient.instance.delete('/contacts/$contactId');
  }

  /// Shares [contactId] into [categoryId] on the current user's side.
  /// Returns `{contact, share}` - the new receiver-side contact plus the
  /// share record - atomically created server-side (transactions copied +
  /// reversed in the same request).
  static Future<Map<String, dynamic>> shareContact({
    required String contactId,
    required String categoryId,
    bool allowReceiverToAddTransactions = false,
  }) async {
    final data = await ApiClient.instance.post('/contacts/$contactId/share', body: {
      'category_id': categoryId,
      'allow_receiver_to_add_transactions': allowReceiverToAddTransactions,
    });
    return data as Map<String, dynamic>;
  }

  /// Whether the current user has already accepted a share for [contactId],
  /// and if so, where it landed (`receiver_category_id`/`receiver_contact_id`).
  static Future<Map<String, dynamic>> pendingShare(String contactId) async {
    final data = await ApiClient.instance.get('/contacts/$contactId/pending-share');
    return data as Map<String, dynamic>;
  }

  /// All users [contactId] (owned by the current user) has been shared with.
  static Future<List<Map<String, dynamic>>> shares(String contactId) async {
    final data = await ApiClient.instance.get('/contacts/$contactId/shares') as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> unshare({required String contactId, required String sharedUserId}) async {
    await ApiClient.instance.delete('/contacts/$contactId/shares/$sharedUserId');
  }

  /// Reads `allow_receiver_to_add_transactions` off the current user's own
  /// (receiver-side, `is_shared_view`) copy of [contactId].
  static Future<bool> sharePermission(String contactId) async {
    final data = await ApiClient.instance.get('/contacts/$contactId/share-permission') as Map<String, dynamic>;
    return data['allow_receiver_to_add_transactions'] == true;
  }
}
