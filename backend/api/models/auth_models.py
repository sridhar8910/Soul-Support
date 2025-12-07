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

class EmailOTP(models.Model):
    """Email OTP for registration and password reset."""
    PURPOSE_REGISTRATION = "registration"
    PURPOSE_PASSWORD_RESET = "password_reset"
    
    PURPOSE_CHOICES = [
        (PURPOSE_REGISTRATION, "Registration"),
        (PURPOSE_PASSWORD_RESET, "Password reset"),
    ]

    email = models.EmailField(
        help_text="Email address"
    )
    code = models.CharField(
        max_length=6,
        help_text="OTP code"
    )
    purpose = models.CharField(
        max_length=32,
        choices=PURPOSE_CHOICES,
        help_text="OTP purpose"
    )
    token = models.CharField(
        max_length=64,
        unique=True,
        help_text="Unique verification token"
    )
    is_verified = models.BooleanField(
        default=False,
        help_text="Whether OTP is verified"
    )
    attempts = models.PositiveSmallIntegerField(
        default=0,
        help_text="Number of verification attempts"
    )
    expires_at = models.DateTimeField(
        help_text="When OTP expires"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When OTP was created"
    )
    verified_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When OTP was verified"
    )

    class Meta:
        indexes = [
            models.Index(fields=["email", "purpose", "is_verified"]),
            models.Index(fields=["token"]),
        ]
        ordering = ("-created_at",)
        verbose_name = "Email OTP"
        verbose_name_plural = "Email OTPs"

    def __str__(self) -> str:
        return f"{self.email} -> {self.purpose}"

    @property
    def is_expired(self) -> bool:
        """Check if OTP is expired."""
        return timezone.now() >= self.expires_at

    def mark_verified(self) -> None:
        """Mark OTP as verified and set verified_at timestamp."""
        self.is_verified = True
        self.verified_at = timezone.now()
        self.save(update_fields=["is_verified", "verified_at"])


