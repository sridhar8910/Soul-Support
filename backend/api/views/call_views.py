"""
Views for video/audio call management and WebRTC TURN credentials.
"""
import logging
from django.db.models import Q
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.request import Request

from ..models import Call
from ..serializers import CallSerializer, CallAcceptSerializer
from ..utils.turn_credentials import get_turn_configuration

logger = logging.getLogger(__name__)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_turn_credentials_view(request: Request) -> Response:
    """
    Get TURN server credentials for WebRTC.
    Returns ICE servers configuration with STUN and TURN servers.
    Uses Redis caching to improve performance for repeated requests.
    """
    try:
        # Use cached credentials with user_id for better cache hit rate
        turn_config = get_turn_configuration(user_id=request.user.id, use_cache=True)
        logger.info("TURN credentials requested by user %s (cached: %s)", 
                   request.user.username, 
                   "yes" if turn_config.get("_from_cache") else "no")
        # Remove internal cache flag before sending to client
        turn_config.pop("_from_cache", None)
        return Response(turn_config, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error("Error generating TURN credentials: %s", e, exc_info=True)
        return Response(
            {"error": "Failed to generate TURN credentials"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_call_view(request: Request) -> Response:
    """
    Create a new call (video or voice).
    """
    try:
        call_type = request.data.get('call_type', 'video')
        counsellor_id = request.data.get('counsellor_id')
        
        if call_type not in [Call.CALL_TYPE_VIDEO, Call.CALL_TYPE_VOICE]:
            return Response(
                {"error": "Invalid call type. Must be 'video' or 'voice'"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Get counsellor if provided
        counsellor = None
        if counsellor_id:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            try:
                counsellor = User.objects.get(id=counsellor_id)
                if not hasattr(counsellor, 'counsellorprofile'):
                    return Response(
                        {"error": "User is not a counsellor"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            except User.DoesNotExist:
                return Response(
                    {"error": "Counsellor not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
        
        # Create call
        call = Call.objects.create(
            user=request.user,
            counsellor=counsellor,
            call_type=call_type,
            status=Call.STATUS_RINGING if counsellor else Call.STATUS_SCHEDULED,
        )
        
        # Get TURN credentials
        turn_config = get_turn_configuration()
        
        logger.info("Call created: id=%s, type=%s, user=%s", call.id, call_type, request.user.username)
        
        return Response({
            "call_id": call.id,
            "call_type": call.call_type,
            "status": call.status,
            "turn_config": turn_config,
            "websocket_url": f"ws://localhost:8000/ws/webrtc/{call.id}/",
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error("Error creating call: %s", e, exc_info=True)
        return Response(
            {"error": "Failed to create call"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


class QueuedCallsView(generics.ListAPIView):
    """List all queued calls (ringing without assigned counsellor)."""
    serializer_class = CallSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'counsellorprofile'):
            logger.warning(
                "QueuedCallsView: User %s (ID: %s) does not have counsellorprofile",
                self.request.user.username,
                self.request.user.id
            )
            return Call.objects.none()
        
        # Get all ringing calls without counsellor assigned or scheduled calls
        queryset = Call.objects.filter(
            status__in=[Call.STATUS_RINGING, Call.STATUS_SCHEDULED],
            counsellor__isnull=True
        ).select_related('user').order_by("created_at")
        
        count = queryset.count()
        logger.debug(
            "QueuedCallsView: Found %d queued calls for counsellor %s (ID: %s)",
            count,
            self.request.user.username,
            self.request.user.id
        )
        
        return queryset


class CallListView(generics.ListAPIView):
    """List calls for current user (user or counsellor)."""
    serializer_class = CallSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Check if user is a counsellor
        if hasattr(self.request.user, 'counsellorprofile'):
            # Counsellors see their assigned calls
            queryset = Call.objects.filter(counsellor=self.request.user)
        else:
            # Regular users see their own calls
            queryset = Call.objects.filter(user=self.request.user)
        
        return queryset.select_related('user', 'counsellor').order_by("-created_at")


class CallDetailView(generics.RetrieveUpdateAPIView):
    """Get or update call details."""
    serializer_class = CallSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if hasattr(self.request.user, 'counsellorprofile'):
            return Call.objects.filter(counsellor=self.request.user)
        return Call.objects.filter(user=self.request.user)


class CallAcceptView(generics.UpdateAPIView):
    """Accept a queued call (counsellors only)."""
    serializer_class = CallAcceptSerializer
    permission_classes = [IsAuthenticated]
    lookup_url_kwarg = 'call_id'

    def get_queryset(self):
        if not hasattr(self.request.user, 'counsellorprofile'):
            return Call.objects.none()
        
        # Allow accepting:
        # 1. Queued/ringing calls without counsellor (new accepts)
        # 2. Active calls already accepted by this counsellor (idempotent - allows retries)
        return Call.objects.filter(
            Q(
            status__in=[Call.STATUS_RINGING, Call.STATUS_SCHEDULED],
            counsellor__isnull=True
            ) | Q(
                status=Call.STATUS_ACTIVE,
                counsellor=self.request.user
            )
        )

    def update(self, request: Request, *args, **kwargs) -> Response:
        try:
            call = self.get_object()
        except Call.DoesNotExist:
            # Call might have been accepted by another counsellor or doesn't exist
            return Response(
                {"error": "Call not found or already accepted by another counsellor"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # If already accepted by this counsellor, return current state (idempotent)
        if call.status == Call.STATUS_ACTIVE and call.counsellor == request.user:
            logger.info(
                "Call %s already accepted by counsellor %s (idempotent request)",
                call.id,
                request.user.username
            )
        else:
            # Assign counsellor and update status
            call.counsellor = request.user
            call.status = Call.STATUS_ACTIVE
            from django.utils import timezone
            call.started_at = timezone.now()
            call.save()
        
        logger.info(
            "Call %s accepted by counsellor %s",
            call.id,
            request.user.username
        )
        
        logger.info(
            "Call %s accepted by counsellor %s",
            call.id,
            request.user.username
        )
        
        # Get TURN credentials (cached per user)
        turn_config = get_turn_configuration(user_id=request.user.id, use_cache=True)
        turn_config.pop("_from_cache", None)  # Remove internal flag
        
        serializer = CallSerializer(call)
        return Response({
            **serializer.data,
            "turn_config": turn_config,
        }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def end_call_view(request: Request, call_id: int) -> Response:
    """End a call."""
    try:
        if hasattr(request.user, 'counsellorprofile'):
            call = Call.objects.get(id=call_id, counsellor=request.user)
        else:
            call = Call.objects.get(id=call_id, user=request.user)
        
        if call.status == Call.STATUS_ENDED:
            return Response(
                {"error": "Call already ended"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        call.status = Call.STATUS_ENDED
        from django.utils import timezone
        if call.started_at:
            call.ended_at = timezone.now()
            delta = call.ended_at - call.started_at
            call.duration_seconds = int(delta.total_seconds())
        else:
            call.ended_at = timezone.now()
        call.save()
        
        logger.info(
            "Call %s ended by %s (duration: %d seconds)",
            call.id,
            request.user.username,
            call.duration_seconds
        )
        
        return Response(CallSerializer(call).data, status=status.HTTP_200_OK)
        
    except Call.DoesNotExist:
        return Response(
            {"error": "Call not found"},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error("Error ending call: %s", e, exc_info=True)
        return Response(
            {"error": "Failed to end call"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
