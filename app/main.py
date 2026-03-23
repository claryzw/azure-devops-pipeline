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

# --- Application Insights Integration ---
# Connects to Azure Monitor using the connection string from App Service.
# Only activates when APPLICATIONINSIGHTS_CONNECTION_STRING is set,
# so your app still works locally without Azure credentials.
connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
if connection_string:
    from opencensus.ext.azure.trace_exporter import AzureExporter
    from opencensus.ext.flask.flask_middleware import FlaskMiddleware
    from opencensus.trace.samplers import ProbabilitySampler

    FlaskMiddleware(
        app,
        exporter=AzureExporter(connection_string=connection_string),
        sampler=ProbabilitySampler(rate=1.0)  # Track 100% of requests
    )


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
    """

  return jsonify({
        "hostname": platform.node(),
        "python_version": platform.python_version(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": os.getenv("FLASK_ENV", "production")
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)