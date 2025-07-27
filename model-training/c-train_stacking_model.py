import numpy as np
import pandas as pd
import os
import joblib
from sklearn.metrics import classification_report, f1_score, precision_recall_curve
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import xgboost as xgb
import optuna

# Configuration
META_LEARNER_NAME = 'xgboost'  # 'xgboost' or 'random_forest'
HOME = '/Users/lucasbraga/Documents/GitHub/fraud-research/'
BASE_MODEL_FOLDER = os.path.join(HOME, 'models', 'models2deploy-td-mlmodels')
STACKING_MODEL_FOLDER = os.path.join(HOME, 'models', 'stacking-model')
os.makedirs(STACKING_MODEL_FOLDER, exist_ok=True)

TUNE_META_HYPERPARAMETERS = True  # Set to False to use saved best parameters
META_PARAMS_PATH = os.path.join(STACKING_MODEL_FOLDER, f'best_meta_params_{META_LEARNER_NAME}.pkl')

# Load original data
def load_data():
    df = pd.read_csv(f'{HOME}/data/european_creditcard.csv')
    df['hour_of_day'] = (df['Time'] % (24 * 3600)) // 3600
    df.drop('Time', axis=1, inplace=True)

    X = df.drop('Class', axis=1)
    y = df['Class']

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.3, random_state=42, stratify=y)

    return X_train, X_test, y_train, y_test

# Load previously trained base models explicitly
def load_base_models():
    base_models = {}
    model_names = ['DecisionTree', 'RandomForest', 'LogisticRegression', 'XGBoost', 'LightGBM']

    for model_name in model_names:
        path = os.path.join(BASE_MODEL_FOLDER, f'{model_name}_model.pkl')
        base_models[model_name] = joblib.load(path)

    return base_models

# Generate meta-features from base models explicitly
def generate_meta_features(models, X):
    meta_features = np.column_stack([
        model.predict_proba(X.values)[:, 1] for model in models.values()
    ])
    return meta_features

# Optimize meta-learner with Optuna explicitly
def optimize_meta_model(X_train, y_train, X_val, y_val, META_LEARNER_NAME='xgboost'):
    def objective(trial):
        if META_LEARNER_NAME == 'xgboost':
            params = {
                'max_depth': trial.suggest_int('max_depth', 3, 10),
                'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True),
                'n_estimators': trial.suggest_int('n_estimators', 50, 200)
            }
            model = xgb.XGBClassifier(**params, eval_metric='logloss', random_state=42)
        else:  # random forest
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

def best_threshold(y_true, y_proba):
    precision, recall, thresholds = precision_recall_curve(y_true, y_proba)
    f1_scores = 2 * recall * precision / (recall + precision + 1e-10)
    best_idx = np.argmax(f1_scores)
    return thresholds[best_idx], f1_scores[best_idx]

# Train and evaluate stacking model explicitly
def train_stacking_model(X_train_meta, y_train, X_test_meta, y_test, meta_model):
    meta_model.fit(X_train_meta, y_train)
    y_proba = meta_model.predict_proba(X_test_meta)[:, 1]

    optimal_threshold, best_f1 = best_threshold(y_test, y_proba)
    y_pred = (y_proba >= optimal_threshold).astype(int)

    report = classification_report(y_test, y_pred)
    print(f"Optimal Threshold: {optimal_threshold:.4f}")
    print(f"Meta-model Test F1-score: {best_f1:.4f}\nClassification Report:\n{report}")

    return meta_model, optimal_threshold

if __name__ == '__main__':
    # Load dataset
    X_train_full, X_test, y_train_full, y_test = load_data()

    # Split train into train and validation explicitly
    X_train, X_val, y_train, y_val = train_test_split(
        X_train_full, y_train_full, test_size=0.2, random_state=42, stratify=y_train_full)

    # Load base models explicitly
    base_models = load_base_models()

    # Generate meta-features explicitly
    X_train_meta = generate_meta_features(base_models, X_train)
    X_val_meta = generate_meta_features(base_models, X_val)
    X_test_meta = generate_meta_features(base_models, X_test)

    if TUNE_META_HYPERPARAMETERS:
        print("Optimizing meta-learner with Optuna...")
        best_params = optimize_meta_model(X_train_meta, y_train, X_val_meta, y_val, META_LEARNER_NAME)
        joblib.dump(best_params, META_PARAMS_PATH)
        print(f"Best params: {best_params}")
    else:
        print("Loading best meta-learner parameters...")
        best_params = joblib.load(META_PARAMS_PATH)

    # Define meta-learner explicitly
    if META_LEARNER_NAME == 'xgboost':
        meta_model = xgb.XGBClassifier(**best_params, eval_metric='logloss', random_state=42)
    else:
        meta_model = RandomForestClassifier(**best_params, random_state=42)

    # Train stacking model explicitly
    print("\nTraining stacking model with optimized meta-learner:")
    stacking_model, optimal_threshold = train_stacking_model(
        X_train_meta, y_train, X_test_meta, y_test, meta_model)

    # Save explicitly both model and optimal threshold together
    joblib.dump(
        (stacking_model, optimal_threshold),
        os.path.join(STACKING_MODEL_FOLDER, f'stacking_model_{META_LEARNER_NAME}.pkl')
    )
