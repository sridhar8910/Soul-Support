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

class SupportGroup(models.Model):
    """Support groups for users."""
    slug = models.SlugField(
        max_length=80,
        unique=True,
        help_text="Unique URL-friendly identifier"
    )
    name = models.CharField(
        max_length=160,
        help_text="Group name"
    )
    description = models.TextField(
        blank=True,
        help_text="Group description"
    )
    icon = models.CharField(
        max_length=64,
        blank=True,
        help_text="Icon identifier"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When group was created"
    )

    class Meta:
        ordering = ("name",)
        verbose_name = "Support Group"
        verbose_name_plural = "Support Groups"

    def __str__(self) -> str:
        return str(self.name) if self.name else "Unnamed Support Group"


class SupportGroupMembership(models.Model):
    """Membership relationship between users and support groups."""
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="support_group_memberships",
        help_text="User who is a member"
    )
    group = models.ForeignKey(
        SupportGroup,
        on_delete=models.CASCADE,
        related_name="memberships",
        help_text="Support group"
    )
    joined_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When user joined the group"
    )

    class Meta:
        unique_together = ("user", "group")
        ordering = ("-joined_at",)
        verbose_name = "Support Group Membership"
        verbose_name_plural = "Support Group Memberships"

    def __str__(self) -> str:
        username = getattr(self.user, 'username', 'Unknown') if self.user else 'Unknown'
        group_slug = getattr(self.group, 'slug', 'unknown') if self.group else 'unknown'
        return f"{username} -> {group_slug}"


