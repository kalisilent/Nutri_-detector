"""Per-IP rate limiting (slowapi). On Cloud Run the client IP arrives via X-Forwarded-For."""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
