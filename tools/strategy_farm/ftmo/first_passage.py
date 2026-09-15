"""Deterministic FTMO first-passage / breach model for the intended Demo portfolio.

OWNER-DEC-CBE-20260915, master directive 3 section 34 (and section 43 item I):

    * probability of profit-target hit,
    * probability of daily-loss violation,
    * probability of total-loss violation,
    * expected time distribution,
    * conditional failure modes.

    Use the representative intended Demo portfolio.
    Do not reduce the result to a single misleading score.

This module answers exactly that question with a seeded, calendar-aligned
block-bootstrap path simulation over the real per-sleeve daily-PnL streams of the
current 8-sleeve FTMO demo roster (or any candidate roster passed in), scaled to
the roster's actual per-sleeve risk.

Method
------
1. Roster resolution. The representative Demo portfolio is resolved either from a
   sealed recompose snapshot manifest (``qm.recompose-frozen-inputs/v1``; the
   ``demo_8`` incumbent already carries the FTMO->DWX symbol mapping and
   sha-pinned frozen streams) or from the live demo-cycle ledger with a documented
   FTMO->DWX symbol resolver.  Nothing is guessed: a sleeve whose DWX stream
   cannot be resolved is dropped with an explicit ``EVIDENCE_MISSING`` note.

2. Stream -> daily book.  Streams are RISK_FIXED $1000 on a 100k account
   (= 1.0 %/trade; the canonical convention shared with
   ``portfolio/recompose/metrics.py`` and ``ftmo_p1_mc.py``).  A sleeve at risk
   r% scales its P&L by r/1.0.  For each Prague calendar day a sleeve carries:
     * ``net``  - realized closed P&L that day,
     * ``low``  - a conservative intraday-low proxy from the per-trade account
                  MAE (``mae_acct``): the most-negative running cumulative of the
                  day's trades, each contributing its MAE at its trough then its
                  net (so intraday drawdown is modelled, not ignored),
     * ``opened`` - whether a position was opened that day (FTMO minimum-trading-
                    day qualifier),
     * ``lots`` / ``commission`` - for the cost/slippage sensitivity.
   The book value on a day is the sleeve sum; the book intraday low is the sleeve
   sum of lows (all sleeves at their trough at once - a conservative overstatement
   of drawdown, i.e. it never understates breach probability).

3. Block bootstrap.  A shared business-day grid is built over the window where
   ALL roster sleeves are active (the intersection [max(first), min(last)],
   matching ``recompose/metrics.py``), so cross-sleeve co-movement inside each
   real day is preserved.  A simulated path resamples contiguous blocks of
   business-day rows (block length preserves short-horizon autocorrelation and
   trade clustering) until it reaches the horizon.

4. First-passage walk (vectorised).  Official parameters come from the bound
   rulepack (never hardcoded): +10 % profit target on end-of-day balance,
   -5 % daily-loss on intraday equity vs the CE(S)T midnight balance, -10 %
   static total-loss on intraday equity, >= 4 opening days, no time limit.
   Breaches are tested on the conservative intraday low BEFORE the target on the
   same day.  Each path resolves to pass / daily-loss breach / total-loss breach /
   censored (still live at the horizon - reported, never hidden).

5. Conditional failure modes.  Every breach is attributed to the sleeve/symbol
   that dominated that day's drawdown and to the weekday, and split daily vs
   total, so the result names WHERE and WHEN the book dies rather than collapsing
   to one number.

6. Cost/slippage sensitivity.  The same bootstrap index matrix is reused across a
   small grid of (commission multiplier, slippage USD/lot) so the scenarios differ
   only by cost - an apples-to-apples sensitivity, not re-drawn noise.

Reproducibility.  The full run is reproducible from a frozen input manifest
(``qm.ftmo-first-passage-manifest/v1``): roster, per-stream sha256, seed, block
length, horizon and path count.  The same manifest + seed reproduce the same
read-model byte-for-byte (numbers are rounded deterministically).

Read-only and OWNER-safe.  This module reads streams and writes one read-model
(``D:/QM/reports/state/ftmo_first_passage.json``).  It never starts MT5, trades,
touches T_Live/AutoTrading, writes the farm DB, or acts on a paid Challenge - the
paid decision is OWNER-only (directive sections 13-14).  Backtest-derived,
gross-of-slippage; intraday equity is a per-trade-MAE proxy, so the model is
labelled a conservative approximation, not tick-exact mark-to-market.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo

import numpy as np

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm.portfolio.ftmo_rule_contract import load_two_step_contract

SCHEMA = "qm.ftmo-first-passage/v1"
MANIFEST_SCHEMA = "qm.ftmo-first-passage-manifest/v1"
REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUT = Path(r"D:\QM\reports\state\ftmo_first_passage.json")
DEFAULT_MANIFEST_OUT = Path(r"D:\QM\reports\state\ftmo_first_passage_manifest.json")
DEFAULT_DEMO_CYCLE = Path(r"D:\QM\reports\state\ftmo_demo_cycle.json")

# Default rulepack bound for the Demo (matches demo-cycle compliance tag and the
# 2-Step / 100k / Standard default product; the official numeric rules are
# identical to the SWING pack, verified 2026-09-15).
DEFAULT_RULEPACK_PATH = (
    REPO_ROOT / "tools" / "strategy_farm" / "config" / "target_rulepacks"
    / "FTMO_2S_100K_STANDARD_V2.json"
)

# Stream source roots searched (in order) for the live-ledger path.
DEFAULT_STREAM_ROOTS = (
    Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\streams_v2b"),
    Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\streams"),
    Path(r"D:\QM\reports\portfolio\sleeve_streams"),
    Path(r"D:\QM\reports\portfolio\dxz_final_20260719"),
)
STREAM_SUBDIR = ("QM", "q08_trades")

# Canonical risk convention (shared with recompose/metrics.py and ftmo_p1_mc.py).
SOURCE_RISK_PCT = 1.0  # streams are RISK_FIXED $1000 on 100k = 1.0 %/trade

MISSING = "EVIDENCE_MISSING"

# Documented FTMO(broker) -> factory(.DWX) symbol resolution. Broker suffixes
# (.cash/.pro/...) are stripped; a small alias table maps names the factory keeps
# under a different base (all sourced from framework/registry/venue_cost_model.json
# and dwx_symbol_matrix conventions). Never a guess: an unresolved symbol drops
# the sleeve with EVIDENCE_MISSING.
_SYMBOL_ALIASES = {
    "USOIL": "XTIUSD",
    "WTI": "XTIUSD",
    "UKOIL": "XBRUSD",
    "BRENT": "XBRUSD",
    "US100": "NDX",
    "USTEC": "NDX",
    "NAS100": "NDX",
    "US500": "SP500",
    "SPX500": "SP500",
    "US30": "WS30",
    "DJI": "WS30",
    "GER40": "GDAXI",
    "DE40": "GDAXI",
    "UK100": "UK100",
    "XNGUSD": "XNGUSD",
    "NATGAS": "XNGUSD",
}

# Bounded-horizon marks reported alongside the (no-deadline) first passage. FTMO
# has no maximum trading period; these named CALENDAR-day marks are a diagnostic
# convenience mapped to business days via the 5/7 trading-week ratio.
_NAMED_CALENDAR_HORIZONS = (30, 60, 90, 180, 252)


def resolve_dwx_symbol(ftmo_symbol: str) -> str:
    """FTMO/broker symbol -> factory .DWX symbol (documented, never a guess)."""
    base = str(ftmo_symbol or "").upper().strip()
    base = base.split(".", 1)[0]  # strip .cash / .pro / ...
    base = _SYMBOL_ALIASES.get(base, base)
    return f"{base}.DWX"


def calendar_to_business_days(calendar_days: int) -> int:
    """Business-day horizon for a named calendar-day mark (5/7 trading week)."""
    return max(1, int(round(calendar_days * 5.0 / 7.0)))


# --------------------------------------------------------------------------- #
# Rulepack projection
# --------------------------------------------------------------------------- #
def load_rules(rulepack_path: Path | str = DEFAULT_RULEPACK_PATH) -> dict[str, Any]:
    """Project the official FTMO parameters from the bound rulepack."""
    contract = load_two_step_contract(rulepack_path)
    return {
        "id": contract.rulepack_id,
        "as_of": contract.rulepack_as_of,
        "canonical_sha256": contract.canonical_sha256,
        "initial_equity": float(contract.initial_equity),
        "target_fraction": float(contract.phase1_target_fraction),
        "daily_loss_fraction": float(contract.maximum_daily_loss_fraction),
        "total_loss_fraction": float(contract.maximum_total_loss_fraction),
        "min_trading_days": int(contract.minimum_trading_days),
        "timezone": contract.timezone,
        "breach_operator": contract.breach_operator,
        "target_operator": contract.target_operator,
        "maximum_loss_model": contract.maximum_loss_model,
    }


# --------------------------------------------------------------------------- #
# Stream loading -> per-sleeve daily book
# --------------------------------------------------------------------------- #
def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parse_ts(value: Any) -> dt.datetime | None:
    if isinstance(value, (int, float)):
        try:
            return dt.datetime.fromtimestamp(float(value), tz=dt.timezone.utc)
        except (OverflowError, OSError, ValueError):
            return None
    text = str(value).strip()
    try:
        return dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        pass
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return dt.datetime.strptime(text[:19], fmt)
        except ValueError:
            continue
    return None


def parse_stream(lines: Iterable[str]) -> list[dict[str, Any]]:
    """Parse TRADE_CLOSED rows: close time, entry time, net, mae, lots, commission."""
    trades: list[dict[str, Any]] = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
            continue
        close = _parse_ts(row.get("time"))
        if close is None:
            continue
        try:
            net = float(row.get("net"))
        except (TypeError, ValueError):
            continue
        try:
            mae = min(float(row.get("mae_acct") or 0.0), 0.0)
        except (TypeError, ValueError):
            mae = 0.0
        try:
            lots = abs(float(row.get("volume") or 0.0))
        except (TypeError, ValueError):
            lots = 0.0
        try:
            commission = abs(float(row.get("commission") or 0.0))
        except (TypeError, ValueError):
            commission = 0.0
        entry = _parse_ts(row.get("entry_time"))
        trades.append(
            {"close": close, "entry": entry, "net": net, "mae": mae,
             "lots": lots, "commission": commission}
        )
    trades.sort(key=lambda t: t["close"])
    return trades


def sleeve_daily(trades: Sequence[Mapping[str, Any]], tz: ZoneInfo) -> dict[dt.date, dict[str, float]]:
    """Aggregate a sleeve's trades into per-Prague-day (net, low, lots, commission, opened).

    ``low`` is the conservative intraday-low proxy: the most-negative running
    cumulative over the day's trades, each contributing its MAE at its trough then
    its realized net. It is <= 0 and <= the day net.
    """
    by_day: dict[dt.date, list[Mapping[str, Any]]] = {}
    opened: dict[dt.date, bool] = {}
    for tr in trades:
        day = tr["close"].astimezone(tz).date()
        by_day.setdefault(day, []).append(tr)
        if tr["entry"] is not None:
            open_day = tr["entry"].astimezone(tz).date()
            opened[open_day] = True
    out: dict[dt.date, dict[str, float]] = {}
    for day, day_trades in by_day.items():
        cum = 0.0
        low = 0.0
        net = 0.0
        lots = 0.0
        commission = 0.0
        for tr in day_trades:  # already close-sorted globally, order preserved
            trough = cum + tr["mae"]
            if trough < low:
                low = trough
            cum += tr["net"]
            net += tr["net"]
            lots += tr["lots"]
            commission += tr["commission"]
        if net < low:  # safety: low must not exceed the realized end value upward
            low = net
        out[day] = {"net": net, "low": low, "lots": lots,
                    "commission": commission, "opened": 1.0 if opened.get(day) else 0.0}
    # days where a position was opened but none closed still count as opening days
    for day in opened:
        out.setdefault(day, {"net": 0.0, "low": 0.0, "lots": 0.0,
                             "commission": 0.0, "opened": 1.0})
        out[day]["opened"] = 1.0
    return out


# --------------------------------------------------------------------------- #
# Grid assembly
# --------------------------------------------------------------------------- #
class SleeveInput:
    __slots__ = ("ea_id", "ftmo_symbol", "dwx_symbol", "magic", "risk_pct",
                 "stream_path", "stream_sha256", "trades", "daily")

    def __init__(self, ea_id: Any, ftmo_symbol: str, dwx_symbol: str, magic: Any,
                 risk_pct: float, stream_path: str, stream_sha256: str,
                 trades: list[dict[str, Any]], daily: dict[dt.date, dict[str, float]]):
        self.ea_id = ea_id
        self.ftmo_symbol = ftmo_symbol
        self.dwx_symbol = dwx_symbol
        self.magic = magic
        self.risk_pct = float(risk_pct)
        self.stream_path = stream_path
        self.stream_sha256 = stream_sha256
        self.trades = trades
        self.daily = daily


def _business_days(start: dt.date, end: dt.date) -> list[dt.date]:
    days: list[dt.date] = []
    cur = start
    while cur <= end:
        if cur.weekday() < 5:
            days.append(cur)
        cur += dt.timedelta(days=1)
    return days


def build_grid(sleeves: Sequence[SleeveInput]) -> dict[str, Any]:
    """Build book-level business-day arrays over the all-active intersection window.

    Returns arrays (net, low, lots, commission, opened) plus per-day dominant
    negative-sleeve index and weekday, and window metadata. Sleeve PnL is scaled
    to its risk_pct (book weight) before summation.
    """
    active = [s for s in sleeves if s.daily]
    if not active:
        return {"ok": False, "reason": "no sleeve carries daily evidence"}
    start = max(min(s.daily) for s in active)
    end = min(max(s.daily) for s in active)
    if start > end:
        return {"ok": False, "reason": f"empty intersection window ({start} > {end})"}
    grid = _business_days(start, end)
    n = len(grid)
    net = np.zeros(n)
    low = np.zeros(n)
    lots = np.zeros(n)
    commission = np.zeros(n)
    opened = np.zeros(n, dtype=bool)
    # Per-sleeve scaled low on each grid day, to find the dominant loser per day.
    sleeve_low = np.zeros((len(active), n))
    active_book_days = 0
    for si, sleeve in enumerate(active):
        factor = sleeve.risk_pct / SOURCE_RISK_PCT
        for di, day in enumerate(grid):
            rec = sleeve.daily.get(day)
            if rec is None:
                continue
            net[di] += rec["net"] * factor
            low[di] += rec["low"] * factor
            lots[di] += rec["lots"] * factor
            commission[di] += rec["commission"] * factor
            if rec["opened"]:
                opened[di] = True
            sleeve_low[si, di] = rec["low"] * factor
    active_book_days = int(np.count_nonzero(net != 0.0) + np.count_nonzero((net == 0.0) & opened))
    # dominant negative sleeve per day (argmin of sleeve low); -1 when no drawdown
    dom_idx = np.full(n, -1, dtype=int)
    any_neg = sleeve_low.min(axis=0) < 0.0
    dom_idx[any_neg] = sleeve_low[:, any_neg].argmin(axis=0)
    weekday = np.array([d.weekday() for d in grid], dtype=int)
    return {
        "ok": True,
        "active_sleeves": active,
        "grid": grid,
        "start": start,
        "end": end,
        "business_days": n,
        "active_book_days": active_book_days,
        "net": net,
        "low": low,
        "lots": lots,
        "commission": commission,
        "opened": opened,
        "dom_idx": dom_idx,
        "weekday": weekday,
    }


# --------------------------------------------------------------------------- #
# Block-bootstrap first-passage simulation (vectorised)
# --------------------------------------------------------------------------- #
def _bootstrap_index_matrix(rng: np.random.Generator, n_grid: int, n_paths: int,
                            horizon: int, block_len: int) -> np.ndarray:
    block_len = max(1, min(block_len, n_grid))
    n_blocks = math.ceil(horizon / block_len)
    starts = rng.integers(0, n_grid - block_len + 1, size=(n_paths, n_blocks))
    offsets = np.arange(block_len)
    idx = starts[:, :, None] + offsets[None, None, :]
    idx = idx.reshape(n_paths, n_blocks * block_len)[:, :horizon]
    return idx


def _first_true_day(mask: np.ndarray, sentinel: int) -> np.ndarray:
    """First column index where mask is True per row, else sentinel."""
    horizon = mask.shape[1]
    day = np.where(mask, np.arange(horizon)[None, :], sentinel)
    return day.min(axis=1)


def simulate(grid: Mapping[str, Any], rules: Mapping[str, Any], *,
             idx: np.ndarray, cost_mult: float = 1.0, slippage_usd_per_lot: float = 0.0,
             attribute: bool = True) -> dict[str, Any]:
    """Vectorised first-passage walk over a prebuilt bootstrap index matrix.

    ``idx`` (paths x horizon) is generated once and reused across cost scenarios so
    scenarios differ only by cost, not by resampled noise.
    """
    initial = rules["initial_equity"]
    target = rules["target_fraction"] * initial
    daily_cap = rules["daily_loss_fraction"] * initial
    total_cap = rules["total_loss_fraction"] * initial
    min_days = rules["min_trading_days"]

    extra_cost = (cost_mult - 1.0) * grid["commission"] + slippage_usd_per_lot * grid["lots"]
    net = (grid["net"] - extra_cost).astype(np.float32)
    low = (grid["low"] - extra_cost).astype(np.float32)
    opened = grid["opened"]

    # float32 keeps peak memory modest (MT5 workers need headroom); PnL magnitudes
    # (~1e4) are well inside float32 precision for probability estimation.
    net_p = net[idx]
    low_p = low[idx]

    n_paths, horizon = idx.shape
    sentinel = horizon + 1

    cum_close = np.cumsum(net_p, axis=1)               # end-of-day cumulative
    equity_low = cum_close - net_p + low_p             # intraday equity trough (cum before today + today's low)

    daily_breach_day = _first_true_day(low_p < -daily_cap, sentinel)
    del low_p
    total_breach_day = _first_true_day(equity_low < -total_cap, sentinel)
    del equity_low
    trading_days = np.cumsum(opened[idx].astype(np.int32), axis=1)
    pass_mask = (cum_close > target) & (trading_days >= min_days)
    del cum_close, trading_days, net_p
    pass_day = _first_true_day(pass_mask, sentinel)
    del pass_mask

    breach_day = np.minimum(daily_breach_day, total_breach_day)
    # breaches tested before target on the same day (conservative)
    passed = pass_day < breach_day
    breached = breach_day <= np.minimum(pass_day, horizon - 1)
    censored = ~passed & ~breached
    is_daily = breached & (daily_breach_day <= total_breach_day)
    is_total = breached & ~is_daily

    n = float(n_paths)
    n_resolved = int(passed.sum() + breached.sum())
    # +1: pass_day is a 0-based column index; days-to-target is the 1-based count.
    days_to_target = pass_day + 1
    pass_days = days_to_target[passed].astype(float)  # business days to target

    def _pct(mask: np.ndarray) -> float:
        return round(float(mask.sum()) / n, 4)

    result: dict[str, Any] = {
        "cost_mult": round(float(cost_mult), 4),
        "slippage_usd_per_lot": round(float(slippage_usd_per_lot), 4),
        "n_paths": n_paths,
        "horizon_business_days": horizon,
        "p_target_hit": _pct(passed),
        "p_daily_loss_breach": _pct(is_daily),
        "p_max_loss_breach": _pct(is_total),
        "p_censored": _pct(censored),
        "n_resolved": n_resolved,
        "p_target_hit_conditional_on_resolution": (
            round(float(passed.sum()) / n_resolved, 4) if n_resolved else None
        ),
    }

    # time-to-target distribution (business days, passing paths only)
    if pass_days.size:
        result["time_to_target_business_days"] = {
            "p10": round(float(np.percentile(pass_days, 10)), 1),
            "p50": round(float(np.percentile(pass_days, 50)), 1),
            "p90": round(float(np.percentile(pass_days, 90)), 1),
            "mean": round(float(pass_days.mean()), 1),
        }
    else:
        result["time_to_target_business_days"] = {
            "p10": None, "p50": None, "p90": None, "mean": None
        }

    # bounded-horizon pass marks
    horizons = {}
    for cal in _NAMED_CALENDAR_HORIZONS:
        bd = calendar_to_business_days(cal)
        within = passed & (days_to_target <= bd)
        horizons[str(cal)] = {"business_days": bd, "p_pass": _pct(within)}
    result["pass_within_calendar_days"] = horizons

    if attribute:
        result["conditional_failure_modes"] = _attribute_breaches(
            grid, idx, is_daily, is_total, daily_breach_day, total_breach_day
        )
    return result


def _attribute_breaches(grid: Mapping[str, Any], idx: np.ndarray,
                        is_daily: np.ndarray, is_total: np.ndarray,
                        daily_breach_day: np.ndarray,
                        total_breach_day: np.ndarray) -> dict[str, Any]:
    """Attribute each breach to the dominant losing sleeve/symbol and weekday."""
    active = grid["active_sleeves"]
    dom_idx = grid["dom_idx"]
    weekday = grid["weekday"]
    breached = is_daily | is_total
    n_breach = int(breached.sum())
    modes: dict[str, Any] = {
        "n_breach": n_breach,
        "by_type": {"daily_loss": int(is_daily.sum()), "max_loss": int(is_total.sum())},
    }
    if n_breach == 0:
        modes["dominant_sleeve"] = []
        modes["dominant_symbol"] = {}
        modes["by_weekday"] = {}
        return modes
    rows = np.where(breached)[0]
    # breach column per breached path
    bcol = np.minimum(daily_breach_day, total_breach_day)[rows]
    grid_day = idx[rows, bcol]
    dom = dom_idx[grid_day]
    wd = weekday[grid_day]

    weekday_names = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    sleeve_counts: dict[str, int] = {}
    symbol_counts: dict[str, int] = {}
    weekday_counts: dict[str, int] = {}
    for d, w in zip(dom.tolist(), wd.tolist()):
        if d < 0:
            key = "UNATTRIBUTED"
            sym = "UNATTRIBUTED"
        else:
            sleeve = active[d]
            key = f"{sleeve.ea_id}:{sleeve.dwx_symbol}"
            sym = sleeve.dwx_symbol
        sleeve_counts[key] = sleeve_counts.get(key, 0) + 1
        symbol_counts[sym] = symbol_counts.get(sym, 0) + 1
        wname = weekday_names[w] if 0 <= w < len(weekday_names) else str(w)
        weekday_counts[wname] = weekday_counts.get(wname, 0) + 1

    modes["dominant_sleeve"] = [
        {"sleeve": k, "breaches": v, "share": round(v / n_breach, 4)}
        for k, v in sorted(sleeve_counts.items(), key=lambda kv: -kv[1])
    ]
    modes["dominant_symbol"] = {
        k: {"breaches": v, "share": round(v / n_breach, 4)}
        for k, v in sorted(symbol_counts.items(), key=lambda kv: -kv[1])
    }
    modes["by_weekday"] = {
        k: {"breaches": v, "share": round(v / n_breach, 4)}
        for k, v in sorted(weekday_counts.items(), key=lambda kv: -kv[1])
    }
    return modes


# --------------------------------------------------------------------------- #
# Roster resolution
# --------------------------------------------------------------------------- #
def _load_json(path: Path) -> Any:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _stream_from_roots(ea_id: Any, dwx_symbol: str,
                       stream_roots: Sequence[Path]) -> Path | None:
    fname = f"{ea_id}_{dwx_symbol.replace('.DWX', '_DWX')}.jsonl"
    for root in stream_roots:
        cand = Path(root, *STREAM_SUBDIR, fname)
        if cand.is_file():
            return cand
    return None


def _make_sleeve(ea_id: Any, ftmo_symbol: str, dwx_symbol: str, magic: Any,
                 risk_pct: float, stream_path: Path, tz: ZoneInfo) -> SleeveInput:
    trades = parse_stream(Path(stream_path).read_text(encoding="utf-8", errors="replace").splitlines())
    daily = sleeve_daily(trades, tz)
    return SleeveInput(
        ea_id=ea_id, ftmo_symbol=ftmo_symbol, dwx_symbol=dwx_symbol, magic=magic,
        risk_pct=risk_pct, stream_path=str(stream_path),
        stream_sha256=_sha256_file(stream_path), trades=trades, daily=daily,
    )


def roster_from_recompose_manifest(manifest_path: Path, tz: ZoneInfo, *,
                                   label: str = "demo_8") -> dict[str, Any]:
    """Resolve the intended Demo roster + sha-pinned streams from a sealed
    ``qm.recompose-frozen-inputs/v1`` snapshot manifest."""
    manifest_path = Path(manifest_path)
    manifest = _load_json(manifest_path)
    if not isinstance(manifest, dict):
        return {"ok": False, "reason": f"manifest unreadable: {manifest_path}"}
    incumbents = {i.get("label"): i for i in manifest.get("incumbents") or []}
    inc = incumbents.get(label)
    if not inc:
        return {"ok": False, "reason": f"incumbent label {label!r} not in manifest"}
    stream_root = manifest.get("streams", {}).get("stream_root", "streams")
    records = {r.get("key"): r for r in manifest.get("streams", {}).get("records") or []}
    sleeves: list[SleeveInput] = []
    dropped: list[dict[str, Any]] = []
    for s in inc.get("sleeves") or []:
        ea_id = s.get("ea_id")
        dwx = s.get("symbol")
        key = f"{ea_id}:{dwx}"
        rec = records.get(key)
        local = Path(manifest_path.parent, stream_root, *STREAM_SUBDIR,
                     f"{ea_id}_{str(dwx).replace('.DWX', '_DWX')}.jsonl")
        path = local if local.is_file() else (Path(rec["source_path"]) if rec and rec.get("source_path") else None)
        if path is None or not Path(path).is_file():
            dropped.append({"sleeve": key, "reason": "stream file missing"})
            continue
        sha = _sha256_file(path)
        if rec and rec.get("sha256") and rec["sha256"] != sha:
            dropped.append({"sleeve": key, "reason": f"sha256 mismatch vs manifest ({sha[:12]} != {rec['sha256'][:12]})"})
            continue
        sleeves.append(_make_sleeve(ea_id, s.get("ftmo_symbol", dwx), dwx,
                                    s.get("magic"), s.get("risk_pct"), path, tz))
    return {
        "ok": bool(sleeves),
        "sleeves": sleeves,
        "dropped": dropped,
        "roster_label": label,
        "roster_source": f"recompose_manifest:{manifest_path}",
        "manifest_git_commit": manifest.get("git_commit"),
        "manifest_frozen_at_utc": manifest.get("frozen_at_utc"),
    }


def roster_from_demo_cycle(demo_cycle_path: Path, tz: ZoneInfo, *,
                           stream_roots: Sequence[Path] = DEFAULT_STREAM_ROOTS) -> dict[str, Any]:
    """Resolve the live Demo roster from the demo-cycle ledger + stream roots."""
    ledger = _load_json(demo_cycle_path)
    if not isinstance(ledger, dict) or not ledger.get("roster"):
        return {"ok": False, "reason": f"demo-cycle ledger unreadable/empty: {demo_cycle_path}"}
    sleeves: list[SleeveInput] = []
    dropped: list[dict[str, Any]] = []
    for s in ledger["roster"]:
        ea_id = s.get("ea_id")
        ftmo_symbol = s.get("symbol")
        dwx = resolve_dwx_symbol(ftmo_symbol)
        path = _stream_from_roots(ea_id, dwx, stream_roots)
        if path is None:
            dropped.append({"sleeve": f"{ea_id}:{dwx}", "ftmo_symbol": ftmo_symbol,
                            "reason": "no DWX stream resolved in stream roots"})
            continue
        sleeves.append(_make_sleeve(ea_id, ftmo_symbol, dwx, s.get("magic"),
                                    s.get("risk_pct") or 0.0, path, tz))
    return {
        "ok": bool(sleeves),
        "sleeves": sleeves,
        "dropped": dropped,
        "roster_label": "live_demo_cycle",
        "roster_source": f"demo_cycle:{demo_cycle_path}",
        "roster_hash": ledger.get("roster_hash"),
    }


def roster_from_spec(spec: Sequence[Mapping[str, Any]], tz: ZoneInfo, *,
                     stream_roots: Sequence[Path] = DEFAULT_STREAM_ROOTS) -> dict[str, Any]:
    """Resolve an explicit candidate roster: [{ea_id, symbol|dwx_symbol, risk_pct, [stream_path]}]."""
    sleeves: list[SleeveInput] = []
    dropped: list[dict[str, Any]] = []
    for s in spec:
        ea_id = s.get("ea_id")
        ftmo_symbol = s.get("ftmo_symbol") or s.get("symbol")
        dwx = s.get("dwx_symbol") or resolve_dwx_symbol(ftmo_symbol)
        stream_path = s.get("stream_path")
        path = Path(stream_path) if stream_path else _stream_from_roots(ea_id, dwx, stream_roots)
        if path is None or not Path(path).is_file():
            dropped.append({"sleeve": f"{ea_id}:{dwx}", "reason": "no stream resolved"})
            continue
        sleeves.append(_make_sleeve(ea_id, ftmo_symbol, dwx, s.get("magic"),
                                    s.get("risk_pct") or 0.0, path, tz))
    return {"ok": bool(sleeves), "sleeves": sleeves, "dropped": dropped,
            "roster_label": "candidate", "roster_source": "explicit_spec"}


# --------------------------------------------------------------------------- #
# Top-level build
# --------------------------------------------------------------------------- #
DEFAULT_SEED = 20260915
DEFAULT_N_PATHS = 10000
DEFAULT_BLOCK_LEN = 10
# ~4 years of business days. FTMO has no time limit; this bounds the simulation
# and any path still live at the horizon is reported as censored, never hidden.
DEFAULT_HORIZON = 1008
DEFAULT_SENSITIVITY = (
    (1.0, 0.0),
    (1.0, 1.0),
    (1.0, 2.0),
    (1.5, 0.0),
    (1.5, 2.0),
)
LOW_POWER_MIN_ACTIVE_DAYS = 60


def _iso(ts: dt.datetime) -> str:
    return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


def _roster_rows(sleeves: Sequence[SleeveInput]) -> list[dict[str, Any]]:
    rows = []
    for s in sleeves:
        days = sorted(s.daily)
        rows.append({
            "ea_id": s.ea_id,
            "ftmo_symbol": s.ftmo_symbol,
            "dwx_symbol": s.dwx_symbol,
            "magic": s.magic,
            "risk_pct": s.risk_pct,
            "stream_path": s.stream_path,
            "stream_sha256": s.stream_sha256,
            "trades": len(s.trades),
            "active_days": len(s.daily),
            "span": f"{days[0]}..{days[-1]}" if days else MISSING,
        })
    return rows


def _manifest(sleeves: Sequence[SleeveInput], rules: Mapping[str, Any], *,
              seed: int, n_paths: int, block_len: int, horizon: int,
              sensitivity: Sequence[tuple[float, float]], roster_label: str,
              roster_source: str, extra: Mapping[str, Any] | None = None) -> dict[str, Any]:
    manifest = {
        "schema": MANIFEST_SCHEMA,
        "roster_label": roster_label,
        "roster_source": roster_source,
        "source_risk_pct": SOURCE_RISK_PCT,
        "seed": seed,
        "n_paths": n_paths,
        "block_len_business_days": block_len,
        "max_horizon_business_days": horizon,
        "sensitivity_scenarios": [{"cost_mult": c, "slippage_usd_per_lot": sl} for c, sl in sensitivity],
        "rulepack": {"id": rules["id"], "as_of": rules["as_of"],
                     "canonical_sha256": rules["canonical_sha256"]},
        "streams": [{"sleeve": f"{s.ea_id}:{s.dwx_symbol}", "risk_pct": s.risk_pct,
                     "stream_path": s.stream_path, "stream_sha256": s.stream_sha256}
                    for s in sleeves],
    }
    if extra:
        manifest.update(extra)
    return manifest


def _canonical_sha256(obj: Any) -> str:
    blob = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def build(*, roster: Mapping[str, Any], rules: Mapping[str, Any], seed: int = DEFAULT_SEED,
          n_paths: int = DEFAULT_N_PATHS, block_len: int = DEFAULT_BLOCK_LEN,
          horizon: int = DEFAULT_HORIZON,
          sensitivity: Sequence[tuple[float, float]] = DEFAULT_SENSITIVITY,
          now: dt.datetime | None = None) -> dict[str, Any]:
    """Run the first-passage model for a resolved roster. Pure over its inputs."""
    now = now or dt.datetime.now(dt.timezone.utc)
    tz = ZoneInfo(rules["timezone"])
    sleeves: list[SleeveInput] = list(roster.get("sleeves") or [])
    roster_label = roster.get("roster_label", MISSING)
    roster_source = roster.get("roster_source", MISSING)

    manifest = _manifest(sleeves, rules, seed=seed, n_paths=n_paths, block_len=block_len,
                         horizon=horizon, sensitivity=sensitivity,
                         roster_label=roster_label, roster_source=roster_source,
                         extra={k: roster[k] for k in ("manifest_git_commit",
                                "manifest_frozen_at_utc", "roster_hash") if k in roster})
    manifest_sha = _canonical_sha256(manifest)

    base = {
        "schema": SCHEMA,
        "generated_at_utc": _iso(now),
        "decision_role": "DECISION_SUPPORT_EVIDENCE",
        "label": "backtest-derived, gross-of-slippage; intraday equity = per-trade MAE proxy (conservative)",
        "roster_label": roster_label,
        "roster_source": roster_source,
        "roster": _roster_rows(sleeves),
        "dropped_sleeves": roster.get("dropped", []),
        "source_risk_pct": SOURCE_RISK_PCT,
        "rulepack": rules,
        "params": {"seed": seed, "n_paths": n_paths,
                   "block_len_business_days": block_len,
                   "max_horizon_business_days": horizon},
        "input_manifest": manifest,
        "input_manifest_sha256": manifest_sha,
    }

    if not sleeves:
        base["status"] = MISSING
        base["reason"] = "no roster sleeve resolved to a DWX stream"
        base["headline"] = MISSING
        return base

    grid = build_grid(sleeves)
    if not grid.get("ok"):
        base["status"] = MISSING
        base["reason"] = grid.get("reason", "grid not buildable")
        base["headline"] = MISSING
        return base

    low_power = grid["active_book_days"] < LOW_POWER_MIN_ACTIVE_DAYS
    base["window"] = {
        "start": grid["start"].isoformat(),
        "end": grid["end"].isoformat(),
        "business_days": grid["business_days"],
        "active_book_days": grid["active_book_days"],
        "low_power": low_power,
        "low_power_note": (
            f"only {grid['active_book_days']} active book days in the all-active window; "
            "estimates are low-power" if low_power else "adequate"
        ),
    }

    rng = np.random.default_rng(seed)
    idx = _bootstrap_index_matrix(rng, grid["business_days"], n_paths, horizon, block_len)

    headline = simulate(grid, rules, idx=idx, cost_mult=1.0,
                        slippage_usd_per_lot=0.0, attribute=True)
    sens = [
        simulate(grid, rules, idx=idx, cost_mult=c, slippage_usd_per_lot=sl, attribute=False)
        for (c, sl) in sensitivity
    ]

    ttt = headline["time_to_target_business_days"]
    named = headline["pass_within_calendar_days"]
    base["status"] = "OK"
    base["headline"] = headline
    base["sensitivity"] = [
        {"cost_mult": s["cost_mult"], "slippage_usd_per_lot": s["slippage_usd_per_lot"],
         "p_target_hit": s["p_target_hit"], "p_daily_loss_breach": s["p_daily_loss_breach"],
         "p_max_loss_breach": s["p_max_loss_breach"], "p_censored": s["p_censored"]}
        for s in sens
    ]
    base["compact_for_readiness"] = {
        "p_target_hit": headline["p_target_hit"],
        "p_target_hit_eventual": headline["p_target_hit_conditional_on_resolution"],
        "p_pass_30d": named["30"]["p_pass"],
        "p_pass_60d": named["60"]["p_pass"],
        "median_days": ttt["p50"],
        "p_daily_loss_breach": headline["p_daily_loss_breach"],
        "p_max_loss_breach": headline["p_max_loss_breach"],
        "p_censored": headline["p_censored"],
        "horizon_note": "p_pass_30d/60d are within-calendar-day marks mapped to "
                        "business days (5/7). FTMO has no maximum trading period: "
                        "p_target_hit is the pass share within the ~4y simulation "
                        "horizon and p_target_hit_eventual is conditional on a path "
                        "resolving (pass-or-breach). Speed, not eventual pass, is the "
                        "binding constraint here.",
    }
    base["method"] = (
        "Seeded calendar-aligned block bootstrap over the all-active intersection "
        "window of the roster's per-sleeve daily-PnL streams (scaled to each "
        "sleeve's risk_pct). Breaches tested on a conservative per-trade-MAE "
        "intraday-low proxy before the target; official parameters from the bound "
        "rulepack; no time limit; censoring reported. Not tick-exact mark-to-market."
    )
    return base


def load_for_readiness(path: Path = DEFAULT_OUT) -> dict[str, Any] | None:
    """Compact first-passage dict for challenge_readiness / ftmo_fitness, or None.

    Returns the keys the consumers expect (p_pass_30d, p_pass_60d, median_days,
    p_daily_loss_breach, p_max_loss_breach, p_target_hit, p_censored) plus a
    provenance stub; None when the read-model is absent or evidence-missing.
    """
    model = _load_json(path)
    if not isinstance(model, dict) or model.get("status") != "OK":
        return None
    compact = dict(model.get("compact_for_readiness") or {})
    if not compact:
        return None
    compact["generated_at_utc"] = model.get("generated_at_utc")
    compact["input_manifest_sha256"] = model.get("input_manifest_sha256")
    compact["roster_label"] = model.get("roster_label")
    return compact


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def build_and_write(*, out: Path = DEFAULT_OUT, manifest_out: Path = DEFAULT_MANIFEST_OUT,
                    rulepack_path: Path = DEFAULT_RULEPACK_PATH,
                    recompose_manifest: Path | None = None,
                    demo_cycle_path: Path = DEFAULT_DEMO_CYCLE,
                    recompose_label: str = "demo_8",
                    seed: int = DEFAULT_SEED, n_paths: int = DEFAULT_N_PATHS,
                    block_len: int = DEFAULT_BLOCK_LEN, horizon: int = DEFAULT_HORIZON,
                    write: bool = True, now: dt.datetime | None = None) -> dict[str, Any]:
    rules = load_rules(rulepack_path)
    tz = ZoneInfo(rules["timezone"])
    if recompose_manifest is not None:
        roster = roster_from_recompose_manifest(Path(recompose_manifest), tz, label=recompose_label)
    else:
        roster = roster_from_demo_cycle(Path(demo_cycle_path), tz)
    model = build(roster=roster, rules=rules, seed=seed, n_paths=n_paths,
                  block_len=block_len, horizon=horizon, now=now)
    if write:
        out = Path(out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(model, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        manifest_out = Path(manifest_out)
        manifest_out.parent.mkdir(parents=True, exist_ok=True)
        manifest_out.write_text(
            json.dumps(model["input_manifest"], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8")
    return model


def _main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="FTMO first-passage / breach model")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("build", help="run the model and write the read-model")
    p.add_argument("--out", default=str(DEFAULT_OUT))
    p.add_argument("--manifest-out", default=str(DEFAULT_MANIFEST_OUT))
    p.add_argument("--rulepack", default=str(DEFAULT_RULEPACK_PATH))
    p.add_argument("--recompose-manifest", default=None,
                   help="sealed qm.recompose-frozen-inputs/v1 manifest (preferred, sha-pinned)")
    p.add_argument("--recompose-label", default="demo_8")
    p.add_argument("--demo-cycle", default=str(DEFAULT_DEMO_CYCLE))
    p.add_argument("--seed", type=int, default=DEFAULT_SEED)
    p.add_argument("--n-paths", type=int, default=DEFAULT_N_PATHS)
    p.add_argument("--block-len", type=int, default=DEFAULT_BLOCK_LEN)
    p.add_argument("--horizon", type=int, default=DEFAULT_HORIZON)
    p.add_argument("--no-write", action="store_true")
    args = parser.parse_args(argv)
    if args.cmd == "build":
        model = build_and_write(
            out=Path(args.out), manifest_out=Path(args.manifest_out),
            rulepack_path=Path(args.rulepack),
            recompose_manifest=Path(args.recompose_manifest) if args.recompose_manifest else None,
            demo_cycle_path=Path(args.demo_cycle), recompose_label=args.recompose_label,
            seed=args.seed, n_paths=args.n_paths, block_len=args.block_len,
            horizon=args.horizon, write=not args.no_write)
        summary = {"status": model.get("status"), "roster_label": model.get("roster_label"),
                   "sleeves": len(model.get("roster") or []),
                   "dropped": len(model.get("dropped_sleeves") or [])}
        if model.get("status") == "OK":
            h = model["headline"]
            summary.update({
                "p_target_hit": h["p_target_hit"],
                "p_daily_loss_breach": h["p_daily_loss_breach"],
                "p_max_loss_breach": h["p_max_loss_breach"],
                "p_censored": h["p_censored"],
                "median_days_to_target": h["time_to_target_business_days"]["p50"],
                "window": model["window"],
            })
        print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
