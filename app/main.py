"""
Flask application for Azure DevOps CI/CD Pipeline project.
Provides a home page, health check endpoint, and system info API.
"""

import os
import platform
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template

app = Flask(__name__)

# Application version — update this when you release new features
VERSION = "1.0.0"


@app.route("/")
def home():
    """Home page — renders an HTML template showing app info."""
    return render_template(
        "index.html",
        version=VERSION,
        status="healthy"
    )


@app.route("/health")
def health():
    """
    Health check endpoint.
    Used by Azure App Service and the CI/CD pipeline
    to verify the app is running correctly.
    Returns JSON so monitoring tools can parse it easily.
    """
    return jsonify({
        "status": "healthy",
        "version": VERSION
    })


@app.route("/api/info")
def info():
    """
    System info endpoint.
    Returns hostname, Python version, timestamp, and environment.
    Useful for debugging which container instance is responding.
    Uses platform.node() instead of os.uname() — works on both
    Windows and Linux, so you can test locally and deploy to Docker.
    """
    return jsonify({
        "hostname": platform.node(),
        "python_version": platform.python_version(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": os.getenv("FLASK_ENV", "production")
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
