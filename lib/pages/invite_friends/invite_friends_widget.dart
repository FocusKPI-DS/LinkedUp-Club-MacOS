import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'invite_friends_model.dart';
export 'invite_friends_model.dart';

class InviteFriendsWidget extends StatefulWidget {
  const InviteFriendsWidget({super.key});

  static String routeName = 'InviteFriends';
  static String routePath = '/invite-friends';

  @override
  State<InviteFriendsWidget> createState() => _InviteFriendsWidgetState();
}

class InviteFriendsDialog extends StatefulWidget {
  const InviteFriendsDialog({super.key});

  @override
  State<InviteFriendsDialog> createState() => _InviteFriendsDialogState();
}

class _InviteFriendsDialogState extends State<InviteFriendsDialog> {
  String _getInviteMessage() {
    return 'Hey! I\'ve been using this app named Lona for communication, and it\'s amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!\n\nDownload here: https://apps.apple.com/us/app/lona-club/id6747595642';
  }

  Future<void> _copyInviteMessage() async {
    await Clipboard.setData(ClipboardData(text: _getInviteMessage()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final message = _getInviteMessage();
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/?text=$encodedMessage';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaGmail() async {
    final message = _getInviteMessage();
    final subject =
        Uri.encodeComponent('Check out Lona - Amazing Communication App');
    final body = Uri.encodeComponent(message);
    final url = 'mailto:?subject=$subject&body=$body';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaSlack() async {
    final message = _getInviteMessage();
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://slack.com/intent/share?text=$encodedMessage';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaMore() async {
    await Share.share(_getInviteMessage(),
        subject: 'Check out Lona - Amazing Communication App');
  }

  Widget _buildShareButton(
      String label, IconData? icon, Color color, VoidCallback onTap,
      {String? imagePath}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            imagePath != null
                ? Image.asset(
                    imagePath,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  )
                : Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF1F2937),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header with icon and close button
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Invite your friends',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _getInviteMessage(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF1F2937),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _copyInviteMessage,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text(
                    'Copy Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share on:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildShareButton(
                    'WhatsApp',
                    Icons.chat,
                    const Color(0xFF25D366),
                    _shareViaWhatsApp,
                  ),
                  const SizedBox(width: 8),
                  _buildShareButton(
                    'Gmail',
                    null,
                    const Color(0xFFEA4335),
                    _shareViaGmail,
                    imagePath: 'assets/images/google.png',
                  ),
                  const SizedBox(width: 8),
                  _buildShareButton(
                    'Slack',
                    Icons.chat_bubble_outline,
                    const Color(0xFF4A154B),
                    _shareViaSlack,
                  ),
                  const SizedBox(width: 8),
                  _buildShareButton(
                    'More',
                    Icons.share,
                    const Color(0xFF6B7280),
                    _shareViaMore,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteFriendsWidgetState extends State<InviteFriendsWidget> {
  late InviteFriendsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _getInviteMessage() {
    return 'Hey! I\'ve been using this app named Lona for communication, and it\'s amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!\n\nDownload here: https://apps.apple.com/us/app/lona-club/id6747595642';
  }

  Future<void> _copyInviteMessage() async {
    await Clipboard.setData(ClipboardData(text: _getInviteMessage()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    final message = _getInviteMessage();
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/?text=$encodedMessage';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaGmail() async {
    final message = _getInviteMessage();
    final subject =
        Uri.encodeComponent('Check out Lona - Amazing Communication App');
    final body = Uri.encodeComponent(message);
    final url = 'mailto:?subject=$subject&body=$body';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaSlack() async {
    final message = _getInviteMessage();
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://slack.com/intent/share?text=$encodedMessage';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaMore() async {
    await Share.share(_getInviteMessage(),
        subject: 'Check out Lona - Amazing Communication App');
  }

  Widget _buildShareButton(
      String label, IconData? icon, Color color, VoidCallback onTap,
      {String? imagePath}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            imagePath != null
                ? Image.asset(
                    imagePath,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  )
                : Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InviteFriendsModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(
              Icons.close,
              color: Color(0xFF1E293B),
              size: 24,
            ),
            onPressed: () async {
              context.safePop();
            },
          ),
          title: const Text(
            'Invite your friends',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF1E293B),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: Color(0xFF3B82F6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Invite your friends',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF111827),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getInviteMessage(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF374151),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _copyInviteMessage,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16, 14, 16, 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Share on:',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildShareButton(
                        'WhatsApp',
                        Icons.chat,
                        const Color(0xFF25D366),
                        _shareViaWhatsApp,
                      ),
                      const SizedBox(width: 8),
                      _buildShareButton(
                        'Gmail',
                        null,
                        const Color(0xFFEA4335),
                        _shareViaGmail,
                        imagePath: 'assets/images/google.png',
                      ),
                      const SizedBox(width: 8),
                      _buildShareButton(
                        'Slack',
                        Icons.chat_bubble_outline,
                        const Color(0xFF4A154B),
                        _shareViaSlack,
                      ),
                      const SizedBox(width: 8),
                      _buildShareButton(
                        'More',
                        Icons.share,
                        const Color(0xFF6B7280),
                        _shareViaMore,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
