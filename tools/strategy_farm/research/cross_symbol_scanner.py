#!/usr/bin/env python3
"""Deterministic Track-B cross-symbol/session transmission scanner.

This is a research prescreen, not an economic-validation gate.  It reads the
validated .DWX HCC M1 archive, builds DST-correct completed session windows,
charges the shared F2 round-trip spread/slippage priors, applies a locked
2018-07..2022-12 / 2023-2025 split, and controls the full family with
Benjamini-Hochberg FDR at ten percent.

The market-return convention is the F2 conservative market convention:
entry at the first available window-open price plus half the round-trip prior,
exit at the final completed bar minus half the prior.  The scanner extracts
session features one HCC year at a time to avoid retaining the full 39-symbol
M1 corpus in memory.  Time conversion, HCC decoding, and cost constants are
imported from the existing F1/F2 research engine; this is not a rival fill
simulator.

No cell reads validation data to choose its direction, threshold, session, or
peer-confirmation rule.  ``WORTH_MT5_TEST`` means only that the prescreen cell
survived FDR and the locked holdout.  Governed MT5 Every-Real-Tick evidence is
the economic judge.
"""
from __future__ import annotations

import argparse
import bisect
import datetime as dt
import gzip
import hashlib
import json
import math
import os
import statistics
import sys
from collections import defaultdict, deque
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo


REPO = Path("C:/QM/repo")
SESSION_TOOLS = REPO / "tools/strategy_farm/session_tools"
if str(SESSION_TOOLS) not in sys.path:
    sys.path.insert(0, str(SESSION_TOOLS))

import velocity_family_f1_sweep_0921 as F1  # noqa: E402
import velocity_family_f2_cash_session_0921 as F2  # noqa: E402
from hcc_m1_reader_0921 import TERMINALS, read_year  # noqa: E402


SCHEMA = "qm.cross-symbol-session-scan/v1"
FEATURE_SCHEMA = "qm.cross-symbol-session-features/v1"
SEED = 20260922
SEL = F1.SEL
VAL = F1.VAL
YEARS = tuple(range(2018, 2026))
LON = ZoneInfo("Europe/London")
NY = ZoneInfo("America/New_York")

ENERGY = ("XTIUSD", "XBRUSD", "XNGUSD")
UNIVERSE = tuple(sorted(s + ".DWX" for s in (*F1.FX, *F1.INDICES, *F1.METALS, *ENERGY)))
THRESHOLDS = (0.5, 1.0)
RELATIONS = (("CONTINUATION", 1), ("REVERSAL", -1))
CONFIRMATION_MODES = ("LEAD_ONLY", "PEER_CONFIRMED_15M")
MIN_SAMPLE = 30
FDR_Q = 0.10
ATR_LOOKBACK = 14
VOL_LOOKBACK = 60

# Every window has an explicit economic time zone.  The London/NY overlap is
# the common 13:00-16:00 London interval; DST divergence weeks are therefore
# mapped by zoneinfo rather than a hard-coded UTC offset.
SESSION_SPECS: dict[str, tuple[ZoneInfo, tuple[int, int], tuple[int, int]]] = {
    "ASIA": (LON, (0, 0), (7, 0)),
    "LONDON": (LON, (8, 0), (12, 0)),
    "NY_PREOPEN": (NY, (8, 0), (9, 30)),
    "CASH_OPEN": (NY, (9, 30), (10, 30)),
    "NY_CASH": (NY, (10, 30), (16, 0)),
    "LONDON_NY_OVERLAP": (LON, (13, 0), (16, 0)),
}
SESSION_ORDER = tuple(SESSION_SPECS)
PREDECESSOR = {
    "ASIA": "PRIOR_NY_CASH",
    "LONDON": "ASIA",
    "NY_PREOPEN": "LONDON",
    "CASH_OPEN": "NY_PREOPEN",
    "NY_CASH": "CASH_OPEN",
    "LONDON_NY_OVERLAP": "LONDON",
}


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def _date(s: str) -> dt.date:
    return dt.date.fromisoformat(s)


def _sign(v: float) -> int:
    return 1 if v > 0 else (-1 if v < 0 else 0)


def _mean(xs: list[float]) -> float | None:
    return sum(xs) / len(xs) if xs else None


def _quantile(xs: list[float], q: float) -> float:
    if not xs:
        raise ValueError("quantile requires data")
    ys = sorted(xs)
    pos = (len(ys) - 1) * q
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return ys[lo]
    return ys[lo] + (ys[hi] - ys[lo]) * (pos - lo)


def cost_prior(symbol: str) -> tuple[float, float, float, str]:
    """Return an explicit F2-format (spread_rt, slip_rt, tick, source) prior.

    Exact shared F2 priors win.  The broader scanner declares conservative
    class priors for the remaining archive symbols; these are labelled as
    priors, never presented as venue measurements.
    """
    if symbol in F2.COST_PRIOR:
        return F2.COST_PRIOR[symbol]
    base = symbol.split(".")[0]
    if len(base) == 6 and base[:3] in F1.STRICT_CCY and base[3:] in F1.STRICT_CCY:
        pip = 0.01 if base.endswith("JPY") else 0.0001
        return 1.5 * pip, 0.5 * pip, pip / 10.0, "declared conservative FX class prior derived from F2 priors"
    if base == "XAGUSD":
        return 0.025, 0.010, 0.001, "shared F3/F6 FTMO XAGUSD prior"
    if base == "JPN225":
        return 10.0, 5.0, 1.0, "declared conservative index class prior"
    if base == "XTIUSD":
        return 0.03, 0.01, 0.01, "shared F6 FTMO USOIL prior"
    if base == "XBRUSD":
        return 0.04, 0.02, 0.01, "declared conservative energy class prior; venue parity unresolved"
    if base == "XNGUSD":
        return 0.005, 0.002, 0.001, "declared conservative energy class prior"
    raise KeyError(f"no declared F2-format cost prior for {symbol}")


