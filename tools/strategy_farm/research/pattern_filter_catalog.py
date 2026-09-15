"""Pattern & Filter Catalog — the §22 / §40 / §44 filter-universe projector.

Deterministic, read-only generator (schema ``qm.pattern-filter-catalog/v1``). It
makes the whole pattern / filter universe visible as company knowledge and feeds
Q12 (as candidate filters, never changing the sealed selection contract) and
autonomous research (a ``search_history_ledger`` hypothesis family).

What it inventories:

* Every ``QM_PatternId`` predicate compiled into the framework pattern-permission
  gate (``framework/include/QM/QM_PatternPermission.mqh``) — id, name, category
  (§40: price-action / trend / volatility / news / session / regime / time),
  finer subfamily, provenance and Andrea-Unger relation.
* Every first-class filter module in the QM filter library
  (``QM_FilterLibrary.mqh`` umbrella + news/regime/volatility + the news gate and
  the straddle integration) — name, file, parameters, category, provenance.

What it joins (historical test results, §40):

* The DL-089 / Q12 walk-forward census MEASURED cells from the farm DB
  (``ea_metrics`` joined to the ``OPT_CENSUS`` ``work_items`` payload). For every
  predicate arm the DESCRIPTIVE effect vs its same-(program, year) no-filter
  baseline is aggregated: trade reduction, per-trade expectancy delta, drawdown
  delta, and a return-to-maxdd relative-improvement census (>= +5% cell count).
  The null / no-filter baseline is the ``baseline`` arm, carried explicitly.
* The SEALED per-program Q12 selection receipts
  (``q12_selection_receipt.json``) — the authoritative ``final_selection`` and
  ``verdict`` (e.g. ``NO_FILTER_CHANGE``). Times a predicate was actually selected
  buy/sell across programs is tallied from these receipts, never re-derived.

Hard invariants:

* Never mutates the DB (URI ``mode=ro`` + ``PRAGMA query_only``); pure reads.
* The DESCRIPTIVE census aggregate is an observational catalog field, NOT a gate
  verdict. Q12's DL-089 selection contract (ROT) is the only authority for which
  filters an EA runs; this module reports its sealed receipts and never re-runs,
  re-weights or challenges the sealed rule.
* An underivable value is an explicit token (``EVIDENCE_MISSING`` / ``UNKNOWN``),
  never a guess or a zero standing in for missing data.
* Deterministic + idempotent: with ``now`` fixed and the same inputs the emitted
  JSON is byte-identical; ``inputs_sha256`` fingerprints the real inputs.

CLI::

    python pattern_filter_catalog.py \
        --db D:/QM/strategy_farm/state/farm_state.sqlite \
        --census-artifacts D:/QM/strategy_farm/artifacts/opt_census \
        --mqh framework/include/QM/QM_PatternPermission.mqh \
        --out D:/QM/reports/state/pattern_filter_catalog.json \
        --doc docs/research/PATTERN_FILTER_CATALOG.md \
        --vault "G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Pattern & Filter Catalog.md"
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

CATALOG_SCHEMA = "qm.pattern-filter-catalog/v1"

# --- canonical inputs --------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_MQH = REPO_ROOT / "framework" / "include" / "QM" / "QM_PatternPermission.mqh"
DEFAULT_COMMON_MQH = REPO_ROOT / "framework" / "include" / "QM" / "QM_Common.mqh"
DEFAULT_DB = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_CENSUS_ARTIFACTS = Path(r"D:/QM/strategy_farm/artifacts/opt_census")
DEFAULT_OUT = Path(r"D:/QM/reports/state/pattern_filter_catalog.json")
DEFAULT_DOC = REPO_ROOT / "docs" / "research" / "PATTERN_FILTER_CATALOG.md"
DEFAULT_VAULT = Path(
    r"G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Pattern & Filter Catalog.md"
)

# Relative-improvement threshold of the SEALED DL-089 success measure
# (return_to_maxdd, each cell vs same-year baseline). Reproduced here only to
# label the DESCRIPTIVE census; the sealed selection is read from receipts.
DL089_REL_IMPROVEMENT = 0.05

# The operative "max N filters" rule (§22 disposition): up to 3 per direction.
PATTERN_FILTER_CAP_PER_DIRECTION = 3

# §40 category taxonomy. Every implemented predicate id maps to exactly one
# category and one finer subfamily. A new enum member without an entry lands in
# UNCLASSIFIED and test_pattern_filter_catalog.py fails, forcing maintenance.
_PA = "price-action"
_TR = "trend"
_VO = "volatility"
_RG = "regime"
_TI = "time"

# id -> (category, subfamily)
CATEGORY_MAP: dict[int, tuple[str, str]] = {
    # single-bar shape (indecision / rejection / conviction candles)
    3: (_PA, "single-bar-indecision"),
    4: (_PA, "single-bar-indecision"),
    5: (_PA, "single-bar-indecision"),
    6: (_PA, "single-bar-reversal"),
    7: (_PA, "single-bar-reversal"),
    8: (_PA, "single-bar-reversal"),
    9: (_PA, "single-bar-reversal"),
    10: (_PA, "single-bar-reversal"),
    11: (_PA, "single-bar-reversal"),
    12: (_PA, "single-bar-wick"),
    13: (_PA, "single-bar-wick"),
    14: (_PA, "single-bar-conviction"),
    15: (_PA, "single-bar-conviction"),
    16: (_PA, "single-bar-conviction"),
    17: (_PA, "single-bar-conviction"),
    18: (_PA, "single-bar-indecision"),
    # two/three-bar reversal
    19: (_PA, "multi-bar-reversal"),
    20: (_PA, "multi-bar-reversal"),
    21: (_PA, "multi-bar-reversal"),
    22: (_PA, "multi-bar-reversal"),
    23: (_PA, "multi-bar-reversal"),
    24: (_PA, "multi-bar-reversal"),
    25: (_PA, "multi-bar-reversal"),
    26: (_PA, "multi-bar-reversal"),
    27: (_PA, "multi-bar-reversal"),
    28: (_PA, "multi-bar-reversal"),
    29: (_PA, "multi-bar-reversal"),
    30: (_PA, "multi-bar-reversal"),
    31: (_PA, "multi-bar-reversal"),
    32: (_PA, "multi-bar-reversal"),
    33: (_PA, "multi-bar-reversal"),
    34: (_PA, "multi-bar-reversal"),
    # continuation
    35: (_TR, "continuation"),
    36: (_TR, "continuation"),
    37: (_TR, "continuation"),
    38: (_TR, "continuation"),
    # consolidation / squeeze
    39: (_PA, "consolidation"),
    40: (_PA, "consolidation"),
    41: (_PA, "consolidation"),
    42: (_VO, "narrow-range"),
    43: (_VO, "narrow-range"),
    44: (_VO, "wide-range"),
    # gaps
    45: (_PA, "gap"),
    46: (_PA, "gap"),
    47: (_PA, "gap"),
    48: (_PA, "gap"),
    49: (_PA, "gap"),
    50: (_PA, "gap"),
    # structure / momentum
    51: (_TR, "structure"),
    52: (_TR, "structure"),
    53: (_TR, "structure"),
    54: (_TR, "structure"),
    55: (_TR, "structure"),
    56: (_TR, "structure"),
    # volatility state
    57: (_VO, "vol-state"),
    58: (_VO, "vol-state"),
    59: (_VO, "vol-state"),
    60: (_VO, "vol-state"),
    # regime (deterministic bar-count trend strength; source-tagged "HMM" but
    # reclassified/renamed per OWNER 2026-08-13 as deterministic bar counting)
    77: (_RG, "trend-strength"),
    78: (_RG, "trend-strength"),
    79: (_RG, "trend-strength"),
    80: (_RG, "trend-strength"),
    81: (_RG, "trend-strength"),
    82: (_RG, "vol-regime"),
    83: (_RG, "transition"),
    84: (_RG, "exhaustion"),
    # statistical (closed-form, no fitting)
    87: (_RG, "statistical-mean-reversion"),
    88: (_RG, "statistical-zscore"),
    89: (_RG, "statistical-zscore"),
    90: (_VO, "vol-percentile"),
    91: (_VO, "vol-percentile"),
    92: (_PA, "fractal-breakout"),
    93: (_TR, "efficiency-ratio"),
    94: (_TR, "efficiency-ratio"),
    # tick-volume proxy (DWX tick COUNT, not traded volume)
    98: (_VO, "volume-climax"),
    # calendar (derived from reference bar open time in UTC)
    99: (_TI, "calendar"),
    100: (_TI, "calendar"),
}

# Predicates with a documented Andrea-Unger relation. Unger's disclosed corpus
# (docs/research/LIBRARY_MINING_unger-forex-strategies_2026-06.md,
# CODEX_UNGER_REFERENCE_PORTABILITY_2026-08-12.md) names three neutral-pattern
# families explicitly — indecision / "daily factor" candles, inside/outside
# bars, and gaps — plus Crabel-style volatility (NR4/NR7, wide-range). The
# per-year walk-forward CONSISTENCY selection method (DL-089) is itself
# Unger-methodology and is documented at programme level, not per predicate.
UNGER_RELATED_IDS: frozenset[int] = frozenset(
    {
        3, 4, 5, 18,          # indecision / daily-factor candles
        39, 40, 41,           # inside / double-inside / outside bar (neutral)
        42, 43, 44,           # NR4 / NR7 / wide-range (Crabel volatility)
        45, 46, 47, 48, 49, 50,  # gaps (neutral pattern family)
    }
)


def _provenance_for(category: str, subfamily: str, unger: bool) -> str:
    """Deterministic provenance string for a predicate."""
    if unger:
        return "unger-corpus + classic-price-action (source-traceable enum id)"
    if category == _PA:
        return "classic-candlestick / price-action reference (source-traceable enum id)"
    if category == _TR:
        return "price-structure / momentum reference (source-traceable enum id)"
    if category == _VO:
        return "volatility reference (ATR / range; source-traceable enum id)"
    if category == _RG:
        return "deterministic regime / closed-form statistic (source-traceable enum id)"
    if category == _TI:
        return "deterministic calendar predicate (reference bar UTC open time)"
    return "UNKNOWN"


# First-class filter modules (the QM_FilterLibrary umbrella + the news gate and
# the straddle integration). Hand-declared from the .mqh sources; the parameter
# lists mirror the module signatures. Kept explicit (not parsed) because these
# are structural facts pinned by the test, and the modules are few and stable.
FILTER_MODULE_INVENTORY: list[dict[str, Any]] = [
    {
        "name": "QM_FilterNewsBlackout",
        "file": "framework/include/QM/QM_FilterNewsBlackout.mqh",
        "category": "news",
        "parameters": ["mode (QM_NewsMode)"],
        "provenance": "first-class wrapper over central QM_NewsFilter",
        "mechanical": True,
        "note": "Pre-entry high-impact-news blackout gate; single source of truth "
        "for calendar parsing stays in QM_NewsFilter.",
    },
    {
        "name": "QM_FilterRegime",
        "file": "framework/include/QM/QM_FilterRegime.mqh",
        "category": "regime",
        "parameters": ["lookback_bars", "bull_return_pct", "bear_return_pct", "allow_sideways", "shift"],
        "provenance": "rule-based N-bar closed-price return; explicitly NOT an ML regime detector",
        "mechanical": True,
        "note": "bull / bear / sideways from a deterministic return threshold.",
    },
    {
        "name": "QM_FilterVolatility",
        "file": "framework/include/QM/QM_FilterVolatility.mqh",
        "category": "volatility",
        "parameters": ["atr_period", "lookback_bars", "compression_ratio", "expansion_ratio", "shift"],
        "provenance": "current ATR vs own recent ATR baseline; three parameters",
        "mechanical": True,
        "note": "compression / normal / expansion state.",
    },
    {
        "name": "QM_NewsFilter",
        "file": "framework/include/QM/QM_NewsFilter.mqh",
        "category": "news",
        "parameters": ["symbol", "broker_time", "mode (QM_NewsMode)"],
        "provenance": "central firm-specific blackout rules + calendar parsing (single source of truth)",
        "mechanical": True,
        "note": "Backtest uses factory news archive; ENV=live uses its own live "
        "calendar and fails closed (HR: live never reads the backtest archive).",
    },
    {
        "name": "QM_PatternPermission",
        "file": "framework/include/QM/QM_PatternPermission.mqh",
        "category": "price-action",
        "parameters": ["opt_pp_buy1..3", "opt_pp_sell1..3 (QM_PatternId enum ids)"],
        "provenance": "closed-bar, fail-closed directional permission gate (plan v2 / DL-089)",
        "mechanical": True,
        "note": "The meta-module that hosts the 77 QM_PatternId predicates; up to "
        f"{PATTERN_FILTER_CAP_PER_DIRECTION} per direction via the six opt_pp inputs.",
    },
    {
        "name": "QM_PatternPermissionStraddle",
        "file": "framework/include/QM/QM_PatternPermissionStraddle.mqh",
        "category": "price-action",
        "parameters": ["QM_StraddlePlan", "QM_PermissionResult"],
        "provenance": "A1/A2 integration for dual-pending (straddle) Balke sleeves",
        "mechanical": True,
        "note": "Applies pattern permission side-effect-free before either leg is "
        "placed; withdraws a resting pending whose direction is later forbidden.",
    },
]


# --- helpers -----------------------------------------------------------------
def _utc_now_iso(now: dt.datetime | None = None) -> str:
    stamp = now or dt.datetime.now(dt.UTC)
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=dt.UTC)
    return stamp.astimezone(dt.UTC).replace(microsecond=0).isoformat()


def _sha256_bytes(*chunks: bytes) -> str:
    digest = hashlib.sha256()
    for chunk in chunks:
        digest.update(chunk)
    return digest.hexdigest()


def _humanize(name: str) -> str:
    """QM_PP_DRAGONFLY_DOJI -> 'Dragonfly Doji'."""
    core = name.removeprefix("QM_PP_")
    return " ".join(w.capitalize() for w in core.split("_"))


def parse_pattern_predicates(mqh_text: str) -> list[dict[str, Any]]:
    """Parse the QM_PatternId enum into categorized predicate rows.

    Deterministic: sorted by id. QM_PP_NONE (id 0) is excluded — it is the no-op
    sentinel, not a predicate. Every implemented id is expected in CATEGORY_MAP;
    an unmapped id is emitted with category ``UNCLASSIFIED`` so the pinning test
    catches it.
    """
    match = re.search(r"enum\s+QM_PatternId\s*\{(.*?)\};", mqh_text, re.S)
    if not match:
        raise ValueError("QM_PatternId enum not found in mqh text")
    body = match.group(1)
    pairs = re.findall(r"(QM_PP_[A-Z0-9_]+)\s*=\s*(\d+)", body)
    predicates: list[dict[str, Any]] = []
    for name, id_str in pairs:
        pid = int(id_str)
        if pid == 0:  # QM_PP_NONE sentinel
            continue
        category, subfamily = CATEGORY_MAP.get(pid, ("UNCLASSIFIED", "UNCLASSIFIED"))
        unger = pid in UNGER_RELATED_IDS
        predicates.append(
            {
                "predicate_id": pid,
                "enum_name": name,
                "display_name": _humanize(name),
                "category": category,
                "subfamily": subfamily,
                "unger_related": unger,
                "provenance": _provenance_for(category, subfamily, unger),
                "mechanical": True,
            }
        )
    predicates.sort(key=lambda r: r["predicate_id"])
    return predicates


def _connect_ro(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")
    return conn


def _safe_ratio(num: float, den: float) -> float | None:
    if den is None or abs(den) < 1e-12:
        return None
    return num / den


def load_census_join(conn: sqlite3.Connection) -> dict[str, Any]:
    """DESCRIPTIVE per-predicate aggregate over the DL-089 / Q12 census.

    Reads MEASURED OPT_CENSUS cells (``work_items`` payload joined to
    ``ea_metrics``), pairs every predicate arm to its same-(program, year)
    no-filter baseline, and aggregates the observed effect. This is catalog
    description, never a verdict.
    """
    try:
        rows = conn.execute(
            """
            SELECT json_extract(w.payload_json,'$.program_id')   AS program_id,
                   json_extract(w.payload_json,'$.year')         AS year,
                   json_extract(w.payload_json,'$.arm')          AS arm,
                   json_extract(w.payload_json,'$.direction')    AS direction,
                   json_extract(w.payload_json,'$.predicate_id') AS predicate_id,
                   m.net_profit, m.trades, m.drawdown_money
            FROM work_items w
            JOIN ea_metrics m ON m.work_item_id = w.id
            WHERE w.phase = 'OPT_CENSUS'
              AND w.status = 'done'
              AND m.verdict = 'MEASURED'
            """
        ).fetchall()
    except sqlite3.OperationalError:
        return {"status": "EVIDENCE_MISSING", "reason": "OPT_CENSUS/ea_metrics not queryable"}

    if not rows:
        return {"status": "EVIDENCE_MISSING", "reason": "no MEASURED OPT_CENSUS cells"}

    # Index baselines per (program, year); predicate arms per (program, year).
    baselines: dict[tuple[str, int], dict[str, float]] = {}
    arms: list[dict[str, Any]] = []
    programs: set[str] = set()
    for program_id, year, arm, direction, predicate_id, net, trades, dd in rows:
        if program_id is None or year is None:
            continue
        try:
            year_i = int(year)
        except (TypeError, ValueError):
            continue
        programs.add(str(program_id))
        rec = {
            "program_id": str(program_id),
            "year": year_i,
            "net_profit": float(net) if net is not None else None,
            "trades": int(trades) if trades is not None else None,
            "drawdown_money": float(dd) if dd is not None else None,
        }
        if arm == "baseline" or (predicate_id in (None, 0)):
            baselines[(rec["program_id"], year_i)] = rec
        else:
            rec["predicate_id"] = int(predicate_id)
            rec["direction"] = direction
            arms.append(rec)

    per_pred: dict[int, dict[str, Any]] = defaultdict(
        lambda: {
            "measured_cells": 0,
            "cells_with_baseline": 0,
            "improved_cells": 0,
            "no_change_or_worse_cells": 0,
            "trade_reduction_pct_sum": 0.0,
            "trade_reduction_pct_n": 0,
            "expectancy_delta_sum": 0.0,
            "expectancy_delta_n": 0,
            "dd_delta_pct_sum": 0.0,
            "dd_delta_pct_n": 0,
            "programs": set(),
        }
    )

    for rec in arms:
        pid = rec["predicate_id"]
        agg = per_pred[pid]
        agg["measured_cells"] += 1
        agg["programs"].add(rec["program_id"])
        base = baselines.get((rec["program_id"], rec["year"]))
        if not base:
            continue
        agg["cells_with_baseline"] += 1

        # trade reduction (%) vs baseline trades
        if rec["trades"] is not None and base["trades"]:
            red = _safe_ratio(base["trades"] - rec["trades"], base["trades"])
            if red is not None:
                agg["trade_reduction_pct_sum"] += red * 100.0
                agg["trade_reduction_pct_n"] += 1

        # per-trade expectancy delta
        arm_exp = _safe_ratio(rec["net_profit"], rec["trades"]) if rec["trades"] else None
        base_exp = _safe_ratio(base["net_profit"], base["trades"]) if base["trades"] else None
        if arm_exp is not None and base_exp is not None:
            agg["expectancy_delta_sum"] += arm_exp - base_exp
            agg["expectancy_delta_n"] += 1

        # drawdown delta (%) vs baseline dd
        if rec["drawdown_money"] is not None and base["drawdown_money"]:
            dd_rel = _safe_ratio(
                rec["drawdown_money"] - base["drawdown_money"], base["drawdown_money"]
            )
            if dd_rel is not None:
                agg["dd_delta_pct_sum"] += dd_rel * 100.0
                agg["dd_delta_pct_n"] += 1

        # return-to-maxdd relative improvement (the sealed success measure; here
        # DESCRIPTIVE only)
        arm_rtmdd = _safe_ratio(rec["net_profit"], rec["drawdown_money"])
        base_rtmdd = _safe_ratio(base["net_profit"], base["drawdown_money"])
        if arm_rtmdd is not None and base_rtmdd is not None and abs(base_rtmdd) > 1e-12:
            rel = (arm_rtmdd - base_rtmdd) / abs(base_rtmdd)
            if rel >= DL089_REL_IMPROVEMENT:
                agg["improved_cells"] += 1
            else:
                agg["no_change_or_worse_cells"] += 1

    def _mean(total: float, n: int) -> float | None:
        return round(total / n, 4) if n else None

    predicate_rows: dict[str, Any] = {}
    for pid, agg in per_pred.items():
        predicate_rows[str(pid)] = {
            "measured_cells": agg["measured_cells"],
            "cells_with_baseline": agg["cells_with_baseline"],
            "programs_covered": len(agg["programs"]),
            "improved_cells_ge_5pct_rtmdd": agg["improved_cells"],
            "no_change_or_worse_cells": agg["no_change_or_worse_cells"],
            "mean_trade_reduction_pct": _mean(
                agg["trade_reduction_pct_sum"], agg["trade_reduction_pct_n"]
            ),
            "mean_expectancy_delta": _mean(
                agg["expectancy_delta_sum"], agg["expectancy_delta_n"]
            ),
            "mean_drawdown_delta_pct": _mean(agg["dd_delta_pct_sum"], agg["dd_delta_pct_n"]),
        }

    return {
        "status": "OK",
        "measure": "DESCRIPTIVE (observational catalog; NOT a Q12 verdict)",
        "success_measure": "return_to_maxdd relative improvement vs same-(program,year) baseline",
        "improvement_threshold": DL089_REL_IMPROVEMENT,
        "measured_cells_total": len(arms),
        "baseline_cells_total": len(baselines),
        "programs_covered": len(programs),
        "per_predicate": predicate_rows,
    }


def load_selection_receipts(artifacts_dir: Path) -> dict[str, Any]:
    """Read the SEALED per-program Q12 selection receipts (authoritative).

    Tallies, per predicate id, how many programs selected it buy / sell (from the
    receipts' ``final_selection``), and the program-level verdict distribution.
    Deterministic: programs iterated in sorted directory order.
    """
    if not artifacts_dir.exists():
        return {"status": "EVIDENCE_MISSING", "reason": f"{artifacts_dir} not present"}

    receipts = sorted(artifacts_dir.glob("DL089_*/q12_selection_receipt.json"))
    if not receipts:
        return {"status": "EVIDENCE_MISSING", "reason": "no q12_selection_receipt.json found"}

    verdict_counts: dict[str, int] = defaultdict(int)
    selected_buy: dict[int, int] = defaultdict(int)
    selected_sell: dict[int, int] = defaultdict(int)
    programs: list[dict[str, Any]] = []

    def _to_ids(items: Iterable[Any]) -> list[int]:
        out: list[int] = []
        for it in items or []:
            try:
                out.append(int(it))
            except (TypeError, ValueError):
                continue
        return out

    for path in receipts:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            verdict_counts["UNREADABLE"] += 1
            continue
        verdict = str(data.get("verdict") or "UNKNOWN")
        verdict_counts[verdict] += 1
        sel = data.get("final_selection") or {}
        buy_ids = _to_ids(sel.get("BUY", []))
        sell_ids = _to_ids(sel.get("SELL", []))
        for pid in buy_ids:
            selected_buy[pid] += 1
        for pid in sell_ids:
            selected_sell[pid] += 1
        programs.append(
            {
                "program_id": path.parent.name,
                "verdict": verdict,
                "final_selection_buy": sorted(buy_ids),
                "final_selection_sell": sorted(sell_ids),
                "receipt_sha256": _sha256_bytes(path.read_bytes()),
            }
        )

    per_pred: dict[str, Any] = {}
    for pid in sorted(set(selected_buy) | set(selected_sell)):
        per_pred[str(pid)] = {
            "times_selected_buy": selected_buy.get(pid, 0),
            "times_selected_sell": selected_sell.get(pid, 0),
        }

    return {
        "status": "OK",
        "authority": "SEALED DL-089 Q12 selection receipts (ROT contract; not re-derived)",
        "programs_evaluated": len(programs),
        "verdict_distribution": dict(sorted(verdict_counts.items())),
        "per_predicate_selected": per_pred,
        "programs": sorted(programs, key=lambda p: p["program_id"]),
    }


def _ablation_programme() -> dict[str, Any]:
    """The fresh §22 ablation programme design (candidate for Q12, not a change)."""
    return {
        "overlay_design": {
            "base": "the Q10/Q11-surviving mechanical strategy, no filter (null control)",
            "single_overlays": "base + exactly one predicate/filter per direction",
            "justified_combinations": (
                "only orthogonal pairs with a predeclared causal thesis "
                "(e.g. a trend filter x a volatility filter), never an exhaustive "
                "power-set; combinations must be pre-registered before measurement"
            ),
            "cap": f"<= {PATTERN_FILTER_CAP_PER_DIRECTION} filters per direction "
            "(OR / blacklist semantics, DL-089)",
        },
        "null_baseline": "the no-filter arm is always present and is the control every "
        "overlay is measured against (same program, same year).",
        "measurements": [
            "trade count / trade reduction",
            "per-trade expectancy and expectancy delta vs base",
            "max drawdown and drawdown delta vs base",
            "return_to_maxdd (the sealed DL-089 success measure)",
            "regime-conditional effect (trend / range / high-vol buckets)",
            "portfolio marginal effect (correlation & tail contribution to the book)",
        ],
        "multiple_testing_control": {
            "pre_registered_families": "filter families (price-action / trend / "
            "volatility / news / session / regime / time) declared before search",
            "fdr": "Benjamini-Hochberg FDR applied WITHIN each pre-registered family",
            "holdout": "anchored walk-forward, >= 3-year minimum window, test years "
            "held out from selection (DL-089 §4); one holdout reuse down-weights",
            "trial_deflation": "declared_trial_count feeds the Q16 DSR/PBO deflation "
            "(154 pattern search space + numeric trials), NEVER silently",
        },
        "regime_and_portfolio_effects": (
            "each overlay is scored inside deterministic regime buckets and by its "
            "marginal contribution to book return_to_maxdd and tail risk, so a filter "
            "that helps standalone but adds correlated tail is rejected at portfolio level"
        ),
        "how_it_feeds_q12": (
            "this catalog supplies CANDIDATE filters and their historical descriptive "
            "effect to Q12; it does NOT change Q12's DL-089 selection contract. Q12 "
            "remains the sole authority that decides, per (EA, symbol), which filters "
            "an EA runs, under the sealed >=2/3-year >=+5% return_to_maxdd rule."
        ),
        "how_it_feeds_autonomous_research": (
            "each predeclared filter family is a search_history_ledger "
            "hypothesis_family (e.g. 'pattern_filter.volatility'); every DISCOVER "
            "search is logged BEFORE it runs so attempts are counted against the "
            "winner-only report pattern and declared_trial_count is auditable."
        ),
        "search_history_families": sorted(
            {
                "pattern_filter.price-action",
                "pattern_filter.trend",
                "pattern_filter.volatility",
                "pattern_filter.news",
                "pattern_filter.session",
                "pattern_filter.regime",
                "pattern_filter.time",
            }
        ),
    }


def _max_n_disposition(selection: dict[str, Any]) -> dict[str, Any]:
    """§22 disposition of the 'max N filters' rule (classify per §20 of master)."""
    return {
        "rule": f"up to {PATTERN_FILTER_CAP_PER_DIRECTION} filters per direction "
        "(OR / blacklist), superseding the retired charter cap of <= 1 predicate/sleeve",
        "where_it_lives": [
            "tools/strategy_farm/config/gate_manifest.v4.json Q12.pattern_filter_cap_per_direction=3",
            "framework/include/QM/QM_Common.mqh opt_pp_buy1..3 / opt_pp_sell1..3 (6 inputs)",
            "decisions/DL-089_pattern_filter_wf_census_v3.md (superseded <=1 -> <=3)",
            "framework/include/QM/QM_PatternPermission.mqh QM_PP_MAX_PREDICATES=8 (profile capacity headroom)",
        ],
        "classification": (
            "SELECTION rule (economic / capacity), NOT a gate-integrity rule. Per "
            "master directive §20 the account-safety job belongs to the portfolio "
            "risk layer, not to a filter-count label; per §22 an arbitrary 'max N' "
            "must not be kept as a Hard Rule unless evidence supports it."
        ),
        "evidence_to_date": (
            "the completed DL-089 census recorded NO_FILTER_CHANGE on every program "
            "with a sealed receipt (see verdict_distribution). No historical EA has "
            "selected even one filter, so the cap of 3 has never bound. There is no "
            "evidence that 3 is too tight; there is also no evidence any filter helps."
        ),
        "recommendation": (
            "KEEP the cap of 3 per direction as a SELECTION parameter (not a Hard "
            "Rule) for now: it is non-binding on all historical evidence, and "
            "loosening it would only widen the search space and worsen the trial "
            "deflation for no demonstrated benefit. Revisit ONLY via the §30 "
            "procedure (counterfactual first, versioned contract, tests, reversible) "
            "if a future predeclared causal thesis produces a filter that both "
            "passes the sealed rule and is capped by 3. This slice does NOT change "
            "the Q12 contract."
        ),
    }


def build_catalog(
    *,
    mqh_path: Path,
    db_path: Path,
    census_artifacts: Path,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Assemble the full deterministic catalog model."""
    mqh_text = Path(mqh_path).read_text(encoding="utf-8")
    predicates = parse_pattern_predicates(mqh_text)

    # Historical joins (best-effort; explicit EVIDENCE_MISSING when absent).
    census: dict[str, Any]
    selection: dict[str, Any]
    if Path(db_path).exists():
        conn = _connect_ro(Path(db_path))
        try:
            census = load_census_join(conn)
        finally:
            conn.close()
    else:
        census = {"status": "EVIDENCE_MISSING", "reason": f"{db_path} not present"}
    selection = load_selection_receipts(Path(census_artifacts))

    # Attach per-predicate historical fields onto the inventory rows.
    census_pp = census.get("per_predicate", {}) if census.get("status") == "OK" else {}
    sel_pp = (
        selection.get("per_predicate_selected", {}) if selection.get("status") == "OK" else {}
    )
    for row in predicates:
        pid = str(row["predicate_id"])
        c = census_pp.get(pid)
        s = sel_pp.get(pid)
        row["historical_census"] = c if c is not None else "EVIDENCE_MISSING"
        row["historical_selection"] = (
            s if s is not None else {"times_selected_buy": 0, "times_selected_sell": 0}
        )

    # Category / provenance rollups.
    by_category: dict[str, int] = defaultdict(int)
    unger_count = 0
    unclassified: list[int] = []
    for row in predicates:
        by_category[row["category"]] += 1
        if row["unger_related"]:
            unger_count += 1
        if row["category"] == "UNCLASSIFIED":
            unclassified.append(row["predicate_id"])

    inputs_fingerprint = _sha256_bytes(
        mqh_text.encode("utf-8"),
        json.dumps(census.get("per_predicate", {}), sort_keys=True).encode("utf-8"),
        json.dumps(selection.get("per_predicate_selected", {}), sort_keys=True).encode("utf-8"),
        json.dumps(selection.get("verdict_distribution", {}), sort_keys=True).encode("utf-8"),
    )

    model = {
        "schema": CATALOG_SCHEMA,
        "generated_at_utc": _utc_now_iso(now),
        "inputs_sha256": inputs_fingerprint,
        "authority": "OWNER directive 3 §22 / §40 / §44 (2026-09-15)",
        "sources": {
            "pattern_permission_mqh": str(Path(mqh_path).as_posix()),
            "filter_library_mqh": "framework/include/QM/QM_FilterLibrary.mqh",
            "farm_db": str(Path(db_path).as_posix()),
            "census_artifacts": str(Path(census_artifacts).as_posix()),
            "selection_contract": "decisions/DL-089_pattern_filter_wf_census_v3.md",
        },
        "counts": {
            "predicates_total": len(predicates),
            "predicates_by_category": dict(sorted(by_category.items())),
            "unger_related_predicates": unger_count,
            "unclassified_predicate_ids": sorted(unclassified),
            "filter_modules": len(FILTER_MODULE_INVENTORY),
        },
        "pattern_filter_cap_per_direction": PATTERN_FILTER_CAP_PER_DIRECTION,
        "predicates": predicates,
        "filter_modules": FILTER_MODULE_INVENTORY,
        "historical_census": census,
        "historical_selection": selection,
        "ablation_programme": _ablation_programme(),
        "max_n_filters_disposition": _max_n_disposition(selection),
        "red_boundary_note": (
            "Descriptive catalog only. It does not change any gate contract, does not "
            "write verdicts, and does not re-run or re-weight the sealed DL-089 Q12 "
            "selection. Any economic-threshold change goes through the §30 procedure."
        ),
    }
    return model


# --- rendering ---------------------------------------------------------------
def _fmt(v: Any) -> str:
    if v is None:
        return "—"
    if isinstance(v, float):
        return f"{v:g}"
    return str(v)


def render_doc(model: dict[str, Any]) -> str:
    c = model["counts"]
    census = model["historical_census"]
    selection = model["historical_selection"]
    lines: list[str] = []
    lines.append("# Pattern & Filter Catalog")
    lines.append("")
    lines.append(
        f"Generated read-model (schema `{model['schema']}`), authority "
        f"{model['authority']}. Deterministic projection of the QuantMechanica "
        "pattern / filter universe with its historical DL-089 / Q12 test results."
    )
    lines.append("")
    lines.append(f"- Generated (UTC): `{model['generated_at_utc']}`")
    lines.append(f"- Inputs fingerprint: `{model['inputs_sha256']}`")
    lines.append(
        f"- Predicates: **{c['predicates_total']}** · Filter modules: "
        f"**{c['filter_modules']}** · Unger-related predicates: "
        f"**{c['unger_related_predicates']}**"
    )
    lines.append(
        f"- Filter cap: **{model['pattern_filter_cap_per_direction']} per direction** "
        "(selection parameter, not a Hard Rule)."
    )
    lines.append("")
    lines.append("> " + model["red_boundary_note"])
    lines.append("")

    lines.append("## Predicates by category (§40)")
    lines.append("")
    lines.append("| Category | Count |")
    lines.append("|---|---|")
    for cat, n in c["predicates_by_category"].items():
        lines.append(f"| {cat} | {n} |")
    lines.append("")

    lines.append("## Predicate inventory")
    lines.append("")
    lines.append(
        "`sel B/S` = programs that SEALED-selected this predicate buy/sell (DL-089 "
        "receipts). `census` = DESCRIPTIVE per-cell effect vs same-year no-filter "
        "baseline (observational, NOT a verdict): improved cells (>= +5% "
        "return_to_maxdd) / cells with a baseline, mean trade-reduction %."
    )
    lines.append("")
    lines.append("| id | name | category | subfamily | Unger | sel B/S | census impr/base | trd red % |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for row in model["predicates"]:
        sel = row["historical_selection"]
        cen = row["historical_census"]
        if isinstance(cen, dict):
            impr = f"{cen['improved_cells_ge_5pct_rtmdd']}/{cen['cells_with_baseline']}"
            trd = _fmt(cen["mean_trade_reduction_pct"])
        else:
            impr = "EVIDENCE_MISSING"
            trd = "—"
        lines.append(
            f"| {row['predicate_id']} | {row['display_name']} | {row['category']} | "
            f"{row['subfamily']} | {'yes' if row['unger_related'] else ''} | "
            f"{sel['times_selected_buy']}/{sel['times_selected_sell']} | {impr} | {trd} |"
        )
    lines.append("")

    lines.append("## Filter modules")
    lines.append("")
    lines.append("| Module | Category | File | Parameters |")
    lines.append("|---|---|---|---|")
    for m in model["filter_modules"]:
        params = ", ".join(m["parameters"])
        lines.append(f"| {m['name']} | {m['category']} | `{m['file']}` | {params} |")
    lines.append("")

    lines.append("## Historical test results (DL-089 / Q12)")
    lines.append("")
    if selection.get("status") == "OK":
        lines.append(
            f"- Sealed selection receipts: **{selection['programs_evaluated']}** programs. "
            "Verdicts: "
            + ", ".join(f"{k}={v}" for k, v in selection["verdict_distribution"].items())
            + "."
        )
        lines.append(f"- Authority: {selection['authority']}.")
    else:
        lines.append(f"- Selection receipts: EVIDENCE_MISSING ({selection.get('reason')}).")
    if census.get("status") == "OK":
        lines.append(
            f"- Census (descriptive): **{census['measured_cells_total']}** measured "
            f"predicate cells across **{census['programs_covered']}** programs; "
            f"**{census['baseline_cells_total']}** baseline cells. Success measure: "
            f"{census['success_measure']}."
        )
    else:
        lines.append(f"- Census: EVIDENCE_MISSING ({census.get('reason')}).")
    lines.append("")

    lines.append("## Fresh ablation programme (§22)")
    lines.append("")
    ab = model["ablation_programme"]
    lines.append(f"- **Overlay design.** base = {ab['overlay_design']['base']}; "
                 f"single = {ab['overlay_design']['single_overlays']}; "
                 f"combinations = {ab['overlay_design']['justified_combinations']}; "
                 f"cap = {ab['overlay_design']['cap']}.")
    lines.append(f"- **Null baseline.** {ab['null_baseline']}")
    lines.append("- **Measurements.** " + "; ".join(ab["measurements"]) + ".")
    mt = ab["multiple_testing_control"]
    lines.append(
        f"- **Multiple-testing control.** {mt['pre_registered_families']}; "
        f"{mt['fdr']}; {mt['holdout']}; {mt['trial_deflation']}."
    )
    lines.append(f"- **Regime & portfolio effects.** {ab['regime_and_portfolio_effects']}")
    lines.append(f"- **Feeds Q12.** {ab['how_it_feeds_q12']}")
    lines.append(f"- **Feeds autonomous research.** {ab['how_it_feeds_autonomous_research']}")
    lines.append(
        "- **search_history_ledger families.** `"
        + "`, `".join(ab["search_history_families"])
        + "`."
    )
    lines.append("")

    lines.append("## Disposition of the 'max N filters' rule (§22)")
    lines.append("")
    d = model["max_n_filters_disposition"]
    lines.append(f"- **Rule.** {d['rule']}")
    lines.append("- **Where it lives.** " + "; ".join(d["where_it_lives"]) + ".")
    lines.append(f"- **Classification.** {d['classification']}")
    lines.append(f"- **Evidence to date.** {d['evidence_to_date']}")
    lines.append(f"- **Recommendation.** {d['recommendation']}")
    lines.append("")
    return "\n".join(lines)


def render_vault(model: dict[str, Any]) -> str:
    """Vault node with an unmistakable machine-generated frontmatter marker."""
    c = model["counts"]
    selection = model["historical_selection"]
    lines: list[str] = []
    lines.append("---")
    lines.append("generated: true")
    lines.append("generated_by: pattern_filter_catalog/v1")
    lines.append(f"schema: {model['schema']}")
    lines.append(f"generated_at_utc: {model['generated_at_utc']}")
    lines.append(f"inputs_sha256: {model['inputs_sha256']}")
    lines.append("source_of_truth: docs/research/PATTERN_FILTER_CATALOG.md")
    lines.append("do_not_edit: this node is overwritten by the generator")
    lines.append("---")
    lines.append("")
    lines.append("# Pattern & Filter Catalog")
    lines.append("")
    lines.append(
        "> Machine-generated company-knowledge projection (§40). Runtime truth is "
        "the read-model `D:/QM/reports/state/pattern_filter_catalog.json`; the "
        "canonical write-up is `docs/research/PATTERN_FILTER_CATALOG.md`."
    )
    lines.append("")
    lines.append(
        f"- **{c['predicates_total']} predicates** across "
        + ", ".join(f"{k} {v}" for k, v in c["predicates_by_category"].items())
        + f"; **{c['unger_related_predicates']}** Unger-related."
    )
    lines.append(f"- **{c['filter_modules']} first-class filter modules** "
                 "(news / regime / volatility / pattern-permission).")
    lines.append(
        f"- Filter cap **{model['pattern_filter_cap_per_direction']} per direction** "
        "(selection parameter — not a Hard Rule; §22)."
    )
    if selection.get("status") == "OK":
        lines.append(
            f"- Historical DL-089 verdicts over {selection['programs_evaluated']} "
            "programs: "
            + ", ".join(f"{k}={v}" for k, v in selection["verdict_distribution"].items())
            + "."
        )
    lines.append("")
    lines.append("## Disposition of the 'max N filters' rule")
    lines.append("")
    d = model["max_n_filters_disposition"]
    lines.append(f"{d['classification']}")
    lines.append("")
    lines.append(f"**Recommendation.** {d['recommendation']}")
    lines.append("")
    lines.append(
        "See the canonical doc for the full predicate inventory, filter modules, "
        "the fresh ablation programme, and per-predicate historical results."
    )
    lines.append("")
    return "\n".join(lines)


def summary_for_research_state(model: dict[str, Any]) -> dict[str, Any]:
    """Compact fold for research_state / Mission Control."""
    c = model["counts"]
    selection = model["historical_selection"]
    return {
        "schema": model["schema"],
        "generated_at_utc": model["generated_at_utc"],
        "predicates_total": c["predicates_total"],
        "filter_modules": c["filter_modules"],
        "unger_related_predicates": c["unger_related_predicates"],
        "pattern_filter_cap_per_direction": model["pattern_filter_cap_per_direction"],
        "selection_verdict_distribution": (
            selection.get("verdict_distribution", {})
            if selection.get("status") == "OK"
            else "EVIDENCE_MISSING"
        ),
    }


def write_outputs(
    model: dict[str, Any],
    out_json: Path,
    out_doc: Path,
    out_vault: Path | None,
) -> list[str]:
    written: list[str] = []
    out_json = Path(out_json)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(
        json.dumps(model, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    written.append(str(out_json))

    out_doc = Path(out_doc)
    out_doc.parent.mkdir(parents=True, exist_ok=True)
    out_doc.write_text(render_doc(model) + "\n", encoding="utf-8", newline="\n")
    written.append(str(out_doc))

    if out_vault is not None:
        out_vault = Path(out_vault)
        try:
            out_vault.parent.mkdir(parents=True, exist_ok=True)
            out_vault.write_text(
                render_vault(model) + "\n", encoding="utf-8", newline="\n"
            )
            written.append(str(out_vault))
        except OSError as exc:  # vault drive may be absent in some sessions
            written.append(f"VAULT_SKIPPED:{out_vault} ({exc})")
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--census-artifacts", type=Path, default=DEFAULT_CENSUS_ARTIFACTS)
    parser.add_argument("--mqh", type=Path, default=DEFAULT_MQH)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--doc", type=Path, default=DEFAULT_DOC)
    parser.add_argument(
        "--vault",
        type=Path,
        default=DEFAULT_VAULT,
        help="Vault node path; pass 'NONE' to skip the vault write.",
    )
    parser.add_argument("--now", type=str, default=None, help="Fixed UTC ISO stamp for determinism.")
    args = parser.parse_args(argv)

    now = None
    if args.now:
        now = dt.datetime.fromisoformat(args.now)

    model = build_catalog(
        mqh_path=args.mqh,
        db_path=args.db,
        census_artifacts=args.census_artifacts,
        now=now,
    )
    vault = None if str(args.vault) == "NONE" else args.vault
    written = write_outputs(model, args.out, args.doc, vault)
    summary = summary_for_research_state(model)
    print(json.dumps({"written": written, "summary": summary}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
