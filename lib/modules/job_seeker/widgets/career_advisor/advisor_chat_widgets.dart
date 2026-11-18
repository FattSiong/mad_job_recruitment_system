import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_format.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../models/advisor_conversation_model.dart';
import '../../../../models/advisor_message_model.dart';
import '../../../../shared_widgets/button_spinner.dart';
import '../../../../shared_widgets/confirm_dialog.dart';
import '../../controllers/career_advisor_controller.dart';

// Pieces of the AI Career Advisor chat screen.

/// One chat message: the user's question or the advisor's answer.
class AdvisorMessageBubble extends StatelessWidget {
  final AdvisorMessageModel message;
  final VoidCallback onLongPress;

  const AdvisorMessageBubble({required this.message, required this.onLongPress});

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
                  Icon(Icons.smart_toy_outlined, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'AI Advisor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
                color: isUser ? AppColors.primary : Colors.white,
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
                          color: AppColors.shadowFaint,
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
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// "Advisor is typing" bubble
// ---------------------------------------------------------------------

/// "Advisor is typing" bubble shown while waiting for the reply.
class AdvisorTypingBubble extends StatelessWidget {
  const AdvisorTypingBubble();

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
            ButtonSpinner(size: 16, color: AppColors.primary),
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

// ---------------------------------------------------------------------
// Past conversations bottom sheet
// ---------------------------------------------------------------------

/// Past conversations: open one or delete it.
class ConversationHistorySheet extends StatefulWidget {
  final CareerAdvisorController controller;
  final String? currentConversationID;
  final ValueChanged<AdvisorConversationModel> onSelected;
  final ValueChanged<String> onDeleted;

  const ConversationHistorySheet({
    required this.controller,
    required this.currentConversationID,
    required this.onSelected,
    required this.onDeleted,
  });

  @override
  State<ConversationHistorySheet> createState() =>
      _ConversationHistorySheetState();
}

class _ConversationHistorySheetState extends State<ConversationHistorySheet> {
  late Future<List<AdvisorConversationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.fetchConversations();
  }

  /// Deletes a past conversation after asking.
  Future<void> _confirmDelete(AdvisorConversationModel conversation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete conversation?',
      message: '"${conversation.title}" will be permanently deleted.',
    );
    if (!confirmed) return;

    final ok = await widget.controller.deleteConversation(conversation.conversationID);
    if (!mounted) return;

    if (ok) {
      widget.onDeleted(conversation.conversationID);
      setState(() => _future = widget.controller.fetchConversations());
    } else {
      SnackBarHelper.showError(context, 'Unable to delete the conversation.');
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
                  color: AppColors.textDark,
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
                          child: CircularProgressIndicator(color: AppColors.primary),
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
                              style: const TextStyle(color: AppColors.textMuted, height: 1.45),
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
                            style: TextStyle(color: AppColors.textMuted, height: 1.45),
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
                                      color: AppColors.primary, size: 20),
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
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppDateFormat.dayTime
                                              .format(c.updatedAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
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
