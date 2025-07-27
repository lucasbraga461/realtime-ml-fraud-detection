FROM python:3.12.3-slim

WORKDIR /app

COPY . .

# Install system dependencies required for TensorFlow
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv venv
ENV PATH="/app/venv/bin:$PATH"

# Install Python requirements
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Corrected gunicorn CMD syntax (fixed --timeout)
CMD ["gunicorn", "--bind", "0.0.0.0:8502", "wsgi:app", "--timeout", "120", "--workers=3"]
# docker build -t flask-cnn-app .
# docker run -d -p 8502:8502 flask-cnn-app