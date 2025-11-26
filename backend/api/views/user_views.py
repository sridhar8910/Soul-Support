"""User profile and settings views."""
import logging
from datetime import datetime, timedelta
from typing import Any

from django.utils import timezone
import pytz
from rest_framework import generics, permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import MoodLog, UserProfile
from ..serializers import MoodUpdateSerializer, UserProfileSerializer, UserSettingsSerializer

logger = logging.getLogger(__name__)


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        profile, _created = UserProfile.objects.get_or_create(user=self.request.user)
        return profile


class UserSettingsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserSettingsSerializer(profile)
        return Response(serializer.data)

    def put(self, request: Request) -> Response:
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserSettingsSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class DashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile_data = UserProfileSerializer(profile).data

        data = {
            "profile": profile_data | {"display_name": request.user.username.title()},
            "wallet": {"minutes": profile.wallet_minutes},
            "mood": {
                "value": profile.last_mood,
                "updated_at": profile.last_mood_updated,
            },
            "upcoming": {
                "title": "Upcoming",
                "description": "No sessions scheduled",
            },
            "quick_actions": [
                {"title": "Schedule Session", "icon": "calendar_today"},
                {"title": "Mental Health", "icon": "psychology"},
                {"title": "Expert Connect", "icon": "person_outline"},
                {"title": "Meditation", "icon": "self_improvement"},
            ],
        }
        return Response(data)


class MoodUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request) -> Response:
        serializer = MoodUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        incoming_tz: str | None = serializer.validated_data.get("timezone")
        tzinfo = timezone.get_current_timezone()
        tz_source = incoming_tz or profile.timezone
        resolved_tz_name = getattr(tzinfo, "zone", str(tzinfo))
        if tz_source:
            try:
                # Normalize timezone format (handle UTC+00:00, UTC, etc.)
                normalized_tz = tz_source.strip().upper()
                # Convert UTC+00:00 format to UTC
                if normalized_tz.startswith('UTC+') or normalized_tz.startswith('UTC-'):
                    # Extract offset and convert to UTC
                    if normalized_tz == 'UTC+00:00' or normalized_tz == 'UTC-00:00' or normalized_tz == 'UTC+0' or normalized_tz == 'UTC-0':
                        normalized_tz = 'UTC'
                    else:
                        # For other offsets, try to parse or default to UTC
                        normalized_tz = 'UTC'
                tzinfo = pytz.timezone(normalized_tz)
                resolved_tz_name = getattr(tzinfo, "zone", normalized_tz)
            except (pytz.UnknownTimeZoneError, AttributeError):
                # Silently use default timezone instead of warning
                tzinfo = timezone.get_current_timezone()
                resolved_tz_name = getattr(tzinfo, "zone", "UTC")
        timezone_updated = False
        if incoming_tz and resolved_tz_name != profile.timezone:
            profile.timezone = resolved_tz_name
            timezone_updated = True

        now_utc = timezone.now()
        local_now = now_utc.astimezone(tzinfo)
        local_date = local_now.date()

        if profile.mood_updates_date != local_date:
            profile.mood_updates_date = local_date
            profile.mood_updates_count = 0

        if profile.mood_updates_count >= 3:
            next_reset_naive = datetime.combine(local_date + timedelta(days=1), datetime.min.time())
            next_reset = timezone.make_aware(next_reset_naive, tzinfo)
            return Response(
                {
                    "status": "limit_reached",
                    "detail": "You can update your mood only 3 times per day.",
                    "reset_at_local": next_reset.isoformat(),
                    "timezone": tzinfo.zone if hasattr(tzinfo, "zone") else str(tzinfo),
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        profile.last_mood = serializer.validated_data["value"]
        profile.last_mood_updated = now_utc
        profile.mood_updates_count += 1
        profile.mood_updates_date = local_date
        update_fields = [
            "last_mood",
            "last_mood_updated",
            "mood_updates_count",
            "mood_updates_date",
        ]
        if timezone_updated:
            update_fields.append("timezone")
        profile.save(update_fields=update_fields)
        MoodLog.objects.create(user=request.user, value=profile.last_mood)
        return Response(
            {
                "status": "ok",
                "mood": profile.last_mood,
                "updated_at": profile.last_mood_updated,
                "updates_used": profile.mood_updates_count,
                "updates_remaining": max(0, 3 - profile.mood_updates_count),
            }
        )

