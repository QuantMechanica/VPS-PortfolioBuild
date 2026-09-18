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

Chain (schema v2, KPI contract section 2)
----------------------------------------
Since engine 2.0.0 the same sampler is chained over the whole path to the first
net cash payout, pathwise (a path either survives every stage or it does not):

    Phase 1 (+10 %)  ->  Verification (+5 %)  ->  funded account  ->  first reward

Every stage restarts on a FRESH 100k account (fresh Daily-Loss anchor, fresh
static 90k Max-Loss floor) and draws its OWN independent bootstrap blocks, so the
continuation is never the same resampled path replayed twice.  The funded stage
carries no profit target: it must survive to the first reward-eligible day (>= 14
calendar days after the first placed trade, mapped to business days, with net
closed profit > 0 and the book flat) plus the payout request/processing lag, all
without a Daily-Loss or Max-Loss breach.  The net-positive condition applies the
bound reward split and fee refund against the paid evaluation fee.  Uncertainty
is a batch bootstrap over the path set (default 20 batches x 500 paths); the
reported control value ``P_FIRST_NET_FTMO_PAYOUT_LCB`` is the 5th percentile.

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

SCHEMA = "qm.ftmo-first-passage/v2"
MANIFEST_SCHEMA = "qm.ftmo-first-passage-manifest/v2"
ENGINE_VERSION = "2.0.0"
KPI_CONTRACT_VERSION = "v1"  # docs/ftmo/FTMO_KPI_CONTRACT.md
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

# Funded-stage payout rule (FTMO_RULES_SNAPSHOT_2026-09-18): the first reward can
# be requested on the 14th or any following day after the FIRST PLACED TRADE on
# the FTMO Account, with every position and pending order closed; review plus
# payment then take ~1-2 + 1-2 business days, modelled as 4 business days during
# which the account must still not breach.
FUNDED_ELIGIBILITY_CALENDAR_DAYS = 14
PAYOUT_PROCESSING_BUSINESS_DAYS = 4
# Business-day horizon for the funded stage: first trade + eligibility + processing
# with generous slack for paths that are not yet in net profit at day 14.
DEFAULT_FUNDED_HORIZON = 120
# Credible interval: 20 batches x 500 paths of the default 10,000-path set.
DEFAULT_N_BATCHES = 20
# Fallback evaluation fee when the bound rulepack carries none (USD 100k 2-Step).
DEFAULT_FEE_USD = 540.0


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
        "phase2_target_fraction": float(contract.phase2_target_fraction),
        "daily_loss_fraction": float(contract.maximum_daily_loss_fraction),
        "total_loss_fraction": float(contract.maximum_total_loss_fraction),
        "min_trading_days": int(contract.minimum_trading_days),
        "timezone": contract.timezone,
        "breach_operator": contract.breach_operator,
        "target_operator": contract.target_operator,
        "maximum_loss_model": contract.maximum_loss_model,
    }


def load_economics(rulepack_path: Path | str = DEFAULT_RULEPACK_PATH, *,
                   fee_usd: float | None = None) -> dict[str, Any]:
    """Project the payout economics (fee, refund, reward split) from the rulepack.

    The fee is taken from the bound rulepack when it carries one; an explicit
    ``fee_usd`` overrides it (the live order-page amount is a documented GAP in
    ``docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md``); otherwise the conservative
    default is used and flagged as ``ASSUMED_DEFAULT`` - never silently invented.
    """
    pack = _load_json(Path(rulepack_path))
    rules = {}
    if isinstance(pack, dict):
        rules = {str(r.get("rule_id")): (r.get("parameters") or {})
                 for r in pack.get("official_rules") or []}

    def _num(rule_id: str, key: str) -> float | None:
        try:
            return float(rules.get(rule_id, {})[key])
        except (KeyError, TypeError, ValueError):
            return None

    pack_fee = _num("ftmo_2s_evaluation_fee", "list_fee_usd")
    if fee_usd is not None:
        fee, source = float(fee_usd), "CLI_OVERRIDE"
    elif pack_fee is not None:
        fee, source = pack_fee, "RULEPACK_LIST_FEE"
    else:
        fee, source = DEFAULT_FEE_USD, "ASSUMED_DEFAULT"
    split = _num("ftmo_2s_reward_split", "base_percent")
    refund = _num("ftmo_2s_fee_refund", "refund_percent")
    return {
        "fee_usd": round(fee, 2),
        "fee_source": source,
        "fee_note": ("list fee from the bound rulepack; the live order-page amount "
                     "(promotions included) is a documented GAP and must be recorded "
                     "at purchase time"),
        "reward_split_percent": split if split is not None else 80.0,
        "reward_split_source": "RULEPACK" if split is not None else "ASSUMED_DEFAULT",
        "fee_refund_percent": refund if refund is not None else 100.0,
        "fee_refund_source": "RULEPACK" if refund is not None else "ASSUMED_DEFAULT",
    }


