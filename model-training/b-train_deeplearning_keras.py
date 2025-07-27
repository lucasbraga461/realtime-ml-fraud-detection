import numpy as np
import pandas as pd
import os
import joblib
import tensorflow as tf
from tensorflow.keras.models import Sequential, Model, load_model
from tensorflow.keras.layers import (Conv2D, MaxPooling2D, Flatten, Dense, LSTM, 
                                     Input, Conv1D, GlobalAveragePooling1D, Dropout, 
                                     LayerNormalization, Add, MultiHeadAttention)
from tensorflow.keras.callbacks import EarlyStopping
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, roc_auc_score, precision_recall_curve, f1_score

HOME = '/Users/lucasbraga/Documents/GitHub/fraud-research/'
MODEL_FOLDER = os.path.join(HOME, 'models', 'models2deploy-dl')
os.makedirs(MODEL_FOLDER, exist_ok=True)

def load_data():
    df = pd.read_csv(f'{HOME}/data/european_creditcard.csv')
    df['hour_of_day'] = (df['Time'] % (24 * 3600)) // 3600
    df.drop('Time', axis=1, inplace=True)

    X = df.drop('Class', axis=1)
    y = df['Class']

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    X_train, X_temp, y_train, y_temp = train_test_split(
        X_scaled, y, test_size=0.3, random_state=42, stratify=y)
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp)

    return (X_train, y_train), (X_val, y_val), (X_test, y_test)

# Model definitions

def create_cnn(input_shape):
    model = Sequential([
        Conv2D(32, (2,2), activation='relu', input_shape=input_shape),
        MaxPooling2D((2,2)),
        Flatten(),
        Dense(64, activation='relu'),
        Dense(1, activation='sigmoid')
    ])
    model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
    return model

def create_lstm(input_shape):
    model = Sequential([
        LSTM(64, input_shape=input_shape),
        Dense(32, activation='relu'),
        Dense(1, activation='sigmoid')
    ])
    model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
    return model

def transformer_encoder(inputs, head_size, num_heads, ff_dim, dropout=0.1):
    x = MultiHeadAttention(key_dim=head_size, num_heads=num_heads, dropout=dropout)(inputs, inputs)
    x = Dropout(dropout)(x)
    x = Add()([inputs, x])
    x = LayerNormalization()(x)

    x_ff = Conv1D(filters=ff_dim, kernel_size=1, activation="relu")(x)
    x_ff = Dropout(dropout)(x_ff)
    x_ff = Conv1D(filters=inputs.shape[-1], kernel_size=1)(x_ff)
    x = Add()([x, x_ff])
    return LayerNormalization()(x)

def create_transformer(input_shape):
    inputs = Input(shape=input_shape)
    x = transformer_encoder(inputs, head_size=32, num_heads=2, ff_dim=64)
    x = GlobalAveragePooling1D()(x)
    x = Dense(64, activation="relu")(x)
    outputs = Dense(1, activation="sigmoid")(x)

    model = Model(inputs, outputs)
    model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
    return model

# Threshold optimization
def best_threshold(y_true, y_proba):
    precision, recall, thresholds = precision_recall_curve(y_true, y_proba)
    f1_scores = 2 * recall * precision / (recall + precision + 1e-10)
    best_idx = np.argmax(f1_scores)
    return thresholds[best_idx], f1_scores[best_idx]

# Training & Evaluation
def train_and_save_model(model, X_train, y_train, X_val, y_val, X_test, y_test, model_name):
    early_stop = EarlyStopping(monitor='val_loss', patience=3, restore_best_weights=True)
    model.fit(X_train, y_train, epochs=10, batch_size=64, validation_data=(X_val, y_val), callbacks=[early_stop])

    y_proba = model.predict(X_test).ravel()
    threshold, best_f1 = best_threshold(y_test, y_proba)
    y_pred = (y_proba >= threshold).astype(int)
    
    report = classification_report(y_test, y_pred, zero_division=0)
    print(f"{model_name} Best Threshold: {threshold:.4f}\n{model_name} Best F1-score: {best_f1:.4f}\n{report}")

    model.save(os.path.join(MODEL_FOLDER, f"{model_name}.keras"))
    model.export(os.path.join(MODEL_FOLDER, f"{model_name}/1/")) #Sagemaker likes this format

if __name__ == '__main__':
    (X_train, y_train), (X_val, y_val), (X_test, y_test) = load_data()

    # Prepare data shapes
    X_train_cnn = X_train.reshape(-1, 5, 6, 1)
    X_val_cnn = X_val.reshape(-1, 5, 6, 1)
    X_test_cnn = X_test.reshape(-1, 5, 6, 1)

    X_train_seq = X_train.reshape(-1, 30, 1)
    X_val_seq = X_val.reshape(-1, 30, 1)
    X_test_seq = X_test.reshape(-1, 30, 1)

    # CNN
    cnn_model = create_cnn((5,6,1))
    train_and_save_model(cnn_model, X_train_cnn, y_train, X_val_cnn, y_val, X_test_cnn, y_test, 'CNN')

    # LSTM
    lstm_model = create_lstm((30,1))
    train_and_save_model(lstm_model, X_train_seq, y_train, X_val_seq, y_val, X_test_seq, y_test, 'LSTM')

    # Transformer
    transformer_model = create_transformer((30,1))
    train_and_save_model(transformer_model, X_train_seq, y_train, X_val_seq, y_val, X_test_seq, y_test, 'Transformer')
