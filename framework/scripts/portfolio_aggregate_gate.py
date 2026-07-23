#!/usr/bin/env python3
"""Portfolio aggregate DXZ compliance gate (binding)."""

from __future__ import annotations

import csv
import json
import math
from datetime import datetime
from pathlib import Path
from typing import Any


def _parse_ts(value: str) -> datetime:
    return datetime.fromisoformat(value.strip().replace("Z", "+00:00"))


def _load_curve(path: Path) -> list[tuple[datetime, float]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
    if not rows:
        return []
    keys = {k.lower(): k for k in rows[0].keys()}
    ts_key = keys.get("timestamp") or keys.get("time") or keys.get("datetime") or keys.get("date")
    eq_key = keys.get("equity") or keys.get("balance")
    if not ts_key or not eq_key:
        return []
    out = [(_parse_ts(r[ts_key]), float(r[eq_key])) for r in rows]
    return sorted(out, key=lambda p: p[0])


def _daily_returns(curve: list[tuple[datetime, float]]) -> dict[str, float]:
    by_day: dict[str, list[float]] = {}
    for ts, eq in curve:
        by_day.setdefault(ts.date().isoformat(), []).append(eq)
    out: dict[str, float] = {}
    prev_close: float | None = None
    for day in sorted(by_day.keys()):
        values = by_day[day]
        day_open = values[0]
        day_close = values[-1]
        base = day_open
        if len(values) == 1 and prev_close is not None:
            base = prev_close
        out[day] = 0.0 if base == 0 else (day_close - base) / base
        prev_close = day_close
    return out


def _max_drawdown_pct(values: list[float]) -> float:
    if not values:
        return 0.0
    peak = values[0]
    max_dd = 0.0
    for value in values:
        peak = max(peak, value)
        if peak > 0:
            max_dd = max(max_dd, (peak - value) / peak)
    return max_dd * 100.0


def _corr(a: list[float], b: list[float]) -> float:
    if len(a) != len(b) or len(a) < 2:
        return 0.0
    mean_a = sum(a) / len(a)
    mean_b = sum(b) / len(b)
    num = sum((x - mean_a) * (y - mean_b) for x, y in zip(a, b))
    den_a = math.sqrt(sum((x - mean_a) ** 2 for x in a))
    den_b = math.sqrt(sum((y - mean_b) ** 2 for y in b))
    if den_a == 0 or den_b == 0:
        return 0.0
    return num / (den_a * den_b)


def check_portfolio_aggregate_compliance(
    basket: list[dict[str, str]],
    *,
    daily_dd_threshold_pct: float = 5.0,
    total_dd_threshold_pct: float = 20.0,
    correlation_warn_threshold: float = 0.7,
    evidence_path: str | Path | None = None,
) -> dict[str, Any]:
    curves = {f"{item['ea']}:{item['symbol']}": _load_curve(Path(item["equity_curve"])) for item in basket}
    daily_by_leg = {k: _daily_returns(v) for k, v in curves.items()}
    all_days = sorted({d for returns in daily_by_leg.values() for d in returns.keys()})

    aggregate_curve: list[float] = [100000.0]
    daily_dd_values: list[float] = []
    for day in all_days:
        day_return = sum(returns.get(day, 0.0) for returns in daily_by_leg.values())
        start = aggregate_curve[-1]
        end = start * (1.0 + day_return)
        aggregate_curve.append(end)
        if start > 0:
            daily_dd_values.append(max(0.0, (start - end) / start * 100.0))
        else:
            daily_dd_values.append(0.0)

    max_daily_dd_pct = max(daily_dd_values) if daily_dd_values else 0.0
    max_total_dd_pct = _max_drawdown_pct(aggregate_curve)
    verdict = "BASKET_PASS"
    reason = "PASS"
    if max_daily_dd_pct > daily_dd_threshold_pct or max_total_dd_pct > total_dd_threshold_pct:
        verdict = "BASKET_FAIL"
        reason = "FAIL_AGGREGATE_DD"

    correlation_pairs: list[dict[str, Any]] = []
    legs = sorted(daily_by_leg.keys())
    for i in range(len(legs)):
        for j in range(i + 1, len(legs)):
            common_days = sorted(set(daily_by_leg[legs[i]].keys()) & set(daily_by_leg[legs[j]].keys()))
            series_i = [daily_by_leg[legs[i]][d] for d in common_days]
            series_j = [daily_by_leg[legs[j]][d] for d in common_days]
            corr = _corr(series_i, series_j)
            correlation_pairs.append({"left": legs[i], "right": legs[j], "pearson": round(corr, 6), "days": len(common_days)})

    payload = {
        "verdict": verdict,
        "reason": reason,
        "max_daily_dd_pct": round(max_daily_dd_pct, 6),
        "max_total_dd_pct": round(max_total_dd_pct, 6),
        "aggregate_days": all_days,
        "correlation_warn_threshold": correlation_warn_threshold,
        "correlation_pairs": correlation_pairs,
    }
    if evidence_path is not None:
        target = Path(evidence_path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        payload["evidence_path"] = str(target)
    return payload
