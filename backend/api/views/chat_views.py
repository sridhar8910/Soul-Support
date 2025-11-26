"""Chat-related views."""
import logging
from datetime import timedelta
from typing import Any

from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Chat, ChatMessage
from ..serializers import (
    ChatCreateSerializer,
    ChatMessageCreateSerializer,
    ChatMessageSerializer,
    ChatSerializer,
)

logger = logging.getLogger(__name__)


class ChatCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request) -> Response:
        # Check wallet balance before allowing chat creation
        from ..utils.billing import check_chat_wallet_balance
        
        has_balance, message, current_balance = check_chat_wallet_balance(request.user)
        if not has_balance:
            return Response(
                {
                    "error": message,
                    "wallet_minutes": current_balance,
                    "required_minimum": 1,  # Minimum 1 rupee (1 minute) to start chat
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        serializer = ChatCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        chat = Chat.objects.create(
            user=request.user,
            status="queued",
            initial_message=serializer.validated_data.get("initial_message", ""),
        )

        logger.info(
            f"Chat {chat.id} created by user {request.user.username} "
            f"(wallet balance: {current_balance} minutes)"
        )

        return Response(
            ChatSerializer(chat).data,
            status=status.HTTP_201_CREATED,
        )


class ChatListView(generics.ListAPIView):
    serializer_class = ChatSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Check if user is a counselor
        is_counselor = hasattr(self.request.user, 'counsellorprofile')
        
        logger.debug(
            f"ChatListView: User {self.request.user.username} (ID: {self.request.user.id}) requesting chats. "
            f"Is counselor: {is_counselor}"
        )
        
        if is_counselor:
            # For counselors: return ALL chats where they are assigned as counselor
            counselor_id = self.request.user.id
            
            queryset = Chat.objects.filter(
                counsellor_id=counselor_id
            ).select_related('user', 'counsellor').prefetch_related('messages').order_by("-created_at", "-updated_at")
            
            count = queryset.count()
            logger.debug(
                f"ChatListView: Counselor {self.request.user.username} (ID: {counselor_id}) requesting chats. "
                f"Query: counsellor_id={counselor_id}, Found {count} chats"
            )
            
            if count > 0:
                logger.debug(f"ChatListView: Showing {min(count, 10)} chats to counselor:")
                for chat in queryset[:10]:
                    msg_count = chat.messages.count() if hasattr(chat, 'messages') else ChatMessage.objects.filter(chat=chat).count()
                    logger.debug(
                        f"  - Chat ID: {chat.id}, User: {chat.user.username} (ID: {chat.user.id}), "
                        f"Status: {chat.status}, Counsellor ID: {chat.counsellor_id}, "
                        f"Messages: {msg_count}, Created: {chat.created_at}"
                    )
            else:
                all_chats = Chat.objects.select_related('counsellor').all()[:10]
                total_chats = Chat.objects.count()
                chats_with_counselor = Chat.objects.exclude(counsellor__isnull=True).count()
                
                logger.warning(
                    f"ChatListView: No chats found for counselor ID {counselor_id}. "
                    f"Total chats in DB: {total_chats}, Chats with counselor: {chats_with_counselor}"
                )
                
                for chat in all_chats:
                    logger.debug(
                        f"  - Chat ID: {chat.id}, User: {chat.user.username}, Status: {chat.status}, "
                        f"Counsellor ID: {chat.counsellor_id}, "
                        f"Counsellor Username: {chat.counsellor.username if chat.counsellor else None}, "
                        f"Created: {chat.created_at}"
                    )
            
            return queryset
        else:
            # For regular users: return only their own chats
            user_id = self.request.user.id
            queryset = Chat.objects.filter(user_id=user_id).select_related('user', 'counsellor').order_by("-created_at", "-updated_at")
            count = queryset.count()
            logger.debug(
                f"ChatListView: User {self.request.user.username} (ID: {user_id}) requesting chats. "
                f"Query: user_id={user_id}, Found {count} chats"
            )
            return queryset


class QueuedChatsView(generics.ListAPIView):
    serializer_class = ChatSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'counsellorprofile'):
            logger.warning(f"QueuedChatsView: User {self.request.user.username} (ID: {self.request.user.id}) does not have counsellorprofile")
            return Chat.objects.none()
        
        # Get all queued chats without counselor assigned
        queryset = Chat.objects.filter(
            status="queued",
            counsellor__isnull=True
        ).select_related('user').order_by("created_at")
        
        count = queryset.count()
        logger.debug(f"QueuedChatsView: Found {count} queued chats for counselor {self.request.user.username} (ID: {self.request.user.id})")
        
        if count > 0:
            for chat in queryset[:5]:
                logger.debug(f"  - Chat ID: {chat.id}, User: {chat.user.username}, Status: {chat.status}, Counsellor: {chat.counsellor}, Created: {chat.created_at}")
        else:
            all_chats = Chat.objects.all()[:10]
            logger.debug(f"QueuedChatsView: No queued chats found. Total chats in DB: {Chat.objects.count()}")
            for chat in all_chats:
                logger.debug(f"  - Chat ID: {chat.id}, User: {chat.user.username}, Status: {chat.status}, Counsellor: {chat.counsellor_id}, Created: {chat.created_at}")
        
        return queryset


class ChatAcceptView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request: Request, chat_id: int) -> Response:
        if not hasattr(request.user, 'counsellorprofile'):
            logger.warning(
                f"ChatAcceptView: User {request.user.username} (ID: {request.user.id}) "
                f"does not have counsellorprofile"
            )
            return Response(
                {"error": "Only counsellors can accept chats"},
                status=status.HTTP_403_FORBIDDEN
            )

        try:
            chat = Chat.objects.select_related('user', 'counsellor').get(id=chat_id, status="queued")
        except Chat.DoesNotExist:
            logger.warning(
                f"ChatAcceptView: Chat {chat_id} not found or not queued. "
                f"User: {request.user.username} (ID: {request.user.id})"
            )
            return Response(
                {"error": "Chat not found or not available"},
                status=status.HTTP_404_NOT_FOUND
            )

        # Assign counselor to chat and activate it
        logger.info(
            f"ChatAcceptView: Counselor {request.user.username} (ID: {request.user.id}) "
            f"accepting chat {chat_id} from user {chat.user.username} (ID: {chat.user.id})"
        )

        chat.counsellor = request.user
        chat.status = "active"
        chat.started_at = timezone.now()
        chat.save(update_fields=['counsellor', 'status', 'started_at', 'updated_at'])

        # Verify the save
        updated_chat = Chat.objects.get(id=chat_id)
        logger.info(
            f"ChatAcceptView: Chat {chat_id} updated successfully. "
            f"Counsellor ID: {updated_chat.counsellor_id}, Status: {updated_chat.status}"
        )

        return Response(ChatSerializer(updated_chat).data)


