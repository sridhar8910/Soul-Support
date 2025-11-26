"""
Main views module - re-exports all views from the views package.
This maintains backward compatibility with existing imports.
The views have been split into smaller modules to fix the "Too many lines" error.

Note: This file imports from .views (the views package, not this file).
The "Module import itself" warnings are false positives - this is a re-export pattern.
"""
# type: ignore
# pylint: disable=import-outside-toplevel,cyclic-import,unused-import,import-self
# Import all views from the views package (views/__init__.py)
from .views import (  # noqa: F401
    # Auth
    EmailOrUsernameTokenObtainPairView,
    RegisterView,
    RegistrationSendOTPView,
    RegistrationVerifyOTPView,
    TokenRefreshView,
    # User
    DashboardView,
    MoodUpdateView,
    ProfileView,
    UserSettingsView,
    # Wallet
    WalletDetailView,
    WalletRechargeView,
    WalletUsageView,
    # Wellness
    SupportGroupListView,
    WellnessJournalEntryDetailView,
    WellnessJournalEntryListCreateView,
    WellnessTaskDetailView,
    WellnessTaskListCreateView,
    # Sessions
    QuickSessionView,
    SessionDurationView,
    SessionEndView,
    SessionStartView,
    SessionSummaryView,
    SessionUpdateView,
    UpcomingSessionDetailView,
    UpcomingSessionListCreateView,
    # Content
    MeditationSessionListView,
    MindCareBoosterListView,
    MusicTrackListView,
    ProfessionalGuidanceListView,
    ReportsAnalyticsView,
    # Legacy
    LegacyAdvancedCareSupportView,
    LegacyAffirmationsView,
    LegacyAssessmentView,
    LegacyBreathingView,
    LegacyExpertConnectView,
    LegacyFeatureDetailView,
    LegacyGuidelinesView,
    # Counsellor
    CounsellorAppointmentsView,
    CounsellorProfileView,
    CounsellorStatsView,
    # Chat
    ChatAcceptView,
    ChatCreateView,
    ChatListView,
    ChatMessageListView,
    QueuedChatsView,
)
