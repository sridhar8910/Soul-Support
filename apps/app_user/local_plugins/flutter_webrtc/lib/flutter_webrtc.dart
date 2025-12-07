// Stub implementation of flutter_webrtc for Windows platform
// WebRTC is not supported on Windows, so this provides type definitions only

import 'dart:async';
import 'package:flutter/material.dart';

// Enums
enum RTCPeerConnectionState {
  RTCPeerConnectionStateNew,
  RTCPeerConnectionStateConnecting,
  RTCPeerConnectionStateConnected,
  RTCPeerConnectionStateDisconnected,
  RTCPeerConnectionStateFailed,
  RTCPeerConnectionStateClosed,
}

enum RTCIceConnectionState {
  RTCIceConnectionStateNew,
  RTCIceConnectionStateChecking,
  RTCIceConnectionStateConnected,
  RTCIceConnectionStateCompleted,
  RTCIceConnectionStateFailed,
  RTCIceConnectionStateDisconnected,
  RTCIceConnectionStateClosed,
}

enum RTCVideoViewObjectFit {
  RTCVideoViewObjectFitContain,
  RTCVideoViewObjectFitCover,
}

// RTCIceServer stub
class RTCIceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  RTCIceServer({
    required this.urls,
    this.username,
    this.credential,
  });
}

// RTCIceCandidate stub
class RTCIceCandidate {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  RTCIceCandidate(
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  );
}

// RTCSessionDescription stub
class RTCSessionDescription {
  final String sdp;
  final String type;

  RTCSessionDescription(this.sdp, this.type);
}

// RTCPeerConnection stub
class RTCPeerConnection {
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCPeerConnectionState)? onConnectionState;
  Function(RTCIceConnectionState)? onIceConnectionState;
  Function(MediaStream)? onAddStream;
  Function(RTCTrackEvent)? onTrack;

  Future<void> setLocalDescription(RTCSessionDescription description) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }

  Future<RTCSessionDescription> createOffer([Map<String, dynamic>? options]) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }

  Future<RTCSessionDescription> createAnswer() async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }

  Future<void> addTrack(MediaStreamTrack track, MediaStream stream) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }

  Future<void> close() async {
    // No-op for stub
  }
}

// RTCVideoRenderer stub
class RTCVideoRenderer {
  MediaStream? srcObject;
  bool get initialized => false;

  Future<void> initialize() async {
    // No-op for stub
  }

  Future<void> dispose() async {
    // No-op for stub
  }
}

// RTCVideoView widget stub
class RTCVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final RTCVideoViewObjectFit objectFit;

  const RTCVideoView(
    this.renderer, {
    this.mirror = false,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Return a placeholder container since WebRTC is not supported on Windows
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}

// MediaStream stub
class MediaStream {
  List<MediaStreamTrack> getTracks() {
    return [];
  }

  List<MediaStreamTrack> getAudioTracks() {
    return [];
  }

  List<MediaStreamTrack> getVideoTracks() {
    return [];
  }

  Future<void> dispose() async {
    // No-op for stub
  }
}

// MediaStreamTrack stub
class MediaStreamTrack {
  String get kind => 'audio';
  bool enabled = true;
}

// RTCTrackEvent stub
class RTCTrackEvent {
  final MediaStreamTrack track;
  final List<MediaStream> streams;

  RTCTrackEvent({
    required this.track,
    required this.streams,
  });
}

// Helper stub
class Helper {
  static Future<void> switchCamera(MediaStreamTrack track) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }
}

// MediaDevices stub (using different name to avoid conflict with Flutter's Navigator)
class MediaDevices {
  Future<MediaStream> getUserMedia(Map<String, dynamic> constraints) async {
    throw UnimplementedError('WebRTC not supported on Windows');
  }
}

// WebRTCNavigator stub (renamed to avoid conflict with Flutter's Navigator widget)
class WebRTCNavigator {
  final MediaDevices mediaDevices = MediaDevices();
}

// Global navigator instance for WebRTC (using different name)
final navigator = WebRTCNavigator();

// createPeerConnection function stub
Future<RTCPeerConnection> createPeerConnection(
  Map<String, dynamic> configuration,
) async {
  throw UnimplementedError('WebRTC not supported on Windows');
}

