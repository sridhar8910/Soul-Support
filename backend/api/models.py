from django.contrib.auth.models import User
from django.db import models


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    full_name = models.CharField(max_length=120, blank=True)
    nickname = models.CharField(max_length=80, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    age = models.PositiveIntegerField(null=True, blank=True)
    gender = models.CharField(max_length=50, blank=True)
    wallet_minutes = models.PositiveIntegerField(default=100)
    last_mood = models.PositiveSmallIntegerField(default=3)
    last_mood_updated = models.DateTimeField(null=True, blank=True)
    mood_updates_count = models.PositiveSmallIntegerField(default=0)
    mood_updates_date = models.DateField(null=True, blank=True)
    timezone = models.CharField(max_length=64, blank=True)
    notifications_enabled = models.BooleanField(default=True)
    prefers_dark_mode = models.BooleanField(default=False)
    language = models.CharField(max_length=32, default="English")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return self.user.username


class WellnessTask(models.Model):
    DAILY = "daily"
    EVENING = "evening"
    CATEGORY_CHOICES = [
        (DAILY, "Daily"),
        (EVENING, "Evening"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="wellness_tasks",
    )
    title = models.CharField(max_length=150)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    is_completed = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "title", "category")
        ordering = ("category", "order", "id")

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return f"{self.user.username} • {self.title}"


class WellnessJournalEntry(models.Model):
    ENTRY_TYPE_CHOICES = [
        ("3-Day Journal", "3-Day Journal"),
        ("Weekly Journal", "Weekly Journal"),
        ("Custom", "Custom"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="wellness_journal_entries",
    )
    title = models.CharField(max_length=160)
    note = models.TextField()
    mood = models.CharField(max_length=16)
    entry_type = models.CharField(max_length=40, choices=ENTRY_TYPE_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at", "-id")

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return f"{self.user.username} • {self.title}"


class SupportGroup(models.Model):
    slug = models.SlugField(max_length=80, unique=True)
    name = models.CharField(max_length=160)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=64, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("name",)

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return self.name


class SupportGroupMembership(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="support_group_memberships")
    group = models.ForeignKey(SupportGroup, on_delete=models.CASCADE, related_name="memberships")
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "group")
        ordering = ("-joined_at",)

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return f"{self.user.username} -> {self.group.slug}"


class UpcomingSession(models.Model):
    SESSION_TYPE_CHOICES = [
        ("one_on_one", "One-on-One"),
        ("group", "Group"),
        ("workshop", "Workshop"),
        ("webinar", "Webinar"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="upcoming_sessions")
    title = models.CharField(max_length=180)
    session_type = models.CharField(max_length=40, choices=SESSION_TYPE_CHOICES)
    start_time = models.DateTimeField()
    counsellor_name = models.CharField(max_length=160)
    notes = models.TextField(blank=True)
    is_confirmed = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("start_time", "id")

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return f"{self.user.username} -> {self.title} @ {self.start_time}"


class Chat(models.Model):
    STATUS_CHOICES = [
        ("queued", "Queued"),
        ("active", "Active"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="chats")
    counsellor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_chats",
        limit_choices_to={"counsellorprofile__isnull": False}
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="queued")
    initial_message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("created_at", "id")

    def __str__(self) -> str:  # pragma: no cover - simple string representation
        return f"{self.user.username} -> Chat ({self.status})"


class EmailOTP(models.Model):
    PURPOSE_REGISTRATION = "registration"
    PURPOSE_PASSWORD_RESET = "password_reset"

    PURPOSE_CHOICES = [
        (PURPOSE_REGISTRATION, "Registration"),
        (PURPOSE_PASSWORD_RESET, "Password reset"),
    ]

    email = models.EmailField()
    code = models.CharField(max_length=6)
    purpose = models.CharField(max_length=32, choices=PURPOSE_CHOICES)
    token = models.CharField(max_length=64, unique=True)
    is_verified = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    verified_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["email", "purpose", "is_verified"]),
            models.Index(fields=["token"]),
        ]
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover - debug helper
        return f"{self.email} -> {self.purpose}"

    @property
    def is_expired(self) -> bool:
        from django.utils import timezone

        return timezone.now() >= self.expires_at

    def mark_verified(self):
        from django.utils import timezone

        self.is_verified = True
        self.verified_at = timezone.now()
        self.save(update_fields=["is_verified", "verified_at"])


class MoodLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="mood_logs")
    value = models.PositiveSmallIntegerField()
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-recorded_at",)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user.username} -> {self.value} @ {self.recorded_at}"


