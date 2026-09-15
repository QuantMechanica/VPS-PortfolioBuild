"""Section 57 DXZ venue-fitness objective (deterministic).

DXZ_FITNESS optimizes portfolio-level: sustainable return; controlled drawdown;
consistency; diversification; tail robustness (directive section 3/57).  This is a
deterministic scalar objective plus its named components so the AI can interpret it
(section 58).  It is intentionally DIFFERENT from FTMO_FITNESS, which optimizes
challenge survival / first-passage (see ``venue_fitness.py``).

The objective is a bounded, monotone composite of the section 7 metric vector
produced by ``metrics.py``.  Higher is better.  No RNG.
"""
from __future__ import annotations

import math
from typing import Any, Mapping

VENUE = "dxz"


def _num(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)) and math.isfinite(float(value)):
        return float(value)
    return None


def _bounded(value: float, scale: float) -> float:
    """Map an unbounded non-negative quality onto [0, 1) monotonically."""
    if value <= 0.0 or scale <= 0.0:
        return 0.0
    return value / (value + scale)


def compute_dxz_fitness(metrics: Mapping[str, Any]) -> dict[str, Any]:
    """Return the DXZ venue objective (higher is better) with its components.

    Components (each in [0, 1], weighted):
      * return_to_dd  -- return / max-drawdown (capital efficiency, DXZ north star),
      * sharpe        -- risk-adjusted consistency,
      * diversification -- effective number of independent bets, normalized by count,
      * tail_robustness -- shallow expected-shortfall relative to volatility,
      * low_dependence  -- 1 - mean|downside correlation| (genuine risk diversity).
    """
    rtd = _num(metrics.get("return_to_maxdd"))
    sharpe = _num(metrics.get("sharpe"))
    enb = _num(metrics.get("effective_number_of_bets"))
    n_sleeves = _num(metrics.get("n_sleeves")) or 0.0
    tail = _num(metrics.get("tail_loss_es5_pct"))  # negative pct (loss)
    vol = _num(metrics.get("volatility_annual_pct"))
    down_corr = _num(metrics.get("mean_abs_downside_correlation"))

    c_return = _bounded(rtd, 3.0) if rtd is not None else 0.0
    c_sharpe = _bounded(sharpe, 1.0) if sharpe is not None else 0.0
    c_div = min(max(enb / n_sleeves, 0.0), 1.0) if (enb is not None and n_sleeves > 0) else 0.0
    # Tail robustness: a shallower expected shortfall relative to daily vol is better.
    if tail is not None and vol is not None and vol > 0.0:
        daily_vol = vol / math.sqrt(252.0)
        severity = abs(tail) / daily_vol if daily_vol > 0 else 0.0
        c_tail = 1.0 / (1.0 + max(severity - 1.0, 0.0))
    else:
        c_tail = 0.0
    c_dep = (1.0 - min(abs(down_corr), 1.0)) if down_corr is not None else 0.5

    weights = {
        "return_to_dd": 0.35,
        "sharpe": 0.25,
        "diversification": 0.20,
        "tail_robustness": 0.10,
        "low_dependence": 0.10,
    }
    components = {
        "return_to_dd": round(c_return, 8),
        "sharpe": round(c_sharpe, 8),
        "diversification": round(c_div, 8),
        "tail_robustness": round(c_tail, 8),
        "low_dependence": round(c_dep, 8),
    }
    objective = sum(weights[name] * components[name] for name in weights)

    return {
        "venue": VENUE,
        "objective": round(objective, 8),
        "components": components,
        "weights": weights,
        "note": "DXZ_FITNESS section 57: return/maxDD + consistency + diversification + tail.",
    }
