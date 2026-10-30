import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/advisor_conversation_model.dart';
import '../../../models/advisor_message_model.dart';

/// Result of one successful question -> answer round trip.
class AdvisorReplyResult {
  final String conversationID;
  final AdvisorMessageModel userMessage;
  final AdvisorMessageModel reply;

  AdvisorReplyResult({
    required this.conversationID,
    required this.userMessage,
    required this.reply,
  });
}

/// Error with a message that is safe to show to the user.
class AdvisorException implements Exception {
  final String code;
  final String message;

  AdvisorException(this.code, this.message);

  @override
  String toString() => message;
}

class CareerAdvisorController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => _supabase.auth.currentUser!.id;

  static const int maxMessageLength = 2000;

  /// Sends a question to the `career-advisor` Edge Function.
  /// Pass [conversationID] = null to start a new conversation.
  Future<AdvisorReplyResult> sendMessage({
    required String message,
    String? conversationID,
  }) async {
    final text = message.trim();

    // Use case A2: empty message validation (also checked on the server)
    if (text.isEmpty) {
      throw AdvisorException(
        'empty_message',
        'Please enter a question for the advisor.',
      );
    }
    if (text.length > maxMessageLength) {
      throw AdvisorException(
        'message_too_long',
        'Please keep your message under $maxMessageLength characters.',
      );
    }

    try {
      final response = await _supabase.functions
          .invoke(
            'career-advisor',
            body: {'message': text, 'conversationId': conversationID},
          )
          .timeout(const Duration(seconds: 35));

      final data = response.data as Map<String, dynamic>;
      return AdvisorReplyResult(
        conversationID: data['conversationId'] as String,
        userMessage: AdvisorMessageModel.fromJson(
          data['userMessage'] as Map<String, dynamic>,
        ),
        reply: AdvisorMessageModel.fromJson(
          data['reply'] as Map<String, dynamic>,
        ),
      );
    } on FunctionException catch (e) {
      // The Edge Function returns { error, message } for every failure
      final details = e.details;
      if (details is Map && details['message'] is String) {
        throw AdvisorException(
          (details['error'] ?? 'error').toString(),
          details['message'] as String,
        );
      }
      debugPrint('career-advisor FunctionException: ${e.status} ${e.details}');
      throw AdvisorException('ai_unavailable', _unavailableMessage);
    } catch (e) {
      // Use case A1: timeout / no internet / unexpected response
      debugPrint('career-advisor error: $e');
      throw AdvisorException('ai_unavailable', _unavailableMessage);
    }
  }

  static const String _unavailableMessage =
      'The AI Advisor is currently unavailable. Please try again later.';

  /// Past conversations, newest first.
  Future<List<AdvisorConversationModel>> fetchConversations() async {
    try {
      final response = await _supabase
          .from(TableConstants.advisorConversation)
          .select()
          .eq('seekerID', _currentSeekerID)
          .order('updatedAt', ascending: false);

      return (response as List<dynamic>)
          .map((json) =>
              AdvisorConversationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching advisor conversations: $e');
      return [];
    }
  }

  /// All messages of one conversation, oldest first.
  Future<List<AdvisorMessageModel>> fetchMessages(String conversationID) async {
    try {
      final response = await _supabase
          .from(TableConstants.advisorMessage)
          .select('messageID, conversationID, role, content, createdAt')
          .eq('conversationID', conversationID)
          .order('createdAt', ascending: true);

      return (response as List<dynamic>)
          .map((json) =>
              AdvisorMessageModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching advisor messages: $e');
      return [];
    }
  }

  /// Deletes a conversation (its messages are removed by ON DELETE CASCADE).
  Future<bool> deleteConversation(String conversationID) async {
    try {
      await _supabase
          .from(TableConstants.advisorConversation)
          .delete()
          .eq('conversationID', conversationID)
          .eq('seekerID', _currentSeekerID);
      return true;
    } catch (e) {
      debugPrint('Error deleting advisor conversation: $e');
      return false;
    }
  }
}
