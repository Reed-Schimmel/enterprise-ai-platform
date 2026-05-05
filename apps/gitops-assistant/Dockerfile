FROM python:3.11-slim

WORKDIR /app

# Copy requirement list and install dependencies first for caching
COPY apps/gitops-assistant/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY apps/gitops-assistant/app.py .
COPY apps/gitops-assistant/.chainlit .chainlit

# Copy the entire gitops repository into /app/repo
# (Assuming the docker build context is the repository root)
COPY . /app/repo

# Remove the virtual environment and git history from the copied repo to save space
RUN rm -rf /app/repo/.venv /app/repo/.git /app/repo/apps/gitops-assistant/.venv || true

EXPOSE 8000

CMD ["chainlit", "run", "app.py", "-h", "0.0.0.0", "-p", "8000"]
