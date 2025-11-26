"""
Views package - re-exports all views for backward compatibility.
This allows existing imports to continue working.
"""
from .auth_views import (
    EmailOrUsernameTokenObtainPairView,
    RegisterView,
    RegistrationSendOTPView,
    RegistrationVerifyOTPView,
    TokenRefreshView,
)
from .chat_views import (
    ChatAcceptView,
    ChatCreateView,
    ChatListView,
    ChatMessageListView,
    QueuedChatsView,
)
from .content_views import (
    MeditationSessionListView,
    MindCareBoosterListView,
    MusicTrackListView,
    ProfessionalGuidanceListView,
    ReportsAnalyticsView,
)
from .counsellor_views import (
    CounsellorAppointmentsView,
    CounsellorProfileView,
    CounsellorStatsView,
)
from .legacy_views import (
    LegacyAdvancedCareSupportView,
    LegacyAffirmationsView,
    LegacyAssessmentView,
    LegacyBreathingView,
    LegacyExpertConnectView,
    LegacyFeatureDetailView,
    LegacyGuidelinesView,
)
from .session_views import (
    QuickSessionView,
    SessionDurationView,
    SessionEndView,
    SessionStartView,
    SessionSummaryView,
    SessionUpdateView,
    UpcomingSessionDetailView,
    UpcomingSessionListCreateView,
)
from .user_views import (
    DashboardView,
    MoodUpdateView,
    ProfileView,
    UserSettingsView,
)
from .wallet_views import (
    WalletDetailView,
    WalletRechargeView,
    WalletUsageView,
)
from .wellness_views import (
    SupportGroupListView,
    WellnessJournalEntryDetailView,
    WellnessJournalEntryListCreateView,
    WellnessTaskDetailView,
    WellnessTaskListCreateView,
)

__all__ = [
    # Auth
    "RegisterView",
    "RegistrationSendOTPView",
    "RegistrationVerifyOTPView",
    "EmailOrUsernameTokenObtainPairView",
    "TokenRefreshView",
    # User
    "ProfileView",
    "UserSettingsView",
    "DashboardView",
    "MoodUpdateView",
    # Wallet
    "WalletRechargeView",
    "WalletDetailView",
    "WalletUsageView",
    # Wellness
    "WellnessTaskListCreateView",
    "WellnessTaskDetailView",
    "WellnessJournalEntryListCreateView",
    "WellnessJournalEntryDetailView",
    "SupportGroupListView",
    # Sessions
    "UpcomingSessionListCreateView",
    "UpcomingSessionDetailView",
    "SessionStartView",
    "SessionEndView",
    "SessionDurationView",
    "SessionUpdateView",
    "SessionSummaryView",
    "QuickSessionView",
    # Content
    "ReportsAnalyticsView",
    "ProfessionalGuidanceListView",
    "MusicTrackListView",
    "MindCareBoosterListView",
    "MeditationSessionListView",
    # Legacy
    "LegacyGuidelinesView",
    "LegacyExpertConnectView",
    "LegacyBreathingView",
    "LegacyAssessmentView",
    "LegacyAffirmationsView",
    "LegacyAdvancedCareSupportView",
    "LegacyFeatureDetailView",
    # Counsellor
    "CounsellorProfileView",
    "CounsellorAppointmentsView",
    "CounsellorStatsView",
    # Chat
    "ChatCreateView",
    "ChatListView",
    "QueuedChatsView",
    "ChatAcceptView",
    "ChatMessageListView",
]

