"""
Professional profile models (counsellors and doctors).
"""
# type: ignore
# pyright: reportAttributeAccessIssue=false
# pylint: disable=no-member,broad-except
from django.contrib.auth.models import User
from django.db import models
import logging

logger = logging.getLogger(__name__)


class CounsellorProfile(models.Model):
    """
    Profile for counselors with specialization and availability.
    Used to identify counselors in Chat and UpcomingSession models.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="counsellorprofile",
        help_text="Associated Django User (must be a counselor)"
    )
    specialization = models.CharField(
        max_length=200,
        blank=True,
        help_text="Counselor's area of specialization"
    )
    experience_years = models.PositiveIntegerField(
        default=0,
        help_text="Years of experience"
    )
    languages = models.JSONField(
        default=list,
        blank=True,
        help_text="List of languages spoken"
    )
    rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=0.0,
        help_text="Average rating (0.00 to 5.00)"
    )
    is_available = models.BooleanField(
        default=True,
        help_text="Whether counselor is currently available"
    )
    bio = models.TextField(
        blank=True,
        help_text="Counselor's biography"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When profile was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When profile was last updated"
    )

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Counselor Profile"
        verbose_name_plural = "Counselor Profiles"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} - Counselor"


class CounsellorTimeSlot(models.Model):
    """
    Time slots for counsellor availability throughout the week.
    """
    DAY_MONDAY = "Monday"
    DAY_TUESDAY = "Tuesday"
    DAY_WEDNESDAY = "Wednesday"
    DAY_THURSDAY = "Thursday"
    DAY_FRIDAY = "Friday"
    DAY_SATURDAY = "Saturday"
    DAY_SUNDAY = "Sunday"
    
    DAY_CHOICES = [
        (DAY_MONDAY, "Monday"),
        (DAY_TUESDAY, "Tuesday"),
        (DAY_WEDNESDAY, "Wednesday"),
        (DAY_THURSDAY, "Thursday"),
        (DAY_FRIDAY, "Friday"),
        (DAY_SATURDAY, "Saturday"),
        (DAY_SUNDAY, "Sunday"),
    ]
    
    counsellor = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='time_slots',
        limit_choices_to={"counsellorprofile__isnull": False},
        help_text="Counselor user"
    )
    day_of_week = models.CharField(
        max_length=10,
        choices=DAY_CHOICES,
        help_text="Day of the week"
    )
    start_time = models.TimeField(
        help_text="Start time of availability"
    )
    end_time = models.TimeField(
        help_text="End time of availability"
    )
    is_available = models.BooleanField(
        default=True,
        help_text="Whether slot is available"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When slot was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When slot was last updated"
    )
    
    class Meta:
        indexes = [
            models.Index(fields=["counsellor", "day_of_week"]),
            models.Index(fields=["counsellor", "is_available"]),
        ]
        verbose_name = "Counselor Time Slot"
        verbose_name_plural = "Counselor Time Slots"
    
    def __str__(self) -> str:
        username = getattr(self.counsellor, 'username', 'Unknown') if self.counsellor else 'Unknown'
        return f"{username} - {self.day_of_week} {self.start_time}-{self.end_time}"


class DoctorProfile(models.Model):
    """
    Profile for doctors with specialization and license information.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="doctorprofile",
        help_text="Associated Django User (must be a doctor)"
    )
    specialization = models.CharField(
        max_length=200,
        blank=True,
        help_text="Doctor's area of specialization"
    )
    experience_years = models.PositiveIntegerField(
        default=0,
        help_text="Years of experience"
    )
    license_number = models.CharField(
        max_length=100,
        blank=True,
        help_text="Medical license number"
    )
    languages = models.JSONField(
        default=list,
        blank=True,
        help_text="List of languages spoken"
    )
    rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=0.0,
        help_text="Average rating (0.00 to 5.00)"
    )
    is_available = models.BooleanField(
        default=True,
        help_text="Whether doctor is currently available"
    )
    bio = models.TextField(
        blank=True,
        help_text="Doctor's biography"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When profile was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When profile was last updated"
    )

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Doctor Profile"
        verbose_name_plural = "Doctor Profiles"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        return f"{username} - Doctor"

