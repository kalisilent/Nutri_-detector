"""API smoke tests."""


def test_health_endpoint(client):
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_unauthenticated_scan_rejected(client):
    resp = client.get("/api/v1/scans/history")
    assert resp.status_code == 401


def test_docs_available_in_dev(client):
    resp = client.get("/docs")
    assert resp.status_code == 200
