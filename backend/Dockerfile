# Use a lightweight, stable, official Python runtime
FROM python:3.9-slim-buster

# Set working directory
WORKDIR /app

# Set environment variables
# PYTHONDONTWRITEBYTECODE: Prevents Python from writing .pyc files to disk
# PYTHONUNBUFFERED: Prevents Python from buffering stdout/stderr (crucial for live logging)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Upgrade pip to the latest version
RUN pip install --no-cache-dir --upgrade pip

# Copy only requirements first to leverage Docker's layer caching.
# If requirements.txt hasn't changed, Docker skips this step entirely.
COPY requirements.txt .

# Install dependencies directly into the system path
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Expose the production port
EXPOSE 8000

# Start uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]