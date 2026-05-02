"""
gmzone-app-template demo application.

This is a starter FastAPI app meant to be replaced with the real application
when this template is used. The endpoints are kept minimal on purpose —
they exist mainly to give the CI/CD pipeline something to build, scan,
and publish, and to validate the full deploy flow end-to-end.

Endpoints:
  GET /          → simple greeting
  GET /health    → liveness probe (used by docker healthcheck and Uptime Kuma)
  GET /version   → build metadata injected at build time via env vars
"""

import os
from fastapi import FastAPI

app = FastAPI(
    title="gmzone-app-template",
    description="Starter template for gmzone services",
    version=os.getenv("APP_VERSION", "0.0.0-dev"),
)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "hello from gmzone-app-template"}


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe. Always 200 if the process is up."""
    return {"status": "ok"}


@app.get("/version")
def version() -> dict[str, str]:
    """Build metadata. Populated by the CI pipeline via build args."""
    return {
        "version": os.getenv("APP_VERSION", "0.0.0-dev"),
        "git_sha": os.getenv("GIT_SHA", "unknown"),
        "build_date": os.getenv("BUILD_DATE", "unknown"),
    }
