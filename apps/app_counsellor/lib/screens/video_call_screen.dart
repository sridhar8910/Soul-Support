import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:common/api/api_client.dart';
import 'package:common/widgets/widgets.dart';
import '../webrtc/webrtc_manager.dart';

class VideoCallScreen extends StatefulWidget {
  final int callId;
  final String? counsellorName;
  final bool isVideoCall;

  const VideoCallScreen({
    super.key,
    required this.callId,
    this.counsellorName,
    this.isVideoCall = true,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final ApiClient _api = ApiClient();
  WebRTCManager? _webrtcManager;
  
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  
  bool _isInitialized = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = false;
  bool _isLocalVideoEnabled = true;
  
  String? _error;
  Timer? _callTimer;
  int _callDuration = 0;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  Future<void> _initializeWebRTC() async {
    try {
      setState(() {
        _isInitialized = false;
        _isConnecting = true;
        _error = null;
      });

      // Initialize video renderers for video calls
      // For audio-only calls on web, also initialize a hidden remote renderer for audio playback
      if (widget.isVideoCall) {
        _localRenderer = RTCVideoRenderer();
        _remoteRenderer = RTCVideoRenderer();
        
        await _localRenderer!.initialize();
        await _remoteRenderer!.initialize();
      } else if (kIsWeb) {
        // For audio-only calls on web, create a hidden remote renderer for audio playback
        _remoteRenderer = RTCVideoRenderer();
        await _remoteRenderer!.initialize();
        print('[Video Call] Initialized hidden renderer for audio-only call on web');
      }

      // Create WebRTC manager
      _webrtcManager = WebRTCManager(
        callId: widget.callId,
        isVideoCall: widget.isVideoCall,
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error;
              _isConnecting = false;
            });
            showErrorSnackBar(context, error);
          }
        },
        onCallEnded: () {
          if (mounted) {
            _endCall();
          }
        },
        onConnectionStateChanged: (connected) {
          if (mounted) {
            setState(() {
              _isConnected = connected;
              _isConnecting = !connected;
            });
            
            if (connected && _callStartTime == null) {
              _callStartTime = DateTime.now();
              _startTimer();
            }
          }
        },
      );

      // Initialize WebRTC connection
      // Pass renderers for video calls, or remote renderer for audio-only calls on web
      final initialized = await _webrtcManager!.initialize(
        localRenderer: widget.isVideoCall ? _localRenderer : null,
        remoteRenderer: widget.isVideoCall ? _remoteRenderer : (kIsWeb ? _remoteRenderer : null),
      );

      if (!initialized) {
        throw Exception('Failed to initialize WebRTC');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isConnecting = true;
        });

        // For counsellor: Wait for offer from user (don't create offer)
        // The offer handler will automatically create and send answer when offer is received
        // Only user (caller) should create offer
        print('[Video Call] Counsellor side - waiting for offer from user');
        
        // If no offer received within 5 seconds, the user might not have connected yet
        // This is normal - the offer will come when the user connects (or be replayed by backend)
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isConnecting && !_isConnected) {
            print('[Video Call] Still waiting for offer from user... (this is normal if user connects late)');
          }
        });
      }
    } catch (e) {
      print('[Video Call] Initialization error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitialized = false;
          _isConnecting = false;
        });
        showErrorSnackBar(context, 'Failed to initialize call: $e');
      }
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    _webrtcManager?.toggleMute();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleVideo() {
    if (widget.isVideoCall) {
      _webrtcManager?.toggleVideo();
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
        _isLocalVideoEnabled = _isVideoEnabled;
      });
    }
  }

  void _toggleSpeaker() {
    _webrtcManager?.toggleSpeaker();
    setState(() {
      _isSpeakerEnabled = !_isSpeakerEnabled;
    });
  }

  Future<void> _switchCamera() async {
    if (widget.isVideoCall) {
      await _webrtcManager?.switchCamera();
    }
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    
    try {
      // End call via API
      await _api.endCall(widget.callId);
    } catch (e) {
      print('[Video Call] Error ending call via API: $e');
    }
    
    if (_webrtcManager != null) {
      await _webrtcManager!.endCall();
      await _webrtcManager!.dispose();
    }
    
    await _localRenderer?.dispose();
    await _remoteRenderer?.dispose();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _webrtcManager?.dispose();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen) - only for video calls
            if (widget.isVideoCall && _isInitialized && _remoteRenderer != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer!,
                  mirror: false,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isVideoCall
                            ? (_isConnecting 
                                ? Icons.videocam 
                                : _error != null 
                                    ? Icons.error_outline 
                                    : Icons.videocam_off)
                            : (_isConnecting 
                                ? Icons.phone 
                                : _error != null 
                                    ? Icons.error_outline 
                                    : Icons.phone_in_talk),
                        color: _error != null ? Colors.red : Colors.white54,
                        size: 64,
                      ),
                      if (_isConnecting && !widget.isVideoCall)
                        const SizedBox(height: 16),
                      if (_isConnecting && !widget.isVideoCall)
                        const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        _isConnecting
                            ? 'Connecting...'
                            : _error != null
                                ? 'Connection failed'
                                : widget.isVideoCall
                                    ? 'Waiting for video...'
                                    : 'Voice call',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      if (widget.counsellorName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.counsellorName!,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Local video preview (small, top-right)
            if (_isInitialized && widget.isVideoCall && _localRenderer != null && _isLocalVideoEnabled)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(
                      _localRenderer!,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Call duration and info (top center)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (_isConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (widget.counsellorName != null && !_isConnected) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.counsellorName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Control buttons (bottom)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _ControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: _toggleMute,
                    backgroundColor: _isMuted ? Colors.red : Colors.white24,
                  ),

                  // Video toggle button (only for video calls)
                  if (widget.isVideoCall)
                    _ControlButton(
                      icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      label: _isVideoEnabled ? 'Video Off' : 'Video On',
                      onPressed: _toggleVideo,
                      backgroundColor: _isVideoEnabled ? Colors.white24 : Colors.red,
                    ),

                  // Speaker button
                  _ControlButton(
                    icon: _isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
                    label: _isSpeakerEnabled ? 'Speaker Off' : 'Speaker On',
                    onPressed: _toggleSpeaker,
                    backgroundColor: _isSpeakerEnabled ? Colors.white24 : Colors.white24,
                  ),

                  // Switch camera (video calls only)
                  if (widget.isVideoCall)
                    _ControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Switch',
                      onPressed: _switchCamera,
                      backgroundColor: Colors.white24,
                    ),

                  // End call button
                  _ControlButton(
                    icon: Icons.call_end,
                    label: 'End',
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),

            // Error message
            if (_error != null)
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _error = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color? iconColor;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor ?? Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

