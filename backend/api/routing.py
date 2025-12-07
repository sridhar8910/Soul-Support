"""
WebSocket URL routing for chat and WebRTC functionality.
"""
from django.urls import path
from .consumers import ChatConsumer
from .consumers_webrtc import WebRTCConsumer

websocket_urlpatterns = [
    path("ws/chat/<int:chat_id>/", ChatConsumer.as_asgi()),
    path("ws/webrtc/<int:call_id>/", WebRTCConsumer.as_asgi()),
]

