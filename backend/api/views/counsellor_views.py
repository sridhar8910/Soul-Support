"""Counsellor-specific views."""
from datetime import timedelta
from typing import Any

from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Chat, CounsellorProfile, UpcomingSession
from ..serializers import (
    CounsellorAppointmentSerializer,
    CounsellorProfileSerializer,
    CounsellorStatsSerializer,
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

    def get(self, request: Request) -> Response:
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

