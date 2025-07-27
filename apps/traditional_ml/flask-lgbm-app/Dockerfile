FROM python:3.12.3-slim

WORKDIR /app

COPY . .

# Install required system libraries explicitly
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgomp1 && \
    rm -rf /var/lib/apt/lists/*

# Create a virtual environment, activate and install the requirements
RUN python -m venv venv
ENV PATH="/app/venv/bin:$PATH"

RUN pip install --upgrade pip && \
    pip install -r requirements.txt

CMD ["gunicorn", "--bind", "0.0.0.0:8502", "wsgi:app", "--timeout", "120", "--workers=3"]
# docker build -t flask-lgbm-app .
# docker run -d -p 8502:8502 flask-lgbm-app