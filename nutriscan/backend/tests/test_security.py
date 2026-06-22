"""Unit tests for JWT + password hashing."""
from app.core.security import (create_access_token, create_refresh_token,
                               decode_token, hash_password, verify_password)


def test_password_roundtrip():
    hashed = hash_password("s3cret-password")
    assert verify_password("s3cret-password", hashed)
    assert not verify_password("wrong", hashed)


def test_access_token_roundtrip():
    token = create_access_token("user-123")
    assert decode_token(token, "access") == "user-123"


def test_token_type_enforced():
    refresh = create_refresh_token("user-123")
    # refresh token must NOT be accepted as an access token
    assert decode_token(refresh, "access") is None
    assert decode_token(refresh, "refresh") == "user-123"


def test_garbage_token_rejected():
    assert decode_token("not-a-jwt") is None