def net_cash_from_profit(profit_usd: np.ndarray, economics: Mapping[str, Any]) -> np.ndarray:
    """First-reward net cash: split x funded net profit + fee refund - paid fee."""
    fee = float(economics["fee_usd"])
    split = float(economics["reward_split_percent"]) / 100.0
    refund = fee * float(economics["fee_refund_percent"]) / 100.0
    return split * np.maximum(profit_usd, 0.0) + refund - fee


def min_profit_for_net_positive(economics: Mapping[str, Any]) -> float:
    """Funded net profit at which the first reward strictly covers the fees."""
    fee = float(economics["fee_usd"])
    split = float(economics["reward_split_percent"]) / 100.0
    refund = fee * float(economics["fee_refund_percent"]) / 100.0
    if split <= 0.0:
        return float("inf")
    return max(0.0, (fee - refund) / split)


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


def _cost_adjusted(grid: Mapping[str, Any], cost_mult: float,
                   slippage_usd_per_lot: float) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Book daily (net, low, opened) after the scenario extra cost/slippage.

    float32 keeps peak memory modest (MT5 workers need headroom); PnL magnitudes
    (~1e4) are well inside float32 precision for probability estimation.
    """
    extra_cost = (cost_mult - 1.0) * grid["commission"] + slippage_usd_per_lot * grid["lots"]
    net = (grid["net"] - extra_cost).astype(np.float32)
    low = (grid["low"] - extra_cost).astype(np.float32)
    return net, low, grid["opened"]


def _phase_walk(net: np.ndarray, low: np.ndarray, opened: np.ndarray, idx: np.ndarray, *,
                target: float, daily_cap: float, total_cap: float,
                min_days: int) -> dict[str, Any]:
    """First-passage walk for ONE evaluation phase on a fresh account anchor.

    Every returned array is a per-path 0-based day index into the path (``sentinel``
    when the event never happens): pass day, daily-loss breach, max-loss breach,
    the day the target alone was first reached, and the day the minimum-trading-day
    requirement was first satisfied (the last two show which of the two pass
    conditions was binding - a path that reaches the target before its 4th trading
    day must keep trading and can still breach).
    """
    n_paths, horizon = idx.shape
    sentinel = horizon + 1

    net_p = net[idx]
    low_p = low[idx]
    cum_close = np.cumsum(net_p, axis=1)               # end-of-day cumulative
    equity_low = cum_close - net_p + low_p             # intraday trough (cum before today + today low)

    daily_breach_day = _first_true_day(low_p < -daily_cap, sentinel)
    del low_p
    total_breach_day = _first_true_day(equity_low < -total_cap, sentinel)
    del equity_low
    trading_days = np.cumsum(opened[idx].astype(np.int32), axis=1)
    target_only_day = _first_true_day(cum_close > target, sentinel)
    min_days_day = _first_true_day(trading_days >= min_days, sentinel)
    pass_mask = (cum_close > target) & (trading_days >= min_days)
    del cum_close, trading_days, net_p
    pass_day = _first_true_day(pass_mask, sentinel)
    del pass_mask
    return {
        "pass_day": pass_day,
        "daily_breach_day": daily_breach_day,
        "total_breach_day": total_breach_day,
        "target_only_day": target_only_day,
        "min_days_day": min_days_day,
        "sentinel": sentinel,
        "horizon": horizon,
        "n_paths": n_paths,
    }


def _resolve_phase(walk: Mapping[str, Any]) -> dict[str, np.ndarray]:
    """Resolve a phase walk into pass / breach / censored masks.

    Breaches are tested BEFORE the target on the same day (conservative).
    """
    horizon = walk["horizon"]
    pass_day = walk["pass_day"]
    daily_breach_day = walk["daily_breach_day"]
    total_breach_day = walk["total_breach_day"]
    breach_day = np.minimum(daily_breach_day, total_breach_day)
    passed = pass_day < breach_day
    breached = breach_day <= np.minimum(pass_day, horizon - 1)
    censored = ~passed & ~breached
    is_daily = breached & (daily_breach_day <= total_breach_day)
    is_total = breached & ~is_daily
    return {"passed": passed, "breached": breached, "censored": censored,
            "is_daily": is_daily, "is_total": is_total, "breach_day": breach_day}


def _funded_walk(net: np.ndarray, low: np.ndarray, opened: np.ndarray, idx: np.ndarray, *,
                 daily_cap: float, total_cap: float, eligibility_business_days: int,
                 processing_business_days: int) -> dict[str, Any]:
    """Funded-stage walk: survive to the first reward payout; no profit target.

    Reward eligibility = the first business day at or after ``eligibility_business_days``
    following the first PLACED trade on which net closed profit is strictly positive
    (positions flat, so the day-end closed balance is the tested quantity).  The payout
    then needs ``processing_business_days`` more, during which the account must still
    not breach Daily Loss or Maximum Loss.
    """
    n_paths, horizon = idx.shape
    sentinel = horizon + 1

    net_p = net[idx]
    low_p = low[idx]
    cum_close = np.cumsum(net_p, axis=1)
    equity_low = cum_close - net_p + low_p
    daily_breach_day = _first_true_day(low_p < -daily_cap, sentinel)
    del low_p
    total_breach_day = _first_true_day(equity_low < -total_cap, sentinel)
    del equity_low, net_p

    first_trade_day = _first_true_day(opened[idx], sentinel)
    cols = np.arange(horizon)[None, :]
    eligible = (cols >= (first_trade_day[:, None] + eligibility_business_days)) & (cum_close > 0.0)
    reward_day = _first_true_day(eligible, sentinel)
    del eligible
    payout_day = reward_day + processing_business_days

    reached = payout_day <= (horizon - 1)
    safe_reward = np.minimum(reward_day, horizon - 1)
    profit = cum_close[np.arange(n_paths), safe_reward].astype(np.float64)
    profit = np.where(reached, profit, 0.0)
    del cum_close

    breach_day = np.minimum(daily_breach_day, total_breach_day)
    survived = reached & (breach_day > payout_day)
    breached = breach_day <= np.minimum(payout_day, horizon - 1)
    is_daily = breached & (daily_breach_day <= total_breach_day)
    is_total = breached & ~is_daily
    return {
        "first_trade_day": first_trade_day,
        "reward_day": reward_day,
        "payout_day": payout_day,
        "profit_at_reward": profit,
        "daily_breach_day": daily_breach_day,
        "total_breach_day": total_breach_day,
        "breach_day": breach_day,
        "survived": survived,
        "breached": breached,
        "is_daily": is_daily,
        "is_total": is_total,
        "censored": ~survived & ~breached,
        "sentinel": sentinel,
        "horizon": horizon,
        "n_paths": n_paths,
    }


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

    net, low, opened = _cost_adjusted(grid, cost_mult, slippage_usd_per_lot)
    walk = _phase_walk(net, low, opened, idx, target=target, daily_cap=daily_cap,
                       total_cap=total_cap, min_days=min_days)
    outcome = _resolve_phase(walk)
    n_paths, horizon = idx.shape
    pass_day = walk["pass_day"]
    daily_breach_day = walk["daily_breach_day"]
    total_breach_day = walk["total_breach_day"]
    passed = outcome["passed"]
    breached = outcome["breached"]
    censored = outcome["censored"]
    is_daily = outcome["is_daily"]
    is_total = outcome["is_total"]

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
# Chain simulation (v2): Phase 1 -> Verification -> funded -> first net payout
# --------------------------------------------------------------------------- #
def _stage_index_matrix(seed: int, stage: int, n_grid: int, n_paths: int,
                        horizon: int, block_len: int) -> np.ndarray:
    """Independent, reproducible bootstrap draws for one chain stage.

    Each stage gets its own seed stream so the continuation is NOT the same
    resampled path replayed on a second account, while the whole chain stays
    reproducible from (seed, stage).
    """
    rng = np.random.default_rng([int(seed), int(stage)])
    return _bootstrap_index_matrix(rng, n_grid, n_paths, horizon, block_len)


def _share(mask: np.ndarray, denom: np.ndarray | None = None) -> float | None:
    """Share of True in ``mask`` (optionally within ``denom``); None if no base."""
    if denom is None:
        base = float(mask.shape[0])
        num = float(mask.sum())
    else:
        base = float(denom.sum())
        num = float((mask & denom).sum())
    if base <= 0.0:
        return None
    return round(num / base, 4)


def _batch_ci(num: np.ndarray, denom: np.ndarray | None, n_batches: int) -> dict[str, Any]:
    """90% credible interval from equal-size contiguous batches of the path set."""
    n = int(num.shape[0])
    size = n // max(1, int(n_batches))
    out: dict[str, Any] = {"n_batches": 0, "batch_size": size, "p05": None,
                           "p50": None, "p95": None}
    if size <= 0:
        return out
    values: list[float] = []
    for b in range(int(n_batches)):
        sl = slice(b * size, (b + 1) * size)
        if denom is None:
            base = float(size)
            hits = float(num[sl].sum())
        else:
            base = float(denom[sl].sum())
            hits = float((num[sl] & denom[sl]).sum())
        if base <= 0.0:
            continue  # empty conditioning set in this batch: no estimate, never a 0
        values.append(hits / base)
    if not values:
        return out
    arr = np.asarray(values, dtype=float)
    out.update({
        "n_batches": len(values),
        "p05": round(float(np.percentile(arr, 5)), 4),
        "p50": round(float(np.percentile(arr, 50)), 4),
        "p95": round(float(np.percentile(arr, 95)), 4),
    })
    return out


def _time_dist(days: np.ndarray) -> dict[str, Any]:
    """p10/p50/p90 business-day distribution over the selected paths."""
    days = np.asarray(days, dtype=float)
    if days.size == 0:
        return {"p10": None, "p50": None, "p90": None, "mean": None, "n": 0}
    return {
        "p10": round(float(np.percentile(days, 10)), 1),
        "p50": round(float(np.percentile(days, 50)), 1),
        "p90": round(float(np.percentile(days, 90)), 1),
        "mean": round(float(days.mean()), 1),
        "n": int(days.size),
    }


def _phase_stage_report(walk: Mapping[str, Any], outcome: Mapping[str, np.ndarray],
                        grid: Mapping[str, Any], idx: np.ndarray, *,
                        reached: np.ndarray | None, attribute: bool) -> dict[str, Any]:
    """Per-stage breach / pass / min-trading-day report for one evaluation phase."""
    passed = outcome["passed"]
    report: dict[str, Any] = {
        "p_pass": _share(passed),
        "p_daily_loss_breach": _share(outcome["is_daily"]),
        "p_max_loss_breach": _share(outcome["is_total"]),
        "p_censored": _share(outcome["censored"]),
    }
    if reached is not None:
        report["conditional_on_reaching_stage"] = {
            "n_paths_reaching": int(reached.sum()),
            "p_pass": _share(passed, reached),
            "p_daily_loss_breach": _share(outcome["is_daily"], reached),
            "p_max_loss_breach": _share(outcome["is_total"], reached),
            "p_censored": _share(outcome["censored"], reached),
        }
    # Minimum-trading-day rule: a path that reaches the target before its 4th
    # trading day has to keep trading and can still breach in the meantime.
    target_first = walk["target_only_day"] < walk["min_days_day"]
    reached_target = walk["target_only_day"] <= (walk["horizon"] - 1)
    report["min_trading_days"] = {
        "required": None,  # filled by the caller from the rulepack
        "p_target_before_min_days": _share(target_first & reached_target),
        "p_pass_delayed_by_min_days": _share(passed & target_first),
        "p_breached_after_target_before_min_days": _share(
            outcome["breached"] & target_first & reached_target),
    }
    if attribute:
        report["conditional_failure_modes"] = _attribute_breaches(
            grid, idx, outcome["is_daily"], outcome["is_total"],
            walk["daily_breach_day"], walk["total_breach_day"])
    return report


def simulate_chain(grid: Mapping[str, Any], rules: Mapping[str, Any],
                   economics: Mapping[str, Any], *, seed: int, n_paths: int,
                   block_len: int, horizon: int,
                   funded_horizon: int = DEFAULT_FUNDED_HORIZON,
                   n_batches: int = DEFAULT_N_BATCHES, cost_mult: float = 1.0,
                   slippage_usd_per_lot: float = 0.0,
                   phase1_idx: np.ndarray | None = None,
                   detail: bool = True) -> dict[str, Any]:
    """Pathwise Phase 1 -> Verification -> funded -> first net payout chain.

    Every path is carried through all three stages, so the end-to-end probability
    is a PATHWISE product (a path passes everything or it fails somewhere), not a
    product of independently reported marginals - both are reported.
    """
    initial = rules["initial_equity"]
    daily_cap = rules["daily_loss_fraction"] * initial
    total_cap = rules["total_loss_fraction"] * initial
    min_days = int(rules["min_trading_days"])
    p1_target = rules["target_fraction"] * initial
    p2_target = rules["phase2_target_fraction"] * initial
    n_grid = int(grid["business_days"])
    elig_bd = calendar_to_business_days(FUNDED_ELIGIBILITY_CALENDAR_DAYS)

    net, low, opened = _cost_adjusted(grid, cost_mult, slippage_usd_per_lot)

    # --- stage 1: Challenge (+10 %), fresh 100k anchor ---------------------- #
    idx1 = phase1_idx if phase1_idx is not None else _stage_index_matrix(
        seed, 1, n_grid, n_paths, horizon, block_len)
    w1 = _phase_walk(net, low, opened, idx1, target=p1_target, daily_cap=daily_cap,
                     total_cap=total_cap, min_days=min_days)
    o1 = _resolve_phase(w1)
    stage1 = _phase_stage_report(w1, o1, grid, idx1, reached=None, attribute=detail)
    stage1["min_trading_days"]["required"] = min_days
    if phase1_idx is None:
        del idx1

    # --- stage 2: Verification (+5 %), fresh 100k account, independent draws - #
    idx2 = _stage_index_matrix(seed, 2, n_grid, n_paths, horizon, block_len)
    w2 = _phase_walk(net, low, opened, idx2, target=p2_target, daily_cap=daily_cap,
                     total_cap=total_cap, min_days=min_days)
    o2 = _resolve_phase(w2)
    stage2 = _phase_stage_report(w2, o2, grid, idx2, reached=o1["passed"], attribute=detail)
    stage2["min_trading_days"]["required"] = min_days
    del idx2

    # --- stage 3: funded account, survive to the first reward payout -------- #
    idx3 = _stage_index_matrix(seed, 3, n_grid, n_paths, funded_horizon, block_len)
    w3 = _funded_walk(net, low, opened, idx3, daily_cap=daily_cap, total_cap=total_cap,
                      eligibility_business_days=elig_bd,
                      processing_business_days=PAYOUT_PROCESSING_BUSINESS_DAYS)
    reached_funded = o1["passed"] & o2["passed"]
    stage3: dict[str, Any] = {
        "p_survive_to_first_reward": _share(w3["survived"]),
        "p_daily_loss_breach": _share(w3["is_daily"]),
        "p_max_loss_breach": _share(w3["is_total"]),
        "p_censored": _share(w3["censored"]),
        "conditional_on_reaching_stage": {
            "n_paths_reaching": int(reached_funded.sum()),
            "p_survive_to_first_reward": _share(w3["survived"], reached_funded),
            "p_daily_loss_breach": _share(w3["is_daily"], reached_funded),
            "p_max_loss_breach": _share(w3["is_total"], reached_funded),
            "p_censored": _share(w3["censored"], reached_funded),
        },
        "reward_eligibility": {
            "calendar_days_after_first_trade": FUNDED_ELIGIBILITY_CALENDAR_DAYS,
            "eligibility_business_days": elig_bd,
            "processing_business_days": PAYOUT_PROCESSING_BUSINESS_DAYS,
            "horizon_business_days": funded_horizon,
            "rule": "first business day at/after the eligibility lag with net closed "
                    "profit > 0 and the book flat; payout after the processing lag, "
                    "no breach in between",
        },
    }
    if detail:
        stage3["conditional_failure_modes"] = _attribute_breaches(
            grid, idx3, w3["is_daily"], w3["is_total"],
            w3["daily_breach_day"], w3["total_breach_day"])
    del idx3

    # --- chain combination (pathwise) --------------------------------------- #
    end_to_end = reached_funded & w3["survived"]
    net_cash = net_cash_from_profit(w3["profit_at_reward"], economics)
    net_positive = end_to_end & (net_cash > 0.0)

    p_challenge = _share(o1["passed"])
    p_verif_given = _share(o2["passed"], o1["passed"])
    p_funded_given = _share(w3["survived"], reached_funded)
    p_pathwise = _share(end_to_end)
    p_net = _share(net_positive)
    marginals = {
        "phase1": _share(o1["passed"]),
        "verification": _share(o2["passed"]),
        "funded_survival": _share(w3["survived"]),
    }
    product_of_marginals = None
    if all(v is not None for v in marginals.values()):
        product_of_marginals = round(
            marginals["phase1"] * marginals["verification"] * marginals["funded_survival"], 4)

    intervals = {
        "P_CHALLENGE_PASS": _batch_ci(o1["passed"], None, n_batches),
        "P_VERIFICATION_PASS_GIVEN_CHALLENGE": _batch_ci(o2["passed"], o1["passed"], n_batches),
        "P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD": _batch_ci(w3["survived"], reached_funded, n_batches),
        "P_END_TO_END_FIRST_PAYOUT": _batch_ci(end_to_end, None, n_batches),
        "P_FIRST_NET_FTMO_PAYOUT": _batch_ci(net_positive, None, n_batches),
    }

    days_p1 = (w1["pass_day"] + 1)[o1["passed"]].astype(float)
    days_p2 = (w2["pass_day"] + 1)[o2["passed"] & o1["passed"]].astype(float)
    days_payout = (w3["payout_day"] + 1)[end_to_end].astype(float)
    days_total = (w1["pass_day"] + w2["pass_day"] + w3["payout_day"] + 3)[end_to_end].astype(float)

    profit_paid = w3["profit_at_reward"][net_positive]
    cash_paid = net_cash[net_positive]

    return {
        "kpi_contract_version": KPI_CONTRACT_VERSION,
        "engine_version": ENGINE_VERSION,
        "cost_mult": round(float(cost_mult), 4),
        "slippage_usd_per_lot": round(float(slippage_usd_per_lot), 4),
        "n_paths": int(n_paths),
        "probabilities": {
            "P_CHALLENGE_PASS": p_challenge,
            "P_VERIFICATION_PASS_GIVEN_CHALLENGE": p_verif_given,
            "P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD": p_funded_given,
            "P_END_TO_END_FIRST_PAYOUT": p_pathwise,
            "P_END_TO_END_FIRST_PAYOUT_PRODUCT_OF_MARGINALS": product_of_marginals,
            "P_FIRST_NET_FTMO_PAYOUT": p_net,
            "P_FIRST_NET_FTMO_PAYOUT_LCB": intervals["P_FIRST_NET_FTMO_PAYOUT"]["p05"],
        },
        "marginals_unconditional": marginals,
        "credible_intervals_90pct": intervals,
        "stages": {"phase1": stage1, "verification": stage2, "funded": stage3},
        "time_business_days": {
            "phase1_target": _time_dist(days_p1),
            "verification_target": _time_dist(days_p2),
            "first_payout": _time_dist(days_payout),
            "end_to_end": _time_dist(days_total),
        },
        "net_condition": {
            "fee_usd": economics["fee_usd"],
            "fee_source": economics["fee_source"],
            "reward_split_percent": economics["reward_split_percent"],
            "fee_refund_percent": economics["fee_refund_percent"],
            "min_funded_profit_usd_for_net_positive": round(
                min_profit_for_net_positive(economics), 2),
            "formula": "net_cash = split x funded_net_profit_at_payout + fee_refund - fee",
            "funded_profit_at_payout_usd": _time_dist(profit_paid) if profit_paid.size else
                {"p10": None, "p50": None, "p90": None, "mean": None, "n": 0},
            "net_cash_usd": _time_dist(cash_paid) if cash_paid.size else
                {"p10": None, "p50": None, "p90": None, "mean": None, "n": 0},
        },
        "method": (
            "Pathwise chain over the SAME block-bootstrap sampler: Phase 1 (+10 %), "
            "Verification (+5 %) and the funded account each start on a fresh 100k "
            "balance anchor with a fresh static 90k Max-Loss floor and draw their own "
            "independent blocks. The funded stage has no profit target: it must reach "
            "the first reward-eligible day and survive the payout processing lag. "
            "End-to-end is counted per path, never as a product of marginals."
        ),
    }


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
              roster_source: str, economics: Mapping[str, Any] | None = None,
              chain: bool = True, funded_horizon: int = DEFAULT_FUNDED_HORIZON,
              n_batches: int = DEFAULT_N_BATCHES,
              extra: Mapping[str, Any] | None = None) -> dict[str, Any]:
    manifest = {
        "schema": MANIFEST_SCHEMA,
        "engine_version": ENGINE_VERSION,
        "kpi_contract_version": KPI_CONTRACT_VERSION,
        "chain_enabled": bool(chain),
        "chain_stage_seeds": {"phase1": [seed, 1], "verification": [seed, 2], "funded": [seed, 3]},
        "funded_horizon_business_days": funded_horizon,
        "funded_eligibility_calendar_days": FUNDED_ELIGIBILITY_CALENDAR_DAYS,
        "payout_processing_business_days": PAYOUT_PROCESSING_BUSINESS_DAYS,
        "credible_interval_batches": n_batches,
        "economics": dict(economics) if economics else None,
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
          economics: Mapping[str, Any] | None = None, chain: bool = True,
          funded_horizon: int = DEFAULT_FUNDED_HORIZON,
          n_batches: int = DEFAULT_N_BATCHES,
          now: dt.datetime | None = None) -> dict[str, Any]:
    """Run the first-passage model for a resolved roster. Pure over its inputs."""
    now = now or dt.datetime.now(dt.timezone.utc)
    economics = dict(economics) if economics else load_economics()
    tz = ZoneInfo(rules["timezone"])
    sleeves: list[SleeveInput] = list(roster.get("sleeves") or [])
    roster_label = roster.get("roster_label", MISSING)
    roster_source = roster.get("roster_source", MISSING)

    manifest = _manifest(sleeves, rules, seed=seed, n_paths=n_paths, block_len=block_len,
                         horizon=horizon, sensitivity=sensitivity,
                         roster_label=roster_label, roster_source=roster_source,
                         economics=economics, chain=chain, funded_horizon=funded_horizon,
                         n_batches=n_batches,
                         extra={k: roster[k] for k in ("manifest_git_commit",
                                "manifest_frozen_at_utc", "roster_hash") if k in roster})
    manifest_sha = _canonical_sha256(manifest)

    base = {
        "schema": SCHEMA,
        "engine_version": ENGINE_VERSION,
        "kpi_contract_version": KPI_CONTRACT_VERSION,
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
                   "max_horizon_business_days": horizon,
                   "funded_horizon_business_days": funded_horizon,
                   "credible_interval_batches": n_batches,
                   "chain_enabled": bool(chain)},
        "economics": economics,
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

    if chain:
        chain_model = simulate_chain(
            grid, rules, economics, seed=seed, n_paths=n_paths, block_len=block_len,
            horizon=horizon, funded_horizon=funded_horizon, n_batches=n_batches,
            cost_mult=1.0, slippage_usd_per_lot=0.0, phase1_idx=idx, detail=True)
        # Same five cost/slippage scenarios as v1, now carried through the chain.
        chain_model["sensitivity"] = []
        for (c, sl) in sensitivity:
            if (c, sl) == (1.0, 0.0):
                scen = chain_model
            else:
                scen = simulate_chain(
                    grid, rules, economics, seed=seed, n_paths=n_paths,
                    block_len=block_len, horizon=horizon, funded_horizon=funded_horizon,
                    n_batches=n_batches, cost_mult=c, slippage_usd_per_lot=sl,
                    phase1_idx=idx, detail=False)
            probs = scen["probabilities"]
            chain_model["sensitivity"].append({
                "cost_mult": round(float(c), 4),
                "slippage_usd_per_lot": round(float(sl), 4),
                "P_CHALLENGE_PASS": probs["P_CHALLENGE_PASS"],
                "P_VERIFICATION_PASS_GIVEN_CHALLENGE": probs["P_VERIFICATION_PASS_GIVEN_CHALLENGE"],
                "P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD": probs["P_FTMO_ACCOUNT_SURVIVAL_TO_FIRST_REWARD"],
                "P_END_TO_END_FIRST_PAYOUT": probs["P_END_TO_END_FIRST_PAYOUT"],
                "P_FIRST_NET_FTMO_PAYOUT": probs["P_FIRST_NET_FTMO_PAYOUT"],
                "P_FIRST_NET_FTMO_PAYOUT_LCB": probs["P_FIRST_NET_FTMO_PAYOUT_LCB"],
            })
        base["chain"] = chain_model

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
    if chain:
        probs = base["chain"]["probabilities"]
        base["compact_for_readiness"].update({
            "p_challenge_pass": probs["P_CHALLENGE_PASS"],
            "p_end_to_end_first_payout": probs["P_END_TO_END_FIRST_PAYOUT"],
            "p_first_net_ftmo_payout": probs["P_FIRST_NET_FTMO_PAYOUT"],
            "p_first_net_ftmo_payout_lcb": probs["P_FIRST_NET_FTMO_PAYOUT_LCB"],
            "end_to_end_median_business_days":
                base["chain"]["time_business_days"]["end_to_end"]["p50"],
        })
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
                    chain: bool = True, funded_horizon: int = DEFAULT_FUNDED_HORIZON,
                    n_batches: int = DEFAULT_N_BATCHES, fee_usd: float | None = None,
                    write: bool = True, now: dt.datetime | None = None) -> dict[str, Any]:
    rules = load_rules(rulepack_path)
    economics = load_economics(rulepack_path, fee_usd=fee_usd)
    tz = ZoneInfo(rules["timezone"])
    if recompose_manifest is not None:
        roster = roster_from_recompose_manifest(Path(recompose_manifest), tz, label=recompose_label)
    else:
        roster = roster_from_demo_cycle(Path(demo_cycle_path), tz)
    model = build(roster=roster, rules=rules, seed=seed, n_paths=n_paths,
                  block_len=block_len, horizon=horizon, economics=economics,
                  chain=chain, funded_horizon=funded_horizon, n_batches=n_batches,
                  now=now)
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
    p.add_argument("--funded-horizon", type=int, default=DEFAULT_FUNDED_HORIZON,
                   help="business-day horizon for the funded stage (reward + payout lag)")
    p.add_argument("--batches", type=int, default=DEFAULT_N_BATCHES,
                   help="equal-size path batches for the 90%% credible interval")
    p.add_argument("--fee-usd", type=float, default=None,
                   help="paid evaluation fee; overrides the rulepack list fee")
    p.add_argument("--no-chain", action="store_true",
                   help="Phase-1 only (schema v1 fields); skips the payout chain")
    p.add_argument("--no-write", action="store_true")
    args = parser.parse_args(argv)
    if args.cmd == "build":
        model = build_and_write(
            out=Path(args.out), manifest_out=Path(args.manifest_out),
            rulepack_path=Path(args.rulepack),
            recompose_manifest=Path(args.recompose_manifest) if args.recompose_manifest else None,
            demo_cycle_path=Path(args.demo_cycle), recompose_label=args.recompose_label,
            seed=args.seed, n_paths=args.n_paths, block_len=args.block_len,
            horizon=args.horizon, chain=not args.no_chain,
            funded_horizon=args.funded_horizon, n_batches=args.batches,
            fee_usd=args.fee_usd, write=not args.no_write)
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
            if model.get("chain"):
                summary["chain"] = model["chain"]["probabilities"]
                summary["chain_time_business_days"] = model["chain"]["time_business_days"]
        print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