def _window_epochs(day: dt.date, spec: tuple[ZoneInfo, tuple[int, int], tuple[int, int]]) -> tuple[int, int]:
    tz, start_hm, end_hm = spec
    start = F1.server_from_local(dt.datetime(day.year, day.month, day.day, *start_hm, tzinfo=tz))
    end = F1.server_from_local(dt.datetime(day.year, day.month, day.day, *end_hm, tzinfo=tz))
    return start, end


def _dedupe_bars(rows: Iterable[tuple]) -> list[tuple]:
    out: list[tuple] = []
    last = None
    for row in rows:
        if row[0] != last:
            out.append(row)
            last = row[0]
    return out


def _source_path(symbol: str, year: int) -> Path | None:
    for root in TERMINALS:
        path = Path(root) / symbol / f"{year}.hcc"
        if path.exists():
            return path
    return None


def _extract_window(bars: list[tuple], times: list[int], start: int, end: int) -> dict[str, Any] | None:
    i = bisect.bisect_left(times, start)
    j = bisect.bisect_left(times, end)
    expected = max(1, int((end - start) / 60))
    if i >= j or j > len(bars):
        return None
    seg = bars[i:j]
    # Fail closed on partial/holiday windows and large boundary gaps.
    if len(seg) < int(expected * 0.80):
        return None
    if seg[0][0] - start > 5 * 60 or end - seg[-1][0] > 6 * 60:
        return None
    confirm_end = start + 15 * 60
    c = bisect.bisect_left(times, confirm_end, i, j)
    if c <= i or c >= j or times[c] - confirm_end > 5 * 60:
        return None
    op = float(seg[0][1])
    cl = float(seg[-1][4])
    hi = max(float(row[2]) for row in seg)
    lo = min(float(row[3]) for row in seg)
    post_confirm_open = float(bars[c][1])
    confirm_close = float(bars[c - 1][4])
    return {
        "start": start,
        "end": end,
        "open": op,
        "high": hi,
        "low": lo,
        "close": cl,
        "ret": cl - op,
        "range": hi - lo,
        "confirm_ret": confirm_close - op,
        "post_confirm_open": post_confirm_open,
        "post_confirm_ret": cl - post_confirm_open,
        "n": len(seg),
        "hold_min": (end - start) / 60.0,
        "post_confirm_hold_min": max(0.0, (end - confirm_end) / 60.0),
    }


def _feature_cache_path(cache_dir: Path, symbol: str) -> Path:
    return cache_dir / f"{symbol.replace('.', '_')}.json.gz"


