"""
Tests for the Flask application.
Run with: pytest tests/ -v
"""

from app.main import app


def test_home_page():
    """Test that the home page loads and shows the app name."""
    client = app.test_client()
    response = client.get("/")

    assert response.status_code == 200
    # Check that key content appears in the HTML
    assert b"Azure DevOps CI/CD Pipeline" in response.data


def test_health_endpoint():
    """
    Test the health check endpoint returns correct JSON.
    This is the same endpoint your CI/CD pipeline will curl
    after deployment — if this test passes, your pipeline will too.
    """
    client = app.test_client()
    response = client.get("/health")
    data = response.get_json()

    assert response.status_code == 200
    assert data["status"] == "healthy"
    assert data["version"] == "1.0.0"


def test_info_endpoint():
    """
    Test the system info endpoint returns all expected fields.
    Like checking 'uname -a' output has the fields you expect.
    """
    client = app.test_client()
    response = client.get("/api/info")
    data = response.get_json()

    assert response.status_code == 200
    assert "hostname" in data
    assert "python_version" in data
    assert "timestamp" in data
    assert "environment" in data
