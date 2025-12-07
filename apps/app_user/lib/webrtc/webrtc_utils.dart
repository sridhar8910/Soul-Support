import 'dart:convert';
import 'package:common/api/api_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Utility functions for WebRTC configuration
class WebRTCUtils {
  /// Get ICE servers configuration from backend
  static Future<List<Map<String, dynamic>>> getIceServers() async {
    try {
      final api = ApiClient();
      final response = await api.getTurnCredentials();
      
      if (response['iceServers'] != null) {
        final iceServers = (response['iceServers'] as List)
            .map((server) {
              if (server['urls'] != null) {
                final urls = server['urls'] is List 
                    ? (server['urls'] as List).cast<String>()
                    : [server['urls'] as String];
                
                final serverMap = <String, dynamic>{
                  'urls': urls,
                };
                
                if (server['username'] != null) {
                  serverMap['username'] = server['username'] as String;
                }
                if (server['credential'] != null) {
                  serverMap['credential'] = server['credential'] as String;
                }
                
                return serverMap;
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
        
        if (iceServers.isNotEmpty) {
          return iceServers;
        }
      }
    } catch (e) {
      print('[WebRTC] Error fetching TURN credentials: $e');
    }
    
    // Fallback to public STUN servers
    return [
      {
        'urls': ['stun:stun.l.google.com:19302'],
      },
      {
        'urls': ['stun:stun1.l.google.com:19302'],
      },
    ];
  }

  /// Create peer connection configuration
  static Future<Map<String, dynamic>> getPeerConnectionConfiguration() async {
    final iceServers = await getIceServers();
    
    return {
      'iceServers': iceServers,
      'iceTransportPolicy': 'all',
      'iceCandidatePoolSize': 10,
    };
  }

  /// Format connection state for logging
  static String formatConnectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'New';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'Connecting';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return 'Connected';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'Disconnected';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'Failed';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'Closed';
      default:
        return 'Unknown';
    }
  }

  /// Format ICE connection state for logging
  static String formatIceConnectionState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateNew:
        return 'New';
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return 'Checking';
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
        return 'Connected';
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return 'Completed';
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        return 'Failed';
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return 'Disconnected';
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return 'Closed';
      default:
        return 'Unknown';
    }
  }
}

