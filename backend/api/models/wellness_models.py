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

class WellnessTask(models.Model):
    """Daily or evening wellness tasks for users."""
    CATEGORY_DAILY = "daily"
    CATEGORY_EVENING = "evening"
    
    CATEGORY_CHOICES = [
        (CATEGORY_DAILY, "Daily"),
        (CATEGORY_EVENING, "Evening"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="wellness_tasks",
        help_text="User who owns this task"
    )
    title = models.CharField(
        max_length=150,
        help_text="Task title"
    )
    category = models.CharField(
        max_length=20,
        choices=CATEGORY_CHOICES,
        help_text="Task category"
    )
    is_completed = models.BooleanField(
        default=False,
        help_text="Whether task is completed"
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="Display order"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When task was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When task was last updated"
    )

    class Meta:
        unique_together = ("user", "title", "category")
        ordering = ("category", "order", "id")
        indexes = [
            models.Index(fields=["user", "category", "is_completed"]),
            models.Index(fields=["user", "-created_at"]),
        ]
        verbose_name = "Wellness Task"
        verbose_name_plural = "Wellness Tasks"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} • {self.title}"
    
    def save(self, *args, **kwargs):
        """Ensure task is always saved with timestamps."""
        super().save(*args, **kwargs)


class WellnessJournalEntry(models.Model):
    """Journal entries for user wellness tracking."""
    ENTRY_TYPE_3_DAY = "3-Day Journal"
    ENTRY_TYPE_WEEKLY = "Weekly Journal"
    ENTRY_TYPE_CUSTOM = "Custom"
    
    ENTRY_TYPE_CHOICES = [
        (ENTRY_TYPE_3_DAY, "3-Day Journal"),
        (ENTRY_TYPE_WEEKLY, "Weekly Journal"),
        (ENTRY_TYPE_CUSTOM, "Custom"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="wellness_journal_entries",
        help_text="User who owns this journal entry"
    )
    title = models.CharField(
        max_length=160,
        help_text="Entry title"
    )
    note = models.TextField(
        help_text="Journal entry content"
    )
    mood = models.CharField(
        max_length=16,
        help_text="Mood at time of entry"
    )
    entry_type = models.CharField(
        max_length=40,
        choices=ENTRY_TYPE_CHOICES,
        help_text="Type of journal entry"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When entry was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When entry was last updated"
    )

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["user", "entry_type", "-created_at"]),
        ]
        verbose_name = "Wellness Journal Entry"
        verbose_name_plural = "Wellness Journal Entries"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} • {self.title}"
    
    def save(self, *args, **kwargs):
        """Ensure journal entry is always saved with timestamps."""
        super().save(*args, **kwargs)


class MyJournal(models.Model):
    """
    Simple journal entries used by the 'My Journal' UI.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="my_journal_entries",
        help_text="Owner of entry"
    )
    entry = models.CharField(
        max_length=200,
        help_text="Entry title"
    )
    emoji = models.CharField(
        max_length=32,
        blank=True,
        help_text="Emoji or short label"
    )
    date = models.DateField(
        help_text="Entry date"
    )
    write_something = models.TextField(
        help_text="Journal content"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When entry was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When entry was last updated"
    )
    
    class Meta:
        ordering = ("-date", "-created_at")
        indexes = [
            models.Index(fields=["user", "-date"]),
            models.Index(fields=["user", "-created_at"]),
        ]
        verbose_name = "My Journal Entry"
        verbose_name_plural = "My Journal Entries"
    
    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} - {self.entry} ({self.date})"


