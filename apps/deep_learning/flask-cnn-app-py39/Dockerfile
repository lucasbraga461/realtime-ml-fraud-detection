FROM python:3.9.12

WORKDIR /app

COPY . .

# Create a virtual environment, activate and install the requirements
RUN python -m venv venv
ENV PATH="/app/venv/bin:$PATH"
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

CMD ["gunicorn", "--bind", "0.0.0.0:8502", "wsgi:app", "timeout", "120", "--workers=3"]
# docker build -t flask-cnn-app .
# docker run -d -p 8502:8502 flask-cnn-app