# --- Stage 1: The "Builder" Stage ---
# We use a specific, slim version of Python on a stable Debian release ("buster").
# Naming this stage "builder" allows us to refer to it later.
FROM python:3.9-slim-buster AS builder

# Set the working directory inside the container. All subsequent commands run here.
WORKDIR /app

# Best practice: Upgrade pip to the latest version inside the container.
RUN pip install --upgrade pip

# Copy ONLY the requirements file first.
# This leverages Docker's layer caching. If requirements.txt doesn't change,
# Docker will reuse the cached result of the next step, making builds much faster.
COPY requirements.txt .

# Create pre-compiled "wheels" for all our dependencies. This makes the
# final installation in the next stage faster and more reliable.
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# --- Stage 2: The "Final" Production Stage ---
# Start from a fresh, clean base image again. This ensures no build tools
# or temporary files from the builder stage are included in our final image.
FROM python:3.9-slim-buster

# Set the working directory.
WORKDIR /app

# Copy the pre-compiled wheels from the "builder" stage.
COPY --from=builder /wheels /wheels

# Copy the requirements file from the "builder" stage.
COPY --from=builder /app/requirements.txt .

# Install all dependencies from the local wheels. This is much faster
# than downloading them from the internet again.
RUN pip install --no-cache-dir /wheels/*

# Now, copy our actual application code into the container.
# This is done last. If we only change our Python code, Docker will
# reuse all the previous cached layers, resulting in a near-instant build.
COPY . .

# The command to run when the container starts.
# We tell uvicorn to run our 'main:app' application.
# --host 0.0.0.0 is ESSENTIAL. It tells the server to listen on all network
# interfaces inside the container, making it accessible from the outside.
# --port 8000 is the port we will expose.
# We do NOT use --reload in production.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]