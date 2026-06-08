import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/custom_code/services/meeting_service.dart';
import '/utils/qurio_url_launcher.dart';

/// A live meeting banner displayed at the top of a group chat when
/// an active Google Meet session is in progress.
///
/// Uses Lona's blue/white color scheme. Shows a pulsing blue indicator,
/// meeting info, participant count, and Join/End buttons.
class MeetingBannerWidget extends StatefulWidget {
  final ChatsRecord chat;

  const MeetingBannerWidget({Key? key, required this.chat}) : super(key: key);

  @override
  State<MeetingBannerWidget> createState() => _MeetingBannerWidgetState();
}

class _MeetingBannerWidgetState extends State<MeetingBannerWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  bool _hasMeeting = false;
  ChatsRecord? _restChat;
  Timer? _restPollTimer;

  void _startAnimation() {
    if (_pulseController != null) return;
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
  }

  void _stopAnimation() {
    _pulseController?.dispose();
    _pulseController = null;
    _pulseAnimation = null;
  }

  @override
  void initState() {
    super.initState();
    if (useWindowsFirestoreRest) {
      _pollChat();
      _restPollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollChat(),
      );
    }
  }

  Future<void> _pollChat() async {
    try {
      final chat = await fsGetChatOnce(widget.chat.reference);
      if (mounted) setState(() => _restChat = chat);
    } catch (_) {}
  }

  @override
  void dispose() {
    _restPollTimer?.cancel();
    _stopAnimation();
    super.dispose();
  }

  Widget _buildBanner(Map<String, dynamic>? meeting) {
    if (meeting == null || (meeting['url'] as String?)?.isEmpty != false) {
      if (_hasMeeting) {
        _hasMeeting = false;
        _stopAnimation();
      }
      return const SizedBox.shrink();
    }

    if (!_hasMeeting) {
      _hasMeeting = true;
      _startAnimation();
    }

    final meetUrl = meeting['url'] as String;
    final startedBy = meeting['started_by'] as DocumentReference?;
    final participants =
        (meeting['participants'] as List<dynamic>?)
                ?.whereType<DocumentReference>()
                .toList() ??
            [];
    final isStarter = currentUserReference != null &&
        startedBy?.path == currentUserReference!.path;
    final participantCount = participants.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.10),
            const Color(0xFF60A5FA).withOpacity(0.05),
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFDBEAFE), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_pulseAnimation != null)
            AnimatedBuilder(
              animation: _pulseAnimation!,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        Color(0xFF3B82F6).withOpacity(_pulseAnimation!.value),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3B82F6)
                            .withOpacity(_pulseAnimation!.value * 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Color(0xFF2563EB),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Meeting in progress',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                if (participantCount > 0)
                  Text(
                    '$participantCount participant${participantCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
              ],
            ),
          ),
          if (isStarter)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () async {
                  await MeetingService.endMeeting(
                    chatRef: widget.chat.reference,
                    enderName: currentUserDocument?.displayName,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'End',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            ),
          InkWell(
            onTap: () async {
              await MeetingService.joinMeeting(chatRef: widget.chat.reference);
              await qurioLaunchUrl(meetUrl);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Join',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useWindowsFirestoreRest) {
      return _buildBanner(_restChat?.activeMeeting);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: widget.chat.reference.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        return _buildBanner(data?['active_meeting'] as Map<String, dynamic>?);
      },
    );
  }
}
