import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_signaling.dart';
import 'webrtc_utils.dart';

// Web-only imports for audio element
import 'dart:html' as html show AudioElement, document;
import 'dart:js_util' as js_util;

/// WebRTC connection manager
class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  WebRTCSignaling? _signaling;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _localStream;
  MediaStream? _remoteStream; // Store remote stream for audio playback
  
  // Web-only: hidden audio element for reliable audio playback
  html.AudioElement? _webAudioElement;
  bool _disposed = false; // Guard against operations after dispose
  
  final int callId;
  final bool isVideoCall;
  final Function(String)? onError;
  final Function()? onCallEnded;
  final Function(bool)? onConnectionStateChanged;

  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = false;
  
  // Track connection states
  RTCPeerConnectionState _peerConnectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  RTCIceConnectionState _iceConnectionState = RTCIceConnectionState.RTCIceConnectionStateNew;

  WebRTCManager({
    required this.callId,
    this.isVideoCall = true,
    this.onError,
    this.onCallEnded,
    this.onConnectionStateChanged,
  });

  /// Initialize WebRTC connection
  Future<bool> initialize({
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
  }) async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Set renderers for video calls, or for audio-only calls on web (for audio playback)
      if (isVideoCall) {
        _localRenderer = localRenderer;
        _remoteRenderer = remoteRenderer;

        // Initialize renderers if provided
        // Note: initialize() can be called multiple times safely
        if (_localRenderer != null) {
          await _localRenderer!.initialize();
        }
        if (_remoteRenderer != null) {
          await _remoteRenderer!.initialize();
        }
      } else if (kIsWeb) {
        // For audio-only calls on web, initialize a hidden remote renderer for audio playback
        // The renderer will handle audio automatically when srcObject is set
        if (remoteRenderer != null) {
          _remoteRenderer = remoteRenderer;
          await _remoteRenderer!.initialize();
          print('[WebRTC] Initialized hidden renderer for audio-only call on web');
        } else {
          // Create our own hidden renderer if none provided
          _remoteRenderer = RTCVideoRenderer();
          await _remoteRenderer!.initialize();
          print('[WebRTC] Created hidden renderer for audio-only call on web');
        }
      }

      // Get ICE servers
      final config = await WebRTCUtils.getPeerConnectionConfiguration();
      
      // Create peer connection
      _peerConnection = await createPeerConnection(config);
      
      // Set up event handlers
      _setupPeerConnectionHandlers();

      // Get user media (audio/video)
      await _getUserMedia();

      // Initialize signaling
      _signaling = WebRTCSignaling(
        callId: callId,
        onOffer: _handleOffer,
        onAnswer: _handleAnswer,
        onIceCandidate: _handleIceCandidate,
        onCallEnded: () {
          onCallEnded?.call();
        },
        onError: (error) {
          onError?.call(error);
        },
      );

      final connected = await _signaling!.connect();
      if (!connected) {
        await dispose();
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      print('[WebRTC Manager] Initialize error: $e');
      onError?.call('Failed to initialize: $e');
      await dispose();
      return false;
    }
  }

  /// Update connection state based on both peer and ICE connection states
  void _updateConnectionState() {
    // Consider connected if either:
    // 1. Peer connection is connected AND ICE connection is connected/completed
    // 2. ICE connection is connected/completed (more reliable indicator)
    final isConnected = (_peerConnectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
            (_iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
             _iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateCompleted)) ||
        (_iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
         _iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateCompleted);
    
    onConnectionStateChanged?.call(isConnected);
    
    if (isConnected) {
      print('[WebRTC] Connection established - Peer: ${WebRTCUtils.formatConnectionState(_peerConnectionState)}, ICE: ${WebRTCUtils.formatIceConnectionState(_iceConnectionState)}');
    } else {
      print('[WebRTC] Connection state - Peer: ${WebRTCUtils.formatConnectionState(_peerConnectionState)}, ICE: ${WebRTCUtils.formatIceConnectionState(_iceConnectionState)}');
    }
  }

  /// Set up peer connection event handlers
  void _setupPeerConnectionHandlers() {
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('[WebRTC] ICE candidate: ${candidate.candidate}');
      _signaling?.sendIceCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('[WebRTC] Connection state: ${WebRTCUtils.formatConnectionState(state)}');
      _peerConnectionState = state;
      _updateConnectionState();
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('[WebRTC] ICE connection state: ${WebRTCUtils.formatIceConnectionState(state)}');
      _iceConnectionState = state;
      _updateConnectionState();
    };

    _peerConnection?.onAddStream = (MediaStream stream) {
      print('[WebRTC] Remote stream added');
      _handleRemoteStream(stream);
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      print('[WebRTC] Track received: ${event.track.kind}');
      
      // Store remote stream from track event
      if (event.streams.isNotEmpty) {
        _handleRemoteStream(event.streams[0]);
      }
    };
  }

  /// Handle remote stream (audio/video) - web-safe with audio element
  void _handleRemoteStream(MediaStream stream) {
    if (_disposed) return;
    
    print('[WebRTC] Remote stream received - this indicates connection is working');
    _remoteStream = stream; // Store remote stream for both audio and video
    
    // If we receive a remote stream, we're definitely connected
    // Update connection state to ensure UI reflects connection
    if (_iceConnectionState != RTCIceConnectionState.RTCIceConnectionStateConnected &&
        _iceConnectionState != RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      // Force update to connected if we have remote stream
      _iceConnectionState = RTCIceConnectionState.RTCIceConnectionStateConnected;
      _updateConnectionState();
    }
    
    // Set remote stream on renderer for video calls, or for audio-only calls on web
    if (_remoteRenderer != null && (isVideoCall || (!isVideoCall && kIsWeb))) {
      try {
        _remoteRenderer!.srcObject = stream;
        if (!isVideoCall && kIsWeb) {
          print('[WebRTC] Set remote stream on hidden renderer for audio-only call on web');
        } else if (isVideoCall) {
          print('[WebRTC] Set remote stream on renderer for video call');
        }
      } catch (e) {
        print('[WebRTC] Error setting remote renderer: $e');
      }
    }
    
    // Always ensure audio tracks are enabled for both video and audio-only calls
    // This ensures audio works on all platforms (web, Android, iOS)
    stream.getAudioTracks().forEach((track) {
      track.enabled = true;
      print('[WebRTC] Audio track enabled: ${track.id} (video call: $isVideoCall)');
    });
    
    // Web-only: create hidden audio element and attach stream for reliable playback
    if (kIsWeb) {
      _attachWebAudioElement(stream);
    }
  }

  /// Web-only: Attach MediaStream to hidden HTMLAudioElement for reliable playback
  /// For audio-only calls, we ensure the renderer is set up (it handles audio automatically)
  /// For video calls, the renderer handles both video and audio automatically
  void _attachWebAudioElement(MediaStream stream) {
    if (_disposed || !kIsWeb) return;
    
    // For audio-only calls, the renderer should be initialized and will handle audio
    // flutter_webrtc's renderer automatically plays audio when srcObject is set
    if (!isVideoCall) {
      if (_remoteRenderer != null && _remoteRenderer!.srcObject == stream) {
        print('[WebRTC] Audio-only call: renderer is set up, audio should play automatically');
        // The renderer's srcObject is already set in _handleRemoteStream
        // flutter_webrtc's renderer will handle audio playback automatically
        return;
      } else {
        print('[WebRTC] Audio-only call: renderer not set up yet, will be handled by renderer initialization');
        return;
      }
    }
    
    // For video calls, the video renderer handles both video and audio automatically
    // The renderer's srcObject is set in _handleRemoteStream, and audio tracks are enabled
    // No separate audio element needed - the video renderer plays audio through the video element
    if (_remoteRenderer != null && _remoteRenderer!.srcObject == stream) {
      print('[WebRTC] Video call: renderer is set up, audio should play automatically through video renderer');
    } else {
      print('[WebRTC] Video call: renderer will handle audio when stream is attached');
    }
  }

  /// Get user media (audio/video)
  Future<void> _getUserMedia() async {
    try {
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        if (isVideoCall) 'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Only set srcObject for video renderer if it's a video call
      if (isVideoCall && _localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
      }

      // Add tracks to peer connection
      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });

      print('[WebRTC] User media obtained');
    } catch (e) {
      print('[WebRTC] Error getting user media: $e');
      onError?.call('Failed to access camera/microphone: $e');
      rethrow;
    }
  }

  /// Create and send offer
  Future<void> createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideoCall,
      });

      await _peerConnection!.setLocalDescription(offer);
      
      print('[WebRTC] Offer created');
      
      _signaling?.sendOffer({
        'type': offer.type,
        'sdp': offer.sdp,
      });
    } catch (e) {
      print('[WebRTC] Error creating offer: $e');
      onError?.call('Failed to create offer: $e');
    }
  }

  /// Handle incoming offer
  Future<void> _handleOffer(Map<String, dynamic> message) async {
    try {
      final offerMap = message['offer'] as Map<String, dynamic>;
      final offer = RTCSessionDescription(
        offerMap['sdp'] as String,
        offerMap['type'] as String,
      );

      await _peerConnection!.setRemoteDescription(offer);

      // Create and send answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _signaling?.sendAnswer({
        'type': answer.type,
        'sdp': answer.sdp,
      });

      print('[WebRTC] Answer created and sent');
    } catch (e) {
      print('[WebRTC] Error handling offer: $e');
      onError?.call('Failed to handle offer: $e');
    }
  }

  /// Handle incoming answer
  Future<void> _handleAnswer(Map<String, dynamic> message) async {
    try {
      final answerMap = message['answer'] as Map<String, dynamic>;
      final answer = RTCSessionDescription(
        answerMap['sdp'] as String,
        answerMap['type'] as String,
      );

      await _peerConnection!.setRemoteDescription(answer);
      print('[WebRTC] Answer received and set');
    } catch (e) {
      print('[WebRTC] Error handling answer: $e');
      onError?.call('Failed to handle answer: $e');
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    try {
      final candidateMap = message['candidate'] as Map<String, dynamic>;
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String,
        candidateMap['sdpMid'] as String?,
        candidateMap['sdpMLineIndex'] as int?,
      );

      await _peerConnection!.addCandidate(candidate);
      print('[WebRTC] ICE candidate added');
    } catch (e) {
      print('[WebRTC] Error handling ICE candidate: $e');
      // Don't throw - ICE candidates can fail silently
    }
  }

  /// Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  bool get isMuted => _isMuted;

  /// Toggle video
  void toggleVideo() {
    if (!isVideoCall) return;
    
    _isVideoEnabled = !_isVideoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }

  bool get isVideoEnabled => _isVideoEnabled;

  /// Toggle speaker (mobile only)
  void toggleSpeaker() {
    _isSpeakerEnabled = !_isSpeakerEnabled;
    // Speaker control is platform-specific and may require native code
    // For now, this is a placeholder
  }

  bool get isSpeakerEnabled => _isSpeakerEnabled;

  /// Switch camera (video calls only)
  Future<void> switchCamera() async {
    if (!isVideoCall) return;

    try {
      final videoTrack = _localStream?.getVideoTracks().first;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    } catch (e) {
      print('[WebRTC] Error switching camera: $e');
    }
  }

  /// End call
  Future<void> endCall() async {
    await _signaling?.sendCallEnded();
    await dispose();
  }

  /// Dispose resources
  Future<void> dispose() async {
    _disposed = true; // Set flag first to prevent new operations
    
    // Stop and dispose local stream tracks
    _localStream?.getTracks().forEach((track) {
      track.enabled = false;
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    
    // Stop and dispose remote stream tracks (for audio playback)
    _remoteStream?.getTracks().forEach((track) {
      track.enabled = false;
      track.stop();
    });
    await _remoteStream?.dispose();
    _remoteStream = null;
    
    // Web-only: remove audio element
    if (kIsWeb && _webAudioElement != null) {
      try {
        // Unset srcObject and remove element
        js_util.setProperty(_webAudioElement!, 'srcObject', null);
        _webAudioElement!.pause();
        _webAudioElement!.remove();
        print('[WebRTC] Removed web audio element');
      } catch (e) {
        print('[WebRTC] Error cleaning web audio element: $e');
      }
      _webAudioElement = null;
    }

    await _peerConnection?.close();
    _peerConnection = null;

    _signaling?.disconnect();
    _signaling = null;

    // Dispose renderers if they exist (with guards)
    if (_localRenderer != null) {
      try {
        _localRenderer!.srcObject = null;
        await _localRenderer!.dispose();
      } catch (e) {
        print('[WebRTC Manager] Error disposing local renderer: $e');
      }
      _localRenderer = null;
    }

    if (_remoteRenderer != null) {
      try {
        _remoteRenderer!.srcObject = null;
        await _remoteRenderer!.dispose();
      } catch (e) {
        print('[WebRTC Manager] Error disposing remote renderer: $e');
      }
      _remoteRenderer = null;
    }

    _isInitialized = false;
    print('[WebRTC Manager] Disposed');
  }
}

