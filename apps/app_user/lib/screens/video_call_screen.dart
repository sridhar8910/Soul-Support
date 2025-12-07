import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
    // Check platform support first
    if (!WebRTCManager.isPlatformSupported()) {
      final platform = kIsWeb 
          ? 'web browser' 
          : defaultTargetPlatform.toString().replaceAll('TargetPlatform.', '');
      
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isConnecting = false;
          _error = 'WebRTC not supported on $platform';
        });
      }
      return;
    }

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

        // User is the caller - wait a moment for WebSocket to be fully connected
        // then create offer to start call
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && _webrtcManager != null) {
          await _webrtcManager!.createOffer();
        }
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
    
    if (_webrtcManager != null) {
      await _webrtcManager!.endCall();
      await _webrtcManager!.dispose();
    }
    
    // Don't dispose renderers here - let dispose() handle it
    // This prevents double-dispose errors
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    
    // Dispose WebRTC manager (which will dispose renderers if needed)
    _webrtcManager?.dispose();
    
    // Only dispose renderers if they weren't already disposed by manager
    // Use try-catch to handle already-disposed errors gracefully
    if (_localRenderer != null) {
      try {
        _localRenderer!.dispose();
      } catch (e) {
        // Already disposed, ignore
      }
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      try {
        _remoteRenderer!.dispose();
      } catch (e) {
        // Already disposed, ignore
      }
      _remoteRenderer = null;
    }
    
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
                      // Show platform not supported message
                      if (_error != null && _error!.contains('not supported')) ...[
                        Icon(
                          Icons.desktop_windows,
                          color: Colors.orange,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Desktop Not Supported',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'WebRTC calls are not available on Windows desktop.\n\n'
                            'Please use one of these options:',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildOptionRow(Icons.open_in_browser, 'Chrome Browser', 'Open in Chrome for web calls'),
                              const SizedBox(height: 12),
                              _buildOptionRow(Icons.phone_android, 'Android App', 'Use the mobile app'),
                              const SizedBox(height: 12),
                              _buildOptionRow(Icons.phone_iphone, 'iOS App', 'Use the mobile app'),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Normal connecting/error states
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
                        if (_error != null && !_error!.contains('not supported')) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ],
                      if (widget.counsellorName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.counsellorName!,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        ],
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
                mainAxisSize: MainAxisSize.min,
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

  Widget _buildOptionRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
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

