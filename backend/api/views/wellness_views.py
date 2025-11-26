"""Wellness-related views (tasks, journals, support groups)."""
from typing import Any

from django.db.models import Max
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import SupportGroup, SupportGroupMembership, WellnessJournalEntry, WellnessTask
from ..serializers import (
    SupportGroupJoinSerializer,
    SupportGroupSerializer,
    WellnessJournalEntrySerializer,
    WellnessTaskSerializer,
)

DEFAULT_WELLNESS_TASKS = {
    WellnessTask.CATEGORY_DAILY: [
        "Meditation (10 min)",
        "Drink 2L Water",
        "Gratitude Note",
    ],
    WellnessTask.CATEGORY_EVENING: [
        "Journaling (5 min)",
        "Reflect on 3 positive things",
    ],
}

DEFAULT_SUPPORT_GROUPS = [
    {
        "slug": "anxiety-support",
        "name": "Anxiety Support",
        "description": "Discuss and manage anxiety together.",
        "icon": "people_alt_rounded",
    },
    {
        "slug": "career-stress",
        "name": "Career Stress",
        "description": "Talk about workplace pressure and burnout.",
        "icon": "work_outline_rounded",
    },
    {
        "slug": "relationships",
        "name": "Relationships",
        "description": "Express emotions and build healthy connections.",
        "icon": "favorite_outline_rounded",
    },
    {
        "slug": "general-awareness",
        "name": "General Awareness",
        "description": "Learn self-care and mental health awareness.",
        "icon": "self_improvement_rounded",
    },
]


class WellnessTaskListCreateView(generics.ListCreateAPIView):
    serializer_class = WellnessTaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            WellnessTask.objects.filter(user=self.request.user)
            .order_by("category", "order", "id")
            .all()
        )

    def list(self, request, *args, **kwargs):
        self._ensure_default_tasks(request.user)
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        items = list(serializer.data)
        grouped = {
            WellnessTask.CATEGORY_DAILY: [item for item in items if item["category"] == WellnessTask.CATEGORY_DAILY],
            WellnessTask.CATEGORY_EVENING: [item for item in items if item["category"] == WellnessTask.CATEGORY_EVENING],
        }
        total = len(items)
        completed = sum(1 for item in items if item["is_completed"])
        return Response(
            {
                "tasks": items,
                "grouped": grouped,
                "summary": {
                    "total": total,
                    "completed": completed,
                },
            }
        )

    def perform_create(self, serializer):
        category = serializer.validated_data.get("category", WellnessTask.CATEGORY_DAILY)
        next_order = (
            WellnessTask.objects.filter(user=self.request.user, category=category).aggregate(Max("order"))[
                "order__max"
            ]
            or 0
        )
        serializer.save(user=self.request.user, order=next_order + 1)

    def _ensure_default_tasks(self, user):
        if WellnessTask.objects.filter(user=user).exists():
            return
        to_create = []
        for category, titles in DEFAULT_WELLNESS_TASKS.items():
            for index, title in enumerate(titles, start=1):
                to_create.append(
                    WellnessTask(
                        user=user,
                        title=title,
                        category=category,
                        order=index,
                    )
                )
        WellnessTask.objects.bulk_create(to_create)


class WellnessTaskDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = WellnessTaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_url_kwarg = "task_id"

    def get_queryset(self):
        return WellnessTask.objects.filter(user=self.request.user)


class SupportGroupListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        self._ensure_default_groups()
        queryset = SupportGroup.objects.all()
        serializer = SupportGroupSerializer(
            queryset,
            many=True,
            context={"request": request},
        )
        joined_count = SupportGroupMembership.objects.filter(user=request.user).count()
        return Response(
            {
                "groups": serializer.data,
                "joined_count": joined_count,
            }
        )

    def post(self, request: Request) -> Response:
        serializer = SupportGroupJoinSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        slug = serializer.validated_data["slug"]
        action = serializer.validated_data["action"]
        group = get_object_or_404(SupportGroup, slug=slug)

        if action == "join":
            SupportGroupMembership.objects.get_or_create(user=request.user, group=group)
        else:
            SupportGroupMembership.objects.filter(user=request.user, group=group).delete()

        updated = SupportGroupSerializer(group, context={"request": request}).data
        return Response({"status": "ok", "group": updated})

    def _ensure_default_groups(self):
        existing_slugs = set(SupportGroup.objects.values_list("slug", flat=True))
        to_create = []
        for item in DEFAULT_SUPPORT_GROUPS:
            if item["slug"] in existing_slugs:
                continue
            to_create.append(
                SupportGroup(
                    slug=item["slug"],
                    name=item["name"],
                    description=item["description"],
                    icon=item["icon"],
                )
            )
        if to_create:
            SupportGroup.objects.bulk_create(to_create)


class WellnessJournalEntryListCreateView(generics.ListCreateAPIView):
    serializer_class = WellnessJournalEntrySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return WellnessJournalEntry.objects.filter(user=self.request.user).order_by("-created_at", "-id")

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return Response({"entries": serializer.data})

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class WellnessJournalEntryDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = WellnessJournalEntrySerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_url_kwarg = "entry_id"

    def get_queryset(self):
        return WellnessJournalEntry.objects.filter(user=self.request.user)

