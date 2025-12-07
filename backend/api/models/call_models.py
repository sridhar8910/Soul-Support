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

class Call(models.Model):
    """
    Model for video/voice calls between users and counselors.
    
    All call data is saved to database for persistence and history.
    Supports duration tracking and status management.
    """
    CALL_TYPE_VIDEO = "video"
    CALL_TYPE_VOICE = "voice"
    
    CALL_TYPE_CHOICES = [
        (CALL_TYPE_VIDEO, "Video Call"),
        (CALL_TYPE_VOICE, "Voice Call"),
    ]
    
    STATUS_SCHEDULED = "scheduled"
    STATUS_RINGING = "ringing"
    STATUS_ACTIVE = "active"
    STATUS_ENDED = "ended"
    STATUS_MISSED = "missed"
    STATUS_CANCELLED = "cancelled"
    
    STATUS_CHOICES = [
        (STATUS_SCHEDULED, "Scheduled"),
        (STATUS_RINGING, "Ringing"),
        (STATUS_ACTIVE, "Active"),
        (STATUS_ENDED, "Ended"),
        (STATUS_MISSED, "Missed"),
        (STATUS_CANCELLED, "Cancelled"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="user_calls",
        help_text="User who initiated the call"
    )
    counsellor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="counsellor_calls",
        limit_choices_to={"counsellorprofile__isnull": False},
        help_text="Counselor for this call"
    )
    call_type = models.CharField(
        max_length=20,
        choices=CALL_TYPE_CHOICES,
        default=CALL_TYPE_VIDEO,
        help_text="Type of call (video or voice)"
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_SCHEDULED,
        help_text="Current status of the call"
    )
    scheduled_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When call is scheduled"
    )
    started_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When call started"
    )
    ended_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When call ended"
    )
    duration_seconds = models.PositiveIntegerField(
        default=0,
        help_text="Call duration in seconds"
    )
    notes = models.TextField(
        blank=True,
        help_text="Post-call notes or summary"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When call was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When call was last updated"
    )

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["counsellor", "-created_at"]),
            models.Index(fields=["status", "-created_at"]),
            models.Index(fields=["counsellor", "status"]),
            models.Index(fields=["scheduled_at", "status"]),
        ]
        verbose_name = "Call"
        verbose_name_plural = "Calls"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        try:
            call_type = self.get_call_type_display()  # pyright: ignore[reportAttributeAccessIssue]
        except AttributeError:
            call_type = self.call_type
        return f"{username} -> {call_type} ({self.status})"
    
    def save(self, *args, **kwargs):
        """
        Ensure call is always saved with proper timestamps and duration.
        Auto-calculates duration when call ends.
        """
        # Auto-set started_at when call becomes active
        if self.status == self.STATUS_ACTIVE and not self.started_at:
            self.started_at = timezone.now()
        
        # Auto-set ended_at and calculate duration when call ends
        if self.status == self.STATUS_ENDED and self.started_at and not self.ended_at:
            self.ended_at = timezone.now()
            # Calculate duration
            if self.started_at:
                delta = self.ended_at - self.started_at
                self.duration_seconds = int(delta.total_seconds())
        
        super().save(*args, **kwargs)
    
    @property
    def duration_formatted(self) -> str:
        """Return formatted duration string (e.g., '5m 30s')."""
        if self.duration_seconds == 0:
            return "0s"
        minutes = self.duration_seconds // 60
        seconds = self.duration_seconds % 60
        if minutes > 0:
            return f"{minutes}m {seconds}s"
        return f"{seconds}s"


