import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/id_helper.dart';
import '../../../models/advisor_conversation_model.dart';
import '../../../models/advisor_message_model.dart';
import '../../../core/utils/session_helper.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../core/utils/text_cut.dart';

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
  /// No reply arrived (timeout or lost connection). The server may still
  /// have answered and saved it.
  static const String noResponse = 'no_response';

  final String code;
  final String message;

  AdvisorException(this.code, this.message);

  @override
  String toString() => message;
}

/// AI Career Advisor: the open conversation (state for the chat screen)
/// plus loading, sending and deleting conversations.
class CareerAdvisorController extends ChangeNotifier with SafeNotifier {
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

  /// Increases on every conversation switch, so a slow, older load can't
  /// show its messages under the conversation the user opened afterwards.
  int _historyRequest = 0;

  /// The last question that got no reply. Sending the same question again
  /// in the same conversation reuses its request ID, so if the server had
  /// answered it after all, that saved answer comes back (no duplicate).
  ({String question, String? conversationID, String requestID})? _unanswered;

  List<AdvisorMessageModel> get messages => List.unmodifiable(_messages);
  String? get conversationID => _conversationID;
  String? get conversationTitle => _conversationTitle;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isSending => _isSending;

  /// Shows a past conversation. Returns an error message, or null.
  Future<String?> openConversation(String conversationID, {String? title}) async {
    // While a reply is on its way it belongs to the open conversation: switching
    // now would put that reply (and the next question) in the wrong chat.
    if (_isSending) return 'Please wait for Career Buddy to reply first.';
    final request = ++_historyRequest;
    _isLoadingHistory = true;
    _conversationID = conversationID;
    _conversationTitle = title;
    _messages.clear();
    notifySafely();

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
        notifySafely();
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
    notifySafely();
  }

  /// Sends [text] in the open conversation (or starts one).
  /// The question shows straight away; on failure it is removed again and
  /// the error is thrown as [AdvisorException] so the screen can give the
  /// text back to the user.
  Future<void> send(String text) async {
    if (_isSending || _isLoadingHistory) return;
    final question = text.trim();
    if (question.isEmpty) {
      throw AdvisorException('empty_message', 'Please enter a question for Career Buddy.');
    }

    final previous = _unanswered;
    final requestID = previous != null &&
            previous.question == question &&
            previous.conversationID == _conversationID
        ? previous.requestID
        : IdHelper.uuidV4();

    final pending = AdvisorMessageModel.pending(question);
    _messages.add(pending);
    _isSending = true;
    notifySafely();

    try {
      final result = await _sendOrRecover(question, requestID);
      _unanswered = null;
      final index = _messages.indexOf(pending);
      if (index != -1) _messages[index] = result.userMessage;
      _messages.add(result.reply);
      _conversationTitle ??= TextCut.withEllipsis(question, 50);
      _conversationID = result.conversationID;
    } on AdvisorException catch (e) {
      _messages.remove(pending);
      _unanswered = e.code == AdvisorException.noResponse
          ? (question: question, conversationID: _conversationID, requestID: requestID)
          : null;
      if (e.code == 'conversation_not_found') {
        _isSending = false;
        startNewConversation();
      }
      rethrow;
    } finally {
      _isSending = false;
      notifySafely();
    }
  }

  /// Sends [question]. When no reply arrives, waits a moment and checks
  /// once whether the server saved an answer anyway before giving up.
  Future<AdvisorReplyResult> _sendOrRecover(String question, String requestID) async {
    try {
      return await sendMessage(
        message: question,
        conversationID: _conversationID,
        requestID: requestID,
      );
    } on AdvisorException catch (e) {
      if (e.code != AdvisorException.noResponse) rethrow;
      await Future<void>.delayed(const Duration(seconds: 3));
      final saved = await findSavedReply(requestID);
      if (saved == null) rethrow;
      return saved;
    }
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  /// Sends a question to the `career-advisor` Edge Function.
  /// Pass [conversationID] = null to start a new conversation. [requestID]
  /// identifies the question, so sending it again can't save it twice.
  Future<AdvisorReplyResult> sendMessage({
    required String message,
    String? conversationID,
    String? requestID,
  }) async {
    final text = message.trim();

    // Use case A2: empty message validation (also checked on the server)
    if (text.isEmpty) {
      throw AdvisorException(
        'empty_message',
        'Please enter a question for Career Buddy.',
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
            body: {
              'message': text,
              'conversationId': conversationID,
              if (requestID != null) 'requestId': requestID,
            },
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
      // No reply of ours (e.g. the gateway timed out): the outcome is unknown
      debugPrint('career-advisor FunctionException: ${e.status} ${e.details}');
      throw AdvisorException(AdvisorException.noResponse, _unavailableMessage);
    } catch (e) {
      // Use case A1: timeout / no internet / unexpected response. The server
      // may still have answered, so the caller can look for a saved reply.
      debugPrint('career-advisor error: $e');
      throw AdvisorException(AdvisorException.noResponse, _unavailableMessage);
    }
  }

  /// The answer saved for the question with [requestID], or null when there
  /// is none (or it can't be checked, e.g. before the database update).
  Future<AdvisorReplyResult?> findSavedReply(String requestID) async {
    const columns = 'messageID, conversationID, role, content, createdAt';
    try {
      final question = await _supabase
          .from(TableConstants.advisorMessage)
          .select(columns)
          .eq('seekerID', _currentSeekerID)
          .eq('requestID', requestID)
          .eq('role', 'user')
          .maybeSingle();
      if (question == null) return null;

      final answer = await _supabase
          .from(TableConstants.advisorMessage)
          .select(columns)
          .eq('conversationID', question['conversationID'] as String)
          .eq('role', 'model')
          .gt('createdAt', question['createdAt'] as String)
          .order('createdAt', ascending: true)
          .limit(1)
          .maybeSingle();
      if (answer == null) return null;

      final userMessage = AdvisorMessageModel.fromJson(question);
      return AdvisorReplyResult(
        conversationID: userMessage.conversationID,
        userMessage: userMessage,
        reply: AdvisorMessageModel.fromJson(answer),
      );
    } catch (e) {
      debugPrint('Checking for a saved Career Buddy reply failed: $e');
      return null;
    }
  }

  static const String _unavailableMessage =
      'Career Buddy is currently unavailable. Please try again later.';

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
