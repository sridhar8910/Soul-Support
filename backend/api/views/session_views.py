"""Session management views."""
# type: ignore
# pyright: reportAttributeAccessIssue=false
# pylint: disable=no-member,broad-except
import logging
from datetime import datetime

from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Chat, ChatMessage, UpcomingSession
from ..serializers import QuickSessionSerializer, UpcomingSessionSerializer

logger = logging.getLogger(__name__)


class UpcomingSessionListCreateView(generics.ListCreateAPIView):
    serializer_class = UpcomingSessionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Django models dynamically add .objects manager via metaclass
        return UpcomingSession.objects.filter(user=self.request.user).order_by("start_time", "id")  # type: ignore[attr-defined]  # pylint: disable=no-member

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class UpcomingSessionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UpcomingSessionSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_url_kwarg = "session_id"

    def get_queryset(self):
        # Django models dynamically add .objects manager via metaclass
        return UpcomingSession.objects.filter(user=self.request.user)  # type: ignore  # pylint: disable=no-member


class SessionStartView(APIView):
    """Endpoint to start a session. Accepts session_id or chat_id."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request, session_id: int) -> Response:
        try:
            session = None
            
            # Try to find session by ID first
            session = UpcomingSession.objects.filter(
                Q(id=session_id) & (Q(user=request.user) | Q(counsellor=request.user))
            ).first()
            
            # If not found by session_id, try to find by chat_id (session_id might be chat_id)
            if not session:
                try:
                    chat_id = int(session_id)
                    chat = Chat.objects.filter(
                        Q(id=chat_id) & (Q(user=request.user) | Q(counsellor=request.user))
                    ).first()
                    
                    if chat and chat.user and chat.counsellor:
                        # Find or create associated UpcomingSession by user and counsellor
                        session = UpcomingSession.objects.filter(
                            Q(user=chat.user) & 
                            Q(counsellor=chat.counsellor) &
                            Q(session_status__in=['scheduled', 'in_progress'])
                        ).order_by('-start_time', '-id').first()
                        
                        # If no session exists, create one
                        if not session:
                            session = UpcomingSession.objects.create(
                                user=chat.user,
                                counsellor=chat.counsellor,
                                title=f"Chat Session with {chat.user.username}",
                                session_type=UpcomingSession.SESSION_TYPE_ONE_ON_ONE,
                                start_time=timezone.now(),
                                counsellor_name=chat.counsellor.username,
                                session_status='scheduled',
                            )
                            logger.info(
                                "Created new session %s for chat %s (user=%s, counsellor=%s)",
                                session.id,
                                chat_id,
                                chat.user.username,
                                chat.counsellor.username
                            )
                        else:
                            logger.info(
                                "Found existing session %s for chat %s (user=%s, counsellor=%s)",
                                session.id,
                                chat_id,
                                chat.user.username,
                                chat.counsellor.username
                            )
                except (ValueError, TypeError):
                    # session_id is not a valid integer, continue to return error
                    pass
            
            if not session:
                return Response(
                    {"error": "Session not found or access denied"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # If already started, return current state
            if session.actual_start_time and session.session_status == 'in_progress':
                return Response(
                    {
                        "status": "already_started",
                        "session_id": session.id,
                        "chat_id": session_id if str(session_id) != str(session.id) else None,
                        "message": "Session already started",
                        "start_time": session.actual_start_time.isoformat(),
                        "duration_seconds": session.duration_seconds,
                    },
                    status=status.HTTP_200_OK
                )
            
            # Store actual start time and update status
            now = timezone.now()
            session.actual_start_time = now
            session.session_status = 'in_progress'
            session.is_confirmed = True
            
            # Add start note to notes field
            start_note = f"\n[Session started at {now.strftime('%Y-%m-%d %H:%M:%S')}]"
            if session.notes:
                session.notes += start_note
            else:
                session.notes = start_note.strip()
            
            session.save()
            
            logger.info("Session %s started by user %s at %s", session_id, request.user.username, now)
            
            return Response(
                {
                    "status": "started",
                    "session_id": session.id,
                    "chat_id": session_id if str(session_id) != str(session.id) else None,
                    "message": "Session started successfully",
                    "start_time": session.actual_start_time.isoformat(),
                    "duration_seconds": 0,
                },
                status=status.HTTP_200_OK
            )
        except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
            logger.error("Error starting session %s: %s", session_id, e, exc_info=True)
            return Response(
                {"error": f"Failed to start session: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class SessionEndView(APIView):
    """Endpoint to end a session. Accepts session_id or chat_id."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request, session_id: int) -> Response:
        logger.info("=" * 80)
        logger.info("SessionEndView: ===== REQUEST TO END SESSION =====")
        logger.info(
            "SessionEndView: Request to end session. session_id=%s (type=%s), user=%s (id=%s), is_counsellor=%s",
            session_id,
            type(session_id).__name__,
            request.user.username,
            request.user.id,
            hasattr(request.user, 'counsellorprofile')
        )
        
        try:
            session = None
            
            # Try to find session by ID first
            session = UpcomingSession.objects.filter(
                Q(id=session_id) & (Q(user=request.user) | Q(counsellor=request.user))
            ).first()
            
            if session:
                user_name = getattr(session.user, 'username', None) if session.user else None
                counsellor_name = getattr(session.counsellor, 'username', None) if session.counsellor else None
                logger.info(
                    "SessionEndView: Found session %s by session_id. status=%s, user=%s, counsellor=%s",
                    session.id,
                    session.session_status,
                    user_name,
                    counsellor_name
                )
            
            # If not found by session_id, try to find by chat_id (session_id might be chat_id)
            chat = None
            if not session:
                try:
                    chat_id = int(session_id)
                    chat = Chat.objects.filter(id=chat_id).first()
                    
                    if chat:
                        chat_user_name = getattr(chat.user, 'username', None) if chat.user else None
                        chat_counsellor_name = getattr(chat.counsellor, 'username', None) if chat.counsellor else None
                        logger.info(
                            "SessionEndView: Found chat %s by session_id. Request by user=%s "
                            "(chat.user=%s, counsellor=%s, status=%s)",
                            chat_id,
                            request.user.username,
                            chat_user_name,
                            chat_counsellor_name,
                            chat.status
                        )
                        
                        # Access control: only the chat user or assigned counsellor may end the chat
                        if not (chat.user_id == request.user.id or (chat.counsellor_id and chat.counsellor_id == request.user.id)):
                            logger.warning(
                                "SessionEndView: Access denied to end chat %s for user %s. "
                                "Chat owned by user_id=%s, counsellor_id=%s, request.user.id=%s",
                                chat.id,
                                request.user.username,
                                chat.user_id,
                                chat.counsellor_id,
                                request.user.id
                            )
                            return Response(
                                {"error": "Access denied to end this chat"},
                                status=status.HTTP_403_FORBIDDEN
                            )
                        
                        # If chat has a counsellor, try to find associated session
                        if chat.user and chat.counsellor:
                            session = UpcomingSession.objects.filter(
                                Q(user=chat.user) & 
                                Q(counsellor=chat.counsellor)
                            ).order_by('-start_time', '-id').first()
                            
                            if session:
                                logger.info(
                                    "SessionEndView: Found session %s for chat %s (user=%s, counsellor=%s, status=%s)",
                                    session.id,
                                    chat_id,
                                    chat.user.username,
                                    chat.counsellor.username,
                                    session.session_status
                                )
                            else:
                                logger.info(
                                    "SessionEndView: No session found for chat %s, will end chat directly if active/inactive",
                                    chat_id
                                )
                        else:
                            logger.info(
                                "SessionEndView: Chat %s has no counsellor assigned (status=%s)",
                                chat.id,
                                chat.status
                            )
                except (ValueError, TypeError) as e:
                    logger.debug(
                        "SessionEndView: session_id=%s is not a valid integer. Error: %s",
                        session_id,
                        e
                    )
            
            # If still no session found, but we have a chat, handle ending the chat directly
            if not session and chat:
                chat_user_name = getattr(chat.user, 'username', None) if chat.user else None
                chat_counsellor_name = getattr(chat.counsellor, 'username', None) if chat.counsellor else None
                logger.info(
                    "SessionEndView: No session exists for chat %s. Request by user=%s "
                    "(chat.user=%s, counsellor=%s, status=%s)",
                    chat.id,
                    request.user.username,
                    chat_user_name,
                    chat_counsellor_name,
                    chat.status
                )
                
                # If there's no counsellor assigned and chat is queued, return a clear message
                if chat.counsellor is None:
                    logger.info(
                        "SessionEndView: Chat %s has no counsellor assigned — cannot end session by chat id",
                        chat.id
                    )
                    return Response(
                        {"error": "Chat has no counselor assigned; cannot end session by chat id"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # If chat is active or inactive, proceed to end and bill
                if chat.status in [Chat.STATUS_ACTIVE, Chat.STATUS_INACTIVE]:
                    now = timezone.now()
                    
                    # End the chat
                    chat.status = Chat.STATUS_COMPLETED
                    if not chat.ended_at:
                        chat.ended_at = now
                    if not chat.started_at:
                        chat.started_at = now
                    
                    # Save (this should trigger billing in Chat.save())
                    chat.save()
                    
                    # Explicitly trigger billing to ensure it happens
                    from ..utils.billing import calculate_and_deduct_chat_billing
                    try:
                        chat.refresh_from_db()
                        if not chat.is_billed:
                            logger.info("Explicitly triggering billing for chat %s from SessionEndView", chat.id)
                            calculate_and_deduct_chat_billing(chat)
                    except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
                        logger.error("Error explicitly triggering billing for chat %s: %s", chat.id, e, exc_info=True)
                    
                    # Refresh to get billing info
                    chat.refresh_from_db()
                    
                    billing_info = None
                    if getattr(chat, "is_billed", False):
                        billing_info = {
                            "billed_amount": float(getattr(chat, "billed_amount", 0.0)),
                            "duration_minutes": getattr(chat, "duration_minutes", 0),
                        }
                    
                    # Calculate duration manually if needed
                    duration_seconds = 0
                    duration_minutes = 0
                    if chat.started_at and chat.ended_at:
                        delta = chat.ended_at - chat.started_at
                        from math import ceil
                        duration_seconds = int(delta.total_seconds())
                        duration_minutes = int(ceil(duration_seconds / 60))
                    
                    billed_amount = billing_info['billed_amount'] if billing_info else 0
                    logger.info(
                        "SessionEndView: Chat %s ended successfully (no session existed). "
                        "Duration: %s minutes, Billing: Rs %s",
                        chat.id,
                        duration_minutes,
                        billed_amount
                    )
                    
                    return Response(
                        {
                            "status": "ended",
                            "message": "Chat ended successfully (no session existed)",
                            "chat_id": chat.id,
                            "end_time": chat.ended_at.isoformat() if chat.ended_at else None,
                            "duration_seconds": duration_seconds,
                            "duration_minutes": duration_minutes,
                            "billing": billing_info,
                        },
                        status=status.HTTP_200_OK
                    )
                
                # Chat cannot be ended because it's not active/inactive
                logger.info(
                    "SessionEndView: Chat %s is in status %s, cannot end",
                    chat.id,
                    chat.status
                )
                return Response(
                    {"error": f"Chat {chat.id} is currently {chat.status} and cannot be ended"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Final check: if still no session found
            if not session:
                logger.warning("=" * 80)
                logger.warning("SessionEndView: ===== FINAL CHECK - NO SESSION FOUND =====")
                
                # Check if chat lookup failed because chat doesn't exist or access denied
                if chat is None:
                    try:
                        chat_id = int(session_id)
                        existing_chat = Chat.objects.filter(id=chat_id).first()
                        if existing_chat:
                            logger.warning(
                                "SessionEndView: Chat %s EXISTS but ACCESS DENIED. "
                                "Request by user=%s (id=%s), chat.user_id=%s, chat.counsellor_id=%s, chat.status=%s",
                                chat_id,
                                request.user.username,
                                request.user.id,
                                existing_chat.user_id,
                                existing_chat.counsellor_id,
                                existing_chat.status
                            )
                            return Response(
                                {
                                    "error": "Access denied to end this chat",
                                    "chat_id": chat_id,
                                    "details": f"Chat exists but user {request.user.username} does not have access"
                                },
                                status=status.HTTP_403_FORBIDDEN
                            )
                        else:
                            logger.warning(
                                "SessionEndView: Chat %s DOES NOT EXIST in database. Request by user=%s",
                                chat_id,
                                request.user.username
                            )
                    except (ValueError, TypeError) as parse_error:
                        logger.warning(
                            "SessionEndView: Cannot parse session_id=%s as integer. Error: %s",
                            session_id,
                            parse_error
                        )
                
                logger.warning("SessionEndView: ===== SUMMARY =====")
                logger.warning("SessionEndView: session_id provided: %s (type=%s)", session_id, type(session_id).__name__)
                logger.warning("SessionEndView: session found: %s", session is not None)
                logger.warning("SessionEndView: chat found: %s", chat is not None)
                if chat:
                    logger.warning(
                        "SessionEndView: chat.id=%s, chat.status=%s, chat.user_id=%s, chat.counsellor_id=%s",
                        chat.id,
                        chat.status,
                        chat.user_id,
                        chat.counsellor_id
                    )
                logger.warning(
                    "SessionEndView: requesting user=%s (id=%s), is_counsellor=%s",
                    request.user.username,
                    request.user.id,
                    hasattr(request.user, 'counsellorprofile')
                )
                logger.warning("=" * 80)
                
                return Response(
                    {
                        "error": "Session not found or access denied",
                        "details": f"No session or chat found with id={session_id} for user={request.user.username}",
                        "session_id": session_id,
                        "debug_info": {
                            "session_found": session is not None,
                            "chat_found": chat is not None,
                            "chat_id": chat.id if chat else None,
                            "chat_status": chat.status if chat else None,
                        }
                    },
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # If already ended, return current state
            if session.actual_end_time and session.session_status == 'completed':
                return Response(
                    {
                        "status": "already_ended",
                        "session_id": session.id,
                        "chat_id": session_id if str(session_id) != str(session.id) else None,
                        "message": "Session already ended",
                        "end_time": session.actual_end_time.isoformat(),
                        "duration_seconds": session.duration_seconds,
                    },
                    status=status.HTTP_200_OK
                )
            
            # Store actual end time and calculate duration
            now = timezone.now()
            session.actual_end_time = now
            session.session_status = 'completed'
            session.is_confirmed = False
            
            # Ensure start time exists (for duration calculation)
            if not session.actual_start_time:
                session.actual_start_time = now
            
            # Add end note to notes field
            end_note = f"\n[Session ended at {now.strftime('%Y-%m-%d %H:%M:%S')}]"
            if session.notes:
                session.notes += end_note
            else:
                session.notes = end_note.strip()
            
            session.save()
            
            # Process billing for associated chat if exists
            billing_info = None
            if session.user and session.counsellor:
                try:
                    chat = Chat.objects.filter(
                        user=session.user,
                        counsellor=session.counsellor,
                        status__in=[Chat.STATUS_ACTIVE, Chat.STATUS_INACTIVE]
                    ).order_by('-started_at', '-id').first()
                    
                    if chat and not chat.is_billed and chat.started_at:
                        logger.info(
                            "Processing billing for chat %s when session %s ended: "
                            "current_status=%s, started_at=%s, ended_at=%s",
                            chat.id,
                            session.id,
                            chat.status,
                            chat.started_at,
                            chat.ended_at
                        )
                        
                        # Ensure chat is ended if session is ending
                        if chat.status != Chat.STATUS_COMPLETED:
                            chat.status = Chat.STATUS_COMPLETED
                            if not chat.ended_at:
                                chat.ended_at = now
                            chat.save()
                        
                        # Get billing info after save
                        chat.refresh_from_db()
                        
                        # If billing wasn't triggered by save(), trigger it explicitly
                        if not chat.is_billed and chat.started_at and chat.ended_at:
                            logger.warning(
                                "Billing not triggered automatically for chat %s, triggering explicitly...",
                                chat.id
                            )
                            from ..utils.billing import calculate_and_deduct_chat_billing
                            try:
                                success = calculate_and_deduct_chat_billing(chat)
                                chat.refresh_from_db()
                                if success:
                                    logger.info("[OK] Explicit billing triggered successfully for chat %s", chat.id)
                                else:
                                    logger.error("[FAILED] Explicit billing failed for chat %s", chat.id)
                            except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
                                logger.error(
                                    "Error triggering explicit billing for chat %s: %s",
                                    chat.id,
                                    e,
                                    exc_info=True
                                )
                        
                        if chat.is_billed:
                            billing_info = {
                                "billed_amount": float(chat.billed_amount),
                                "duration_minutes": chat.duration_minutes,
                            }
                            logger.info(
                                "[OK] Billing processed for chat %s when session %s ended: Rs %s for %s minutes",
                                chat.id,
                                session.id,
                                chat.billed_amount,
                                chat.duration_minutes
                            )
                        else:
                            logger.warning(
                                "[WARNING] Billing not processed for chat %s after session %s ended: "
                                "is_billed=%s, duration_minutes=%s",
                                chat.id,
                                session.id,
                                chat.is_billed,
                                chat.duration_minutes
                            )
                except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
                    logger.error("Error processing billing when session %s ended: %s", session.id, e, exc_info=True)
            
            logger.info("Session %s ended by user %s at %s", session_id, request.user.username, now)
            
            response_data = {
                "status": "ended",
                "session_id": session.id,
                "chat_id": session_id if str(session_id) != str(session.id) else None,
                "message": "Session ended successfully",
                "end_time": session.actual_end_time.isoformat(),
                "duration_seconds": session.duration_seconds,
                "duration_minutes": session.duration_minutes,
            }
            
            if billing_info:
                response_data["billing"] = billing_info
            
            return Response(
                response_data,
                status=status.HTTP_200_OK
            )
        except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
            logger.error("=" * 80)
            logger.error("SessionEndView: ===== EXCEPTION IN END SESSION =====")
            logger.error(
                "SessionEndView: Error ending session. session_id=%s, user=%s (id=%s), error=%s, type=%s",
                session_id,
                request.user.username,
                request.user.id,
                str(e),
                type(e).__name__
            )
            logger.error("SessionEndView: Full traceback:", exc_info=True)
            logger.error("=" * 80)
            return Response(
                {
                    "error": f"Failed to end session: {str(e)}",
                    "session_id": session_id,
                    "details": f"An unexpected error occurred: {type(e).__name__}: {str(e)}"
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class SessionDurationView(APIView):
    """Get current session duration from backend."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request: Request, session_id: int) -> Response:
        try:
            session = UpcomingSession.objects.filter(
                Q(id=session_id) & (Q(user=request.user) | Q(counsellor=request.user))
            ).first()
            
            if not session:
                return Response(
                    {"error": "Session not found or access denied"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            duration_seconds = session.duration_seconds
            duration_minutes = session.duration_minutes
            
            return Response({
                "session_id": session_id,
                "status": session.session_status,
                "start_time": session.actual_start_time.isoformat() if session.actual_start_time else None,
                "end_time": session.actual_end_time.isoformat() if session.actual_end_time else None,
                "duration_seconds": duration_seconds,
                "duration_minutes": duration_minutes,
                "is_active": session.session_status == 'in_progress',
            }, status=status.HTTP_200_OK)
        except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
            logger.error("Error getting session duration %s: %s", session_id, e, exc_info=True)
            return Response(
                {"error": f"Failed to get session duration: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class SessionUpdateView(APIView):
    """Update session risk level, notes, manual flag."""
    permission_classes = [permissions.IsAuthenticated]
    
    def patch(self, request: Request, session_id: int) -> Response:
        try:
            session = UpcomingSession.objects.filter(
                Q(id=session_id) & (Q(user=request.user) | Q(counsellor=request.user))
            ).first()
            
            if not session:
                return Response(
                    {"error": "Session not found or access denied"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Update allowed fields
            allowed_fields = ['risk_level', 'manual_flag', 'notes']
            update_data = {k: v for k, v in request.data.items() if k in allowed_fields}
            
            if not update_data:
                return Response(
                    {"error": "No valid fields to update"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate risk_level
            if 'risk_level' in update_data:
                valid_risk_levels = ['none', 'low', 'medium', 'high', 'critical']
                if update_data['risk_level'] not in valid_risk_levels:
                    return Response(
                        {"error": f"Invalid risk_level. Must be one of: {valid_risk_levels}"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Validate manual_flag
            if 'manual_flag' in update_data:
                valid_flags = ['green', 'yellow', 'red']
                if update_data['manual_flag'] not in valid_flags:
                    return Response(
                        {"error": f"Invalid manual_flag. Must be one of: {valid_flags}"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Update session
            for field, value in update_data.items():
                setattr(session, field, value)
            
            session.save()
            
            logger.info("Session %s updated by user %s: %s", session_id, request.user.username, update_data)
            
            serializer = UpcomingSessionSerializer(session)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
            logger.error("Error updating session %s: %s", session_id, e, exc_info=True)
            return Response(
                {"error": f"Failed to update session: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class SessionSummaryView(APIView):
    """Get complete session summary with all data."""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request: Request, session_id: int) -> Response:
        try:
            session = UpcomingSession.objects.filter(
                Q(id=session_id) & (Q(user=request.user) | Q(counsellor=request.user))
            ).first()
            
            if not session:
                return Response(
                    {"error": "Session not found or access denied"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Get associated chat to count messages
            chat = None
            message_count = 0
            if session.user and session.counsellor:
                chat = Chat.objects.filter(
                    user=session.user,
                    counsellor=session.counsellor
                ).order_by('-created_at').first()
                
                if chat:
                    message_count = ChatMessage.objects.filter(chat=chat).count()
            
            return Response({
                "session_id": session.id,
                "client_name": session.counsellor_name or session.user.username if session.user else "Unknown",
                "session_type": session.session_type,
                "scheduled_time": session.start_time.isoformat() if session.start_time else None,
                "start_time": session.actual_start_time.isoformat() if session.actual_start_time else None,
                "end_time": session.actual_end_time.isoformat() if session.actual_end_time else None,
                "duration_seconds": session.duration_seconds,
                "duration_minutes": session.duration_minutes,
                "message_count": message_count,
                "risk_level": session.risk_level,
                "manual_flag": session.manual_flag,
                "notes": session.notes,
                "status": session.session_status,
                "is_confirmed": session.is_confirmed,
            }, status=status.HTTP_200_OK)
        except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
            logger.error("Error getting session summary %s: %s", session_id, e, exc_info=True)
            return Response(
                {"error": f"Failed to get session summary: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class QuickSessionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request) -> Response:
        serializer = QuickSessionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        session_date = serializer.validated_data["date"]
        session_time = serializer.validated_data["time"]
        start_naive = datetime.combine(session_date, session_time)
        start_at = timezone.make_aware(start_naive, timezone.get_current_timezone())

        session = UpcomingSession.objects.create(
            user=request.user,
            title=serializer.validated_data.get("title") or "Counselling Session",
            session_type="one_on_one",
            start_time=start_at,
            counsellor_name="Assigned Counsellor",
            notes=serializer.validated_data.get("notes", ""),
            is_confirmed=False,
        )
        return Response(
            {
                "status": "scheduled",
                "session": UpcomingSessionSerializer(session).data,
            },
            status=status.HTTP_201_CREATED,
        )

