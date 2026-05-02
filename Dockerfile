# syntax=docker/dockerfile:1.7
#
# Multi-stage build:
#   1) builder    → installs dependencies in a virtualenv (heavy, build-time only)
#   2) runtime    → copies the venv into a slim, non-root image (final, shipped)
#
# Goals:
#   - Final image as small as possible (less surface for Trivy scan to flag)
#   - No build toolchain in the final image
#   - Runs as non-root
#   - Reproducible: pinned base image SHA ideally (see TODO at the bottom)
#
# Build args (populated by the CI pipeline):
#   APP_VERSION  → semver / tag name
#   GIT_SHA      → git commit sha
#   BUILD_DATE   → ISO 8601 timestamp

ARG PYTHON_VERSION=3.12

# ---------- Stage 1: builder ----------
FROM python:${PYTHON_VERSION}-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Create venv so we can copy a self-contained directory into the runtime stage
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------- Stage 2: runtime ----------
FROM python:${PYTHON_VERSION}-slim AS runtime

ARG APP_VERSION=0.0.0-dev
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    BUILD_DATE=${BUILD_DATE}

# OCI labels — picked up by registries, makes the image self-describing
LABEL org.opencontainers.image.title="gmzone-app-template" \
      org.opencontainers.image.description="Starter template for gmzone services" \
      org.opencontainers.image.source="https://github.com/gmzone-it/gmzone-app-template" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT"

# Non-root user. UID 10001 is in the recommended range for unprivileged users
# (above the typical 1000-9999 used by default users on most distros).
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid app --no-create-home --shell /sbin/nologin app

WORKDIR /srv

# Copy the virtualenv from the builder
COPY --from=builder /opt/venv /opt/venv

# Copy app code (last, so changes here don't invalidate the venv layer)
COPY --chown=app:app app/ ./app/

USER app

EXPOSE 8000

# Embedded healthcheck — docker compose can use this directly
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; \
    sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=2).status==200 else sys.exit(1)" \
  || exit 1

# Use uvicorn directly — for production scale, swap to gunicorn+uvicorn workers
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# TODO: pin the python base image to a digest (sha256:...) for fully reproducible builds
#       Example: FROM python:3.12-slim@sha256:abc123...
