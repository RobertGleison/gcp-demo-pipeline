# Extractor Cloud Run Job image: built + pushed by GitHub Actions CD, run on a
# schedule by Cloud Scheduler. Reproducible install via uv against uv.lock.
#
# Build from the REPO ROOT so the `extraction.` package path resolves:
#   docker build -f extraction/Dockerfile -t extractor .
#
# uv's combined image ships uv + Python 3.13 (matches requires-python).
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

# Hermetic, faster installs: compile to bytecode, copy (don't symlink) into the layer.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# Dependency layer first — cached until the lockfile changes. --locked fails the
# build if pyproject.toml and uv.lock have drifted (so the image is reproducible);
# --no-install-project because the code runs as source, not as an installed package.
COPY extraction/pyproject.toml extraction/uv.lock /app/extraction/
RUN cd /app/extraction && uv sync --locked --no-install-project --no-dev

# Application source. .dockerignore keeps the host .venv / .env / caches out, so
# this never clobbers the venv uv just built or bakes the Riot key into the image.
COPY extraction/ /app/extraction/

# Run inside the project venv; PYTHONPATH=/app makes `import extraction...` resolve.
ENV PATH="/app/extraction/.venv/bin:$PATH" \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

# Default run = real publish (needs PUBSUB_TOPIC). Cloud Run overrides args via
# the cloudrun_job module, e.g. ["--count", "10"] or ["--dry-run"].
ENTRYPOINT ["python", "-m", "extraction.league_of_legends.matches.main"]