def _read_feature_cache(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            obj = json.load(fh)
        if obj.get("schema") == FEATURE_SCHEMA:
            return obj
    except (OSError, json.JSONDecodeError):
        return None
    return None


def _write_feature_cache(path: Path, obj: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(obj, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    tmp = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    with tmp.open("wb") as base:
        with gzip.GzipFile(filename="", mode="wb", fileobj=base, mtime=0) as gz:
            gz.write(raw)
    os.replace(tmp, path)


def prepare_symbol(symbol: str, cache_dir: Path | None = None, reuse_cache: bool = True) -> dict[str, Any]:
    cache_path = _feature_cache_path(cache_dir, symbol) if cache_dir else None
    if cache_path and reuse_cache:
        cached = _read_feature_cache(cache_path)
        if cached is not None:
            return cached

    prior = cost_prior(symbol)
    sessions: dict[str, dict[str, dict[str, Any]]] = {name: {} for name in SESSION_ORDER}
    source_files: list[dict[str, Any]] = []
    structural = {"bars": 0, "ohlc_violations": 0, "duplicate_timestamps_dropped": 0}

    for year in YEARS:
        try:
            source_path = _source_path(symbol, year)
            raw = list(read_year(symbol, year))
        except FileNotFoundError:
            continue
        bars = _dedupe_bars(raw)
        structural["duplicate_timestamps_dropped"] += len(raw) - len(bars)
        structural["bars"] += len(bars)
        structural["ohlc_violations"] += sum(
            1 for row in bars if not (row[3] <= row[1] <= row[2] and row[3] <= row[4] <= row[2] and row[3] > 0)
        )
        if not bars:
            continue
        source_files.append({
            "year": year,
            "path": str(source_path).replace("\\", "/") if source_path else None,
            "size": source_path.stat().st_size if source_path else None,
        })
        times = [int(row[0]) for row in bars]
        day = dt.date(year, 1, 1)
        last = dt.date(year, 12, 31)
        while day <= last:
            if day.weekday() < 5:
                key = day.isoformat()
                for name, spec in SESSION_SPECS.items():
                    start, end = _window_epochs(day, spec)
                    rec = _extract_window(bars, times, start, end)
                    if rec is not None:
                        sessions[name][key] = rec
            day += dt.timedelta(days=1)

    # Prior-window ATR and rolling volatility state.  Both exclude the current
    # observation, so these fields are safe at entry time.
    for name in SESSION_ORDER:
        ranges: deque[float] = deque(maxlen=ATR_LOOKBACK)
        atr_history: deque[float] = deque(maxlen=VOL_LOOKBACK)
        for day in sorted(sessions[name]):
            rec = sessions[name][day]
            if len(ranges) == ATR_LOOKBACK:
                rec["atr"] = sum(ranges) / ATR_LOOKBACK
                if len(atr_history) >= 20:
                    hist = list(atr_history)
                    q1, q2 = _quantile(hist, 1 / 3), _quantile(hist, 2 / 3)
                    rec["vol_state"] = "LOW" if rec["atr"] <= q1 else ("HIGH" if rec["atr"] >= q2 else "MID")
                else:
                    rec["vol_state"] = None
                atr_history.append(rec["atr"])
            else:
                rec["atr"] = None
                rec["vol_state"] = None
            ranges.append(rec["range"])

    all_days = sorted(set().union(*(set(sessions[name]) for name in SESSION_ORDER)))
    daily: dict[str, dict[str, Any]] = {}
    for day in all_days:
        rows = [sessions[name][day] for name in SESSION_ORDER if day in sessions[name]]
        if not rows:
            continue
        rows.sort(key=lambda row: row["start"])
        high, low = max(row["high"] for row in rows), min(row["low"] for row in rows)
        close = rows[-1]["close"]
        daily[day] = {
            "open": rows[0]["open"], "high": high, "low": low, "close": close,
            "close_location": (close - low) / (high - low) if high > low else 0.5,
        }

    obj = {
        "schema": FEATURE_SCHEMA,
        "symbol": symbol,
        "cost_prior": {"spread_rt": prior[0], "slip_rt": prior[1], "tick": prior[2], "source": prior[3]},
        "structural": structural,
        "source_files": source_files,
        "sessions": sessions,
        "daily": daily,
    }
    if cache_path:
        _write_feature_cache(cache_path, obj)
    return obj


def _prepare_job(args: tuple[str, str | None, bool]) -> tuple[str, dict[str, Any]]:
    symbol, cache_dir, reuse = args
    return symbol, prepare_symbol(symbol, Path(cache_dir) if cache_dir else None, reuse)


def _previous_key(keys: list[str], day: str) -> str | None:
    i = bisect.bisect_left(keys, day) - 1
    return keys[i] if i >= 0 else None


def _period(values: list[dict[str, float]], bounds: tuple[dt.date, dt.date]) -> list[dict[str, float]]:
    a, b = bounds
    return [row for row in values if a <= _date(str(row["day"])) <= b]


def sample_stats(values: list[dict[str, float]], bounds: tuple[dt.date, dt.date]) -> dict[str, Any]:
    rows = _period(values, bounds)
    net = [float(row["net_r"]) for row in rows]
    gross = [float(row["gross_r"]) for row in rows]
    costs = [float(row["cost_r"]) for row in rows]
    holds = [float(row["hold_min"]) for row in rows]
    n = len(net)
    if not n:
        return {
            "n": 0, "mean_net_r": None, "median_net_r": None, "mean_gross_r": None,
            "mean_cost_r": None, "double_cost_mean_net_r": None, "t_stat": None,
            "p_one_sided": 1.0, "hit_rate": None, "mean_hold_min": None, "median_hold_min": None,
        }
    mean = sum(net) / n
    if n > 1:
        sd = statistics.stdev(net)
        if sd > 0:
            t_stat = mean / (sd / math.sqrt(n))
            # Normal-tail approximation is deterministic and sufficiently
            # conservative for the n>=30 FDR eligibility floor.
            p = 0.5 * math.erfc(t_stat / math.sqrt(2.0))
        else:
            t_stat = math.inf if mean > 0 else (-math.inf if mean < 0 else 0.0)
            p = 0.0 if mean > 0 else 1.0
    else:
        t_stat, p = None, 1.0
    return {
        "n": n,
        "mean_net_r": round(mean, 8),
        "median_net_r": round(statistics.median(net), 8),
        "mean_gross_r": round(sum(gross) / n, 8),
        "mean_cost_r": round(sum(costs) / n, 8),
        "double_cost_mean_net_r": round(sum(v - c for v, c in zip(net, costs)) / n, 8),
        "t_stat": None if t_stat is None else ("INF" if t_stat == math.inf else ("-INF" if t_stat == -math.inf else round(t_stat, 8))),
        "p_one_sided": round(max(0.0, min(1.0, p)), 12),
        "hit_rate": round(sum(v > 0 for v in net) / n, 8),
        "mean_hold_min": round(sum(holds) / n, 4),
        "median_hold_min": round(statistics.median(holds), 4),
    }


def _make_cell(cell_id: str, kind: str, meta: dict[str, Any], observations: list[dict[str, float]]) -> dict[str, Any]:
    return {
        "cell_id": cell_id,
        "kind": kind,
        **meta,
        "selection": sample_stats(observations, SEL),
        "validation": sample_stats(observations, VAL),
        "_observations": observations,
    }


def _cross_observations(
    ref: dict[str, Any], exe: dict[str, Any], session: str, threshold: float,
    confirmation: str, relation_mult: int,
) -> list[dict[str, float]]:
    r_sessions = ref["sessions"]
    x_rows = exe["sessions"][session]
    predecessor = PREDECESSOR[session]
    prior_keys = sorted(r_sessions["NY_CASH"]) if predecessor == "PRIOR_NY_CASH" else []
    cost_price = float(exe["cost_prior"]["spread_rt"]) + float(exe["cost_prior"]["slip_rt"])
    out: list[dict[str, float]] = []
    for day, x in x_rows.items():
        if not x.get("atr") or x["atr"] <= 0:
            continue
        if predecessor == "PRIOR_NY_CASH":
            pd = _previous_key(prior_keys, day)
            if pd is None:
                continue
            lead = r_sessions["NY_CASH"].get(pd)
        else:
            lead = r_sessions[predecessor].get(day)
        if not lead or not lead.get("atr") or lead["atr"] <= 0:
            continue
        lead_sign = _sign(float(lead["ret"]))
        if lead_sign == 0 or abs(float(lead["ret"])) / float(lead["atr"]) < threshold:
            continue
        if confirmation == "PEER_CONFIRMED_15M":
            peer = r_sessions[session].get(day)
            if not peer or _sign(float(peer["confirm_ret"])) != lead_sign:
                continue
            x_ret = float(x["post_confirm_ret"])
            hold = float(x["post_confirm_hold_min"])
        else:
            x_ret = float(x["ret"])
            hold = float(x["hold_min"])
        atr = float(x["atr"])
        gross = relation_mult * lead_sign * x_ret / atr
        cost = cost_price / atr
        out.append({"day": day, "gross_r": gross, "cost_r": cost, "net_r": gross - cost, "hold_min": hold})
    return out


def _directional_observations(
    exe: dict[str, Any], session: str, direction: int,
    predicate,
) -> list[dict[str, float]]:
    cost_price = float(exe["cost_prior"]["spread_rt"]) + float(exe["cost_prior"]["slip_rt"])
    out: list[dict[str, float]] = []
    for day, rec in exe["sessions"][session].items():
        if not rec.get("atr") or rec["atr"] <= 0 or not predicate(day, rec):
            continue
        atr = float(rec["atr"])
        gross = direction * float(rec["ret"]) / atr
        cost = cost_price / atr
        out.append({"day": day, "gross_r": gross, "cost_r": cost, "net_r": gross - cost, "hold_min": float(rec["hold_min"])})
    return out


def build_cells(
    prepared: dict[str, dict[str, Any]], symbols: Iterable[str],
    thresholds: tuple[float, ...] = THRESHOLDS,
    sessions: tuple[str, ...] = SESSION_ORDER,
    include_single: bool = True,
) -> list[dict[str, Any]]:
    syms = tuple(sorted(symbols))
    cells: list[dict[str, Any]] = []

    for ref_symbol in syms:
        for exe_symbol in syms:
            if ref_symbol == exe_symbol:
                continue
            ref, exe = prepared[ref_symbol], prepared[exe_symbol]
            for session in sessions:
                for threshold in thresholds:
                    for confirmation in CONFIRMATION_MODES:
                        for relation, mult in RELATIONS:
                            obs = _cross_observations(ref, exe, session, threshold, confirmation, mult)
                            cid = (
                                f"PAIR|R={ref_symbol}|X={exe_symbol}|W={session}|T={threshold:.2f}"
                                f"|C={confirmation}|REL={relation}"
                            )
                            cells.append(_make_cell(cid, "CROSS_SYMBOL", {
                                "reference_symbol": ref_symbol, "execution_symbol": exe_symbol,
                                "session": session, "predecessor_window": PREDECESSOR[session],
                                "threshold_atr": threshold, "confirmation": confirmation,
                                "relation": relation,
                            }, obs))

    if not include_single:
        return sorted(cells, key=lambda row: row["cell_id"])

    for symbol in syms:
        exe = prepared[symbol]
        daily_keys = sorted(exe["daily"])
        for session in sessions:
            for dow in range(5):
                for label, direction in (("LONG", 1), ("SHORT", -1)):
                    obs = _directional_observations(exe, session, direction, lambda d, _r, dow=dow: _date(d).weekday() == dow)
                    cid = f"SINGLE|X={symbol}|TYPE=DOW|W={session}|D={dow}|DIR={label}"
                    cells.append(_make_cell(cid, "DAY_OF_WEEK", {
                        "execution_symbol": symbol, "session": session, "day_of_week": dow, "direction": label,
                    }, obs))
            for state in ("LOW", "MID", "HIGH"):
                for label, direction in (("LONG", 1), ("SHORT", -1)):
                    obs = _directional_observations(exe, session, direction, lambda _d, r, state=state: r.get("vol_state") == state)
                    cid = f"SINGLE|X={symbol}|TYPE=VOL|W={session}|STATE={state}|DIR={label}"
                    cells.append(_make_cell(cid, "VOLATILITY_STATE", {
                        "execution_symbol": symbol, "session": session, "volatility_state": state, "direction": label,
                    }, obs))

            # Prior-day close at the top/bottom 20% of the combined completed
            # windows; relation is fixed before VAL.
            for relation, mult in RELATIONS:
                cost_price = float(exe["cost_prior"]["spread_rt"]) + float(exe["cost_prior"]["slip_rt"])
                obs: list[dict[str, float]] = []
                for day, rec in exe["sessions"][session].items():
                    pd = _previous_key(daily_keys, day)
                    prev = exe["daily"].get(pd) if pd else None
                    if not prev or not rec.get("atr") or rec["atr"] <= 0:
                        continue
                    loc = float(prev["close_location"])
                    signal = 1 if loc >= 0.8 else (-1 if loc <= 0.2 else 0)
                    if not signal:
                        continue
                    atr = float(rec["atr"])
                    gross = mult * signal * float(rec["ret"]) / atr
                    cost = cost_price / atr
                    obs.append({"day": day, "gross_r": gross, "cost_r": cost, "net_r": gross - cost, "hold_min": float(rec["hold_min"])})
                cid = f"SINGLE|X={symbol}|TYPE=PRIOR_EXTREME|W={session}|REL={relation}"
                cells.append(_make_cell(cid, "PRIOR_DAY_EXTREME", {
                    "execution_symbol": symbol, "session": session, "relation": relation,
                    "extreme_rule": "prior combined-window close in top/bottom 20 percent of range",
                }, obs))

        # Overnight gap -> US cash-open / remaining NY cash.  The gap is
        # current cash-open open minus the previous completed NY-cash close.
        ny_keys = sorted(exe["sessions"]["NY_CASH"])
        for session in ("CASH_OPEN", "NY_CASH"):
            for threshold in thresholds:
                for relation, mult in RELATIONS:
                    cost_price = float(exe["cost_prior"]["spread_rt"]) + float(exe["cost_prior"]["slip_rt"])
                    obs = []
                    for day, rec in exe["sessions"][session].items():
                        cash = exe["sessions"]["CASH_OPEN"].get(day)
                        pd = _previous_key(ny_keys, day)
                        prev = exe["sessions"]["NY_CASH"].get(pd) if pd else None
                        if not cash or not prev or not rec.get("atr") or rec["atr"] <= 0 or not prev.get("atr"):
                            continue
                        gap = float(cash["open"]) - float(prev["close"])
                        signal = _sign(gap)
                        if not signal or abs(gap) / float(prev["atr"]) < threshold:
                            continue
                        atr = float(rec["atr"])
                        gross = mult * signal * float(rec["ret"]) / atr
                        cost = cost_price / atr
                        obs.append({"day": day, "gross_r": gross, "cost_r": cost, "net_r": gross - cost, "hold_min": float(rec["hold_min"])})
                    cid = f"SINGLE|X={symbol}|TYPE=OVERNIGHT_GAP|W={session}|T={threshold:.2f}|REL={relation}"
                    cells.append(_make_cell(cid, "OVERNIGHT_GAP", {
                        "execution_symbol": symbol, "session": session, "threshold_atr": threshold, "relation": relation,
                    }, obs))
    return sorted(cells, key=lambda row: row["cell_id"])


def apply_bh(cells: list[dict[str, Any]], q: float = FDR_Q, min_sample: int = MIN_SAMPLE) -> dict[str, Any]:
    ranked: list[tuple[float, str, dict[str, Any]]] = []
    for cell in cells:
        sel = cell["selection"]
        p = float(sel["p_one_sided"]) if sel["n"] >= min_sample and (sel["mean_net_r"] or 0) > 0 else 1.0
        ranked.append((p, cell["cell_id"], cell))
    ranked.sort(key=lambda row: (row[0], row[1]))
    m = len(ranked)
    cutoff_rank = 0
    cutoff_p = None
    for rank, (p, _cid, _cell) in enumerate(ranked, 1):
        if p <= q * rank / m:
            cutoff_rank, cutoff_p = rank, p

    # Monotone BH adjusted p-values.
    qvals: dict[str, float] = {}
    running = 1.0
    for rank in range(m, 0, -1):
        p, cid, _cell = ranked[rank - 1]
        running = min(running, p * m / rank)
        qvals[cid] = min(1.0, running)

    for p, _cid, cell in ranked:
        sel, val = cell["selection"], cell["validation"]
        cell["fdr_q_value"] = round(qvals[cell["cell_id"]], 12)
        cell["fdr_reject_10pct"] = bool(cutoff_p is not None and p <= cutoff_p and sel["n"] >= min_sample)
        cell["validation_same_sign_half_effect"] = bool(
            cell["fdr_reject_10pct"] and val["n"] >= min_sample and (val["mean_net_r"] or 0) > 0
            and (val["mean_net_r"] or 0) >= 0.5 * (sel["mean_net_r"] or math.inf)
        )
        cell["state"] = (
            "WORTH_MT5_TEST" if cell["validation_same_sign_half_effect"]
            else ("UNKNOWN" if sel["n"] < min_sample or val["n"] < min_sample else "CLEAR_REJECT")
        )
    return {"q": q, "tests": m, "eligible_min_n": sum(c["selection"]["n"] >= min_sample for c in cells),
            "cutoff_rank": cutoff_rank, "cutoff_p": cutoff_p}


def attach_neighbor_robustness(cells: list[dict[str, Any]], thresholds: tuple[float, ...]) -> None:
    cross: dict[tuple, dict[tuple[str, float], dict[str, Any]]] = defaultdict(dict)
    for cell in cells:
        if cell["kind"] != "CROSS_SYMBOL":
            continue
        base = (cell["reference_symbol"], cell["execution_symbol"], cell["confirmation"], cell["relation"])
        cross[base][(cell["session"], float(cell["threshold_atr"]))] = cell
    for cell in cells:
        if cell["kind"] != "CROSS_SYMBOL":
            cell["neighbor_robustness"] = {"tested": False, "same_sign_neighbors": 0, "neighbors": []}
            continue
        base = (cell["reference_symbol"], cell["execution_symbol"], cell["confirmation"], cell["relation"])
        candidates: list[tuple[str, float]] = []
        ti = thresholds.index(float(cell["threshold_atr"]))
        for k in (ti - 1, ti + 1):
            if 0 <= k < len(thresholds):
                candidates.append((cell["session"], thresholds[k]))
        si = SESSION_ORDER.index(cell["session"])
        for k in (si - 1, si + 1):
            if 0 <= k < len(SESSION_ORDER):
                candidates.append((SESSION_ORDER[k], float(cell["threshold_atr"])))
        rows = []
        for key in candidates:
            nb = cross[base].get(key)
            if nb is None:
                continue
            same = bool((nb["selection"]["mean_net_r"] or 0) > 0 and (nb["validation"]["mean_net_r"] or 0) > 0)
            rows.append({"cell_id": nb["cell_id"], "same_positive_sign": same})
        detail = {
            "tested": True,
            "neighbors_tested": len(rows),
            "same_sign_neighbors": sum(r["same_positive_sign"] for r in rows),
        }
        # Keep the full adjacency trace where it is decision-relevant without
        # repeating long cell ids across tens of thousands of rejected cells.
        if cell.get("state") == "WORTH_MT5_TEST":
            detail["neighbors"] = rows
        cell["neighbor_robustness"] = detail


def survivor_hypothesis(cell: dict[str, Any]) -> dict[str, Any]:
    kind = cell["kind"]
    symbol = cell["execution_symbol"]
    session = cell["session"]
    if kind == "CROSS_SYMBOL":
        ref = cell["reference_symbol"]
        conf = cell["confirmation"]
        relation = cell["relation"].lower()
        entry = (
            f"After {PREDECESSOR[session]} closes, require |{ref} return| >= {cell['threshold_atr']:.2f} x its prior-14-window ATR; "
            f"trade {symbol} in {relation} direction at the {session} open"
        )
        if conf == "PEER_CONFIRMED_15M":
            entry += "; require the first completed 15-minute reference bar to agree and enter at the next bar open"
        rationale = "testable information transmission from a completed reference-market window into the execution market"
        refs = [ref]
    elif kind == "DAY_OF_WEEK":
        entry = f"On weekday {cell['day_of_week']}, enter {cell['direction']} {symbol} at the {session} open"
        rationale, refs = "persistent session/day inventory and funding flow", []
    elif kind == "VOLATILITY_STATE":
        entry = f"When prior-only rolling volatility state is {cell['volatility_state']}, enter {cell['direction']} {symbol} at the {session} open"
        rationale, refs = "session risk premium conditional on observable pre-entry volatility", []
    elif kind == "OVERNIGHT_GAP":
        entry = f"If the cash-open gap is >= {cell['threshold_atr']:.2f} prior-window ATR, trade {cell['relation'].lower()} through {session}"
        rationale, refs = "overnight inventory transfer into the cash session", []
    else:
        entry = f"If prior combined-window close is in its top/bottom 20%, trade {cell['relation'].lower()} through {session}"
        rationale, refs = "prior-day extreme inventory continuation/reversal", []
    return {
        "HYPOTHESIS_ID": "CSCAN-" + hashlib.sha256(cell["cell_id"].encode()).hexdigest()[:12].upper(),
        "CELL_ID": cell["cell_id"],
        "ECONOMIC_RATIONALE": rationale,
        "SYMBOLS": sorted(set([symbol, *refs])),
        "EXECUTION_SYMBOL": symbol,
        "REFERENCE_SYMBOLS": refs,
        "TIMEFRAME": "M1 source / completed session windows / first-15m confirmation where specified",
        "SESSION": session,
        "ENTRY_RULE": entry,
        "STOP_RULE": "hard stop 1.0 x the execution symbol's prior-14 same-window ATR; conservative gap-through fill in F2 mechanisation",
        "EXIT_RULE": f"time exit at the end of {session}; no overnight hold",
        "RISK_RULE": "RISK_FIXED per trade; 1R equals prior-14 same-window ATR; one position per symbol/session/day",
        "EXPECTED_BOOK_ROLE": "dense session-flat return stream with low overnight and swap exposure",
        "EXPECTED_OVERLAP": f"overlap concentrated in {session} and {','.join(sorted(set([symbol, *refs])))}",
        "COST_SENSITIVITY": {
            "selection_base_mean_net_r": cell["selection"]["mean_net_r"],
            "selection_double_cost_mean_net_r": cell["selection"]["double_cost_mean_net_r"],
            "validation_base_mean_net_r": cell["validation"]["mean_net_r"],
            "validation_double_cost_mean_net_r": cell["validation"]["double_cost_mean_net_r"],
        },
        "FALSIFICATION_TEST": "mechanise unchanged in the shared F2 engine, including the 1ATR stop and exact M1 gap fills; reject if MT5 Every-Real-Tick or locked holdout sign/effect fails",
        "DISCOVERY_SAMPLE": {"period": [SEL[0].isoformat(), SEL[1].isoformat()], **cell["selection"]},
        "VALIDATION_SAMPLE": {"period": [VAL[0].isoformat(), VAL[1].isoformat()], **cell["validation"]},
        "NEIGHBOURING_CELL_ROBUSTNESS": cell["neighbor_robustness"],
    }


def canonical_json(obj: Any, compact: bool = False) -> str:
    kwargs = {"sort_keys": True, "ensure_ascii": False, "allow_nan": False}
    if compact:
        return json.dumps(obj, separators=(",", ":"), **kwargs) + "\n"
    return json.dumps(obj, indent=1, **kwargs) + "\n"


def build_output(
    prepared: dict[str, dict[str, Any]], symbols: tuple[str, ...], cells: list[dict[str, Any]],
    thresholds: tuple[float, ...], bh: dict[str, Any],
) -> dict[str, Any]:
    clean_cells = []
    for cell in cells:
        clean_cells.append({k: v for k, v in cell.items() if k != "_observations"})
    survivors = [survivor_hypothesis(cell) for cell in cells if cell["state"] == "WORTH_MT5_TEST"]
    with_history = [s for s in symbols if prepared[s]["structural"]["bars"] > 0]
    without_history = [s for s in symbols if prepared[s]["structural"]["bars"] == 0]
    script = Path(__file__).resolve()
    return {
        "schema": SCHEMA,
        "script": str(script).replace("\\", "/"),
        "script_sha256": _sha256(script),
        "seed": SEED,
        "universe": list(symbols),
        "universe_count": len(symbols),
        "sessions": {name: {"timezone": str(spec[0]), "start": f"{spec[1][0]:02d}:{spec[1][1]:02d}", "end": f"{spec[2][0]:02d}:{spec[2][1]:02d}", "predecessor": PREDECESSOR[name]} for name, spec in SESSION_SPECS.items()},
        "thresholds_atr": list(thresholds),
        "confirmation_modes": list(CONFIRMATION_MODES),
        "relations": [name for name, _ in RELATIONS],
        "selection_period": [SEL[0].isoformat(), SEL[1].isoformat()],
        "validation_period": [VAL[0].isoformat(), VAL[1].isoformat()],
        "cost_model": "F2 conservative market convention: spread_rt + slip_rt charged once per round trip, normalised by prior-14 same-window ATR",
        "cost_priors": {s: prepared[s]["cost_prior"] for s in symbols},
        "multiple_testing": {**bh, "p_value": "one-sided normal-tail approximation of net-R t-stat; negative/zero SEL means assigned p=1", "minimum_sample_each_period": MIN_SAMPLE},
        "discipline": {
            "validation_used_for_tuning": False,
            "lookahead": "none: lead window is completed; peer mode waits for first completed 15m bar and enters at next open; ATR/volatility fields exclude current window",
            "ml_used": False,
            "economic_validation": "not claimed; WORTH_MT5_TEST requires governed MT5 evidence",
        },
        "counts": {
            "symbols": len(symbols), "ordered_pairs": len(symbols) * (len(symbols) - 1),
            "symbols_with_2018_2025_history": len(with_history),
            "symbols_without_2018_2025_history": len(without_history),
            "windows": len(SESSION_ORDER), "thresholds": len(thresholds),
            "hypotheses_total": len(cells),
            "cross_symbol_cells": sum(c["kind"] == "CROSS_SYMBOL" for c in cells),
            "single_symbol_cells": sum(c["kind"] != "CROSS_SYMBOL" for c in cells),
            "fdr_rejections": sum(c["fdr_reject_10pct"] for c in cells),
            "validation_confirmed": len(survivors),
            "states": dict(sorted((state, sum(c["state"] == state for c in cells)) for state in ("CLEAR_REJECT", "UNKNOWN", "WORTH_MT5_TEST"))),
        },
        "runtime_target_seconds": 7200,
        "data_availability": {
            "with_2018_2025_history": with_history,
            "without_2018_2025_history": without_history,
            "disposition": "declared cells remain in the family and fail closed as UNKNOWN when required history is absent",
        },
        "data": {s: {"structural": prepared[s]["structural"], "source_files": prepared[s]["source_files"]} for s in symbols},
        "survivors": survivors,
        "cells": clean_cells,
    }


def markdown_report(out: dict[str, Any]) -> str:
    c = out["counts"]
    lines = [
        "# Cross-symbol/session transmission scan — 2026-09-22",
        "",
        "State: research prescreen only. `WORTH_MT5_TEST` is not economic validation.",
        "",
        "## Result",
        "",
        f"The deterministic scan evaluated **{c['hypotheses_total']:,} cells** across {c['symbols']} symbols, "
        f"{c['ordered_pairs']:,} ordered pairs, {c['windows']} windows, and {c['thresholds']} locked lead-size thresholds. "
        f"BH FDR 10% rejected {c['fdr_rejections']:,} selection nulls; **{c['validation_confirmed']:,}** also retained the same positive net-R sign "
        "and at least half the selection effect in the locked 2023-2025 holdout.",
        "",
        f"Data availability: {c['symbols_with_2018_2025_history']} of {c['symbols']} declared symbols have 2018-2025 HCC history. "
        f"The missing-history symbols are `{', '.join(out['data_availability']['without_2018_2025_history'])}`; only 2026 files exist for them. "
        "Their pre-declared cells remain in the BH family and fail closed as `UNKNOWN`.",
        "",
        f"States: `{json.dumps(c['states'], sort_keys=True)}`. Runtime target: `< {out['runtime_target_seconds']} seconds on four workers`.",
        "",
        "## Locked method",
        "",
        "- SEL 2018-07-02..2022-12-31; VAL 2023-01-01..2025-12-31.",
        "- Lead thresholds: 0.5 and 1.0 prior-14 same-window ATR; continuation and reversal are separate tests.",
        "- Lead-only entries use only a completed predecessor window. Peer-confirmed entries wait for the first completed 15-minute reference bar and use the next bar open.",
        "- F2 spread plus slippage priors are charged once per round trip. Double-cost means are included per cell.",
        "- One-sided net-R t-stat p-values enter a single BH family at q=0.10; both SEL and VAL need at least 30 observations.",
        "- No validation threshold tuning, ML, terminal access, factory rows, roster changes, or gate changes.",
        "",
        "## Survivors in OWNER section-28 format",
        "",
    ]
    if not out["survivors"]:
        lines.append("No cell survived both FDR and the locked validation rule.")
    else:
        headers = ["HYPOTHESIS_ID", "EXECUTION_SYMBOL", "REFERENCE_SYMBOLS", "SESSION", "ENTRY_RULE", "STOP_RULE", "EXIT_RULE", "RISK_RULE", "ECONOMIC_RATIONALE", "EXPECTED_BOOK_ROLE", "EXPECTED_OVERLAP", "COST_SENSITIVITY", "FALSIFICATION_TEST", "DISCOVERY_SAMPLE", "VALIDATION_SAMPLE", "NEIGHBOURING_CELL_ROBUSTNESS"]
        lines.extend(["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"])
        for row in out["survivors"]:
            vals = []
            for h in headers:
                v = row[h]
                text = json.dumps(v, sort_keys=True, ensure_ascii=False) if isinstance(v, (dict, list)) else str(v)
                vals.append(text.replace("|", "\\|").replace("\n", " "))
            lines.append("| " + " | ".join(vals) + " |")
    lines.extend([
        "", "## Reproduction", "",
        "```powershell",
        "python tools/strategy_farm/research/cross_symbol_scanner.py --workers 4",
        "```",
        "",
        "The companion JSON contains every cell, its SEL/VAL statistics, BH q-value, state, neighboring-cell check, cost prior, and HCC source inventory.",
        "",
    ])
    return "\n".join(lines)


def run_scan(
    symbols: tuple[str, ...], workers: int, thresholds: tuple[float, ...], cache_dir: Path | None,
    reuse_cache: bool,
) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    prepared: dict[str, dict[str, Any]] = {}
    jobs = [(symbol, str(cache_dir) if cache_dir else None, reuse_cache) for symbol in symbols]
    if workers > 1 and len(jobs) > 1:
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for symbol, result in pool.map(_prepare_job, jobs):
                prepared[symbol] = result
                print(f"prepared {symbol}", file=sys.stderr, flush=True)
    else:
        for job in jobs:
            symbol, result = _prepare_job(job)
            prepared[symbol] = result
            print(f"prepared {symbol}", file=sys.stderr, flush=True)
    cells = build_cells(prepared, symbols, thresholds=thresholds)
    bh = apply_bh(cells)
    attach_neighbor_robustness(cells, thresholds)
    return prepared, cells, bh


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--symbols", default="ALL", help="ALL or comma-separated .DWX symbols")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--thresholds", default=",".join(str(v) for v in THRESHOLDS))
    ap.add_argument("--cache-dir", default="D:/QM/reports/research/cross_symbol_scanner/features_v1")
    ap.add_argument("--no-reuse-cache", action="store_true")
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_shadow/cross_symbol_scan_2026-09-22.json"))
    ap.add_argument("--report", default=str(REPO / "docs/research/ftmo_shadow/cross_symbol_scan_2026-09-22.md"))
    args = ap.parse_args()
    symbols = UNIVERSE if args.symbols == "ALL" else tuple(sorted(s.strip() for s in args.symbols.split(",") if s.strip()))
    unknown = sorted(set(symbols) - set(UNIVERSE))
    if unknown:
        ap.error(f"symbols outside declared universe: {unknown}")
    thresholds = tuple(sorted(float(v) for v in args.thresholds.split(",") if v.strip()))
    if not thresholds or any(v <= 0 for v in thresholds):
        ap.error("thresholds must be positive")
    started = dt.datetime.now(dt.timezone.utc)
    prepared, cells, bh = run_scan(symbols, max(1, args.workers), thresholds, Path(args.cache_dir) if args.cache_dir else None, not args.no_reuse_cache)
    elapsed = (dt.datetime.now(dt.timezone.utc) - started).total_seconds()
    out = build_output(prepared, symbols, cells, thresholds, bh)
    out_path, report_path = Path(args.out), Path(args.report)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(canonical_json(out, compact=True), encoding="utf-8", newline="\n")
    report_path.write_text(markdown_report(out), encoding="utf-8", newline="\n")
    runtime_observation = {"elapsed_seconds": round(elapsed, 3), "target_seconds": 7200, "within_target": elapsed < 7200}
    print(canonical_json({"out": str(out_path), "report": str(report_path), "counts": out["counts"], "bh": bh, "runtime_observation": runtime_observation}), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
