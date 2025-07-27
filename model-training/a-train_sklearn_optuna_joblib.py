import numpy as np
import pandas as pd
import os
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import f1_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import LogisticRegression
from lightgbm import LGBMClassifier
import xgboost as xgb
import optuna
import joblib

# Configuration
HOME = '/Users/lucasbraga/Documents/GitHub/fraud-research/'
MODEL_FOLDER = 'models2deploy-td-mlmodels'
TUNE_HYPERPARAMETERS = True
PARAMS_PATH = os.path.join(HOME, 'models', MODEL_FOLDER, 'best_params.pkl')

def load_data():
    df = pd.read_csv(f'{HOME}/data/european_creditcard.csv')
    print(f"Data shape: {df.shape}")

    # Feature engineering: hour_of_day instead of Time
    df['hour_of_day'] = (df['Time'] % (24 * 3600)) // 3600
    df.drop('Time', axis=1, inplace=True)

    X = df.drop(['Class'], axis=1)
    y = df['Class']

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y, test_size=0.3, random_state=42, stratify=y)

    undersample_idx = np.random.choice(len(X_train), size=len(X_train)//2, replace=False)
    X_train, y_train = X_train[undersample_idx], y_train.iloc[undersample_idx]

    return X_train, X_test, y_train, y_test, X.columns

def optimize_model(model, param_space, X, y):
    def objective(trial):
        params = {k: trial.suggest_categorical(k, v) if isinstance(v, list) else trial.suggest_float(k, *v) for k, v in param_space.items()}
        model.set_params(**params)
        model.fit(X, y)
        preds = model.predict(X)
        return f1_score(y, preds)

    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=20)
    return study.best_params

if __name__ == '__main__':
    X_train, X_test, y_train, y_test, _ = load_data()

    models = {
        'DecisionTree': DecisionTreeClassifier(random_state=42),
        'RandomForest': RandomForestClassifier(random_state=42),
        'LogisticRegression': LogisticRegression(max_iter=1000, random_state=42),
        'XGBoost': xgb.XGBClassifier(random_state=42, eval_metric='logloss'),
        'LightGBM': LGBMClassifier(random_state=42)
    }

    param_spaces = {
        'DecisionTree': {'max_depth': [5,10,15,20]},
        'RandomForest': {'n_estimators': [50,100,200], 'max_depth': [5,10,15]},
        'LogisticRegression': {'C': [0.1, 1.0, 10.0]},
        'XGBoost': {'max_depth': [3,5,7], 'learning_rate': [0.01,0.1,0.3]},
        'LightGBM': {'num_leaves': [31,50,70], 'learning_rate': [0.01,0.05,0.1]}
    }

    best_params = {}
    for name, model in models.items():
        print(f"Tuning {name}...")
        params = optimize_model(model, param_spaces[name], X_train, y_train)
        model.set_params(**params).fit(X_train, y_train)
        preds = model.predict(X_test)
        print(f"{name} F1-score: {f1_score(y_test, preds):.4f}")

        model_path = os.path.join(HOME, 'models', MODEL_FOLDER, f'{name}_model.pkl')
        joblib.dump(model, model_path)
        
        best_params[name] = params
        joblib.dump(best_params, PARAMS_PATH)
