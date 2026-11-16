import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/advisor_conversation_model.dart';
import '../../../models/advisor_message_model.dart';
import '../../../core/utils/session_helper.dart';

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

/// AI Career Advisor: the open conversation (state for the chat screen)
/// plus loading, sending and deleting conversations.
class CareerAdvisorController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  static const int maxMessageLength = 2000;

  // ---------------------------------------------------------------------
  // State of the open conversation
  // ---------------------------------------------------------------------

  final List<AdvisorMessageModel> _messages = [];
  String? _conversationID;
  String? _conversationTitle;
  bool _isLoadingHistory = false;
  bool _isSending = false;
  bool _disposed = false;

  /// Increases on every conversation switch, so a slow, older load can't
  /// show its messages under the conversation the user opened afterwards.
  int _historyRequest = 0;

  List<AdvisorMessageModel> get messages => List.unmodifiable(_messages);
  String? get conversationID => _conversationID;
  String? get conversationTitle => _conversationTitle;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isSending => _isSending;

  /// Shows a past conversation. Returns an error message, or null.
  Future<String?> openConversation(String conversationID, {String? title}) async {
    // While a reply is on its way it belongs to the open conversation: switching
    // now would put that reply (and the next question) in the wrong chat.
    if (_isSending) return 'Please wait for the advisor to reply first.';
    final request = ++_historyRequest;
    _isLoadingHistory = true;
    _conversationID = conversationID;
    _conversationTitle = title;
    _messages.clear();
    _notify();

    try {
      final messages = await fetchMessages(conversationID);
      if (request != _historyRequest) return null; // a newer tap won
      _messages.addAll(messages);
      return null;
    } on DataLoadException catch (e) {
      if (request != _historyRequest) return null;
      return e.message;
    } finally {
      if (request == _historyRequest) {
        _isLoadingHistory = false;
        _notify();
      }
    }
  }

  /// Clears the screen for a new conversation (ignored while sending).
  void startNewConversation() {
    if (_isSending) return;
    _historyRequest++; // ignore any conversation still loading
    _isLoadingHistory = false;
    _conversationID = null;
    _conversationTitle = null;
    _messages.clear();
    _notify();
  }

  /// Sends [text] in the open conversation (or starts one).
  /// The question shows straight away; on failure it is removed again and
  /// the error is thrown as [AdvisorException] so the screen can give the
  /// text back to the user.
  Future<void> send(String text) async {
    if (_isSending) return;
    final question = text.trim();
    if (question.isEmpty) {
      throw AdvisorException('empty_message', 'Please enter a question for the advisor.');
    }

    final pending = AdvisorMessageModel.pending(question);
    _messages.add(pending);
    _isSending = true;
    _notify();

    try {
      final result = await sendMessage(message: question, conversationID: _conversationID);
      final index = _messages.indexOf(pending);
      if (index != -1) _messages[index] = result.userMessage;
      _messages.add(result.reply);
      _conversationTitle ??=
          question.length > 50 ? '${question.substring(0, 50)}…' : question;
      _conversationID = result.conversationID;
    } on AdvisorException catch (e) {
      _messages.remove(pending);
      if (e.code == 'conversation_not_found') {
        _isSending = false;
        startNewConversation();
      }
      rethrow;
    } finally {
      _isSending = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

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

  /// Past conversations, newest first. Throws [DataLoadException].
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
    } on DataLoadException {
      rethrow;
    } catch (e) {
      debugPrint('Error fetching advisor conversations: $e');
      throw DataLoadException(
        'Unable to load your conversations. Please check your connection and try again.',
      );
    }
  }

  /// All messages of one conversation, oldest first.
  /// Throws [DataLoadException] if they can't be loaded.
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
      throw DataLoadException(
        'Unable to load this conversation. Please check your connection and try again.',
      );
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
