"""
Billing utilities for chat sessions.
Implements time-based billing: 2 rupees per minute of active chat time.
"""
# type: ignore
# pyright: reportAttributeAccessIssue=false
# pylint: disable=no-member,broad-except
from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from ..models import Chat, UserProfile
import logging

logger = logging.getLogger(__name__)

# Billing rate: 2 rupees per minute
CHAT_RATE_PER_MINUTE = Decimal('2.00')


def calculate_chat_duration_minutes(chat: Chat) -> int:
    """
    Calculate the active duration of a chat in minutes.
    
    Args:
        chat: Chat instance with started_at and ended_at
        
    Returns:
        int: Duration in minutes (rounded up to nearest minute, minimum 1 minute)
    """
    if not chat.started_at:
        return 0
    
    # Use ended_at if available, otherwise use current time (for active chats)
    end_time = chat.ended_at if chat.ended_at else timezone.now()
    
    if end_time <= chat.started_at:
        return 0
    
    # Calculate total seconds
    duration_seconds = (end_time - chat.started_at).total_seconds()
    
    # Convert to minutes (round up to nearest minute for billing)
    from math import ceil
    duration_minutes = int(ceil(duration_seconds / 60))
    
    # Ensure minimum 1 minute billing for any chat that started and ended
    # This guarantees Rs 2 is charged even for very short chats (< 1 minute)
    if duration_minutes == 0 and chat.ended_at and chat.started_at:
        duration_minutes = 1
    
    return duration_minutes


def calculate_chat_billing(chat: Chat) -> Decimal:
    """
    Calculate billing amount for a chat session.
    
    Args:
        chat: Chat instance
        
    Returns:
        Decimal: Billing amount in rupees (2 rupees per minute)
    """
    duration_minutes = calculate_chat_duration_minutes(chat)
    
    # Calculate billing: 2 rupees per minute
    billing_amount = Decimal(duration_minutes) * CHAT_RATE_PER_MINUTE
    
    return billing_amount


def deduct_chat_billing(chat: Chat, billing_amount: Decimal) -> bool:
    """
    Deduct billing amount from user's wallet.
    
    Args:
        chat: Chat instance
        billing_amount: Amount to deduct (in rupees)
        
    Returns:
        bool: True if deduction successful, False otherwise
    """
    try:
        if not chat.user:
            logger.error("Chat %s has no user assigned", chat.id)
            return False
        
        # Convert billing_amount to int for wallet_minutes (which is an integer field)
        billing_amount_int = int(billing_amount)
        
        if billing_amount_int <= 0:
            logger.info("Billing amount is %s, no deduction needed for chat %s", billing_amount_int, chat.id)
            return True
        
        with transaction.atomic():
            # Get user profile with select_for_update to prevent race conditions
            try:
                profile = UserProfile.objects.select_for_update().get(user=chat.user)
            except UserProfile.DoesNotExist:
                # Create profile if it doesn't exist
                logger.warning("UserProfile not found for user %s, creating one", chat.user.username)
                profile = UserProfile.objects.create(user=chat.user, wallet_minutes=0)
            
            old_balance = profile.wallet_minutes
            
            logger.info(
                "Attempting to deduct billing for chat %s: amount=Rs %s, current_balance=Rs %s, user=%s",
                chat.id,
                billing_amount_int,
                old_balance,
                chat.user.username
            )
            
            # Check if user has sufficient balance
            if profile.wallet_minutes < billing_amount_int:
                logger.warning(
                    "[FAILED] Insufficient wallet balance for chat %s: user has Rs %s, needs Rs %s. User: %s",
                    chat.id,
                    profile.wallet_minutes,
                    billing_amount_int,
                    chat.user.username
                )
                return False
            
            # Deduct from wallet
            profile.wallet_minutes -= billing_amount_int
            profile.save(update_fields=['wallet_minutes'])
            
            # Verify the deduction was successful
            profile.refresh_from_db()
            
            logger.info(
                "[OK] Billing deducted successfully for chat %s: amount=Rs %s, balance: Rs %s -> Rs %s, user=%s",
                chat.id,
                billing_amount_int,
                old_balance,
                profile.wallet_minutes,
                chat.user.username
            )
            
            return True
            
    except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
        logger.error("[ERROR] Error deducting billing for chat %s: %s", chat.id, e, exc_info=True)
        return False


