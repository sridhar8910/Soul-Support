"""
Views for video/audio call management and WebRTC TURN credentials.
"""
import logging
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.request import Request
from rest_framework.views import APIView

from ..models import Call
from ..serializers import CallSerializer, CallAcceptSerializer
from ..utils.turn_credentials import get_turn_configuration

logger = logging.getLogger(__name__)

# Constants for call billing (matching expected structure)
CALL_RATE_PER_MINUTE = 5
MIN_CALL_BALANCE = 100


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


class CallCreateView(APIView):
    """
    Create a call request.
    Uses WebRTC with TURN credentials instead of VideoSDK.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        # Check wallet balance
        from ..utils.billing import check_call_wallet_balance
        
        has_balance, message, current_balance = check_call_wallet_balance(request.user)
        if not has_balance:
            return Response(
                {
                    "error": message,
                    "wallet_minutes": current_balance,
                    "required_minimum": MIN_CALL_BALANCE,
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        call_type = request.data.get('call_type', Call.CALL_TYPE_VIDEO)
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
        
        # Get TURN credentials (using WebRTC instead of VideoSDK)
        try:
            turn_config = get_turn_configuration(user_id=request.user.id, use_cache=True)
            turn_config.pop("_from_cache", None)  # Remove internal flag
        except Exception as e:
            logger.error("Error generating TURN credentials: %s", e, exc_info=True)
            return Response(
                {"error": "Failed to generate TURN credentials"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        logger.info(
            "Call %s created by user %s (type: %s, wallet: %s minutes)",
            call.id, request.user.username, call_type, current_balance
        )
        
        return Response(
            CallSerializer(call, context={"request": request}).data | {
                "turn_config": turn_config,
                "websocket_url": f"ws://localhost:8000/ws/webrtc/{call.id}/",
            },
            status=status.HTTP_201_CREATED
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
            
            # Get TURN credentials (cached per user) - using WebRTC instead of VideoSDK
            try:
                turn_config = get_turn_configuration(user_id=request.user.id, use_cache=True)
                turn_config.pop("_from_cache", None)  # Remove internal flag
            except Exception as e:
                logger.error("Error generating TURN credentials: %s", e, exc_info=True)
                return Response(
                    {"error": "Failed to generate TURN credentials"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            serializer = CallSerializer(call)
            return Response({
                **serializer.data,
                "turn_config": turn_config,
            }, status=status.HTTP_200_OK)


class CallTokenView(APIView):
    """
    Get TURN credentials for a participant.
    Used when participant needs to join/rejoin the call.
    Returns WebRTC TURN configuration instead of VideoSDK token.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, call_id):
        try:
            call = Call.objects.select_related('user', 'counsellor').get(id=call_id)
        except Call.DoesNotExist:
            return Response(
                {"error": "Call not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Verify user is part of this call
        if request.user != call.user and request.user != call.counsellor:
            return Response(
                {"error": "Not authorized"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        if call.status != Call.STATUS_ACTIVE:
            return Response(
                {"error": "Call is not active"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Get TURN credentials (using WebRTC instead of VideoSDK)
            turn_config = get_turn_configuration(
                user_id=request.user.id,
                use_cache=True
            )
            turn_config.pop("_from_cache", None)  # Remove internal flag
        except Exception as e:
            logger.error("Failed to generate TURN credentials for call %s: %s", call_id, e)
            return Response(
                {"error": "Failed to generate TURN credentials"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response({
            "turn_config": turn_config,
            "call_type": call.call_type,  # Include call type for frontend to enable video
        })


class CallEndView(APIView):
    """
    End a call.
    Both participants can call this to mark call as ended.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, call_id):
        try:
            call = Call.objects.select_related('user', 'counsellor').get(id=call_id)
        except Call.DoesNotExist:
            return Response(
                {"error": "Call not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Verify user is part of this call
        if request.user != call.user and request.user != call.counsellor:
            return Response(
                {"error": "Not authorized"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        if call.status == Call.STATUS_ENDED:
            return Response(
                {"message": "Call already ended"},
                status=status.HTTP_200_OK
            )
        
        # Mark call as ended
        call.status = Call.STATUS_ENDED
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
        
        return Response({
            'status': 'ended',
            'call_id': call.id,
            'duration_seconds': call.duration_seconds,
            'duration_minutes': call.duration_seconds // 60 if call.duration_seconds else 0,
        }, status=status.HTTP_200_OK)


class CallHistoryView(APIView):
    """Get call history for users, separated into active calls and history."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Check if user is a counsellor
        is_counsellor = hasattr(request.user, 'counsellorprofile')
        
        if is_counsellor:
            # Counsellors see their assigned calls
            all_calls = Call.objects.filter(
                counsellor=request.user
            ).select_related('user', 'counsellor').order_by('-created_at', '-id')
        else:
            # Regular users see their own calls
            all_calls = Call.objects.filter(
                user=request.user
            ).select_related('user', 'counsellor').order_by('-created_at', '-id')
        
        # Separate into active and history
        active_calls = [
            call for call in all_calls 
            if call.status in [Call.STATUS_SCHEDULED, Call.STATUS_RINGING, Call.STATUS_ACTIVE]
        ]
        history_calls = [
            call for call in all_calls 
            if call.status in [Call.STATUS_ENDED, Call.STATUS_MISSED, Call.STATUS_CANCELLED]
        ]
        
        serializer = CallSerializer(active_calls, many=True, context={'request': request})
        active_data = serializer.data
        
        serializer = CallSerializer(history_calls, many=True, context={'request': request})
        history_data = serializer.data
        
        return Response({
            'active_calls': active_data,
            'history': history_data,
            'total_history_count': len(history_calls),
        })
