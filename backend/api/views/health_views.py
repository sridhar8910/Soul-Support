"""Health check and server info views."""
from rest_framework import permissions
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthCheckView(APIView):
    """Health check endpoint that returns server status."""
    permission_classes = [permissions.AllowAny]

    def get(self, request: Request) -> Response:
        """Return health status."""
        return Response({
            "status": "ok",
            "service": "Soul Support API"
        })

