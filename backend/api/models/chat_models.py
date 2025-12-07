"""
Django models for the mental health counseling platform.

All models are designed to ensure data persistence, proper relationships,
and automatic timestamp management. Chat and message data is saved to
the database for history and counselor access.

Note: Django ORM dynamically adds attributes (.objects, .id, .user_id, etc.)
Type checker warnings about these are false positives.
"""
# type: ignore
# pyright: reportAttributeAccessIssue=false
# pylint: disable=no-member,broad-except
from django.contrib.auth.models import User
from django.db import models
from django.db.models import Q
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)

class Chat(models.Model):
    """
    Chat model for conversations between users and counselors.
    
    All chat data is saved to database for persistence and history.
    Counselors can see all their assigned chats through the counsellor ForeignKey.
    
    Status Flow:
    - queued: User created chat, waiting for counselor
    - active: Counselor accepted or user sent message
    - inactive: User hasn't sent message in 5+ minutes (auto-set)
    - completed: Chat ended normally
    - cancelled: Chat was cancelled
    
    Timestamps:
    - created_at: When chat was created
    - started_at: When chat became active (auto-set)
    - ended_at: When chat ended (auto-set)
    - updated_at: Last update (auto-managed)
    """
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._billing_processing: bool = False  # Flag to prevent recursive billing
    STATUS_QUEUED = "queued"
    STATUS_ACTIVE = "active"
    STATUS_INACTIVE = "inactive"  # User inactive for 5+ minutes
    STATUS_COMPLETED = "completed"
    STATUS_CANCELLED = "cancelled"
    
    STATUS_CHOICES = [
        (STATUS_QUEUED, "Queued"),
        (STATUS_ACTIVE, "Active"),
        (STATUS_INACTIVE, "Inactive"),  # User hasn't sent message in 5 minutes
        (STATUS_COMPLETED, "Completed"),
        (STATUS_CANCELLED, "Cancelled"),
    ]

    # Relationships
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="chats",
        help_text="User who initiated this chat"
    )
    
    counsellor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_chats",
        limit_choices_to={"counsellorprofile__isnull": False},
        help_text="Counselor assigned to this chat (null for queued chats)"
    )
    
    # Chat data
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_QUEUED,
        db_index=True,
        help_text="Current status of the chat"
    )
    
    initial_message = models.TextField(
        blank=True,
        help_text="Initial message from user when creating the chat"
    )
    
    # Timestamps (all auto-managed)
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="When the chat was created"
    )
    started_at = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        help_text="When the chat became active (counselor accepted or user sent message)"
    )
    ended_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the chat ended (completed or cancelled)"
    )
    last_user_activity = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        help_text="When the user last interacted with this chat (sending message or opening chat)"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        db_index=True,
        help_text="Last update timestamp"
    )
    
    # Billing fields (time-based: 2 rupees per minute)
    billed_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Total amount billed for this chat (in rupees)"
    )
    duration_minutes = models.PositiveIntegerField(
        default=0,
        help_text="Total active chat duration in minutes (for billing calculation)"
    )
    is_billed = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Whether billing has been processed and wallet deducted"
    )
    billing_processed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When billing was processed"
    )

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            # User's chats (ordered by creation date)
            models.Index(fields=["user", "-created_at"]),
            # Counselor's chats (ordered by creation date)
            models.Index(fields=["counsellor", "-created_at"]),
            # Status queries
            models.Index(fields=["status", "-created_at"]),
            # Counselor status queries (for dashboard)
            models.Index(fields=["counsellor", "status"]),
            # Queued chats (counsellor is null, status is queued)
            models.Index(fields=["status", "counsellor"], name="chat_queued_idx"),
        ]
        verbose_name = "Chat"
        verbose_name_plural = "Chats"

    def __str__(self) -> str:
        """String representation of the chat."""
        counsellor_name = getattr(self.counsellor, 'username', 'Unassigned') if self.counsellor else "Unassigned"
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"Chat {self.id}: {username} -> {counsellor_name} ({self.status})"  # type: ignore[attr-defined]
    
    def save(self, *args, **kwargs):
        """
        Ensure chat is always saved with proper timestamps and status tracking.
        This method ensures data persistence and proper state management.
        """
        # Store previous status to detect status changes
        if self.pk:
            try:
                old_instance = self.__class__.objects.get(pk=self.pk)  # type: ignore[attr-defined]
                old_status = old_instance.status
            except self.__class__.DoesNotExist:  # type: ignore[attr-defined]
                old_status = None
        else:
            old_status = None
        
        # Track which fields we modify so we can include them in update_fields if needed
        fields_to_update = set()
        
        # Auto-set started_at when chat becomes active
        if self.status == self.STATUS_ACTIVE and not self.started_at:
            self.started_at = timezone.now()
            fields_to_update.add('started_at')
            logger.info("Chat %s started at %s", self.id, self.started_at)  # type: ignore[attr-defined]

        # Auto-set ended_at when chat is inactive, completed, or cancelled
        ending_chat = False
        status_changed_to_ending = False
        
        # Detect if status changed to an ending status
        if self.status in [self.STATUS_INACTIVE, self.STATUS_COMPLETED, self.STATUS_CANCELLED]:
            if old_status != self.status:
                status_changed_to_ending = True
                logger.info("Chat %s status changed to %s (was %s)", self.id, self.status, old_status)  # type: ignore[attr-defined]
            
            if not self.ended_at:
                ending_chat = True
                # For inactive chats, set ended_at to 5 minutes after last_user_activity if available
                if self.status == self.STATUS_INACTIVE and self.last_user_activity:
                    from datetime import timedelta
                    self.ended_at = self.last_user_activity + timedelta(minutes=5)
                else:
                    # For completed/cancelled or no last_user_activity, set ended_at to now
                    self.ended_at = timezone.now()
                fields_to_update.add('ended_at')
                logger.info("Chat %s ended at %s with status %s", self.id, self.ended_at, self.status)  # type: ignore[attr-defined]
            elif status_changed_to_ending:
                # Status changed but ended_at already set - still need to process billing
                ending_chat = True
                logger.info("Chat %s status changed to %s, ended_at already set: %s", self.id, self.status, self.ended_at)  # type: ignore[attr-defined]

        # updated_at is auto-managed by Django (auto_now=True) so no need to set it here,
        # but keep the safe fallback if needed:
        if not getattr(self, "updated_at", None):
            self.updated_at = timezone.now()

        # If update_fields is specified, ensure we include any fields we modified
        if 'update_fields' in kwargs and kwargs['update_fields'] is not None:
            # Convert to list if it's a tuple
            update_fields_list = list(kwargs['update_fields']) if isinstance(kwargs['update_fields'], (list, tuple)) else [kwargs['update_fields']]
            # Add any fields we modified that aren't already in the list
            for field in fields_to_update:
                if field not in update_fields_list:
                    update_fields_list.append(field)
            kwargs['update_fields'] = update_fields_list

        # Persist
        super().save(*args, **kwargs)
        
        # Calculate and process billing when chat ends (after save to ensure we have ended_at)
        # Trigger billing if:
        # 1. Chat is ending AND not already billed AND has started_at AND has ended_at
        # 2. OR status changed to ending status (even if ended_at was already set)
        should_process_billing = False
        if ending_chat or status_changed_to_ending:
            should_process_billing = (
                not getattr(self, '_billing_processing', False) and
                not self.is_billed and
                self.started_at is not None and
                self.ended_at is not None
            )
        
        if should_process_billing:
            username = getattr(self.user, 'username', None) if self.user else None
            logger.info(
                "Chat %s ended - triggering billing: status=%s, started_at=%s, ended_at=%s, "
                "user=%s, is_billed=%s, ending_chat=%s, status_changed=%s",
                self.id,  # type: ignore[attr-defined]
                self.status,
                self.started_at,
                self.ended_at,
                username,
                self.is_billed,
                ending_chat,
                status_changed_to_ending
            )
            # Mark to prevent recursion
            self._billing_processing = True
            # Import here to avoid circular imports
            from ..utils.billing import calculate_and_deduct_chat_billing
            try:
                # Refresh from DB to get latest state (including any fields that were just saved)
                self.refresh_from_db()
                
                # Double-check that started_at is set (it should have been saved above)
                if not self.started_at:
                    logger.warning(
                        "[WARNING] Chat %s ended but started_at is None after refresh. "
                        "This may prevent billing. Old status was %s, new status is %s.",
                        self.id,  # type: ignore[attr-defined]
                        old_status,
                        self.status
                    )
                
                # Calculate billing and deduct from wallet
                success = calculate_and_deduct_chat_billing(self)
                if success:
                    logger.info("[OK] Billing processed successfully for chat %s", self.id)  # type: ignore[attr-defined]
                else:
                    logger.error(
                        "[FAILED] Billing processing failed for chat %s. "
                        "This may be due to insufficient wallet balance or an error during deduction.",
                        self.id  # type: ignore[attr-defined]
                    )
            except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
                logger.error("[ERROR] Error processing billing for chat %s: %s", self.id, e, exc_info=True)  # type: ignore[attr-defined]
            finally:
                # Clear flag
                self._billing_processing = False
        elif (ending_chat or status_changed_to_ending) and self.is_billed:
            logger.debug("Chat %s already billed, skipping billing calculation", self.id)  # type: ignore[attr-defined]
        elif ending_chat or status_changed_to_ending:
            logger.debug(
                "Chat %s ended but billing skipped: is_billed=%s, started_at=%s, ended_at=%s",
                self.id,  # type: ignore[attr-defined]
                self.is_billed,
                self.started_at,
                self.ended_at
            )

        logger.debug(
            "Chat %s saved: user=%s, counsellor=%s, status=%s, created_at=%s, updated_at=%s",
            self.id,  # type: ignore[attr-defined]
            self.user_id,  # type: ignore[attr-defined]
            self.counsellor_id,  # type: ignore[attr-defined]
            self.status,
            self.created_at,
            self.updated_at
        )
    
    @property
    def message_count(self) -> int:
        """Get the number of messages in this chat."""
        return self.messages.count()  # type: ignore[attr-defined]
    
    @property
    def current_duration_minutes(self) -> int:
        """Calculate current duration in minutes (for active chats)."""
        if not self.started_at:
            return 0
        
        # Use ended_at if available, otherwise current time
        end_time = self.ended_at if self.ended_at else timezone.now()
        
        if end_time <= self.started_at:
            return 0
        
        from math import ceil
        duration_seconds = (end_time - self.started_at).total_seconds()
        return int(ceil(duration_seconds / 60))
    
    @property
    def current_estimated_cost(self) -> float:
        """Calculate estimated cost for active chat or final cost for completed chat."""
        duration = self.duration_minutes if self.is_billed else self.current_duration_minutes
        return float(duration * 2.00)  # 2 rupees per minute
    
    @property
    def is_active(self) -> bool:
        """Check if chat is currently active."""
        return self.status == self.STATUS_ACTIVE
    
    @property
    def is_queued(self) -> bool:
        """Check if chat is queued (waiting for counselor)."""
        return self.status == self.STATUS_QUEUED and self.counsellor is None
    
    @property
    def is_inactive(self) -> bool:
        """Check if chat is inactive (user hasn't sent message in 5+ minutes)."""
        return self.status == self.STATUS_INACTIVE
    
    @property
    def is_completed(self) -> bool:
        """Check if chat is completed."""
        return self.status == self.STATUS_COMPLETED
    
    @property
    def is_cancelled(self) -> bool:
        """Check if chat is cancelled."""
        return self.status == self.STATUS_CANCELLED
    
    def assign_counsellor(self, counsellor: User) -> None:  # type: ignore[type-arg]
        """
        Assign a counselor to this chat and activate it.
        This ensures the chat is properly saved to database.
        
        Args:
            counsellor: User instance with CounsellorProfile
            
        Raises:
            ValueError: If user is not a counselor
        """
        if not hasattr(counsellor, 'counsellorprofile'):
            raise ValueError(f"User {counsellor.username} is not a counselor")
        
        self.counsellor = counsellor
        self.status = self.STATUS_ACTIVE
        if not self.started_at:
            self.started_at = timezone.now()
        
        # Save to database
        self.save(update_fields=['counsellor', 'status', 'started_at', 'updated_at'])
        
        counsellor_username = getattr(counsellor, 'username', 'Unknown')
        counsellor_id = getattr(counsellor, 'id', 'Unknown')
        logger.info(
            "Chat %s assigned to counselor %s (ID: %s)",
            self.id,  # type: ignore[attr-defined]
            counsellor_username,
            counsellor_id
        )
    
    def complete(self) -> None:
        """Mark chat as completed and set ended_at timestamp."""
        self.status = self.STATUS_COMPLETED
        if not self.ended_at:
            self.ended_at = timezone.now()
        # Ensure started_at is set if not already set (for billing)
        if not self.started_at:
            self.started_at = self.created_at or timezone.now()
        
        self.save(update_fields=['status', 'ended_at', 'started_at', 'updated_at'])
        
        logger.info("Chat %s completed at %s", self.id, self.ended_at)  # type: ignore[attr-defined]
    
    def cancel(self) -> None:
        """Cancel the chat and set ended_at timestamp."""
        self.status = self.STATUS_CANCELLED
        if not self.ended_at:
            self.ended_at = timezone.now()
        # Ensure started_at is set if not already set (for billing)
        if not self.started_at:
            self.started_at = self.created_at or timezone.now()
        
        self.save(update_fields=['status', 'ended_at', 'started_at', 'updated_at'])
        
        logger.info("Chat %s cancelled at %s", self.id, self.ended_at)  # type: ignore[attr-defined]
    
    def reopen(self) -> None:
        """
        Reopen a completed, inactive, or cancelled chat to allow follow-up conversations.
        Clears ended_at timestamp and sets status to active.
        Updates last_user_activity to current time.
        """
        if self.status not in [self.STATUS_COMPLETED, self.STATUS_INACTIVE, self.STATUS_CANCELLED]:
            logger.warning("Chat %s is already active (status: %s), no need to reopen", self.id, self.status)  # type: ignore[attr-defined]
            return
        
        old_status = self.status
        self.status = self.STATUS_ACTIVE
        self.ended_at = None  # Clear ended_at since chat is active again
        self.last_user_activity = timezone.now()  # Update user activity
        # Ensure started_at is set when reopening (for billing)
        if not self.started_at:
            self.started_at = timezone.now()
        
        self.save(update_fields=['status', 'ended_at', 'started_at', 'last_user_activity', 'updated_at'])
        
        logger.info("Chat %s reopened from %s to active status", self.id, old_status)  # type: ignore[attr-defined]
    
    def mark_inactive(self) -> None:
        """
        Mark chat as inactive when user hasn't sent a message in 5+ minutes.
        Sets ended_at timestamp to when inactivity occurred.
        """
        if self.status != self.STATUS_ACTIVE:
            logger.warning("Chat %s cannot be marked inactive (current status: %s)", self.id, self.status)  # type: ignore[attr-defined]
            return
        
        self.status = self.STATUS_INACTIVE
        if not self.ended_at and self.last_user_activity:
            # Set ended_at to 5 minutes after last user activity
            from datetime import timedelta
            self.ended_at = self.last_user_activity + timedelta(minutes=5)
        
        self.save(update_fields=['status', 'ended_at', 'updated_at'])
        logger.info("Chat %s marked as inactive (user inactive for 5+ minutes)", self.id)  # type: ignore[attr-defined]


