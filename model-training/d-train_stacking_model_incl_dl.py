import numpy as np
import pandas as pd
import os
import joblib
import tensorflow as tf
from sklearn.metrics import classification_report, precision_recall_curve, f1_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
import xgboost as xgb
import optuna

# Configuration explicitly
META_LEARNER_NAME = 'random_forest'  # 'xgboost' or 'random_forest'
HOME = '/Users/lucasbraga/Documents/GitHub/fraud-research/'
BASE_MODEL_FOLDER = os.path.join(HOME, 'models', 'models2deploy-td-mlmodels')
DL_MODEL_FOLDER = os.path.join(HOME, 'models', 'models2deploy-dl')
STACKING_MODEL_FOLDER = os.path.join(HOME, 'models', 'stacking-model-dl')
os.makedirs(STACKING_MODEL_FOLDER, exist_ok=True)

TUNE_META_HYPERPARAMETERS = True
META_PARAMS_PATH = os.path.join(STACKING_MODEL_FOLDER, f'best_meta_params_{META_LEARNER_NAME}_dl.pkl')

# Load data explicitly
def load_data():
    df = pd.read_csv(f'{HOME}/data/european_creditcard.csv')
    df['hour_of_day'] = (df['Time'] % (24 * 3600)) // 3600
    df.drop('Time', axis=1, inplace=True)

    X = df.drop('Class', axis=1)
    y = df['Class']

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    X_train_full, X_test, y_train_full, y_test = train_test_split(
        X_scaled, y, test_size=0.3, random_state=42, stratify=y)

    return X_train_full, X_test, y_train_full, y_test

# Load traditional ML models explicitly
def load_traditional_models():
    models = {}
    names = ['DecisionTree', 'RandomForest', 'LogisticRegression', 'XGBoost', 'LightGBM']
    for name in names:
        path = os.path.join(BASE_MODEL_FOLDER, f'{name}_model.pkl')
        models[name] = joblib.load(path)
    return models

# Load CNN and LSTM explicitly
def load_dl_models():
    cnn_model = tf.keras.models.load_model(os.path.join(DL_MODEL_FOLDER, 'CNN.keras'))
    lstm_model = tf.keras.models.load_model(os.path.join(DL_MODEL_FOLDER, 'LSTM.keras'))
    return {'CNN': cnn_model, 'LSTM': lstm_model}

# Generate meta-features explicitly
def generate_meta_features(ml_models, dl_models, X):
    meta_features_ml = np.column_stack([model.predict_proba(X)[:, 1] for model in ml_models.values()])

    X_cnn = X.reshape(-1, 5, 6, 1)
    X_lstm = X.reshape(-1, 30, 1)
    meta_features_dl = np.column_stack([
        dl_models['CNN'].predict(X_cnn).ravel(),
        dl_models['LSTM'].predict(X_lstm).ravel()
    ])

    return np.hstack((meta_features_ml, meta_features_dl))

# Optimize meta-learner with Optuna explicitly
def optimize_meta_model(X_train, y_train, X_val, y_val, meta_learner_name='random_forest'):
    def objective(trial):
        if meta_learner_name == 'xgboost':
            params = {
                'max_depth': trial.suggest_int('max_depth', 3, 10),
                'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True),
                'n_estimators': trial.suggest_int('n_estimators', 50, 200)
            }
            model = xgb.XGBClassifier(**params, eval_metric='logloss', random_state=42)
        else:
            params = {
                'n_estimators': trial.suggest_int('n_estimators', 50, 200),
                'max_depth': trial.suggest_int('max_depth', 3, 20)
            }
            model = RandomForestClassifier(**params, random_state=42)

        model.fit(X_train, y_train)
        preds = model.predict(X_val)
        return f1_score(y_val, preds)

    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=20)
    return study.best_params

# Find best threshold explicitly
def best_threshold(y_true, y_proba):
    precision, recall, thresholds = precision_recall_curve(y_true, y_proba)
    f1_scores = 2 * recall * precision / (recall + precision + 1e-10)
    best_idx = np.argmax(f1_scores)
    return thresholds[best_idx], f1_scores[best_idx]

# Train stacking model explicitly
def train_stacking_model(X_train_meta, y_train, X_test_meta, y_test, params, meta_learner_name='random_forest'):
    if meta_learner_name == 'xgboost':
        meta_model = xgb.XGBClassifier(**params, eval_metric='logloss', random_state=42)
    else:
        meta_model = RandomForestClassifier(**params, random_state=42)

    meta_model.fit(X_train_meta, y_train)
    y_proba = meta_model.predict_proba(X_test_meta)[:, 1]
    optimal_threshold, best_f1 = best_threshold(y_test, y_proba)

    y_pred = (y_proba >= optimal_threshold).astype(int)
    print(f"Optimal Threshold: {optimal_threshold:.4f}")
    print(classification_report(y_test, y_pred))

    return meta_model, optimal_threshold

# Main execution explicitly
if __name__ == '__main__':
    X_train_full, X_test, y_train_full, y_test = load_data()
    X_train, X_val, y_train, y_val = train_test_split(
        X_train_full, y_train_full, test_size=0.2, random_state=42, stratify=y_train_full)

    ml_models = load_traditional_models()
    dl_models = load_dl_models()

    X_train_meta = generate_meta_features(ml_models, dl_models, X_train)
    X_val_meta = generate_meta_features(ml_models, dl_models, X_val)
    X_test_meta = generate_meta_features(ml_models, dl_models, X_test)

    if TUNE_META_HYPERPARAMETERS:
        best_params = optimize_meta_model(X_train_meta, y_train, X_val_meta, y_val, META_LEARNER_NAME)
        joblib.dump(best_params, META_PARAMS_PATH)
    else:
        best_params = joblib.load(META_PARAMS_PATH)

    print(f'Best meta-learner params explicitly: {best_params}')

    meta_model, optimal_threshold = train_stacking_model(
        X_train_meta, y_train, X_test_meta, y_test, best_params, META_LEARNER_NAME)

    model_save_path = os.path.join(STACKING_MODEL_FOLDER, f'stacking_model_{META_LEARNER_NAME}_dl.pkl')
    joblib.dump((meta_model, optimal_threshold), model_save_path)

    print(f"Meta-model and threshold explicitly saved at: {model_save_path}")
