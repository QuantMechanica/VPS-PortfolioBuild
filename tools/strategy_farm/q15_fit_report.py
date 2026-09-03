#!/usr/bin/env python3
"""Vault Q15 step-3 / Q11 OWNER-facing portfolio fit report generator (tool gap G2).

Vault Q15 step 3 (mirrored in ``docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md`` step 6,
line 155) promises an OWNER-facing ``q11_fit_<date>.md`` -- correlation matrix, family
clustering, symbol / asset-class coverage, per-member marginal Sharpe, effective number
of bets (ENB), and a risk-budget frame -- but no single tool produced it bound to the
qualified pool (``build_book_dxz.py`` emits only a manifest).  This closes gap G2
(runbook lines 328-331).

It is strictly read-only:

  * The qualified pool is exactly what ``book_build_guard`` reports -- its census
    delegates to ``rebaseline_census.build_pairs`` / ``summarise_pair`` and opens the
    farm DB via ``rebaseline_census.open_ro`` (a ``mode=ro`` URI, ``rebaseline_census``).
    This module imports that census function; it never opens the DB read/write.
  * The return streams are the sealed q08 daily-PnL streams that
    ``portfolio_correlation.py`` uses -- loaded through
    ``portfolio_common.load_streams`` from the MT5 ``Common\\Files\\QM\\q08_trades``
    tree (``portfolio_common.DEFAULT_COMMON_DIR``), priced with the same commission
    model, and reduced to daily ``net_of_cost`` by ``portfolio_common.to_daily_pnl``.

No threshold is invented.  Every cap is cited to its source file in
``THRESHOLD_PROVENANCE`` and echoed into both the markdown and the JSON sidecar:

  * ``min_overlap_days = 60`` -- ``portfolio_correlation.build_artifact`` default
    (``portfolio_correlation.py``); Vault Q15 correlation-evidence standard V4
    (``docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md`` lines 212-214).
  * ``|r| < 0.5`` between any two members -- Vault Q15 hard rule
    (``BOOK_CEREMONY_RUNBOOK_2026-09.md`` lines 213-214).
  * ``family <= 3``, ``symbol <= 2``, ``10-15 EAs`` -- Vault Q15 hard caps
    (``BOOK_CEREMONY_RUNBOOK_2026-09.md`` lines 202-203).

A pair whose co-active overlap is below the floor is marked ``NOT_EVALUABLE`` -- never a
fabricated correlation.  When any pair is ``NOT_EVALUABLE`` the ENB and the |r| cap are
reported ``NOT_EVALUABLE`` / ``NOT_ASSERTABLE`` rather than guessed.

This tool creates no book, manifest, sleeve, weight, order file, live/T_Live state, gate
threshold, verdict, trade stream, queue row, or DB change.  Application of any weight to
live remains a separate OWNER ceremony (runbook steps 7-12).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import statistics
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import book_build_guard, gate_manifest
from tools.strategy_farm.portfolio import concentration_tail, portfolio_correlation
from tools.strategy_farm.portfolio.commission import describe_model, load_model
from tools.strategy_farm.portfolio.portfolio_common import (
    DEFAULT_COMMON_DIR,
    _coerce_ea_int,
    align,
    key_label,
    load_streams,
    to_daily_pnl,
)

try:
    import numpy as _np
except Exception:  # pragma: no cover - numpy is present in the runtime env
    _np = None

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_ORDER_DIR = REPO_ROOT / "decisions"
DEFAULT_OUT_DIR = Path(r"D:\QM\reports\portfolio")

# Floor and caps -- each carried with the file it is cited to.  Nothing here is a
# free parameter of this tool; changing any of these is a gate-threshold act (ROT).
MIN_OVERLAP_DAYS = 60
CORRELATION_CAP = 0.5
FAMILY_CAP = 3
SYMBOL_CAP = 2
BOOK_MIN = 10
BOOK_MAX = 15

THRESHOLD_PROVENANCE: dict[str, dict[str, Any]] = {
    "min_overlap_days": {
        "value": MIN_OVERLAP_DAYS,
        "source": "portfolio_correlation.py build_artifact default; "
        "docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 212-214 (Vault Q15 V4)",
    },
    "correlation_cap_abs_r": {
        "value": CORRELATION_CAP,
        "comparator": "|r| < 0.5",
        "source": "docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 213-214 "
        "(Vault Q15 hard rule)",
    },
    "family_cap_members": {
        "value": FAMILY_CAP,
        "comparator": "family <= 3 members",
        "source": "docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 202-203 "
        "(Vault Q15 hard caps)",
    },
    "symbol_cap_members": {
        "value": SYMBOL_CAP,
        "comparator": "symbol <= 2 members",
        "source": "docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 202-203 "
        "(Vault Q15 hard caps)",
    },
    "book_size_band_eas": {
        "value": [BOOK_MIN, BOOK_MAX],
        "comparator": "10-15 EAs",
        "source": "docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 202-203 "
        "(Vault Q15 hard caps)",
    },
}

ENB_FORMULA = (
    "ENB = (sum_i lambda_i)^2 / (sum_i lambda_i^2), where lambda_i are the eigenvalues "
    "of the N x N Pearson correlation matrix C. Because trace(C) = sum_i lambda_i = N, "
    "this equals N^2 / sum_i lambda_i^2, and sum_i lambda_i^2 = ||C||_F^2 = "
    "sum_{i,j} C_ij^2 (Frobenius identity). ENB = N when all members are mutually "
    "uncorrelated and ENB = 1 when all members are perfectly correlated."
)
ENB_REFERENCE = (
    "Meucci, A. (2009), 'Managing Diversification', Risk 22(5), 74-79 (diversification "
    "distribution / effective number of bets); the closed form used here is the inverse "
    "participation ratio (effective rank) of the correlation eigenvalue spectrum."
)
SHARPE_FORMULA = (
    "Pool daily series P(d) = sum_k x_k(d) over the union of all members' trade days, "
    "where x_k(d) is member k's daily net-of-cost P/L (0 on days k did not close a "
    "trade) at equal unit weight (no per-sleeve risk weights exist pre-Q15). "
    "Sharpe_daily(S) = mean(S) / stdev(S) with sample stdev (ddof=1); non-annualized "
    "(the union grid is irregular, so no periods-per-year constant is invented). "
    "Marginal Sharpe of member m = Sharpe_daily(P) - Sharpe_daily(P - x_m) on the same "
    "fixed union grid (leave-one-out)."
)

_ISO = "%Y-%m-%d"


# --------------------------------------------------------------------------- pool
def qualified_pool_keys(
    db_path: Path,
    order_dir: Path,
    venue: str,
) -> tuple[list[tuple[int, str]], dict[str, Any]]:
    """Return the qualified (ea_int, symbol) keys and the guard status snapshot.

    Pool membership is exactly ``book_build_guard``'s census: pairs whose
    ``highest_contiguous_valid_gate`` equals the manifest terminal requalification
    gate (``book_build_guard._qualified_pair_rows``).  The guard result gives the
    OWNER-facing three counts and the order/allow reasons.
    """
    manifest = gate_manifest.load_gate_manifest()
    terminal_gate = manifest.terminal_requalification_gate
    rows = book_build_guard._qualified_pair_rows(Path(db_path), terminal_gate)
    guard = book_build_guard.check_book_build_allowed(venue, Path(db_path), Path(order_dir))

    keys: list[tuple[int, str]] = []
    unparseable: list[str] = []
    for row in rows:
        ea_int = _coerce_ea_int(row["ea_id"])
        if ea_int is None:
            unparseable.append(str(row["ea_id"]))
            continue
        keys.append((ea_int, str(row["symbol"])))
    keys = sorted(set(keys))

    snapshot = {
        "terminal_requalification_gate": terminal_gate,
        "venue": venue,
        "qualified_pairs": guard.qualified_pairs,
        "distinct_eas": guard.distinct_eas,
        "strategy_families": guard.strategy_families,
        "allowed": guard.allowed,
        "order_artifact": guard.order_artifact,
        "reasons": list(guard.reasons),
        "unparseable_ea_ids": unparseable,
    }
    return keys, snapshot


def load_pool_streams(common_dir: Path, keys: Sequence[tuple[int, str]]):
    """Load the sealed q08 streams for the pool keys (same source as correlation)."""
    model = load_model()
    streams = load_streams(Path(common_dir), candidates=list(keys), commission_model=model)
    present = sorted(streams)
    missing = sorted(set(tuple(k) for k in keys) - set(present))
    series_by_key = {key: to_daily_pnl(trades) for key, trades in streams.items()}
    empty = sorted(k for k, s in series_by_key.items() if not s)
    return streams, series_by_key, present, missing, empty, model


# ------------------------------------------------------------------ correlation
def correlation_block(
    series_by_key: Mapping[tuple[int, str], Mapping[dt.date, float]],
    min_overlap_days: int = MIN_OVERLAP_DAYS,
) -> dict[str, Any]:
    """Pairwise Pearson on co-active days with explicit overlap counts.

    Co-activity and the correlation formula match
    ``portfolio_correlation.correlation_matrix`` / ``_pearson`` exactly (both members
    non-zero on a day counts as one overlap day).  A pair below the floor is marked
    ``NOT_EVALUABLE`` and its correlation is ``None`` -- never a fabricated number.
    """
    keys, dates, matrix = align(dict(series_by_key))
    n = len(keys)
    corr: list[list[float | None]] = [[None] * n for _ in range(n)]
    overlap: list[list[int]] = [[0] * n for _ in range(n)]
    not_evaluable: list[dict[str, Any]] = []
    evaluable: list[dict[str, Any]] = []

    for i in range(n):
        corr[i][i] = 1.0
        overlap[i][i] = sum(1 for row in matrix for v in [row[i]] if float(v) != 0.0)
        for j in range(i + 1, n):
            left = [float(row[i]) for row in matrix]
            right = [float(row[j]) for row in matrix]
            active = [
                (a, b) for a, b in zip(left, right) if a != 0.0 and b != 0.0
            ]
            days = len(active)
            overlap[i][j] = overlap[j][i] = days
            pair = [key_label(keys[i]), key_label(keys[j])]
            if days < min_overlap_days:
                corr[i][j] = corr[j][i] = None
                not_evaluable.append({"pair": pair, "overlap_days": days})
            else:
                value = portfolio_correlation._pearson(
                    [a for a, _ in active], [b for _, b in active]
                )
                corr[i][j] = corr[j][i] = value
                evaluable.append({"pair": pair, "overlap_days": days, "r": value})

    return {
        "keys": [key_label(k) for k in keys],
        "key_tuples": [list(k) for k in keys],
        "dates_start": dates[0].isoformat() if dates else None,
        "dates_end": dates[-1].isoformat() if dates else None,
        "n_union_days": len(dates),
        "min_overlap_days": min_overlap_days,
        "matrix": corr,
        "overlap_days_matrix": overlap,
        "evaluable_pairs": evaluable,
        "not_evaluable_pairs": not_evaluable,
        "_ordered_keys": list(keys),
    }


# -------------------------------------------------------------------------- ENB
def compute_enb(matrix: Sequence[Sequence[float | None]]) -> dict[str, Any]:
    """Effective number of bets from the correlation eigenvalue spectrum.

    Requires a fully evaluable matrix: if any off-diagonal is ``None``
    (``NOT_EVALUABLE``) the ENB is reported ``NOT_EVALUABLE`` rather than computed on a
    fabricated matrix.  ``sum lambda_i^2`` is computed via the exact Frobenius identity
    ``sum_{i,j} C_ij^2`` (numpy-independent); eigenvalues are additionally reported when
    numpy is available.
    """
    n = len(matrix)
    result: dict[str, Any] = {
        "formula": ENB_FORMULA,
        "reference": ENB_REFERENCE,
        "n_series": n,
        "value": None,
        "status": "NOT_EVALUABLE",
        "reason": None,
        "eigenvalues": None,
    }
    if n == 0:
        result["reason"] = "empty correlation matrix"
        return result
    missing = [
        [i, j]
        for i in range(n)
        for j in range(i + 1, n)
        if matrix[i][j] is None
    ]
    if missing:
        result["reason"] = (
            f"{len(missing)} of {n * (n - 1) // 2} off-diagonal pairs are "
            f"NOT_EVALUABLE (below the {MIN_OVERLAP_DAYS}-day overlap floor); "
            "ENB requires a complete correlation matrix"
        )
        result["not_evaluable_pairs"] = missing
        return result

    frob_sq = 0.0
    for i in range(n):
        for j in range(n):
            frob_sq += float(matrix[i][j]) ** 2
    if frob_sq <= 0.0:
        result["reason"] = "degenerate correlation matrix (zero Frobenius norm)"
        return result
    enb = (float(n) ** 2) / frob_sq
    result["value"] = round(enb, 8)
    result["sum_lambda_squared_frobenius"] = round(frob_sq, 8)
    result["status"] = "OK"
    if _np is not None:
        try:
            eig = _np.linalg.eigvalsh(_np.array(matrix, dtype=float))
            result["eigenvalues"] = [round(float(v), 8) for v in sorted(eig, reverse=True)]
            result["sum_lambda_squared_eigen"] = round(
                float(sum(float(v) ** 2 for v in eig)), 8
            )
        except Exception as exc:  # pragma: no cover - numerical guard
            result["eigenvalues_error"] = f"{type(exc).__name__}: {exc}"
    return result


# ------------------------------------------------------------ marginal Sharpe
def _sharpe_daily(series: Sequence[float]) -> float | None:
    values = [float(v) for v in series]
    if len(values) < 2:
        return None
    sd = statistics.stdev(values)
    if sd == 0.0:
        return None
    return statistics.mean(values) / sd


def marginal_sharpe_block(
    series_by_key: Mapping[tuple[int, str], Mapping[dt.date, float]],
) -> dict[str, Any]:
    """Per-member leave-one-out marginal Sharpe on the pooled daily P/L series."""
    keys = sorted(series_by_key)
    dates = sorted({d for s in series_by_key.values() for d in s})
    pooled = [
        sum(float(series_by_key[k].get(d, 0.0)) for k in keys) for d in dates
    ]
    pool_sharpe = _sharpe_daily(pooled)

    members: list[dict[str, Any]] = []
    for k in keys:
        loo = [
            pooled[idx] - float(series_by_key[k].get(d, 0.0))
            for idx, d in enumerate(dates)
        ]
        loo_sharpe = _sharpe_daily(loo)
        if pool_sharpe is None or loo_sharpe is None:
            marginal: float | None = None
        else:
            marginal = round(pool_sharpe - loo_sharpe, 8)
        members.append({
            "key": key_label(k),
            "leave_one_out_sharpe_daily": None if loo_sharpe is None else round(loo_sharpe, 8),
            "marginal_sharpe_daily": marginal,
        })

    return {
        "formula": SHARPE_FORMULA,
        "series_units": "daily net-of-cost P/L (account currency), equal unit weight, "
        "RISK_FIXED backtest scale",
        "n_union_days": len(dates),
        "pool_sharpe_daily": None if pool_sharpe is None else round(pool_sharpe, 8),
        "members": members,
    }


# -------------------------------------------------------- families / symbols
def resolve_families(keys: Sequence[tuple[int, str]]) -> dict[tuple[int, str], str]:
    """Family per key via the same registry/slug source the builders use.

    ``concentration_tail.family_fingerprints`` derives the family from the active
    ``ea_id_registry`` slug stem (falling back to the unique EA directory).  Resolve
    per key so one unresolved EA does not abort the whole OWNER report.
    """
    out: dict[tuple[int, str], str] = {}
    for key in keys:
        try:
            fam = concentration_tail.family_fingerprints(REPO_ROOT, [key])
            out[key] = fam[key]
        except Exception as exc:
            out[key] = f"UNRESOLVED ({type(exc).__name__})"
    return out


def resolve_asset_classes(keys: Sequence[tuple[int, str]]) -> dict[tuple[int, str], str]:
    try:
        assets, _binding = concentration_tail.load_asset_classes()
    except Exception:
        return {key: "unknown" for key in keys}
    return {key: assets.get(str(key[1]).upper(), "unknown") for key in keys}


def _count_cap_block(
    label: str,
    group_of: Mapping[tuple[int, str], str],
    keys: Sequence[tuple[int, str]],
    cap: int,
    source: str,
) -> dict[str, Any]:
    groups: dict[str, list[str]] = {}
    for key in keys:
        groups.setdefault(group_of[key], []).append(key_label(key))
    rows = []
    breach = False
    for name in sorted(groups):
        members = sorted(groups[name])
        is_breach = len(members) > cap
        breach = breach or is_breach
        rows.append({
            "group": name,
            "count": len(members),
            "cap": cap,
            "members": members,
            "status": "BREACH" if is_breach else "PASS",
        })
    return {
        "dimension": label,
        "cap": cap,
        "cap_source": source,
        "distinct_groups": len(groups),
        "status": "BREACH" if breach else "PASS",
        "rows": rows,
    }


def coverage_block(
    keys: Sequence[tuple[int, str]],
    family_of: Mapping[tuple[int, str], str],
    asset_of: Mapping[tuple[int, str], str],
) -> dict[str, Any]:
    symbol_of = {key: str(key[1]).upper() for key in keys}
    symbol_cap = _count_cap_block(
        "symbol", symbol_of, keys, SYMBOL_CAP,
        THRESHOLD_PROVENANCE["symbol_cap_members"]["source"],
    )
    family_cap = _count_cap_block(
        "family", family_of, keys, FAMILY_CAP,
        THRESHOLD_PROVENANCE["family_cap_members"]["source"],
    )
    asset_counts: dict[str, list[str]] = {}
    for key in keys:
        asset_counts.setdefault(asset_of[key], []).append(key_label(key))
    asset_rows = [
        {"asset_class": name, "count": len(sorted(members)), "members": sorted(members)}
        for name, members in sorted(asset_counts.items())
    ]
    return {
        "symbol_cap": symbol_cap,
        "family_cap": family_cap,
        "asset_class_coverage": {
            "distinct_asset_classes": len(asset_counts),
            "rows": asset_rows,
        },
    }


def correlation_cap_block(corr: Mapping[str, Any]) -> dict[str, Any]:
    """|r| < 0.5 cap check over the evaluable pairs; NOT_ASSERTABLE otherwise."""
    breaches = [
        {"pair": p["pair"], "r": p["r"], "abs_r": round(abs(float(p["r"])), 8)}
        for p in corr["evaluable_pairs"]
        if p["r"] is not None and abs(float(p["r"])) >= CORRELATION_CAP
    ]
    n_eval = len(corr["evaluable_pairs"])
    n_pairs = n_eval + len(corr["not_evaluable_pairs"])
    if breaches:
        status = "BREACH"
    elif n_eval == n_pairs and n_pairs > 0:
        status = "PASS"
    elif n_eval == 0:
        status = "NOT_ASSERTABLE"
    else:
        status = "PARTIAL"
    return {
        "cap": CORRELATION_CAP,
        "comparator": "|r| < 0.5",
        "cap_source": THRESHOLD_PROVENANCE["correlation_cap_abs_r"]["source"],
        "pairs_total": n_pairs,
        "pairs_evaluable": n_eval,
        "pairs_not_evaluable": len(corr["not_evaluable_pairs"]),
        "breaches": breaches,
        "status": status,
    }


def book_size_block(n: int) -> dict[str, Any]:
    if n > BOOK_MAX:
        status = "BREACH"
    elif n < BOOK_MIN:
        status = "BELOW_BAND"
    else:
        status = "PASS"
    return {
        "n_eas": n,
        "band": [BOOK_MIN, BOOK_MAX],
        "band_source": THRESHOLD_PROVENANCE["book_size_band_eas"]["source"],
        "status": status,
    }


# ------------------------------------------------------------------- assemble
def build_report(
    *,
    db_path: Path,
    order_dir: Path,
    venue: str,
    common_dir: Path,
    min_overlap_days: int,
    as_of: str,
) -> dict[str, Any]:
    keys, pool = qualified_pool_keys(db_path, order_dir, venue)
    streams, series_by_key, present, missing, empty, model = load_pool_streams(
        common_dir, keys
    )
    present_keys = [k for k in present if series_by_key.get(k)]

    corr = correlation_block(series_by_key, min_overlap_days)
    enb = compute_enb(corr["matrix"])
    sharpe = marginal_sharpe_block(series_by_key)
    family_of = resolve_families(present_keys)
    asset_of = resolve_asset_classes(present_keys)
    coverage = coverage_block(present_keys, family_of, asset_of)
    corr_cap = correlation_cap_block(corr)
    size = book_size_block(pool["qualified_pairs"])

    per_series = {}
    for key in present_keys:
        trades = streams[key]
        daily = series_by_key[key]
        per_series[key_label(key)] = {
            "trades": len(trades),
            "active_days": sum(1 for v in daily.values() if v != 0.0),
            "family": family_of.get(key),
            "symbol": str(key[1]).upper(),
            "asset_class": asset_of.get(key),
            "net_of_cost_total": round(sum(t.net_of_cost for t in trades), 8),
            "first_day": min(daily).isoformat() if daily else None,
            "last_day": max(daily).isoformat() if daily else None,
        }

    corr_public = {k: v for k, v in corr.items() if not k.startswith("_")}

    return {
        "schema": "qm.q15_fit_report/v1",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "as_of": as_of,
        "read_only": True,
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "inputs": {
            "db_path": str(Path(db_path)),
            "db_access": "read-only via rebaseline_census.open_ro (mode=ro)",
            "order_dir": str(Path(order_dir)),
            "common_dir": str(Path(common_dir)),
            "stream_source": "portfolio_common.load_streams (Common/Files/QM/q08_trades)",
            "commission_basis": portfolio_correlation.COMMISSION_BASIS,
            "commission_model": describe_model(model),
            "commission_degraded": model.degraded,
        },
        "threshold_provenance": THRESHOLD_PROVENANCE,
        "pool": pool,
        "stream_availability": {
            "streams_present": [key_label(k) for k in present],
            "streams_missing": [key_label(k) for k in missing],
            "streams_empty": [key_label(k) for k in empty],
        },
        "per_series": per_series,
        "correlation": corr_public,
        "enb": enb,
        "marginal_sharpe": sharpe,
        "coverage": coverage,
        "cap_checks": {
            "correlation": corr_cap,
            "symbol": coverage["symbol_cap"],
            "family": coverage["family_cap"],
            "book_size": size,
        },
    }


# -------------------------------------------------------------------- markdown
def _fmt(value: Any) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.4f}"
    return str(value)


def render_markdown(report: Mapping[str, Any]) -> str:
    pool = report["pool"]
    corr = report["correlation"]
    enb = report["enb"]
    sharpe = report["marginal_sharpe"]
    caps = report["cap_checks"]
    lines: list[str] = []

    lines.append(f"# Q11/Q15 Portfolio Fit Report - {report['as_of']}")
    lines.append("")
    lines.append(
        f"Generated {report['generated_at_utc']} (UTC). **Read-only, analytic; "
        "application authority OWNER_ONLY, deployment/AutoTrading action NONE.** This "
        "report changes no book, weight, verdict, or live state."
    )
    lines.append("")
    lines.append(
        "Tool: `tools/strategy_farm/q15_fit_report.py` (closes runbook gap G2). Pool "
        "membership is exactly `book_build_guard`'s census; return streams are the "
        "sealed q08 daily-PnL streams `portfolio_correlation.py` uses."
    )
    lines.append("")

    # Pool summary
    lines.append("## 1 - Qualified pool (book_build_guard census)")
    lines.append("")
    lines.append(
        f"- Terminal requalification gate: `{pool['terminal_requalification_gate']}`; "
        f"venue `{pool['venue']}`."
    )
    lines.append(
        f"- `qualified_pairs = {pool['qualified_pairs']}`, "
        f"`distinct_eas = {pool['distinct_eas']}`, "
        f"`strategy_families = {pool['strategy_families']}`; "
        f"guard `allowed = {str(pool['allowed']).lower()}`."
    )
    if pool.get("order_artifact"):
        lines.append(f"- OWNER order artifact: `{pool['order_artifact']}`.")
    if pool.get("reasons"):
        lines.append("- Guard reasons:")
        for reason in pool["reasons"]:
            lines.append(f"  - `{reason}`")
    lines.append("")
    lines.append("| EA:symbol | family | asset class | trades | active days | first | last |")
    lines.append("|---|---|---|---:|---:|---|---|")
    for label in report["correlation"]["keys"]:
        info = report["per_series"].get(label, {})
        lines.append(
            f"| {label} | {info.get('family','n/a')} | {info.get('asset_class','n/a')} | "
            f"{info.get('trades','n/a')} | {info.get('active_days','n/a')} | "
            f"{info.get('first_day','n/a')} | {info.get('last_day','n/a')} |"
        )
    avail = report["stream_availability"]
    if avail["streams_missing"]:
        lines.append("")
        lines.append(f"- Streams missing (no q08 file): {avail['streams_missing']}.")
    if avail["streams_empty"]:
        lines.append(f"- Streams empty (no closed trades): {avail['streams_empty']}.")
    lines.append("")

    # Correlation matrix
    lines.append("## 2 - Correlation matrix (daily net-of-cost P/L)")
    lines.append("")
    lines.append(
        f"Pearson on co-active days (both members non-zero). Overlap floor "
        f"`min_overlap_days = {corr['min_overlap_days']}` "
        f"({THRESHOLD_PROVENANCE['min_overlap_days']['source']}). A pair below the "
        "floor is `NOT_EVALUABLE` (never a fabricated number)."
    )
    lines.append("")
    keys = corr["keys"]
    header = "| r \\\\ overlap | " + " | ".join(keys) + " |"
    lines.append(header)
    lines.append("|" + "---|" * (len(keys) + 1))
    for i, ki in enumerate(keys):
        cells = []
        for j in range(len(keys)):
            if i == j:
                cells.append("1.0")
            else:
                r = corr["matrix"][i][j]
                ov = corr["overlap_days_matrix"][i][j]
                if r is None:
                    cells.append(f"NE (ov={ov})")
                else:
                    cells.append(f"{r:.3f} (ov={ov})")
        lines.append(f"| {ki} | " + " | ".join(cells) + " |")
    lines.append("")
    lines.append(
        f"- Union trading days: `{corr['n_union_days']}` "
        f"({_fmt(corr['dates_start'])} -> {_fmt(corr['dates_end'])})."
    )
    lines.append(
        f"- Evaluable pairs: `{len(corr['evaluable_pairs'])}`; "
        f"NOT_EVALUABLE pairs: `{len(corr['not_evaluable_pairs'])}` "
        "(overlap below floor)."
    )
    if corr["not_evaluable_pairs"]:
        lines.append("- NOT_EVALUABLE pairs (overlap days):")
        for pair in corr["not_evaluable_pairs"]:
            lines.append(f"  - {pair['pair'][0]} x {pair['pair'][1]}: `{pair['overlap_days']}` days")
    lines.append("")

    # ENB
    lines.append("## 3 - Effective number of bets (ENB)")
    lines.append("")
    lines.append(f"- Formula: {enb['formula']}")
    lines.append(f"- Reference: {enb['reference']}")
    if enb["status"] == "OK":
        lines.append(
            f"- **ENB = `{enb['value']}`** across `{enb['n_series']}` members "
            f"(sum lambda^2 = `{enb.get('sum_lambda_squared_frobenius')}`)."
        )
        if enb.get("eigenvalues") is not None:
            lines.append(f"- Correlation eigenvalues: `{enb['eigenvalues']}`.")
    else:
        lines.append(f"- **ENB = `NOT_EVALUABLE`** - {enb['reason']}.")
    lines.append("")

    # Marginal Sharpe
    lines.append("## 4 - Per-member marginal Sharpe (leave-one-out)")
    lines.append("")
    lines.append(f"- Formula: {sharpe['formula']}")
    lines.append(f"- Series units: {sharpe['series_units']}.")
    lines.append(
        f"- Pool daily Sharpe over `{sharpe['n_union_days']}` union days: "
        f"`{_fmt(sharpe['pool_sharpe_daily'])}`."
    )
    lines.append("")
    lines.append("| Member | leave-one-out Sharpe | marginal Sharpe |")
    lines.append("|---|---:|---:|")
    for m in sharpe["members"]:
        lines.append(
            f"| {m['key']} | {_fmt(m['leave_one_out_sharpe_daily'])} | "
            f"{_fmt(m['marginal_sharpe_daily'])} |"
        )
    lines.append("")
    lines.append(
        "- Positive marginal Sharpe = the member raises the pooled daily Sharpe; "
        "negative = it lowers it. Non-annualized."
    )
    lines.append("")

    # Coverage
    cov = report["coverage"]
    lines.append("## 5 - Symbol / asset-class / family coverage")
    lines.append("")
    lines.append("| Asset class | count | members |")
    lines.append("|---|---:|---|")
    for row in cov["asset_class_coverage"]["rows"]:
        lines.append(f"| {row['asset_class']} | {row['count']} | {', '.join(row['members'])} |")
    lines.append("")

    # Cap checks
    lines.append("## 6 - Cap checks (all thresholds cited; none invented)")
    lines.append("")
    cc = caps["correlation"]
    lines.append(
        f"- **Correlation `|r| < {cc['cap']}`** ({cc['cap_source']}): `{cc['status']}` "
        f"- {cc['pairs_evaluable']}/{cc['pairs_total']} pairs evaluable, "
        f"{cc['pairs_not_evaluable']} NOT_EVALUABLE."
    )
    if cc["breaches"]:
        for b in cc["breaches"]:
            lines.append(f"  - BREACH {b['pair'][0]} x {b['pair'][1]}: |r|=`{b['abs_r']}`")
    fam = caps["family"]
    lines.append(
        f"- **Family `<= {fam['cap']}` members** ({fam['cap_source']}): `{fam['status']}` "
        f"- {fam['distinct_groups']} distinct families."
    )
    for row in fam["rows"]:
        lines.append(
            f"  - {row['group']}: `{row['count']}` ({row['status']}) "
            f"[{', '.join(row['members'])}]"
        )
    sym = caps["symbol"]
    lines.append(
        f"- **Symbol `<= {sym['cap']}` members** ({sym['cap_source']}): `{sym['status']}` "
        f"- {sym['distinct_groups']} distinct symbols."
    )
    for row in sym["rows"]:
        if row["count"] > 1:
            lines.append(
                f"  - {row['group']}: `{row['count']}` ({row['status']}) "
                f"[{', '.join(row['members'])}]"
            )
    size = caps["book_size"]
    lines.append(
        f"- **Book size `{size['band'][0]}-{size['band'][1]}` EAs** ({size['band_source']}): "
        f"`{size['status']}` - N=`{size['n_eas']}`."
    )
    lines.append("")

    # Risk-budget frame
    lines.append("## 7 - Risk-budget frame (OWNER decision, not applied here)")
    lines.append("")
    lines.append(
        "- No per-sleeve risk weight is proposed or applied by this tool. Weight "
        "allocation and the total-risk level are OWNER acts at runbook steps 6-7 "
        "(`docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` step list section 2; V6 line 219). "
        "The SP-C3 stop-risk concentration budget (symbol 40% / asset-class 60% / "
        "family 50% of the 2.5% stop-risk budget) is evaluated by "
        "`portfolio/concentration_tail.py` against a manifest with weights - out of "
        "scope until an OWNER weight vector exists."
    )
    lines.append(
        "- The DXZ builder default total-risk is `--total-risk-pct 9.75` (runbook V6, "
        "line 219); no change is proposed here."
    )
    lines.append("")

    # Provenance
    lines.append("## 8 - Provenance and read-only statement")
    lines.append("")
    inp = report["inputs"]
    lines.append(f"- Farm DB: `{inp['db_path']}` ({inp['db_access']}).")
    lines.append(f"- Streams: `{inp['stream_source']}` under `{inp['common_dir']}`.")
    lines.append(
        f"- Commission basis: `{inp['commission_basis']}`; degraded: "
        f"`{str(inp['commission_degraded']).lower()}`."
    )
    lines.append(
        "- This report created no book, manifest, sleeve, weight, order file, "
        "live/T_Live state, gate threshold, verdict, trade stream, queue row, or DB "
        "change. Every application step remains a separate OWNER act."
    )
    lines.append("")
    return "\n".join(lines)


# ------------------------------------------------------------------------- CLI
def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--db-path", type=Path, default=DEFAULT_DB_PATH)
    parser.add_argument("--order-dir", type=Path, default=DEFAULT_ORDER_DIR)
    parser.add_argument(
        "--venue", choices=sorted(book_build_guard.SUPPORTED_VENUES), default="both"
    )
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--min-overlap-days", type=int, default=MIN_OVERLAP_DAYS)
    parser.add_argument("--as-of", default=dt.date.today().strftime(_ISO))
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Markdown output path. Default D:/QM/reports/portfolio/q11_fit_<as_of>.md",
    )
    parser.add_argument(
        "--out-json",
        type=Path,
        default=None,
        help="JSON sidecar path. Default: --out path with a .json suffix.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    out_md = args.out or (DEFAULT_OUT_DIR / f"q11_fit_{args.as_of}.md")
    out_json = args.out_json or out_md.with_suffix(".json")

    report = build_report(
        db_path=args.db_path,
        order_dir=args.order_dir,
        venue=args.venue,
        common_dir=args.common_dir,
        min_overlap_days=args.min_overlap_days,
        as_of=args.as_of,
    )
    report["outputs"] = {"markdown": str(out_md), "json": str(out_json)}

    _write(out_md, render_markdown(report))
    _write(out_json, json.dumps(report, indent=2, sort_keys=True) + "\n")

    print(json.dumps({
        "qualified_pairs": report["pool"]["qualified_pairs"],
        "enb_status": report["enb"]["status"],
        "correlation_cap_status": report["cap_checks"]["correlation"]["status"],
        "family_cap_status": report["cap_checks"]["family"]["status"],
        "symbol_cap_status": report["cap_checks"]["symbol"]["status"],
        "book_size_status": report["cap_checks"]["book_size"]["status"],
        "out_md": str(out_md),
        "out_json": str(out_json),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
