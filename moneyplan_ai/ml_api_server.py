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
import json as pyjson
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
import socket

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

# --- Rates proxy helpers and endpoints ---

def fetch_json(url: str, timeout: int = 8):
    """Fetch JSON from a URL with basic error handling and timeout."""
    try:
        req = Request(url, headers={
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (MoneyPlanAI)'
        })
        with urlopen(req, timeout=timeout) as resp:
            data = resp.read().decode('utf-8')
            return pyjson.loads(data)
    except (HTTPError, URLError, socket.timeout) as e:
        logger.error(f"HTTP error fetching {url}: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error fetching {url}: {e}")
        return None

def per10g_from_per_oz(value: float) -> float:
    """Convert per-ounce price to per-10g price."""
    try:
        return float(value) * (10.0 / 31.1035)
    except Exception:
        return 0.0

@app.route('/rates/gold', methods=['GET'])
def rates_gold():
    # Optional primary: goldapi.io (requires API key) for XAU/INR per ounce
    try:
        api_key = os.environ.get('GOLDAPI_KEY')
        if api_key:
            headers = {'x-access-token': api_key}
            r = requests.get('https://www.goldapi.io/api/XAU/INR', headers=headers, timeout=6)
            if r.ok:
                j = r.json()
                price_oz_inr = j.get('price') or j.get('price_gram_24k')
                if isinstance(price_oz_inr, (int, float)) and price_oz_inr > 0:
                    # If price_gram_24k returned, convert gram to 10g directly; else per-oz
                    if j.get('price_gram_24k'):
                        price_10g = float(price_oz_inr) * 10.0
                    else:
                        price_10g = per10g_from_per_oz(float(price_oz_inr))
                    return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'goldapi'})
    except Exception as e:
        logger.error(f"GoldAPI primary error: {e}")
    """Gold price in INR per 10g via server-side fetch to avoid CORS."""
    primary = 'https://api.exchangerate.host/latest?base=XAU&symbols=INR'
    fallback = 'https://cdn.jsdelivr.net/gh/fawazahmed0/currency-api@1/latest/currencies/xau.json'

    data = fetch_json(primary)
    if data and isinstance(data, dict):
        rate_inr = (data.get('rates') or {}).get('INR')
        if isinstance(rate_inr, (int, float)) and rate_inr > 0:
            price_10g = per10g_from_per_oz(rate_inr)
            return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'exchangerate.host'})

    data = fetch_json(fallback)
    if data and isinstance(data, dict):
        rate_inr = (data.get('xau') or {}).get('inr')
        if isinstance(rate_inr, (int, float)) and rate_inr > 0:
            price_10g = per10g_from_per_oz(rate_inr)
            return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'jsdelivr'})

    # Secondary fallback: Yahoo Finance XAUUSD and USDINR
    try:
        # Try direct INR quote first
        direct = fetch_json('https://query1.finance.yahoo.com/v7/finance/quote?symbols=XAUINR=X')
        if direct and isinstance(direct, dict):
            results = ((direct.get('quoteResponse') or {}).get('result') or [])
            if results:
                price = results[0].get('regularMarketPrice')
                if isinstance(price, (int, float)) and price > 0:
                    price_10g = per10g_from_per_oz(float(price))
                    return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'yahoo'})

        yf = fetch_json('https://query1.finance.yahoo.com/v7/finance/quote?symbols=XAUUSD=X,USDINR=X')
        if yf and isinstance(yf, dict):
            results = ((yf.get('quoteResponse') or {}).get('result') or [])
            prices = {}
            for item in results:
                sym = item.get('symbol')
                price = item.get('regularMarketPrice')
                if sym and isinstance(price, (int, float)):
                    prices[sym] = float(price)
            xauusd = prices.get('XAUUSD=X')
            usdinr = prices.get('USDINR=X')
            if xauusd and usdinr:
                rate_inr = xauusd * usdinr
                price_10g = per10g_from_per_oz(rate_inr)
                return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'yahoo'})
    except Exception as e:
        logger.error(f"Yahoo fallback (gold) error: {e}")

    return jsonify({'price': 71500.0, 'change': 350.0, 'changePercent': 0.49, 'source': 'fallback'}), 200

