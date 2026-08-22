#!/usr/bin/env python3
"""SP-C3 concentration and common-tail diagnostics for dry-run book builders.

The calculations consume only already-sealed trade streams plus repository
registries.  They complement planned stop-risk totals; they never replace those
totals, mutate a book, or authorize a live weight.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))


SCHEMA = "qm.concentration-tail-report/v1"
POLICY_SCHEMA = "qm.concentration-tail-policy/v1"
REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_POLICY_PATH = (
    REPO_ROOT / "tools" / "strategy_farm" / "config" / "concentration_tail_limits.v1.json"
)
DEFAULT_SYMBOL_MATRIX = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
DEFAULT_EA_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
Key = tuple[int, str]


class ConcentrationTailError(ValueError):
    """A required evidence input is absent, ambiguous, or malformed."""


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _binding(path: Path) -> dict[str, Any]:
    resolved = Path(path).expanduser().resolve()
    if not resolved.is_file():
        raise ConcentrationTailError(f"required evidence file missing: {resolved}")
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _finite_positive(value: object, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ConcentrationTailError(f"{label} must be numeric") from exc
    if not math.isfinite(number) or number <= 0:
        raise ConcentrationTailError(f"{label} must be finite and > 0")
    return number


def load_policy(path: Path = DEFAULT_POLICY_PATH) -> tuple[dict[str, Any], dict[str, Any]]:
    binding = _binding(path)
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ConcentrationTailError(f"cannot read concentration policy: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != POLICY_SCHEMA:
        raise ConcentrationTailError(f"policy must declare {POLICY_SCHEMA}")
    if value.get("status") not in {
        "PROPOSED_OWNER_RATIFICATION_REQUIRED",
        "OWNER_RATIFIED",
    }:
        raise ConcentrationTailError("policy status is unsupported")
    if value.get("application_authority") != "OWNER_ONLY":
        raise ConcentrationTailError("policy application authority must be OWNER_ONLY")
    if value.get("deployment_action") != "NONE" or value.get("autotrading_action") != "NONE":
        raise ConcentrationTailError("policy cannot carry deployment or AutoTrading action")
    _finite_positive(value.get("stop_risk_budget_pct"), "stop_risk_budget_pct")
    caps = value.get("caps_percent_of_budget")
    if not isinstance(caps, dict):
        raise ConcentrationTailError("policy caps_percent_of_budget is missing")
    for key in ("symbol", "asset_class", "family", "session_warn", "session"):
        _finite_positive(caps.get(key), f"caps_percent_of_budget.{key}")
    if float(caps["session_warn"]) >= float(caps["session"]):
        raise ConcentrationTailError("session WARN cap must be below session breach cap")
    tail = value.get("tail")
    if not isinstance(tail, dict):
        raise ConcentrationTailError("policy tail block is missing")
    fraction = _finite_positive(tail.get("per_sleeve_worst_fraction"), "tail fraction")
    if fraction >= 1:
        raise ConcentrationTailError("tail fraction must be < 1")
    _finite_positive(tail.get("joint_sleeve_divisor"), "joint_sleeve_divisor")
    _finite_positive(tail.get("venue_daily_loss_limit_pct"), "venue daily loss limit")
    daily_fraction = _finite_positive(
        tail.get("maximum_fraction_of_daily_limit"), "maximum fraction of daily limit"
    )
    if daily_fraction > 1:
        raise ConcentrationTailError("maximum fraction of daily limit must be <= 1")
    _validated_sessions(value.get("sessions_broker_wall"))
    return value, binding


def _validated_sessions(value: object) -> list[tuple[str, int, int]]:
    if not isinstance(value, dict):
        raise ConcentrationTailError("sessions_broker_wall must be an object")
    rows: list[tuple[str, int, int]] = []
    for name, bounds in value.items():
        if not isinstance(bounds, list) or len(bounds) != 2:
            raise ConcentrationTailError(f"session {name} must contain [start,end]")
        try:
            start, end = int(bounds[0]), int(bounds[1])
        except (TypeError, ValueError) as exc:
            raise ConcentrationTailError(f"session {name} bounds must be integers") from exc
        if not 0 <= start < end <= 24:
            raise ConcentrationTailError(f"session {name} bounds are outside 0..24")
        rows.append((str(name), start, end))
    rows.sort(key=lambda row: row[1])
    if not rows or rows[0][1] != 0 or rows[-1][2] != 24:
        raise ConcentrationTailError("session buckets must cover broker hours 0..24")
    if any(rows[index][2] != rows[index + 1][1] for index in range(len(rows) - 1)):
        raise ConcentrationTailError("session buckets must be contiguous and non-overlapping")
    return rows


def _bare_symbol(symbol: str) -> str:
    return str(symbol).strip().upper().removesuffix(".DWX")


def load_asset_classes(path: Path = DEFAULT_SYMBOL_MATRIX) -> tuple[dict[str, str], dict[str, Any]]:
    binding = _binding(path)
    result: dict[str, str] = {}
    with Path(path).open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            symbol = str(row.get("symbol") or "").strip().upper()
            raw = str(row.get("asset_class") or "").strip().lower()
            bare = _bare_symbol(symbol)
            if bare in {"XAUUSD", "XAGUSD"}:
                normalized = "metals"
            elif bare in {"XTIUSD", "XNGUSD", "XBRUSD"}:
                normalized = "energy"
            elif raw == "forex":
                normalized = "fx"
            elif raw in {"indices", "index"}:
                normalized = "indices"
            else:
                normalized = raw or "unknown"
            if symbol:
                result[symbol] = normalized
    return result, binding


def family_fingerprints(
    repo_root: Path,
    keys: Iterable[Key],
    registry_path: Path = DEFAULT_EA_REGISTRY,
) -> dict[Key, str]:
    output: dict[Key, str] = {}
    eas = Path(repo_root) / "framework" / "EAs"
    active_slugs: dict[int, list[str]] = defaultdict(list)
    with Path(registry_path).open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if str(row.get("status") or "").strip().lower() != "active":
                continue
            try:
                ea_id = int(row["ea_id"])
            except (KeyError, TypeError, ValueError):
                continue
            slug = str(row.get("slug") or "").strip()
            if slug:
                active_slugs[ea_id].append(slug)
    for key in keys:
        registry_slugs = sorted(set(active_slugs.get(key[0], [])))
        if len(registry_slugs) == 1:
            slug = registry_slugs[0]
        elif len(registry_slugs) > 1:
            raise ConcentrationTailError(
                f"family fingerprint has multiple active registry slugs for QM5_{key[0]}: {registry_slugs}"
            )
        else:
            matches = sorted(eas.glob(f"QM5_{key[0]}_*"))
            matches = [match for match in matches if match.is_dir()]
            if len(matches) != 1:
                raise ConcentrationTailError(
                    f"family fingerprint requires one active registry slug or EA directory for "
                    f"QM5_{key[0]}, found {len(matches)} directories"
                )
            parts = matches[0].name.split("_", 2)
            if len(parts) != 3 or not parts[2]:
                raise ConcentrationTailError(f"EA directory has no slug for QM5_{key[0]}")
            slug = parts[2]
        family = slug.split("-", 1)[0].strip().lower()
        if not family:
            raise ConcentrationTailError(f"EA slug has no family stem for QM5_{key[0]}")
        output[key] = family
    return output


def dominant_sessions(
    streams: Mapping[Key, Sequence[Any]],
    keys: Iterable[Key],
    session_policy: object,
) -> dict[Key, str]:
    buckets = _validated_sessions(session_policy)
    output: dict[Key, str] = {}
    for key in keys:
        trades = streams.get(key)
        if not trades:
            raise ConcentrationTailError(f"session evidence stream missing/empty for {key}")
        counts: Counter[str] = Counter()
        missing = 0
        for trade in trades:
            raw = getattr(trade, "entry_time", None)
            if raw is None:
                missing += 1
                continue
            try:
                # MT5 stream entry_time is the broker-wall epoch. Interpreting
                # it on the UTC clock recovers the encoded GMT+2/+3 wall hour.
                hour = dt.datetime.fromtimestamp(int(raw), tz=dt.timezone.utc).hour
            except (OSError, OverflowError, TypeError, ValueError):
                missing += 1
                continue
            name = next((name for name, start, end in buckets if start <= hour < end), None)
            if name is None:
                missing += 1
            else:
                counts[name] += 1
        if not counts:
            raise ConcentrationTailError(f"no usable entry_time evidence for session: {key}")
        maximum = max(counts.values())
        leaders = sorted(name for name, count in counts.items() if count == maximum)
        if len(leaders) != 1:
            raise ConcentrationTailError(f"dominant session tie for {key}: {leaders}")
        output[key] = leaders[0]
    return output


def _quantile(values: Sequence[float], probability: float) -> float:
    if not values:
        raise ConcentrationTailError("quantile requires observations")
    ordered = sorted(float(value) for value in values)
    position = probability * (len(ordered) - 1)
    lower = int(math.floor(position))
    upper = int(math.ceil(position))
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def _dimension(
    name: str,
    groups: Mapping[str, float],
    *,
    budget: float,
    cap_percent: float,
    warn_percent: float | None = None,
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    cap_value = budget * cap_percent / 100.0
    warn_value = budget * warn_percent / 100.0 if warn_percent is not None else None
    for key, raw_value in sorted(groups.items()):
        value = float(raw_value)
        status = "BREACH" if value > cap_value + 1e-12 else "PASS"
        if status == "PASS" and warn_value is not None and value > warn_value + 1e-12:
            status = "WARN"
        rows.append({
            "key": key,
            "stop_risk_pct": round(value, 8),
            "percent_of_stop_risk_budget": round(value / budget * 100.0, 8),
            "cap_percent_of_budget": cap_percent,
            "cap_stop_risk_pct": round(cap_value, 8),
            "warn_percent_of_budget": warn_percent,
            "status": status,
        })
    return {
        "dimension": name,
        "status": "BREACH" if any(row["status"] == "BREACH" for row in rows) else (
            "WARN" if any(row["status"] == "WARN" for row in rows) else "PASS"
        ),
        "rows": rows,
    }


def unknown_report(
    reason: str,
    *,
    policy_path: Path = DEFAULT_POLICY_PATH,
) -> dict[str, Any]:
    try:
        policy, binding = load_policy(policy_path)
        policy_status = policy["status"]
    except ConcentrationTailError as exc:
        binding = {"path": str(policy_path), "sha256": None, "size_bytes": None}
        policy_status = "UNKNOWN"
        reason = f"{reason}; policy_error={exc}"
    return {
        "schema": SCHEMA,
        "status": "UNKNOWN",
        "passed": False,
        "builder_eligible": False,
        "policy_status": policy_status,
        "policy_binding": binding,
        "reason": reason,
        "dimensions": {},
        "tail": {"status": "UNKNOWN"},
        "risk_proxies": {
            "historical_daily_var_95_loss_pct": None,
            "d_leverage_like_stop_risk_to_var95_ratio": None,
            "classification": "D_LEVERAGE_LIKE_PROXY_NOT_PROVIDER_METRIC",
        },
        "concentration_reject": [{"dim": "data", "reason": reason}],
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
    }


def evaluate(
    *,
    keys: Sequence[Key],
    weights: Mapping[Key, float],
    dates: Sequence[Any],
    matrix: Sequence[Sequence[float]],
    streams: Mapping[Key, Sequence[Any]],
    starting_capital: float,
    policy_path: Path = DEFAULT_POLICY_PATH,
    symbol_matrix_path: Path = DEFAULT_SYMBOL_MATRIX,
    repo_root: Path = REPO_ROOT,
    asset_by_key: Mapping[Key, str] | None = None,
    family_by_key: Mapping[Key, str] | None = None,
    session_by_key: Mapping[Key, str] | None = None,
) -> dict[str, Any]:
    """Evaluate the five designed dimensions and VaR/D-like visibility metrics."""
    if not keys:
        raise ConcentrationTailError("book has no sleeves")
    if len(matrix) != len(dates) or not dates:
        raise ConcentrationTailError("daily P/L matrix and date grid are empty or inconsistent")
    if any(len(row) != len(keys) for row in matrix):
        raise ConcentrationTailError("daily P/L matrix width does not match sleeve keys")
    capital = _finite_positive(starting_capital, "starting_capital")
    policy, policy_binding = load_policy(policy_path)
    budget = _finite_positive(policy["stop_risk_budget_pct"], "stop_risk_budget_pct")
    normalized_weights: dict[Key, float] = {}
    for key in keys:
        if key not in weights:
            raise ConcentrationTailError(f"planned stop-risk weight missing for {key}")
        normalized_weights[key] = _finite_positive(weights[key], f"planned stop risk {key}")

    if asset_by_key is None:
        assets, symbol_binding = load_asset_classes(symbol_matrix_path)
        asset_by_key = {}
        for key in keys:
            asset = assets.get(str(key[1]).upper())
            if not asset or asset == "unknown":
                raise ConcentrationTailError(f"asset class unavailable for {key}")
            asset_by_key[key] = asset
    else:
        symbol_binding = {"path": "fixture_override", "sha256": None, "size_bytes": None}
    family_override = family_by_key is not None
    family_by_key = dict(family_by_key or family_fingerprints(repo_root, keys))
    session_by_key = dict(
        session_by_key
        or dominant_sessions(streams, keys, policy.get("sessions_broker_wall"))
    )
    for label, mapping in (
        ("asset", asset_by_key), ("family", family_by_key), ("session", session_by_key)
    ):
        missing = [key for key in keys if not str(mapping.get(key) or "").strip()]
        if missing:
            raise ConcentrationTailError(f"{label} classification missing for {missing}")

    symbol_groups: dict[str, float] = defaultdict(float)
    asset_groups: dict[str, float] = defaultdict(float)
    family_groups: dict[str, float] = defaultdict(float)
    session_groups: dict[str, float] = defaultdict(float)
    for key in keys:
        weight = normalized_weights[key]
        symbol_groups[str(key[1]).upper()] += weight
        asset_groups[str(asset_by_key[key])] += weight
        family_groups[str(family_by_key[key])] += weight
        session_groups[str(session_by_key[key])] += weight

    caps = policy["caps_percent_of_budget"]
    dimensions = {
        "symbol": _dimension("symbol", symbol_groups, budget=budget, cap_percent=float(caps["symbol"])),
        "asset_class": _dimension(
            "asset_class", asset_groups, budget=budget, cap_percent=float(caps["asset_class"])
        ),
        "family": _dimension("family", family_groups, budget=budget, cap_percent=float(caps["family"])),
        "session": _dimension(
            "session",
            session_groups,
            budget=budget,
            cap_percent=float(caps["session"]),
            warn_percent=float(caps["session_warn"]),
        ),
    }

    # D5: take exactly ceil(5% * N) worst observations per sleeve. Exact-count
    # selection avoids marking every zero day as tail for sparse strategies.
    tail_policy = policy["tail"]
    worst_fraction = float(tail_policy["per_sleeve_worst_fraction"])
    tail_n = max(1, math.ceil(len(dates) * worst_fraction))
    tail_membership: list[set[int]] = []
    for column in range(len(keys)):
        ranked = sorted(range(len(dates)), key=lambda row: (float(matrix[row][column]), str(dates[row])))
        tail_membership.append(set(ranked[:tail_n]))
    joint_k = math.ceil(len(keys) / int(tail_policy["joint_sleeve_divisor"]))
    portfolio_daily: list[float] = []
    joint_rows: list[dict[str, Any]] = []
    for row_index, day in enumerate(dates):
        pnl = sum(
            float(matrix[row_index][column]) * normalized_weights[key]
            for column, key in enumerate(keys)
        )
        portfolio_daily.append(pnl)
        tail_keys = [
            f"{key[0]}:{key[1]}"
            for column, key in enumerate(keys)
            if row_index in tail_membership[column]
        ]
        if len(tail_keys) >= joint_k:
            joint_rows.append({
                "date": str(day),
                "tail_sleeve_count": len(tail_keys),
                "tail_sleeves": tail_keys,
                "portfolio_pnl": round(pnl, 8),
                "portfolio_loss_pct": round(max(0.0, -pnl / capital * 100.0), 8),
            })
    worst_joint = max((float(row["portfolio_loss_pct"]) for row in joint_rows), default=0.0)
    tail_cap = (
        float(tail_policy["venue_daily_loss_limit_pct"])
        * float(tail_policy["maximum_fraction_of_daily_limit"])
    )
    tail_status = "PASS" if worst_joint <= tail_cap + 1e-12 else "BREACH"
    tail = {
        "status": tail_status,
        "per_sleeve_worst_fraction": worst_fraction,
        "per_sleeve_tail_observations": tail_n,
        "joint_k": joint_k,
        "joint_tail_day_count": len(joint_rows),
        "worst_joint_day_loss_pct": round(worst_joint, 8),
        "cap_loss_pct": round(tail_cap, 8),
        "joint_tail_days": joint_rows,
    }

    var95 = max(0.0, -_quantile(portfolio_daily, 0.05) / capital * 100.0)
    total_stop_risk = sum(normalized_weights.values())
    d_like = total_stop_risk / var95 if var95 > 0 else None
    risk_proxies = {
        "historical_daily_var_95_loss_pct": round(var95, 8),
        "daily_var_basis": "weighted_synchronized_OOS_close_PnL_5th_percentile",
        "d_leverage_like_stop_risk_to_var95_ratio": round(d_like, 8) if d_like is not None else None,
        "d_leverage_like_formula": "sum_planned_stop_risk_pct / historical_daily_var95_loss_pct",
        "classification": "D_LEVERAGE_LIKE_PROXY_NOT_PROVIDER_METRIC",
        "stop_risk_sum_retained_pct": round(total_stop_risk, 8),
        "stop_risk_budget_pct": round(budget, 8),
    }

    total_for_share = total_stop_risk
    metals_energy = float(asset_groups.get("metals", 0.0)) + float(asset_groups.get("energy", 0.0))
    xau = float(symbol_groups.get("XAUUSD.DWX", 0.0))
    highlights = {
        "metals_energy_stop_risk_pct": round(metals_energy, 8),
        "metals_energy_pct_of_total_book_risk": round(metals_energy / total_for_share * 100.0, 8),
        "xauusd_stop_risk_pct": round(xau, 8),
        "xauusd_pct_of_total_book_risk": round(xau / total_for_share * 100.0, 8),
    }

    rejects: list[dict[str, Any]] = []
    for dimension, block in dimensions.items():
        for row in block["rows"]:
            if row["status"] == "BREACH":
                rejects.append({
                    "dim": dimension,
                    "key": row["key"],
                    "value": row["stop_risk_pct"],
                    "cap": row["cap_stop_risk_pct"],
                    "unit": "planned_stop_risk_pct",
                })
    if tail_status == "BREACH":
        rejects.append({
            "dim": "joint_tail",
            "key": "worst_joint_day_loss_pct",
            "value": round(worst_joint, 8),
            "cap": round(tail_cap, 8),
            "unit": "starting_capital_pct",
        })
    passed = not rejects
    ratified = policy.get("status") == "OWNER_RATIFIED"
    if rejects:
        status = "BREACH"
    elif not ratified:
        status = "POLICY_UNRATIFIED"
    else:
        status = "PASS"
    return {
        "schema": SCHEMA,
        "status": status,
        "passed": passed,
        "builder_eligible": bool(passed and ratified),
        "policy_status": policy["status"],
        "policy_binding": policy_binding,
        "symbol_matrix_binding": symbol_binding,
        "family_registry_binding": (
            {"path": "fixture_override", "sha256": None, "size_bytes": None}
            if family_override
            else _binding(DEFAULT_EA_REGISTRY)
        ),
        "dimensions": dimensions,
        "tail": tail,
        "risk_proxies": risk_proxies,
        "highlights": highlights,
        "concentration_reject": rejects,
        "classification_basis": {
            "asset_class": "dwx_symbol_matrix.csv; commodities split by canonical metal/energy symbols",
            "family": policy.get("family_fallback"),
            "session": "dominant entry_time histogram on MT5 broker-wall hour",
        },
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
    }


def markdown_panel(report: Mapping[str, Any]) -> str:
    lines = [
        "## SP-C3 concentration and common-tail panel",
        "",
        f"- Status: `{report.get('status')}`; policy: `{report.get('policy_status')}`; "
        f"builder eligible: `{str(bool(report.get('builder_eligible'))).lower()}`.",
    ]
    if report.get("status") == "UNKNOWN":
        lines.append(f"- Data status: `{report.get('reason')}`")
        return "\n".join(lines)
    proxies = report.get("risk_proxies") or {}
    highlights = report.get("highlights") or {}
    lines.extend([
        f"- Stop-risk sum: `{proxies.get('stop_risk_sum_retained_pct')}%`; historical daily VaR95: "
        f"`{proxies.get('historical_daily_var_95_loss_pct')}%`; D-Leverage-like proxy: "
        f"`{proxies.get('d_leverage_like_stop_risk_to_var95_ratio')}` (not a provider metric).",
        f"- Metals+energy: `{highlights.get('metals_energy_pct_of_total_book_risk')}%` of book risk; "
        f"XAUUSD: `{highlights.get('xauusd_pct_of_total_book_risk')}%`.",
        "",
        "| Dimension | Key | Stop risk | % of B | Cap | Status |",
        "|---|---|---:|---:|---:|---|",
    ])
    for name in ("symbol", "asset_class", "family", "session"):
        for row in ((report.get("dimensions") or {}).get(name) or {}).get("rows", []):
            lines.append(
                f"| {name} | {row['key']} | {row['stop_risk_pct']:.4f}% | "
                f"{row['percent_of_stop_risk_budget']:.2f}% | "
                f"{row['cap_stop_risk_pct']:.4f}% | {row['status']} |"
            )
    tail = report.get("tail") or {}
    lines.extend([
        "",
        f"- Joint tail days: `{tail.get('joint_tail_day_count')}` (K=`{tail.get('joint_k')}`); "
        f"worst joint day loss `{tail.get('worst_joint_day_loss_pct')}%` vs cap "
        f"`{tail.get('cap_loss_pct')}%` => `{tail.get('status')}`.",
    ])
    rejects = report.get("concentration_reject") or []
    if rejects:
        lines.append(f"- Machine-readable rejection count: `{len(rejects)}`.")
    return "\n".join(lines)


def evaluate_manifest(
    *,
    manifest_path: Path,
    stream_root: Path,
    starting_capital: float,
    policy_path: Path = DEFAULT_POLICY_PATH,
    symbol_matrix_path: Path = DEFAULT_SYMBOL_MATRIX,
) -> dict[str, Any]:
    """Reproducible read-only report for an existing manifest and stream bundle."""
    from tools.strategy_farm.portfolio.portfolio_common import align, load_streams, to_daily_pnl

    manifest_binding = _binding(manifest_path)
    try:
        manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ConcentrationTailError(f"cannot read book manifest: {exc}") from exc
    rows = manifest.get("sleeves") if isinstance(manifest, dict) else None
    if not isinstance(rows, list) or not rows:
        raise ConcentrationTailError("book manifest has no sleeves list")
    keys: list[Key] = []
    weights: dict[Key, float] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ConcentrationTailError(f"manifest sleeve {index} is not an object")
        try:
            ea_id = int(str(row["ea_id"]).upper().replace("QM5_", ""))
            symbol = str(row["symbol"]).strip().upper()
        except (KeyError, TypeError, ValueError) as exc:
            raise ConcentrationTailError(f"manifest sleeve {index} lacks ea_id/symbol") from exc
        if "." not in symbol:
            symbol += ".DWX"
        key = (ea_id, symbol)
        if key in weights:
            raise ConcentrationTailError(f"duplicate manifest sleeve: {key}")
        raw_weight = row.get("risk_percent", row.get("weight"))
        weights[key] = _finite_positive(raw_weight, f"manifest sleeve {index} risk weight")
        keys.append(key)
    streams = load_streams(Path(stream_root), candidates=keys)
    missing = sorted(set(keys) - set(streams))
    if missing:
        raise ConcentrationTailError(f"sealed stream bundle is missing manifest sleeves: {missing}")
    daily = {key: to_daily_pnl(streams[key]) for key in keys}
    empty = [key for key, values in daily.items() if not values]
    if empty:
        raise ConcentrationTailError(f"sealed stream bundle contains empty series: {empty}")
    aligned_keys, dates, matrix = align(daily)
    report = evaluate(
        keys=aligned_keys,
        weights=weights,
        dates=dates,
        matrix=matrix,
        streams=streams,
        starting_capital=starting_capital,
        policy_path=policy_path,
        symbol_matrix_path=symbol_matrix_path,
    )
    report["evaluation_input"] = {
        "manifest": manifest_binding,
        "manifest_book": manifest.get("book"),
        "stream_root": str(Path(stream_root).resolve()),
        "streams_loaded": len(streams),
        "date_start": str(dates[0]),
        "date_end": str(dates[-1]),
        "calendar_days": len(dates),
        "starting_capital": float(starting_capital),
    }
    return report


def _atomic_write(path: Path, text: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(text, encoding="utf-8")
    os.replace(temp, path)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--stream-root", type=Path, required=True)
    parser.add_argument("--starting-capital", type=float, default=100_000.0)
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY_PATH)
    parser.add_argument("--symbol-matrix", type=Path, default=DEFAULT_SYMBOL_MATRIX)
    parser.add_argument("--out-json", type=Path)
    parser.add_argument("--out-md", type=Path)
    args = parser.parse_args(argv)
    try:
        report = evaluate_manifest(
            manifest_path=args.manifest,
            stream_root=args.stream_root,
            starting_capital=args.starting_capital,
            policy_path=args.policy,
            symbol_matrix_path=args.symbol_matrix,
        )
    except ConcentrationTailError as exc:
        print(json.dumps({"status": "UNKNOWN", "error": str(exc)}, indent=2), file=sys.stderr)
        return 2
    if args.out_json:
        _atomic_write(args.out_json, json.dumps(report, indent=2, sort_keys=True) + "\n")
    if args.out_md:
        _atomic_write(args.out_md, markdown_panel(report) + "\n")
    print(json.dumps({
        "status": report["status"],
        "builder_eligible": report["builder_eligible"],
        "reject_count": len(report["concentration_reject"]),
        "highlights": report["highlights"],
        "out_json": str(args.out_json) if args.out_json else None,
        "out_md": str(args.out_md) if args.out_md else None,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
