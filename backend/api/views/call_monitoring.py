"""
Call monitoring and quality tracking.
Logs call metrics for performance analysis and troubleshooting.
"""
import logging
import time
from django.utils import timezone
from django.db import transaction
from ..models import Call

logger = logging.getLogger(__name__)


class CallMonitor:
    """Monitor call quality and connection metrics."""
    
    @staticmethod
    def log_call_started(call_id: int, user_id: int, counsellor_id: int = None):
        """Log when a call starts."""
        try:
            call = Call.objects.get(id=call_id)
            call.status = Call.STATUS_ACTIVE
            call.started_at = timezone.now()
            call.save(update_fields=['status', 'started_at'])
            
            logger.info(
                "CALL_STARTED: call_id=%d, user_id=%d, counsellor_id=%s, call_type=%s",
                call_id,
                user_id,
                counsellor_id,
                call.call_type
            )
        except Call.DoesNotExist:
            logger.error("CALL_STARTED: Call %d not found", call_id)
        except Exception as e:
            logger.error("CALL_STARTED: Error logging call start: %s", e, exc_info=True)
    
    @staticmethod
    def log_call_ended(call_id: int, duration_seconds: int, reason: str = "user_ended"):
        """Log when a call ends."""
        try:
            call = Call.objects.get(id=call_id)
            call.status = Call.STATUS_ENDED
            call.ended_at = timezone.now()
            call.duration_seconds = duration_seconds
            call.save(update_fields=['status', 'ended_at', 'duration_seconds'])
            
            logger.info(
                "CALL_ENDED: call_id=%d, duration=%d, reason=%s, user_id=%d, counsellor_id=%s",
                call_id,
                duration_seconds,
                reason,
                call.user_id,
                call.counsellor_id if call.counsellor else None
            )
        except Call.DoesNotExist:
            logger.error("CALL_ENDED: Call %d not found", call_id)
        except Exception as e:
            logger.error("CALL_ENDED: Error logging call end: %s", e, exc_info=True)
    
    @staticmethod
    def log_connection_state(call_id: int, state: str, details: dict = None):
        """Log WebRTC connection state changes."""
        logger.info(
            "CALL_CONNECTION_STATE: call_id=%d, state=%s, details=%s",
            call_id,
            state,
            details or {}
        )
    
    @staticmethod
    def log_ice_connection_state(call_id: int, state: str, candidate_type: str = None):
        """Log ICE connection state changes."""
        logger.info(
            "CALL_ICE_STATE: call_id=%d, state=%s, candidate_type=%s",
            call_id,
            state,
            candidate_type
        )
    
    @staticmethod
    def log_signaling_event(call_id: int, event_type: str, success: bool, error: str = None):
        """Log WebRTC signaling events (offer, answer, ICE candidate)."""
        logger.info(
            "CALL_SIGNALING: call_id=%d, event=%s, success=%s, error=%s",
            call_id,
            event_type,
            success,
            error
        )
    
    @staticmethod
    def log_call_quality_metrics(call_id: int, metrics: dict):
        """
        Log call quality metrics.
        
        Expected metrics:
        - audio_bitrate: Audio bitrate in bps
        - video_bitrate: Video bitrate in bps (if video call)
        - packet_loss: Packet loss percentage
        - jitter: Jitter in ms
        - rtt: Round-trip time in ms
        - frames_per_second: Video FPS (if video call)
        - resolution: Video resolution (if video call)
        """
        logger.info(
            "CALL_QUALITY: call_id=%d, metrics=%s",
            call_id,
            metrics
        )
    
    @staticmethod
    def log_turn_server_usage(call_id: int, used_turn: bool, turn_server: str = None):
        """Log whether TURN server was used for the call."""
        logger.info(
            "CALL_TURN_USAGE: call_id=%d, used_turn=%s, server=%s",
            call_id,
            used_turn,
            turn_server
        )
    
    @staticmethod
    def get_call_statistics(counsellor_id: int = None, days: int = 30):
        """Get call statistics for analysis."""
        from django.db.models import Count, Avg, Sum, Q
        from datetime import timedelta
        
        end_date = timezone.now()
        start_date = end_date - timedelta(days=days)
        
        queryset = Call.objects.filter(
            created_at__gte=start_date,
            created_at__lte=end_date
        )
        
        if counsellor_id:
            queryset = queryset.filter(counsellor_id=counsellor_id)
        
        stats = {
            'total_calls': queryset.count(),
            'successful_calls': queryset.filter(status=Call.STATUS_ENDED).count(),
            'failed_calls': queryset.filter(
                status__in=[Call.STATUS_MISSED, Call.STATUS_CANCELLED]
            ).count(),
            'average_duration': queryset.filter(
                status=Call.STATUS_ENDED,
                duration_seconds__gt=0
            ).aggregate(
                avg_duration=Avg('duration_seconds')
            )['avg_duration'] or 0,
            'total_duration': queryset.filter(
                status=Call.STATUS_ENDED
            ).aggregate(
                total_duration=Sum('duration_seconds')
            )['total_duration'] or 0,
            'video_calls': queryset.filter(call_type=Call.CALL_TYPE_VIDEO).count(),
            'voice_calls': queryset.filter(call_type=Call.CALL_TYPE_VOICE).count(),
            'calls_by_status': queryset.values('status').annotate(
                count=Count('id')
            ).values('status', 'count'),
        }
        
        logger.info("CALL_STATISTICS: counsellor_id=%s, days=%d, stats=%s", counsellor_id, days, stats)
        
        return stats

