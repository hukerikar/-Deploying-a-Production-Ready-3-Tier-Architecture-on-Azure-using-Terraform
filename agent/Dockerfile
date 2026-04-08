# Use lightweight Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install required system packages
RUN apt-get update && apt-get install -y \
    procps \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY agent.py .



# Environment variable (backend URL)
ENV BACKEND_URL="http://10.0.3.4:8080/logs"

# Run the agent
CMD ["python", "-u", "agent.py"]