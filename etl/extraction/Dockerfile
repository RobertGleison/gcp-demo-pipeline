FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

# Hermetic, faster installs: compile to bytecode, copy (don't symlink) into the layer.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# Dependency layer first — cached until the lockfile changes. --locked fails the
# build if pyproject.toml and uv.lock have drifted (so the image is reproducible);
# --no-install-project because the code runs as source, not as an installed package.
COPY etl/extraction/pyproject.toml etl/extraction/uv.lock /app/etl/extraction/
RUN cd /app/etl/extraction && uv sync --locked --no-install-project --no-dev

COPY etl/extraction/ /app/etl/extraction/

ENV PATH="/app/etl/extraction/.venv/bin:$PATH" \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

# Default run = real publish (needs PUBSUB_TOPIC). Cloud Run overrides args via
# the cloudrun_job module, e.g. ["--count", "10"] or ["--dry-run"].
ENTRYPOINT ["python", "-m", "etl.extraction.league_of_legends.matches.main"]
