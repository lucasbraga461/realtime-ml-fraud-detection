#!/usr/bin/env python3
"""
Simple Model API Call Script
============================
This script loads the European credit card dataset, preprocesses it exactly like 
the locust file, makes a single API call, and prints the response payload.

Based on: locustfile-european-td_n_dl_models.py
"""

import random
import json
import pandas as pd
import numpy as np
import requests
from sklearn.preprocessing import StandardScaler

# Configuration
# API_HOST = "http://3.76.115.39:8502"
API_HOST = "http://18.196.80.29:8502"
AUTH_FILE_PATH = '/home/ec2-user/Documents/config/auth_flask.json'
DATA_FILE_PATH = '/home/ec2-user/Documents/data/european_creditcard.csv'

USE_REAL_DATA = True  # Set to False to generate random payloads instead

def load_credentials():
    """Load API credentials from auth file."""
    try:
        with open(AUTH_FILE_PATH, 'r') as f:
            auth_data = json.load(f)
            api_username = auth_data['prod']['user']
            api_password = auth_data['prod']['password']
            print("✓ Credentials loaded successfully")
            return api_username, api_password
    except Exception as e:
        print(f"Error loading credentials: {e}")
        return None, None

def load_and_preprocess_data():
    """Load and preprocess the European credit card dataset."""
    try:
        print("Loading European credit card dataset...")
        df = pd.read_csv(DATA_FILE_PATH)
        print(f"✓ Dataset loaded: {df.shape[0]} rows, {df.shape[1]} columns")
        
        # Preprocess exactly like the locust file
        df['hour_of_day'] = (df['Time'] % (24 * 3600)) // 3600
        df.drop(['Time', 'Class'], axis=1, inplace=True)
        print("✓ Added hour_of_day feature and removed Time/Class columns")
        
        # Fit scaler on the original data
        scaler = StandardScaler()
        scaler.fit(df)
        print("✓ Scaler fitted on preprocessed data")
        
        if USE_REAL_DATA:
            scaled_features = scaler.transform(df)
            df_scaled = pd.DataFrame(scaled_features, columns=df.columns)
            real_data_rows = df_scaled.to_dict(orient='records')
            print(f"✓ Generated {len(real_data_rows)} scaled data samples")
            return real_data_rows, scaler, df.columns
        else:
            return None, scaler, df.columns
            
    except Exception as e:
        print(f"Error loading/preprocessing data: {e}")
        return None, None, None

def generate_api_payload(real_data_rows, scaler, columns):
    """Generate API payload either from real dataset or scaled random data."""
    if USE_REAL_DATA and real_data_rows:
        payload = random.choice(real_data_rows)
        print("✓ Using real data sample")
    else:
        print("✓ Generating random data sample")
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

def make_api_call(payload, api_username, api_password):
    """Make a single API call and return the response."""
    predict_url = f"{API_HOST}/predict"
    
    print(f"\nMaking API call to: {predict_url}")
    print("="*60)
    
    try:
        response = requests.post(
            predict_url,
            json=payload,
            auth=(api_username, api_password),
            timeout=30
        )
        
        print(f"Response Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            try:
                response_data = response.json()
                print("✓ Successfully received JSON response")
                return response_data, True
            except json.JSONDecodeError as e:
                print(f"✗ Failed to parse JSON response: {e}")
                print(f"Raw response text: {response.text}")
                return response.text, False
        else:
            print(f"✗ HTTP Error {response.status_code}")
            print(f"Response text: {response.text}")
            return None, False
            
    except requests.exceptions.RequestException as e:
        print(f"✗ Request failed: {e}")
        return None, False

def print_payload_analysis(payload):
    """Print detailed analysis of the request payload."""
    print("\nREQUEST PAYLOAD ANALYSIS")
    print("="*60)
    print(f"Total features: {len(payload)}")
    print(f"Payload size: {len(json.dumps(payload))} characters")
    
    # Show first few features
    print("\nFirst 5 features:")
    for i, (key, value) in enumerate(payload.items()):
        if i < 5:
            print(f"  {key}: {value:.6f}")
        else:
            break
    
    # Show last few features  
    print("\nLast 5 features:")
    items = list(payload.items())
    for key, value in items[-5:]:
        print(f"  {key}: {value:.6f}")
    
    # Statistics
    values = list(payload.values())
    print(f"\nPayload Statistics:")
    print(f"  Min value: {min(values):.6f}")
    print(f"  Max value: {max(values):.6f}")
    print(f"  Mean value: {np.mean(values):.6f}")
    print(f"  Std dev: {np.std(values):.6f}")

def print_response_analysis(response_data):
    """Print detailed analysis of the API response."""
    print("\nAPI RESPONSE ANALYSIS")
    print("="*60)
    
    if isinstance(response_data, dict):
        print("Response type: JSON Dictionary")
        print(f"Response keys: {list(response_data.keys())}")
        
        # Print each key-value pair
        for key, value in response_data.items():
            print(f"  {key}: {value} (type: {type(value).__name__})")
        
        # Check for expected fields
        print(f"\nExpected Fields Check:")
        print(f"  'model_name' present: {'model_name' in response_data}")
        print(f"  'score' present: {'score' in response_data}")
        
        if 'model_name' in response_data:
            print(f"  Model Name: '{response_data['model_name']}'")
        
        if 'score' in response_data:
            score = response_data['score']
            print(f"  Score: {score} (type: {type(score).__name__})")
            if isinstance(score, (int, float)):
                print(f"  Score range check: {'✓ Valid' if 0 <= score <= 1 else '⚠ Outside [0,1]'}")
    
    else:
        print(f"Response type: {type(response_data).__name__}")
        print(f"Response content: {response_data}")

def main():
    """Main function to run the simple model call."""
    print("Simple Model API Call Script")
    print("="*60)
    
    # Load credentials
    api_username, api_password = load_credentials()
    if not api_username or not api_password:
        print("Cannot proceed without valid credentials")
        return
    
    # Load and preprocess data
    real_data_rows, scaler, columns = load_and_preprocess_data()
    if scaler is None:
        print("Cannot proceed without data preprocessing")
        return
    
    # Generate payload
    print(f"\nGenerating API payload...")
    payload = generate_api_payload(real_data_rows, scaler, columns)
    
    # Print payload analysis
    print_payload_analysis(payload)
    
    # Make API call
    response_data, success = make_api_call(payload, api_username, api_password)
    
    # Print response analysis
    if success and response_data is not None:
        print_response_analysis(response_data)
        
        # Pretty print the full response
        print(f"\nFULL API RESPONSE")
        print("="*60)
        if isinstance(response_data, dict):
            print(json.dumps(response_data, indent=2, default=str))
        else:
            print(response_data)
    else:
        print("\n✗ API call failed - no response to analyze")
    
    print(f"\nScript completed!")

if __name__ == "__main__":
    main() 