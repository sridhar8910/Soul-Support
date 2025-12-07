// lib/webrtc/signaling_ws.dart
// Cross-platform WebSocket signaling adapter for WebRTC
// Works on web (Chrome), Android, and iOS

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnSignalingMessage = void Function(Map<String, dynamic> msg);
typedef OnConnected = void Function();
typedef OnDisconnected = void Function();

class SignalingWS {
  final String wsUrl; // e.g. "ws://127.0.0.1:8000/ws/webrtc/<call_id>/"
  final Map<String, String>? headers; // optional auth header
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  OnSignalingMessage? onMessage;
  OnConnected? onConnected;
  OnDisconnected? onDisconnected;

  SignalingWS({required this.wsUrl, this.headers});

  void connect() {
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> msg = data is String 
                ? jsonDecode(data) 
                : Map<String, dynamic>.from(data);
            onMessage?.call(msg);
          } catch (e) {
            print('[SignalingWS] Error parsing message: $e');
            // ignore parse error
          }
        },
        onDone: () {
          onDisconnected?.call();
        },
        onError: (err) {
          print('[SignalingWS] WebSocket error: $err');
          onDisconnected?.call();
        },
        cancelOnError: true,
      );

      // We don't have an explicit "connected" event, call after small delay
      Future.delayed(const Duration(milliseconds: 200), () => onConnected?.call());
    } catch (e) {
      print('[SignalingWS] Connection error: $e');
      onDisconnected?.call();
    }
  }

  void send(Map<String, dynamic> msg) {
    if (_channel == null) {
      print('[SignalingWS] Cannot send: not connected');
      return;
    }
    
    try {
      _channel!.sink.add(jsonEncode(msg));
      print('[SignalingWS] Sent: ${msg['type']}');
    } catch (e) {
      print('[SignalingWS] Error sending message: $e');
    }
  }

  void close() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
    print('[SignalingWS] Closed');
  }

  bool get isConnected => _channel != null;
}

