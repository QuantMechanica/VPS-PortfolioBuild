#!/usr/bin/env python3
"""Closed-data session feature layer for offline mechanical-rule discovery.

Only 2018-2022 HCC files are read.  Rows are keyed by an already-completed
feature window and a strictly later target-window entry.  2023-2025 are never
opened by this module; those years are reserved for a later pre-registered F2
prescreen.

Fair-value-gap definition (fixed): in completed Asia M15 bars b1,b2,b3, a
bullish FVG exists when low(b3) > high(b1); a bearish FVG exists when
high(b3) < low(b1).  The feature is the sign of the last such gap in the
00:00-07:00 Europe/London window (0 when none), with a separate count.
"""
from __future__ import annotations

import argparse
import bisect
import datetime as dt
import gzip
import hashlib
import json
import os
import statistics
import sys
from collections import deque
from pathlib import Path
from typing import Any

REPO = Path("C:/QM/repo")
RESEARCH = Path(__file__).resolve().parent
SESSION_TOOLS = REPO / "tools/strategy_farm/session_tools"
for path in (str(RESEARCH), str(SESSION_TOOLS)):
    if path not in sys.path:
        sys.path.insert(0, path)

import cross_symbol_scanner as CSCAN  # noqa: E402
from hcc_m1_reader_0921 import read_year  # noqa: E402


SCHEMA = "qm.session-features/v2"
BASE_SCHEMA = "qm.session-feature-base/v2"
YEARS = tuple(range(2018, 2023))
START = dt.date(2018, 7, 2)
END = dt.date(2022, 12, 31)
DISCOVERY_END = dt.date(2021, 12, 31)
VALIDATION_START = dt.date(2022, 1, 1)
REFERENCE_SYMBOLS = (
    "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX",
    "XAGUSD.DWX", "USDJPY.DWX", "EURUSD.DWX", "GBPUSD.DWX", "XTIUSD.DWX",
)
NEXT_SESSION = {
    "ASIA": ("LONDON", False),
    "LONDON": ("NY_PREOPEN", False),
    "NY_PREOPEN": ("CASH_OPEN", False),
    "CASH_OPEN": ("NY_CASH", False),
    "NY_CASH": ("ASIA", True),
    "LONDON_NY_OVERLAP": ("ASIA", True),
}


def _cache_path(cache_dir: Path, symbol: str) -> Path:
    return cache_dir / f"{symbol.replace('.', '_')}.json.gz"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _write_gzip_json(path: Path, obj: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(obj, sort_keys=True, separators=(",", ":")) + "\n").encode()
    tmp = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    with tmp.open("wb") as fh:
        with gzip.GzipFile(filename="", mode="wb", fileobj=fh, mtime=0) as gz:
            gz.write(raw)
    os.replace(tmp, path)


def load_base(path: Path) -> dict[str, Any]:
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        obj = json.load(fh)
    if obj.get("schema") != BASE_SCHEMA:
        raise ValueError(f"unexpected feature-base schema in {path}")
    return obj


def _asia_fvg(bars: list[tuple], times: list[int], start: int, end: int) -> tuple[int, int]:
    i, j = bisect.bisect_left(times, start), bisect.bisect_left(times, end)
    if i >= j:
        return 0, 0
    grid: dict[int, list[float]] = {}
    for row in bars[i:j]:
        key = int(row[0]) - int(row[0]) % 900
        cur = grid.get(key)
        if cur is None:
            grid[key] = [float(row[1]), float(row[2]), float(row[3]), float(row[4])]
        else:
            cur[1] = max(cur[1], float(row[2])); cur[2] = min(cur[2], float(row[3])); cur[3] = float(row[4])
    keys = sorted(k for k in grid if start <= k and k + 900 <= end)
    sign, count = 0, 0
    for n in range(2, len(keys)):
        b1, b3 = grid[keys[n - 2]], grid[keys[n]]
        if b3[2] > b1[1]:
            sign, count = 1, count + 1
        elif b3[1] < b1[2]:
            sign, count = -1, count + 1
    return sign, count


