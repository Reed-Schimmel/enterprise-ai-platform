FROM python:3.11-slim

# Install uv for blazing fast dependency installation
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

# Copy requirement list and install dependencies first for caching
COPY apps/gitops-assistant/requirements.txt .

# Use BuildKit cache mounts and uv to drastically speed up builds
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system -r requirements.txt

# Copy the application code
COPY apps/gitops-assistant/app.py .
COPY apps/gitops-assistant/.chainlit .chainlit

# Copy the entire gitops repository into /app/repo
# (Assuming the docker build context is the repository root)
COPY . /app/repo

EXPOSE 8000

CMD ["chainlit", "run", "app.py", "--host", "0.0.0.0", "--port", "8000"]
