import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/advisor_conversation_model.dart';
import '../../../models/advisor_message_model.dart';
import '../controllers/career_advisor_controller.dart';

/// AI Career Advisor chat (Use Case 4.58: Chat with AI Career Advisor).
class AiCareerAdvisorScreen extends StatefulWidget {
  /// Open an existing conversation, or null to start a new one.
  final String? conversationID;

  const AiCareerAdvisorScreen({super.key, this.conversationID});

  @override
  State<AiCareerAdvisorScreen> createState() => _AiCareerAdvisorScreenState();
}

class _AiCareerAdvisorScreenState extends State<AiCareerAdvisorScreen> {
  // Same palette as the other job seeker screens
  static const Color _primary = AppColors.primary;
  static const Color _background = AppColors.background;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _softBlue = AppColors.primarySoft;
  static const Color _border = AppColors.borderSoft;

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

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _openConversation(String conversationID, {String? title}) async {
    final error = await _controller.openConversation(conversationID, title: title);
    if (!mounted) return;
    if (error != null) {
      SnackBarHelper.showStyled(
        context,
        message: error,
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    _scrollToBottom();
  }

  void _startNewConversation() {
    if (_isSending) return;
    _controller.startNewConversation();
    _messageController.clear();
  }

  Future<void> _sendMessage([String? presetText]) async {
    if (_isSending) return;
    final text = (presetText ?? _messageController.text).trim();

    // Use case A2: ignore empty input and prompt the user
    if (text.isEmpty) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please enter a question for the advisor.',
        icon: Icons.info_outline_rounded,
        accentColor: _primary,
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
      SnackBarHelper.showStyled(
        context,
        message: e.message,
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
        duration: const Duration(seconds: 3),
      );
    }
  }

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

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    SnackBarHelper.showStyled(
      context,
      message: 'Copied to clipboard',
      icon: Icons.check_circle_outline_rounded,
      accentColor: AppColors.successGreen,
    );
  }

  // ---------------------------------------------------------------------
  // History bottom sheet
  // ---------------------------------------------------------------------

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ConversationHistorySheet(
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
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEAF2FC), Color(0xFFF8FAFD)],
                ),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _primary),
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
                  'AI Career Advisor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isSending
                      ? 'Thinking…'
                      : (_conversationTitle ?? 'Ask anything about your career'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _textMuted),
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
          onPressed: _showHistorySheet,
        ),
        _buildActionButton(
          icon: Icons.add_comment_outlined,
          tooltip: 'New conversation',
          onPressed: _startNewConversation,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: IconButton(
        icon: Icon(icon, color: _primary),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: _primary));
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
        if (showTyping && index == 0) return const _TypingBubble();
        final message = items[showTyping ? index - 1 : index];
        return _AdvisorMessageBubble(
          message: message,
          onLongPress: () => _copyMessage(message.content),
        );
      },
    );
  }

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
              color: Color(0x120F172A),
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
                color: _softBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 34, color: _primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'Hi! I\'m your AI Career Advisor',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'I use your profile, skills and experience to give personalised '
              'career guidance. Try one of these questions:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: _textMuted),
            ),
            const SizedBox(height: 20),
            ..._suggestedQuestions.map(_buildSuggestionTile),
          ],
        ),
      ),
    );
  }

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
                const Icon(Icons.lightbulb_outline_rounded, color: _primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: _textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _hasMessageText && !_isSending;

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
                color: Color(0x140F172A),
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
                          ? 'Advisor is replying…'
                          : 'Ask your career question…',
                      hintStyle: const TextStyle(color: Color(0xFF9AA5B5)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: _background,
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
                        borderSide: const BorderSide(color: _primary, width: 1.2),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: canSend ? AppColors.primary : const Color(0xFFD7E3F3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _isSending ? null : () => _sendMessage(),
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

// ------------------------------------------------------------------------
// Message bubble
// ------------------------------------------------------------------------
class _AdvisorMessageBubble extends StatelessWidget {
  final AdvisorMessageModel message;
  final VoidCallback onLongPress;

  const _AdvisorMessageBubble({required this.message, required this.onLongPress});

  static const Color _primary = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 14, color: _primary),
                  SizedBox(width: 6),
                  Text(
                    'AI Advisor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? _primary : Colors.white,
                border: isUser ? null : Border.all(color: AppColors.borderSoft),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                boxShadow: isUser
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x0D0F172A),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: isUser ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
            child: Text(
              DateFormat('h:mm a').format(message.createdAt),
              style: const TextStyle(fontSize: 11, color: Color(0xFF7C8798)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------
// "Advisor is typing" bubble
// ------------------------------------------------------------------------
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.borderSoft),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(22),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Advisor is thinking…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Past conversations bottom sheet
// ------------------------------------------------------------------------
class _ConversationHistorySheet extends StatefulWidget {
  final CareerAdvisorController controller;
  final String? currentConversationID;
  final ValueChanged<AdvisorConversationModel> onSelected;
  final ValueChanged<String> onDeleted;

  const _ConversationHistorySheet({
    required this.controller,
    required this.currentConversationID,
    required this.onSelected,
    required this.onDeleted,
  });

  @override
  State<_ConversationHistorySheet> createState() =>
      _ConversationHistorySheetState();
}

class _ConversationHistorySheetState extends State<_ConversationHistorySheet> {
  static const Color _primary = AppColors.primary;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;

  late Future<List<AdvisorConversationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.fetchConversations();
  }

  Future<void> _confirmDelete(AdvisorConversationModel conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete conversation?'),
        content: Text('"${conversation.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await widget.controller.deleteConversation(conversation.conversationID);
    if (!mounted) return;

    if (ok) {
      widget.onDeleted(conversation.conversationID);
      setState(() => _future = widget.controller.fetchConversations());
    } else {
      SnackBarHelper.showStyled(
        context,
        message: 'Unable to delete the conversation.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Past Conversations',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<List<AdvisorConversationModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              error is DataLoadException
                                  ? error.message
                                  : 'Unable to load your conversations.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _textMuted, height: 1.45),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _future = widget.controller.fetchConversations(),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try Again'),
                            ),
                          ],
                        ),
                      );
                    }
                    final conversations = snapshot.data ?? [];
                    if (conversations.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No conversations yet.\nAsk your first question to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textMuted, height: 1.45),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = conversations[index];
                        final isCurrent =
                            c.conversationID == widget.currentConversationID;

                        return Material(
                          color: isCurrent
                              ? AppColors.primarySoft
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => widget.onSelected(c),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded,
                                      color: _primary, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('d MMM yyyy, h:mm a')
                                              .format(c.updatedAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: AppColors.errorRed),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(c),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
