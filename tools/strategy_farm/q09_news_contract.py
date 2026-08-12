#!/usr/bin/env python3
"""Pure Q09_NEWS v2 evidence validation and configuration selection.

This module deliberately has no farm dispatcher dependencies.  A runner may
produce the evidence payload described by :func:`adjudicate`; this module then
checks the sealed experiment and returns one of the canonical Q09_NEWS
verdicts.  It never invents a default configuration when evidence is missing.

The experiment has two logical arms:

* ``CONTROL_OFF`` is temporal OFF and compliance NONE.
* ``POLICY_ON`` sweeps all seven temporal modes with the deployment target's
  fixed compliance policy.

Every policy run is paired to the control run with the same seed and immutable
base identity.  Expanded evidence may contain the complete 7 x 4 compliance
matrix, but automatic selection always uses the target compliance policy.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import cmp_to_key
from pathlib import Path
from typing import Any, Mapping, Sequence


SCHEMA_VERSION = "q09-news-evidence/v2"
ADJUDICATION_SCHEMA_VERSION = "q09-news-adjudication/v2"

TEMPORAL_MODES: tuple[str, ...] = (
    "OFF",
    "PRE30",
    "PRE60",
    "PRE30_POST30",
    "PRE60_POST60",
    "SKIP_DAY",
    "CLOSE_ALL_PRE",
)
TEMPORAL_MODE_IDS = {name: index for index, name in enumerate(TEMPORAL_MODES)}
COMPLIANCE_MODES: tuple[str, ...] = ("NONE", "DXZ", "FTMO", "5ERS")
SEEDS: tuple[int, ...] = (42, 17, 99, 7, 2026)

TARGET_COMPLIANCE = {
    "RESEARCH": "NONE",
    "NONE": "NONE",
    "DXZ": "DXZ",
    "DARWINEXZERO": "DXZ",
    "DARWINEX_ZERO": "DXZ",
    "FTMO": "FTMO",
    "5ERS": "5ERS",
    "THE5ERS": "5ERS",
    "THE_5ERS": "5ERS",
}

CANONICAL_VERDICTS = ("CONFIG_LOCKED", "REVIEW_REQUIRED", "INVALID_EVIDENCE")
HEX64 = frozenset("0123456789abcdef")


class ContractError(ValueError):
    """Raised when Q09 evidence is malformed or contradictory."""


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode(
        "utf-8"
    )


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and set(value.lower()) <= HEX64


def _require_sha256(value: Any, field: str) -> str:
    if not _is_sha256(value):
        raise ContractError(f"{field} must be a lowercase 64-character SHA-256")
    if value != value.lower():
        raise ContractError(f"{field} must use lowercase hexadecimal")
    return value


def _require_nonempty(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ContractError(f"{field} must be a non-empty string")
    return value.strip()


def _finite_number(value: Any, field: str) -> float:
    if isinstance(value, bool):
        raise ContractError(f"{field} must be numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ContractError(f"{field} must be numeric") from exc
    if not math.isfinite(number):
        raise ContractError(f"{field} must be finite")
    return number


def _integer(value: Any, field: str, minimum: int = 0) -> int:
    if isinstance(value, bool):
        raise ContractError(f"{field} must be an integer")
    try:
        integer = int(value)
    except (TypeError, ValueError) as exc:
        raise ContractError(f"{field} must be an integer") from exc
    if integer != value and not (isinstance(value, str) and str(integer) == value.strip()):
        raise ContractError(f"{field} must be an integer")
    if integer < minimum:
        raise ContractError(f"{field} must be >= {minimum}")
    return integer


def _parse_utc(value: Any, field: str) -> datetime:
    text = _require_nonempty(value, field)
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError as exc:
        raise ContractError(f"{field} is not an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None:
        raise ContractError(f"{field} must include a UTC offset")
    parsed = parsed.astimezone(timezone.utc)
    return parsed


def compliance_for_target(deployment_target: str) -> str:
    normalized = deployment_target.strip().upper().replace("-", "_").replace(" ", "_")
    try:
        return TARGET_COMPLIANCE[normalized]
    except KeyError as exc:
        raise ContractError(f"unsupported deployment_target: {deployment_target!r}") from exc


@dataclass(frozen=True)
class Metrics:
    trades: int
    profit_factor: float
    drawdown_pct: float
    sharpe: float
    net_r: float
    original_entries: int
    blocked_entries: int
    affected_entries: int

    @classmethod
    def from_mapping(cls, raw: Mapping[str, Any], field: str) -> "Metrics":
        if not isinstance(raw, Mapping):
            raise ContractError(f"{field} must be an object")
        trades = _integer(raw.get("trades"), f"{field}.trades")
        original = _integer(raw.get("original_entries", trades), f"{field}.original_entries")
        blocked = _integer(raw.get("blocked_entries", 0), f"{field}.blocked_entries")
        affected = _integer(raw.get("affected_entries", blocked), f"{field}.affected_entries")
        if blocked > original or affected > original:
            raise ContractError(f"{field} blocked/affected entries exceed original entries")
        drawdown = _finite_number(raw.get("drawdown_pct"), f"{field}.drawdown_pct")
        if drawdown < 0:
            raise ContractError(f"{field}.drawdown_pct must be >= 0")
        return cls(
            trades=trades,
            profit_factor=_finite_number(raw.get("profit_factor"), f"{field}.profit_factor"),
            drawdown_pct=drawdown,
            sharpe=_finite_number(raw.get("sharpe"), f"{field}.sharpe"),
            net_r=_finite_number(raw.get("net_r"), f"{field}.net_r"),
            original_entries=original,
            blocked_entries=blocked,
            affected_entries=affected,
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "trades": self.trades,
            "profit_factor": self.profit_factor,
            "drawdown_pct": self.drawdown_pct,
            "sharpe": self.sharpe,
            "net_r": self.net_r,
            "original_entries": self.original_entries,
            "blocked_entries": self.blocked_entries,
            "affected_entries": self.affected_entries,
        }


@dataclass(frozen=True)
class Cell:
    arm: str
    temporal_mode: str
    compliance_mode: str
    seed: int
    requested_seed: int
    effective_seed: int
    paired_base_identity_sha256: str
    run_identity_sha256: str
    setfile_sha256: str
    evidence_sha256: str
    report_sha256: str
    selection: Metrics
    holdout: Metrics
    full: Metrics
    q07_seed_stability_pass: bool
    flat_at_event_receipt_sha256: str | None

    @property
    def key(self) -> tuple[str, str, str, int]:
        return (self.arm, self.temporal_mode, self.compliance_mode, self.seed)

    @classmethod
    def from_mapping(cls, raw: Mapping[str, Any], index: int) -> "Cell":
        field = f"cells[{index}]"
        if not isinstance(raw, Mapping):
            raise ContractError(f"{field} must be an object")
        arm = _require_nonempty(raw.get("arm"), f"{field}.arm").upper()
        if arm not in {"CONTROL_OFF", "POLICY_ON"}:
            raise ContractError(f"{field}.arm is not canonical")
        temporal = _require_nonempty(raw.get("temporal_mode"), f"{field}.temporal_mode").upper()
        compliance = _require_nonempty(raw.get("compliance_mode"), f"{field}.compliance_mode").upper()
        if temporal not in TEMPORAL_MODE_IDS:
            raise ContractError(f"{field}.temporal_mode is not canonical")
        if compliance not in COMPLIANCE_MODES:
            raise ContractError(f"{field}.compliance_mode is not canonical")
        seed = _integer(raw.get("seed"), f"{field}.seed")
        requested = _integer(raw.get("requested_seed"), f"{field}.requested_seed")
        effective = _integer(raw.get("effective_seed"), f"{field}.effective_seed")
        if seed not in SEEDS or requested != seed or effective != seed:
            raise ContractError(f"{field} failed requested/effective seed authentication")
        if arm == "CONTROL_OFF" and (temporal != "OFF" or compliance != "NONE"):
            raise ContractError(f"{field} CONTROL_OFF must use OFF/NONE")
        stability = raw.get("q07_seed_stability_pass")
        if not isinstance(stability, bool):
            raise ContractError(f"{field}.q07_seed_stability_pass must be boolean")
        receipt = raw.get("flat_at_event_receipt_sha256")
        if receipt is not None:
            receipt = _require_sha256(receipt, f"{field}.flat_at_event_receipt_sha256")
        return cls(
            arm=arm,
            temporal_mode=temporal,
            compliance_mode=compliance,
            seed=seed,
            requested_seed=requested,
            effective_seed=effective,
            paired_base_identity_sha256=_require_sha256(
                raw.get("paired_base_identity_sha256"), f"{field}.paired_base_identity_sha256"
            ),
            run_identity_sha256=_require_sha256(raw.get("run_identity_sha256"), f"{field}.run_identity_sha256"),
            setfile_sha256=_require_sha256(raw.get("setfile_sha256"), f"{field}.setfile_sha256"),
            evidence_sha256=_require_sha256(raw.get("evidence_sha256"), f"{field}.evidence_sha256"),
            report_sha256=_require_sha256(raw.get("report_sha256"), f"{field}.report_sha256"),
            selection=Metrics.from_mapping(raw.get("selection"), f"{field}.selection"),
            holdout=Metrics.from_mapping(raw.get("holdout"), f"{field}.holdout"),
            full=Metrics.from_mapping(raw.get("full"), f"{field}.full"),
            q07_seed_stability_pass=stability,
            flat_at_event_receipt_sha256=receipt,
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "arm": self.arm,
            "temporal_mode": self.temporal_mode,
            "compliance_mode": self.compliance_mode,
            "seed": self.seed,
            "requested_seed": self.requested_seed,
            "effective_seed": self.effective_seed,
            "paired_base_identity_sha256": self.paired_base_identity_sha256,
            "run_identity_sha256": self.run_identity_sha256,
            "setfile_sha256": self.setfile_sha256,
            "evidence_sha256": self.evidence_sha256,
            "report_sha256": self.report_sha256,
            "selection": self.selection.as_dict(),
            "holdout": self.holdout.as_dict(),
            "full": self.full.as_dict(),
            "q07_seed_stability_pass": self.q07_seed_stability_pass,
            "flat_at_event_receipt_sha256": self.flat_at_event_receipt_sha256,
        }


@dataclass(frozen=True)
class CandidateScore:
    temporal_mode: str
    selection_delta_sharpe: float
    holdout_delta_sharpe: float
    paired_non_worse: int
    worst_dd_worsening_pct_points: float
    lower_confidence_bound: float
    worst_drawdown_pct: float
    worst_profit_factor: float
    blocked_entry_share: float
    robust: bool
    rejection_reasons: tuple[str, ...]

    def as_dict(self) -> dict[str, Any]:
        return {
            "temporal_mode": self.temporal_mode,
            "temporal_mode_id": TEMPORAL_MODE_IDS[self.temporal_mode],
            "selection_delta_sharpe": self.selection_delta_sharpe,
            "holdout_delta_sharpe": self.holdout_delta_sharpe,
            "paired_non_worse": self.paired_non_worse,
            "worst_dd_worsening_pct_points": self.worst_dd_worsening_pct_points,
            "lower_confidence_bound": self.lower_confidence_bound,
            "worst_drawdown_pct": self.worst_drawdown_pct,
            "worst_profit_factor": self.worst_profit_factor,
            "blocked_entry_share": self.blocked_entry_share,
            "robust": self.robust,
            "rejection_reasons": list(self.rejection_reasons),
        }


def _mean(values: Sequence[float]) -> float:
    return statistics.fmean(values)


def _lower_confidence_bound(values: Sequence[float]) -> float:
    """One-sided 95% Student-t lower bound for five paired seed deltas."""

    if not values:
        raise ContractError("confidence bound requires paired observations")
    if len(values) == 1:
        return values[0]
    # Locked Q09 uses five seeds, hence df=4 and t(0.95)=2.131846786.
    return _mean(values) - 2.131846786 * statistics.stdev(values) / math.sqrt(len(values))


def _valid_config_cells(cells: Sequence[Cell]) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    if len(cells) != len(SEEDS) or {cell.seed for cell in cells} != set(SEEDS):
        reasons.append("five_authenticated_seeds_required")
    for cell in cells:
        if cell.selection.trades < 20:
            reasons.append(f"seed_{cell.seed}_selection_trades_below_20")
        if cell.selection.profit_factor <= 1.0:
            reasons.append(f"seed_{cell.seed}_selection_pf_not_above_1")
        if cell.selection.drawdown_pct > 25.0:
            reasons.append(f"seed_{cell.seed}_selection_dd_above_25pct")
        if not cell.q07_seed_stability_pass:
            reasons.append(f"seed_{cell.seed}_q07_stability_failed")
    return (not reasons, reasons)


def _score_candidate(policy: Sequence[Cell], control_by_seed: Mapping[int, Cell]) -> CandidateScore:
    valid, reasons = _valid_config_cells(policy)
    selection_deltas = [cell.selection.sharpe - control_by_seed[cell.seed].selection.sharpe for cell in policy]
    holdout_deltas = [cell.holdout.sharpe - control_by_seed[cell.seed].holdout.sharpe for cell in policy]
    selection_delta = _mean(selection_deltas)
    holdout_delta = _mean(holdout_deltas)
    # "paired seed non-worse" is evaluated on the sealed selection statistic;
    # holdout has its own strict positive aggregate requirement.
    non_worse = sum(delta >= 0.0 for delta in selection_deltas)
    worst_policy_dd = max(cell.full.drawdown_pct for cell in policy)
    worst_control_dd = max(cell.full.drawdown_pct for cell in control_by_seed.values())
    dd_worsening = worst_policy_dd - worst_control_dd
    lower_bound = min(_lower_confidence_bound(selection_deltas), _lower_confidence_bound(holdout_deltas))
    if selection_delta < 0.06:
        reasons.append("selection_delta_sharpe_below_0.06")
    if holdout_delta <= 0.0:
        reasons.append("holdout_delta_sharpe_not_positive")
    if non_worse < 4:
        reasons.append("fewer_than_4_of_5_selection_pairs_non_worse")
    if dd_worsening > 0.05 + 1e-12:
        reasons.append("worst_seed_dd_worsened_more_than_0.05pp")
    temporal = policy[0].temporal_mode
    if temporal == "CLOSE_ALL_PRE" and any(not cell.flat_at_event_receipt_sha256 for cell in policy):
        reasons.append("close_all_pre_missing_flat_at_event_receipt")
    originals = sum(cell.full.original_entries for cell in policy)
    blocked = sum(cell.full.blocked_entries for cell in policy)
    return CandidateScore(
        temporal_mode=temporal,
        selection_delta_sharpe=selection_delta,
        holdout_delta_sharpe=holdout_delta,
        paired_non_worse=non_worse,
        worst_dd_worsening_pct_points=dd_worsening,
        lower_confidence_bound=lower_bound,
        worst_drawdown_pct=worst_policy_dd,
        worst_profit_factor=min(cell.full.profit_factor for cell in policy),
        blocked_entry_share=(blocked / originals if originals else 0.0),
        robust=not reasons,
        rejection_reasons=tuple(dict.fromkeys(reasons)),
    )


_INTERVENTION_BURDEN = {
    "OFF": 0,
    "PRE30": 1,
    "PRE60": 2,
    "PRE30_POST30": 3,
    "PRE60_POST60": 4,
    "SKIP_DAY": 5,
    "CLOSE_ALL_PRE": 6,
}


def _compare_scores(left: CandidateScore, right: CandidateScore) -> int:
    # Locked tie rule: if both Sharpe-LCB and DD are practically tied, choose
    # the less interventionist policy.  It precedes the remaining stable
    # ranking keys only inside that explicit equivalence band.
    if (
        abs(left.lower_confidence_bound - right.lower_confidence_bound) < 0.02
        and abs(left.worst_drawdown_pct - right.worst_drawdown_pct) < 0.05
    ):
        left_tie = (_INTERVENTION_BURDEN[left.temporal_mode], TEMPORAL_MODE_IDS[left.temporal_mode])
        right_tie = (_INTERVENTION_BURDEN[right.temporal_mode], TEMPORAL_MODE_IDS[right.temporal_mode])
        return (left_tie > right_tie) - (left_tie < right_tie)
    left_rank = (
        -left.lower_confidence_bound,
        left.worst_drawdown_pct,
        -left.worst_profit_factor,
        left.blocked_entry_share,
        TEMPORAL_MODE_IDS[left.temporal_mode],
    )
    right_rank = (
        -right.lower_confidence_bound,
        right.worst_drawdown_pct,
        -right.worst_profit_factor,
        right.blocked_entry_share,
        TEMPORAL_MODE_IDS[right.temporal_mode],
    )
    return (left_rank > right_rank) - (left_rank < right_rank)


def _material_effect(policy_by_mode: Mapping[str, Sequence[Cell]], control: Mapping[int, Cell]) -> dict[str, Any]:
    reasons: set[str] = set()
    max_flip_pairs = 0
    max_affected = 0
    off_entries = sum(cell.full.original_entries for cell in control.values())
    for cells in policy_by_mode.values():
        affected = sum(cell.full.affected_entries for cell in cells)
        max_affected = max(max_affected, affected)
        if affected >= max(3, math.ceil(0.05 * off_entries)):
            reasons.add("affected_entries")
        if abs(_mean([c.full.profit_factor for c in cells]) - _mean([c.full.profit_factor for c in control.values()])) >= 0.10:
            reasons.add("delta_profit_factor")
        if abs(max(c.full.drawdown_pct for c in cells) - max(c.full.drawdown_pct for c in control.values())) >= 2.0:
            reasons.add("delta_drawdown_pct_points")
        policy_net = sum(c.full.net_r for c in cells)
        control_net = sum(c.full.net_r for c in control.values())
        if abs(policy_net - control_net) >= max(5.0, 0.10 * abs(control_net)):
            reasons.add("delta_net_r")
        mode_flip_pairs = 0
        for cell in cells:
            baseline = control[cell.seed]
            net_sign_flip = (cell.full.net_r > 0) != (baseline.full.net_r > 0)
            cell_gate = cell.full.profit_factor > 1.0 and cell.full.drawdown_pct <= 25.0
            base_gate = baseline.full.profit_factor > 1.0 and baseline.full.drawdown_pct <= 25.0
            if net_sign_flip or cell_gate != base_gate:
                mode_flip_pairs += 1
        max_flip_pairs = max(max_flip_pairs, mode_flip_pairs)
    if max_flip_pairs >= 3:
        reasons.add("sign_or_gate_flip_3_of_5")
    return {
        "material": bool(reasons),
        "reasons": sorted(reasons),
        "max_affected_entries": max_affected,
        "control_original_entries": off_entries,
        "sign_or_gate_flip_pairs": max_flip_pairs,
    }


def _invalid(reason: str, *, details: Mapping[str, Any] | None = None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "schema_version": ADJUDICATION_SCHEMA_VERSION,
        "verdict": "INVALID_EVIDENCE",
        "reason_codes": [reason],
        "chosen_config": None,
        "locked_arms": [],
    }
    if details:
        result["details"] = dict(details)
    result["adjudication_sha256"] = sha256_bytes(canonical_json_bytes(result))
    return result


def _validated_header(payload: Mapping[str, Any]) -> dict[str, Any]:
    if payload.get("schema_version") != SCHEMA_VERSION:
        raise ContractError(f"schema_version must be {SCHEMA_VERSION}")
    deployment_target = _require_nonempty(payload.get("deployment_target"), "deployment_target")
    target_compliance = compliance_for_target(deployment_target)
    work_item_id = _require_nonempty(payload.get("work_item_id"), "work_item_id")
    identities = payload.get("identities")
    if not isinstance(identities, Mapping):
        raise ContractError("identities must be an object")
    required_identity_fields = (
        "q08_work_item_id",
        "q08_evidence_sha256",
        "baseline_setfile_sha256",
        "ex5_sha256",
        "include_closure_sha256",
        "paired_base_identity_sha256",
    )
    normalized_identities: dict[str, Any] = {}
    for field in required_identity_fields:
        if field.endswith("_sha256"):
            normalized_identities[field] = _require_sha256(identities.get(field), f"identities.{field}")
        else:
            normalized_identities[field] = _require_nonempty(identities.get(field), f"identities.{field}")

    calendar = payload.get("calendar_bundle")
    if not isinstance(calendar, Mapping):
        raise ContractError("calendar_bundle must be an object")
    normalized_calendar = {
        "bundle_id": _require_nonempty(calendar.get("bundle_id"), "calendar_bundle.bundle_id"),
        "manifest_sha256": _require_sha256(calendar.get("manifest_sha256"), "calendar_bundle.manifest_sha256"),
        "content_sha256": _require_sha256(calendar.get("content_sha256"), "calendar_bundle.content_sha256"),
        "coverage_from_utc": _parse_utc(calendar.get("coverage_from_utc"), "calendar_bundle.coverage_from_utc"),
        "coverage_to_utc": _parse_utc(calendar.get("coverage_to_utc"), "calendar_bundle.coverage_to_utc"),
    }
    windows = payload.get("windows")
    if not isinstance(windows, Mapping):
        raise ContractError("windows must be an object")
    normalized_windows = {
        key: _parse_utc(windows.get(key), f"windows.{key}")
        for key in (
            "full_from_utc",
            "full_to_utc",
            "selection_from_utc",
            "selection_to_utc",
            "holdout_from_utc",
            "holdout_to_utc",
        )
    }
    complete_months = _integer(windows.get("complete_months"), "windows.complete_months")
    holdout_months = _integer(windows.get("holdout_complete_months"), "windows.holdout_complete_months")
    if complete_months < 60 or holdout_months < 24:
        raise ContractError("at least 60 complete months and a 24 complete-month holdout are required")
    if windows.get("holdout_sealed") is not True:
        raise ContractError("windows.holdout_sealed must be true")
    if not (
        normalized_windows["full_from_utc"] <= normalized_windows["selection_from_utc"]
        <= normalized_windows["selection_to_utc"]
        < normalized_windows["holdout_from_utc"]
        <= normalized_windows["holdout_to_utc"]
        == normalized_windows["full_to_utc"]
    ):
        raise ContractError("selection/holdout windows are not ordered or holdout is not the sealed tail")
    if (
        normalized_calendar["coverage_from_utc"] > normalized_windows["full_from_utc"]
        or normalized_calendar["coverage_to_utc"] < normalized_windows["full_to_utc"]
    ):
        raise ContractError("calendar bundle does not cover the full experiment window")
    return {
        "work_item_id": work_item_id,
        "deployment_target": deployment_target,
        "target_compliance": target_compliance,
        "identities": normalized_identities,
        "calendar": normalized_calendar,
        "windows": normalized_windows,
        "complete_months": complete_months,
        "holdout_complete_months": holdout_months,
    }


def validate_experiment_header(payload: Mapping[str, Any]) -> dict[str, Any]:
    """Public header validator shared by planners and evidence collectors."""

    if not isinstance(payload, Mapping):
        raise TypeError("payload must be a mapping")
    return _validated_header(payload)


def adjudicate(payload: Mapping[str, Any]) -> dict[str, Any]:
    """Validate a sealed Q09_NEWS experiment and select a configuration.

    Malformed or contradictory evidence returns ``INVALID_EVIDENCE`` instead
    of raising.  Programmer misuse (a non-mapping payload) still raises
    ``TypeError``.
    """

    if not isinstance(payload, Mapping):
        raise TypeError("payload must be a mapping")
    try:
        header = _validated_header(payload)
        raw_cells = payload.get("cells")
        if not isinstance(raw_cells, Sequence) or isinstance(raw_cells, (str, bytes)):
            raise ContractError("cells must be an array")
        cells = [Cell.from_mapping(raw, index) for index, raw in enumerate(raw_cells)]
        if not cells:
            raise ContractError("cells must not be empty")
        if len({cell.key for cell in cells}) != len(cells):
            raise ContractError("duplicate cell key")
        if len({cell.run_identity_sha256 for cell in cells}) != len(cells):
            raise ContractError("run_identity_sha256 reused by multiple cells")
        if len({cell.evidence_sha256 for cell in cells}) != len(cells):
            raise ContractError("evidence_sha256 reused by multiple cells")
        base_identity = header["identities"]["paired_base_identity_sha256"]
        if any(cell.paired_base_identity_sha256 != base_identity for cell in cells):
            raise ContractError("cell paired_base_identity_sha256 mismatch")
    except ContractError as exc:
        return _invalid("contract_invalid", details={"error": str(exc)})

    by_key = {cell.key: cell for cell in cells}
    control: dict[int, Cell] = {}
    missing: list[str] = []
    for seed in SEEDS:
        key = ("CONTROL_OFF", "OFF", "NONE", seed)
        if key not in by_key:
            missing.append("/".join(map(str, key)))
        else:
            control[seed] = by_key[key]
    target_compliance = header["target_compliance"]
    policy_by_mode: dict[str, list[Cell]] = {}
    for temporal in TEMPORAL_MODES:
        mode_cells: list[Cell] = []
        for seed in SEEDS:
            key = ("POLICY_ON", temporal, target_compliance, seed)
            if key not in by_key:
                missing.append("/".join(map(str, key)))
            else:
                mode_cells.append(by_key[key])
        policy_by_mode[temporal] = mode_cells
    if missing:
        return _invalid("required_matrix_cells_missing", details={"missing_cells": missing})

    control_valid, control_reasons = _valid_config_cells(list(control.values()))
    off_valid, off_reasons = _valid_config_cells(policy_by_mode["OFF"])
    if not control_valid or not off_valid:
        result = {
            "schema_version": ADJUDICATION_SCHEMA_VERSION,
            "verdict": "REVIEW_REQUIRED",
            "reason_codes": ["control_or_policy_off_not_qualifiable"],
            "details": {"control_reasons": control_reasons, "policy_off_reasons": off_reasons},
            "chosen_config": None,
            "locked_arms": [],
        }
        result["adjudication_sha256"] = sha256_bytes(canonical_json_bytes(result))
        return result

    material = _material_effect(policy_by_mode, control)
    normalized_target = header["deployment_target"].strip().upper().replace("-", "_").replace(" ", "_")
    expansion_reasons: list[str] = []
    if bool(payload.get("news_or_event_strategy")):
        expansion_reasons.append("news_or_event_strategy")
    if normalized_target in {"FTMO", "5ERS", "THE5ERS", "THE_5ERS"}:
        expansion_reasons.append("prop_deployment_target")
    if material["material"]:
        expansion_reasons.append("material_effect")
    missing_expanded: list[str] = []
    if expansion_reasons:
        for compliance in COMPLIANCE_MODES:
            for temporal in TEMPORAL_MODES:
                for seed in SEEDS:
                    key = ("POLICY_ON", temporal, compliance, seed)
                    if key not in by_key:
                        missing_expanded.append("/".join(map(str, key)))
        if missing_expanded:
            result = {
                "schema_version": ADJUDICATION_SCHEMA_VERSION,
                "verdict": "REVIEW_REQUIRED",
                "reason_codes": ["expanded_7x4_matrix_required"],
                "details": {
                    "expansion_reasons": expansion_reasons,
                    "missing_cell_count": len(missing_expanded),
                    "missing_cells": missing_expanded,
                    "material_effect": material,
                },
                "chosen_config": None,
                "locked_arms": [],
            }
            result["adjudication_sha256"] = sha256_bytes(canonical_json_bytes(result))
            return result

    scores = [_score_candidate(policy_by_mode[mode], control) for mode in TEMPORAL_MODES if mode != "OFF"]
    robust_scores = sorted((score for score in scores if score.robust), key=cmp_to_key(_compare_scores))
    chosen_mode = robust_scores[0].temporal_mode if robust_scores else "OFF"
    chosen_cells = policy_by_mode[chosen_mode]
    chosen_set_hashes = sorted({cell.setfile_sha256 for cell in chosen_cells})
    # Seed is an effective tester setting, so a generated setfile per seed is
    # valid.  The lock records all five hashes rather than pretending one file
    # represented the authenticated cohort.
    locked_arms = [
        {
            "arm": "CONTROL_OFF",
            "temporal_mode": "OFF",
            "compliance_mode": "NONE",
            "seed_set": list(SEEDS),
            "setfile_sha256_by_seed": {str(seed): control[seed].setfile_sha256 for seed in SEEDS},
            "evidence_sha256_by_seed": {str(seed): control[seed].evidence_sha256 for seed in SEEDS},
        },
        {
            "arm": "POLICY_ON",
            "temporal_mode": chosen_mode,
            "temporal_mode_id": TEMPORAL_MODE_IDS[chosen_mode],
            "compliance_mode": target_compliance,
            "seed_set": list(SEEDS),
            "setfile_sha256_by_seed": {str(cell.seed): cell.setfile_sha256 for cell in chosen_cells},
            "evidence_sha256_by_seed": {str(cell.seed): cell.evidence_sha256 for cell in chosen_cells},
        },
    ]
    result = {
        "schema_version": ADJUDICATION_SCHEMA_VERSION,
        "verdict": "CONFIG_LOCKED",
        "reason_codes": ["robust_policy_selected" if robust_scores else "off_fallback_no_robust_improvement"],
        "work_item_id": header["work_item_id"],
        "deployment_target": header["deployment_target"],
        "target_compliance": target_compliance,
        "chosen_config": {
            "temporal_mode": chosen_mode,
            "temporal_mode_id": TEMPORAL_MODE_IDS[chosen_mode],
            "compliance_mode": target_compliance,
            "setfile_sha256s": chosen_set_hashes,
        },
        "locked_arms": locked_arms,
        "ranking": [score.as_dict() for score in sorted(scores, key=cmp_to_key(_compare_scores))],
        "matrix_scope": "7x4" if expansion_reasons else "7x1_target_compliance",
        "expansion_reasons": expansion_reasons,
        "material_effect": material,
        "calendar_bundle": {
            key: (value.isoformat().replace("+00:00", "Z") if isinstance(value, datetime) else value)
            for key, value in header["calendar"].items()
        },
        "identities": header["identities"],
        "windows": {
            key: value.isoformat().replace("+00:00", "Z") for key, value in header["windows"].items()
        }
        | {
            "complete_months": header["complete_months"],
            "holdout_complete_months": header["holdout_complete_months"],
            "holdout_sealed": True,
        },
    }
    result["adjudication_sha256"] = sha256_bytes(canonical_json_bytes(result))
    return result


def write_adjudication(payload_path: Path, output_path: Path) -> dict[str, Any]:
    payload = json.loads(payload_path.read_text(encoding="utf-8"))
    result = adjudicate(payload)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary.write_bytes(canonical_json_bytes(result))
    temporary.replace(output_path)
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = write_adjudication(args.evidence, args.output)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["verdict"] == "CONFIG_LOCKED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
