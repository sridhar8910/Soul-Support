"""
Django models for the mental health counseling platform.

This file now re-exports all models from the models package for backward compatibility.
All models have been organized into separate files in the models/ directory.

For new code, you can import directly from the models package:
    from api.models import UserProfile
    from api.models.chat_models import Chat

Or continue using the old import style (backward compatible):
    from api.models import UserProfile, Chat
"""
# Import all models from the models package
from .models import *  # noqa: F403, F405

# Re-export everything for backward compatibility
from .models import (  # noqa: F401
    # User models
    UserProfile,
    # Professional profiles
    CounsellorProfile,
    CounsellorTimeSlot,
    DoctorProfile,
    # Communication models
    Chat,
    ChatMessage,
    Call,
    # Session models
    UpcomingSession,
    SessionRating,
    # Wellness models
    WellnessTask,
    WellnessJournalEntry,
    MyJournal,
    MoodLog,
    # Community models
    SupportGroup,
    SupportGroupMembership,
    # Content models
    GuidanceResource,
    MusicTrack,
    MindCareBooster,
    MeditationSession,
    # Assessment models
    Assessment,
    AssessmentQuestion,
    AssessmentResult,
    # Authentication models
    EmailOTP,
    # Feedback models
    UserFeedback,
)
