import os
from typing import List, Dict, Any

from fastapi import FastAPI, Body
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(title="Investment Portfolio API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# In-memory user profile and portfolio state
USER_PROFILE: Dict[str, Any] = {
    "name": "Rahil",
    "age": 28,
    "job": "Software Engineer",
    "income": 1200000,
    "risk_level": "moderate",
}

# Retirement-specific mock profile
RETIREMENT_PROFILE: Dict[str, Any] = {
    "age": 30,
    "income": 1200000,
    "monthly_expenses": 40000,
    "current_savings": 800000,
    "retirement_age_goal": 60,
    "risk_level": "moderate",
}

BASE_OPPORTUNITIES: List[Dict[str, Any]] = [
    {
        "title": "Government Bonds",
        "expected_return": "6%",
        "risk": "low",
        "category": "Fixed Income",
    },
    {
        "title": "Large-cap Mutual Fund",
        "expected_return": "11%",
        "risk": "moderate",
        "category": "Mutual Funds",
    },
    {
        "title": "Crypto Index Fund",
        "expected_return": "18%",
        "risk": "high",
        "category": "Digital Assets",
    },
    {
        "title": "Blue-chip Stocks",
        "expected_return": "12%",
        "risk": "moderate",
        "category": "Equities",
    },
    {
        "title": "Gold ETF",
        "expected_return": "8%",
        "risk": "low",
        "category": "Commodities",
    },
]

# Simple in-memory portfolio structure: { title, category, allocation_percent }
PORTFOLIO: List[Dict[str, Any]] = []
RETIREMENT_STRATEGY: List[Dict[str, Any]] = []


@app.get("/user/profile")
def get_user_profile() -> Dict[str, Any]:
    return USER_PROFILE


@app.get("/user/retirement-profile")
def get_retirement_profile() -> Dict[str, Any]:
    return RETIREMENT_PROFILE


def _filter_opportunities_by_risk(risk_level: str) -> List[Dict[str, Any]]:
    risk_order = {"low": 0, "moderate": 1, "high": 2}
    user_risk_rank = risk_order.get(risk_level, 1)

    # Prefer items with risk <= user's level, but ensure diversity
    preferred = [o for o in BASE_OPPORTUNITIES if risk_order.get(o["risk"], 1) <= user_risk_rank]

    # Ensure at least 3 items and diverse categories
    by_category: Dict[str, Dict[str, Any]] = {}
    for o in preferred:
        by_category.setdefault(o["category"], o)

    selected = list(by_category.values())

    # If fewer than 3, add more from remaining opportunities, prioritizing different categories
    if len(selected) < 3:
        remaining = [o for o in BASE_OPPORTUNITIES if o not in selected]
        for o in remaining:
            selected.append(o)
            if len(selected) >= 3:
                break

    # If still fewer than 3 (edge case), just pad from base list
    while len(selected) < 3 and BASE_OPPORTUNITIES:
        for o in BASE_OPPORTUNITIES:
            if o not in selected:
                selected.append(o)
                if len(selected) >= 3:
                    break

    return selected[:5]


@app.get("/market/opportunities")
def get_market_opportunities() -> List[Dict[str, Any]]:
    risk_level = USER_PROFILE.get("risk_level", "moderate")
    return _filter_opportunities_by_risk(risk_level)


@app.post("/portfolio/update")
def update_portfolio(
    action: str = Body("add"),
    item: Dict[str, Any] = Body(...),
    allocation_percent: float = Body(10.0),
) -> Dict[str, Any]:
    global PORTFOLIO
    title = item.get("title")
    category = item.get("category")

    if not title or not category:
        return {"status": "error", "message": "Invalid item payload"}

    if action == "add":
        # Update if exists; else add new
        found = next((p for p in PORTFOLIO if p["title"] == title), None)
        if found:
            found["allocation_percent"] = allocation_percent
        else:
            PORTFOLIO.append({
                "title": title,
                "category": category,
                "allocation_percent": allocation_percent,
            })
        status = "added"
    elif action == "remove":
        PORTFOLIO = [p for p in PORTFOLIO if p["title"] != title]
        status = "removed"
    else:
        return {"status": "error", "message": "Unknown action"}

    # Return updated portfolio summary
    total = sum(p["allocation_percent"] for p in PORTFOLIO) or 0.0
    by_category: Dict[str, float] = {}
    for p in PORTFOLIO:
        by_category[p["category"]] = by_category.get(p["category"], 0.0) + p["allocation_percent"]

    return {
        "status": status,
        "portfolio": PORTFOLIO,
        "total_allocation": total,
        "by_category": by_category,
    }


def _expected_return_from_risk(risk: str) -> float:
    mapping = {"low": 0.05, "moderate": 0.08, "high": 0.10}
    return mapping.get(risk, 0.08)


@app.get("/retirement/projections")
def get_retirement_projections() -> Dict[str, Any]:
    profile = RETIREMENT_PROFILE
    age = int(profile.get("age", 30))
    retirement_age_goal = int(profile.get("retirement_age_goal", 60))
    years_to_retirement = max(retirement_age_goal - age, 0)

    income = float(profile.get("income", 1200000))  # yearly
    monthly_expenses = float(profile.get("monthly_expenses", 40000))
    current_savings = float(profile.get("current_savings", 800000))
    risk_level = profile.get("risk_level", "moderate")

    # Assumptions
    annual_inflation = 0.06
    post_retirement_years = 25
    expected_return = _expected_return_from_risk(risk_level)

    # Adjust monthly expenses to retirement year using compounding inflation
    adjusted_monthly_expenses = monthly_expenses * ((1 + annual_inflation) ** years_to_retirement)
    estimated_corpus_required = adjusted_monthly_expenses * 12 * post_retirement_years

    # Project savings using simple FV formula with yearly compounding on monthly contributions
    monthly_surplus = max(income / 12.0 - monthly_expenses, 0.0)
    r = expected_return
    n = years_to_retirement
    # Future value of current savings
    fv_savings = current_savings * ((1 + r) ** n)
    # Approximate future value of monthly contributions compounded annually
    fv_contrib = 0.0
    if r > 0 and n > 0 and monthly_surplus > 0:
        yearly_contrib = monthly_surplus * 12
        fv_contrib = yearly_contrib * (((1 + r) ** n - 1) / r)

    projected = fv_savings + fv_contrib
    shortfall_or_surplus = projected - estimated_corpus_required

    return {
        "years_to_retirement": years_to_retirement,
        "estimated_corpus_required": round(estimated_corpus_required, 2),
        "projected_savings_at_current_rate": round(projected, 2),
        "shortfall_or_surplus": round(shortfall_or_surplus, 2),
    }


@app.get("/retirement/recommendations")
def get_retirement_recommendations() -> List[Dict[str, Any]]:
    return [
        {
            "title": "Equity Mutual Fund SIP",
            "expected_return": "12%",
            "category": "Growth",
            "risk": "moderate",
        },
        {
            "title": "NPS (National Pension Scheme)",
            "expected_return": "10%",
            "category": "Retirement",
            "risk": "low",
        },
        {
            "title": "REITs",
            "expected_return": "9%",
            "category": "Real Estate",
            "risk": "moderate",
        },
    ]


@app.post("/retirement/strategy")
def update_retirement_strategy(
    plan: Dict[str, Any] = Body(...),
    allocation_percent: float = Body(10.0),
) -> Dict[str, Any]:
    global RETIREMENT_STRATEGY
    if not plan.get("title"):
        return {"status": "error", "message": "Invalid plan payload"}

    found = next((p for p in RETIREMENT_STRATEGY if p.get("title") == plan["title"]), None)
    if found:
        found["allocation_percent"] = allocation_percent
    else:
        RETIREMENT_STRATEGY.append(
            {
                "title": plan.get("title"),
                "category": plan.get("category", "Retirement"),
                "risk": plan.get("risk", "moderate"),
                "allocation_percent": allocation_percent,
            }
        )

    total = sum(p.get("allocation_percent", 0.0) for p in RETIREMENT_STRATEGY) or 0.0
    return {"status": "ok", "strategy": RETIREMENT_STRATEGY, "total_allocation": total}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORTFOLIO_API_PORT", "5001"))
    uvicorn.run("portfolio_api_server:app", host="0.0.0.0", port=port, reload=True)