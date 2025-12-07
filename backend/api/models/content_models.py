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

class GuidanceResource(models.Model):
    """Guidance resources (articles, talks, podcasts)."""
    TYPE_ARTICLE = "article"
    TYPE_TALK = "talk"
    TYPE_PODCAST = "podcast"
    
    TYPE_CHOICES = [
        (TYPE_ARTICLE, "Article"),
        (TYPE_TALK, "Expert Talk"),
        (TYPE_PODCAST, "Podcast"),
    ]

    resource_type = models.CharField(
        max_length=16,
        choices=TYPE_CHOICES,
        help_text="Type of resource"
    )
    title = models.CharField(
        max_length=200,
        help_text="Resource title"
    )
    subtitle = models.CharField(
        max_length=160,
        blank=True,
        help_text="Resource subtitle"
    )
    summary = models.TextField(
        blank=True,
        help_text="Resource summary"
    )
    category = models.CharField(
        max_length=120,
        blank=True,
        help_text="Resource category"
    )
    duration = models.CharField(
        max_length=40,
        blank=True,
        help_text="Resource duration"
    )
    media_url = models.URLField(
        blank=True,
        help_text="Media URL"
    )
    thumbnail = models.URLField(
        blank=True,
        help_text="Thumbnail URL"
    )
    is_featured = models.BooleanField(
        default=False,
        help_text="Whether resource is featured"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When resource was created"
    )

    class Meta:
        ordering = ("resource_type", "title")
        verbose_name = "Guidance Resource"
        verbose_name_plural = "Guidance Resources"

    def __str__(self) -> str:
        try:
            resource_type = self.get_resource_type_display()  # type: ignore[attr-defined]
        except AttributeError:
            resource_type = self.resource_type
        return f"{resource_type} • {self.title}"


class MusicTrack(models.Model):
    """Music tracks for mood-based listening."""
    MOOD_CALM = "calm"
    MOOD_FOCUS = "focus"
    MOOD_SLEEP = "sleep"
    MOOD_UPLIFT = "uplift"
    
    MOOD_CHOICES = [
        (MOOD_CALM, "Calm"),
        (MOOD_FOCUS, "Focus"),
        (MOOD_SLEEP, "Sleep"),
        (MOOD_UPLIFT, "Uplift"),
    ]

    title = models.CharField(
        max_length=160,
        unique=True,
        help_text="Track title"
    )
    description = models.TextField(
        blank=True,
        help_text="Track description"
    )
    duration_seconds = models.PositiveIntegerField(
        default=180,
        help_text="Track duration in seconds"
    )
    audio_url = models.URLField(
        blank=True,
        help_text="Audio file URL"
    )
    mood = models.CharField(
        max_length=20,
        choices=MOOD_CHOICES,
        default=MOOD_CALM,
        help_text="Mood category"
    )
    thumbnail = models.URLField(
        blank=True,
        help_text="Thumbnail URL"
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="Display order"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When track was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When track was last updated"
    )

    class Meta:
        ordering = ["order", "title"]
        verbose_name = "Music Track"
        verbose_name_plural = "Music Tracks"

    def __str__(self) -> str:
        return str(self.title) if self.title else "Untitled Track"


class MindCareBooster(models.Model):
    """Mind care boosters (breathing, audio, movement, reflection)."""
    CATEGORY_BREATHING = "breathing"
    CATEGORY_AUDIO = "audio"
    CATEGORY_MOVEMENT = "movement"
    CATEGORY_REFLECTION = "reflection"
    
    CATEGORY_CHOICES = [
        (CATEGORY_BREATHING, "Breathing"),
        (CATEGORY_AUDIO, "Audio"),
        (CATEGORY_MOVEMENT, "Movement"),
        (CATEGORY_REFLECTION, "Reflection"),
    ]

    title = models.CharField(
        max_length=160,
        unique=True,
        help_text="Booster title"
    )
    subtitle = models.CharField(
        max_length=160,
        blank=True,
        help_text="Booster subtitle"
    )
    description = models.TextField(
        blank=True,
        help_text="Booster description"
    )
    category = models.CharField(
        max_length=32,
        choices=CATEGORY_CHOICES,
        default=CATEGORY_BREATHING,
        help_text="Booster category"
    )
    icon = models.CharField(
        max_length=40,
        blank=True,
        help_text="Icon identifier"
    )
    action_label = models.CharField(
        max_length=60,
        default="Start",
        help_text="Action button label"
    )
    prompt = models.TextField(
        blank=True,
        help_text="Booster prompt text"
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="Display order"
    )
    estimated_seconds = models.PositiveIntegerField(
        default=120,
        help_text="Estimated duration in seconds"
    )
    resource_url = models.URLField(
        blank=True,
        help_text="Resource URL"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When booster was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When booster was last updated"
    )

    class Meta:
        ordering = ["order", "title"]
        verbose_name = "Mind Care Booster"
        verbose_name_plural = "Mind Care Boosters"

    def __str__(self) -> str:
        return str(self.title) if self.title else "Untitled Track"


class MeditationSession(models.Model):
    """Meditation sessions with different difficulty levels."""
    DIFFICULTY_BEGINNER = "beginner"
    DIFFICULTY_INTERMEDIATE = "intermediate"
    DIFFICULTY_ADVANCED = "advanced"
    
    DIFFICULTY_CHOICES = [
        (DIFFICULTY_BEGINNER, "Beginner"),
        (DIFFICULTY_INTERMEDIATE, "Intermediate"),
        (DIFFICULTY_ADVANCED, "Advanced"),
    ]

    title = models.CharField(
        max_length=160,
        unique=True,
        help_text="Session title"
    )
    subtitle = models.CharField(
        max_length=160,
        blank=True,
        help_text="Session subtitle"
    )
    description = models.TextField(
        blank=True,
        help_text="Session description"
    )
    category = models.CharField(
        max_length=60,
        help_text="Session category"
    )
    duration_minutes = models.PositiveIntegerField(
        default=5,
        help_text="Session duration in minutes"
    )
    difficulty = models.CharField(
        max_length=20,
        choices=DIFFICULTY_CHOICES,
        default=DIFFICULTY_BEGINNER,
        help_text="Difficulty level"
    )
    audio_url = models.URLField(
        blank=True,
        help_text="Audio file URL"
    )
    video_url = models.URLField(
        blank=True,
        help_text="Video file URL"
    )
    is_featured = models.BooleanField(
        default=False,
        help_text="Whether session is featured"
    )
    thumbnail = models.URLField(
        blank=True,
        help_text="Thumbnail URL"
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="Display order"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When session was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When session was last updated"
    )

    class Meta:
        ordering = ["order", "title"]
        verbose_name = "Meditation Session"
        verbose_name_plural = "Meditation Sessions"

    def __str__(self) -> str:
        return str(self.title) if self.title else "Untitled Track"


