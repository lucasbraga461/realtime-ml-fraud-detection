from flask import Flask, render_template, request, jsonify
from flask_httpauth import HTTPBasicAuth
import numpy as np
import json
import logging
import joblib
import os
import tensorflow as tf

# Configuration explicitly
HOME_PATH = '.'
STACKING_MODEL_FOLDER = f'{HOME_PATH}/models/stacking-model-dl'
BASE_MODEL_FOLDER = f'{HOME_PATH}/models/models2deploy-td-mlmodels'
DL_MODEL_FOLDER = f'{HOME_PATH}/models/models2deploy-dl'
PATH_MODEL = os.path.join(STACKING_MODEL_FOLDER, 'stacking_model_random_forest_dl.pkl')
PATH_AUTH = f'{HOME_PATH}/config/auth_flask.json'

# Load stacking model (meta-model and optimal threshold)
try:
    model, optimal_threshold = joblib.load(PATH_MODEL)
    logging.info(f"Stacking model loaded successfully from {PATH_MODEL}")
    logging.info(f"Optimal threshold: {optimal_threshold}")
except Exception as e:
    logging.error(f"Error loading stacking model: {str(e)}")
    raise

# Load traditional base models explicitly
base_model_names = ['DecisionTree', 'RandomForest', 'LogisticRegression', 'XGBoost', 'LightGBM']
base_models = {}
for name in base_model_names:
    try:
        base_models[name] = joblib.load(os.path.join(BASE_MODEL_FOLDER, f'{name}_model.pkl'))
        logging.info(f"Base model '{name}' loaded successfully.")
    except Exception as e:
        logging.error(f"Error loading base model '{name}': {str(e)}")
        raise

# Load DL models explicitly
try:
    cnn_model = tf.keras.models.load_model(os.path.join(DL_MODEL_FOLDER, 'CNN.keras'))
    lstm_model = tf.keras.models.load_model(os.path.join(DL_MODEL_FOLDER, 'LSTM.keras'))
    logging.info("DL models loaded successfully.")
except Exception as e:
    logging.error(f"Error loading DL models: {str(e)}")
    raise

# Load authentication
try:
    with open(PATH_AUTH, 'r') as file:
        users = json.load(file)
except Exception as e:
    logging.error(f"Error loading auth file: {str(e)}")
    raise

app = Flask('Stacking DL Transaction Scoring')
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

# Setup predict function explicitly for stacking with DL
@app.route('/predict', methods=['POST'])
@auth.login_required
def predict():
    try:
        data_input = request.get_json()
        if not data_input:
            raise ValueError("No input data provided")

        input_array = np.array(list(data_input.values())).reshape(1, -1)

        # Generate meta-features explicitly from traditional ML models
        meta_features_ml = np.column_stack([
            base_models[name].predict_proba(input_array)[:, 1] for name in base_model_names
        ])

        # Generate meta-features explicitly from DL models
        X_cnn = input_array.reshape(-1, 5, 6, 1)
        X_lstm = input_array.reshape(-1, 30, 1)
        meta_features_dl = np.column_stack([
            cnn_model.predict(X_cnn).ravel(),
            lstm_model.predict(X_lstm).ravel()
        ])

        # Combine meta-features explicitly
        meta_features = np.hstack((meta_features_ml, meta_features_dl))

        # Predict with stacking meta-model explicitly
        stacking_proba = model.predict_proba(meta_features)[0, 1]
        predicted_label = int(stacking_proba >= optimal_threshold)

        result = {
            'model_name': 'Stacking_RF_DL_model',
            'score': stacking_proba,
            'prediction': predicted_label,
            'threshold': optimal_threshold
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
