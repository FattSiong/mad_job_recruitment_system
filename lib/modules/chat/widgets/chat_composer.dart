import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../chat_formatters.dart';

/// Bottom bar: attach, text box, and send (or hold-to-record when empty).
class ChatComposer extends StatefulWidget {
  final TextEditingController textController;
  final bool isUploading;
  final bool isRecording;
  final Duration recordingElapsed;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;

  const ChatComposer({
    super.key,
    required this.textController,
    required this.isUploading,
    required this.isRecording,
    required this.recordingElapsed,
    required this.onSend,
    required this.onAttach,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onRecordCancel,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onTextChanged);
      widget.textController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  /// Switches between the send and mic buttons as the text box fills or empties.
  void _onTextChanged() {
    final hasText = widget.textController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _squareButton(
              color: AppColors.primarySoft,
              onPressed: (widget.isUploading || widget.isRecording) ? null : widget.onAttach,
              tooltip: 'Send a photo or file',
              child: widget.isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.add_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(child: widget.isRecording ? _recordingBar() : _textField()),
            const SizedBox(width: 8),
            if (_hasText)
              _squareButton(
                color: AppColors.primary,
                onPressed: widget.onSend,
                tooltip: 'Send',
                child: const Icon(Icons.send_rounded, color: Colors.white),
              )
            else
              Tooltip(
                message: 'Hold to record',
                child: GestureDetector(
                  onLongPressStart: (_) => widget.onRecordStart(),
                  onLongPressEnd: (_) => widget.onRecordEnd(),
                  onLongPressMoveUpdate: (details) {
                    // Slide left to cancel.
                    if (widget.isRecording && details.offsetFromOrigin.dx < -80) {
                      widget.onRecordCancel();
                    }
                  },
                  onLongPressCancel: widget.onRecordCancel,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hold the mic button to record a voice message.')),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: widget.isRecording ? 56 : 48,
                    height: widget.isRecording ? 56 : 48,
                    decoration: BoxDecoration(
                      color: widget.isRecording ? AppColors.danger : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      widget.isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: widget.isRecording ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The message text box.
  Widget _textField() {
    return TextField(
      controller: widget.textController,
      minLines: 1,
      maxLines: 5,
      maxLength: 4000,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Message',
        counterText: '',
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }

  /// Red "recording" bar with the timer, shown while the mic is held.
  Widget _recordingBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record_rounded, color: AppColors.danger, size: 14),
          const SizedBox(width: 8),
          Text(
            ChatFormatters.duration(widget.recordingElapsed),
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Release to send · slide left to cancel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Rounded square button used for attach and send.
  Widget _squareButton({
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
    required Widget child,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}
