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

class MoodLog(models.Model):
    """Log of user mood updates."""
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="mood_logs",
        help_text="User who recorded this mood"
    )
    value = models.DecimalField(
        max_digits=3,
        decimal_places=1,
        help_text="Mood value (1-5 scale with half-point precision, e.g., 1.5, 2.5, 3.5)"
    )
    recorded_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When mood was recorded"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When log was created"
    )

    class Meta:
        ordering = ("-recorded_at", "-id")
        indexes = [
            models.Index(fields=["user", "-recorded_at"]),
            models.Index(fields=["user", "value", "-recorded_at"]),
        ]
        verbose_name = "Mood Log"
        verbose_name_plural = "Mood Logs"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} -> {self.value} @ {self.recorded_at}"

    def save(self, *args, **kwargs):
        """Ensure mood log is always saved with timestamp."""
        if not self.recorded_at:
            self.recorded_at = timezone.now()
        super().save(*args, **kwargs)

