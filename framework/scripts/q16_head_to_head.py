#!/usr/bin/env python3
"""DL-084 Q16 sealed parent/challenger head-to-head evaluator.

Inputs are explicit, SHA-bound opt-card/lineage/stream artifacts. Only the
pre-registered anchored-Q04 OOS folds and post-DEV holdout are read. Raw trade
profit and swap are repriced with ``venue_cost_model.json`` at RISK_FIXED=1000.
The evaluator is analytic-only: no terminal, DB, queue, or live surface access.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm.portfolio.book_builder_common import (
    aligned_matrix,
    book_metrics,
    capped_inverse_vol,
    canonical_json,
    portfolio_daily,
    sha256_bytes,
    sha256_file,
    write_json,
    write_text,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_COST_MODEL = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"
RESULT_SCHEMA = "qm.q16-head-to-head-result/v1"
LINEAGE_SCHEMA = "qm.q16-lineage/v1"
OPT_CARD_SCHEMA = "qm.opt-card/v1"
TRIAL_LEDGER_SCHEMA = "qm.opt-trial-ledger/v1"
FROZEN_BUNDLE_SCHEMA = "qm.frozen-trade-bundle/v1"
RISK_FIXED = 1000.0
RISK_PERCENT = 0.0
STARTING_CAPITAL = 100_000.0
CORR_ADMIT_MAX = 0.15
CORR_REJECT_MIN = 0.40
DSHARPE_EPS = 0.020
DMAXDD_EPS_PCT = 0.05
MIN_CONTRIBUTION_ANN_PCT = 0.06
TOTAL_RISK_PCT = 9.75
SLEEVE_CAP_PCT = 1.0

Key = tuple[int, str]


class Q16Error(ValueError):
    """A sealed Q16 comparison cannot be proved from the supplied artifacts."""


def _load_json(path: Path, label: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Q16Error(f"{label} is missing or invalid JSON: {path}: {exc}") from exc


def _binding(path: Path) -> dict[str, Any]:
    target = path.expanduser().resolve()
    if not target.is_file():
        raise Q16Error(f"bound file is missing: {target}")
    return {"path": str(target), "sha256": sha256_file(target), "size_bytes": target.stat().st_size}


def _resolve_bound_file(raw: Any, label: str, *, base: Path | None = None) -> tuple[Path, dict[str, Any]]:
    if not isinstance(raw, Mapping):
        raise Q16Error(f"{label} binding must be an object")
    token = raw.get("path")
    expected = str(raw.get("sha256") or "").lower()
    if not isinstance(token, str) or not token.strip() or not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise Q16Error(f"{label} binding requires path and lowercase SHA-256")
    path = Path(token)
    if not path.is_absolute():
        path = (base or REPO_ROOT) / path
    actual = _binding(path)
    if actual["sha256"] != expected:
        raise Q16Error(f"{label} SHA-256 mismatch: {actual['sha256']} != {expected}")
    return path.resolve(), actual


def _key(row: Mapping[str, Any], label: str) -> Key:
    try:
        ea = int(str(row["ea_id"]).upper().replace("QM5_", ""))
        symbol = str(row["symbol"]).strip().upper()
    except (KeyError, TypeError, ValueError) as exc:
        raise Q16Error(f"{label} has invalid ea_id/symbol") from exc
    if "." not in symbol:
        symbol += ".DWX"
    return ea, symbol


def _is_mutable_mt5_storage(path: Path) -> bool:
    """Identify terminal-owned MT5 storage without rejecting all AppData paths."""
    lowered = "\\" + str(path.resolve()).lower().replace("/", "\\").strip("\\") + "\\"
    return any(pattern in lowered for pattern in (
        "\\metaquotes\\terminal\\",
        "\\terminal\\common\\files\\",
        "\\mql5\\files\\",
    ))


def _set_risk_contract(path: Path, label: str) -> None:
    text = path.read_text(encoding="utf-8-sig")
    values: dict[str, float] = {}
    for name in ("RISK_FIXED", "RISK_PERCENT"):
        match = re.search(rf"(?mi)^\s*{name}\s*=\s*([-+0-9.eE]+)\s*$", text)
        if not match:
            raise Q16Error(f"{label} setfile lacks {name}")
        values[name] = float(match.group(1))
    if values != {"RISK_FIXED": RISK_FIXED, "RISK_PERCENT": RISK_PERCENT}:
        raise Q16Error(f"{label} requires RISK_FIXED=1000 and RISK_PERCENT=0, got {values}")


def _parse_day(value: Any, label: str) -> dt.date:
    try:
        return dt.date.fromisoformat(str(value))
    except ValueError as exc:
        raise Q16Error(f"{label} must be an ISO date") from exc


def load_windows(card: Mapping[str, Any]) -> list[dict[str, Any]]:
    rows = card.get("comparison_windows")
    if not isinstance(rows, list) or not rows:
        raise Q16Error("opt-card comparison_windows must be a non-empty list")
    result: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise Q16Error(f"comparison_windows[{index}] must be an object")
        window_id = str(row.get("id") or "")
        kind = str(row.get("kind") or "").upper()
        if not window_id or window_id in seen_ids:
            raise Q16Error("comparison window ids must be non-empty and unique")
        if kind not in {"Q04_ANCHORED_OOS", "POST_DEV_HOLDOUT"}:
            raise Q16Error(f"unsupported comparison window kind: {kind}")
        start = _parse_day(row.get("start"), f"window {window_id}.start")
        end = _parse_day(row.get("end"), f"window {window_id}.end")
        if start > end:
            raise Q16Error(f"comparison window {window_id} starts after it ends")
        seen_ids.add(window_id)
        result.append({"id": window_id, "kind": kind, "start": start, "end": end})
    if sum(row["kind"] == "Q04_ANCHORED_OOS" for row in result) < 3:
        raise Q16Error("Q16 requires at least three anchored Q04 OOS folds")
    if not any(row["kind"] == "POST_DEV_HOLDOUT" for row in result):
        raise Q16Error("Q16 requires a post-DEV holdout window")
    ordered = sorted(result, key=lambda row: (row["start"], row["end"], row["id"]))
    for left, right in zip(ordered, ordered[1:]):
        if right["start"] <= left["end"]:
            raise Q16Error(f"comparison windows overlap: {left['id']} and {right['id']}")
    return result


class VenueCostModel:
    """Worst of the declared real DXZ and FTMO round-trip commission models."""

    def __init__(self, path: Path) -> None:
        payload = _load_json(path, "venue cost model")
        if not isinstance(payload, Mapping) or not isinstance(payload.get("symbols"), Mapping):
            raise Q16Error("venue_cost_model.json has no symbols map")
        self.binding = _binding(path)
        self.class_model = payload.get("canonical_engine", {}).get("class_model", {})
        self.by_symbol: dict[str, Mapping[str, Any]] = {}
        for row in payload["symbols"].values():
            if isinstance(row, Mapping) and row.get("dwx_symbol") and "alias_of" not in row:
                self.by_symbol[str(row["dwx_symbol"]).upper()] = row

    @staticmethod
    def _venue_cost(model: Mapping[str, Any], *, volume: float, notional: float | None) -> float:
        name = str(model.get("commission_model") or "")
        if name == "commission_free":
            return 0.0
        if name.startswith("pct_notional"):
            if notional is None:
                raise Q16Error(f"notional is required by venue commission model {name}")
            return 0.00005 * notional
        for key in ("commission_rt_per_lot_usd", "commission_rt_per_lot_usd_indicative"):
            value = model.get(key)
            if value is not None:
                return float(value) * volume
        raise Q16Error(f"venue commission model is unresolved: {name or 'missing'}")

    def round_trip(self, symbol: str, volume: float, notional: float | None) -> float:
        row = self.by_symbol.get(symbol.upper())
        if row is None:
            raise Q16Error(f"venue cost model has no exact symbol row for {symbol}")
        costs = []
        for venue in ("dxz", "ftmo"):
            raw = row.get(venue)
            if not isinstance(raw, Mapping):
                raise Q16Error(f"venue cost model lacks {venue} row for {symbol}")
            try:
                costs.append(self._venue_cost(raw, volume=volume, notional=notional))
            except Q16Error:
                asset = str(row.get("asset_class") or "")
                fallback = self.class_model.get(asset) if isinstance(self.class_model, Mapping) else None
                if not isinstance(fallback, Mapping):
                    raise
                pct = float(fallback.get("pct_rate_rt", 0.0)) * float(notional or 0.0)
                flat = float(fallback.get("flat_per_lot_rt", 0.0)) * volume
                costs.append(max(pct, flat))
        cost = max(costs)
        if not math.isfinite(cost) or cost < 0:
            raise Q16Error(f"invalid venue commission for {symbol}")
        return cost


def load_lineage(path: Path, expected_role: str) -> dict[str, Any]:
    payload = _load_json(path, f"{expected_role.lower()} lineage")
    if not isinstance(payload, Mapping) or payload.get("schema") != LINEAGE_SCHEMA:
        raise Q16Error(f"{expected_role} lineage schema must be {LINEAGE_SCHEMA}")
    if str(payload.get("role") or "").upper() != expected_role:
        raise Q16Error(f"lineage role is not {expected_role}")
    key = _key(payload, f"{expected_role} lineage")
    binary_path, binary = _resolve_bound_file(payload.get("binary"), f"{expected_role} binary", base=path.parent)
    setfile_path, setfile = _resolve_bound_file(payload.get("setfile"), f"{expected_role} setfile", base=path.parent)
    del binary_path
    _set_risk_contract(setfile_path, expected_role)
    stream_raw = payload.get("stream")
    stream_path, stream = _resolve_bound_file(stream_raw, f"{expected_role} stream", base=path.parent)
    if not isinstance(stream_raw, Mapping) or stream_raw.get("frozen") is not True:
        raise Q16Error(f"{expected_role} stream must declare frozen=true")
    if _is_mutable_mt5_storage(stream_path):
        raise Q16Error(f"{expected_role} stream resolves to mutable MT5 storage")
    try:
        stream_risk_fixed = float(stream_raw.get("risk_fixed"))
        stream_risk_percent = float(stream_raw.get("risk_percent"))
    except (TypeError, ValueError) as exc:
        raise Q16Error(f"{expected_role} stream lacks risk scale") from exc
    if stream_risk_fixed != RISK_FIXED or stream_risk_percent != RISK_PERCENT:
        raise Q16Error(f"{expected_role} stream is not RISK_FIXED=1000/RISK_PERCENT=0")
    q10 = payload.get("q10")
    if not isinstance(q10, Mapping) or str(q10.get("verdict") or "").upper() != "PASS":
        raise Q16Error(f"{expected_role} lineage does not hold Q10 PASS")
    q10_path, q10_evidence = _resolve_bound_file(q10.get("evidence"), f"{expected_role} Q10 evidence", base=path.parent)
    q10_payload = _load_json(q10_path, f"{expected_role} Q10 evidence")
    if (
        not isinstance(q10_payload, Mapping)
        or str(q10_payload.get("phase") or "").upper() != "Q10"
        or str(q10_payload.get("verdict") or "").upper() != "PASS"
    ):
        raise Q16Error(f"{expected_role} bound Q10 evidence is not a Q10 PASS artifact")
    result = {
        "key": key,
        "input": _binding(path),
        "binary": binary,
        "setfile": setfile,
        "stream": stream,
        "stream_path": stream_path,
        "stream_declared_count": stream_raw.get("trade_count"),
        "q10": {"verdict": "PASS", "evidence": q10_evidence},
        "raw": payload,
    }
    return result


def validate_trial_ledger(card: Mapping[str, Any], ledger_path: Path, challenger: Mapping[str, Any]) -> dict[str, Any]:
    ledger = _load_json(ledger_path, "trial ledger")
    if not isinstance(ledger, Mapping) or ledger.get("schema") != TRIAL_LEDGER_SCHEMA:
        raise Q16Error(f"trial ledger schema must be {TRIAL_LEDGER_SCHEMA}")
    if str(ledger.get("card_id")) != str(card.get("card_id")):
        raise Q16Error("trial ledger card_id does not match opt-card")
    declared_path = card.get("trial_ledger_path")
    if declared_path and Path(str(declared_path)).resolve() != ledger_path.resolve():
        raise Q16Error("trial ledger path does not match opt-card")
    trials = ledger.get("trials")
    if not isinstance(trials, list):
        raise Q16Error("trial ledger trials must be a list")
    try:
        declared = int(ledger.get("declared_trial_count"))
    except (TypeError, ValueError) as exc:
        raise Q16Error("trial ledger declared_trial_count must be an integer") from exc
    if declared < 0 or declared != len(trials):
        raise Q16Error(f"trial ledger undercount: declared={declared}, rows={len(trials)}")
    ids = [str(row.get("trial_id") or "") for row in trials if isinstance(row, Mapping)]
    if len(ids) != len(trials) or any(not item for item in ids) or len(set(ids)) != len(ids):
        raise Q16Error("trial ledger requires one unique non-empty trial_id per row")
    refs: dict[str, Any] = {}
    for phase in ("q07", "q08"):
        raw = challenger["raw"].get(phase)
        if not isinstance(raw, Mapping):
            raise Q16Error(f"challenger lineage lacks {phase.upper()} trial-count evidence")
        try:
            referenced = int(raw.get("trial_ledger_declared_count"))
            observed = int(raw.get("observed_trial_count"))
        except (TypeError, ValueError) as exc:
            raise Q16Error(f"challenger {phase.upper()} trial counts are missing") from exc
        if referenced != declared or observed > declared:
            raise Q16Error(
                f"trial ledger undercount at {phase.upper()}: ledger={declared}, "
                f"referenced={referenced}, observed={observed}"
            )
        evidence_path, evidence = _resolve_bound_file(raw.get("evidence"), f"challenger {phase.upper()} evidence", base=Path(challenger["input"]["path"]).parent)
        evidence_payload = _load_json(evidence_path, f"challenger {phase.upper()} evidence")
        if not isinstance(evidence_payload, Mapping):
            raise Q16Error(f"challenger {phase.upper()} evidence is not an object")
        evidence_trial = evidence_payload.get("trial_ledger", evidence_payload)
        if not isinstance(evidence_trial, Mapping):
            raise Q16Error(f"challenger {phase.upper()} evidence lacks trial_ledger reference")
        try:
            evidence_declared = int(evidence_trial.get("declared_trial_count"))
            evidence_observed = int(evidence_trial.get("observed_trial_count"))
        except (TypeError, ValueError) as exc:
            raise Q16Error(f"challenger {phase.upper()} evidence lacks embedded trial counts") from exc
        if evidence_declared != declared or evidence_observed != observed:
            raise Q16Error(f"challenger {phase.upper()} evidence trial counts differ from lineage/ledger")
        refs[phase.upper()] = {"referenced": referenced, "observed": observed, "evidence": evidence}
    return {"input": _binding(ledger_path), "declared_trial_count": declared, "phase_references": refs}


def _window_for_trade(entry: dt.date, close: dt.date, windows: list[dict[str, Any]]) -> str | None:
    matches = [row["id"] for row in windows if row["start"] <= entry <= close <= row["end"]]
    if len(matches) > 1:
        raise Q16Error("a trade matched multiple pre-registered windows")
    return matches[0] if matches else None


def load_repriced_stream(
    path: Path,
    *,
    expected_key: Key,
    expected_count: Any,
    windows: list[dict[str, Any]],
    costs: VenueCostModel,
) -> tuple[dict[dt.date, float], dict[str, Any]]:
    daily: dict[dt.date, float] = {}
    included = excluded = raw_count = 0
    cost_total = 0.0
    by_window = {row["id"]: {"trades": 0, "net": 0.0} for row in windows}
    with path.open(encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, start=1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise Q16Error(f"invalid stream JSON at {path}:{line_no}") from exc
            if row.get("event") != "TRADE_CLOSED":
                continue
            raw_count += 1
            if row.get("entry_time") is None:
                raise Q16Error(f"stream lacks entry_time at {path}:{line_no}")
            symbol = str(row.get("symbol") or expected_key[1]).upper()
            if symbol != expected_key[1]:
                raise Q16Error(f"stream symbol mismatch at {path}:{line_no}: {symbol}")
            if row.get("ea_id") is not None:
                try:
                    row_ea = int(str(row["ea_id"]).upper().replace("QM5_", ""))
                except ValueError as exc:
                    raise Q16Error(f"stream ea_id invalid at {path}:{line_no}") from exc
                if row_ea != expected_key[0]:
                    raise Q16Error(f"stream ea_id mismatch at {path}:{line_no}: {row_ea}")
            entry = dt.datetime.fromtimestamp(int(row["entry_time"]), tz=dt.UTC).date()
            close = dt.datetime.fromtimestamp(int(row["time"]), tz=dt.UTC).date()
            window_id = _window_for_trade(entry, close, windows)
            if window_id is None:
                excluded += 1
                continue
            try:
                profit = float(row["profit"])
                swap = float(row.get("swap", 0.0))
                volume = float(row["volume"])
                notional = None if row.get("notional") is None else float(row["notional"])
            except (KeyError, TypeError, ValueError) as exc:
                raise Q16Error(f"stream trade fields invalid at {path}:{line_no}") from exc
            commission = costs.round_trip(symbol, volume, notional)
            net = profit + swap - commission
            if not math.isfinite(net):
                raise Q16Error(f"non-finite repriced trade at {path}:{line_no}")
            daily[close] = daily.get(close, 0.0) + net
            included += 1
            cost_total += commission
            by_window[window_id]["trades"] += 1
            by_window[window_id]["net"] += net
    if expected_count is not None and int(expected_count) != raw_count:
        raise Q16Error(f"stream trade_count mismatch for {path}: {raw_count} != {expected_count}")
    if not daily:
        raise Q16Error(f"stream has no trades wholly inside the pre-registered windows: {path}")
    return daily, {
        "raw_trade_count": raw_count,
        "included_trade_count": included,
        "excluded_trade_count": excluded,
        "venue_commission_total": round(cost_total, 6),
        "windows": by_window,
    }


def _profit_factor(values: Iterable[float]) -> float | None:
    vals = list(values)
    gross_profit = sum(value for value in vals if value > 0)
    gross_loss = abs(sum(value for value in vals if value < 0))
    if gross_loss == 0:
        return None if gross_profit == 0 else 999.0
    return gross_profit / gross_loss


def standalone_metrics(daily: Mapping[dt.date, float]) -> dict[str, Any]:
    ordered = [daily[day] for day in sorted(daily)]
    metrics = book_metrics(ordered, 1, STARTING_CAPITAL)
    metrics["profit_factor"] = round(_profit_factor(ordered), 6) if _profit_factor(ordered) is not None else None
    return metrics


def _metric_beats(parent: Mapping[str, Any], challenger: Mapping[str, Any], contract: Mapping[str, Any]) -> dict[str, Any]:
    primary = str(contract.get("primary") or "return_to_maxdd")
    direction = str(contract.get("direction") or "MAXIMIZE").upper()
    if primary not in {"return_to_maxdd", "annual_return_pct", "sharpe", "profit_factor"}:
        raise Q16Error(f"unsupported pre-registered success metric: {primary}")
    if direction != "MAXIMIZE":
        raise Q16Error("Q16 success metric direction must be MAXIMIZE")
    try:
        parent_value = float(parent[primary])
        challenger_value = float(challenger[primary])
        minimum = float(contract.get("minimum_improvement", 0.0))
    except (KeyError, TypeError, ValueError) as exc:
        raise Q16Error("success metric is unavailable on the sealed comparison") from exc
    checks = {
        "primary_improvement": challenger_value - parent_value >= minimum,
        "maxdd_not_worse": (
            not bool(contract.get("require_maxdd_not_worse", True))
            or float(challenger["max_drawdown_pct"]) <= float(parent["max_drawdown_pct"])
        ),
        "worst_day_not_worse": (
            not bool(contract.get("require_worst_day_not_worse", True))
            or float(challenger["worst_day_pct"]) >= float(parent["worst_day_pct"])
        ),
    }
    return {
        "contract": dict(contract),
        "parent_value": parent_value,
        "challenger_value": challenger_value,
        "observed_improvement": round(challenger_value - parent_value, 8),
        "checks": checks,
        "passed": all(checks.values()),
    }


def _pearson(a: list[float], b: list[float]) -> float | None:
    if len(a) != len(b) or len(a) < 3:
        return None
    ma, mb = sum(a) / len(a), sum(b) / len(b)
    da = math.sqrt(sum((value - ma) ** 2 for value in a))
    db = math.sqrt(sum((value - mb) ** 2 for value in b))
    if da == 0 or db == 0:
        return None
    return sum((a[i] - ma) * (b[i] - mb) for i in range(len(a))) / (da * db)


def regime_correlation(candidate: list[float], book: list[float]) -> dict[str, Any]:
    n = len(candidate)
    thirds = []
    correlations: list[float] = []
    for idx, name in enumerate(("EARLY", "MIDDLE", "LATE")):
        start, end = (idx * n // 3), ((idx + 1) * n // 3)
        corr = _pearson(candidate[start:end], book[start:end])
        thirds.append({"segment": name, "n_days": end - start, "corr": None if corr is None else round(corr, 6)})
        if corr is not None:
            correlations.append(corr)
    ranked = sorted(range(n), key=lambda index: abs(book[index]), reverse=True)
    high_indices = sorted(ranked[: max(3, math.ceil(n * 0.20))])
    high_corr = _pearson([candidate[i] for i in high_indices], [book[i] for i in high_indices])
    if high_corr is not None:
        correlations.append(high_corr)
    maximum = max((abs(value) for value in correlations), default=None)
    return {
        "thirds": thirds,
        "high_vol_subset": {"n_days": len(high_indices), "corr": None if high_corr is None else round(high_corr, 6)},
        "max_abs_regime_corr": None if maximum is None else round(maximum, 6),
    }


def marginal_evaluation(
    *,
    rest_daily: Mapping[Key, Mapping[dt.date, float]],
    candidate_key: Key,
    candidate_daily: Mapping[dt.date, float],
) -> dict[str, Any]:
    if not rest_daily:
        raise Q16Error("book marginal evaluation requires at least one non-parent incumbent")
    combined = dict(rest_daily)
    combined[candidate_key] = candidate_daily
    all_dates = sorted({day for values in combined.values() for day in values})
    if len(all_dates) < 3:
        raise Q16Error("book marginal evaluation has fewer than three OOS days")
    rest_keys = sorted(rest_daily)
    all_keys = sorted(combined)
    full_grid = {
        key: {day: float(values.get(day, 0.0)) for day in all_dates}
        for key, values in combined.items()
    }
    _, dates_before, matrix_before = aligned_matrix(full_grid, rest_keys, all_dates[0], all_dates[-1])
    _, dates_after, matrix_after = aligned_matrix(full_grid, all_keys, all_dates[0], all_dates[-1])
    if dates_before != dates_after:
        raise Q16Error("marginal before/after calendar grids differ")
    before_weights = capped_inverse_vol(rest_keys, matrix_before, total=TOTAL_RISK_PCT, cap=SLEEVE_CAP_PCT)
    after_weights = capped_inverse_vol(all_keys, matrix_after, total=TOTAL_RISK_PCT, cap=SLEEVE_CAP_PCT)
    before_pnl = portfolio_daily(rest_keys, matrix_before, before_weights)
    after_pnl = portfolio_daily(all_keys, matrix_after, after_weights)
    before = book_metrics(before_pnl, len(rest_keys), STARTING_CAPITAL)
    after = book_metrics(after_pnl, len(all_keys), STARTING_CAPITAL)
    deltas = {
        "d_sharpe": round(float(after["sharpe"]) - float(before["sharpe"]), 6),
        "d_maxdd_pct": round(float(after["max_drawdown_pct"]) - float(before["max_drawdown_pct"]), 6),
        "d_worst_day_pct": round(float(after["worst_day_pct"]) - float(before["worst_day_pct"]), 6),
    }
    date_index = {day: index for index, day in enumerate(dates_after)}
    cand_vector = [0.0] * len(dates_after)
    for day, value in candidate_daily.items():
        if day in date_index:
            cand_vector[date_index[day]] += value
    rest_book = before_pnl
    corr = regime_correlation(cand_vector, rest_book)
    years = max(len(dates_after) / 252.0, 1.0 / 252.0)
    contribution = sum(cand_vector) * after_weights[candidate_key] / years / STARTING_CAPITAL * 100.0
    ops_worthy = contribution >= MIN_CONTRIBUTION_ANN_PCT
    diversifying = corr["max_abs_regime_corr"] is not None and corr["max_abs_regime_corr"] < CORR_ADMIT_MAX
    risk_improves = (
        deltas["d_maxdd_pct"] <= -DMAXDD_EPS_PCT
        or deltas["d_worst_day_pct"] > 0
    )
    sharpe_help = deltas["d_sharpe"] >= DSHARPE_EPS
    contributes = ops_worthy and (risk_improves or (sharpe_help and diversifying))
    return {
        "before": before,
        "after": after,
        "deltas": deltas,
        "regime_split_correlation_vs_rest_book": corr,
        "candidate_weight_pct": round(after_weights[candidate_key], 8),
        "annualized_net_contribution_pct": round(contribution, 8),
        "ops_worthy": ops_worthy,
        "contributes": contributes,
        "rules": {
            "regime_corr_admit_max": CORR_ADMIT_MAX,
            "regime_corr_reject_min": CORR_REJECT_MIN,
            "d_sharpe_eps_never_sole_driver": DSHARPE_EPS,
            "d_maxdd_eps_pct": DMAXDD_EPS_PCT,
            "min_contribution_ann_pct": MIN_CONTRIBUTION_ANN_PCT,
            "weighting": "capped_inverse_vol_cap1_total9.75",
        },
    }


def load_frozen_book(
    book_manifest_path: Path,
    stream_manifest_path: Path,
    *,
    windows: list[dict[str, Any]],
    costs: VenueCostModel,
) -> tuple[dict[Key, dict[dt.date, float]], dict[str, Any]]:
    book = _load_json(book_manifest_path, "incumbent book manifest")
    bundle = _load_json(stream_manifest_path, "frozen book stream manifest")
    if not isinstance(book, Mapping) or not isinstance(book.get("sleeves"), list):
        raise Q16Error("incumbent book manifest lacks sleeves")
    if not isinstance(bundle, Mapping) or bundle.get("schema") != FROZEN_BUNDLE_SCHEMA or bundle.get("frozen") is not True:
        raise Q16Error(f"book streams must use {FROZEN_BUNDLE_SCHEMA} with frozen=true")
    book_keys = {_key(row, "book sleeve") for row in book["sleeves"] if isinstance(row, Mapping)}
    rows = bundle.get("streams")
    if not isinstance(rows, list):
        raise Q16Error("frozen book stream manifest lacks streams")
    stream_rows: dict[Key, Mapping[str, Any]] = {}
    for row in rows:
        if not isinstance(row, Mapping):
            raise Q16Error("frozen book stream row must be an object")
        key = _key(row, "book stream")
        if key in stream_rows:
            raise Q16Error(f"duplicate frozen book stream {key}")
        stream_rows[key] = row
    if set(stream_rows) != book_keys:
        raise Q16Error("frozen book stream identities do not exactly match book sleeves")
    daily: dict[Key, dict[dt.date, float]] = {}
    stream_hashes: dict[str, str] = {}
    seen_stream_paths: set[Path] = set()
    for key in sorted(book_keys):
        row = stream_rows[key]
        if row.get("frozen") is not True or float(row.get("risk_fixed", -1)) != RISK_FIXED or float(row.get("risk_percent", -1)) != 0:
            raise Q16Error(f"book stream {key} is not frozen RISK_FIXED=1000/RISK_PERCENT=0")
        path, bound = _resolve_bound_file(row, f"book stream {key}", base=stream_manifest_path.parent)
        if _is_mutable_mt5_storage(path):
            raise Q16Error(f"book stream {key} resolves to mutable MT5 storage")
        if path in seen_stream_paths:
            raise Q16Error(f"frozen book stream file is reused by multiple sleeves: {path}")
        seen_stream_paths.add(path)
        daily[key], _ = load_repriced_stream(
            path, expected_key=key, expected_count=row.get("trade_count"), windows=windows, costs=costs
        )
        stream_hashes[f"{key[0]}:{key[1]}"] = bound["sha256"]
    return daily, {
        "book_manifest": _binding(book_manifest_path),
        "stream_manifest": _binding(stream_manifest_path),
        "sleeves": len(daily),
        "stream_sha256": stream_hashes,
    }


def evaluate_q16(
    *,
    opt_card_path: Path,
    parent_lineage_path: Path,
    challenger_lineage_path: Path,
    trial_ledger_path: Path,
    book_manifest_path: Path,
    book_stream_manifest_path: Path,
    cost_model_path: Path = DEFAULT_COST_MODEL,
) -> dict[str, Any]:
    input_paths = {
        "opt_card": opt_card_path,
        "parent_lineage": parent_lineage_path,
        "challenger_lineage": challenger_lineage_path,
        "trial_ledger": trial_ledger_path,
        "book_manifest": book_manifest_path,
        "book_stream_manifest": book_stream_manifest_path,
        "cost_model": cost_model_path,
    }
    input_bindings = {}
    for name, path in input_paths.items():
        try:
            input_bindings[name] = _binding(path)
        except Q16Error:
            input_bindings[name] = {"path": str(path), "status": "MISSING"}
    try:
        card = _load_json(opt_card_path, "opt-card")
        if not isinstance(card, Mapping) or card.get("schema") != OPT_CARD_SCHEMA:
            raise Q16Error(f"opt-card schema must be {OPT_CARD_SCHEMA}")
        windows = load_windows(card)
        parent = load_lineage(parent_lineage_path, "PARENT")
        challenger = load_lineage(challenger_lineage_path, "CHALLENGER")
        if parent["key"] == challenger["key"]:
            raise Q16Error("parent and challenger identities are identical")
        if parent["key"][1] != challenger["key"][1]:
            raise Q16Error("head-to-head parent and challenger symbols differ")
        card_parent = card.get("parent")
        if not isinstance(card_parent, Mapping) or _key(card_parent, "opt-card parent") != parent["key"]:
            raise Q16Error("parent lineage identity does not match opt-card")
        for name in ("binary", "setfile"):
            raw = card_parent.get(name)
            if not isinstance(raw, Mapping) or str(raw.get("sha256") or "").lower() != parent[name]["sha256"]:
                raise Q16Error(f"parent {name} lineage does not match opt-card frozen hash")
        trial = validate_trial_ledger(card, trial_ledger_path, challenger)
        costs = VenueCostModel(cost_model_path)
        parent_daily, parent_stream = load_repriced_stream(
            parent["stream_path"], expected_key=parent["key"],
            expected_count=parent["stream_declared_count"], windows=windows, costs=costs,
        )
        challenger_daily, challenger_stream = load_repriced_stream(
            challenger["stream_path"], expected_key=challenger["key"],
            expected_count=challenger["stream_declared_count"], windows=windows, costs=costs,
        )
        parent_metrics = standalone_metrics(parent_daily)
        challenger_metrics = standalone_metrics(challenger_daily)
        success_raw = card.get("success_metric")
        if not isinstance(success_raw, Mapping):
            raise Q16Error("opt-card success_metric must be an object")
        standalone = _metric_beats(parent_metrics, challenger_metrics, success_raw)
        book_daily, book_provenance = load_frozen_book(
            book_manifest_path, book_stream_manifest_path, windows=windows, costs=costs
        )
        if parent["key"] not in book_daily:
            raise Q16Error("frozen parent is not an incumbent-book sleeve")
        parent_label = f"{parent['key'][0]}:{parent['key'][1]}"
        if book_provenance["stream_sha256"].get(parent_label) != parent["stream"]["sha256"]:
            raise Q16Error("incumbent-book parent stream differs from frozen parent lineage")
        if challenger["key"] in book_daily:
            raise Q16Error("challenger already exists in incumbent book")
        rest = {key: values for key, values in book_daily.items() if key != parent["key"]}
        parent_marginal = marginal_evaluation(
            rest_daily=rest, candidate_key=parent["key"], candidate_daily=parent_daily
        )
        challenger_marginal = marginal_evaluation(
            rest_daily=rest, candidate_key=challenger["key"], candidate_daily=challenger_daily
        )
        both_dates = sorted(set(parent_daily) | set(challenger_daily))
        parent_vector = [parent_daily.get(day, 0.0) for day in both_dates]
        challenger_vector = [challenger_daily.get(day, 0.0) for day in both_dates]
        pair_corr = regime_correlation(parent_vector, challenger_vector)
        both_contribute = parent_marginal["contributes"] and challenger_marginal["contributes"]
        admit_corr = (
            pair_corr["max_abs_regime_corr"] is not None
            and pair_corr["max_abs_regime_corr"] < CORR_ADMIT_MAX
        )
        if standalone["passed"] and both_contribute and admit_corr:
            verdict = "ADMIT_BOTH"
            reason_codes = ["CHALLENGER_BEATS_NO_CHANGE", "BOTH_CONTRIBUTE", "PAIR_CORR_BELOW_ADMIT"]
        elif standalone["passed"] and challenger_marginal["contributes"]:
            verdict = "PROMOTE_CHALLENGER"
            reason_codes = ["CHALLENGER_BEATS_NO_CHANGE", "CHALLENGER_CONTRIBUTES"]
        else:
            verdict = "KEEP_INCUMBENT"
            reason_codes = []
            if not standalone["passed"]:
                reason_codes.append("CHALLENGER_DOES_NOT_BEAT_NO_CHANGE")
            if not challenger_marginal["contributes"]:
                reason_codes.append("CHALLENGER_NOT_BOOK_CONTRIBUTIVE")
            if both_contribute and not admit_corr:
                reason_codes.append("PAIR_CORR_NOT_BELOW_ADMIT")
        result = {
            "schema": RESULT_SCHEMA,
            "verdict": verdict,
            "reason_codes": reason_codes,
            "card_id": card.get("card_id"),
            "parent": {"ea_id": parent["key"][0], "symbol": parent["key"][1]},
            "challenger": {"ea_id": challenger["key"][0], "symbol": challenger["key"][1]},
            "sealed_windows": [
                {"id": row["id"], "kind": row["kind"], "start": row["start"].isoformat(), "end": row["end"].isoformat()}
                for row in windows
            ],
            "risk_contract": {"RISK_FIXED": RISK_FIXED, "RISK_PERCENT": RISK_PERCENT},
            "real_venue_cost_model": costs.binding,
            "trial_ledger": trial,
            "no_change_control": {
                "definition": "parent re-evaluated on identical sealed windows/data/cost model",
                "parent_metrics": parent_metrics,
                "parent_stream": parent_stream,
            },
            "challenger_comparison": {
                "metrics": challenger_metrics,
                "stream": challenger_stream,
                "success": standalone,
            },
            "book_marginal": {
                "parent": parent_marginal,
                "challenger": challenger_marginal,
                "pair_regime_correlation": pair_corr,
                "admit_both_checks": {
                    "both_contribute": both_contribute,
                    "max_abs_pair_regime_corr_below_0p15": admit_corr,
                },
                "provenance": book_provenance,
            },
            "lineage": {"parent": parent["input"], "challenger": challenger["input"]},
            "inputs": input_bindings,
            "actions": {"pipeline_verdict_only": True, "deployment": "NONE", "autotrading": "NONE"},
        }
    except (Q16Error, OSError, ValueError, KeyError) as exc:
        result = {
            "schema": RESULT_SCHEMA,
            "verdict": "FAIL",
            "reason_codes": ["FAIL_CLOSED_INPUT_OR_EVIDENCE"],
            "error": str(exc),
            "inputs": input_bindings,
            "actions": {"pipeline_verdict_only": True, "deployment": "NONE", "autotrading": "NONE"},
        }
    result["result_body_sha256"] = sha256_bytes(canonical_json(result).encode("ascii"))
    return result


def evidence_markdown(result: Mapping[str, Any], result_path: Path) -> str:
    reasons = ", ".join(str(value) for value in result.get("reason_codes", [])) or "NONE"
    return f"""# Q16 sealed head-to-head evidence

