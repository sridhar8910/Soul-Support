"""
User profile models for the mental health counseling platform.
"""
# type: ignore
# pyright: reportAttributeAccessIssue=false
# pylint: disable=no-member,broad-except
from django.contrib.auth.models import User
from django.db import models
import logging

logger = logging.getLogger(__name__)


class UserProfile(models.Model):
    """
    Extended user profile with preferences, wallet, and mood tracking.
    All data is saved to database for persistence.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="profile",
        help_text="Associated Django User"
    )
    full_name = models.CharField(max_length=120, blank=True, help_text="User's full name")
    nickname = models.CharField(max_length=80, blank=True, help_text="User's preferred nickname")
    phone = models.CharField(max_length=30, blank=True, help_text="Contact phone number")
    age = models.PositiveIntegerField(null=True, blank=True, help_text="User's age")
    gender = models.CharField(max_length=50, blank=True, help_text="User's gender")
    
    # Wallet system
    wallet_minutes = models.PositiveIntegerField(
        default=100,
        help_text="Available minutes in wallet for services"
    )
    
    # Mood tracking
    last_mood = models.DecimalField(
        max_digits=3,
        decimal_places=1,
        default=3.0,
        help_text="Last recorded mood value (1-5 scale with half-point precision, e.g., 1.5, 2.5, 3.5)"
    )
    last_mood_updated = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When mood was last updated"
    )
    mood_updates_count = models.PositiveSmallIntegerField(
        default=0,
        help_text="Total number of mood updates"
    )
    mood_updates_date = models.DateField(
        null=True,
        blank=True,
        help_text="Date of last mood update"
    )
    
    # Preferences
    timezone = models.CharField(
        max_length=64,
        blank=True,
        help_text="User's timezone (e.g., 'Asia/Kolkata')"
    )
    notifications_enabled = models.BooleanField(
        default=True,
        help_text="Whether notifications are enabled"
    )
    prefers_dark_mode = models.BooleanField(
        default=False,
        help_text="Whether user prefers dark mode"
    )
    language = models.CharField(
        max_length=32,
        default="English",
        help_text="Preferred language"
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When profile was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When profile was last updated"
    )

    class Meta:
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["wallet_minutes"]),
        ]
        verbose_name = "User Profile"
        verbose_name_plural = "User Profiles"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} - Profile"
    
    def save(self, *args, **kwargs):
        """Ensure profile is always saved with timestamps."""
        super().save(*args, **kwargs)
        logger.debug("UserProfile saved: user=%s, wallet=%s", self.user_id, self.wallet_minutes)  # type: ignore[attr-defined]

