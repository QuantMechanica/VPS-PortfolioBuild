#!/usr/bin/env python3
"""DXZ compliance helpers (per-EA soft signal)."""

from __future__ import annotations

import csv
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


@dataclass
class EquityPoint:
    ts: datetime
    equity: float


def _parse_ts(value: str) -> datetime:
    text = value.strip().replace("Z", "+00:00")
    return datetime.fromisoformat(text)


def _find_col(row: dict[str, str], names: tuple[str, ...]) -> str:
    lowered = {k.lower(): k for k in row.keys()}
    for name in names:
        if name.lower() in lowered:
            return lowered[name.lower()]
    return ""


def _load_equity_curve(path: Path) -> list[EquityPoint]:
    points: list[EquityPoint] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        first = next(reader, None)
        if first is None:
            return points
        ts_key = _find_col(first, ("timestamp", "time", "datetime", "date"))
        eq_key = _find_col(first, ("equity", "balance"))
        if not ts_key or not eq_key:
            return points
        points.append(EquityPoint(ts=_parse_ts(first[ts_key]), equity=float(first[eq_key])))
        for row in reader:
            points.append(EquityPoint(ts=_parse_ts(row[ts_key]), equity=float(row[eq_key])))
    return sorted(points, key=lambda p: p.ts)


def _load_trade_reconstructed_equity(path: Path, start_equity: float) -> list[EquityPoint]:
    rows: list[dict[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
    if not rows:
        return []
    first = rows[0]
    ts_key = _find_col(first, ("close_time", "time", "timestamp", "datetime", "date"))
    pnl_key = _find_col(first, ("profit", "pnl", "net_profit"))
    if not ts_key or not pnl_key:
        return []
    ordered = sorted(rows, key=lambda r: _parse_ts(r[ts_key]))
    equity = start_equity
    out: list[EquityPoint] = []
    for row in ordered:
        equity += float(row[pnl_key])
        out.append(EquityPoint(ts=_parse_ts(row[ts_key]), equity=equity))
    return out


def _max_total_dd_pct(points: list[EquityPoint]) -> float:
    if not points:
        return 0.0
    peak = points[0].equity
    max_dd = 0.0
    for point in points:
        peak = max(peak, point.equity)
        if peak > 0:
            dd = (peak - point.equity) / peak
            max_dd = max(max_dd, dd)
    return max_dd * 100.0


def _max_daily_dd_pct(points: list[EquityPoint]) -> tuple[float, list[str]]:
    if not points:
        return 0.0, []
    by_day: dict[str, list[float]] = {}
    for point in points:
        key = point.ts.date().isoformat()
        by_day.setdefault(key, []).append(point.equity)
    max_dd = 0.0
    violations: list[str] = []
    for day, equities in sorted(by_day.items()):
        day_peak = equities[0]
        day_max_dd = 0.0
        for value in equities:
            day_peak = max(day_peak, value)
            if day_peak > 0:
                day_max_dd = max(day_max_dd, (day_peak - value) / day_peak)
        day_dd_pct = day_max_dd * 100.0
        if day_dd_pct > max_dd:
            max_dd = day_dd_pct
        violations.append(day)
    return max_dd, violations


def check_dxz_compliance(
    report_csv_path: str | Path,
    equity_curve_path: str | Path,
    *,
    daily_dd_threshold_pct: float = 5.0,
    total_dd_threshold_pct: float = 20.0,
    evidence_path: str | Path | None = None,
) -> dict[str, Any]:
    report_path = Path(report_csv_path)
    curve_path = Path(equity_curve_path)
    points = _load_equity_curve(curve_path)
    if not points:
        points = _load_trade_reconstructed_equity(report_path, start_equity=100000.0)

    max_daily_dd_pct, days = _max_daily_dd_pct(points)
    max_total_dd_pct = _max_total_dd_pct(points)

    reasons: list[str] = []
    if max_daily_dd_pct > daily_dd_threshold_pct:
        reasons.append("FAIL_DAILY_DD")
    if max_total_dd_pct > total_dd_threshold_pct:
        reasons.append("FAIL_TOTAL_DD")

    verdict = "DXZ_PASS" if not reasons else "DXZ_FAIL"
    payload = {
        "verdict": verdict,
        "reason": ",".join(reasons) if reasons else "PASS",
        "max_daily_dd_pct": round(max_daily_dd_pct, 6),
        "max_total_dd_pct": round(max_total_dd_pct, 6),
        "violation_dates": days if reasons else [],
        "report_csv_path": str(report_path),
        "equity_curve_path": str(curve_path),
    }
    if evidence_path is not None:
        target = Path(evidence_path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        payload["evidence_path"] = str(target)
    return payload
