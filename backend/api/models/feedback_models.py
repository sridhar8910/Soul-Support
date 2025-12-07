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

class UserFeedback(models.Model):
    """
    Feedback from counsellors about users.
    
    This allows counsellors to leave notes and feedback about users
    that can help other counsellors understand the user's issues and
    provide better support in future interactions.
    
    Fields:
    - user: The user this feedback is about
    - counsellor: The counsellor who wrote the feedback
    - chat: Optional reference to the chat session (if feedback is chat-specific)
    - issue_category: Category of the issue discussed
    - feedback_text: The actual feedback/notes
    - priority: Priority level (low, medium, high, critical)
    - is_private: Whether this feedback is private (only visible to the counsellor who wrote it)
    - created_at: When feedback was created
    - updated_at: Last update timestamp
    """
    PRIORITY_LOW = "low"
    PRIORITY_MEDIUM = "medium"
    PRIORITY_HIGH = "high"
    PRIORITY_CRITICAL = "critical"
    
    PRIORITY_CHOICES = [
        (PRIORITY_LOW, "Low"),
        (PRIORITY_MEDIUM, "Medium"),
        (PRIORITY_HIGH, "High"),
        (PRIORITY_CRITICAL, "Critical"),
    ]
    
    ISSUE_CATEGORY_ANXIETY = "anxiety"
    ISSUE_CATEGORY_DEPRESSION = "depression"
    ISSUE_CATEGORY_STRESS = "stress"
    ISSUE_CATEGORY_RELATIONSHIP = "relationship"
    ISSUE_CATEGORY_WORK = "work"
    ISSUE_CATEGORY_FAMILY = "family"
    ISSUE_CATEGORY_TRAUMA = "trauma"
    ISSUE_CATEGORY_SUBSTANCE = "substance"
    ISSUE_CATEGORY_EATING = "eating"
    ISSUE_CATEGORY_SLEEP = "sleep"
    ISSUE_CATEGORY_OTHER = "other"
    
    ISSUE_CATEGORY_CHOICES = [
        (ISSUE_CATEGORY_ANXIETY, "Anxiety"),
        (ISSUE_CATEGORY_DEPRESSION, "Depression"),
        (ISSUE_CATEGORY_STRESS, "Stress"),
        (ISSUE_CATEGORY_RELATIONSHIP, "Relationship Issues"),
        (ISSUE_CATEGORY_WORK, "Work/Career"),
        (ISSUE_CATEGORY_FAMILY, "Family Issues"),
        (ISSUE_CATEGORY_TRAUMA, "Trauma"),
        (ISSUE_CATEGORY_SUBSTANCE, "Substance Use"),
        (ISSUE_CATEGORY_EATING, "Eating Disorders"),
        (ISSUE_CATEGORY_SLEEP, "Sleep Issues"),
        (ISSUE_CATEGORY_OTHER, "Other"),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="feedback_received",
        help_text="User this feedback is about"
    )
    counsellor = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="feedback_given",
        limit_choices_to={"counsellorprofile__isnull": False},
        help_text="Counsellor who wrote this feedback"
    )
    chat = models.ForeignKey(
        'Chat',  # Use string reference to avoid circular imports
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="feedback",
        help_text="Optional reference to the chat session this feedback relates to"
    )
    issue_category = models.CharField(
        max_length=50,
        choices=ISSUE_CATEGORY_CHOICES,
        default=ISSUE_CATEGORY_OTHER,
        help_text="Category of the issue discussed"
    )
    feedback_text = models.TextField(
        help_text="Feedback notes about the user and their issues"
    )
    priority = models.CharField(
        max_length=20,
        choices=PRIORITY_CHOICES,
        default=PRIORITY_MEDIUM,
        help_text="Priority level of the feedback"
    )
    is_private = models.BooleanField(
        default=False,
        help_text="Whether this feedback is private (only visible to the counsellor who wrote it)"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When feedback was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When feedback was last updated"
    )
    
    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=["user", "-created_at"]),
            models.Index(fields=["counsellor", "-created_at"]),
            models.Index(fields=["user", "is_private"]),
            models.Index(fields=["issue_category", "-created_at"]),
            models.Index(fields=["priority", "-created_at"]),
        ]
        verbose_name = "User Feedback"
        verbose_name_plural = "User Feedbacks"
    
    def __str__(self) -> str:
        counsellor_name = getattr(self.counsellor, 'username', 'Unknown') if self.counsellor else 'Unknown'
        user_name = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"Feedback from {counsellor_name} about {user_name} - {self.get_issue_category_display()}"
    
    def save(self, *args, **kwargs):
        """Ensure feedback is always saved with timestamps."""
        # Validate that counsellor is actually a counsellor
        if not hasattr(self.counsellor, 'counsellorprofile'):
            raise ValueError(f"User {self.counsellor.username} is not a counsellor")
        
        super().save(*args, **kwargs)
        
        logger.info(
            f"UserFeedback {self.id} saved: user={self.user_id}, counsellor={self.counsellor_id}, "
            f"issue_category={self.issue_category}, priority={self.priority}, "
            f"is_private={self.is_private}, created_at={self.created_at}"
        )