def prepare_symbol(symbol: str, cache_dir: Path, reuse: bool = True) -> dict[str, Any]:
    path = _cache_path(cache_dir, symbol)
    if reuse and path.exists():
        try:
            return load_base(path)
        except (OSError, ValueError, json.JSONDecodeError):
            pass
    sessions: dict[str, dict[str, dict[str, Any]]] = {name: {} for name in CSCAN.SESSION_ORDER}
    asia_fvg: dict[str, dict[str, int]] = {}
    sources = []
    bars_total = violations = 0
    for year in YEARS:
        try:
            raw = list(read_year(symbol, year))
        except FileNotFoundError:
            continue
        bars = CSCAN._dedupe_bars(raw)
        bars_total += len(bars)
        violations += sum(1 for r in bars if not (r[3] <= r[1] <= r[2] and r[3] <= r[4] <= r[2] and r[3] > 0))
        source = CSCAN._source_path(symbol, year)
        sources.append({
            "year": year,
            "path": str(source).replace("\\", "/") if source else None,
            "size": source.stat().st_size if source else None,
            "sha256": _sha256(source) if source else None,
        })
        times = [int(r[0]) for r in bars]
        day, last = dt.date(year, 1, 1), dt.date(year, 12, 31)
        while day <= last:
            if day.weekday() < 5:
                key = day.isoformat()
                for name, spec in CSCAN.SESSION_SPECS.items():
                    start, end = CSCAN._window_epochs(day, spec)
                    rec = CSCAN._extract_window(bars, times, start, end)
                    if rec:
                        # HCC rows are timestamped at bar open. This is the
                        # last source record consumed by every feature derived
                        # from the window, and must precede target entry.
                        rec["data_cutoff"] = int(bars[bisect.bisect_left(times, end) - 1][0])
                        sessions[name][key] = rec
                a0, a1 = CSCAN._window_epochs(day, CSCAN.SESSION_SPECS["ASIA"])
                sign, count = _asia_fvg(bars, times, a0, a1)
                asia_fvg[key] = {"sign": sign, "count": count}
            day += dt.timedelta(days=1)

    for name in CSCAN.SESSION_ORDER:
        ranges: deque[float] = deque(maxlen=14)
        prior20: deque[float] = deque(maxlen=20)
        atr60: deque[float] = deque(maxlen=60)
        for day in sorted(sessions[name]):
            rec = sessions[name][day]
            rec["atr"] = sum(ranges) / 14 if len(ranges) == 14 else None
            rec["range_median20"] = statistics.median(prior20) if len(prior20) == 20 else None
            rec["compression"] = bool(rec["range_median20"] and rec["range"] <= 0.7 * rec["range_median20"])
            rec["vol_ratio"] = (rec["atr"] / statistics.median(atr60)) if rec["atr"] and len(atr60) >= 20 and statistics.median(atr60) > 0 else None
            if rec["atr"]:
                atr60.append(rec["atr"])
            ranges.append(rec["range"]); prior20.append(rec["range"])

    days = sorted(set().union(*(set(sessions[n]) for n in CSCAN.SESSION_ORDER)))
    daily: dict[str, dict[str, Any]] = {}
    closes: deque[float] = deque(maxlen=200)
    previous: dict[str, Any] | None = None
    for day in days:
        rows = [sessions[n][day] for n in CSCAN.SESSION_ORDER if day in sessions[n]]
        if not rows:
            continue
        rows.sort(key=lambda r: r["start"])
        high, low, close = max(r["high"] for r in rows), min(r["low"] for r in rows), rows[-1]["close"]
        ma50 = sum(list(closes)[-50:]) / 50 if len(closes) >= 50 else None
        ma200 = sum(closes) / 200 if len(closes) == 200 else None
        regime = 0
        if previous and ma50 is not None and ma200 is not None:
            regime = 1 if previous["close"] > ma200 and ma50 > ma200 else (-1 if previous["close"] < ma200 and ma50 < ma200 else 0)
        daily[day] = {
            "open": rows[0]["open"], "high": high, "low": low, "close": close,
            "prior_position": previous["position"] if previous else None,
            "ma50": ma50, "ma200": ma200, "ma_regime": regime,
            "asia_fvg_sign": asia_fvg.get(day, {}).get("sign", 0),
            "asia_fvg_count": asia_fvg.get(day, {}).get("count", 0),
        }
        position = (close - low) / (high - low) if high > low else 0.5
        previous = {"close": close, "position": position}
        closes.append(close)

    ny_keys = sorted(sessions["NY_CASH"])
    for day, rec in daily.items():
        cash = sessions["CASH_OPEN"].get(day)
        pd = CSCAN._previous_key(ny_keys, day)
        prev = sessions["NY_CASH"].get(pd) if pd else None
        rec["overnight_gap_atr"] = ((cash["open"] - prev["close"]) / prev["atr"]) if cash and prev and prev.get("atr") else None

    obj = {
        "schema": BASE_SCHEMA, "symbol": symbol, "years_opened": list(YEARS),
        "cost_prior": dict(zip(("spread_rt", "slip_rt", "tick", "source"), CSCAN.cost_prior(symbol))),
        "structural": {"bars": bars_total, "ohlc_violations": violations}, "source_files": sources,
        "sessions": sessions, "daily": daily,
    }
    _write_gzip_json(path, obj)
    return obj


def assert_closed(feature_cutoff: int, target_entry: int, label: str = "feature") -> None:
    if feature_cutoff >= target_entry:
        raise AssertionError(f"LOOKAHEAD:{label}:feature_cutoff={feature_cutoff}>=target_entry={target_entry}")


def _next_day_key(keys: list[str], day: str) -> str | None:
    i = bisect.bisect_right(keys, day)
    return keys[i] if i < len(keys) else None


