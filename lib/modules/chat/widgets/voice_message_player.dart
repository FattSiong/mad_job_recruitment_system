import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../chat_formatters.dart';

/// Only one voice note plays at a time across the chat.
final ValueNotifier<String?> _currentlyPlayingId = ValueNotifier<String?>(null);

/// Play/pause button, seek bar and length for a voice note.
class VoiceMessagePlayer extends StatefulWidget {
  final String messageID;
  final String url;
  final Duration? knownLength; // from "Voice Message (12s)"
  final bool isMine;

  const VoiceMessagePlayer({
    super.key,
    required this.messageID,
    required this.url,
    required this.isMine,
    this.knownLength,
  });

  /// Reads the "(12s)" length stored in the message text.
  static Duration? lengthFromContent(String content) {
    final match = RegExp(r'\((\d+)s\)').firstMatch(content);
    final seconds = int.tryParse(match?.group(1) ?? '');
    return (seconds == null || seconds <= 0) ? null : Duration(seconds: seconds);
  }

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentlyPlayingId.addListener(_pauseIfAnotherStarts);
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
        if (_currentlyPlayingId.value == widget.messageID) _currentlyPlayingId.value = null;
      }),
    ]);
  }

  /// Pauses this player when another voice note starts playing.
  void _pauseIfAnotherStarts() {
    if (_currentlyPlayingId.value != widget.messageID && _isPlaying) {
      _player.pause();
    }
  }

  Duration get _length {
    final known = widget.knownLength;
    if (_duration > Duration.zero) {
      return (known != null && known < _duration) ? known : _duration;
    }
    return known ?? Duration.zero;
  }

  /// Play / pause. Resumes from where it stopped.
  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    _currentlyPlayingId.value = widget.messageID;
    try {
      if (_position > Duration.zero) {
        await _player.resume();
      } else {
        setState(() => _isLoading = true);
        // Private chat file: play it through a signed link.
        final url = await StorageUrlHelper.resolveCached(widget.url);
        if (!mounted) return;
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      debugPrint('Voice message playback failed: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Unable to play this voice message.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentlyPlayingId.removeListener(_pauseIfAnotherStarts);
    if (_currentlyPlayingId.value == widget.messageID) _currentlyPlayingId.value = null;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isMine ? Colors.white : AppColors.primary;
    final length = _length;
    final maxSeconds = length.inMilliseconds > 0 ? length.inMilliseconds / 1000 : 1.0;
    final value = (_position.inMilliseconds / 1000).clamp(0.0, maxSeconds).toDouble();
    final shown = _position > Duration.zero ? _position : length;

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMine ? Colors.white.withValues(alpha: 0.18) : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: foreground,
                    ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: foreground,
                inactiveTrackColor:
                    widget.isMine ? Colors.white.withValues(alpha: 0.35) : AppColors.borderSoft,
                thumbColor: foreground,
              ),
              child: Slider(
                min: 0,
                max: maxSeconds.toDouble(),
                value: value,
                onChanged: (v) => _player.seek(Duration(milliseconds: (v * 1000).round())),
              ),
            ),
          ),
          Text(
            ChatFormatters.duration(shown),
            style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
