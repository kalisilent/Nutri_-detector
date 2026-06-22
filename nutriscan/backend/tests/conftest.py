"""Shared fixtures. Uses SQLite in-memory for unit tests; pipeline tests mock OCR."""
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client(monkeypatch):
    # Avoid loading real ML/OCR in app startup for fast unit tests
    from app.main import app
    return TestClient(app, raise_server_exceptions=False)
