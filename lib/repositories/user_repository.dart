import '../services/api_client.dart';

/// Centralizes access to the authenticated user's profile against `/api/me`
/// and the unauthenticated mobile->email lookup used by the login screen.
class UserRepository {
  static Future<Map<String, dynamic>?> getMe() async {
    final data = await ApiClient.instance.get('/me');
    return data as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> updateMe({
    String? username,
    String? mobileNo,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{
      if (username != null) 'username': username,
      if (mobileNo != null) 'mobile_no': mobileNo,
      if (imageUrl != null) 'image_url': imageUrl,
    };
    final data = await ApiClient.instance.patch('/me', body: body);
    return data as Map<String, dynamic>;
  }

  /// Returns the email registered against [mobileNo], or null if none exists.
  static Future<String?> lookupEmailByMobile(String mobileNo) async {
    try {
      final data = await ApiClient.instance.get('/users/lookup', query: {'mobile_no': mobileNo});
      return (data as Map<String, dynamic>?)?['email'] as String?;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
