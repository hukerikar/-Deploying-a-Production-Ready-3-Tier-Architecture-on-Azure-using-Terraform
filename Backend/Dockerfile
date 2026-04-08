FROM python:3.12-slim

# Avoid Python buffering logs
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code
COPY . .

# Expose FastAPI port
EXPOSE 8000

# Run backend
CMD ["uvicorn", "backend:app", "--host", "0.0.0.0", "--port", "8000"]
