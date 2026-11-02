import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/chat_room_model.dart';
import 'controllers/chat_room_controller.dart';
import 'screens/chat_room_screen.dart';

/// Opens (or creates) the one-to-one chat with [otherUserID].
/// Use this from any screen, e.g. the "Message" button on an applicant.
Future<void> openChatWith(BuildContext context, String otherUserID) async {
  try {
    final results = await Future.wait([
      ChatRoomController.getOrCreateRoomId(otherUserID),
      ChatRoomController.fetchParticipant(otherUserID),
    ]);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomID: results[0] as String,
          otherUser: results[1] as ChatParticipant,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Open chat failed: $e');
    if (!context.mounted) return;
    SnackBarHelper.showStyled(
      context,
      message: 'Unable to open the chat. Please try again.',
      icon: Icons.error_outline_rounded,
      accentColor: AppColors.errorRed,
    );
  }
}