class ChatMessage(models.Model):
    """
    Individual message within a chat conversation.
    
    All messages are saved to database for persistence and history.
    Messages support deduplication via client_message_id.
    
    Fields:
    - chat: ForeignKey to Chat (CASCADE delete)
    - sender: ForeignKey to User (CASCADE delete)
    - text: Message content
    - client_message_id: UUID from client for deduplication
    - created_at: When message was created (auto-set)
    - updated_at: Last update (auto-managed)
    """
    chat = models.ForeignKey(
        Chat,
        on_delete=models.CASCADE,
        related_name="messages",
        help_text="Chat this message belongs to"
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sent_messages",
        help_text="User who sent this message"
    )
    text = models.TextField(
        help_text="Message content"
    )
    client_message_id = models.CharField(
        max_length=64,
        null=True,
        blank=True,
        db_index=True,
        help_text="Client-generated UUID for deduplication"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="When message was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When message was last updated"
    )

    class Meta:
        ordering = ("created_at", "id")
        indexes = [
            # Messages ordered by time
            models.Index(fields=["chat", "created_at"]),
            # Sender's messages
            models.Index(fields=["sender", "-created_at"]),
            # Chat messages reverse order
            models.Index(fields=["chat", "-created_at"]),
            # Deduplication lookups
            models.Index(fields=["chat", "client_message_id"], name="chat_client_msg_idx"),
            models.Index(fields=["sender", "client_message_id"], name="sender_client_msg_idx"),
        ]
        constraints = [
            # Prevent duplicate messages from same sender with same client_message_id
            models.UniqueConstraint(
                fields=['sender', 'client_message_id'],
                condition=Q(client_message_id__isnull=False),
                name='unique_client_message_per_sender'
            ),
        ]
        verbose_name = "Chat Message"
        verbose_name_plural = "Chat Messages"

    def __str__(self) -> str:
        text_preview = str(self.text)[:50] if self.text else ""
        username = getattr(self.sender, 'username', 'Unknown') if self.sender else 'Unknown'
        return f"{username}: {text_preview}"
    
    def save(self, *args, **kwargs):
        """
        Ensure message is always saved with timestamp.
        This method ensures data persistence.
        """
        if not self.created_at:
            self.created_at = timezone.now()
        
        super().save(*args, **kwargs)
        
        logger.debug(
            "ChatMessage %s saved: chat=%s, sender=%s, text_length=%s, created_at=%s",
            self.id,  # type: ignore[attr-defined]
            self.chat_id,  # type: ignore[attr-defined]
            self.sender_id,  # type: ignore[attr-defined]
            len(self.text),
            self.created_at
        )


