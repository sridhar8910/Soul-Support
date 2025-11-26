"""Authentication and registration views."""
import logging
import secrets
import threading
from typing import Any

from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView as BaseTokenRefreshView

from ..models import EmailOTP
from ..serializers import (
    EmailOrUsernameTokenObtainPairSerializer,
    RegisterSerializer,
    SendOTPSerializer,
    VerifyOTPSerializer,
)

logger = logging.getLogger(__name__)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class RegistrationSendOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request: Request) -> Response:
        serializer = SendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"]

        with transaction.atomic():
            # Note: 'objects' is added by Django's ModelBase metaclass at runtime
            # This is a false positive from static type checkers
            # pylint: disable=no-member
            EmailOTP.objects.filter(email=email, purpose=EmailOTP.PURPOSE_REGISTRATION).delete()  # type: ignore[attr-defined,no-member]  # noqa: E501
            code = f"{secrets.randbelow(1_000_000):06d}"
            token = secrets.token_urlsafe(32)
            # pylint: disable=no-member
            otp = EmailOTP.objects.create(  # type: ignore[attr-defined,no-member]
                email=email,
                code=code,
                purpose=EmailOTP.PURPOSE_REGISTRATION,
                token=token,
                expires_at=timezone.now() + timezone.timedelta(minutes=10),
            )

        logger.info("Registration OTP for %s is %s", email, code)
        print(f"[OTP] Registration code for {email}: {code}")

        # Return response immediately, send email asynchronously
        # This prevents the request from hanging if email sending is slow
        def send_email_async():
            """Send email in background thread to avoid blocking the request."""
            try:
                from django.conf import settings
                from django.db import connections
                
                # Close database connections in this thread to avoid issues
                connections.close_all()
                
                # Use DEFAULT_FROM_EMAIL from settings
                from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'python.nexnoratech@gmail.com')
                
                logger.info("Attempting to send OTP email to %s from %s", email, from_email)
                print(f"[OTP] Sending email to {email} from {from_email}")
                
                result = send_mail(
                    subject="Your Soul Support verification code",
                    message=f"Use this code to finish your sign up: {otp.code}. It expires in 10 minutes.",
                    from_email=from_email,
                    recipient_list=[email],
                    fail_silently=False,
                )

                logger.info("OTP email sent successfully to %s. Result: %s", email, result)
                print(f"[OTP] Email sent successfully to {email}")
                
            except Exception as e:  # noqa: BLE001, broad-except  # pylint: disable=broad-except
                error_msg = f"Failed to send OTP email to {email}: {str(e)}"
                logger.error(error_msg, exc_info=True)
                print(f"[OTP ERROR] {error_msg}")
            finally:
                # Ensure database connections are closed
                from django.db import connections
                connections.close_all()

        # Start email sending in background thread
        email_thread = threading.Thread(target=send_email_async, daemon=True)
        email_thread.start()
        
        # Return response immediately without waiting for email
        return Response({"status": "sent", "message": "OTP sent successfully"})


class RegistrationVerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request: Request) -> Response:
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        otp: EmailOTP = serializer.validated_data["otp"]
        otp.mark_verified()
        return Response({"status": "verified", "token": otp.token})


class EmailOrUsernameTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailOrUsernameTokenObtainPairSerializer

    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        """Obtain JWT pair using either email or username. Fixed to handle immutable response.data."""
        # First, validate the credentials using serializer
        serializer = self.get_serializer(data=request.data)
        
        # Check if validation succeeds before accessing serializer.user
        if not serializer.is_valid(raise_exception=False):
            # Return validation errors if credentials are invalid
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        # At this point serializer is valid and should expose .user
        user = getattr(serializer, "user", None)
        if user is None:
            # Defensive fallback - shouldn't happen if serializer validated correctly
            return Response(
                {"detail": "Authentication failed."},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Call the original authentication / token creation logic
        response = super().post(request, *args, **kwargs)
        
        # If authentication failed, return the error response as-is
        if response.status_code != 200:
            return response
        
        # response.data may be an immutable Mapping - copy to a mutable dict before modifying
        resp_data = dict(response.data) if response.data is not None else {}
        
        # Determine user role
        role = 'user'
        if hasattr(user, 'counsellorprofile'):
            role = 'counsellor'
        elif hasattr(user, 'doctorprofile'):
            role = 'doctor'
        elif user.is_superuser:
            role = 'admin'
        
        # Add role and user info to response safely
        resp_data['role'] = role
        resp_data['user_id'] = user.id
        resp_data['username'] = user.username
        
        # Return a new Response with the modified payload and same status code
        return Response(resp_data, status=response.status_code)


class TokenRefreshView(BaseTokenRefreshView):
    """
    Custom token refresh view that handles cases where the user no longer exists.
    Returns 401 Unauthorized instead of 500 Internal Server Error.
    """
    
    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        try:
            return super().post(request, *args, **kwargs)
        # pylint: disable=no-member
        except User.DoesNotExist:  # type: ignore[attr-defined]
            request_data = request.data if hasattr(request, 'data') else 'N/A'
            logger.warning(
                "Token refresh attempted for non-existent user. Request data: %s",
                request_data
            )
            return Response(
                {
                    "detail": "Token is invalid or user no longer exists. Please login again.",
                    "code": "token_invalid"
                },
                status=status.HTTP_401_UNAUTHORIZED
            )
        except (InvalidToken, TokenError) as e:
            logger.warning("Token refresh failed: %s", e)
            return Response(
                {
                    "detail": str(e),
                    "code": "token_invalid"
                },
                status=status.HTTP_401_UNAUTHORIZED
            )
        # pylint: disable-next=broad-except
        except Exception as e:  # noqa: BLE001, broad-except
            logger.error("Unexpected error in token refresh: %s", e, exc_info=True)
            return Response(
                {
                    "detail": "An error occurred while refreshing the token. Please try again.",
                    "code": "token_refresh_error"
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