class ChatMessageListView(generics.ListCreateAPIView):
    serializer_class = ChatMessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        chat_id = self.kwargs.get('chat_id')
        request_user_id = self.request.user.id
        request_username = self.request.user.username
        
        logger.debug(
            f"ChatMessageListView GET: chat_id={chat_id}, "
            f"request_user={request_username} (id={request_user_id})"
        )
        
        try:
            # Get chat with all related data
            chat = Chat.objects.select_related('user', 'counsellor').prefetch_related('messages').get(id=chat_id)
            
            # Log chat details
            logger.debug(
                f"ChatMessageListView: Chat found - ID: {chat_id}, "
                f"User: {chat.user.username} (ID: {chat.user.id}), "
                f"Counsellor: {chat.counsellor.username if chat.counsellor else None} (ID: {chat.counsellor_id}), "
                f"Status: {chat.status}"
            )
            
            # Check if user has access to this chat
            is_chat_user = chat.user_id == request_user_id
            is_chat_counsellor = chat.counsellor_id is not None and chat.counsellor_id == request_user_id
            
            logger.debug(
                f"ChatMessageListView: Access check - is_chat_user={is_chat_user}, "
                f"is_chat_counsellor={is_chat_counsellor}, "
                f"chat_user_id={chat.user_id}, chat_counsellor_id={chat.counsellor_id}, "
                f"request_user_id={request_user_id}"
            )
            
            if not is_chat_user and not is_chat_counsellor:
                logger.warning(
                    f"ChatMessageListView: Access DENIED for user {request_username} (ID: {request_user_id}) "
                    f"to chat {chat_id}. User is not the chat user or assigned counselor."
                )
                return ChatMessage.objects.none()
            
            # IMPORTANT: Only user interaction should activate/reactivate chats
            # When user opens the chat, update last_user_activity and check for inactivity
            if is_chat_user:
                now = timezone.now()
                chat.last_user_activity = now
                
                # Check if chat is active but user has been inactive for > 1 hour
                # Auto-disconnect inactive chats
                if chat.status == 'active' and chat.last_user_activity:
                    one_hour_ago = now - timedelta(hours=1)
                    if chat.last_user_activity < one_hour_ago:
                        # User was inactive for > 1 hour, auto-disconnect
                        logger.info(
                            f"ChatMessageListView GET: Auto-disconnecting inactive chat {chat_id}, "
                            f"last_user_activity={chat.last_user_activity}, "
                            f"hours_inactive={(now - chat.last_user_activity).total_seconds() / 3600:.2f}"
                        )
                        chat.status = 'completed'
                        if not chat.ended_at:
                            chat.ended_at = now
                        # Ensure started_at is set if not already set (for billing)
                        if not chat.started_at:
                            chat.started_at = chat.created_at or now
                        chat.save(update_fields=['status', 'ended_at', 'started_at', 'last_user_activity', 'updated_at'])
                        logger.info(f"Chat {chat_id} auto-disconnected due to 1 hour inactivity")
                    else:
                        # User is active, just update last_user_activity
                        chat.save(update_fields=['last_user_activity', 'updated_at'])
                elif chat.status in ['completed', 'cancelled']:
                    # User is opening a completed/cancelled chat - allow reopening
                    chat.save(update_fields=['last_user_activity', 'updated_at'])
                else:
                    # Chat is queued or active, just update last_user_activity
                    chat.save(update_fields=['last_user_activity', 'updated_at'])
            
            # User has access - return ALL messages for this chat from database
            messages = ChatMessage.objects.filter(
                chat_id=chat_id
            ).select_related('sender', 'chat').order_by("created_at", "id")
            
            msg_count = messages.count()
            
            logger.debug(
                f"ChatMessageListView: Access GRANTED. Returning {msg_count} messages for chat {chat_id}. "
                f"User {request_username} has access."
            )
            
            # Log first few messages for debugging
            if msg_count > 0:
                logger.debug(f"ChatMessageListView: First {min(msg_count, 5)} messages:")
                for msg in messages[:5]:
                    logger.debug(
                        f"  - Message ID: {msg.id}, Sender: {msg.sender.username} (ID: {msg.sender_id}), "
                        f"Text: {msg.text[:50]}..., Created: {msg.created_at}"
                    )
            else:
                logger.debug(
                    f"ChatMessageListView: No messages found in database for chat {chat_id}. "
                    f"Chat exists but has no messages."
                )
            
            return messages
        except Chat.DoesNotExist:
            logger.error(
                f"ChatMessageListView: Chat {chat_id} NOT FOUND in database. "
                f"User: {request_username} (ID: {request_user_id})"
            )
            return ChatMessage.objects.none()
        except Exception as e:
            logger.error(
                f"ChatMessageListView: ERROR getting messages for chat {chat_id}: {e}", 
                exc_info=True
            )
            return ChatMessage.objects.none()

    def post(self, request: Request, chat_id: int) -> Response:
        try:
            chat = Chat.objects.select_related('user', 'counsellor').get(id=chat_id)
        except Chat.DoesNotExist:
            logger.error(f"ChatMessageListView POST: Chat {chat_id} not found")
            return Response(
                {"error": "Chat not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        # Log access check
        logger.info(
            f"ChatMessageListView POST: chat_id={chat_id}, "
            f"request_user={request.user.username} (id={request.user.id}), "
            f"chat_user={chat.user.username} (id={chat.user.id}), "
            f"chat_counsellor={chat.counsellor.username if chat.counsellor else None} "
            f"(id={chat.counsellor_id if chat.counsellor else None}), "
            f"chat_status={chat.status}"
        )

        # Check if user has access to this chat
        is_chat_user = chat.user == request.user
        is_chat_counsellor = chat.counsellor is not None and chat.counsellor == request.user
        
        if not is_chat_user and not is_chat_counsellor:
            logger.warning(
                f"ChatMessageListView POST: Access denied for user {request.user.username} (ID: {request.user.id}) "
                f"to chat {chat_id}"
            )
            return Response(
                {"error": "You don't have access to this chat"},
                status=status.HTTP_403_FORBIDDEN
            )

        # IMPORTANT: Only user can reactivate chats, not counselor
        # If user is sending a message to a completed/cancelled chat, reopen it
        if is_chat_user and chat.status in ['completed', 'cancelled']:
            # User wants to continue the conversation - always allow reopening
            logger.info(
                f"ChatMessageListView POST: User {request.user.username} reopening chat {chat_id} "
                f"(old_status={chat.status}, ended_at={chat.ended_at})"
            )
            chat.reopen()
            # Update last_user_activity
            chat.last_user_activity = timezone.now()
            chat.save(update_fields=['status', 'ended_at', 'last_user_activity', 'updated_at'])
            
            # Notify counselor that user wants to continue chat
            # This will be handled via WebSocket in the consumer
        
        # Check if chat is active (after potential reopen)
        if chat.status != "active":
            logger.warning(
                f"ChatMessageListView POST: Chat {chat_id} is not active (status: {chat.status})"
            )
            return Response(
                {"error": "Chat is not active"},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = ChatMessageCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        text = serializer.validated_data["text"]
        logger.info(f"API SAVING MESSAGE: chat_id={chat_id}, sender={request.user.username} (id={request.user.id}), text_length={len(text)}")
        
        try:
            message = ChatMessage.objects.create(
                chat=chat,
                sender=request.user,
                text=text
            )
            
            # Verify it was saved
            saved_message = ChatMessage.objects.get(id=message.id)
            logger.info(f"API MESSAGE SAVED SUCCESSFULLY: message_id={saved_message.id}, chat_id={saved_message.chat_id}, created_at={saved_message.created_at}")
            
            # Count total messages for this chat
            total_messages = ChatMessage.objects.filter(chat=chat).count()
            logger.info(f"Total messages in chat {chat_id}: {total_messages}")
            
        except Exception as e:
            logger.error(f"ERROR SAVING MESSAGE VIA API: chat_id={chat_id}, error={e}", exc_info=True)
            return Response(
                {"error": f"Failed to save message: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        return Response(
            ChatMessageSerializer(message).data,
            status=status.HTTP_201_CREATED
        )

