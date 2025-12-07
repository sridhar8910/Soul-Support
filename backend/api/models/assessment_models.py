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

class Assessment(models.Model):
    """Mental health assessment template."""
    
    title = models.CharField(
        max_length=200,
        help_text="Assessment title"
    )
    description = models.TextField(
        blank=True,
        help_text="Assessment description"
    )
    category = models.CharField(
        max_length=100,
        blank=True,
        help_text="Assessment category (e.g., Depression, Anxiety, Stress)"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether assessment is available"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When assessment was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When assessment was last updated"
    )

    class Meta:
        ordering = ["title"]
        verbose_name = "Assessment"
        verbose_name_plural = "Assessments"

    def __str__(self) -> str:
        return self.title


class AssessmentQuestion(models.Model):
    """Questions for an assessment."""
    
    assessment = models.ForeignKey(
        Assessment,
        on_delete=models.CASCADE,
        related_name="questions",
        help_text="Parent assessment"
    )
    question_text = models.TextField(
        help_text="Question text"
    )
    question_type = models.CharField(
        max_length=50,
        default="multiple_choice",
        choices=[
            ("multiple_choice", "Multiple Choice"),
            ("scale", "Scale"),
            ("text", "Text"),
        ],
        help_text="Type of question"
    )
    options = models.JSONField(
        default=list,
        blank=True,
        help_text="Answer options (for multiple choice or scale)"
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="Display order"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When question was created"
    )

    class Meta:
        ordering = ["assessment", "order"]
        verbose_name = "Assessment Question"
        verbose_name_plural = "Assessment Questions"

    def __str__(self) -> str:
        return f"{self.assessment.title} - Q{self.order}: {self.question_text[:50]}"


class AssessmentResult(models.Model):
    """User's assessment submission and results."""
    
    RESULT_NORMAL = "normal"
    RESULT_MILD = "mild"
    RESULT_MODERATE = "moderate"
    RESULT_SEVERE = "severe"
    
    RESULT_CHOICES = [
        (RESULT_NORMAL, "Normal"),
        (RESULT_MILD, "Mild"),
        (RESULT_MODERATE, "Moderate"),
        (RESULT_SEVERE, "Severe"),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="assessment_results",
        help_text="User who took the assessment"
    )
    assessment = models.ForeignKey(
        Assessment,
        on_delete=models.CASCADE,
        related_name="results",
        help_text="Assessment taken"
    )
    answers = models.JSONField(
        default=dict,
        help_text="User's answers (question_id -> answer)"
    )
    total_score = models.FloatField(
        null=True,
        blank=True,
        help_text="Total assessment score"
    )
    result_category = models.CharField(
        max_length=20,
        choices=RESULT_CHOICES,
        help_text="Result category"
    )
    recommendations = models.TextField(
        blank=True,
        help_text="Personalized recommendations"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When assessment was completed"
    )

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Assessment Result"
        verbose_name_plural = "Assessment Results"

    def __str__(self) -> str:
        return f"{self.user.username} - {self.assessment.title} ({self.result_category})"


