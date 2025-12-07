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

class UpcomingSession(models.Model):
    """
    Scheduled sessions between users and counselors.
    
    All session data is saved to database for persistence and history.
    Supports start/end tracking via notes field.
    """
    SESSION_TYPE_ONE_ON_ONE = "one_on_one"
    SESSION_TYPE_GROUP = "group"
    SESSION_TYPE_WORKSHOP = "workshop"
    SESSION_TYPE_WEBINAR = "webinar"
    
    SESSION_TYPE_CHOICES = [
        (SESSION_TYPE_ONE_ON_ONE, "One-on-One"),
        (SESSION_TYPE_GROUP, "Group"),
        (SESSION_TYPE_WORKSHOP, "Workshop"),
        (SESSION_TYPE_WEBINAR, "Webinar"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="upcoming_sessions",
        help_text="User who scheduled this session"
    )
    counsellor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="counsellor_sessions",
        limit_choices_to={"counsellorprofile__isnull": False},
        help_text="Counselor assigned to this session"
    )
    title = models.CharField(
        max_length=180,
        help_text="Session title"
    )
    session_type = models.CharField(
        max_length=40,
        choices=SESSION_TYPE_CHOICES,
        help_text="Type of session"
    )
    start_time = models.DateTimeField(
        help_text="Scheduled start time"
    )
    counsellor_name = models.CharField(
        max_length=160,
        help_text="Name of the counselor"
    )
    notes = models.TextField(
        blank=True,
        help_text="Session notes (confidential notes for counselor)"
    )
    is_confirmed = models.BooleanField(
        default=True,
        help_text="Whether session is confirmed"
    )
    
    # Session execution tracking (actual start/end times)
    actual_start_time = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        help_text="When session actually started (not scheduled time)"
    )
    actual_end_time = models.DateTimeField(
        null=True,
        blank=True,
        db_index=True,
        help_text="When session actually ended"
    )
    session_status = models.CharField(
        max_length=20,
        choices=[
            ('scheduled', 'Scheduled'),
            ('in_progress', 'In Progress'),
            ('completed', 'Completed'),
            ('cancelled', 'Cancelled'),
            ('no_show', 'No Show'),
        ],
        default='scheduled',
        db_index=True,
        help_text="Current status of the session"
    )
    
    # Risk assessment and flags
    risk_level = models.CharField(
        max_length=20,
        choices=[
            ('none', 'None'),
            ('low', 'Low'),
            ('medium', 'Medium'),
            ('high', 'High'),
            ('critical', 'Critical'),
        ],
        default='none',
        help_text="Risk level assessment"
    )
    manual_flag = models.CharField(
        max_length=10,
        choices=[
            ('green', 'Green'),
            ('yellow', 'Yellow'),
            ('red', 'Red'),
        ],
        default='green',
        help_text="Manual flag set by counselor"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When session was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When session was last updated"
    )
    
    @property
    def duration_seconds(self) -> int:
        """Calculate session duration in seconds."""
        if not self.actual_start_time:
            return 0
        end_time = self.actual_end_time or timezone.now()
        return int((end_time - self.actual_start_time).total_seconds())
    
    @property
    def duration_minutes(self) -> int:
        """Calculate session duration in minutes."""
        return self.duration_seconds // 60

    class Meta:
        ordering = ("start_time", "id")
        indexes = [
            models.Index(fields=["user", "start_time"]),
            models.Index(fields=["counsellor", "start_time"]),
            models.Index(fields=["start_time", "is_confirmed"]),
            models.Index(fields=["counsellor", "session_status"]),
            models.Index(fields=["session_status", "actual_start_time"]),
        ]
        verbose_name = "Upcoming Session"
        verbose_name_plural = "Upcoming Sessions"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} -> {self.title} @ {self.start_time}"


class SessionRating(models.Model):
    """
    User ratings for completed counselling sessions.
    """
    RATING_CHOICES = [
        (1, "1 Star"),
        (2, "2 Stars"),
        (3, "3 Stars"),
        (4, "4 Stars"),
        (5, "5 Stars"),
    ]
    
    session = models.OneToOneField(
        UpcomingSession,
        on_delete=models.CASCADE,
        related_name='rating',
        help_text="The session being rated"
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='given_ratings',
        help_text="User who gave rating"
    )
    counsellor = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='received_ratings',
        limit_choices_to={"counsellorprofile__isnull": False},
        help_text="Counsellor being rated"
    )
    rating = models.IntegerField(
        choices=RATING_CHOICES,
        help_text="Rating from 1-5 stars"
    )
    feedback = models.TextField(
        blank=True,
        help_text="Optional written feedback"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When rating was created"
    )
    
    class Meta:
        indexes = [
            models.Index(fields=["counsellor", "-created_at"]),
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["session"]),
        ]
        verbose_name = "Session Rating"
        verbose_name_plural = "Session Ratings"
    
    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} -> {self.rating} stars for session {self.session_id}"

