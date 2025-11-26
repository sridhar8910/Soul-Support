"""Legacy views for backward compatibility."""
from typing import Any

from rest_framework import permissions
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

LEGACY_GUIDELINES = [
    {
        "title": "Respect & Confidentiality",
        "bullets": [
            "Treat all members with dignity and respect.",
            "Never share personal information without consent.",
            "Maintain strict confidentiality of others' stories.",
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
        "tagline": "Guiding you through life's big decisions.",
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

    def get(self, request: Request) -> Response:
        return Response({"sections": LEGACY_GUIDELINES})


class LegacyExpertConnectView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response({"counsellors": LEGACY_COUNSELLORS})


class LegacyBreathingView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response(
            {
                "cycle_options": [4, 5, 6, 8, 10],
                "tip": "For calm, try 6–8 second cycles. If you feel lightheaded stop and return to normal breathing.",
            }
        )


class LegacyAssessmentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response({"questions": LEGACY_ASSESSMENT_QUESTIONS})


class LegacyAffirmationsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
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

    def get(self, request: Request) -> Response:
        return Response(
            {
                "services": LEGACY_ADVANCED_SERVICES,
                "specialists": LEGACY_ADVANCED_SPECIALISTS,
            }
        )


class LegacyFeatureDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response(LEGACY_FEATURE_DETAIL)

