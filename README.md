# Real-Time Machine Learning Fraud Detection: A Comparative Study

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.9](https://img.shields.io/badge/python-3.9-blue.svg)](https://www.python.org/downloads/)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.19.0-orange.svg)](https://tensorflow.org/)
[![AWS](https://img.shields.io/badge/AWS-Infrastructure-orange.svg)](https://aws.amazon.com/)

## 📋 Project Overview

This repository contains a comprehensive research study on **Real-Time Credit Card Fraud Detection** using various Machine Learning models and deployment architectures on AWS cloud infrastructure. The project implements and compares 12 different ML/DL models across three deployment architectures to evaluate performance, scalability, and cost-effectiveness.

### 🎯 Research Objectives

- **Model Performance Comparison**: Evaluate traditional ML vs. Deep Learning approaches
- **Deployment Architecture Analysis**: Compare EC2, ECS, and ECS+ALB architectures
- **Real-Time Performance**: Measure response times and throughput under load
- **Cost-Benefit Analysis**: Assess infrastructure costs vs. performance gains
- **Scalability Assessment**: Test auto-scaling capabilities and resource utilization

## 📊 Research Paper

This project is based on the research paper:
**"A Comparative Study of ML Models and Deployment Architectures for Real-Time Credit Card Fraud Detection"**

The paper presents comprehensive findings on:
- Model accuracy and performance metrics
- Infrastructure deployment comparisons
- Load testing results and scalability analysis
- Cost optimization recommendations
- Production deployment guidelines

## 🏗️ Project Architecture

```
realtime-ml-fraud-detection/
├── apps/                          # ML Applications
│   ├── deep_learning/            # Neural Network Models
│   │   ├── flask-cnn-app/        # Convolutional Neural Networks
│   │   ├── flask-lstm-app/       # Long Short-Term Memory
│   │   └── flask-transformers-app/ # Transformer Models
│   ├── traditional_ml/           # Classical ML Models
│   │   ├── flask-lgbm-app/       # LightGBM
│   │   ├── flask-xgboost-app/    # XGBoost
│   │   └── flask-logreg-app/     # Logistic Regression
│   └── stacking_models/          # Ensemble Methods
│       ├── flask-stacking-app/   # ML Stacking
│       └── flask-stacking-dl-app/ # DL Stacking
├── model-training/               # Training Scripts
├── experiment-results/           # Performance Results
├── real-aws-deployment/         # AWS Deployment System
└── docs/                        # Documentation & Visualizations
```

## 🤖 Machine Learning Models

### Deep Learning Models
| Model | Architecture | Framework | Use Case |
|-------|-------------|-----------|----------|
| **CNN** | Convolutional Neural Network | TensorFlow/Keras | Pattern recognition in transaction sequences |
| **LSTM** | Long Short-Term Memory | TensorFlow/Keras | Temporal dependency modeling |
| **Transformer** | Attention-based architecture | TensorFlow/Keras | Complex sequence relationships |

### Traditional ML Models
| Model | Algorithm | Library | Use Case |
|-------|-----------|---------|----------|
| **LightGBM** | Gradient Boosting | LightGBM | Fast, memory-efficient boosting |
| **XGBoost** | Gradient Boosting | XGBoost | High-performance boosting |
| **Logistic Regression** | Linear classification | Scikit-learn | Baseline comparison |

### Ensemble Methods
| Model | Approach | Components | Use Case |
|-------|----------|------------|----------|
| **Stacking ML** | Meta-learning | LightGBM + XGBoost + DT | Improved generalization |
| **Stacking DL** | Hybrid ensemble | CNN + LSTM + Transformer | Deep learning combination |

## ☁️ Deployment Architectures

### 1. EC2 Single Instance
- **Use Case**: Development, testing, cost-effective deployment
- **Resources**: Single EC2 instance with auto-scaling
- **Pros**: Simple, cost-effective, full control
- **Cons**: Single point of failure, manual scaling

### 2. ECS Fargate
- **Use Case**: Serverless container deployment
- **Resources**: ECS cluster with Fargate tasks
- **Pros**: Serverless, auto-scaling, managed infrastructure
- **Cons**: Higher cost per request, cold start latency

### 3. ECS with Application Load Balancer
- **Use Case**: Production, high-availability deployment
- **Resources**: ALB + ECS cluster + auto-scaling (2-10 instances)
- **Pros**: High availability, load distribution, auto-scaling
- **Cons**: Higher complexity, additional costs

## 📈 Key Research Findings

### Model Performance
- **Best Accuracy**: Stacking models (ML + DL combinations)
- **Fastest Inference**: LightGBM and XGBoost
- **Best for Real-time**: LSTM with optimized architecture
- **Cost-Effective**: Traditional ML models

### Deployment Performance
- **Lowest Latency**: EC2 single instance
- **Best Scalability**: ECS with ALB
- **Cost Efficiency**: EC2 for low traffic, ECS+ALB for high traffic
- **Reliability**: ECS+ALB with multi-AZ deployment

### Load Testing Results
- **Throughput**: Up to 1000+ requests/second
- **Response Time**: 50-200ms average
- **Auto-scaling**: 2-10 instances based on load
- **Resource Utilization**: 60-80% CPU, 70-90% memory

## 🚀 Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform installed
- Docker installed
- Python 3.9+

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/realtime-ml-fraud-detection.git
cd realtime-ml-fraud-detection
```

### 2. Deploy an Application
```bash
cd real-aws-deployment
./dynamic_deployment_system.sh
```

### 3. Run Load Tests
```bash
./automated_test_all.sh
```

### 4. View Results
Check the `experiment-results/` directory for detailed performance reports.

## 📊 Performance Results

### Model Comparison
| Model | Accuracy | F1-Score | Response Time | Memory Usage |
|-------|----------|----------|---------------|--------------|
| CNN | 94.2% | 0.941 | 120ms | 512MB |
| LSTM | 95.1% | 0.950 | 150ms | 768MB |
| Transformer | 95.8% | 0.957 | 200ms | 1024MB |
| LightGBM | 93.5% | 0.934 | 50ms | 256MB |
| XGBoost | 93.8% | 0.937 | 60ms | 320MB |
| Stacking ML | 96.2% | 0.961 | 80ms | 512MB |
| Stacking DL | 96.8% | 0.967 | 180ms | 1024MB |

### Infrastructure Performance
| Architecture | Avg Response Time | Max Throughput | Cost/Hour | Auto-scaling |
|--------------|------------------|----------------|-----------|--------------|
| EC2 Single | 80ms | 500 req/s | $0.10 | Manual |
| ECS Fargate | 120ms | 800 req/s | $0.15 | Automatic |
| ECS + ALB | 100ms | 1200 req/s | $0.25 | 2-10 instances |

## 🔧 Model Training

### Training Scripts
```bash
# Traditional ML with Optuna optimization
python model-training/a-train_sklearn_optuna_joblib.py

# Deep Learning models
python model-training/b-train_deeplearning_keras.py

# Stacking ensemble
python model-training/c-train_stacking_model.py

# Hybrid DL stacking
python model-training/d-train_stacking_model_incl_dl.py
```

### Training Data
- **Dataset**: Credit card transaction data
- **Features**: 30+ engineered features
- **Split**: 70% train, 15% validation, 15% test
- **Augmentation**: Synthetic minority oversampling

## 📋 API Documentation

### Prediction Endpoint
```http
POST /predict
Content-Type: application/json

{
  "transaction_data": {
    "amount": 100.50,
    "merchant_category": "online_retail",
    "hour": 14,
    "day_of_week": 3,
    ...
  }
}
```

### Response Format
```json
{
  "prediction": 0,
  "probability": 0.023,
  "model_confidence": 0.95,
  "processing_time": 85
}
```

## 🛠️ Development

### Local Development
```bash
# Set up virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run local development server
cd apps/deep_learning/flask-lstm-app
python app.py
```

### Testing
```bash
# Run unit tests
python -m pytest tests/

# Run load tests
cd Documents/lb-load-test-ecs-3-task/
python locust-flask-lstm-app-ecs-3t.py
```

## 📚 Documentation

- **[Quick Start Guide](real-aws-deployment/QUICK_START_GUIDE.md)** - 5-minute deployment guide
- **[Validation Report](real-aws-deployment/VALIDATION_REPORT.md)** - Comprehensive testing results
- **[Package Contents](real-aws-deployment/PACKAGE_CONTENTS.md)** - Detailed system overview
- **[Research Paper](A%20Comparative%20Study%20of%20ML%20Models%20and%20Deployment%20Architectures%20for%20Real-Time%20Credit%20Card%20Fraud%20Detection.pdf)** - Academic paper with findings

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Lucas Benevides e Braga** - *Author & Developer* - [lucasbraga461](https://github.com/lucasbraga461) | [ORCID](https://orcid.org/0009-0007-5397-5652)
- **Rodrigo Marins Piaba** - *Co-Author & Developer* - [rodrigomarinsp](https://github.com/rodrigomarinsp) | [ORCID](https://orcid.org/0009-0005-6569-4095)

## 🙏 Acknowledgments

- AWS for cloud infrastructure
- TensorFlow and scikit-learn communities

## 📞 Contact

- **Email**: lucasbraga461@gmail.com
- **LinkedIn**: [Lucas Braga](https://linkedin.com/in/lucasbraga461)
- **LinkedIn**: [Rodrigo Marins](https://linkedin.com/in/marinsrodrigo)

---

**Note**: This project is part of academic research. For production use, please ensure compliance with data protection regulations and security best practices.