import logging
import secrets
from collections import defaultdict
from datetime import datetime, timedelta

from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.db import transaction
from django.db.models import Avg, Count, Max
from django.db.models.functions import TruncDate
from django.shortcuts import get_object_or_404
from django.utils import timezone
import pytz
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    Chat,
    CounsellorProfile,
    DoctorProfile,
    EmailOTP,
    GuidanceResource,
    MeditationSession,
    MindCareBooster,
    MoodLog,
    MusicTrack,
    SupportGroup,
    SupportGroupMembership,
    UpcomingSession,
    UserProfile,
    WellnessJournalEntry,
    WellnessTask,
)
from .serializers import (
    ChatCreateSerializer,
    ChatSerializer,
    CounsellorAppointmentSerializer,
    CounsellorProfileSerializer,
    CounsellorStatsSerializer,
    GuidanceResourceSerializer,
    MeditationSessionSerializer,
    MindCareBoosterSerializer,
    MoodUpdateSerializer,
    MusicTrackSerializer,
    QuickSessionSerializer,
    RegisterSerializer,
    SendOTPSerializer,
    SupportGroupJoinSerializer,
    SupportGroupSerializer,
    UpcomingSessionSerializer,
    UserProfileSerializer,
    UserSettingsSerializer,
    VerifyOTPSerializer,
    WalletRechargeSerializer,
    WalletUsageSerializer,
    WellnessJournalEntrySerializer,
    WellnessTaskSerializer,
)
from .serializers import EmailOrUsernameTokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView


logger = logging.getLogger(__name__)

CALL_RATE_PER_MINUTE = 5
CHAT_RATE_PER_MINUTE = 1
MIN_CALL_BALANCE = 100
MIN_CHAT_BALANCE = 50
SERVICE_RATE_MAP = {
    "call": CALL_RATE_PER_MINUTE,
    "chat": CHAT_RATE_PER_MINUTE,
}
SERVICE_MIN_BALANCE_MAP = {
    "call": MIN_CALL_BALANCE,
    "chat": MIN_CHAT_BALANCE,
}


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        profile, _created = UserProfile.objects.get_or_create(user=self.request.user)
        return profile


class UserSettingsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserSettingsSerializer(profile)
        return Response(serializer.data)

    def put(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserSettingsSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class DashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
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

    def post(self, request):
        serializer = MoodUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        incoming_tz: str | None = serializer.validated_data.get("timezone")
        tzinfo = timezone.get_current_timezone()
        tz_source = incoming_tz or profile.timezone
        resolved_tz_name = getattr(tzinfo, "zone", str(tzinfo))
        if tz_source:
            try:
                tzinfo = pytz.timezone(tz_source)
                resolved_tz_name = getattr(tzinfo, "zone", tz_source)
            except pytz.UnknownTimeZoneError:
                logger.warning("Unknown timezone %s supplied for mood update", tz_source)
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


# Legacy content payloads -------------------------------------------------

LEGACY_GUIDELINES = [
    {
        "title": "Respect & Confidentiality",
        "bullets": [
            "Treat all members with dignity and respect.",
            "Never share personal information without consent.",
            "Maintain strict confidentiality of others’ stories.",
            "What is shared in the community stays in the community.",
        ],
    },
    {
        "title": "Responsible Communication",
        "bullets": [
            "Use kind and supportive language.",
            "Avoid judgment, criticism, or dismissive comments.",
            "Listen actively and empathetically.",
            "Share personal experiences, not medical advice.",
        ],
    },
    {
        "title": "Content Standards",
        "bullets": [
            "No hate speech, discrimination, or harassment.",
            "No self-harm, suicide, or crisis content.",
            "No spam, advertisements, or commercial promotion.",
            "No illegal content or activities.",
        ],
    },
    {
        "title": "Crisis Support",
        "bullets": [
            "If experiencing a crisis, contact emergency services.",
            "Call our 24/7 crisis hotline for immediate help.",
            "Book an urgent counselling session.",
            "Crisis support is not a replacement for professional help.",
        ],
    },
    {
        "title": "Privacy & Data Protection",
        "bullets": [
            "Your data is encrypted and protected.",
            "We never sell or share personal information.",
            "You can request data deletion anytime.",
            "Anonymous usage options are available.",
        ],
    },
]

LEGACY_COUNSELLORS = [
    {
        "name": "Dr. Aisha Khan",
        "expertise": ["Stress", "Anxiety"],
        "rating": 4.8,
        "languages": ["English", "Hindi"],
        "tagline": "Helping you find calm and clarity.",
        "is_available_now": True,
    },
    {
        "name": "Rahul Mehta",
        "expertise": ["Career", "Relationship"],
        "rating": 4.5,
        "languages": ["English", "Hindi"],
        "tagline": "Guiding you through life’s big decisions.",
        "is_available_now": False,
    },
    {
        "name": "Sofia Fernandez",
        "expertise": ["Depression", "Stress"],
        "rating": 4.9,
        "languages": ["English"],
        "tagline": "Compassionate support for brighter days.",
        "is_available_now": True,
    },
]

LEGACY_ASSESSMENT_QUESTIONS = [
    {
        "question": "How have you been feeling lately?",
        "options": ["Very low", "Low", "Neutral", "Positive", "Very positive"],
    },
    {
        "question": "How is your sleep quality?",
        "options": ["Poor", "Fair", "Average", "Good", "Excellent"],
    },
    {
        "question": "How often do you feel anxious?",
        "options": ["Rarely", "Sometimes", "Often", "Very often", "Always"],
    },
]

LEGACY_ADVANCED_SERVICES = [
    {
        "title": "Professional Counseling",
        "description": "Connect with licensed therapists and counselors for personalized support.",
        "benefits": [
            "One-on-one sessions",
            "Personalized treatment plans",
            "Confidential support",
            "Flexible scheduling",
        ],
    },
    {
        "title": "Psychiatric Consultation",
        "description": "Expert psychiatric evaluation and medication management when needed.",
        "benefits": [
            "Clinical assessment",
            "Medication guidance",
            "Crisis intervention",
            "Treatment planning",
        ],
    },
    {
        "title": "Family Therapy",
        "description": "Strengthen relationships and improve communication with family members.",
        "benefits": [
            "Family sessions",
            "Conflict resolution",
            "Communication skills",
            "Support networks",
        ],
    },
]

LEGACY_ADVANCED_SPECIALISTS = [
    {
        "name": "Dr. Sarah Johnson",
        "specialization": "Clinical Psychology",
        "experience_years": 15,
    },
    {
        "name": "Dr. Rajesh Patel",
        "specialization": "Psychiatry",
        "experience_years": 12,
    },
    {
        "name": "Emma Wilson",
        "specialization": "Family Therapy",
        "experience_years": 10,
    },
]

LEGACY_FEATURE_DETAIL = {
    "title": "Legacy Feature Detail",
    "sections": [
        {
            "heading": "Overview",
            "bullets": [
                "This is the original feature detail demo page.",
                "Content is static and for presentation purposes only.",
            ],
        },
        {
            "heading": "Next steps",
            "bullets": [
                "Review how stories were structured in the prototype.",
                "Compare against the live feature implementation.",
            ],
        },
    ],
}


class LegacyGuidelinesView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response({"sections": LEGACY_GUIDELINES})


class LegacyExpertConnectView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response({"counsellors": LEGACY_COUNSELLORS})


class LegacyBreathingView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(
            {
                "cycle_options": [4, 5, 6, 8, 10],
                "tip": "For calm, try 6–8 second cycles. If you feel lightheaded stop and return to normal breathing.",
            }
        )


class LegacyAssessmentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response({"questions": LEGACY_ASSESSMENT_QUESTIONS})


class LegacyAffirmationsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(
            {
                "affirmations": [
                    "I am worthy of care and respect.",
                    "I breathe in calm and exhale tension.",
                    "I am capable of handling what comes my way.",
                    "I give myself permission to rest and heal.",
                ]
            }
        )


class LegacyAdvancedCareSupportView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(
            {
                "services": LEGACY_ADVANCED_SERVICES,
                "specialists": LEGACY_ADVANCED_SPECIALISTS,
            }
        )


class LegacyFeatureDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(LEGACY_FEATURE_DETAIL)


class WalletRechargeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = WalletRechargeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        minutes = serializer.validated_data["minutes"]
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile.wallet_minutes += minutes
        profile.save(update_fields=["wallet_minutes"])
        return Response(
            {"status": "ok", "wallet_minutes": profile.wallet_minutes},
            status=status.HTTP_200_OK,
        )


class WalletDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        return Response(
            {
                "wallet_minutes": profile.wallet_minutes,
                "rates": SERVICE_RATE_MAP,
                "minimum_balance": SERVICE_MIN_BALANCE_MAP,
            }
        )


class WalletUsageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = WalletUsageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        service = serializer.validated_data["service"]
        minutes = serializer.validated_data["minutes"]
        rate = SERVICE_RATE_MAP[service]
        charge = minutes * rate
        min_required = SERVICE_MIN_BALANCE_MAP[service]

        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        if profile.wallet_minutes < min_required:
            return Response(
                {
                    "detail": f"Minimum balance of ₹{min_required} required to start {service}.",
                    "wallet_minutes": profile.wallet_minutes,
                    "required_minimum": min_required,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        if profile.wallet_minutes < charge:
            return Response(
                {
                    "detail": "Insufficient wallet balance",
                    "wallet_minutes": profile.wallet_minutes,
                    "required": charge,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile.wallet_minutes -= charge
        profile.save(update_fields=["wallet_minutes"])
        return Response(
            {
                "status": "ok",
                "service": service,
                "minutes": minutes,
                "rate_per_minute": rate,
                "charged": charge,
                "wallet_minutes": profile.wallet_minutes,
            }
        )


DEFAULT_WELLNESS_TASKS = {
    WellnessTask.DAILY: [
        "Meditation (10 min)",
        "Drink 2L Water",
        "Gratitude Note",
    ],
    WellnessTask.EVENING: [
        "Journaling (5 min)",
        "Reflect on 3 positive things",
    ],
}


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
            WellnessTask.DAILY: [item for item in items if item["category"] == WellnessTask.DAILY],
            WellnessTask.EVENING: [item for item in items if item["category"] == WellnessTask.EVENING],
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
        category = serializer.validated_data.get("category", WellnessTask.DAILY)
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


class SupportGroupListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
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

    def post(self, request):
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


class UpcomingSessionListCreateView(generics.ListCreateAPIView):
    serializer_class = UpcomingSessionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return UpcomingSession.objects.filter(user=self.request.user).order_by("start_time", "id")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class UpcomingSessionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UpcomingSessionSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_url_kwarg = "session_id"

    def get_queryset(self):
        return UpcomingSession.objects.filter(user=self.request.user)


class QuickSessionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = QuickSessionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        session_date = serializer.validated_data["date"]
        session_time = serializer.validated_data["time"]
        start_naive = datetime.combine(session_date, session_time)
        start_at = timezone.make_aware(start_naive, timezone.get_current_timezone())

        session = UpcomingSession.objects.create(
            user=request.user,
            title=serializer.validated_data.get("title") or "Counselling Session",
            session_type="one_on_one",
            start_time=start_at,
            counsellor_name="Assigned Counsellor",
            notes=serializer.validated_data.get("notes", ""),
            is_confirmed=False,
        )
        return Response(
            {
                "status": "scheduled",
                "session": UpcomingSessionSerializer(session).data,
            },
            status=status.HTTP_201_CREATED,
        )


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


class RegistrationSendOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"]

        with transaction.atomic():
            EmailOTP.objects.filter(email=email, purpose=EmailOTP.PURPOSE_REGISTRATION).delete()
            code = f"{secrets.randbelow(1_000_000):06d}"
            token = secrets.token_urlsafe(32)
            otp = EmailOTP.objects.create(
                email=email,
                code=code,
                purpose=EmailOTP.PURPOSE_REGISTRATION,
                token=token,
                expires_at=timezone.now() + timezone.timedelta(minutes=10),
            )

        logger.info("Registration OTP for %s is %s", email, code)
        print(f"[OTP] Registration code for {email}: {code}")

        send_mail(
            subject="Your Soul Support verification code",
            message=f"Use this code to finish your sign up: {otp.code}. It expires in 10 minutes.",
            from_email=None,
            recipient_list=[email],
            fail_silently=False,
        )

        return Response({"status": "sent"})


class RegistrationVerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        otp: EmailOTP = serializer.validated_data["otp"]
        otp.mark_verified()
        return Response({"status": "verified", "token": otp.token})


class EmailOrUsernameTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailOrUsernameTokenObtainPairSerializer

    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        
        if response.status_code == 200:
            # Get user from serializer
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=False)
            user = serializer.user
            
            # Determine user role
            role = 'user'
            if hasattr(user, 'counsellorprofile'):
                role = 'counsellor'
            elif hasattr(user, 'doctorprofile'):
                role = 'doctor'
            elif user.is_superuser:
                role = 'admin'
            
            # Add role to response
            data = response.data
            data['role'] = role
            data['user_id'] = user.id
            data['username'] = user.username
            
            return Response(data)
        return response


class ReportsAnalyticsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
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
        tasks_daily = tasks_qs.filter(category=WellnessTask.DAILY).count()
        tasks_evening = tasks_qs.filter(category=WellnessTask.EVENING).count()
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

    def get(self, request):
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

    def get(self, request):
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

    def get(self, request):
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

    def get(self, request):
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


class CounsellorProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = CounsellorProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        if not hasattr(self.request.user, 'counsellorprofile'):
            raise generics.NotFound("Counsellor profile not found")
        return self.request.user.counsellorprofile


class CounsellorAppointmentsView(generics.ListAPIView):
    serializer_class = CounsellorAppointmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'counsellorprofile'):
            return UpcomingSession.objects.none()
        
        # Get all sessions where counsellor_name matches this counselor
        counsellor_name = self.request.user.counsellorprofile.user.get_full_name() or self.request.user.username
        
        queryset = UpcomingSession.objects.filter(
            counsellor_name__icontains=counsellor_name
        ).order_by('start_time')
        
        # Filter by status if provided
        status = self.request.query_params.get('status', None)
        now = timezone.now()
        if status == 'upcoming':
            queryset = queryset.filter(start_time__gt=now)
        elif status == 'completed':
            queryset = queryset.filter(start_time__lt=now)
        elif status == 'today':
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            today_end = today_start + timedelta(days=1)
            queryset = queryset.filter(start_time__gte=today_start, start_time__lt=today_end)
        
        return queryset


class CounsellorStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if not hasattr(request.user, 'counsellorprofile'):
            return Response(
                {"error": "Counsellor profile not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        counsellor_name = request.user.counsellorprofile.user.get_full_name() or request.user.username
        now = timezone.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        # Get all sessions for this counselor
        all_sessions = UpcomingSession.objects.filter(
            counsellor_name__icontains=counsellor_name
        )
        
        total_sessions = all_sessions.count()
        today_sessions = all_sessions.filter(
            start_time__gte=today_start,
            start_time__lt=today_start + timedelta(days=1)
        ).count()
        upcoming_sessions = all_sessions.filter(start_time__gt=now).count()
        completed_sessions = all_sessions.filter(start_time__lt=now).count()
        
        # Get unique clients
        total_clients = all_sessions.values('user').distinct().count()
        
        # Get counselor profile for rating
        profile = request.user.counsellorprofile
        average_rating = float(profile.rating)
        
        # Calculate earnings (simplified - 100 per session)
        session_rate = 100
        monthly_earnings = all_sessions.filter(
            start_time__gte=month_start,
            start_time__lt=now
        ).count() * session_rate
        total_earnings = completed_sessions * session_rate
        
        # Get queued chats count
        queued_chats = Chat.objects.filter(
            status="queued",
            counsellor__isnull=True
        ).count()
        
        stats = {
            "total_sessions": total_sessions,
            "today_sessions": today_sessions,
            "upcoming_sessions": upcoming_sessions,
            "completed_sessions": completed_sessions,
            "average_rating": average_rating,
            "total_clients": total_clients,
            "monthly_earnings": monthly_earnings,
            "total_earnings": total_earnings,
            "queued_chats": queued_chats,
        }
        
        serializer = CounsellorStatsSerializer(stats)
        return Response(serializer.data)


class ChatCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ChatCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        chat = Chat.objects.create(
            user=request.user,
            status="queued",
            initial_message=serializer.validated_data.get("initial_message", ""),
        )

        return Response(
            ChatSerializer(chat).data,
            status=status.HTTP_201_CREATED,
        )


class ChatListView(generics.ListAPIView):
    serializer_class = ChatSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Chat.objects.filter(user=self.request.user).order_by("-created_at")


class QueuedChatsView(generics.ListAPIView):
    serializer_class = ChatSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if not hasattr(self.request.user, 'counsellorprofile'):
            return Chat.objects.none()
        
        return Chat.objects.filter(
            status="queued",
            counsellor__isnull=True
        ).order_by("created_at")


class ChatAcceptView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, chat_id):
        if not hasattr(request.user, 'counsellorprofile'):
            return Response(
                {"error": "Only counsellors can accept chats"},
                status=status.HTTP_403_FORBIDDEN
            )

        try:
            chat = Chat.objects.get(id=chat_id, status="queued")
        except Chat.DoesNotExist:
            return Response(
                {"error": "Chat not found or not available"},
                status=status.HTTP_404_NOT_FOUND
            )

        chat.counsellor = request.user
        chat.status = "active"
        chat.started_at = timezone.now()
        chat.save()

        return Response(ChatSerializer(chat).data)
