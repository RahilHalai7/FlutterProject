#!/usr/bin/env python3
"""
ML API Server for Loan Eligibility Prediction
This Flask server loads the random_forest_model.pkl file and provides
a REST API endpoint for loan eligibility predictions.

Usage:
1. Install dependencies: pip install flask pandas scikit-learn numpy
2. Run server: python ml_api_server.py
3. Server will run on http://localhost:5000
"""

import os
import pickle
import pandas as pd
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web app

# Global variable to store the loaded model
model = None

def load_model():
    """Load the random forest model from pickle file"""
    global model
    model_path = 'random_forest_model.pkl'
    
    try:
        if os.path.exists(model_path):
            with open(model_path, 'rb') as file:
                model = pickle.load(file)
            logger.info(f"Model loaded successfully from {model_path}")
            return True
        else:
            logger.error(f"Model file not found: {model_path}")
            return False
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        return False

def preprocess_input(data):
    """Preprocess input data to match model training format"""
    try:
        # Create DataFrame with expected columns
        df = pd.DataFrame([data])
        
        # Handle categorical variables encoding
        # Gender: Male=1, Female=0
        df['Gender'] = df['Gender'].map({'Male': 1, 'Female': 0})
        
        # Married: Yes=1, No=0
        df['Married'] = df['Married'].map({'Yes': 1, 'No': 0})
        
        # Dependents: Convert to numeric, handle '3+' case
        df['Dependents'] = df['Dependents'].replace('3+', '3').astype(int)
        
        # Education: Graduate=1, Not Graduate=0
        df['Education'] = df['Education'].map({'Graduate': 1, 'Not Graduate': 0})
        
        # Self_Employed: Yes=1, No=0
        df['Self_Employed'] = df['Self_Employed'].map({'Yes': 1, 'No': 0})
        
        # Property_Area: Urban=2, Semiurban=1, Rural=0
        df['Property_Area'] = df['Property_Area'].map({
            'Urban': 2, 
            'Semiurban': 1, 
            'Rural': 0
        })
        
        # Ensure numeric columns are properly typed
        numeric_columns = ['ApplicantIncome', 'CoapplicantIncome', 'LoanAmount', 
                          'Loan_Amount_Term', 'Credit_History']
        for col in numeric_columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # Handle missing values (fill with median/mode)
        df = df.fillna({
            'Gender': 1,
            'Married': 1,
            'Dependents': 0,
            'Education': 1,
            'Self_Employed': 0,
            'ApplicantIncome': 5000,
            'CoapplicantIncome': 0,
            'LoanAmount': 150,
            'Loan_Amount_Term': 360,
            'Credit_History': 1,
            'Property_Area': 1
        })
        
        # Ensure column order matches training data
        expected_columns = [
            'Gender', 'Married', 'Dependents', 'Education', 'Self_Employed',
            'ApplicantIncome', 'CoapplicantIncome', 'LoanAmount', 
            'Loan_Amount_Term', 'Credit_History', 'Property_Area'
        ]
        
        # Reorder columns and ensure all are present
        df = df.reindex(columns=expected_columns, fill_value=0)
        
        logger.info(f"Preprocessed data shape: {df.shape}")
        logger.info(f"Preprocessed data: {df.iloc[0].to_dict()}")
        
        return df
        
    except Exception as e:
        logger.error(f"Error in preprocessing: {str(e)}")
        raise ValueError(f"Data preprocessing failed: {str(e)}")

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'message': 'ML API Server is running'
    })

@app.route('/predict', methods=['POST'])
def predict_loan_eligibility():
    """Predict loan eligibility using the loaded model"""
    try:
        if model is None:
            return jsonify({
                'error': 'Model not loaded',
                'message': 'Please check server logs for model loading issues'
            }), 500
        
        # Get JSON data from request
        data = request.get_json()
        
        if not data:
            return jsonify({
                'error': 'No data provided',
                'message': 'Please provide input data in JSON format'
            }), 400
        
        logger.info(f"Received prediction request: {data}")
        
        # Preprocess the input data
        processed_data = preprocess_input(data)
        
        # Make prediction
        prediction = model.predict(processed_data)[0]
        
        # Get prediction probability if available
        try:
            prediction_proba = model.predict_proba(processed_data)[0]
            # Get probability of positive class (loan approved)
            if hasattr(model, 'classes_'):
                positive_class_idx = list(model.classes_).index('Y') if 'Y' in model.classes_ else 1
            else:
                positive_class_idx = 1
            probability = float(prediction_proba[positive_class_idx])
        except Exception as e:
            logger.warning(f"Could not get prediction probability: {str(e)}")
            probability = 0.8 if prediction == 'Y' else 0.2
        
        result = {
            'prediction': str(prediction),
            'probability': probability,
            'model_info': {
                'type': str(type(model).__name__),
                'features_used': processed_data.columns.tolist()
            }
        }
        
        logger.info(f"Prediction result: {result}")
        
        return jsonify(result)
        
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        return jsonify({
            'error': 'Invalid input data',
            'message': str(e)
        }), 400
        
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        return jsonify({
            'error': 'Prediction failed',
            'message': str(e)
        }), 500

@app.route('/model-info', methods=['GET'])
def get_model_info():
    """Get information about the loaded model"""
    if model is None:
        return jsonify({
            'error': 'Model not loaded'
        }), 500
    
    try:
        info = {
            'model_type': str(type(model).__name__),
            'model_loaded': True
        }
        
        # Try to get additional model information
        if hasattr(model, 'n_estimators'):
            info['n_estimators'] = model.n_estimators
        if hasattr(model, 'feature_importances_'):
            info['has_feature_importance'] = True
        if hasattr(model, 'classes_'):
            info['classes'] = model.classes_.tolist()
            
        return jsonify(info)
        
    except Exception as e:
        logger.error(f"Error getting model info: {str(e)}")
        return jsonify({
            'error': 'Could not retrieve model information',
            'message': str(e)
        }), 500

@app.route('/feature-importance', methods=['GET'])
def get_feature_importance():
    """Get feature importance from the model"""
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500
    
    try:
        if hasattr(model, 'feature_importances_'):
            feature_names = [
                'Gender', 'Married', 'Dependents', 'Education', 'Self_Employed',
                'ApplicantIncome', 'CoapplicantIncome', 'LoanAmount', 
                'Loan_Amount_Term', 'Credit_History', 'Property_Area'
            ]
            
            importance_dict = dict(zip(feature_names, model.feature_importances_))
            # Sort by importance
            sorted_importance = dict(sorted(importance_dict.items(), 
                                          key=lambda x: x[1], reverse=True))
            
            return jsonify({
                'feature_importance': sorted_importance,
                'total_features': len(feature_names)
            })
        else:
            return jsonify({
                'error': 'Model does not support feature importance'
            }), 400
            
    except Exception as e:
        logger.error(f"Error getting feature importance: {str(e)}")
        return jsonify({
            'error': 'Could not retrieve feature importance',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    # Load the model on startup
    if load_model():
        logger.info("Starting ML API Server...")
        # Run the Flask app
        app.run(
            host='0.0.0.0',  # Allow external connections
            port=5000,
            debug=True,
            threaded=True
        )
    else:
        logger.error("Failed to load model. Server not started.")
        print("\nTo fix this issue:")
        print("1. Ensure 'random_forest_model.pkl' exists in the current directory")
        print("2. Install required packages: pip install flask pandas scikit-learn numpy flask-cors")
        print("3. Check that the pickle file is not corrupted")