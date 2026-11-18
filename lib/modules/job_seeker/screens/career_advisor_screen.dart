import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/advisor_message_model.dart';
import '../controllers/career_advisor_controller.dart';
import '../widgets/career_advisor/advisor_chat_widgets.dart';
import '../../../shared_widgets/button_spinner.dart';

/// AI Career Advisor chat (Use Case 4.58: Chat with AI Career Advisor).
class AiCareerAdvisorScreen extends StatefulWidget {
  /// Open an existing conversation, or null to start a new one.
  final String? conversationID;

  const AiCareerAdvisorScreen({super.key, this.conversationID});

  @override
  State<AiCareerAdvisorScreen> createState() => _AiCareerAdvisorScreenState();
}

class _AiCareerAdvisorScreenState extends State<AiCareerAdvisorScreen> {
  static const List<String> _suggestedQuestions = [
    'What career paths suit my skills?',
    'How can I improve my resume for my first job?',
    'Which certifications are worth getting in my field?',
    'How do I prepare for a technical interview?',
  ];

  final CareerAdvisorController _controller = CareerAdvisorController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Conversation state lives in the controller (MVC); these read it.
  List<AdvisorMessageModel> get _messages => _controller.messages;
  String? get _conversationTitle => _controller.conversationTitle;
  bool get _isLoadingHistory => _controller.isLoadingHistory;
  bool get _isSending => _controller.isSending;

  bool _hasMessageText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasMessageText) {
        setState(() => _hasMessageText = hasText);
      }
    });
    if (widget.conversationID != null) {
      _openConversation(widget.conversationID!);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Rebuilds when the conversation changes.
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// Shows a past conversation (from the history sheet).
  Future<void> _openConversation(String conversationID, {String? title}) async {
    final error = await _controller.openConversation(conversationID, title: title);
    if (!mounted) return;
    if (error != null) {
      SnackBarHelper.showError(context, error, duration: const Duration(seconds: 3));
      return;
    }
    _scrollToBottom();
  }

  /// Clears the chat for a new conversation.
  void _startNewConversation() {
    if (_isSending) return;
    _controller.startNewConversation();
    _messageController.clear();
  }

  /// Sends the typed question, or [presetText] from a suggestion.
  Future<void> _sendMessage([String? presetText]) async {
    // Wait for a past conversation to finish loading, or the question would
    // show above its older messages.
    if (_isSending || _isLoadingHistory) return;
    final text = (presetText ?? _messageController.text).trim();

    // Use case A2: ignore empty input and prompt the user
    if (text.isEmpty) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please enter a question for Career Buddy.',
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.primary,
      );
      return;
    }

    _messageController.clear();
    final sending = _controller.send(text); // the question shows straight away
    _scrollToBottom();

    try {
      await sending;
      if (!mounted) return;
      _scrollToBottom();
    } on AdvisorException catch (e) {
      if (!mounted) return;
      // Use case A1: give the text back and show the error
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = text;
        _messageController.selection = TextSelection.collapsed(offset: text.length);
      }
      SnackBarHelper.showError(context, e.message, duration: const Duration(seconds: 3));
    }
  }

  /// Scrolls to the newest message after the next frame.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // list is reversed, so 0 is the bottom
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Copies a message to the clipboard.
  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    SnackBarHelper.showSuccess(context, 'Copied to clipboard');
  }

  // ---------------------------------------------------------------------
  // History bottom sheet
  // ---------------------------------------------------------------------

  /// Opens the past conversations sheet.
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ConversationHistorySheet(
        controller: _controller,
        currentConversationID: _controller.conversationID,
        onSelected: (conversation) {
          Navigator.pop(sheetContext);
          _openConversation(
            conversation.conversationID,
            title: conversation.title,
          );
        },
        onDeleted: (conversationID) {
          if (conversationID == _controller.conversationID) _startNewConversation();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: AppColors.chatGradient,
                borderRadius: BorderRadius.circular(30),
              ),
              child: _buildBody(),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  /// App bar with the conversation title, history and new chat buttons.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Career Buddy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isSending
                      ? 'Thinking…'
                      : (_conversationTitle ?? 'Ask anything about your career'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildActionButton(
          icon: Icons.history_rounded,
          tooltip: 'Past conversations',
          onPressed: _isSending ? null : _showHistorySheet,
        ),
        _buildActionButton(
          icon: Icons.add_comment_outlined,
          tooltip: 'New conversation',
          onPressed: _isSending ? null : _startNewConversation,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Small white icon button in the app bar.
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed, // null = disabled
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// The messages, or the welcome card when the chat is empty.
  Widget _buildBody() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    // Reversed list keeps the newest message at the bottom
    final items = _messages.reversed.toList();
    final showTyping = _isSending;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      itemCount: items.length + (showTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (showTyping && index == 0) return const AdvisorTypingBubble();
        final message = items[showTyping ? index - 1 : index];
        return AdvisorMessageBubble(
          message: message,
          onLongPress: () => _copyMessage(message.content),
        );
      },
    );
  }

  /// Welcome card with suggested questions.
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'Hi! I\'m Career Buddy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'I use your profile, skills and experience to give personalised '
              'career guidance. Try one of these questions:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            ..._suggestedQuestions.map(_buildSuggestionTile),
          ],
        ),
      ),
    );
  }

  /// One suggested question; tapping it sends it.
  Widget _buildSuggestionTile(String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isSending ? null : () => _sendMessage(question),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Question box and send button.
  Widget _buildComposer() {
    final canSend = _hasMessageText && !_isSending && !_isLoadingHistory;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: CareerAdvisorController.maxMessageLength,
                    buildCounter: (context,
                            {required currentLength, required isFocused, required maxLength}) =>
                        null, // hide the counter, keep the limit
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isSending
                          ? 'Career Buddy is replying…'
                          : 'Ask your career question…',
                      hintStyle: const TextStyle(color: AppColors.textHint),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: canSend ? AppColors.primary : AppColors.disabled,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const ButtonSpinner(size: 20)
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: (_isSending || _isLoadingHistory) ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------
