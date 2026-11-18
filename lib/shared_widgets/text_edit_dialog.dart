import 'package:flutter/material.dart';

import '../core/theme/app_input_decoration.dart';

/// Dialog to edit a short text (a chat message, a comment). Returns the new
/// text, or null when cancelled.
Future<String?> showTextEditDialog(
  BuildContext context, {
  required String title,
  required String initialText,
  required int maxLength,
  bool showCounter = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextEditDialog(
      title: title,
      initialText: initialText,
      maxLength: maxLength,
      showCounter: showCounter,
    ),
  );
}

class _TextEditDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final int maxLength;
  final bool showCounter;

  const _TextEditDialog({
    required this.title,
    required this.initialText,
    required this.maxLength,
    required this.showCounter,
  });

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  // Disposed with the dialog, once it has fully closed.
  late final TextEditingController _text = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: filledInputDecoration(counterText: widget.showCounter ? null : ''),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _text.text), child: const Text('Save')),
      ],
    );
  }
}
