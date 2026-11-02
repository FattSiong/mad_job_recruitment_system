import 'package:flutter/material.dart';

import '../../../services/interview_service.dart';
import 'interview_call_screen.dart';

class InterviewLobbyScreen extends StatefulWidget {
  final String roomID;
  final bool isEmployer;

  const InterviewLobbyScreen({
    super.key,
    required this.roomID,
    required this.isEmployer,
  });

  @override
  State<InterviewLobbyScreen> createState() => _InterviewLobbyScreenState();
}

class _InterviewLobbyScreenState extends State<InterviewLobbyScreen> {
  final InterviewService _interviewService = InterviewService();
  bool _isStarting = false;
  bool _postInterviewAiAnalyticsEnabled = false;

  Future<void> _enterVideoCallRoom(String generatedRoomCode) async {
    if (mounted && _isStarting) {
      setState(() => _isStarting = false);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewCallScreen(
          roomCode: generatedRoomCode,
          interviewID: widget.roomID,
          isEmployer: widget.isEmployer,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _interviewService.listenToInterviewStatus(widget.roomID),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPageFrame(
                child: const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildPageFrame(
                child: _buildMessageCard(
                  icon: Icons.videocam_off_outlined,
                  title: 'Interview not found',
                  message: 'This interview room is unavailable or may have been removed.',
                ),
              );
            }

            final interviewData = snapshot.data!.first;
            final status = (interviewData['status'] ?? 'waiting')
                .toString()
                .toLowerCase();
            final streamRoomCode = interviewData['roomCode'];

            if (status == 'completed') {
              return _buildPageFrame(child: _buildCompletedCard());
            }

            return _buildPageFrame(
              child: Column(
                children: [
                  _buildLobbyHero(status),
                  const SizedBox(height: 18),
                  _buildStatusCard(status),
                  const SizedBox(height: 18),
                  if (widget.isEmployer) ...[
                    _buildAiAnalyticsCard(),
                    const SizedBox(height: 18),
                    _buildEmployerAction(status, streamRoomCode),
                  ] else
                    _buildSeekerAction(status, streamRoomCode),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageFrame({required Widget child}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _buildTopBar(),
        const SizedBox(height: 20),
        child,
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Interview Lobby',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDCEBFB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF163B65)),
              const SizedBox(width: 6),
              Text(
                widget.isEmployer ? 'Host' : 'Guest',
                style: const TextStyle(
                  color: Color(0xFF163B65),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLobbyHero(String status) {
    final isActive = status == 'active';
    final isWaiting = status == 'waiting' || status == 'pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B65), Color(0xFF335D8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPill(
            isActive ? Icons.videocam_rounded : Icons.hourglass_top_rounded,
            isActive ? 'Room is active' : 'Lobby is open',
          ),
          const SizedBox(height: 20),
          Text(
            widget.isEmployer
                ? (isActive ? 'Your interview is live' : 'Ready when you are')
                : (isActive ? 'The interview is ready' : 'Waiting for the host'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.isEmployer
                ? (isActive
                    ? 'Rejoin the video room whenever you are ready.'
                    : 'Check your setup, then start the conversation with your candidate.')
                : (isWaiting
                    ? 'You can join as soon as the employer starts the interview.'
                    : 'The employer has started the room. You can join now.'),
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    final isActive = status == 'active';
    final isWaiting = status == 'waiting' || status == 'pending';
    final color = isActive
        ? const Color(0xFF2D8A5D)
        : isWaiting
        ? const Color(0xFFC28A22)
        : const Color(0xFF687588);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(
              isActive ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Interview room active' : 'Waiting for the interview to begin',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1B2433)),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? 'A secure video room is available now.'
                      : 'This screen will update automatically when the status changes.',
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF687588)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalyticsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4D9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFF6B4FD3), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Post-interview AI analytics',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1B2433)),
                ),
              ),
              Switch.adaptive(
                value: _postInterviewAiAnalyticsEnabled,
                activeColor: const Color(0xFF6B4FD3),
                onChanged: (value) => setState(() => _postInterviewAiAnalyticsEnabled = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _postInterviewAiAnalyticsEnabled
                ? 'Enabled for this interview. A future release will generate a structured summary and candidate insights after the call.'
                : 'Enable this to prepare a future post-call summary, key discussion points, and candidate insights.',
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF4F5D70)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF6B4FD3)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview only — no analytics are generated or saved yet.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF687588)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerAction(String status, dynamic streamRoomCode) {
    final isActive = status == 'active';
    return _buildActionCard(
      title: isActive ? 'Ready to rejoin?' : 'Start the interview',
      subtitle: isActive
          ? 'The interview room is open and available for you to enter.'
          : 'Starting the call will open the room for your candidate.',
      buttonLabel: isActive ? 'Rejoin Interview' : 'Start Interview',
      icon: isActive ? Icons.login_rounded : Icons.videocam_rounded,
      isLoading: _isStarting,
      onPressed: () async {
        setState(() => _isStarting = true);
        try {
          if (isActive && streamRoomCode != null) {
            await _enterVideoCallRoom(streamRoomCode.toString());
          } else {
            final newCode = await _interviewService.startInterview(widget.roomID);
            await _enterVideoCallRoom(newCode);
          }
        } finally {
          if (mounted && _isStarting) {
            setState(() => _isStarting = false);
          }
        }
      },
    );
  }

  Widget _buildSeekerAction(String status, dynamic streamRoomCode) {
    final canJoin = status == 'active' && streamRoomCode != null;
    return _buildActionCard(
      title: canJoin ? 'Ready to join?' : 'Almost time',
      subtitle: canJoin
          ? 'The employer has opened the room. You can join the interview now.'
          : 'Keep this screen open. Your join button will activate automatically.',
      buttonLabel: canJoin ? 'Join Interview Now' : 'Waiting to Start...',
      icon: canJoin ? Icons.videocam_rounded : Icons.hourglass_empty_rounded,
      onPressed: canJoin ? () => _enterVideoCallRoom(streamRoomCode) : null,
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2433))),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF687588))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(icon),
              label: Text(isLoading ? 'Opening room...' : buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE4EAF2),
                disabledForegroundColor: const Color(0xFF8A96A8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return _buildMessageCard(
      icon: Icons.task_alt_rounded,
      iconColor: const Color(0xFF2D8A5D),
      title: 'Interview completed',
      message: 'The video call has ended and this interview room is now closed.',
      actionLabel: 'Return to Dashboard',
      onAction: () => Navigator.pop(context),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    Color iconColor = const Color(0xFF163B65),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(22)),
            child: Icon(icon, color: iconColor, size: 38),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1B2433))),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF687588)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B65),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
