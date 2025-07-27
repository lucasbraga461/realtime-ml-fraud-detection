from flask import Flask, render_template, request, jsonify
from flask_httpauth import HTTPBasicAuth
import numpy as np
import json
import logging
import tensorflow as tf

# Load model and load Auth keys
HOME_PATH = '.'
PATH_MODEL = f'{HOME_PATH}/models/LSTM.keras'
PATH_AUTH = f'{HOME_PATH}/config/auth_flask.json'

try:
    model = tf.keras.models.load_model(PATH_MODEL)
    logging.info(f"Model loaded successfully from {PATH_MODEL}")
except FileNotFoundError:
    logging.error(f"Model folder not found at {PATH_MODEL}")
    raise
except Exception as e:
    logging.error(f"Error loading model: {str(e)}")
    raise

try:
    with open(PATH_AUTH, 'r') as file:
        users = json.load(file)
except FileNotFoundError:
    logging.error(f"Auth file not found at {PATH_AUTH}")
    raise
except Exception as e:
    logging.error(f"Error loading auth file: {str(e)}")
    raise

app = Flask('LSTM Transaction Scoring')
auth = HTTPBasicAuth()

# Setup logging
logging.basicConfig(filename='logs/flask.log', level=logging.DEBUG, format='%(asctime)s %(message)s')

@app.before_request
def log_request_info():
    logging.debug(f"Headers: {request.headers}")
    logging.debug(f"Body: {request.get_data()}")

@auth.verify_password
def verify_password(username, password):
    logging.debug(f"Auth attempt with username={username}")
    if username == users['prod']['user'] and password == users['prod']['password']:
        logging.debug("Authentication successful")
        return username
    logging.warning(f"Failed auth attempt with username={username}")

# Setup predict function
@app.route('/predict', methods=['POST'])
@auth.login_required
def predict():
    try:
        data_input = request.get_json()
        if not data_input:
            raise ValueError("No input data provided")

        # Assuming input is a flat dictionary of 30 features
        input_array = np.array(list(data_input.values()))

        # LSTM expects shape (batch_size, 30, 1)
        reshaped_input = input_array.reshape(-1, 30, 1)

        prediction_proba = model.predict(reshaped_input)
        predicted_probability = float(prediction_proba[0][0])

        result = {
            'model_name': 'LSTM_model',
            'score': predicted_probability
        }
        logging.debug(f"Prediction result: {result}")
        return jsonify(result), 200

    except Exception as e:
        logging.error(f"Error during prediction: {str(e)}")
        return jsonify({"error": str(e)}), 400

@app.route('/', methods=['GET'])
def home():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8502, debug=True)
