// lib/screens/audio_call_screen.dart
// Simple audio-only call screen using WebRTCManager
// Works with Chrome, Android, and iOS

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../webrtc/webrtc_manager.dart';
import '../webrtc/signaling_ws.dart';
import 'package:common/api/api_client.dart';

class AudioCallScreen extends StatefulWidget {
  final int callId;
  final bool isCaller; // true = this user initiates the call
  final String? counsellorName;

  const AudioCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    this.counsellorName,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  WebRTCManager? _webrtcManager;
  SignalingWS? _signaling;
  final ApiClient _api = ApiClient();

  bool _muted = false;
  bool _isInitialized = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _status = 'Initializing...';
  String? _error;

  Timer? _callTimer;
  int _callDuration = 0;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    // Check platform support first
    if (!WebRTCManager.isPlatformSupported()) {
      final platform = kIsWeb 
          ? 'web browser' 
          : defaultTargetPlatform.toString().replaceAll('TargetPlatform.', '');
      
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isConnecting = false;
          _status = 'Platform not supported';
          _error = 'WebRTC not supported on $platform. Please use Chrome browser or mobile app.';
        });
      }
      return;
    }

    try {
      setState(() {
        _isInitialized = false;
        _isConnecting = true;
        _status = 'Connecting...';
        _error = null;
      });

      // Create WebRTC manager for audio-only call
      _webrtcManager = WebRTCManager(
        callId: widget.callId,
        isVideoCall: false, // Audio-only
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error;
              _status = 'Error: $error';
              _isConnecting = false;
            });
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
              _status = connected ? 'Connected' : 'Connecting...';
            });

            if (connected && _callStartTime == null) {
              _callStartTime = DateTime.now();
              _startTimer();
            }
          }
        },
      );

      // Initialize WebRTC connection (no renderers needed for audio)
      final initialized = await _webrtcManager!.initialize(
        localRenderer: null,
        remoteRenderer: null,
      );

      if (!initialized) {
        throw Exception('Failed to initialize WebRTC');
      }

      setState(() {
        _isInitialized = true;
        _status = widget.isCaller ? 'Creating offer...' : 'Waiting for call...';
      });

      // If caller, create offer immediately after initialization
      if (widget.isCaller) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _webrtcManager!.createOffer();
        setState(() {
          _status = 'Offer sent, waiting for answer...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _status = 'Initialization error: $e';
          _isConnecting = false;
        });
      }
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _callStartTime != null) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    if (_webrtcManager == null) return;

    _webrtcManager!.toggleMute();
    setState(() {
      _muted = !_muted;
    });
  }

  Future<void> _endCall() async {
    try {
      await _webrtcManager?.endCall();
      await _api.endCall(widget.callId);
    } catch (e) {
      print('[AudioCall] Error ending call: $e');
    }

    _callTimer?.cancel();
    _callTimer = null;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _webrtcManager?.dispose();
    _signaling?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text(
          widget.counsellorName ?? 'Audio Call',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _endCall,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Status display
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  
                  if (_isConnected && _callDuration > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // Call controls
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Mute button
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _muted ? Colors.red : Colors.white24,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _muted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _isInitialized ? _toggleMute : null,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    _muted ? 'Unmute' : 'Mute',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),

                  const SizedBox(height: 40),

                  // End call button
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _endCall,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  const Text(
                    'End Call',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

