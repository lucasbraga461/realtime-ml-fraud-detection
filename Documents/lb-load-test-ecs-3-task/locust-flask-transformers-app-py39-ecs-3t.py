# numpy==1.26.0
# pandas==2.2.3
# scikit-learn==1.4.2
# locust==2.26.0
# requests==2.32.3

import random
import json
import os
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from locust import HttpUser, task, constant, LoadTestShape

# Configuration flags
IS_WARM_UP = False  # Set to True for warm-up only, False for full load test

# Adjust the host to your Flask CNN, LSTM, Transformers Docker app endpoint
# API_HOST = "http://localhost:8502"  # Use your actual deployed Flask app URL
API_HOST = "http://flask-transformers-app-py39-alb-164899558.eu-central-1.elb.amazonaws.com"
AUTH_FILE_PATH = '/home/ec2-user/Documents/config/auth_flask.json'
DATA_FILE_PATH = '/home/ec2-user/Documents/data/european_creditcard.csv'

USE_REAL_DATA = True  # Set to False to generate random payloads instead

# Load credentials
with open(AUTH_FILE_PATH, 'r') as f:
    auth_data = json.load(f)
    api_username = auth_data['prod']['user']
    api_password = auth_data['prod']['password']

# Load and preprocess real dataset (always needed to fit scaler)
df = pd.read_csv(DATA_FILE_PATH)
df['hour_of_day'] = (df['Time'] % (24 * 3600)) // 3600
df.drop(['Time', 'Class'], axis=1, inplace=True)

scaler = StandardScaler()
scaler.fit(df)  # Fit scaler on the original data to reuse the transformation

if USE_REAL_DATA:
    scaled_features = scaler.transform(df)
    df_scaled = pd.DataFrame(scaled_features, columns=df.columns)
    real_data_rows = df_scaled.to_dict(orient='records')
    print(f"Loaded {len(real_data_rows)} rows from the real dataset (scaled).")

def generate_api_payload():
    """
    Generate API payload either from real dataset or scaled random data.
    """
    if USE_REAL_DATA:
        payload = random.choice(real_data_rows)
    else:
        # Generate random data for all 30 numeric features
        random_row = {
            **{f"V{i}": random.uniform(-3, 3) for i in range(1, 29)},
            "Amount": random.uniform(0, 5000),
            "hour_of_day": random.randint(0, 23)
        }
        # Scale the randomly generated row exactly as done during training
        random_row_df = pd.DataFrame([random_row])
        scaled_row = scaler.transform(random_row_df)
        payload = dict(zip(random_row_df.columns, scaled_row[0]))

    return payload

class AuthenticatedAPIUser(HttpUser):
    host = API_HOST
    wait_time = constant(0)

    @task
    def call_predict_endpoint(self):
        payload_data = generate_api_payload()
        with self.client.post(
            "/predict",
            json=payload_data,
            auth=(api_username, api_password),
            catch_response=True
        ) as response:
            if response.status_code == 200:
                try:
                    if "score" in response.json():
                        response.success()
                        # print(f"Response: {response.json()}")
                    else:
                        response.failure("Response JSON missing 'score'")
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            else:
                response.failure(f"Error {response.status_code}: {response.text[:150]}")

# Staged Load Shape (optional, adjust if needed)
class StagedLoadShape(LoadTestShape):
    def __init__(self):
        super().__init__()
        if IS_WARM_UP:
            # Warm-up only configuration
            self.stages = [
                {"duration": 600, "users": 60, "spawn_rate": 20}, # Heavy Warm-up (10 min) so that the actual load test can start with 3 tasks already running
            ]
        else:
            # Full load test configuration
            self.stages = [
                {"duration": 60, "users": 5, "spawn_rate": 5},    # Warm-up (60 sec)
                {"duration": 360, "users": 25, "spawn_rate": 10}, # Moderate load (5 mins)
                {"duration": 240, "users": 60, "spawn_rate": 20}, # Peak load (4 mins)
                {"duration": 60, "users": 5, "spawn_rate": 10},   # Ramp-down (1 min)
            ]

    def tick(self):
        run_time = self.get_run_time()
        total_time = 0
        for stage in self.stages:
            total_time += stage["duration"]
            if run_time < total_time:
                return stage["users"], stage["spawn_rate"]
        return None


# --- How to Run ---
# locust -f locustfile.py
# http://localhost:8089 (or the address Locust prints)

