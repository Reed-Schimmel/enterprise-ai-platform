FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Create a directory to mount the repository into
RUN mkdir -p /app/repo

# Expose Chainlit port
EXPOSE 8000

# Run Chainlit
CMD ["chainlit", "run", "app.py", "-h", "0.0.0.0", "-p", "8000"]