@app.route('/rates/silver', methods=['GET'])
def rates_silver():
    # Optional primary: goldapi.io (requires API key) for XAG/INR per ounce
    try:
        api_key = os.environ.get('GOLDAPI_KEY')
        if api_key:
            headers = {'x-access-token': api_key}
            r = requests.get('https://www.goldapi.io/api/XAG/INR', headers=headers, timeout=6)
            if r.ok:
                j = r.json()
                price_oz_inr = j.get('price') or j.get('price_gram_24k')
                if isinstance(price_oz_inr, (int, float)) and price_oz_inr > 0:
                    if j.get('price_gram_24k'):
                        price_10g = float(price_oz_inr) * 10.0
                    else:
                        price_10g = per10g_from_per_oz(float(price_oz_inr))
                    return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'goldapi'})
    except Exception as e:
        logger.error(f"GoldAPI primary error (silver): {e}")
    """Silver price in INR per 10g via server-side fetch to avoid CORS."""
    primary = 'https://api.exchangerate.host/latest?base=XAG&symbols=INR'
    fallback = 'https://cdn.jsdelivr.net/gh/fawazahmed0/currency-api@1/latest/currencies/xag.json'

    data = fetch_json(primary)
    if data and isinstance(data, dict):
        rate_inr = (data.get('rates') or {}).get('INR')
        if isinstance(rate_inr, (int, float)) and rate_inr > 0:
            price_10g = per10g_from_per_oz(rate_inr)
            return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'exchangerate.host'})

    data = fetch_json(fallback)
    if data and isinstance(data, dict):
        rate_inr = (data.get('xag') or {}).get('inr')
        if isinstance(rate_inr, (int, float)) and rate_inr > 0:
            price_10g = per10g_from_per_oz(rate_inr)
            return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'jsdelivr'})

    # Secondary fallback: Yahoo Finance XAGUSD and USDINR
    try:
        # Try direct INR quote first
        direct = fetch_json('https://query1.finance.yahoo.com/v7/finance/quote?symbols=XAGINR=X')
        if direct and isinstance(direct, dict):
            results = ((direct.get('quoteResponse') or {}).get('result') or [])
            if results:
                price = results[0].get('regularMarketPrice')
                if isinstance(price, (int, float)) and price > 0:
                    price_10g = per10g_from_per_oz(float(price))
                    return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'yahoo'})

        yf = fetch_json('https://query1.finance.yahoo.com/v7/finance/quote?symbols=XAGUSD=X,USDINR=X')
        if yf and isinstance(yf, dict):
            results = ((yf.get('quoteResponse') or {}).get('result') or [])
            prices = {}
            for item in results:
                sym = item.get('symbol')
                price = item.get('regularMarketPrice')
                if sym and isinstance(price, (int, float)):
                    prices[sym] = float(price)
            xagusd = prices.get('XAGUSD=X')
            usdinr = prices.get('USDINR=X')
            if xagusd and usdinr:
                rate_inr = xagusd * usdinr
                price_10g = per10g_from_per_oz(rate_inr)
                return jsonify({'price': price_10g, 'change': 0.0, 'changePercent': 0.0, 'source': 'yahoo'})
    except Exception as e:
        logger.error(f"Yahoo fallback (silver) error: {e}")

    return jsonify({'price': 950.0, 'change': 5.0, 'changePercent': 0.53, 'source': 'fallback'}), 200

@app.route('/rates/bitcoin', methods=['GET'])
def rates_bitcoin():
    """Bitcoin price in INR via server-side fetch to avoid CORS."""
    primary = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=inr&include_24hr_change=true'
    fallback = 'https://api.coindesk.com/v1/bpi/currentprice/INR.json'

    data = fetch_json(primary)
    if data and isinstance(data, dict):
        btc = data.get('bitcoin') or {}
        price_inr = btc.get('inr')
        change_pct = btc.get('inr_24h_change')
        if isinstance(price_inr, (int, float)) and price_inr > 0:
            return jsonify({'price': float(price_inr), 'change': float(price_inr) * float(change_pct or 0.0) / 100.0, 'changePercent': float(change_pct or 0.0), 'source': 'coingecko'})

    data = fetch_json(fallback)
    if data and isinstance(data, dict):
        bpi_inr = ((data.get('bpi') or {}).get('INR') or {})
        price_inr = bpi_inr.get('rate_float')
        if isinstance(price_inr, (int, float)) and price_inr > 0:
            return jsonify({'price': float(price_inr), 'change': 0.0, 'changePercent': 0.0, 'source': 'coindesk'})

    return jsonify({'price': 4125000.0, 'change': 51562.50, 'changePercent': 1.25, 'source': 'fallback'}), 200

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