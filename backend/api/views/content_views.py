"""Content-related views (reports, guidance, music, meditation)."""
from collections import defaultdict
from typing import Any

from django.db.models import Avg, Count
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import permissions
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import (
    GuidanceResource,
    MeditationSession,
    MindCareBooster,
    MoodLog,
    MusicTrack,
    UpcomingSession,
    UserProfile,
    WellnessTask,
)
from ..serializers import (
    GuidanceResourceSerializer,
    MeditationSessionSerializer,
    MindCareBoosterSerializer,
    MusicTrackSerializer,
)


class ReportsAnalyticsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        user = request.user
        now = timezone.now()
        seven_days_ago = now - timezone.timedelta(days=6)
        thirty_days_ago = now - timezone.timedelta(days=29)

        weekly_logs = (
            MoodLog.objects.filter(user=user, recorded_at__date__gte=seven_days_ago.date())
            .annotate(day=TruncDate("recorded_at"))
            .values("day")
            .annotate(average=Avg("value"), count=Count("id"))
            .order_by("day")
        )
        monthly_logs = (
            MoodLog.objects.filter(user=user, recorded_at__date__gte=thirty_days_ago.date())
            .annotate(day=TruncDate("recorded_at"))
            .values("day")
            .annotate(average=Avg("value"), count=Count("id"))
            .order_by("day")
        )

        weekly_data = [
            {"date": entry["day"].isoformat(), "average": round(entry["average"], 2), "count": entry["count"]}
            for entry in weekly_logs
        ]
        monthly_data = [
            {"date": entry["day"].isoformat(), "average": round(entry["average"], 2), "count": entry["count"]}
            for entry in monthly_logs
        ]

        tasks_qs = WellnessTask.objects.filter(user=user)
        tasks_total = tasks_qs.count()
        tasks_completed = tasks_qs.filter(is_completed=True).count()
        tasks_daily = tasks_qs.filter(category=WellnessTask.CATEGORY_DAILY).count()
        tasks_evening = tasks_qs.filter(category=WellnessTask.CATEGORY_EVENING).count()
        completion_rate = (tasks_completed / tasks_total) if tasks_total else 0

        top_tasks = list(
            tasks_qs.values("title")
            .annotate(total=Count("id"))
            .order_by("-total", "title")[:5]
        )

        sessions_qs = UpcomingSession.objects.filter(user=user)
        total_sessions = sessions_qs.count()
        upcoming_sessions = sessions_qs.filter(start_time__gte=now).count()
        past_sessions = total_sessions - upcoming_sessions

        profile, _ = UserProfile.objects.get_or_create(user=user)

        if completion_rate >= 0.7 and weekly_data:
            insight = "Fantastic consistency! You're completing most of your planned tasks."
        elif upcoming_sessions == 0 and total_sessions > 0:
            insight = "You have no upcoming sessions. Consider booking a follow-up to stay on track."
        elif profile.last_mood <= 2:
            insight = "Your recent mood updates seem low. Try a relaxation activity or journaling."
        else:
            insight = "Great work staying engaged with your wellness plan. Keep the momentum going!"

        return Response(
            {
                "mood": {
                    "weekly": weekly_data,
                    "monthly": monthly_data,
                },
                "tasks": {
                    "total": tasks_total,
                    "completed": tasks_completed,
                    "completion_rate": round(completion_rate, 2),
                    "by_category": {
                        "daily": tasks_daily,
                        "evening": tasks_evening,
                    },
                    "top_tasks": top_tasks,
                },
                "sessions": {
                    "total": total_sessions,
                    "upcoming": upcoming_sessions,
                    "completed": past_sessions if past_sessions > 0 else 0,
                },
                "wallet": {"minutes": profile.wallet_minutes},
                "insight": insight,
            }
        )


class ProfessionalGuidanceListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        resource_type = request.query_params.get("type")
        category = request.query_params.get("category")
        featured = request.query_params.get("featured")

        queryset = GuidanceResource.objects.all()
        if resource_type:
            queryset = queryset.filter(resource_type=resource_type)
        if category:
            queryset = queryset.filter(category__iexact=category)
        if featured:
            queryset = queryset.filter(is_featured=True)

        serializer = GuidanceResourceSerializer(queryset, many=True)
        categories = (
            GuidanceResource.objects.exclude(category="")
            .order_by("category")
            .values_list("category", flat=True)
            .distinct()
        )
        return Response(
            {
                "resources": serializer.data,
                "categories": list(categories),
            }
        )


class MusicTrackListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        mood = request.query_params.get("mood")
        queryset = MusicTrack.objects.all()
        if mood:
            queryset = queryset.filter(mood=mood)

        serializer = MusicTrackSerializer(queryset, many=True)
        moods = (
            MusicTrack.objects.order_by("mood")
            .values_list("mood", flat=True)
            .distinct()
        )
        return Response(
            {
                "tracks": serializer.data,
                "moods": list(moods),
                "count": queryset.count(),
            }
        )


class MindCareBoosterListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        category = request.query_params.get("category")
        queryset = MindCareBooster.objects.all()
        if category:
            queryset = queryset.filter(category=category)

        serializer = MindCareBoosterSerializer(queryset, many=True)
        grouped: dict[str, list[dict]] = defaultdict(list)
        for item in serializer.data:
            grouped[item["category"]].append(item)

        categories = (
            MindCareBooster.objects.order_by("category")
            .values_list("category", flat=True)
            .distinct()
        )
        grouped_dict = {key: value for key, value in grouped.items()}
        return Response(
            {
                "boosters": serializer.data,
                "categories": list(categories),
                "grouped": grouped_dict,
            }
        )


class MeditationSessionListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        category = request.query_params.get("category")
        difficulty = request.query_params.get("difficulty")
        featured = request.query_params.get("featured")

        queryset = MeditationSession.objects.all()
        if category:
            queryset = queryset.filter(category__iexact=category)
        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)
        if featured:
            queryset = queryset.filter(is_featured=True)

        serializer = MeditationSessionSerializer(queryset, many=True)
        grouped: dict[str, list[dict]] = defaultdict(list)
        featured_items = []
        for item in serializer.data:
            grouped[item["category"]].append(item)
            if item["is_featured"]:
                featured_items.append(item)

        categories = (
            MeditationSession.objects.order_by("category")
            .values_list("category", flat=True)
            .distinct()
        )
        grouped_dict = {key: value for key, value in grouped.items()}
        return Response(
            {
                "sessions": serializer.data,
                "categories": list(categories),
                "grouped": grouped_dict,
                "featured": featured_items,
            }
        )

