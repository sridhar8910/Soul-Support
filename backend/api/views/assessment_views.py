"""Assessment-related views."""
import logging
from typing import Any

from django.db import transaction
from rest_framework import generics, permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Assessment, AssessmentQuestion, AssessmentResult
from ..serializers import (
    AssessmentResultSerializer,
    AssessmentSerializer,
    AssessmentSubmissionSerializer,
)

logger = logging.getLogger(__name__)


class AssessmentListView(generics.ListAPIView):
    """List all available assessments."""
    serializer_class = AssessmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Assessment.objects.filter(is_active=True)


class AssessmentDetailView(generics.RetrieveAPIView):
    """Get assessment details with questions."""
    serializer_class = AssessmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Assessment.objects.filter(is_active=True)

    def retrieve(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        assessment = self.get_object()
        serializer = self.get_serializer(assessment)
        
        # Include questions in response
        questions = AssessmentQuestion.objects.filter(
            assessment=assessment
        ).order_by('order')
        
        questions_data = [
            {
                'id': q.id,
                'question_text': q.question_text,
                'question_type': q.question_type,
                'options': q.options,
                'order': q.order,
            }
            for q in questions
        ]
        
        data = serializer.data
        data['questions'] = questions_data
        
        return Response(data)


class AssessmentSubmitView(APIView):
    """Submit assessment answers and get results."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        assessment_id = kwargs.get('assessment_id')
        if not assessment_id:
            return Response(
                {"error": "assessment_id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        serializer = AssessmentSubmissionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            assessment = Assessment.objects.get(id=assessment_id, is_active=True)
        except Assessment.DoesNotExist:
            return Response(
                {"error": "Assessment not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        answers = serializer.validated_data['answers']
        questions = AssessmentQuestion.objects.filter(assessment=assessment)
        
        # Calculate score (simple implementation - can be enhanced)
        total_score = 0
        max_score = 0
        
        for question in questions:
            question_id = str(question.id)
            if question_id in answers:
                answer_value = answers[question_id]
                
                if question.question_type == 'scale':
                    # Scale questions: value from 0 to max in options
                    try:
                        score = float(answer_value)
                        max_val = float(question.options[-1]) if question.options else 5.0
                        total_score += score
                        max_score += max_val
                    except (ValueError, IndexError):
                        pass
                elif question.question_type == 'multiple_choice':
                    # Multiple choice: map option index to score
                    try:
                        option_index = int(answer_value)
                        if 0 <= option_index < len(question.options):
                            # Score based on position (first option = lowest, last = highest)
                            score = option_index
                            max_val = len(question.options) - 1
                            total_score += score
                            max_score += max_val
                    except (ValueError, IndexError):
                        pass

        # Determine result category
        result_category = AssessmentResult.RESULT_NORMAL
        if max_score > 0:
            percentage = (total_score / max_score) * 100
            if percentage >= 75:
                result_category = AssessmentResult.RESULT_SEVERE
            elif percentage >= 50:
                result_category = AssessmentResult.RESULT_MODERATE
            elif percentage >= 25:
                result_category = AssessmentResult.RESULT_MILD

        # Generate recommendations
        recommendations = self._generate_recommendations(result_category, assessment.category)

        # Save result
        with transaction.atomic():
            result = AssessmentResult.objects.create(
                user=request.user,
                assessment=assessment,
                answers=answers,
                total_score=total_score if max_score > 0 else None,
                result_category=result_category,
                recommendations=recommendations,
            )

        logger.info(
            f"Assessment submitted: user={request.user.username}, "
            f"assessment={assessment.title}, category={result_category}"
        )

        return Response(
            AssessmentResultSerializer(result).data,
            status=status.HTTP_201_CREATED
        )

    def _generate_recommendations(self, category: str, assessment_category: str) -> str:
        """Generate personalized recommendations based on result."""
        recommendations_map = {
            AssessmentResult.RESULT_NORMAL: (
                "Your responses suggest you're managing well. "
                "Continue with your self-care practices and check in regularly."
            ),
            AssessmentResult.RESULT_MILD: (
                "You're experiencing some challenges. "
                "Consider trying our wellness tools, meditation sessions, or speaking with a counselor."
            ),
            AssessmentResult.RESULT_MODERATE: (
                "Your responses indicate you may benefit from professional support. "
                "We recommend scheduling a session with one of our counselors or exploring our support groups."
            ),
            AssessmentResult.RESULT_SEVERE: (
                "Your responses suggest you may be experiencing significant challenges. "
                "We strongly recommend reaching out to a professional counselor immediately. "
                "You can book a session through the app or contact our crisis support line."
            ),
        }
        
        base_recommendation = recommendations_map.get(
            category,
            "Thank you for completing the assessment. Consider speaking with a counselor for personalized guidance."
        )
        
        if assessment_category:
            base_recommendation += f" Our counselors specialize in {assessment_category.lower()} support."
        
        return base_recommendation


class AssessmentResultsListView(generics.ListAPIView):
    """List user's assessment results."""
    serializer_class = AssessmentResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AssessmentResult.objects.filter(user=self.request.user)


class AssessmentResultDetailView(generics.RetrieveAPIView):
    """Get specific assessment result details."""
    serializer_class = AssessmentResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return AssessmentResult.objects.filter(user=self.request.user)