def calculate_and_deduct_chat_billing(chat: Chat) -> bool:
    """
    Calculate and deduct billing for a chat session.
    This is called automatically when a chat ends.
    
    Args:
        chat: Chat instance that has ended (must be saved first to have ended_at)
        
    Returns:
        bool: True if billing processed successfully, False otherwise
    """
    # Refresh from database to get latest state
    try:
        chat.refresh_from_db()
    except Chat.DoesNotExist:
        logger.error("Chat %s does not exist in database", chat.id)
        return False
    
    # Skip if already billed
    if chat.is_billed:
        logger.debug("Chat %s already billed, skipping", chat.id)
        return True
    
    # Skip if chat never started
    if not chat.started_at:
        logger.debug("Chat %s never started, no billing required", chat.id)
        # Mark as billed with 0 amount to prevent retries
        Chat.objects.filter(id=chat.id).update(
            is_billed=True,
            billing_processed_at=timezone.now(),
            duration_minutes=0,
            billed_amount=Decimal('0.00')
        )
        return True
    
    # Ensure ended_at is set
    if not chat.ended_at:
        logger.warning("Chat %s ended but ended_at not set, using current time", chat.id)
        chat.ended_at = timezone.now()
        # Use update to avoid recursion
        Chat.objects.filter(id=chat.id).update(ended_at=chat.ended_at)
        chat.refresh_from_db()
    
    # Calculate billing
    duration_minutes = calculate_chat_duration_minutes(chat)
    billing_amount = calculate_chat_billing(chat)
    
    username = getattr(chat.user, 'username', None) if chat.user else None
    logger.info(
        "Calculating billing for chat %s: duration_minutes=%s, billing_amount=Rs %s, "
        "started_at=%s, ended_at=%s, user=%s",
        chat.id,
        duration_minutes,
        billing_amount,
        chat.started_at,
        chat.ended_at,
        username
    )
    
    # Deduct from wallet
    deduction_success = False
    if billing_amount > 0:
        deduction_success = deduct_chat_billing(chat, billing_amount)
        if not deduction_success:
            username = getattr(chat.user, 'username', None) if chat.user else None
            logger.error(
                "[FAILED] FAILED to deduct Rs %s from wallet for chat %s. User: %s, Insufficient balance or error occurred.",
                billing_amount,
                chat.id,
                username
            )
    else:
        # No charge for 0 minutes
        deduction_success = True
        logger.info("Chat %s has 0 minutes duration, no billing required", chat.id)
    
    # Update chat with billing information
    # Use update() to avoid triggering save() again (which would cause recursion)
    update_fields = {
        'duration_minutes': duration_minutes,
        'billed_amount': billing_amount,
    }
    
    if deduction_success or billing_amount == 0:
        update_fields['is_billed'] = True
        update_fields['billing_processed_at'] = timezone.now()
        
        Chat.objects.filter(id=chat.id).update(**update_fields)
        # Refresh chat object
        chat.refresh_from_db()
        
        logger.info(
            "[OK] Billing processed for chat %s: duration=%s minutes, amount=Rs %s, deduction_success=%s",
            chat.id,
            duration_minutes,
            billing_amount,
            deduction_success
        )
        return True
    else:
        # Log error - don't mark as billed if deduction failed
        logger.error(
            "[FAILED] Failed to deduct billing for chat %s: amount=Rs %s, user wallet may be insufficient. "
            "Billing will be retried on next save.",
            chat.id,
            billing_amount
        )
        # Still save duration and billing amount for record keeping
        # Don't mark as billed so it can be retried
        Chat.objects.filter(id=chat.id).update(**update_fields)
        chat.refresh_from_db()
        return False


def get_chat_estimated_cost(chat: Chat) -> dict:
    """
    Get estimated billing cost for an active chat (based on current duration).
    
    Args:
        chat: Chat instance (active or completed)
        
    Returns:
        dict: {
            "duration_minutes": int,
            "estimated_amount": Decimal,
            "is_active": bool
        }
    """
    duration_minutes = calculate_chat_duration_minutes(chat)
    estimated_amount = calculate_chat_billing(chat)
    is_active = chat.status == Chat.STATUS_ACTIVE
    
    return {
        "duration_minutes": duration_minutes,
        "estimated_amount": float(estimated_amount),
        "is_active": is_active,
        "is_billed": chat.is_billed if hasattr(chat, 'is_billed') else False,
    }


def check_chat_wallet_balance(user) -> tuple[bool, str, int]:
    """
    Check if user has sufficient wallet balance to start a chat.
    
    Args:
        user: Django User instance
        
    Returns:
        tuple: (has_sufficient_balance: bool, message: str, current_balance: int)
    """
    try:
        profile, _ = UserProfile.objects.get_or_create(user=user)
        min_balance = 2  # Minimum 2 rupees (1 minute) to start chat
        
        if profile.wallet_minutes < min_balance:
            return (
                False,
                f"Insufficient wallet balance. Minimum Rs {min_balance} required to start chat. "
                f"Current balance: Rs {profile.wallet_minutes}",
                profile.wallet_minutes
            )
        
        return (True, "", profile.wallet_minutes)
        
    except Exception as e:  # noqa: BLE001  # type: ignore[assignment]  # pylint: disable=broad-except
        logger.error("Error checking wallet balance for user %s: %s", user.username, e, exc_info=True)
        return (False, f"Error checking wallet balance: {str(e)}", 0)

