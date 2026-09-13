import '../services/api_client.dart';

/// Sends a statement PDF via the backend's Resend-powered mailer
/// (`POST /api/statements/email`).
class StatementEmailRepository {
  static Future<void> sendStatement({
    required String recipientEmail,
    required String contactName,
    required String filename,
    required String contentBase64,
  }) async {
    await ApiClient.instance.post('/statements/email', body: {
      'recipient_email': recipientEmail,
      'contact_name': contactName,
      'filename': filename,
      'content_base64': contentBase64,
      'mime': 'application/pdf',
    });
  }
}
