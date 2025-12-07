"""
Django models package for the mental health counseling platform.

All models are organized into separate files by functionality for better
maintainability and understanding.
"""

# User models
from .user_models import UserProfile

# Professional profiles
from .professional_models import CounsellorProfile, CounsellorTimeSlot, DoctorProfile

# Communication models
from .chat_models import Chat, ChatMessage
from .call_models import Call

# Session models
from .session_models import UpcomingSession, SessionRating

# Wellness models
from .wellness_models import WellnessTask, WellnessJournalEntry, MyJournal
from .mood_models import MoodLog

# Community models
from .support_group_models import SupportGroup, SupportGroupMembership

# Content models
from .content_models import (
    GuidanceResource,
    MusicTrack,
    MindCareBooster,
    MeditationSession,
)

# Assessment models
from .assessment_models import Assessment, AssessmentQuestion, AssessmentResult

# Authentication models
from .auth_models import EmailOTP

# Feedback models
from .feedback_models import UserFeedback

# Export all models for backward compatibility
__all__ = [
    # User models
    'UserProfile',
    # Professional profiles
    'CounsellorProfile',
    'CounsellorTimeSlot',
    'DoctorProfile',
    # Communication models
    'Chat',
    'ChatMessage',
    'Call',
    # Session models
    'UpcomingSession',
    'SessionRating',
    # Wellness models
    'WellnessTask',
    'WellnessJournalEntry',
    'MyJournal',
    'MoodLog',
    # Community models
    'SupportGroup',
    'SupportGroupMembership',
    # Content models
    'GuidanceResource',
    'MusicTrack',
    'MindCareBooster',
    'MeditationSession',
    # Assessment models
    'Assessment',
    'AssessmentQuestion',
    'AssessmentResult',
    # Authentication models
    'EmailOTP',
    # Feedback models
    'UserFeedback',
]

