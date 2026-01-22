import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';

/// Zego App credentials
const int zegoAppID = 1857210024;
const String zegoAppSign = '6467c11d1d838b8a054137f4cf643b5b2a220d427efd4ec664581e3f00d24c47';

/// Calling screen widget with custom UI using Zego Express Engine SDK
/// Zego is only supported on iOS, Android, and Web - not macOS
class CallingScreenWidget extends StatefulWidget {
  const CallingScreenWidget({
    Key? key,
    required this.chat,
    required this.isVideoCall,
    required this.onEndCall,
  }) : super(key: key);

  final ChatsRecord chat;
  final bool isVideoCall;
  final VoidCallback onEndCall;

  @override
  State<CallingScreenWidget> createState() => _CallingScreenWidgetState();
}

class _CallingScreenWidgetState extends State<CallingScreenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _callDuration = 0;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  UsersRecord? _otherUser;

  // Zego state
  bool _isEngineCreated = false;
  bool _isInRoom = false;
  int? _localViewID;
  int? _remoteViewID;
  Widget? _localView;
  Widget? _remoteView;
  String _callStatus = 'Connecting...';

  // Check if Zego is supported on this platform
  bool get _isZegoSupported {
    if (kIsWeb) return true;
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadOtherUser();
    _startCallTimer();

    // Only initialize Zego on supported platforms
    if (_isZegoSupported) {
      _initZegoEngine();
    } else {
      // On unsupported platforms, just show the UI as demo
      _callStatus = 'Calling...';
    }
  }

  Future<void> _loadOtherUser() async {
    if (!widget.chat.isGroup) {
      final otherUserRef = widget.chat.members.firstWhere(
        (member) => member != currentUserReference,
        orElse: () => widget.chat.members.first,
      );
      final user = await UsersRecord.getDocumentOnce(otherUserRef);
      if (mounted) {
        setState(() {
          _otherUser = user;
        });
      }
    }
  }

  Future<void> _initZegoEngine() async {
    if (!_isZegoSupported) return;

    try {
      // Create Zego Engine
      ZegoEngineProfile profile = ZegoEngineProfile(
        zegoAppID,
        ZegoScenario.Default,
        appSign: zegoAppSign,
      );

      await ZegoExpressEngine.createEngineWithProfile(profile);
      _isEngineCreated = true;

      // Set up event handlers
      ZegoExpressEngine.onRoomStateUpdate = _onRoomStateUpdate;
      ZegoExpressEngine.onRoomUserUpdate = _onRoomUserUpdate;
      ZegoExpressEngine.onRoomStreamUpdate = _onRoomStreamUpdate;

      // Login to room and start publishing
      await _joinRoom();
    } catch (e) {
      debugPrint('Failed to initialize Zego: $e');
      if (mounted) {
        setState(() {
          _callStatus = 'Connection failed';
        });
      }
    }
  }

  void _onRoomStateUpdate(String roomID, ZegoRoomState state, int errorCode, Map<String, dynamic> extendedData) {
    debugPrint('Room state update: $state, errorCode: $errorCode');
    if (mounted) {
      setState(() {
        if (state == ZegoRoomState.Connected) {
          _isInRoom = true;
          _callStatus = 'Calling...';
        } else if (state == ZegoRoomState.Disconnected) {
          _isInRoom = false;
          _callStatus = 'Disconnected';
        }
      });
    }
  }

  void _onRoomUserUpdate(String roomID, ZegoUpdateType updateType, List<ZegoUser> userList) {
    debugPrint('Room user update: $updateType, users: ${userList.length}');
    if (mounted) {
      setState(() {
        if (updateType == ZegoUpdateType.Add && userList.isNotEmpty) {
          _callStatus = 'Connected';
        } else if (updateType == ZegoUpdateType.Delete) {
          _callStatus = 'User left';
        }
      });
    }
  }

  void _onRoomStreamUpdate(String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList, Map<String, dynamic> extendedData) async {
    debugPrint('Room stream update: $updateType, streams: ${streamList.length}');
    
    if (updateType == ZegoUpdateType.Add) {
      for (var stream in streamList) {
        if (_remoteViewID == null && widget.isVideoCall) {
          final viewWidget = await ZegoExpressEngine.instance.createCanvasView((viewID) {
            _remoteViewID = viewID;
            ZegoCanvas canvas = ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill);
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID, canvas: canvas);
          });
          if (mounted) {
            setState(() {
              _remoteView = viewWidget;
              _callStatus = 'Connected';
            });
          }
        } else {
          ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
          if (mounted) {
            setState(() {
              _callStatus = 'Connected';
            });
          }
        }
      }
    } else if (updateType == ZegoUpdateType.Delete) {
      for (var stream in streamList) {
        ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
      }
      if (_remoteViewID != null) {
        await ZegoExpressEngine.instance.destroyCanvasView(_remoteViewID!);
        if (mounted) {
          setState(() {
            _remoteViewID = null;
            _remoteView = null;
          });
        }
      }
    }
  }

  Future<void> _joinRoom() async {
    if (!_isZegoSupported) return;

    final userID = currentUserReference?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final userName = currentUserDocument?.displayName ?? 'User';
    final roomID = widget.chat.reference.id;
    final streamID = '${roomID}_${userID}';

    ZegoUser user = ZegoUser(userID, userName);
    ZegoRoomConfig roomConfig = ZegoRoomConfig.defaultConfig();
    roomConfig.isUserStatusNotify = true;

    await ZegoExpressEngine.instance.loginRoom(roomID, user, config: roomConfig);

    if (widget.isVideoCall) {
      final viewWidget = await ZegoExpressEngine.instance.createCanvasView((viewID) {
        _localViewID = viewID;
        ZegoCanvas canvas = ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill);
        ZegoExpressEngine.instance.startPreview(canvas: canvas);
      });
      if (mounted) {
        setState(() {
          _localView = viewWidget;
        });
      }
    }

    await ZegoExpressEngine.instance.startPublishingStream(streamID);
    await ZegoExpressEngine.instance.enableCamera(widget.isVideoCall);
    await ZegoExpressEngine.instance.muteMicrophone(false);
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isZegoSupported && _isEngineCreated) {
      try {
        await ZegoExpressEngine.instance.muteMicrophone(_isMuted);
      } catch (e) {
        debugPrint('Error toggling mute: $e');
      }
    }
  }

  void _toggleCamera() async {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    if (_isZegoSupported && _isEngineCreated) {
      try {
        await ZegoExpressEngine.instance.enableCamera(!_isCameraOff);
      } catch (e) {
        debugPrint('Error toggling camera: $e');
      }
    }
  }

  void _toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    if (_isZegoSupported && _isEngineCreated) {
      try {
        await ZegoExpressEngine.instance.setAudioRouteToSpeaker(_isSpeakerOn);
      } catch (e) {
        debugPrint('Error toggling speaker: $e');
      }
    }
  }

  void _switchCamera() async {
    if (_isZegoSupported && _isEngineCreated) {
      try {
        await ZegoExpressEngine.instance.useFrontCamera(true);
      } catch (e) {
        debugPrint('Error switching camera: $e');
      }
    }
  }

  Future<void> _endCall() async {
    if (_isZegoSupported && _isEngineCreated) {
      try {
        await ZegoExpressEngine.instance.stopPublishingStream();
        if (_localViewID != null) {
          await ZegoExpressEngine.instance.stopPreview();
          await ZegoExpressEngine.instance.destroyCanvasView(_localViewID!);
        }
        await ZegoExpressEngine.instance.logoutRoom();
        await ZegoExpressEngine.destroyEngine();
      } catch (e) {
        debugPrint('Error ending call: $e');
      }
    }
    widget.onEndCall();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callTimer?.cancel();
    if (_isZegoSupported && _isEngineCreated) {
      try {
        ZegoExpressEngine.instance.stopPublishingStream();
        if (_localViewID != null) {
          ZegoExpressEngine.instance.stopPreview();
          ZegoExpressEngine.instance.destroyCanvasView(_localViewID!);
        }
        ZegoExpressEngine.instance.logoutRoom();
        ZegoExpressEngine.destroyEngine();
      } catch (e) {
        debugPrint('Error disposing Zego: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isVideoCall
                ? [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)]
                : [Color(0xFF2D3436), Color(0xFF1e272e), Color(0xFF2D3436)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Remote video (full screen background for video calls)
              if (widget.isVideoCall && _remoteView != null)
                Positioned.fill(child: _remoteView!),

              // Gradient overlay for video calls
              if (widget.isVideoCall && _remoteView != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                        stops: [0.0, 0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

              // Main content
              Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Show avatar when no remote video
                        if (!widget.isVideoCall || _remoteView == null) ...[
                          _buildCallerAvatar(),
                          SizedBox(height: 24),
                        ],
                        _buildCallerName(),
                        SizedBox(height: 8),
                        _buildCallStatus(),
                        SizedBox(height: 8),
                        Text(
                          _formatDuration(_callDuration),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        // Show platform note on unsupported platforms
                        if (!_isZegoSupported)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Video calls work on iOS, Android & Web',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildActionButtons(),
                  SizedBox(height: 40),
                ],
              ),

              // Local video preview (small corner view)
              if (widget.isVideoCall && _localView != null && !_isCameraOff)
                Positioned(
                  top: 100,
                  right: 20,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _localView!,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.8), size: 28),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isVideoCall ? CupertinoIcons.video_camera_solid : CupertinoIcons.phone_fill,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  widget.isVideoCall ? 'Video Call' : 'Audio Call',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ],
            ),
          ),
          if (widget.isVideoCall)
            IconButton(
              onPressed: _switchCamera,
              icon: Icon(CupertinoIcons.switch_camera_solid, color: Colors.white.withOpacity(0.8), size: 24),
            )
          else
            SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCallerAvatar() {
    final String? avatarUrl = widget.chat.isGroup
        ? (widget.chat.chatImageUrl.isNotEmpty ? widget.chat.chatImageUrl : null)
        : _otherUser?.photoUrl;
    final String displayName = widget.chat.isGroup
        ? (widget.chat.title.isNotEmpty ? widget.chat.title : 'Group')
        : (_otherUser?.displayName ?? 'User');

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 160 * _pulseAnimation.value,
          height: 160 * _pulseAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isVideoCall ? Color(0xFF4CAF50).withOpacity(0.5) : Color(0xFF3B82F6).withOpacity(0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isVideoCall ? Color(0xFF4CAF50) : Color(0xFF3B82F6)).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF374151)),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildAvatarPlaceholder(displayName),
                      errorWidget: (context, url, error) => _buildAvatarPlaceholder(displayName),
                    )
                  : _buildAvatarPlaceholder(displayName),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: Color(0xFF4B5563),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 56, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCallerName() {
    final String displayName = widget.chat.isGroup
        ? (widget.chat.title.isNotEmpty ? widget.chat.title : 'Group')
        : (_otherUser?.displayName ?? 'User');

    return Text(
      displayName,
      style: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCallStatus() {
    final bool isConnected = _callStatus == 'Connected';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Color(0xFF4CAF50) : Colors.orange,
            boxShadow: [BoxShadow(color: (isConnected ? Color(0xFF4CAF50) : Colors.orange).withOpacity(0.5), blurRadius: 6)],
          ),
        ),
        SizedBox(width: 8),
        Text(
          _callStatus,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isConnected ? Color(0xFF4CAF50) : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: _isMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic_fill,
            label: _isMuted ? 'Unmute' : 'Mute',
            isActive: _isMuted,
            onTap: _toggleMute,
          ),
          if (widget.isVideoCall)
            _buildActionButton(
              icon: _isCameraOff ? CupertinoIcons.video_camera : CupertinoIcons.video_camera_solid,
              label: _isCameraOff ? 'Camera On' : 'Camera Off',
              isActive: _isCameraOff,
              onTap: _toggleCamera,
            )
          else
            _buildActionButton(
              icon: _isSpeakerOn ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_1_fill,
              label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
              isActive: _isSpeakerOn,
              onTap: _toggleSpeaker,
            ),
          _buildEndCallButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
              boxShadow: [BoxShadow(color: Color(0xFFEF4444).withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
            ),
            child: Icon(CupertinoIcons.phone_down_fill, color: Colors.white, size: 32),
          ),
          SizedBox(height: 8),
          Text('End', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
        ],
      ),
    );
  }
}
