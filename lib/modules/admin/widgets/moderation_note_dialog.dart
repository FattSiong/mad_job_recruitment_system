import 'package:flutter/material.dart';

/// Confirm dialog with an optional note for the record ("adminNotes").
/// Pops with the note ('' when empty), or null when cancelled.
class ModerationNoteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const ModerationNoteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  State<ModerationNoteDialog> createState() => _ModerationNoteDialogState();
}

class _ModerationNoteDialogState extends State<ModerationNoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Why? Only admins see this.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: widget.confirmColor, elevation: 0),
          child: Text(widget.confirmLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
