"""
TURN server credential generation for WebRTC.
Generates time-limited TURN credentials using shared secret (HMAC).
Includes Redis caching for improved performance.
"""
import hmac
import hashlib
import os
import time
import logging
import json
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# Try to import Redis for caching
try:
    import redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    logger.warning("Redis not available - TURN credentials will not be cached")

# TURN server configuration - uses environment variables for production
# Set these in your .env file or environment:
# TURN_SERVER=your-turn-server.com
# TURN_PORT=3478
# TURN_REALM=soulsupport.local
# TURN_SHARED_SECRET=your-secret-key-here
TURN_SERVER = os.environ.get("TURN_SERVER", "localhost")
TURN_PORT = int(os.environ.get("TURN_PORT", "3478"))
TURN_REALM = os.environ.get("TURN_REALM", "soulsupport.local")
TURN_SHARED_SECRET = os.environ.get("TURN_SHARED_SECRET", "change-me-to-a-random-secret-key")

# Redis configuration for TURN credential caching
REDIS_HOST = os.environ.get("REDIS_HOST", "redis" if os.environ.get("DOCKER_ENV") else "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_DB = int(os.environ.get("REDIS_DB", "0"))
REDIS_TURN_CACHE_PREFIX = "turn_creds:"
REDIS_TURN_CACHE_TTL = int(os.environ.get("TURN_CACHE_TTL", "3300"))  # 55 minutes (slightly less than credential TTL)


def _get_redis_client() -> Optional[redis.Redis]:
    """Get Redis client for caching. Returns None if Redis is unavailable."""
    if not REDIS_AVAILABLE:
        return None
    
    try:
        client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            socket_connect_timeout=2,
            decode_responses=True
        )
        # Test connection
        client.ping()
        return client
    except Exception as e:
        logger.debug("Redis not available for TURN caching: %s", e)
        return None


def _get_cache_key(user_id: Optional[int] = None) -> str:
    """Generate cache key for TURN credentials."""
    if user_id:
        return f"{REDIS_TURN_CACHE_PREFIX}user:{user_id}"
    return f"{REDIS_TURN_CACHE_PREFIX}default"


def _get_cached_credentials(user_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
    """Get cached TURN credentials from Redis."""
    redis_client = _get_redis_client()
    if not redis_client:
        return None
    
    try:
        cache_key = _get_cache_key(user_id)
        cached_data = redis_client.get(cache_key)
        
        if cached_data:
            credentials = json.loads(cached_data)
            # Verify credentials haven't expired
            expires_at = credentials.get("expires_at", 0)
            if expires_at > int(time.time()):
                logger.info("TURN credentials cache HIT for user_id=%s", user_id)
                credentials["_from_cache"] = True
                return credentials
            else:
                # Expired, delete from cache
                redis_client.delete(cache_key)
                logger.debug("TURN credentials expired, removed from cache")
        
        logger.debug("TURN credentials cache MISS for user_id=%s", user_id)
        return None
    except Exception as e:
        logger.warning("Error reading TURN credentials from cache: %s", e)
        return None


def _cache_credentials(credentials: Dict[str, Any], user_id: Optional[int] = None) -> None:
    """Cache TURN credentials in Redis."""
    redis_client = _get_redis_client()
    if not redis_client:
        return
    
    try:
        cache_key = _get_cache_key(user_id)
        # Cache with TTL slightly less than credential expiration
        redis_client.setex(
            cache_key,
            REDIS_TURN_CACHE_TTL,
            json.dumps(credentials)
        )
        logger.info("TURN credentials cached for user_id=%s (TTL=%ds)", user_id, REDIS_TURN_CACHE_TTL)
    except Exception as e:
        logger.warning("Error caching TURN credentials: %s", e)
        # Don't fail if caching fails - credentials are still valid


def generate_turn_credentials(username: str = None, ttl: int = 3600) -> dict:
    """
    Generate TURN server credentials using TURN REST API (time-limited).
    
    Args:
        username: Optional username (defaults to timestamp-based)
        ttl: Time-to-live in seconds (default: 1 hour)
    
    Returns:
        Dictionary with TURN server configuration including credentials
    """
    if not username:
        # Generate username from timestamp
        username = str(int(time.time()) + ttl)
    
    # Generate credential using HMAC-SHA1
    # Format: HMAC-SHA1(shared_secret, username:realm:expiration_time)
    expiration_time = int(time.time()) + ttl
    credential_string = f"{username}:{TURN_REALM}:{expiration_time}"
    credential = hmac.new(
        TURN_SHARED_SECRET.encode('utf-8'),
        credential_string.encode('utf-8'),
        hashlib.sha1
    ).hexdigest()
    
    logger.info("Generated TURN credentials for username=%s, expires in %d seconds", username, ttl)
    
    # Build STUN and TURN URLs
    stun_url = f"stun:{TURN_SERVER}:{TURN_PORT}"
    turn_url = f"turn:{TURN_SERVER}:{TURN_PORT}"
    
    # For production, also include TURNS (secure TURN over TLS) if configured
    ice_servers = [
        {
            "urls": stun_url,
        },
        {
            "urls": turn_url,
            "username": username,
            "credential": credential,
        },
    ]
    
    # Add TURNS (secure TURN) if TURNS port is configured
    turns_port = os.environ.get("TURN_TLS_PORT")
    if turns_port:
        turns_url = f"turns:{TURN_SERVER}:{turns_port}"
        ice_servers.append({
            "urls": turns_url,
            "username": username,
            "credential": credential,
        })
    
    return {
        "iceServers": ice_servers,
        "ttl": ttl,
        "expires_at": expiration_time,
    }


def get_turn_configuration(user_id: Optional[int] = None, use_cache: bool = True) -> dict:
    """
    Get TURN server configuration for WebRTC clients.
    Uses Redis caching to avoid regenerating credentials for the same user.
    
    Args:
        user_id: Optional user ID for user-specific caching
        use_cache: Whether to use cache (default: True)
    
    Returns:
        Dictionary with TURN server configuration including credentials
    """
    # Try to get from cache first
    if use_cache and user_id is not None:
        cached = _get_cached_credentials(user_id)
        if cached:
            return cached
    
    # Generate new credentials
    credentials = generate_turn_credentials()
    
    # Cache them for future use
    if use_cache and user_id is not None:
        _cache_credentials(credentials, user_id)
    
    return credentials


def invalidate_turn_cache(user_id: Optional[int] = None) -> None:
    """
    Invalidate cached TURN credentials for a user.
    Useful when credentials need to be regenerated immediately.
    
    Args:
        user_id: User ID to invalidate cache for, or None for default cache
    """
    redis_client = _get_redis_client()
    if not redis_client:
        return
    
    try:
        cache_key = _get_cache_key(user_id)
        redis_client.delete(cache_key)
        logger.info("TURN credentials cache invalidated for user_id=%s", user_id)
    except Exception as e:
        logger.warning("Error invalidating TURN credentials cache: %s", e)