class GuidanceResource(models.Model):
    TYPE_ARTICLE = "article"
    TYPE_TALK = "talk"
    TYPE_PODCAST = "podcast"
    TYPE_CHOICES = [
        (TYPE_ARTICLE, "Article"),
        (TYPE_TALK, "Expert Talk"),
        (TYPE_PODCAST, "Podcast"),
    ]

    resource_type = models.CharField(max_length=16, choices=TYPE_CHOICES)
    title = models.CharField(max_length=200)
    subtitle = models.CharField(max_length=160, blank=True)
    summary = models.TextField(blank=True)
    category = models.CharField(max_length=120, blank=True)
    duration = models.CharField(max_length=40, blank=True)
    media_url = models.URLField(blank=True)
    thumbnail = models.URLField(blank=True)
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("resource_type", "title")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.get_resource_type_display()} • {self.title}"


class MusicTrack(models.Model):
    MOOD_CHOICES = [
        ("calm", "Calm"),
        ("focus", "Focus"),
        ("sleep", "Sleep"),
        ("uplift", "Uplift"),
    ]

    title = models.CharField(max_length=160, unique=True)
    description = models.TextField(blank=True)
    duration_seconds = models.PositiveIntegerField(default=180)
    audio_url = models.URLField(blank=True)
    mood = models.CharField(max_length=20, choices=MOOD_CHOICES, default="calm")
    thumbnail = models.URLField(blank=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "title"]


class MindCareBooster(models.Model):
    CATEGORY_CHOICES = [
        ("breathing", "Breathing"),
        ("audio", "Audio"),
        ("movement", "Movement"),
        ("reflection", "Reflection"),
    ]

    title = models.CharField(max_length=160, unique=True)
    subtitle = models.CharField(max_length=160, blank=True)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=32, choices=CATEGORY_CHOICES, default="breathing")
    icon = models.CharField(max_length=40, blank=True)
    action_label = models.CharField(max_length=60, default="Start")
    prompt = models.TextField(blank=True)
    order = models.PositiveIntegerField(default=0)
    estimated_seconds = models.PositiveIntegerField(default=120)
    resource_url = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "title"]


class MeditationSession(models.Model):
    DIFFICULTY_CHOICES = [
        ("beginner", "Beginner"),
        ("intermediate", "Intermediate"),
        ("advanced", "Advanced"),
    ]

    title = models.CharField(max_length=160, unique=True)
    subtitle = models.CharField(max_length=160, blank=True)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=60)
    duration_minutes = models.PositiveIntegerField(default=5)
    difficulty = models.CharField(max_length=20, choices=DIFFICULTY_CHOICES, default="beginner")
    audio_url = models.URLField(blank=True)
    video_url = models.URLField(blank=True)
    is_featured = models.BooleanField(default=False)
    thumbnail = models.URLField(blank=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "title"]


class CounsellorProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="counsellorprofile"
    )
    specialization = models.CharField(max_length=200, blank=True)
    experience_years = models.PositiveIntegerField(default=0)
    languages = models.JSONField(default=list, blank=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.0)
    is_available = models.BooleanField(default=True)
    bio = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.user.username} - Counsellor"


class DoctorProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="doctorprofile"
    )
    specialization = models.CharField(max_length=200, blank=True)
    experience_years = models.PositiveIntegerField(default=0)
    license_number = models.CharField(max_length=100, blank=True)
    languages = models.JSONField(default=list, blank=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.0)
    is_available = models.BooleanField(default=True)
    bio = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.user.username} - Doctor"
