"""
WebRTC signaling consumer for video/audio calls.
Handles WebSocket connections for WebRTC peer-to-peer signaling.
"""
import json
import logging
from typing import Any, Dict

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import User
from .models import Call

logger = logging.getLogger(__name__)


class WebRTCConsumer(AsyncWebsocketConsumer):
    """WebSocket consumer for WebRTC signaling (offer/answer/ICE candidates)."""

    # Class-level storage for missed messages (message replay)
    # Format: {call_id: [list of messages]}
    _call_messages: Dict[str, list] = {}

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.call_id: str = ""
        self.room_group_name: str = ""
        self.user: Any = None

    async def connect(self) -> None:
        """Handle WebSocket connection for WebRTC signaling."""
        url_route = self.scope.get("url_route", {})
        kwargs = url_route.get("kwargs", {})
        self.call_id = str(kwargs.get("call_id", ""))
        self.room_group_name = f"webrtc_call_{self.call_id}"
        self.user = self.scope["user"]

        logger.info(
            "WebRTC CONNECT attempt: call_id=%s, user=%s",
            self.call_id,
            self.user.username if self.user.is_authenticated else "anonymous",
        )

        # Check if user is authenticated
        if not self.user.is_authenticated:
            logger.warning("WebRTC CONNECT rejected: user not authenticated (call_id=%s)", self.call_id)
            await self.close()
            return

        # Verify user has access to this call
        has_access = await self.check_call_access(self.user, self.call_id)
        if not has_access:
            logger.warning("WebRTC CONNECT rejected: no access to call %s for user %s", self.call_id, self.user.username)
            await self.close()
            return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()
        logger.info("WebRTC CONNECT success: Joined group %s (user=%s)", self.room_group_name, self.user.username)
        
        # Send any missed messages to newly connected client (message replay)
        if self.call_id in WebRTCConsumer._call_messages:
            replayed_count = 0
            for msg in WebRTCConsumer._call_messages[self.call_id]:
                # Don't send back to sender
                if msg.get('from_user_id') != self.user.id:
                    await self.send(text_data=json.dumps(msg))
                    replayed_count += 1
                    logger.info(
                        "Replayed message to user %s: type=%s (call_id=%s)",
                        self.user.username,
                        msg.get('type'),
                        self.call_id
                    )
            if replayed_count > 0:
                logger.info(
                    "Replayed %d missed message(s) to user %s (call_id=%s)",
                    replayed_count,
                    self.user.username,
                    self.call_id
                )

    async def disconnect(self, close_code: int) -> None:
        """Handle WebSocket disconnection."""
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
        logger.info("WebRTC DISCONNECT: Left group %s (close_code=%s)", self.room_group_name, close_code)
        
        # Clean up old messages for this call (optional - prevents memory leaks)
        # Keep messages for 5 minutes after last disconnect
        # This is a simple cleanup - in production, consider using Redis with TTL
        if self.call_id in WebRTCConsumer._call_messages:
            # For now, we keep messages until call ends
            # In production, add timestamp-based cleanup here
            pass

    async def receive(self, text_data: str) -> None:
        """Handle WebRTC signaling messages (offer, answer, ICE candidates)."""
        try:
            data = json.loads(text_data)
            message_type = data.get("type")

            logger.info("WebRTC RECEIVE: call_id=%s, type=%s, user=%s", self.call_id, message_type, self.user.username)

            # Route message based on type
            if message_type == "offer":
                await self.handle_offer(data)
            elif message_type == "answer":
                await self.handle_answer(data)
            elif message_type == "ice-candidate":
                await self.handle_ice_candidate(data)
            elif message_type == "call-ended":
                await self.handle_call_ended()
            else:
                logger.warning("Unknown WebRTC message type: %s", message_type)
                await self.send(text_data=json.dumps({
                    "error": f"Unknown message type: {message_type}"
                }))

        except json.JSONDecodeError as e:
            logger.error("Invalid JSON in WebRTC message: %s", e)
            await self.send(text_data=json.dumps({
                "error": "Invalid message format"
            }))
        except Exception as e:
            logger.error("Error processing WebRTC message: %s", e, exc_info=True)
            await self.send(text_data=json.dumps({
                "error": f"Failed to process message: {str(e)}"
            }))

    async def handle_offer(self, data: Dict[str, Any]) -> None:
        """Handle WebRTC offer from caller."""
        offer = data.get("offer")
        if not offer:
            await self.send(text_data=json.dumps({"error": "Missing offer"}))
            return

        # Store the offer for message replay
        if self.call_id not in WebRTCConsumer._call_messages:
            WebRTCConsumer._call_messages[self.call_id] = []
        
        # Remove any previous offer for this call (only keep latest)
        WebRTCConsumer._call_messages[self.call_id] = [
            m for m in WebRTCConsumer._call_messages[self.call_id] 
            if m.get('type') != 'offer'
        ]
        
        # Store the new offer
        offer_msg = {
            "type": "offer",
            "offer": offer,
            "from_user_id": self.user.id,
            "from_username": self.user.username,
        }
        WebRTCConsumer._call_messages[self.call_id].append(offer_msg)

        # Broadcast offer to other participants
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "webrtc_offer",
                "offer": offer,
                "from_user_id": self.user.id,
                "from_username": self.user.username,
            }
        )

    async def handle_answer(self, data: Dict[str, Any]) -> None:
        """Handle WebRTC answer from callee."""
        answer = data.get("answer")
        if not answer:
            await self.send(text_data=json.dumps({"error": "Missing answer"}))
            return

        # Store the answer for message replay
        if self.call_id not in WebRTCConsumer._call_messages:
            WebRTCConsumer._call_messages[self.call_id] = []
        
        # Remove any previous answer for this call (only keep latest)
        WebRTCConsumer._call_messages[self.call_id] = [
            m for m in WebRTCConsumer._call_messages[self.call_id] 
            if m.get('type') != 'answer'
        ]
        
        # Store the new answer
        answer_msg = {
            "type": "answer",
            "answer": answer,
            "from_user_id": self.user.id,
            "from_username": self.user.username,
        }
        WebRTCConsumer._call_messages[self.call_id].append(answer_msg)

        # Broadcast answer to other participants
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "webrtc_answer",
                "answer": answer,
                "from_user_id": self.user.id,
                "from_username": self.user.username,
            }
        )

    async def handle_ice_candidate(self, data: Dict[str, Any]) -> None:
        """Handle ICE candidate from peer."""
        candidate = data.get("candidate")
        if not candidate:
            await self.send(text_data=json.dumps({"error": "Missing candidate"}))
            return

        # Store ICE candidate for message replay (limit to last 10 per call to avoid memory issues)
        if self.call_id not in WebRTCConsumer._call_messages:
            WebRTCConsumer._call_messages[self.call_id] = []
        
        # Get all non-ICE messages and ICE candidates
        non_ice_messages = [m for m in WebRTCConsumer._call_messages[self.call_id] if m.get('type') != 'ice-candidate']
        ice_candidates = [m for m in WebRTCConsumer._call_messages[self.call_id] if m.get('type') == 'ice-candidate']
        
        # Add new ICE candidate
        ice_candidates.append({
            "type": "ice-candidate",
            "candidate": candidate,
            "from_user_id": self.user.id,
            "from_username": self.user.username,
        })
        
        # Keep only last 10 ICE candidates per call
        if len(ice_candidates) > 10:
            ice_candidates = ice_candidates[-10:]
        
        # Update stored messages
        WebRTCConsumer._call_messages[self.call_id] = non_ice_messages + ice_candidates

        # Broadcast ICE candidate to other participants
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "webrtc_ice_candidate",
                "candidate": candidate,
                "from_user_id": self.user.id,
                "from_username": self.user.username,
            }
        )

    async def handle_call_ended(self) -> None:
        """Handle call end notification."""
        logger.info(
            "Call ended by user %s (call_id=%s)",
            self.user.username,
            self.call_id
        )
        
        # Clean up stored messages for this call
        if self.call_id in WebRTCConsumer._call_messages:
            del WebRTCConsumer._call_messages[self.call_id]
            logger.info("Cleaned up stored messages for call %s", self.call_id)
        
        # Broadcast call ended to all participants
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "webrtc_call_ended",
                "from_user_id": self.user.id,
                "from_username": self.user.username,
            }
        )

    async def webrtc_offer(self, event: Dict[str, Any]) -> None:
        """Send WebRTC offer to WebSocket."""
        # Don't send back to sender
        if event["from_user_id"] == self.user.id:
            return

        await self.send(text_data=json.dumps({
            "type": "offer",
            "offer": event["offer"],
            "from_user_id": event["from_user_id"],
            "from_username": event["from_username"],
        }))

    async def webrtc_answer(self, event: Dict[str, Any]) -> None:
        """Send WebRTC answer to WebSocket."""
        # Don't send back to sender
        if event["from_user_id"] == self.user.id:
            return

        await self.send(text_data=json.dumps({
            "type": "answer",
            "answer": event["answer"],
            "from_user_id": event["from_user_id"],
            "from_username": event["from_username"],
        }))

    async def webrtc_ice_candidate(self, event: Dict[str, Any]) -> None:
        """Send ICE candidate to WebSocket."""
        # Don't send back to sender
        if event["from_user_id"] == self.user.id:
            return

        await self.send(text_data=json.dumps({
            "type": "ice-candidate",
            "candidate": event["candidate"],
            "from_user_id": event["from_user_id"],
            "from_username": event["from_username"],
        }))

    async def webrtc_call_ended(self, event: Dict[str, Any]) -> None:
        """Send call ended notification to WebSocket."""
        await self.send(text_data=json.dumps({
            "type": "call-ended",
            "from_user_id": event["from_user_id"],
            "from_username": event["from_username"],
        }))

    @database_sync_to_async
    def check_call_access(self, user: User, call_id: str) -> bool:
        """Check if user has access to this call."""
        try:
            call = Call.objects.select_related('user', 'counsellor').get(id=call_id)
            
            # User who created the call can always access
            if call.user == user:
                return True
            
            # Counsellor can access if:
            # 1. They are assigned to the call (counsellor is set), OR
            # 2. They are a counsellor and the call is in ringing/scheduled status (not yet assigned)
            if hasattr(user, 'counsellorprofile'):
                if call.counsellor == user:
                    return True
                # Allow counsellors to connect to queued calls (ringing/scheduled status)
                if call.counsellor is None and call.status in [Call.STATUS_RINGING, Call.STATUS_SCHEDULED]:
                    return True
            
            return False
        except Call.DoesNotExist:
            logger.error("Call %s not found", call_id)
            return False
        except Exception as e:
            logger.error("Error checking call access: %s", e, exc_info=True)
            return False

