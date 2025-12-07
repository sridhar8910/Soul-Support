"""Constants used across views."""
CALL_RATE_PER_MINUTE = 5  # ₹5 per minute
CHAT_RATE_PER_MINUTE = 1  # ₹1 per minute
MIN_CALL_BALANCE = 100  # Minimum ₹100 balance required
MIN_CHAT_BALANCE = 50  # Minimum ₹50 balance required
SERVICE_RATE_MAP = {
    "call": CALL_RATE_PER_MINUTE,
    "chat": CHAT_RATE_PER_MINUTE,
}
SERVICE_MIN_BALANCE_MAP = {
    "call": MIN_CALL_BALANCE,
    "chat": MIN_CHAT_BALANCE,
}

