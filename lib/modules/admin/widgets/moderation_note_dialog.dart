import 'package:flutter/material.dart';

/// What the admin chose in [ModerationNoteDialog].
class ModerationDecision {
  /// Private note for the record ("adminNotes"); '' when empty.
  final String note;

  /// Send the author a notification (only offered when removing).
  final bool notifyAuthor;

  const ModerationDecision({required this.note, required this.notifyAuthor});
}

/// Confirm dialog with an optional private note and, when removing
/// content, "Tell the author". Pops with a [ModerationDecision], or null
/// when cancelled.
class ModerationNoteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  /// Shows the "Tell the author" switch (on by default).
  final bool offerNotify;

  /// Wording of that switch (e.g. "Tell the employer and applicants").
  final String notifyTitle;
  final String notifySubtitle;

  const ModerationNoteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    this.offerNotify = false,
    this.notifyTitle = 'Tell the author',
    this.notifySubtitle = 'They get a notification with the report reasons. Your note is not shown.',
  });

  @override
  State<ModerationNoteDialog> createState() => _ModerationNoteDialogState();
}

class _ModerationNoteDialogState extends State<ModerationNoteDialog> {
  final TextEditingController _note = TextEditingController();
  bool _notifyAuthor = true;

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
          if (widget.offerNotify) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifyAuthor,
              onChanged: (v) => setState(() => _notifyAuthor = v),
              title: Text(widget.notifyTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                widget.notifySubtitle,
                style: const TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 12),
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
          onPressed: () => Navigator.pop(
            context,
            ModerationDecision(note: _note.text.trim(), notifyAuthor: widget.offerNotify && _notifyAuthor),
          ),
          style: ElevatedButton.styleFrom(backgroundColor: widget.confirmColor, elevation: 0),
          child: Text(widget.confirmLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
