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
import joblib

# Configuration
HOME = '/Users/lucasbraga/Documents/GitHub/fraud-research/'
MODEL_FOLDER = 'models2deploy-td-mlmodels-defaultparams'
TUNE_HYPERPARAMETERS = False
# PARAMS_PATH = os.path.join(HOME, 'models', 'models2deploy-td-mlmodels', 'best_params.pkl')
os.makedirs(os.path.join(HOME, 'models', MODEL_FOLDER), exist_ok=True)

def load_data():
    df = pd.read_csv(f'{HOME}/data/european_creditcard.csv')
    print(f"Data shape: {df.shape}")

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

if __name__ == '__main__':
    X_train, X_test, y_train, y_test, _ = load_data()

    models = {
        'DecisionTree': DecisionTreeClassifier(random_state=42),
        'RandomForest': RandomForestClassifier(random_state=42),
        'LogisticRegression': LogisticRegression(max_iter=1000, random_state=42),
        'XGBoost': xgb.XGBClassifier(random_state=42, eval_metric='logloss'),
        'LightGBM': LGBMClassifier(random_state=42)
    }

    # Don't load params; train with default parameters
    best_params = {name: {} for name in models.keys()}

    for name, model in models.items():
        print(f"Training {name} with default parameters...")
        params = best_params.get(name, {})
        model.set_params(**params).fit(X_train, y_train)

        preds = model.predict(X_test)
        f1 = f1_score(y_test, preds)
        print(f"{name} F1-score: {f1:.4f}")

        model_path = os.path.join(HOME, 'models', MODEL_FOLDER, f'{name}_model.pkl')
        joblib.dump(model, model_path)
