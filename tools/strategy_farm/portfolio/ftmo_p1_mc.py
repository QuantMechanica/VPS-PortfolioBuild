"""FTMO Phase-1 Monte-Carlo harness (trade-level bootstrap over factory evidence streams).

Answers, for candidate FTMO demo-book compositions: how fast does the book reach the
+10% Phase-1 target, and how often does it die on the -5% daily-loss or -10% total-loss
rule, within a trading-day horizon?

Method (see docs/ops/evidence/2026-07-20_ftmo_p1_mc_design.md):
  * Input = per-EA x symbol Q08 closed-trade JSONL streams (TRADE_CLOSED events with
    profit / swap / commission / volume / notional / entry_time / time). Frozen
    SHA-pinned copies (dxz24_weekend_frozen_20260717) are preferred where they exist;
    otherwise the current Common\\Files export is used and its SHA256 is recorded.
  * FTMO cost injection: the stream's DXZ tester commission is REPLACED by the FTMO
    commission from framework/registry/venue_cost_model.json (2026-07-19): forex flat
    $5/lot round-trip, indices commission-free, metals/energy pct-notional. The
    stream's tester swap is KEPT as a DXZ-derived proxy (no FTMO swap numbers exist on
    disk; venue model marks swap OPEN - never invented). Index sleeves holding
    overnight are flagged with a breakeven-swap figure instead.
  * Everything is backtest-derived and gross of slippage. .DWX real-tick history is
    spread-inclusive, so no extra spread is injected.
  * Risk scaling: source streams are RISK_FIXED $1000/trade on a 100k account
    (= 1.0%). A sleeve at risk r% multiplies its P&L by r/1.0.
  * MC: per-sleeve DAY-bundle bootstrap. A sleeve's historical stream is grouped into
    active-day bundles (all trades closed the same broker-time day stay together,
    preserving intra-day clustering). Each simulated trading day, each sleeve is
    active with its empirical daily arrival probability and, if active, realises a
    uniformly resampled historical day bundle. Sleeves are resampled independently
    (cross-sleeve correlation broken; the historical rolling-window evaluation, which
    preserves real calendar alignment, is reported alongside as the correlation-
    faithful anchor).
  * Phase-1 rules applied on closed daily P&L (floating intraday drawdown is not
    visible in these artifacts, so breach probabilities are lower bounds): fail when
    day P&L <= -daily_limit_pct of initial balance, fail when cumulative P&L <=
    -total_limit_pct, pass when cumulative P&L >= +target_pct and >= 4 trading days.
    Breaches are evaluated before the target on the same day (conservative).

Usage:
  python ftmo_p1_mc.py --out-dir D:/QM/reports/portfolio/ftmo_p1_mc_20260720
  python ftmo_p1_mc.py --list
  python ftmo_p1_mc.py --compositions a_motor_solo_100,c_full_book_equal_050
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import statistics
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[3]
VENUE_COST_MODEL_PATH = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"

FROZEN_STREAM_DIR = Path(
    r"D:\QM\reports\portfolio\dxz24_weekend_frozen_20260717\QM\q08_trades"
)
COMMON_STREAM_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\Common\Files\QM\q08_trades"
)

DEFAULT_CAPITAL = 100_000.0
DEFAULT_TARGET_PCT = 10.0
DEFAULT_DAILY_LIMIT_PCT = 5.0
DEFAULT_TOTAL_LIMIT_PCT = 10.0
DEFAULT_HORIZON_TRADING_DAYS = 90
DEFAULT_PATHS = 10_000
DEFAULT_SEED = 20260720
MIN_TRADING_DAYS = 4  # FTMO Phase-1 minimum trading days
SOURCE_RISK_PCT = 1.0  # RISK_FIXED=1000 on 100k source account


# --------------------------------------------------------------------------- sleeves

@dataclass(frozen=True)
class SleeveSpec:
    name: str
    ea_id: int
    label: str
    role: str
    stream_path: Path
    stream_basis: str  # "frozen_dxz24_20260717" | "common_files_current"
    asset_class: str   # dominant class for swap flagging: forex | index | basket_fx
    notes: str = ""


# Candidate sleeves for the 26.07 FTMO demo-book decision. 20004 (TOM GDAXI/NDX) is
# EXCLUDED: no Q02 evidence row exists in the consolidated metrics DB and its stream
# is an in-flight partial (26 trades, 2019-2022 span only, mtime 2026-07-20).
SLEEVES: dict[str, SleeveSpec] = {
    spec.name: spec
    for spec in (
        SleeveSpec(
            name="12969_USDJPY",
            ea_id=12969,
            label="usdjpy-gotobi (density motor)",
            role="density_motor",
            stream_path=FROZEN_STREAM_DIR / "12969_USDJPY_DWX.jsonl",
            stream_basis="frozen_dxz24_20260717",
            asset_class="forex",
            notes="Q09 PASS_PORTFOLIO. Overnight FX holder (~7.5h across Tokyo open).",
        ),
        SleeveSpec(
            name="13013_NDX",
            ea_id=13013,
            label="grimes-trendday-v2 NDX",
            role="slow",
            stream_path=COMMON_STREAM_DIR / "13013_NDX_DWX.jsonl",
            stream_basis="common_files_current",
            asset_class="index",
            notes="Q08+Q10 PASS. Mostly intraday (median hold 2h).",
        ),
        SleeveSpec(
            name="10815_GDAXI",
            ea_id=10815,
            label="10815 GDAXI chain",
            role="slow",
            stream_path=COMMON_STREAM_DIR / "10815_GDAXI_DWX.jsonl",
            stream_basis="common_files_current",
            asset_class="index",
            notes="Q09 PASS_PORTFOLIO. Stream schema lacks entry_time -> holding "
            "period unknown; nonzero tester swap on 13/66 trades implies some "
            "overnight index holds.",
        ),
        SleeveSpec(
            name="10815_EURUSD",
            ea_id=10815,
            label="10815 EURUSD chain",
            role="slow",
            stream_path=COMMON_STREAM_DIR / "10815_EURUSD_DWX.jsonl",
            stream_basis="common_files_current",
            asset_class="forex",
            notes="Q09 PASS_PORTFOLIO. Stream schema lacks entry_time.",
        ),
        SleeveSpec(
            name="13128_NDX",
            ea_id=13128,
            label="pre-fomc-drift NDX",
            role="slow",
            stream_path=FROZEN_STREAM_DIR / "13128_NDX_DWX.jsonl",
            stream_basis="frozen_dxz24_20260717",
            asset_class="index",
            notes="23h overnight NDX holder -> FTMO index swap exposure (flagged).",
        ),
        SleeveSpec(
            name="12474_GBPUSD",
            ea_id=12474,
            label="12474 GBPUSD",
            role="slow",
            stream_path=COMMON_STREAM_DIR / "12474_GBPUSD_DWX.jsonl",
            stream_basis="common_files_current",
            asset_class="forex",
            notes="Current stream (2026-07-19) carries 273 trades vs 442 in the "
            "metrics-DB Q05/Q08 rows from an earlier run; the current artifact is "
            "used as-is and the mismatch is documented.",
        ),
        SleeveSpec(
            name="10706_GBPUSD",
            ea_id=10706,
            label="10706 GBPUSD",
            role="slow",
            stream_path=FROZEN_STREAM_DIR / "10706_GBPUSD_DWX.jsonl",
            stream_basis="frozen_dxz24_20260717",
            asset_class="forex",
            notes="Q09 PASS_PORTFOLIO; DXZ live-book probation sleeve.",
        ),
        SleeveSpec(
            name="12778_BASKET",
            ea_id=12778,
            label="AUDUSD/EURJPY cointegration basket",
            role="slow",
            stream_path=FROZEN_STREAM_DIR / "12778_AUDUSD_DWX.jsonl",
            stream_basis="frozen_dxz24_20260717",
            asset_class="basket_fx",
            notes="Multi-day FX holder (median 69h, max 4145h in frozen stream); "
            "tester FX swap kept as proxy.",
        ),
    )
}

EXCLUSIONS = [
    {
        "candidate": "20004 TOM (GDAXI/NDX)",
        "reason": "pending Q02: no Q02 row in the consolidated ea_metrics table "
        "(D:/QM/strategy_farm/state/farm_state.sqlite, ea_metrics.py query "
        "2026-07-20) and the only "
        "stream artifact (Common/Files 20004_GDAXI_DWX.jsonl) is an in-flight "
        "partial: 26 trades, span 2019-02..2022-12, mtime 2026-07-20 18:51.",
    },
]


# --------------------------------------------------------------------------- costs

class FtmoCostModel:
    """FTMO commission from venue_cost_model.json (2026-07-19, single source)."""

    def __init__(self, model_path: Path = VENUE_COST_MODEL_PATH) -> None:
        self.model_path = model_path
        payload = json.loads(model_path.read_text(encoding="utf-8"))
        self.generated = payload.get("generated")
        self.class_model = payload["canonical_engine"]["class_model"]
        self.by_dwx: dict[str, dict[str, Any]] = {}
        for sym_name, spec in payload["symbols"].items():
            if not isinstance(spec, dict) or "alias_of" in spec:
                continue
            dwx = spec.get("dwx_symbol")
            if not dwx:
                continue
            self.by_dwx[str(dwx)] = {
                "symbol": sym_name,
                "asset_class": spec.get("asset_class"),
                "ftmo": spec.get("ftmo") or {},
            }
        self.fallback_symbols: set[str] = set()

    def commission_rt(self, symbol: str, volume: float, notional: float | None) -> float:
        """FTMO round-trip commission in USD for one closed trade (>= 0)."""
        spec = self.by_dwx.get(symbol)
        if spec is not None:
            ftmo = spec["ftmo"]
            model = str(ftmo.get("commission_model") or "")
            if model == "commission_free":
                return 0.0
            if model == "flat_per_lot_rt":
                return float(ftmo.get("commission_rt_per_lot_usd", 0.0)) * float(volume)
            if model.startswith("pct_notional"):
                if notional is None:
                    # degrade to indicative per-lot figure
                    per_lot = ftmo.get("commission_rt_per_lot_usd_indicative")
                    return float(per_lot or 0.0) * float(volume)
                return 0.00005 * float(notional)  # 0.005% RT
        # symbol not in the per-symbol table (e.g. EURJPY basket leg): forex class
        self.fallback_symbols.add(symbol)
        rates = self.class_model["forex"]
        return float(rates["flat_per_lot_rt"]) * float(volume)


# --------------------------------------------------------------------------- loading

@dataclass
class LoadedSleeve:
    spec: SleeveSpec
    sha256: str
    mtime_utc: str
    trades: list[dict[str, Any]] = field(default_factory=list)
    # derived
    day_bundles: dict[dt.date, float] = field(default_factory=dict)  # at 1% risk
    first_day: dt.date | None = None
    last_day: dt.date | None = None
    n_weekdays_span: int = 0
    p_active: float = 0.0
    total_net_ftmo_1pct: float = 0.0
    total_ftmo_commission: float = 0.0
    total_stream_swap: float = 0.0
    total_stream_commission_dropped: float = 0.0
    overnight_nights: int = 0
    lot_nights: float = 0.0
    missing_entry_time: int = 0


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _weekday_count(first: dt.date, last: dt.date) -> int:
    days = (last - first).days + 1
    return sum(
        1
        for offset in range(days)
        if (first + dt.timedelta(days=offset)).weekday() < 5
    )


def _nights_crossed(entry_ts: int, close_ts: int) -> int:
    entry_day = dt.datetime.utcfromtimestamp(entry_ts).date()
    close_day = dt.datetime.utcfromtimestamp(close_ts).date()
    return max(0, (close_day - entry_day).days)


def load_sleeve(spec: SleeveSpec, cost_model: FtmoCostModel) -> LoadedSleeve:
    path = spec.stream_path
    if not path.exists():
        raise FileNotFoundError(f"stream artifact missing for {spec.name}: {path}")
    loaded = LoadedSleeve(
        spec=spec,
        sha256=_sha256_file(path),
        mtime_utc=dt.datetime.fromtimestamp(path.stat().st_mtime, tz=dt.UTC)
        .replace(microsecond=0)
        .isoformat(),
    )
    with path.open("r", encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            if row.get("event") != "TRADE_CLOSED":
                continue
            profit = float(row["profit"])
            swap = float(row.get("swap", 0.0))
            stream_comm = float(row.get("commission", 0.0))
            volume = float(row["volume"])
            notional = row.get("notional")
            notional_val = None if notional is None else float(notional)
            symbol = str(row.get("symbol") or "")
            close_ts = int(row["time"])
            entry_ts = row.get("entry_time")
            entry_val = None if entry_ts is None else int(entry_ts)
            # integrity: stream net must equal profit + swap + commission
            net_declared = float(row["net"])
            if abs(net_declared - (profit + swap + stream_comm)) > 0.05:
                raise ValueError(
                    f"{path}:{line_no} net != profit+swap+commission "
                    f"({net_declared} vs {profit + swap + stream_comm})"
                )
            ftmo_comm = cost_model.commission_rt(symbol, volume, notional_val)
            net_ftmo = profit + swap - ftmo_comm
            loaded.trades.append(
                {
                    "close_ts": close_ts,
                    "entry_ts": entry_val,
                    "net_ftmo_1pct": net_ftmo,
                    "volume": volume,
                    "symbol": symbol,
                }
            )
            loaded.total_net_ftmo_1pct += net_ftmo
            loaded.total_ftmo_commission += ftmo_comm
            loaded.total_stream_swap += swap
            loaded.total_stream_commission_dropped += stream_comm
            if entry_val is None:
                loaded.missing_entry_time += 1
            else:
                nights = _nights_crossed(entry_val, close_ts)
                loaded.overnight_nights += nights
                loaded.lot_nights += nights * volume

    if not loaded.trades:
        raise ValueError(f"stream for {spec.name} contains no TRADE_CLOSED rows: {path}")

    for trade in loaded.trades:
        day = dt.datetime.utcfromtimestamp(trade["close_ts"]).date()
        loaded.day_bundles[day] = loaded.day_bundles.get(day, 0.0) + trade["net_ftmo_1pct"]
    days = sorted(loaded.day_bundles)
    loaded.first_day, loaded.last_day = days[0], days[-1]
    loaded.n_weekdays_span = _weekday_count(loaded.first_day, loaded.last_day)
    loaded.p_active = len(days) / max(1, loaded.n_weekdays_span)
    return loaded


# ----------------------------------------------------------------- compositions

def build_compositions(loaded: dict[str, LoadedSleeve]) -> dict[str, dict[str, float]]:
    all_names = list(loaded)
    inv_vol: dict[str, float] = {}
    for name, sleeve in loaded.items():
        bundle_values = list(sleeve.day_bundles.values())
        vol = statistics.pstdev(bundle_values) if len(bundle_values) > 1 else 0.0
        inv_vol[name] = 1.0 / vol if vol > 0 else 0.0
    # inverse-vol book: risk ~ 1/std(day bundle at 1%), cap 1.0/sleeve, total 4.0
    total_inv = sum(inv_vol.values())
    inv_risks = {name: 4.0 * value / total_inv for name, value in inv_vol.items()}
    # apply the 1.0 cap and redistribute the clipped mass proportionally (one pass
    # per clip round so the total stays ~4.0 without exceeding caps)
    for _ in range(len(inv_risks)):
        clipped = {n: min(r, 1.0) for n, r in inv_risks.items()}
        spare = 4.0 - sum(clipped.values())
        headroom = {n: 1.0 - clipped[n] for n in clipped if clipped[n] < 1.0}
        if spare <= 1e-9 or not headroom:
            inv_risks = clipped
            break
        weight_sum = sum(inv_vol[n] for n in headroom)
        inv_risks = dict(clipped)
        for n in headroom:
            inv_risks[n] = min(1.0, clipped[n] + spare * inv_vol[n] / weight_sum)
    return {
        "a_motor_solo_100": {"12969_USDJPY": 1.0},
        "a_motor_solo_050": {"12969_USDJPY": 0.5},
        "a_motor_solo_025": {"12969_USDJPY": 0.25},
        "b_motor_plus_2slow": {
            "12969_USDJPY": 1.0,
            "13013_NDX": 0.5,
            "12778_BASKET": 0.5,
        },
        "c_full_book_equal_050": {name: 0.5 for name in all_names},
        "d_full_book_invvol_total40": {
            name: round(risk, 4) for name, risk in inv_risks.items()
        },
        # decision probe: the fastest admissible tilt under the caps (1.0/sleeve,
        # ~5% book) - upweights the only high-carry sleeve (10706) plus the motor.
        "e_speed_tilt_total45": {
            "10706_GBPUSD": 1.0,
            "12969_USDJPY": 1.0,
            "10815_GDAXI": 0.5,
            "10815_EURUSD": 0.5,
            "13013_NDX": 0.5,
            "13128_NDX": 0.5,
            "12474_GBPUSD": 0.25,
            "12778_BASKET": 0.25,
        },
    }


# ----------------------------------------------------------------- MC simulation

def simulate_composition(
    comp_name: str,
    risks: dict[str, float],
    loaded: dict[str, LoadedSleeve],
    *,
    paths: int,
    horizon: int,
    capital: float,
    target_pct: float,
    daily_limit_pct: float,
    total_limit_pct: float,
    seed: int,
    comp_index: int,
) -> dict[str, Any]:
    rng = np.random.default_rng([seed, comp_index])
    target = capital * target_pct / 100.0
    daily_limit = capital * daily_limit_pct / 100.0
    total_limit = capital * total_limit_pct / 100.0

    pnl = np.zeros((paths, horizon), dtype=np.float64)
    active_any = np.zeros((paths, horizon), dtype=bool)
    for name, risk in sorted(risks.items()):
        sleeve = loaded[name]
        bundles = np.array(list(sleeve.day_bundles.values()), dtype=np.float64)
        active = rng.random((paths, horizon)) < sleeve.p_active
        draws = bundles[rng.integers(0, len(bundles), size=(paths, horizon))]
        pnl += np.where(active, draws * (risk / SOURCE_RISK_PCT), 0.0)
        active_any |= active

    cum = np.cumsum(pnl, axis=1)
    trading_days = np.cumsum(active_any, axis=1)

    sentinel = horizon + 1
    day_index = np.arange(1, horizon + 1)

    def first_hit(mask: np.ndarray) -> np.ndarray:
        hit = np.where(mask, day_index[None, :], sentinel)
        return hit.min(axis=1)

    fail_daily_day = first_hit(pnl <= -daily_limit)
    fail_total_day = first_hit(cum <= -total_limit)
    pass_day = first_hit((cum >= target) & (trading_days >= MIN_TRADING_DAYS))

    fail_day = np.minimum(fail_daily_day, fail_total_day)
    # breaches evaluated before the target on the same day (conservative)
    passed = pass_day < fail_day
    failed = fail_day <= np.minimum(pass_day, horizon)
    timeout = ~passed & ~failed
    fail_is_daily = failed & (fail_daily_day <= fail_total_day)
    fail_is_total = failed & ~fail_is_daily

    pass_days = pass_day[passed].astype(float)
    end_equity_timeout = cum[timeout, -1] if timeout.any() else np.array([])

    def pct(mask: np.ndarray) -> float:
        return round(float(mask.mean()) * 100.0, 2)

    def quartiles(values: np.ndarray) -> dict[str, float | None]:
        if values.size == 0:
            return {"p25": None, "p50": None, "p75": None, "mean": None}
        return {
            "p25": round(float(np.percentile(values, 25)), 1),
            "p50": round(float(np.percentile(values, 50)), 1),
            "p75": round(float(np.percentile(values, 75)), 1),
            "mean": round(float(values.mean()), 1),
        }

    return {
        "composition": comp_name,
        "risks_pct": dict(sorted(risks.items())),
        "total_risk_pct": round(sum(risks.values()), 4),
        "paths": paths,
        "horizon_trading_days": horizon,
        "pass_probability_pct": pct(passed),
        "fail_daily_dd_probability_pct": pct(fail_is_daily),
        "fail_total_dd_probability_pct": pct(fail_is_total),
        "timeout_probability_pct": pct(timeout),
        "days_to_pass": quartiles(pass_days),
        "timeout_end_pnl_usd": quartiles(end_equity_timeout)
        if end_equity_timeout.size
        else {"p25": None, "p50": None, "p75": None, "mean": None},
        "expected_90d_pnl_usd": round(float(cum[:, -1].mean()), 0),
        "concurrency": historical_concurrency(risks, loaded),
    }


# ------------------------------------------------- historical (calendar-faithful)

def historical_daily_series(
    risks: dict[str, float], loaded: dict[str, LoadedSleeve]
) -> tuple[list[dt.date], list[float], list[bool]]:
    """Real calendar-aligned combined weekday P&L (preserves cross-sleeve corr)."""
    first = min(loaded[n].first_day for n in risks)
    last = max(loaded[n].last_day for n in risks)
    dates: list[dt.date] = []
    cursor = first
    while cursor <= last:
        if cursor.weekday() < 5:
            dates.append(cursor)
        cursor += dt.timedelta(days=1)
    values: list[float] = []
    active: list[bool] = []
    for day in dates:
        total = 0.0
        any_active = False
        for name, risk in risks.items():
            bundle = loaded[name].day_bundles.get(day)
            if bundle is not None:
                total += bundle * (risk / SOURCE_RISK_PCT)
                any_active = True
        values.append(total)
        active.append(any_active)
    return dates, values, active


def historical_windows(
    risks: dict[str, float],
    loaded: dict[str, LoadedSleeve],
    *,
    horizon: int,
    capital: float,
    target_pct: float,
    daily_limit_pct: float,
    total_limit_pct: float,
    stride: int = 5,
) -> dict[str, Any]:
    _dates, values, active = historical_daily_series(risks, loaded)
    target = capital * target_pct / 100.0
    daily_limit = capital * daily_limit_pct / 100.0
    total_limit = capital * total_limit_pct / 100.0
    outcomes: dict[str, int] = {"pass": 0, "fail_daily": 0, "fail_total": 0, "timeout": 0}
    pass_days: list[int] = []
    n_windows = 0
    for start in range(0, len(values) - horizon + 1, stride):
        n_windows += 1
        cum = 0.0
        tdays = 0
        outcome = "timeout"
        for offset in range(horizon):
            day_pnl = values[start + offset]
            if active[start + offset]:
                tdays += 1
            cum += day_pnl
            if day_pnl <= -daily_limit:
                outcome = "fail_daily"
                break
            if cum <= -total_limit:
                outcome = "fail_total"
                break
            if cum >= target and tdays >= MIN_TRADING_DAYS:
                outcome = "pass"
                pass_days.append(offset + 1)
                break
        outcomes[outcome] += 1
    result: dict[str, Any] = {
        "n_windows": n_windows,
        "stride_trading_days": stride,
        "outcome_counts": outcomes,
    }
    if n_windows:
        result["pass_fraction_pct"] = round(outcomes["pass"] / n_windows * 100.0, 2)
        result["median_days_to_pass"] = (
            float(np.median(pass_days)) if pass_days else None
        )
    return result


# --------------------------------------------------------------- concurrency

def historical_concurrency(
    risks: dict[str, float], loaded: dict[str, LoadedSleeve]
) -> dict[str, Any]:
    """Risk-weighted co-open exposure per calendar day from entry/close intervals.

    Sleeves without entry_time (10815 streams) are counted as open on the close day
    only (documented approximation)."""
    day_risk: dict[dt.date, float] = {}
    day_count: dict[dt.date, int] = {}
    for name, risk in risks.items():
        sleeve = loaded[name]
        open_days: set[dt.date] = set()
        for trade in sleeve.trades:
            close_day = dt.datetime.utcfromtimestamp(trade["close_ts"]).date()
            if trade["entry_ts"] is None:
                span = [close_day]
            else:
                entry_day = dt.datetime.utcfromtimestamp(trade["entry_ts"]).date()
                span = [
                    entry_day + dt.timedelta(days=offset)
                    for offset in range((close_day - entry_day).days + 1)
                ]
            open_days.update(span)
        for day in open_days:
            day_risk[day] = day_risk.get(day, 0.0) + risk
            day_count[day] = day_count.get(day, 0) + 1
    if not day_risk:
        return {"max_concurrent_risk_pct": 0.0, "p95_concurrent_risk_pct": 0.0}
    values = sorted(day_risk.values())
    return {
        "max_concurrent_risk_pct": round(values[-1], 4),
        "p95_concurrent_risk_pct": round(
            float(np.percentile(np.array(values), 95)), 4
        ),
        "max_concurrent_sleeves": max(day_count.values()),
        "days_with_open_position": len(values),
        "note": "risk-weighted sum over sleeves with an open position that calendar "
        "day (historical alignment); sleeves without entry_time counted on close "
        "day only",
    }


# --------------------------------------------------------------------- reporting

def sleeve_report(loaded: dict[str, LoadedSleeve]) -> list[dict[str, Any]]:
    rows = []
    for name, sleeve in sorted(loaded.items()):
        years = max(1e-9, (sleeve.last_day - sleeve.first_day).days / 365.25)
        bundle_values = list(sleeve.day_bundles.values())
        breakeven_swap = None
        if sleeve.spec.asset_class == "index" and sleeve.lot_nights > 0:
            breakeven_swap = round(sleeve.total_net_ftmo_1pct / sleeve.lot_nights, 2)
        rows.append(
            {
                "sleeve": name,
                "ea_id": sleeve.spec.ea_id,
                "label": sleeve.spec.label,
                "role": sleeve.spec.role,
                "asset_class": sleeve.spec.asset_class,
                "stream_path": str(sleeve.spec.stream_path),
                "stream_basis": sleeve.spec.stream_basis,
                "sha256": sleeve.sha256,
                "mtime_utc": sleeve.mtime_utc,
                "trades": len(sleeve.trades),
                "span": f"{sleeve.first_day}..{sleeve.last_day}",
                "trades_per_year": round(len(sleeve.trades) / years, 1),
                "active_days": len(sleeve.day_bundles),
                "p_active_per_weekday": round(sleeve.p_active, 4),
                "total_net_ftmo_at_1pct_usd": round(sleeve.total_net_ftmo_1pct, 2),
                "annual_net_ftmo_at_1pct_usd": round(
                    sleeve.total_net_ftmo_1pct / years, 0
                ),
                "day_bundle_std_at_1pct_usd": round(
                    statistics.pstdev(bundle_values) if len(bundle_values) > 1 else 0.0,
                    2,
                ),
                "ftmo_commission_total_usd": round(sleeve.total_ftmo_commission, 2),
                "dxz_close_side_commission_dropped_usd": round(
                    sleeve.total_stream_commission_dropped, 2
                ),
                "stream_swap_kept_usd": round(sleeve.total_stream_swap, 2),
                "overnight_nights": sleeve.overnight_nights,
                "lot_nights": round(sleeve.lot_nights, 2),
                "breakeven_ftmo_index_swap_usd_per_lot_night": breakeven_swap,
                "missing_entry_time": sleeve.missing_entry_time,
                "notes": sleeve.spec.notes,
            }
        )
    return rows


def write_summary_md(
    out_dir: Path,
    args: argparse.Namespace,
    sleeves: list[dict[str, Any]],
    results: list[dict[str, Any]],
    cost_model: FtmoCostModel,
) -> Path:
    lines: list[str] = []
    add = lines.append
    add("# FTMO Phase-1 Monte-Carlo — candidate book compositions (2026-07-20)")
    add("")
    add(
        "**Label: backtest-derived, gross-of-slippage.** Per-trade net = tester "
        "profit (spread-inclusive .DWX real ticks) + tester swap (DXZ-derived proxy; "
        "FTMO swap is not published anywhere on disk) − FTMO commission injected from "
        f"`framework/registry/venue_cost_model.json` ({cost_model.generated}): forex "
        "$5/lot RT, indices $0, pct-notional otherwise. Floating intraday drawdown is "
        "not visible in closed-trade artifacts, so daily/total DD breach "
        "probabilities are lower bounds."
    )
    add("")
    add("## Assumptions")
    add("")
    add("| Assumption | Value |")
    add("|---|---|")
    add(f"| Account | ${args.capital:,.0f} FTMO Phase-1 |")
    add(f"| Pass target | +{args.target_pct}% (closed P&L, ≥{MIN_TRADING_DAYS} trading days) |")
    add(f"| Daily loss fail | closed day P&L ≤ −{args.daily_limit_pct}% of initial balance |")
    add(f"| Total loss fail | closed cumulative P&L ≤ −{args.total_limit_pct}% |")
    add(f"| Horizon | {args.horizon} trading days |")
    add(f"| Paths | {args.paths:,} (seed {args.seed}, per-composition substream) |")
    add(
        "| Risk scaling | source streams = RISK_FIXED $1000/trade on 100k (=1.0%); "
        "sleeve at r% multiplies P&L by r/1.0 |"
    )
    add(
        "| MC resampling | per-sleeve active-day bundles (intra-day clustering "
        "preserved), Bernoulli daily arrival at empirical rate, sleeves independent |"
    )
    add(
        "| Correlation anchor | historical rolling windows (real calendar alignment) "
        "reported per composition |"
    )
    add("| Day boundary | broker-time midnight (stream timestamps) |")
    if cost_model.fallback_symbols:
        add(
            f"| Commission fallback | {', '.join(sorted(cost_model.fallback_symbols))} "
            "not in venue model per-symbol table -> forex class flat $5/lot RT |"
        )
    add("")
    add("## Data provenance (per sleeve)")
    add("")
    add(
        "| Sleeve | Role | Trades | Span | tr/yr | Net@1% (USD) | /yr | Stream basis "
        "| SHA256 (12) |"
    )
    add("|---|---|---|---|---|---|---|---|---|")
    for row in sleeves:
        add(
            f"| {row['sleeve']} | {row['role']} | {row['trades']} | {row['span']} | "
            f"{row['trades_per_year']} | {row['total_net_ftmo_at_1pct_usd']:,.0f} | "
            f"{row['annual_net_ftmo_at_1pct_usd']:,.0f} | {row['stream_basis']} | "
            f"{row['sha256'][:12]} |"
        )
    add("")
    add("Full paths + full SHA256 in `results.json` (`sleeves` block).")
    add("")
    add("## Swap exposure flags (FTMO index swap not modelled — no real numbers exist)")
    add("")
    for row in sleeves:
        if row["breakeven_ftmo_index_swap_usd_per_lot_night"] is not None:
            add(
                f"- **{row['sleeve']}**: {row['overnight_nights']} overnight nights, "
                f"{row['lot_nights']} lot-nights; edge at 1% risk is wiped if FTMO "
                f"index swap ≥ ${row['breakeven_ftmo_index_swap_usd_per_lot_night']}"
                "/lot/night."
            )
        elif row["asset_class"] == "index" and row["missing_entry_time"]:
            add(
                f"- **{row['sleeve']}**: holding period unknown (stream lacks "
                "entry_time); nonzero tester swap on some trades implies overnight "
                "index holds — FTMO swap exposure unquantifiable from this artifact."
            )
    add("")
    add("## Results (compositions × Phase-1 outcome)")
    add("")
    add(
        "| Composition | Σrisk% | P(pass) | P(daily-DD) | P(total-DD) | P(timeout) | "
        "days-to-pass p25/p50/p75 | E[90d P&L] | max conc. risk% (hist) | hist. "
        "windows pass% |"
    )
    add("|---|---|---|---|---|---|---|---|---|---|")
    for res in results:
        dtp = res["days_to_pass"]
        dtp_str = (
            f"{dtp['p25']}/{dtp['p50']}/{dtp['p75']}" if dtp["p50"] is not None else "—"
        )
        hist = res.get("historical_windows", {})
        add(
            f"| {res['composition']} | {res['total_risk_pct']} | "
            f"{res['pass_probability_pct']}% | {res['fail_daily_dd_probability_pct']}% | "
            f"{res['fail_total_dd_probability_pct']}% | {res['timeout_probability_pct']}% | "
            f"{dtp_str} | ${res['expected_90d_pnl_usd']:,.0f} | "
            f"{res['concurrency'].get('max_concurrent_risk_pct', 0)} | "
            f"{hist.get('pass_fraction_pct', '—')}% |"
        )
    add("")
    add("## Exclusions")
    add("")
    for excl in EXCLUSIONS:
        add(f"- **{excl['candidate']}** — {excl['reason']}")
    add("")
    add("## Composition definitions")
    add("")
    for res in results:
        add(f"- `{res['composition']}`: " + ", ".join(
            f"{k}@{v}" for k, v in res["risks_pct"].items()
        ))
    add("")
    out = out_dir / "summary.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


# --------------------------------------------------------------------------- main

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="FTMO Phase-1 Monte-Carlo over factory Q08 trade streams."
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(r"D:\QM\reports\portfolio\ftmo_p1_mc_20260720"),
    )
    parser.add_argument("--paths", type=int, default=DEFAULT_PATHS)
    parser.add_argument("--horizon", type=int, default=DEFAULT_HORIZON_TRADING_DAYS)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--capital", type=float, default=DEFAULT_CAPITAL)
    parser.add_argument("--target-pct", type=float, default=DEFAULT_TARGET_PCT)
    parser.add_argument("--daily-limit-pct", type=float, default=DEFAULT_DAILY_LIMIT_PCT)
    parser.add_argument("--total-limit-pct", type=float, default=DEFAULT_TOTAL_LIMIT_PCT)
    parser.add_argument(
        "--compositions",
        default=None,
        help="Comma-separated composition names to run (default: all).",
    )
    parser.add_argument("--list", action="store_true", help="List sleeves/compositions.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    cost_model = FtmoCostModel()
    loaded = {name: load_sleeve(spec, cost_model) for name, spec in SLEEVES.items()}
    compositions = build_compositions(loaded)

    if args.list:
        for name in loaded:
            print("sleeve:", name)
        for name, risks in compositions.items():
            print("composition:", name, risks)
        return 0

    selected = compositions
    if args.compositions:
        wanted = [token.strip() for token in args.compositions.split(",") if token.strip()]
        unknown = [w for w in wanted if w not in compositions]
        if unknown:
            raise SystemExit(f"unknown composition(s): {unknown}")
        selected = {name: compositions[name] for name in wanted}

    results: list[dict[str, Any]] = []
    for comp_index, (comp_name, risks) in enumerate(selected.items()):
        for sleeve_name, risk in risks.items():
            if risk > 1.0 + 1e-9:
                raise SystemExit(
                    f"{comp_name}: sleeve {sleeve_name} risk {risk} exceeds 1.0 cap"
                )
        if sum(risks.values()) > 5.0 + 1e-9:
            raise SystemExit(f"{comp_name}: total risk {sum(risks.values())} exceeds 5.0")
        result = simulate_composition(
            comp_name,
            risks,
            loaded,
            paths=args.paths,
            horizon=args.horizon,
            capital=args.capital,
            target_pct=args.target_pct,
            daily_limit_pct=args.daily_limit_pct,
            total_limit_pct=args.total_limit_pct,
            seed=args.seed,
            comp_index=comp_index,
        )
        result["historical_windows"] = historical_windows(
            risks,
            loaded,
            horizon=args.horizon,
            capital=args.capital,
            target_pct=args.target_pct,
            daily_limit_pct=args.daily_limit_pct,
            total_limit_pct=args.total_limit_pct,
        )
        results.append(result)
        print(
            f"{comp_name}: pass={result['pass_probability_pct']}% "
            f"p50_days={result['days_to_pass']['p50']} "
            f"dailyDD={result['fail_daily_dd_probability_pct']}% "
            f"totalDD={result['fail_total_dd_probability_pct']}% "
            f"hist_pass={result['historical_windows'].get('pass_fraction_pct')}%"
        )

    sleeves = sleeve_report(loaded)
    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    artifact = {
        "artifact": "ftmo_p1_mc",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "label": "backtest-derived, gross-of-slippage",
        "cost_basis": {
            "venue_cost_model": str(VENUE_COST_MODEL_PATH),
            "venue_cost_model_generated": cost_model.generated,
            "commission": "FTMO injected (forex $5/lot RT flat, index $0, "
            "pct-notional metals/energy); DXZ close-side tester commission dropped",
            "swap": "stream tester swap kept as DXZ-derived proxy; FTMO swap "
            "unpublished (venue model open axis) - index overnight sleeves flagged "
            "with breakeven swap",
            "spread": "embedded in .DWX real-tick history (no double count)",
            "slippage": "not modelled",
            "commission_fallback_symbols": sorted(cost_model.fallback_symbols),
        },
        "parameters": {
            "capital": args.capital,
            "target_pct": args.target_pct,
            "daily_limit_pct": args.daily_limit_pct,
            "total_limit_pct": args.total_limit_pct,
            "horizon_trading_days": args.horizon,
            "paths": args.paths,
            "seed": args.seed,
            "min_trading_days": MIN_TRADING_DAYS,
            "source_risk_pct": SOURCE_RISK_PCT,
        },
        "sleeves": sleeves,
        "exclusions": EXCLUSIONS,
        "compositions": {name: risks for name, risks in selected.items()},
        "results": results,
    }
    results_path = out_dir / "results.json"
    results_path.write_text(
        json.dumps(artifact, indent=2, sort_keys=False) + "\n", encoding="utf-8"
    )
    summary_path = write_summary_md(out_dir, args, sleeves, results, cost_model)
    print(f"wrote {results_path}")
    print(f"wrote {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
