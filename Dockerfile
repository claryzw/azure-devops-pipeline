# ============================================================
# Dockerfile for Azure DevOps CI/CD Pipeline Project
# Author: Clarence Itai Msindo
# Purpose: Containerise the Flask app for deployment to Azure
# ============================================================

# Stage 1: Use a slim Python base image to keep the image small
# python:3.11-slim is ~150MB vs ~900MB for the full image
FROM python:3.11-slim

# Security: Add metadata labels so anyone inspecting this image
# knows who built it and what it does
LABEL maintainer="Clarence Itai Msindo"
LABEL description="Flask API for Azure DevOps CI/CD Pipeline"
LABEL version="1.0.0"

# Security: Create a non-root user to run the app
# This follows the principle of least privilege — same concept
# as your security policies at HA Group
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

# Set the working directory inside the container
# All commands after this run from /app
WORKDIR /app

# Copy requirements.txt FIRST (layer caching optimisation)
# Docker caches this layer — if requirements.txt has not changed,
# pip install is skipped on rebuild, saving minutes
COPY requirements.txt .

# Install Python dependencies, then remove build tools
# --no-cache-dir: do not store pip cache (smaller image)
# --no-compile: skip .pyc generation at install time (smaller image)
# Removing pip, setuptools, and wheel eliminates 5 Trivy findings
# because these tools are not needed at runtime
RUN pip install --no-cache-dir --no-compile -r requirements.txt \
    && pip uninstall -y pip setuptools wheel \
    && rm -rf /root/.cache

# Copy the rest of the application code
COPY . .

# Security: Change ownership of app files to the non-root user
RUN chown -R appuser:appuser /app

# Security: Switch to non-root user for runtime
USER appuser

# Tell Docker this container listens on port 8000
# This is documentation only — you still need -p flag when running
EXPOSE 8000

# Health check: Docker will ping /health every 30 seconds
# If it fails 3 times in a row, Docker marks the container unhealthy
# This is the same concept as your uptime monitoring at HA Group
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Run the app with gunicorn (production WSGI server)
# --workers 2: handle multiple requests at once
# --bind 0.0.0.0:8000: listen on all interfaces inside the container
# --access-logfile -: print access logs to stdout (Docker best practice)
# --error-logfile -: print error logs to stderr
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app.main:app"]