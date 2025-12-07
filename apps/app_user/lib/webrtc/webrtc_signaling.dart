import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:common/api/api_client.dart';

/// WebSocket signaling handler for WebRTC
class WebRTCSignaling {
  WebSocketChannel? _channel;
  final int callId;
  final Function(Map<String, dynamic>)? onOffer;
  final Function(Map<String, dynamic>)? onAnswer;
  final Function(Map<String, dynamic>)? onIceCandidate;
  final Function()? onCallEnded;
  final Function(String)? onError;

  WebRTCSignaling({
    required this.callId,
    this.onOffer,
    this.onAnswer,
    this.onIceCandidate,
    this.onCallEnded,
    this.onError,
  });

  StreamSubscription? _subscription;

  /// Connect to WebRTC signaling WebSocket
  Future<bool> connect() async {
    try {
      final api = ApiClient();
      _channel = await api.connectWebRTCWebSocket(callId);
      
      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (e) {
            print('[WebRTC Signaling] Error parsing message: $e');
            onError?.call('Invalid message format');
          }
        },
        onError: (error) {
          print('[WebRTC Signaling] WebSocket error: $error');
          onError?.call('WebSocket error: $error');
        },
        onDone: () {
          print('[WebRTC Signaling] WebSocket closed');
        },
      );

      return true;
    } catch (e) {
      print('[WebRTC Signaling] Connection error: $e');
      onError?.call('Failed to connect: $e');
      return false;
    }
  }

  /// Handle incoming signaling messages
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    print('[WebRTC Signaling] Received message type: $type');

    switch (type) {
      case 'offer':
        onOffer?.call(message);
        break;
      case 'answer':
        onAnswer?.call(message);
        break;
      case 'ice-candidate':
        onIceCandidate?.call(message);
        break;
      case 'call-ended':
        onCallEnded?.call();
        break;
      case 'error':
        final error = message['error'] as String? ?? 'Unknown error';
        onError?.call(error);
        break;
      default:
        print('[WebRTC Signaling] Unknown message type: $type');
    }
  }

  /// Send offer
  Future<void> sendOffer(Map<String, dynamic> offer) async {
    _sendMessage({
      'type': 'offer',
      'offer': offer,
    });
  }

  /// Send answer
  Future<void> sendAnswer(Map<String, dynamic> answer) async {
    _sendMessage({
      'type': 'answer',
      'answer': answer,
    });
  }

  /// Send ICE candidate
  Future<void> sendIceCandidate(Map<String, dynamic> candidate) async {
    _sendMessage({
      'type': 'ice-candidate',
      'candidate': candidate,
    });
  }

  /// Send call ended
  Future<void> sendCallEnded() async {
    _sendMessage({
      'type': 'call-ended',
    });
  }

  /// Send message to WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
        print('[WebRTC Signaling] Sent: ${message['type']}');
      } catch (e) {
        print('[WebRTC Signaling] Error sending message: $e');
        onError?.call('Failed to send message: $e');
      }
    }
  }

  /// Disconnect from signaling server
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    print('[WebRTC Signaling] Disconnected');
  }

  /// Check if connected
  bool get isConnected => _channel != null;
}

