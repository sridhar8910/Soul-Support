"""
Views package - re-exports all views for backward compatibility.
This allows existing imports to continue working.
"""
from .auth_views import (
    EmailOrUsernameTokenObtainPairView,
    PasswordResetSendOTPView,
    PasswordResetVerifyOTPView,
    PasswordResetView,
    RegisterView,
    RegistrationSendOTPView,
    RegistrationVerifyOTPView,
    TokenRefreshView,
)
from .chat_views import (
    ChatAcceptView,
    ChatCreateView,
    ChatFilteredListView,
    ChatListView,
    ChatMessageListView,
    ChatTranscriptView,
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
    SessionHistoryView,
    SessionRatingCreateView,
    SessionRatingDetailView,
    SessionRatingListView,
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
    MyJournalDetailView,
    MyJournalListCreateView,
    SupportGroupListView,
    WellnessJournalEntryDetailView,
    WellnessJournalEntryListCreateView,
    WellnessTaskDetailView,
    WellnessTaskListCreateView,
)
from .mood_views import (
    MoodAnalyticsView,
    MoodHistoryView,
)
from .assessment_views import (
    AssessmentDetailView,
    AssessmentListView,
    AssessmentResultDetailView,
    AssessmentResultsListView,
    AssessmentSubmitView,
)

__all__ = [
    # Auth
    "RegisterView",
    "RegistrationSendOTPView",
    "RegistrationVerifyOTPView",
    "PasswordResetSendOTPView",
    "PasswordResetVerifyOTPView",
    "PasswordResetView",
    "RegistrationVerifyOTPView",
    "EmailOrUsernameTokenObtainPairView",
    "TokenRefreshView",
    # User
    "ProfileView",
    "UserSettingsView",
    "DashboardView",
    "MoodUpdateView",
    "MoodHistoryView",
    "MoodAnalyticsView",
    # Wallet
    "WalletRechargeView",
    "WalletDetailView",
    "WalletUsageView",
    # Wellness
    "WellnessTaskListCreateView",
    "WellnessTaskDetailView",
    "WellnessJournalEntryListCreateView",
    "WellnessJournalEntryDetailView",
    "MyJournalListCreateView",
    "MyJournalDetailView",
    "SupportGroupListView",
    # Sessions
    "UpcomingSessionListCreateView",
    "UpcomingSessionDetailView",
    "SessionStartView",
    "SessionEndView",
    "SessionDurationView",
    "SessionUpdateView",
    "SessionSummaryView",
    "SessionHistoryView",
    "SessionRatingCreateView",
    "SessionRatingListView",
    "SessionRatingDetailView",
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
    "ChatFilteredListView",
    "QueuedChatsView",
    "ChatAcceptView",
    "ChatMessageListView",
    "ChatTranscriptView",
    # Assessment
    "AssessmentListView",
    "AssessmentDetailView",
    "AssessmentSubmitView",
    "AssessmentResultsListView",
    "AssessmentResultDetailView",
]