def build_rows(execution_symbol: str, bases: dict[str, dict[str, Any]], start: dt.date = START, end: dt.date = END) -> list[dict[str, Any]]:
    exe = bases[execution_symbol]
    if exe["structural"]["bars"] == 0:
        return []
    cost_price = exe["cost_prior"]["spread_rt"] + exe["cost_prior"]["slip_rt"]
    rows: list[dict[str, Any]] = []
    refs = [s for s in REFERENCE_SYMBOLS if s in bases and bases[s]["structural"]["bars"] > 0]
    for current_session in CSCAN.SESSION_ORDER:
        target_session, next_day = NEXT_SESSION[current_session]
        target_keys = sorted(exe["sessions"][target_session])
        for day, current in exe["sessions"][current_session].items():
            target_day = _next_day_key(target_keys, day) if next_day else day
            target = exe["sessions"][target_session].get(target_day) if target_day else None
            if not target or not target.get("atr") or target["atr"] <= 0:
                continue
            td = dt.date.fromisoformat(target_day)
            if not (start <= td <= end):
                continue
            feature_cutoff = int(current["data_cutoff"])
            assert_closed(feature_cutoff, int(target["start"]), f"{execution_symbol}:{current_session}->{target_session}:{day}")
            own_daily = exe["daily"].get(day, {})
            features: dict[str, float | int | None] = {
                "own_return_atr": current["ret"] / current["atr"] if current.get("atr") else None,
                "own_range_atr": current["range"] / current["atr"] if current.get("atr") else None,
                "own_vol_ratio": current.get("vol_ratio"),
                "own_compression": int(bool(current.get("compression"))),
                "own_ma_regime": own_daily.get("ma_regime"),
                "own_prior_day_position": own_daily.get("prior_position"),
                "own_asia_fvg_sign": own_daily.get("asia_fvg_sign"),
                "own_asia_fvg_count": own_daily.get("asia_fvg_count"),
                "own_overnight_gap_atr": own_daily.get("overnight_gap_atr") if feature_cutoff >= exe["sessions"].get("CASH_OPEN", {}).get(day, {}).get("start", 10**30) else None,
                "target_day_of_week": td.weekday(),
                "feature_time_of_day": CSCAN.SESSION_ORDER.index(current_session),
            }
            for ref_symbol in refs:
                ref = bases[ref_symbol]
                rr = ref["sessions"][current_session].get(day)
                rd = ref["daily"].get(day, {})
                prefix = "ref_" + ref_symbol.split(".")[0].lower()
                if rr:
                    assert_closed(int(rr["data_cutoff"]), int(target["start"]), f"{ref_symbol}:{current_session}:{day}")
                features.update({
                    prefix + "_return_atr": rr["ret"] / rr["atr"] if rr and rr.get("atr") else None,
                    prefix + "_range_atr": rr["range"] / rr["atr"] if rr and rr.get("atr") else None,
                    prefix + "_vol_ratio": rr.get("vol_ratio") if rr else None,
                    prefix + "_compression": int(bool(rr and rr.get("compression"))),
                    prefix + "_ma_regime": rd.get("ma_regime"),
                    prefix + "_asia_fvg_sign": rd.get("asia_fvg_sign"),
                })
            atr = target["atr"]
            gross_long = target["ret"] / atr
            cost = cost_price / atr
            rows.append({
                "execution_symbol": execution_symbol, "feature_session": current_session,
                "target_session": target_session, "feature_day": day, "target_day": target_day,
                "feature_cutoff": feature_cutoff, "target_entry": target["start"],
                "features": features, "target_long_net_r": gross_long - cost,
                "target_short_net_r": -gross_long - cost, "target_cost_r": cost,
                "target_hold_min": target["hold_min"],
            })
    return sorted(rows, key=lambda r: (r["execution_symbol"], r["target_session"], r["target_day"], r["feature_session"]))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--symbols", default="ALL")
    ap.add_argument("--cache-dir", default="D:/QM/reports/research/ml_rule_discovery/features_2018_2022")
    ap.add_argument("--no-reuse", action="store_true")
    ap.add_argument("--summary", default="D:/QM/reports/research/ml_rule_discovery/session_features_summary.json")
    args = ap.parse_args()
    symbols = CSCAN.UNIVERSE if args.symbols == "ALL" else tuple(sorted(s.strip() for s in args.symbols.split(",") if s.strip()))
    cache = Path(args.cache_dir)
    bases = {s: prepare_symbol(s, cache, not args.no_reuse) for s in symbols}
    summary = {
        "schema": SCHEMA, "years_opened": list(YEARS), "future_years_opened": [],
        "symbols": list(symbols), "symbols_with_rows": [s for s in symbols if bases[s]["structural"]["bars"]],
        "references": list(REFERENCE_SYMBOLS), "feature_contract": "last closed source-bar timestamp < target entry",
        "base_rows": {s: sum(len(v) for v in bases[s]["sessions"].values()) for s in symbols},
    }
    out = Path(args.summary); out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, sort_keys=True, indent=1) + "\n", encoding="utf-8")
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
