"""Wallet management views."""
# type: ignore
# pyright: reportAttributeAccessIssue=false
# pylint: disable=no-member
from rest_framework import permissions, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import UserProfile
from ..serializers import WalletUsageSerializer
from .constants import SERVICE_MIN_BALANCE_MAP, SERVICE_RATE_MAP


class WalletRechargeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request) -> Response:
        # Accept both 'amount' (rupees) and 'minutes' for backward compatibility
        # Frontend sends 'amount' in rupees, but field name is 'minutes' for legacy reasons
        amount = request.data.get("amount") or request.data.get("minutes")
        if amount is None:
            return Response(
                {"detail": "Either 'amount' or 'minutes' field is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        try:
            amount = int(amount)
            if amount <= 0:
                return Response(
                    {"detail": "Amount must be greater than 0"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        except (ValueError, TypeError):
            return Response(
                {"detail": "Invalid amount value"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile.wallet_minutes += amount
        profile.save(update_fields=["wallet_minutes"])
        return Response(
            {"status": "ok", "wallet_minutes": profile.wallet_minutes},
            status=status.HTTP_200_OK,
        )


class WalletDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request: Request) -> Response:
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        return Response(
            {
                "wallet_minutes": profile.wallet_minutes,
                "rates": SERVICE_RATE_MAP,
                "minimum_balance": SERVICE_MIN_BALANCE_MAP,
            }
        )


class WalletUsageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request: Request) -> Response:
        serializer = WalletUsageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        service = serializer.validated_data["service"]
        minutes = serializer.validated_data["minutes"]
        rate = SERVICE_RATE_MAP[service]
        charge = minutes * rate
        min_required = SERVICE_MIN_BALANCE_MAP[service]

        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        if profile.wallet_minutes < min_required:
            return Response(
                {
                    "detail": f"Minimum balance of Rs {min_required} required to start {service}.",
                    "wallet_minutes": profile.wallet_minutes,
                    "required_minimum": min_required,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        if profile.wallet_minutes < charge:
            return Response(
                {
                    "detail": "Insufficient wallet balance",
                    "wallet_minutes": profile.wallet_minutes,
                    "required": charge,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile.wallet_minutes -= charge
        profile.save(update_fields=["wallet_minutes"])
        return Response(
            {
                "status": "ok",
                "service": service,
                "minutes": minutes,
                "rate_per_minute": rate,
                "charged": charge,
                "wallet_minutes": profile.wallet_minutes,
            }
        )