- Verdict: `{result['verdict']}`
- Reasons: `{reasons}`
- Result: `{result_path}`
- Result body SHA-256: `{result['result_body_sha256']}`
- Actions: pipeline verdict only; deployment and AutoTrading are `NONE`.

The evaluator read only the opt-card's pre-registered anchored-Q04 OOS folds and post-DEV holdout. Any missing Q10, immutable-stream, risk, venue-cost, or trial-ledger evidence produces `FAIL`.
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--opt-card", type=Path, required=True)
    parser.add_argument("--parent-lineage", type=Path, required=True)
    parser.add_argument("--challenger-lineage", type=Path, required=True)
    parser.add_argument("--trial-ledger", type=Path, required=True)
    parser.add_argument("--book-manifest", type=Path, required=True)
    parser.add_argument("--book-stream-manifest", type=Path, required=True)
    parser.add_argument("--cost-model", type=Path, default=DEFAULT_COST_MODEL)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = evaluate_q16(
        opt_card_path=args.opt_card,
        parent_lineage_path=args.parent_lineage,
        challenger_lineage_path=args.challenger_lineage,
        trial_ledger_path=args.trial_ledger,
        book_manifest_path=args.book_manifest,
        book_stream_manifest_path=args.book_stream_manifest,
        cost_model_path=args.cost_model,
    )
    write_json(args.out, result)
    evidence = args.evidence or args.out.with_suffix(".md")
    write_text(evidence, evidence_markdown(result, args.out))
    print(json.dumps({"verdict": result["verdict"], "result": str(args.out), "evidence": str(evidence)}, indent=2))
    return 0 if result["verdict"] != "FAIL" else 2


if __name__ == "__main__":
    raise SystemExit(main())
