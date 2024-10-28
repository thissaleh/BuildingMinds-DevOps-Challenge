# First Stage: Builder - Install dependencies
# Use build argument for the Python version
ARG PYTHON_VERSION=3.8
FROM python:${PYTHON_VERSION} AS builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8

# Set the working directory
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN python -m pip install --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements.txt

# Copy the Kafka producer and health check scripts to the container
COPY producer.py .
COPY health_check.py .


# Second Stage: Final Image - Use minimal runtime image
FROM python:${PYTHON_VERSION} AS final

# Set environment variables 
ENV PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8

    # Copy installed dependencies from the builder stage
COPY --from=builder /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy only the necessary files from the builder stage
COPY --from=builder /app /app

# Set the working directory and specify non-root user for security
WORKDIR /app
RUN useradd -m appuser

# Set permissions for application files
RUN chown -R appuser:appuser /app && chmod -R 755 /app

USER appuser

# Set the command for the final container

# CMD ["python", "producer.py"]

# To keep container running for live-testing purpose only
CMD ["sleep", "infinity"]  
