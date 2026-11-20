import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends a transactional email to a member of the same Cookidea project.
/// The Edge Function validates the current session and project permissions.
class ProjectEmailService {
  ProjectEmailService._();

  static Future<void> send({
    required String projectId,
    required String recipientUserId,
    required String subject,
    required String message,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'send-project-email',
      body: {
        'project_id': projectId,
        'recipient_user_id': recipientUserId,
        'subject': subject,
        'message': message,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final payload = response.data;
      final code = payload is Map ? payload['error']?.toString() : null;
      throw FunctionException(
        status: response.status,
        details: response.data,
        reasonPhrase: code ?? 'Project email request failed',
      );
    }
  }
}
