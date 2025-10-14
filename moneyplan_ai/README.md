# MoneyPlanAI

Personal finance assistant built with Flutter, backed by local ML APIs for credit scoring and a Python portfolio API.

## Overview

- Credit Score: Uses a local CIBIL model (`Cibil.pkl`) via a Python API on port `5000`.
- Loan Eligibility: Predicts via ML API, with a rule-based fallback.
- Investment Portfolio: Python API on port `5001` serving portfolio and planning endpoints.
- Works on web and mobile; platform-aware networking is built in.

## Architecture

- Flutter app: `moneyplan_ai/lib` (Web, Android, iOS, Desktop).
- ML API server: `moneyplan_ai/ml_api_server.py` (port `5000`).
- Portfolio API server: `portfolio_api_server.py` (port `5001`).

## Prerequisites

- Flutter SDK and Chrome (for web) or an emulator/device.
- Python 3.10+ and `pip`.
- Recommended: a virtual environment for Python dependencies.

## Setup

1) Install Python dependencies

```bash
pip install -r moneyplan_ai/requirements.txt
```

2) Get Flutter packages

```bash
cd moneyplan_ai
flutter pub get
```

## Run the servers

Run each in its own terminal.

1) ML API (CIBIL and loan ML)

```bash
python moneyplan_ai/ml_api_server.py
# Serves on http://localhost:5000/
```

Health checks:
- `GET http://localhost:5000/health` → General ML server health
- `GET http://localhost:5000/cibil/health` → CIBIL model status (`model_loaded: true` when ready)

2) Portfolio API

```bash
python portfolio_api_server.py
# Serves on http://localhost:5001/
```

## Run the Flutter app

Web (Chrome):

```bash
cd moneyplan_ai
flutter run -d chrome
```

Optional: provide a metals API key for live rates.

```bash
flutter run -d chrome --dart-define=METALS_API_KEY=YOUR_KEY
```

Android emulator:
- The app uses `http://10.0.2.2` to reach local servers from the emulator.

## Key routes in the app

- `/login`, `/signup`, `/home`
- `/cibil` → CIBIL Credit Score page (uses local ML API)
- `/loan` → Loan Eligibility (ML API with fallback)
- `/retirement` → Retirement planning (Portfolio API)
- `/investment` → Investment portfolio (Portfolio API)

## API reference (brief)

ML API (port 5000):
- `POST /cibil/predict`

Request body example:
```json
{
  "full_name": "John Doe",
  "mobile_number": "9876543210",
  "date_of_birth": "1990-05-12",
  "pan_number": "ABCDE1234F"
}
```

Successful response shape (adapted for UI):
```json
{
  "success": true,
  "data": {
    "status": "success",
    "message": "CIBIL report fetched successfully",
    "data": {
      "personal_info": {"name": "John Doe", "phone": "9876543210", "dob": "1990-05-12"},
      "cibil_score": {"score": 762, "score_range": "300-900", "last_updated": "2025-10-12"},
      "factors": ["Payment history", "Credit utilization"]
    }
  }
}
```

Portfolio API (port 5001):
- `GET /user/profile`
- `GET /market/opportunities`
- `POST /portfolio/update`
- `GET /user/retirement-profile`

## Platform notes

- Web uses `http://localhost` to reach local APIs.
- Android emulator uses `http://10.0.2.2` for local APIs.
- CORS is enabled in the portfolio API; ML API targets are designed for local development.

## Troubleshooting

- Ports busy: ensure nothing else is using `5000` or `5001`.
- Models missing: verify `moneyplan_ai/Cibil.pkl` exists; check terminal logs for load status.
- Web CORS issues: confirm API servers are reachable at `localhost`; avoid proxies that rewrite ports.
- Flutter hot reload not updating: press `r` or `R` in the Flutter terminal.

## Project structure (selected)

```
FlutterProject/
├── moneyplan_ai/
│   ├── lib/                 # Flutter app code
│   ├── ml_api_server.py     # ML API (CIBIL + loan)
│   ├── Cibil.pkl            # CIBIL model file
│   └── requirements.txt     # Python deps
├── portfolio_api_server.py  # Portfolio API (port 5001)
└── ...
```

## Notes

- CIBIL now uses the local ML model only; Surepass code has been removed.
- Keep API servers running while using the Flutter app for full functionality.
