"""Mood tracking and history views."""
from datetime import datetime, timedelta
from typing import Any

from django.db.models import Avg, Count, Q
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import permissions
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import MoodLog, UserProfile


class MoodHistoryView(APIView):
    """
    Retrieve mood history with optional filtering by date range.
    
    Query parameters:
    - days: Number of days to retrieve (default: 30, max: 365)
    - start_date: Start date (YYYY-MM-DD format)
    - end_date: End date (YYYY-MM-DD format)
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        user = request.user
        days = int(request.query_params.get('days', 30))
        days = min(days, 365)  # Cap at 1 year
        
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        # Build query
        query = Q(user=user)
        
        if start_date or end_date:
            # Use date range if provided
            if start_date:
                try:
                    start = datetime.strptime(start_date, '%Y-%m-%d').date()
                    query &= Q(recorded_at__date__gte=start)
                except ValueError:
                    return Response(
                        {"error": "Invalid start_date format. Use YYYY-MM-DD."},
                        status=400
                    )
            if end_date:
                try:
                    end = datetime.strptime(end_date, '%Y-%m-%d').date()
                    query &= Q(recorded_at__date__lte=end)
                except ValueError:
                    return Response(
                        {"error": "Invalid end_date format. Use YYYY-MM-DD."},
                        status=400
                    )
        else:
            # Use days parameter
            cutoff_date = timezone.now().date() - timedelta(days=days)
            query &= Q(recorded_at__date__gte=cutoff_date)
        
        # Get mood logs
        mood_logs = MoodLog.objects.filter(query).order_by('-recorded_at')
        
        # Get profile for current mood
        profile, _ = UserProfile.objects.get_or_create(user=user)
        
        # Calculate statistics
        total_logs = mood_logs.count()
        if total_logs > 0:
            avg_mood = mood_logs.aggregate(avg=Avg('value'))['avg'] or 0.0
            # Group by date for daily averages
            daily_averages = (
                mood_logs
                .annotate(day=TruncDate('recorded_at'))
                .values('day')
                .annotate(
                    average=Avg('value'),
                    count=Count('id')
                )
                .order_by('day')
            )
        else:
            avg_mood = 0.0
            daily_averages = []
        
        # Serialize mood logs
        logs_data = [
            {
                "id": log.id,
                "value": float(log.value),
                "recorded_at": log.recorded_at.isoformat(),
            }
            for log in mood_logs[:100]  # Limit to 100 most recent
        ]
        
        # Serialize daily averages
        daily_data = [
            {
                "date": entry['day'].isoformat(),
                "average": float(entry['average']),
                "count": entry['count'],
            }
            for entry in daily_averages
        ]
        
        return Response({
            "current_mood": float(profile.last_mood) if profile.last_mood else None,
            "last_updated": profile.last_mood_updated.isoformat() if profile.last_mood_updated else None,
            "statistics": {
                "total_entries": total_logs,
                "average_mood": round(float(avg_mood), 1) if avg_mood else None,
                "period_days": days if not (start_date or end_date) else None,
            },
            "daily_averages": daily_data,
            "recent_logs": logs_data,
        })


class MoodAnalyticsView(APIView):
    """
    Advanced mood analytics with trends and insights.
    
    Returns:
    - Weekly and monthly trends
    - Mood distribution
    - Improvement/decline indicators
    - Best and worst days
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        user = request.user
        now = timezone.now()
        seven_days_ago = now - timedelta(days=6)
        thirty_days_ago = now - timedelta(days=29)
        
        # Weekly data
        weekly_logs = (
            MoodLog.objects
            .filter(user=user, recorded_at__date__gte=seven_days_ago.date())
            .annotate(day=TruncDate('recorded_at'))
            .values('day')
            .annotate(average=Avg('value'), count=Count('id'))
            .order_by('day')
        )
        
        # Monthly data
        monthly_logs = (
            MoodLog.objects
            .filter(user=user, recorded_at__date__gte=thirty_days_ago.date())
            .annotate(day=TruncDate('recorded_at'))
            .values('day')
            .annotate(average=Avg('value'), count=Count('id'))
            .order_by('day')
        )
        
        # All-time statistics
        all_logs = MoodLog.objects.filter(user=user)
        total_entries = all_logs.count()
        all_time_avg = all_logs.aggregate(avg=Avg('value'))['avg'] or 0.0
        
        # Weekly average
        weekly_avg = (
            MoodLog.objects
            .filter(user=user, recorded_at__date__gte=seven_days_ago.date())
            .aggregate(avg=Avg('value'))['avg'] or 0.0
        )
        
        # Monthly average
        monthly_avg = (
            MoodLog.objects
            .filter(user=user, recorded_at__date__gte=thirty_days_ago.date())
            .aggregate(avg=Avg('value'))['avg'] or 0.0
        )
        
        # Mood distribution (count by value ranges)
        mood_distribution = {
            "very_low": all_logs.filter(value__lt=2.0).count(),  # < 2.0
            "low": all_logs.filter(value__gte=2.0, value__lt=3.0).count(),  # 2.0-2.9
            "neutral": all_logs.filter(value__gte=3.0, value__lt=4.0).count(),  # 3.0-3.9
            "good": all_logs.filter(value__gte=4.0, value__lt=4.5).count(),  # 4.0-4.4
            "very_good": all_logs.filter(value__gte=4.5).count(),  # >= 4.5
        }
        
        # Best and worst days
        best_day = (
            all_logs
            .annotate(day=TruncDate('recorded_at'))
            .values('day')
            .annotate(avg=Avg('value'))
            .order_by('-avg')
            .first()
        )
        
        worst_day = (
            all_logs
            .annotate(day=TruncDate('recorded_at'))
            .values('day')
            .annotate(avg=Avg('value'))
            .order_by('avg')
            .first()
        )
        
        # Trend analysis (compare last 7 days to previous 7 days)
        last_7_days_avg = weekly_avg
        previous_7_days_start = seven_days_ago - timedelta(days=7)
        previous_7_days_avg = (
            MoodLog.objects
            .filter(
                user=user,
                recorded_at__date__gte=previous_7_days_start.date(),
                recorded_at__date__lt=seven_days_ago.date()
            )
            .aggregate(avg=Avg('value'))['avg'] or 0.0
        )
        
        trend = "stable"
        trend_value = 0.0
        if previous_7_days_avg > 0:
            trend_value = float(last_7_days_avg) - float(previous_7_days_avg)
            if trend_value > 0.2:
                trend = "improving"
            elif trend_value < -0.2:
                trend = "declining"
        
        # Serialize data
        weekly_data = [
            {
                "date": entry["day"].isoformat(),
                "average": round(float(entry["average"]), 1),
                "count": entry["count"],
            }
            for entry in weekly_logs
        ]
        
        monthly_data = [
            {
                "date": entry["day"].isoformat(),
                "average": round(float(entry["average"]), 1),
                "count": entry["count"],
            }
            for entry in monthly_logs
        ]
        
        return Response({
            "overview": {
                "total_entries": total_entries,
                "all_time_average": round(float(all_time_avg), 1) if all_time_avg else None,
                "weekly_average": round(float(weekly_avg), 1) if weekly_avg else None,
                "monthly_average": round(float(monthly_avg), 1) if monthly_avg else None,
            },
            "trends": {
                "weekly": weekly_data,
                "monthly": monthly_data,
                "direction": trend,
                "change": round(trend_value, 1),
            },
            "distribution": mood_distribution,
            "insights": {
                "best_day": {
                    "date": best_day["day"].isoformat() if best_day else None,
                    "average": round(float(best_day["avg"]), 1) if best_day else None,
                } if best_day else None,
                "worst_day": {
                    "date": worst_day["day"].isoformat() if worst_day else None,
                    "average": round(float(worst_day["avg"]), 1) if worst_day else None,
                } if worst_day else None,
            },
        })

