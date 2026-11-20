import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../shared_widgets/confirm_dialog.dart';
import '../../../../shared_widgets/empty_hint.dart';
import '../../../../shared_widgets/gradient_page_header.dart';
import '../load_error_view.dart';

/// The Education and Work Experience screens: header, the records with
/// Edit / Remove, and an Add button. Changes are saved straight away;
/// callers should reload when the screen closes.
class ProfileRecordsPage<T> extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// "Your Education" (the count is added when loaded).
  final String listTitle;

  /// Label of the floating button, e.g. "Add Education".
  final String addLabel;

  /// Used in the messages, e.g. "education" -> "Education added!".
  final String noun;
  final String emptyText;

  /// Data access (the screen passes its controller's methods).
  final Future<List<T>> Function() load;
  final Future<bool> Function(T item) add;
  final Future<bool> Function(T item) update;
  final Future<bool> Function(String id) delete;

  /// The add / edit sheet ([initial] is null when adding).
  final Future<T?> Function(BuildContext context, T? initial) openSheet;

  final String? Function(T item) idOf;

  /// Shown in "Remove "..." from your profile?".
  final String Function(T item) describe;

  final Widget Function(T item, VoidCallback? onEdit, VoidCallback? onDelete) cardBuilder;

  const ProfileRecordsPage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.listTitle,
    required this.addLabel,
    required this.noun,
    required this.emptyText,
    required this.load,
    required this.add,
    required this.update,
    required this.delete,
    required this.openSheet,
    required this.idOf,
    required this.describe,
    required this.cardBuilder,
  });

  @override
  State<ProfileRecordsPage<T>> createState() => _ProfileRecordsPageState<T>();
}

class _ProfileRecordsPageState<T> extends State<ProfileRecordsPage<T>> {
  List<T> _items = [];
  String? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;

  /// "Education" / "Work experience" at the start of a message.
  String get _capitalNoun => widget.noun[0].toUpperCase() + widget.noun.substring(1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// Loads the records (shows an error card with Try Again on failure).
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on DataLoadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  /// Opens the add sheet (or the edit sheet for [initial]) and saves.
  Future<void> _addOrEdit([T? initial]) async {
    final result = await widget.openSheet(context, initial);
    if (result == null || !mounted) return;

    setState(() => _isSaving = true);
    final ok = initial == null ? await widget.add(result) : await widget.update(result);
    if (!mounted) return;
    setState(() => _isSaving = false);

    final noun = widget.noun;
    _showSnack(
      initial == null
          ? (ok ? '$_capitalNoun added!' : 'Failed to add $noun.')
          : (ok ? '$_capitalNoun updated!' : 'Failed to update $noun.'),
      success: ok,
    );
    if (ok) _load();
  }

  /// Deletes [item] after asking.
  Future<void> _delete(T item) async {
    final id = widget.idOf(item);
    if (id == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${widget.noun}?',
      message: 'Remove "${widget.describe(item)}" from your profile?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await widget.delete(id);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) _items = _items.where((e) => widget.idOf(e) != id).toList();
    });

    _showSnack(ok ? '$_capitalNoun removed.' : 'Failed to remove ${widget.noun}.', success: ok);
  }

  /// Green or red snackbar.
  void _showSnack(String message, {required bool success}) {
    if (success) {
      SnackBarHelper.showSuccess(context, message);
    } else {
      SnackBarHelper.showError(context, message);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final loaded = !_isLoading && _loadError == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  GradientPageHeader(icon: widget.icon, title: widget.title, subtitle: widget.subtitle),
                  const SizedBox(height: 24),
                  Text(
                    loaded ? '${widget.listTitle} (${_items.length})' : widget.listTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 14),
                  ..._buildBody(),
                ],
              ),
            ),
            if (_isSaving)
              const Positioned.fill(
                child: ColoredBox(
                  color: AppColors.overlay,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: loaded
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => _addOrEdit(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(widget.addLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  /// The records, or a spinner / error / empty message.
  List<Widget> _buildBody() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    if (_loadError != null) return [LoadErrorView(message: _loadError!, onRetry: _load)];
    if (_items.isEmpty) return [EmptyHint(text: widget.emptyText, color: AppColors.surface)];
    return [
      for (final item in _items)
        widget.cardBuilder(
          item,
          _isSaving ? null : () => _addOrEdit(item),
          _isSaving ? null : () => _delete(item),
        ),
      const SizedBox(height: 72), // room for the floating button
    ];
  }
}
