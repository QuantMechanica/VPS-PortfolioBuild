#!/usr/bin/env python3
"""Validate the immutable DXZ 10706 repair/requalification packet.

The validator is intentionally read-only.  It does not run MT5, create a
reference, mutate a preset/EA/Card/registry, or promote a sleeve.  Its evidence
contract prevents a generated qualification stream from serving as its own
reference and keeps technical identity separate from execution-cost evidence.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import dxz_as_live_requal as requal_runner
    from . import dxz_cost_evidence as native_cost_parser
except ImportError:  # pragma: no cover - direct script execution
    import dxz_as_live_requal as requal_runner  # type: ignore
    import dxz_cost_evidence as native_cost_parser  # type: ignore


SPEC_ARTIFACT_TYPE = "DXZ_10706_GBPUSD_REQUALIFICATION_SPEC"
RECEIPT_ARTIFACT_TYPE = "DXZ_10706_SEGMENTED_RUN_RECEIPT"
BUNDLE_ARTIFACT_TYPE = "DXZ_10706_REQUALIFICATION_EVIDENCE_BUNDLE"
SEAL_ARTIFACT_TYPE = "DXZ_10706_OWNER_SEALED_CONSENSUS_REFERENCE"
SEALED_INPUT_ARTIFACT_TYPE = "DXZ_10706_SEALED_INPUT_MANIFEST"
DATA_MANIFEST_ARTIFACT_TYPE = "DXZ_10706_DWX_DATA_MANIFEST"
INSTRUMENT_MANIFEST_ARTIFACT_TYPE = "DXZ_10706_INSTRUMENT_SNAPSHOT_MANIFEST"
SESSION_CALENDAR_ARTIFACT_TYPE = "DXZ_10706_BOUND_SESSION_CALENDAR"
OWNER_RECEIPT_ARTIFACT_TYPE = "DXZ_10706_OWNER_TRUST_RECEIPT"
OWNER_GATES = ("RISK_CONTRACT", "SEALED_INPUT", "REFERENCE_SEAL")
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$")
SEAL_PROVENANCE = "OWNER_SEALED_POST_CONSENSUS_BASELINE"
BASELINE_MODE = "DISCOVERY_COMPLETE_UNREFERENCED"
QUALIFICATION_MODE = "AS_LIVE_REQUAL"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
FORBIDDEN_SELF_KEYS = {"self_path", "self_sha256", "spec_path", "spec_sha256"}
FORBIDDEN_MT5_ROOT_RE = re.compile(
    r"(?:^|[\\/])mt5[\\/](?:T_Live|T(?:10|[1-9]))(?:[\\/]|$)", re.IGNORECASE
)
FORBIDDEN_TIER_PART_RE = re.compile(r"^(?:T_Live|T(?:10|[1-9]))$", re.IGNORECASE)


def canonical_json_sha(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def embedded_hash(payload: Mapping[str, Any], field: str) -> str:
    unsigned = dict(payload)
    unsigned.pop(field, None)
    return canonical_json_sha(unsigned)


def _valid_sha(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value.lower()) is not None


def _path_id(path: Path) -> str:
    try:
        resolved = path.resolve(strict=False)
    except OSError:
        resolved = path.absolute()
    return str(resolved).replace("/", "\\").casefold()


def _within(child: Path, parent: Path) -> bool:
    child_id = _path_id(child)
    parent_id = _path_id(parent).rstrip("\\")
    return child_id == parent_id or child_id.startswith(parent_id + "\\")


def _paths_overlap_or_nested(left: Path, right: Path) -> bool:
    left_id = _path_id(left).rstrip("\\")
    right_id = _path_id(right).rstrip("\\")
    return (
        left_id == right_id
        or left_id.startswith(right_id + "\\")
        or right_id.startswith(left_id + "\\")
    )


def _is_forbidden_tier_path(path: Path) -> bool:
    try:
        parts = path.resolve(strict=False).parts
    except OSError:
        parts = path.absolute().parts
    return any(FORBIDDEN_TIER_PART_RE.fullmatch(part) for part in parts)


def _decimal_text(value: Any) -> str:
    parsed = Decimal(str(value))
    if not parsed.is_finite():
        raise ValueError("non-finite decimal")
    text = format(parsed, "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return "0" if text in {"", "-0"} else text


def _canonical_jsonl(rows: Sequence[Mapping[str, Any]]) -> bytes:
    return b"".join(
        (
            json.dumps(row, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
            + "\n"
        ).encode("utf-8")
        for row in rows
    )


def _weekend_policy_violation(
    entry: dt.datetime, exit_time: dt.datetime, session_cutoffs: Sequence[dt.datetime]
) -> bool:
    """Check the earlier of Friday 21 and the bound last tradable session."""

    if entry > exit_time:
        return True
    if entry.weekday() >= 5 or exit_time.weekday() >= 5:
        return True
    for cutoff in session_cutoffs:
        next_monday = dt.datetime.combine(
            cutoff.date() + dt.timedelta(days=(7 - cutoff.weekday()) % 7),
            dt.time(0, 0),
        )
        if entry < cutoff < exit_time or cutoff <= entry < next_monday:
            return True
    return False


def _control_topology_issues(
    control_paths: Sequence[Path],
    run_roots: Sequence[Path],
    generated_paths: Sequence[Path],
) -> list[str]:
    issues: list[str] = []
    ids = [_path_id(path) for path in control_paths]
    if len(ids) != len(set(ids)):
        issues.append("CONTROL_ARTIFACT_PATH_COLLISION")
    generated_ids = {_path_id(path) for path in generated_paths}
    for path in control_paths:
        if _is_forbidden_tier_path(path):
            issues.append(f"CONTROL_ARTIFACT_IN_FORBIDDEN_MT5_ROOT:{path}")
        if _path_id(path) in generated_ids:
            issues.append(f"CONTROL_ARTIFACT_REUSES_GENERATED_PATH:{path}")
        if any(_paths_overlap_or_nested(path, root) for root in run_roots):
            issues.append(f"CONTROL_ARTIFACT_OVERLAPS_RUN_ROOT:{path}")
    return issues


def _execution_cost_control_paths(manifest_path: Path) -> list[Path]:
    paths = [manifest_path, manifest_path.with_name(manifest_path.name + ".sha256")]
    payload = _load_object(manifest_path)
    axes = payload.get("axes") if isinstance(payload, Mapping) else None
    if isinstance(axes, Mapping):
        for row in axes.values():
            evidence = row.get("evidence") if isinstance(row, Mapping) else None
            value = evidence.get("path") if isinstance(evidence, Mapping) else None
            if isinstance(value, str) and value:
                path = Path(value)
                if not path.is_absolute():
                    path = manifest_path.parent / path
                paths.extend([path, path.with_name(path.name + ".sha256")])
    return paths


def _parse_utc(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(dt.timezone.utc)


def _decimal(value: Any) -> Decimal | None:
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None
    return parsed if parsed.is_finite() else None


def _load_object(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def _result(status: str, issues: Sequence[str], **extra: Any) -> dict[str, Any]:
    result: dict[str, Any] = {
        "status": status,
        "issues": sorted(set(issues)),
        "valid": not issues,
    }
    result.update(extra)
    return result


def _find_forbidden_self_keys(value: Any, prefix: str = "$") -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key).casefold() in FORBIDDEN_SELF_KEYS:
                found.append(f"{prefix}.{key}")
            found.extend(_find_forbidden_self_keys(child, f"{prefix}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(_find_forbidden_self_keys(child, f"{prefix}[{index}]"))
    return found


def _source_dependency_closure(source: Path, repo_root: Path) -> list[Path]:
    include_re = re.compile(r'^\s*#include\s*[<"]([^>"]+)[>"]', re.MULTILINE)
    pending = [source.resolve(strict=True)]
    seen: set[str] = set()
    result: list[Path] = []
    while pending:
        path = pending.pop()
        key = _path_id(path)
        if key in seen:
            continue
        seen.add(key)
        result.append(path)
        text = path.read_text(encoding="utf-8-sig")
        for token in include_re.findall(text):
            cleaned = token.strip().replace("\\", "/")
            candidates = [path.parent / cleaned]
            if cleaned.startswith("QM/"):
                candidates.append(repo_root / "framework" / "include" / cleaned)
            candidates.append(repo_root / "framework" / "include" / cleaned)
            resolved = next((candidate.resolve() for candidate in candidates if candidate.is_file()), None)
            if resolved is not None and _path_id(resolved) not in seen:
                pending.append(resolved)
    return sorted(result, key=_path_id)


def _source_closure_issues(spec: Mapping[str, Any]) -> list[str]:
    contract = spec.get("source_closure_contract")
    if not isinstance(contract, Mapping):
        return ["SPEC_SOURCE_CLOSURE_CONTRACT_INVALID"]
    try:
        repo_root = Path(str(contract.get("repo_root") or "")).resolve(strict=True)
        source = Path(str(contract.get("source_path") or "")).resolve(strict=True)
        paths = _source_dependency_closure(source, repo_root)
        rows = [
            {
                "path": path.relative_to(repo_root).as_posix(),
                "sha256": sha256_file(path),
            }
            for path in paths
        ]
    except (OSError, UnicodeError, ValueError):
        return ["SPEC_SOURCE_CLOSURE_UNREADABLE"]
    aggregate = canonical_json_sha(rows)
    expected_aggregate = contract.get("aggregate_sha256")
    issues: list[str] = []
    if (
        contract.get("resolver") != "RECURSIVE_MQL5_INCLUDE_CLOSURE"
        or contract.get("canonical_path_encoding") != "REPO_RELATIVE_POSIX"
        or contract.get("expected_member_count") != len(rows)
        or not _valid_sha(expected_aggregate)
        or expected_aggregate != aggregate
        or (spec.get("contract_artifact_sha256s") or {}).get(
            "source_dependency_closure"
        )
        != aggregate
    ):
        issues.append("SPEC_SOURCE_CLOSURE_AGGREGATE_INVALID")
    row_index = {row["path"]: row["sha256"] for row in rows}
    critical = contract.get("critical_member_sha256s")
    if not isinstance(critical, Mapping) or any(
        not _valid_sha(expected) or row_index.get(str(path)) != expected
        for path, expected in (critical.items() if isinstance(critical, Mapping) else [])
    ):
        issues.append("SPEC_SOURCE_CLOSURE_CRITICAL_MEMBER_INVALID")
    required_critical = {
        "framework/EAs/QM5_10706_tv-mon-ls/QM5_10706_tv-mon-ls.mq5",
        "framework/include/QM/QM_Exit.mqh",
        "framework/include/QM/QM_KillSwitch.mqh",
        "framework/include/QM/QM_KillSwitchKS.mqh",
        "framework/include/QM/QM_NewsFilter.mqh",
    }
    if not isinstance(critical, Mapping) or set(critical) != required_critical:
        issues.append("SPEC_SOURCE_CLOSURE_CRITICAL_SET_INVALID")
    return issues


def _spec_issues(spec: Mapping[str, Any], *, verify_anchors: bool) -> list[str]:
    issues: list[str] = []
    if spec.get("schema_version") != 1:
        issues.append("SPEC_SCHEMA_INVALID")
    if spec.get("artifact_type") != SPEC_ARTIFACT_TYPE:
        issues.append("SPEC_ARTIFACT_TYPE_INVALID")
    if _find_forbidden_self_keys(spec):
        issues.append("SPEC_SELF_REFERENCE_FIELD_FORBIDDEN")

    scope = spec.get("scope")
    if not isinstance(scope, dict) or any(
        scope.get(key) != value
        for key, value in {
            "ea_id": 10706,
            "symbol": "GBPUSD.DWX",
            "timeframe": "H1",
            "magic": 107060001,
            "mutation_authority": "NONE",
            "mt5_execution_authority": "NONE",
        }.items()
    ):
        issues.append("SPEC_SCOPE_INVALID")
    if (
        spec.get("qualification_state")
        != "BLOCKED_OWNER_TRUST_EARLY_CLOSE_AND_NEWS_ORDERING_RUNTIME_REMEDIATION"
    ):
        issues.append("SPEC_QUALIFICATION_STATE_INVALID")

    gate = spec.get("owner_gate")
    candidates = spec.get("risk_contract_candidates")
    if not isinstance(gate, dict) or gate.get("status") != "PENDING":
        issues.append("SPEC_OWNER_GATE_NOT_PENDING")
    trust = spec.get("owner_trust_contract")
    if not isinstance(trust, dict) or trust != {
        "status": "PENDING_EXTERNAL_TRUST_ANCHORS",
        "receipt_artifact_type": OWNER_RECEIPT_ARTIFACT_TYPE,
        "required_gate_ids": list(OWNER_GATES),
        "trust_anchor_source": "OUT_OF_BAND_CALLER_EXPECTED_SHA256_ONLY",
        "bundle_declared_hash_is_trusted": False,
        "self_attested_inline_approval_is_accepted": False,
        "qualification_blocked_without_all_external_expected_receipt_sha256s": True,
    }:
        issues.append("SPEC_OWNER_TRUST_CONTRACT_INVALID")
    directives = spec.get("owner_directives")
    expected_weekend = {
        "status": "OWNER_DIRECTIVE_RECORDED_UNSEALED",
        "decision": "NO_WEEKEND_HOLDINGS",
        "strategy_friday_exit_enabled": True,
        "strategy_friday_exit_broker_time": "18:30",
        "framework_friday_safety_fallback_enabled": True,
        "framework_friday_safety_fallback_broker_hour": 21,
        "effective_weekend_flat_cutoff": "MIN(CARD_STRATEGY_FRIDAY_18_30,FRAMEWORK_FRIDAY_21,LAST_TRADABLE_SESSION_OR_TICK_BEFORE_WEEKEND)",
        "holiday_early_close_fallback_required": True,
        "purpose": ["WEEKEND_GAP_AVOIDANCE", "PROP_FIRM_PREPARATION"],
        "semantic_decision_open": False,
        "qualification_receipt_still_required": True,
    }
    if not isinstance(directives, dict) or directives.get("weekend_holdings") != expected_weekend:
        issues.append("SPEC_OWNER_WEEKEND_DIRECTIVE_INVALID")
    runtime_gap = spec.get("runtime_policy_gap")
    if runtime_gap != {
        "status": "BLOCKING_REMEDIATION_REQUIRED",
        "bound_source_capability": "FIXED_CARD_FRIDAY_18_30_AND_FRAMEWORK_FRIDAY_21_ONLY",
        "bound_source_has_bound_session_calendar_fallback": False,
        "required_future_card_runtime_behavior": "Flat no later than the earliest of the Card strategy cutoff (18:30 for 10706), framework Friday-21 safety fallback, and the last tradable session/tick before each weekend, including holiday and early-close weeks.",
        "current_packet_mutation_authority": "NONE",
        "promotion_allowed_before_remediated_binary_requalification": False,
        "news_before_friday_close_ordering": {
            "status": "BLOCKING_FOR_BOUND_10706_SOURCE_AND_PRESET",
            "source_on_tick_order": "NEWS_CHECKS_BEFORE_QM_FrameworkHandleFridayClose",
            "source_default_qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
            "source_default_qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
            "live_preset_effective_qm_news_axis_keys_present": False,
            "live_preset_legacy_unread_keys": [
                "qm_filter_news_enabled=1",
                "qm_filter_news_mode=3",
            ],
            "failure_mode": "A blocking or stale/missing news result can return before strategy and framework Friday close handling.",
            "required_on_tick_risk_order": [
                "QM_KillSwitchCheck",
                "EFFECTIVE_FRIDAY_WEEKEND_FLAT_HANDLER",
                "OPTIONAL_NEWS_AND_ENTRY_FILTERS",
            ],
            "kill_switch_first_is_allowed": "QM_KillSwitchCheck has its own flatten/retry behavior while halted; its bound source-closure hash remains mandatory.",
            "farmwide_portability_rule": "Friday/weekend risk closure must execute before any optional entry/news filter for every EA, even when current news axes are NONE.",
            "remediated_source_and_binary_requalification_required": True,
        },
    }:
        issues.append("SPEC_EARLY_CLOSE_RUNTIME_GAP_INVALID")
    if not isinstance(candidates, list) or len(candidates) != 3:
        issues.append("SPEC_RISK_CANDIDATES_INVALID")
        candidates = []
    candidate_ids: set[str] = set()
    for candidate in candidates:
        if not isinstance(candidate, dict):
            issues.append("SPEC_RISK_CANDIDATE_INVALID")
            continue
        contract_id = candidate.get("contract_id")
        rp = _decimal(candidate.get("RISK_PERCENT"))
        fixed = _decimal(candidate.get("RISK_FIXED"))
        weight = _decimal(candidate.get("PORTFOLIO_WEIGHT"))
        effective = _decimal(candidate.get("effective_risk_percent"))
        initial = _decimal(candidate.get("initial_continuous_target_risk_eur"))
        if not isinstance(contract_id, str) or not contract_id or contract_id in candidate_ids:
            issues.append("SPEC_RISK_CANDIDATE_ID_INVALID")
        else:
            candidate_ids.add(contract_id)
        if None in {rp, fixed, weight, effective, initial} or fixed != Decimal("0"):
            issues.append(f"SPEC_RISK_MATH_INVALID:{contract_id}")
            continue
        assert rp is not None and weight is not None and effective is not None and initial is not None
        if effective != rp * weight or initial != Decimal("100000") * effective / Decimal("100"):
            issues.append(f"SPEC_RISK_MATH_INVALID:{contract_id}")
        if weight == Decimal("1") and candidate.get("owner_selectable") is not True:
            issues.append(f"SPEC_OWNER_SELECTABILITY_INVALID:{contract_id}")
        if weight != Decimal("1") and (
            candidate.get("owner_selectable") is not False
            or candidate.get("qualification_class") != "REJECTED_DIMENSIONAL_DOUBLE_SCALING"
        ):
            issues.append(f"SPEC_DOUBLE_WEIGHT_NOT_REJECTED:{contract_id}")

    comparison = spec.get("risk_scale_comparison")
    factor = _decimal(
        comparison.get("PORTFOLIO_WEIGHT_1_vs_0_005783_factor")
        if isinstance(comparison, dict)
        else None
    )
    expected_factor = Decimal("1") / Decimal("0.005783")
    if factor is None or abs(factor - expected_factor) > Decimal("1e-24"):
        issues.append("SPEC_WEIGHT_SCALE_FACTOR_INVALID")
    if gate and gate.get("recommended_contract_id") not in candidate_ids:
        issues.append("SPEC_OWNER_RECOMMENDATION_INVALID")

    artifacts = spec.get("contract_artifact_sha256s")
    required_artifact_keys = {
        "approved_card",
        "ea_spec",
        "ea_source",
        "source_dependency_closure",
        "live_ex5",
        "live_preset",
        "risk_sizer",
    }
    if (
        not isinstance(artifacts, dict)
        or set(artifacts) != required_artifact_keys
        or any(not _valid_sha(value) for value in artifacts.values())
    ):
        issues.append("SPEC_CONTRACT_ARTIFACT_HASHES_INVALID")
    issues.extend(_source_closure_issues(spec))

    anchors = spec.get("anchor_files")
    if not isinstance(anchors, list) or not anchors:
        issues.append("SPEC_ANCHORS_INVALID")
    else:
        labels: set[str] = set()
        for anchor in anchors:
            if not isinstance(anchor, dict):
                issues.append("SPEC_ANCHOR_INVALID")
                continue
            label = anchor.get("label")
            path_value = anchor.get("path")
            expected_sha = anchor.get("sha256")
            if (
                not isinstance(label, str)
                or label in labels
                or not isinstance(path_value, str)
                or not Path(path_value).is_absolute()
                or not _valid_sha(expected_sha)
            ):
                issues.append(f"SPEC_ANCHOR_INVALID:{label}")
                continue
            labels.add(label)
            if verify_anchors:
                path = Path(path_value)
                if not path.is_file():
                    issues.append(f"SPEC_ANCHOR_MISSING:{label}")
                elif sha256_file(path) != expected_sha:
                    issues.append(f"SPEC_ANCHOR_HASH_MISMATCH:{label}")
        if not {"live_ex5", "live_preset", "ea_source", "risk_sizer"}.issubset(labels):
            issues.append("SPEC_CONTRACT_ANCHORS_INCOMPLETE")

    gaps = spec.get("exceptional_h1_gaps")
    expected_gaps = [
        ("B", "2023-12-12T01:00:00Z", "2023-12-18T00:00:00Z", 143),
        ("C", "2025-10-09T02:00:00Z", "2025-11-03T00:00:00Z", 598),
        ("D", "2025-12-17T18:00:00Z", "2025-12-22T00:00:00Z", 102),
    ]
    actual_gaps = []
    if isinstance(gaps, list):
        actual_gaps = [
            (
                item.get("gap_id"),
                item.get("last_bar_open_utc"),
                item.get("next_bar_open_utc"),
                item.get("delta_hours"),
            )
            for item in gaps
            if isinstance(item, dict)
        ]
    if actual_gaps != expected_gaps:
        issues.append("SPEC_EXCEPTIONAL_GAPS_INVALID")

    segments = spec.get("segments")
    expected_segment_ids = ["S0", "S1", "S2", "S3"]
    if (
        not isinstance(segments, list)
        or [row.get("segment_id") for row in segments if isinstance(row, dict)]
        != expected_segment_ids
    ):
        issues.append("SPEC_SEGMENTS_INVALID")
    else:
        previous_end: dt.datetime | None = None
        for segment in segments:
            score_start = _parse_utc(segment.get("score_from_utc"))
            score_end = _parse_utc(segment.get("score_to_exclusive_utc"))
            try:
                tester_start = dt.date.fromisoformat(str(segment.get("tester_from_date")))
                tester_end = dt.date.fromisoformat(str(segment.get("tester_to_date")))
            except ValueError:
                issues.append(f"SPEC_SEGMENT_WINDOW_INVALID:{segment.get('segment_id')}")
                continue
            if (
                score_start is None
                or score_end is None
                or score_start >= score_end
                or tester_start > tester_end
                or (previous_end is not None and score_start <= previous_end)
            ):
                issues.append(f"SPEC_SEGMENT_WINDOW_INVALID:{segment.get('segment_id')}")
            previous_end = score_end

    execution_rules = spec.get("segment_execution_rules")
    if not isinstance(execution_rules, Mapping) or any(
        execution_rules.get(key) != value
        for key, value in {
            "weekend_holdings_allowed": False,
            "strategy_friday_exit_enabled": True,
            "strategy_friday_exit_broker_time": "18:30",
            "framework_friday_safety_fallback_enabled": True,
            "framework_friday_safety_fallback_broker_hour": 21,
            "effective_weekend_flat_cutoff": "MIN(CARD_STRATEGY_FRIDAY_18_30,FRAMEWORK_FRIDAY_21,LAST_TRADABLE_SESSION_OR_TICK_BEFORE_WEEKEND)",
            "bound_session_calendar_required": True,
            "parsed_trade_interval_policy_validation_required": True,
        }.items()
    ):
        issues.append("SPEC_FRIDAY21_NO_WEEKEND_RULE_INVALID")

    frozen = spec.get("frozen_data_contract")
    if not isinstance(frozen, dict) or frozen.get("required_symbols") != [
        "EURUSD.DWX",
        "GBPUSD.DWX",
    ]:
        issues.append("SPEC_FROZEN_DATA_SYMBOLS_INVALID")
    elif any(not str(symbol).endswith(".DWX") for symbol in frozen["required_symbols"]):
        issues.append("SPEC_NON_DWX_DATA_FORBIDDEN")
    expected_calendar = {
        "source": "DARWINEXZERO_MT5_SERVER_BOUND_SESSION_EXPORT",
        "timezone_basis": "MT5_BROKER_TIME",
        "weekly_coverage": "EVERY_FRIDAY_IN_EFFECTIVE_WINDOW",
        "effective_cutoff_rule": "MIN_FRIDAY_21_AND_LAST_TRADABLE_BEFORE_WEEKEND",
    }
    if not isinstance(frozen, dict) or frozen.get("required_session_calendar") != expected_calendar:
        issues.append("SPEC_SESSION_CALENDAR_CONTRACT_INVALID")

    axes = spec.get("identity_axes")
    expected_axes = [
        "signal_identity_sha256",
        "entry_identity_sha256",
        "close_identity_sha256",
        "outcome_sign_sha256",
        "lot_identity_sha256",
        "pnl_identity_sha256",
        "full_stream_sha256",
    ]
    if axes != expected_axes:
        issues.append("SPEC_IDENTITY_AXES_INVALID")
    cost_window = spec.get("cost_evaluation_window")
    if cost_window != {
        "requested_from_date": "2017-10-09",
        "requested_to_date": "2025-12-31",
        "effective_from_date": "2017-10-09",
        "effective_to_date": "2025-12-31",
    }:
        issues.append("SPEC_COST_EVALUATION_WINDOW_INVALID")
    protocol = spec.get("repeat_protocol")
    if not isinstance(protocol, dict) or any(
        protocol.get(key) != value
        for key, value in {
            "baseline_repeat_count": 2,
            "baseline_mode": BASELINE_MODE,
            "baseline_is_qualifying": False,
            "seal_provenance": SEAL_PROVENANCE,
            "seal_is_independent_reference": False,
            "qualification_repeat_count": 2,
            "qualification_mode": QUALIFICATION_MODE,
            "required_receipt_schema_version": 2,
        }.items()
    ):
        issues.append("SPEC_REPEAT_PROTOCOL_INVALID")
    return issues


def validate_spec(spec: Mapping[str, Any], *, verify_anchors: bool = False) -> dict[str, Any]:
    issues = _spec_issues(spec, verify_anchors=verify_anchors)
    if issues:
        return _result("INVALID", issues, owner_decision_required=True)
    return _result(
        "BLOCKED_OWNER_TRUST_AND_RUNTIME_REMEDIATION",
        [],
        valid=True,
        owner_decision_required=True,
        qualification_ready=False,
    )


def _candidate_index(spec: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row["contract_id"]): dict(row)
        for row in spec.get("risk_contract_candidates", [])
        if isinstance(row, dict) and isinstance(row.get("contract_id"), str)
    }


def _validate_binding(binding: Any, label: str) -> tuple[list[str], Path | None, dict[str, Any] | None, str | None]:
    issues: list[str] = []
    if not isinstance(binding, dict):
        return [f"{label}_BINDING_INVALID"], None, None, None
    path_value = binding.get("path")
    declared_sha = binding.get("sha256")
    if not isinstance(path_value, str) or not Path(path_value).is_absolute() or not _valid_sha(declared_sha):
        return [f"{label}_BINDING_INVALID"], None, None, None
    path = Path(path_value)
    if not path.is_file():
        return [f"{label}_FILE_MISSING"], path, None, None
    actual_sha = sha256_file(path)
    if actual_sha != declared_sha:
        issues.append(f"{label}_HASH_MISMATCH")
    payload = _load_object(path)
    if payload is None:
        issues.append(f"{label}_JSON_INVALID")
    return issues, path, payload, actual_sha


def _structured_payload_issues(
    payload: Mapping[str, Any],
    *,
    artifact_type: str,
    hash_field: str = "manifest_payload_sha256",
) -> list[str]:
    issues: list[str] = []
    if payload.get("schema_version") != 1 or payload.get("artifact_type") != artifact_type:
        issues.append("STRUCTURED_ARTIFACT_SCHEMA_INVALID")
    declared = payload.get(hash_field)
    if not _valid_sha(declared) or declared != embedded_hash(payload, hash_field):
        issues.append("STRUCTURED_ARTIFACT_PAYLOAD_HASH_INVALID")
    return issues


def _validate_owner_receipt(
    binding: Any,
    *,
    gate_id: str,
    expected_sha256s: Mapping[str, str] | None,
    spec_sha256: str,
) -> tuple[list[str], Path | None, dict[str, Any] | None, str | None]:
    issues, path, payload, actual_sha = _validate_binding(
        binding, f"OWNER_RECEIPT_{gate_id}"
    )
    externally_expected = (
        str(expected_sha256s.get(gate_id) or "").lower()
        if isinstance(expected_sha256s, Mapping)
        else ""
    )
    if not _valid_sha(externally_expected):
        issues.append(f"OWNER_TRUST_ANCHOR_MISSING:{gate_id}")
    elif actual_sha != externally_expected:
        issues.append(f"OWNER_TRUST_ANCHOR_MISMATCH:{gate_id}")
    if payload is not None:
        structural = _structured_payload_issues(
            payload,
            artifact_type=OWNER_RECEIPT_ARTIFACT_TYPE,
            hash_field="receipt_payload_sha256",
        )
        if structural:
            issues.append(f"OWNER_RECEIPT_STRUCTURE_INVALID:{gate_id}")
        if (
            payload.get("gate_id") != gate_id
            or payload.get("spec_sha256") != spec_sha256
            or payload.get("status") != "APPROVED"
            or payload.get("approved_by") != "OWNER"
            or _parse_utc(payload.get("approved_at_utc")) is None
        ):
            issues.append(f"OWNER_RECEIPT_CONTRACT_INVALID:{gate_id}")
    return issues, path, payload, actual_sha


def _binding_descriptor(binding: Any) -> dict[str, Any] | None:
    if not isinstance(binding, Mapping):
        return None
    path = binding.get("path")
    sha = binding.get("sha256")
    if not isinstance(path, str) or not Path(path).is_absolute() or not _valid_sha(sha):
        return None
    return {"path": str(Path(path).resolve(strict=False)), "sha256": str(sha).lower()}


def _validate_data_manifest(
    binding: Any, spec: Mapping[str, Any]
) -> tuple[list[str], Path | None, dict[str, Any] | None, str | None, str | None, list[Path]]:
    issues, path, payload, actual_sha = _validate_binding(binding, "DATA_MANIFEST")
    control_paths: list[Path] = [path] if path is not None else []
    aggregate_sha: str | None = None
    if payload is None:
        return issues, path, payload, actual_sha, aggregate_sha, control_paths
    if _structured_payload_issues(payload, artifact_type=DATA_MANIFEST_ARTIFACT_TYPE):
        issues.append("DATA_MANIFEST_STRUCTURE_INVALID")
    required_symbols = list(spec["frozen_data_contract"]["required_symbols"])
    required_years = list(spec["frozen_data_contract"]["required_years"])
    if payload.get("required_symbols") != required_symbols or payload.get("required_years") != required_years:
        issues.append("DATA_MANIFEST_SCOPE_INVALID")
    files = payload.get("files")
    expected_keys = {
        (symbol, int(year), kind)
        for symbol in required_symbols
        for year in required_years
        for kind in ("HCC", "TKC")
    }
    observed: set[tuple[str, int, str]] = set()
    snapshot_rows: list[dict[str, Any]] = []
    if not isinstance(files, list):
        issues.append("DATA_MANIFEST_FILES_INVALID")
        files = []
    for index, row in enumerate(files):
        if not isinstance(row, Mapping):
            issues.append(f"DATA_FILE_BINDING_INVALID:{index}")
            continue
        symbol = row.get("symbol")
        year = row.get("year")
        kind = row.get("kind")
        path_value = row.get("path")
        declared_sha = row.get("sha256")
        declared_bytes = row.get("bytes")
        key = (symbol, year, kind)
        if (
            key not in expected_keys
            or key in observed
            or not isinstance(path_value, str)
            or not Path(path_value).is_absolute()
            or not _valid_sha(declared_sha)
            or not isinstance(declared_bytes, int)
            or declared_bytes <= 0
        ):
            issues.append(f"DATA_FILE_BINDING_INVALID:{index}")
            continue
        observed.add(key)  # type: ignore[arg-type]
        bound_path = Path(path_value)
        control_paths.append(bound_path)
        if (
            not bound_path.is_file()
            or sha256_file(bound_path) != declared_sha
            or bound_path.stat().st_size != declared_bytes
        ):
            issues.append(f"DATA_FILE_HASH_OR_SIZE_MISMATCH:{index}")
        snapshot_rows.append(
            {
                "symbol": symbol,
                "year": year,
                "kind": kind,
                "sha256": declared_sha,
                "bytes": declared_bytes,
            }
        )
    if observed != expected_keys:
        issues.append("DATA_MANIFEST_COVERAGE_INCOMPLETE")
    snapshot_rows.sort(key=lambda row: (row["symbol"], row["year"], row["kind"]))
    aggregate_sha = canonical_json_sha(snapshot_rows)
    if payload.get("data_snapshot_sha256") != aggregate_sha:
        issues.append("DATA_SNAPSHOT_HASH_INVALID")
    return issues, path, payload, actual_sha, aggregate_sha, control_paths


def _validate_instrument_manifest(
    binding: Any, spec: Mapping[str, Any]
) -> tuple[list[str], Path | None, dict[str, Any] | None, str | None, str | None, list[Path]]:
    issues, path, payload, actual_sha = _validate_binding(binding, "INSTRUMENT_MANIFEST")
    control_paths: list[Path] = [path] if path is not None else []
    aggregate_sha: str | None = None
    if payload is None:
        return issues, path, payload, actual_sha, aggregate_sha, control_paths
    if _structured_payload_issues(payload, artifact_type=INSTRUMENT_MANIFEST_ARTIFACT_TYPE):
        issues.append("INSTRUMENT_MANIFEST_STRUCTURE_INVALID")
    raw_binding = payload.get("raw_terminal_export")
    raw_issues, raw_path, raw_payload, raw_sha = _validate_binding(
        raw_binding, "INSTRUMENT_RAW_TERMINAL_EXPORT"
    )
    issues.extend(raw_issues)
    if raw_path is not None:
        control_paths.append(raw_path)
    required_symbols = list(spec["frozen_data_contract"]["required_symbols"])
    required_fields = list(
        spec["frozen_data_contract"]["required_instrument_snapshot_fields"]
    )
    snapshot = payload.get("snapshot")
    if (
        not isinstance(snapshot, Mapping)
        or snapshot.get("source") != "DARWINEXZERO_MT5_SERVER"
        or snapshot.get("account_currency") != "EUR"
        or snapshot.get("leverage") != 100
        or _parse_utc(snapshot.get("captured_at_utc")) is None
        or set(snapshot.get("symbols") or {}) != set(required_symbols)
    ):
        issues.append("INSTRUMENT_SNAPSHOT_SCOPE_INVALID")
    else:
        symbols = snapshot.get("symbols") or {}
        for symbol in required_symbols:
            values = symbols.get(symbol)
            if not isinstance(values, Mapping) or set(values) != set(required_fields):
                issues.append(f"INSTRUMENT_FIELDS_INVALID:{symbol}")
                continue
            for field in required_fields:
                value = values.get(field)
                if field in {"account_currency", "profit_currency"}:
                    if not isinstance(value, str) or not value:
                        issues.append(f"INSTRUMENT_FIELD_VALUE_INVALID:{symbol}:{field}")
                elif not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(float(value)) or float(value) <= 0:
                    issues.append(f"INSTRUMENT_FIELD_VALUE_INVALID:{symbol}:{field}")
        canonical_snapshot = {
            "source": snapshot.get("source"),
            "captured_at_utc": snapshot.get("captured_at_utc"),
            "account_currency": snapshot.get("account_currency"),
            "leverage": snapshot.get("leverage"),
            "symbols": snapshot.get("symbols"),
            "raw_terminal_export_sha256": raw_sha,
        }
        aggregate_sha = canonical_json_sha(canonical_snapshot)
        if payload.get("instrument_snapshot_sha256") != aggregate_sha:
            issues.append("INSTRUMENT_SNAPSHOT_HASH_INVALID")
        if raw_payload != dict(snapshot):
            issues.append("INSTRUMENT_RAW_EXPORT_MISMATCH")
    return issues, path, payload, actual_sha, aggregate_sha, control_paths


def _fridays_between(start: dt.date, end: dt.date) -> list[dt.date]:
    cursor = start + dt.timedelta(days=(4 - start.weekday()) % 7)
    values: list[dt.date] = []
    while cursor <= end:
        values.append(cursor)
        cursor += dt.timedelta(days=7)
    return values


def _validate_session_calendar(
    binding: Any, spec: Mapping[str, Any]
) -> tuple[
    list[str],
    Path | None,
    dict[str, Any] | None,
    str | None,
    str | None,
    list[dt.datetime],
    list[Path],
]:
    issues, path, payload, actual_sha = _validate_binding(
        binding, "SESSION_CALENDAR_MANIFEST"
    )
    control_paths: list[Path] = [path] if path is not None else []
    aggregate_sha: str | None = None
    cutoffs: list[dt.datetime] = []
    if payload is None:
        return issues, path, payload, actual_sha, aggregate_sha, cutoffs, control_paths
    if _structured_payload_issues(payload, artifact_type=SESSION_CALENDAR_ARTIFACT_TYPE):
        issues.append("SESSION_CALENDAR_STRUCTURE_INVALID")
    raw_issues, raw_path, raw_payload, raw_sha = _validate_binding(
        payload.get("raw_server_session_export"), "SESSION_CALENDAR_RAW_EXPORT"
    )
    issues.extend(raw_issues)
    if raw_path is not None:
        control_paths.append(raw_path)
    window = spec["cost_evaluation_window"]
    start = dt.date.fromisoformat(str(window["effective_from_date"]))
    end = dt.date.fromisoformat(str(window["effective_to_date"]))
    expected_fridays = _fridays_between(start, end)
    boundaries = payload.get("weekend_boundaries")
    if (
        payload.get("source") != "DARWINEXZERO_MT5_SERVER_BOUND_SESSION_EXPORT"
        or payload.get("timezone_basis") != "MT5_BROKER_TIME"
        or payload.get("effective_from_date") != start.isoformat()
        or payload.get("effective_to_date") != end.isoformat()
        or not isinstance(boundaries, list)
    ):
        issues.append("SESSION_CALENDAR_SCOPE_INVALID")
        boundaries = []
    canonical_rows: list[dict[str, Any]] = []
    observed_fridays: list[dt.date] = []
    for index, row in enumerate(boundaries):
        if not isinstance(row, Mapping):
            issues.append(f"SESSION_BOUNDARY_INVALID:{index}")
            continue
        try:
            friday = dt.date.fromisoformat(str(row.get("week_ending_friday")))
            cutoff = dt.datetime.strptime(
                str(row.get("last_tradable_broker_time")), "%Y.%m.%d %H:%M:%S"
            )
        except ValueError:
            issues.append(f"SESSION_BOUNDARY_INVALID:{index}")
            continue
        nominal = dt.datetime.combine(friday, dt.time(21, 0))
        monday = nominal - dt.timedelta(days=4, hours=21)
        if (
            friday.weekday() != 4
            or cutoff < monday
            or cutoff > nominal
            or row.get("effective_cutoff_rule")
            != "MIN_FRIDAY_21_AND_LAST_TRADABLE_BEFORE_WEEKEND"
        ):
            issues.append(f"SESSION_BOUNDARY_SEMANTICS_INVALID:{index}")
        observed_fridays.append(friday)
        card_cutoff = dt.datetime.combine(friday, dt.time(18, 30))
        cutoffs.append(min(cutoff, card_cutoff))
        canonical_rows.append(
            {
                "week_ending_friday": friday.isoformat(),
                "last_tradable_broker_time": cutoff.strftime("%Y.%m.%d %H:%M:%S"),
                "effective_cutoff_rule": row.get("effective_cutoff_rule"),
            }
        )
    if observed_fridays != expected_fridays:
        issues.append("SESSION_CALENDAR_WEEKLY_COVERAGE_INCOMPLETE")
    aggregate_sha = canonical_json_sha(
        {"raw_server_session_export_sha256": raw_sha, "weekend_boundaries": canonical_rows}
    )
    if payload.get("session_calendar_sha256") != aggregate_sha:
        issues.append("SESSION_CALENDAR_HASH_INVALID")
    expected_raw = {
        "source": payload.get("source"),
        "timezone_basis": payload.get("timezone_basis"),
        "effective_from_date": payload.get("effective_from_date"),
        "effective_to_date": payload.get("effective_to_date"),
        "weekend_boundaries": boundaries,
    }
    if raw_payload != expected_raw:
        issues.append("SESSION_CALENDAR_RAW_EXPORT_MISMATCH")
    return (
        issues,
        path,
        payload,
        actual_sha,
        aggregate_sha,
        cutoffs,
        control_paths,
    )


def _native_report_rows(
    report_path: Path, symbol: str
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    native_metrics, fallback_rows = requal_runner._parse_native_report(report_path, symbol)
    execution = requal_runner.parse_native_report_execution_evidence(report_path)
    round_trips, stats = native_cost_parser.extract_round_trips(report_path)
    if not execution.get("real_ticks_certified"):
        raise ValueError("native report is not 100% real ticks")
    if stats.get("host_symbol") != symbol or stats.get("account_currency") != "EUR":
        raise ValueError("native report symbol/currency mismatch")
    if len(fallback_rows) != len(round_trips) or not round_trips:
        raise ValueError("native parser round-trip count mismatch")
    for fallback, trade in zip(fallback_rows, round_trips, strict=True):
        expected_close = dt.datetime.strptime(
            trade.exit_time, "%Y.%m.%d %H:%M:%S"
        ).replace(tzinfo=dt.timezone.utc)
        fallback_close = _parse_utc(fallback.get("ts_utc"))
        fallback_net = _decimal(fallback.get("net"))
        expected_net = (
            Decimal(str(trade.gross_pnl))
            + Decimal(str(trade.recorded_swap))
            + Decimal(str(trade.native_commission))
        )
        if fallback_close != expected_close or fallback_net != expected_net:
            raise ValueError("native parsers disagree on close time or net PnL")
    rows: list[dict[str, Any]] = []
    for trade in round_trips:
        if trade.symbol != symbol:
            raise ValueError("native report contains an unexpected traded symbol")
        gross = Decimal(str(trade.gross_pnl))
        swap = Decimal(str(trade.recorded_swap))
        commission = Decimal(str(trade.native_commission))
        rows.append(
            {
                "symbol": trade.symbol,
                "side": str(trade.side).upper(),
                "entry_time_mt5_server": trade.entry_time,
                "exit_time_mt5_server": trade.exit_time,
                "entry_deal": trade.entry_deal,
                "exit_deal": trade.exit_deal,
                "volume": _decimal_text(trade.volume),
                "entry_price": _decimal_text(trade.entry_price),
                "exit_price": _decimal_text(trade.exit_price),
                "gross_pnl": _decimal_text(gross),
                "recorded_swap": _decimal_text(swap),
                "native_commission": _decimal_text(commission),
                "net_pnl": _decimal_text(gross + swap + commission),
                "outcome_sign": 1 if gross > 0 else -1 if gross < 0 else 0,
            }
        )
    native_metrics_contract = {
        key: native_metrics.get(key)
        for key in (
            "basis",
            "symbol",
            "symbols",
            "period",
            "start_date",
            "end_date",
            "closed_trades",
            "report_net",
            "gross_profit",
            "gross_loss",
            "pf",
            "equity_drawdown",
            "equity_drawdown_pct",
            "host_symbol",
            "execution_evidence",
        )
    }
    compact_metrics = {
        "currency": stats.get("account_currency"),
        "history_quality": execution.get("history_quality_normalized"),
        "bars": execution.get("bars"),
        "ticks": execution.get("ticks"),
        "symbol_count": execution.get("symbol_count"),
        "trade_count": len(rows),
        "net_profit": _decimal_text(sum(Decimal(row["net_pnl"]) for row in rows)),
        "gross_profit": _decimal_text(sum(max(Decimal(row["gross_pnl"]), Decimal("0")) for row in rows)),
        "gross_loss": _decimal_text(sum(min(Decimal(row["gross_pnl"]), Decimal("0")) for row in rows)),
        "native_parser_metrics_sha256": canonical_json_sha(native_metrics_contract),
    }
    return rows, compact_metrics


def _identity_digests(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    signal = [[r["symbol"], r["side"], r["entry_time_mt5_server"]] for r in rows]
    entry = [[r["symbol"], r["side"], r["entry_time_mt5_server"], r["entry_price"], r["volume"]] for r in rows]
    close = [[r["symbol"], r["exit_time_mt5_server"], r["exit_price"]] for r in rows]
    outcome = [[r["symbol"], r["entry_time_mt5_server"], r["outcome_sign"]] for r in rows]
    lots = [[r["symbol"], r["entry_time_mt5_server"], r["volume"]] for r in rows]
    pnl = [[r["symbol"], r["exit_time_mt5_server"], r["gross_pnl"], r["recorded_swap"], r["native_commission"], r["net_pnl"]] for r in rows]
    return {
        "trade_count": len(rows),
        "signal_identity_sha256": canonical_json_sha(signal),
        "entry_identity_sha256": canonical_json_sha(entry),
        "close_identity_sha256": canonical_json_sha(close),
        "outcome_sign_sha256": canonical_json_sha(outcome),
        "lot_identity_sha256": canonical_json_sha(lots),
        "pnl_identity_sha256": canonical_json_sha(pnl),
        "full_stream_sha256": hashlib.sha256(_canonical_jsonl(rows)).hexdigest(),
    }


def _receipt_issues(
    spec: Mapping[str, Any],
    receipt_path: Path,
    receipt: Mapping[str, Any],
    *,
    phase: str,
    selected_candidate: Mapping[str, Any],
    sealed_input_manifest_sha256: str | None,
    data_manifest_sha256: str | None,
    data_snapshot_sha256: str | None,
    instrument_manifest_sha256: str | None,
    instrument_snapshot_sha256: str | None,
    session_calendar_manifest_sha256: str | None,
    session_calendar_sha256: str | None,
    session_cutoffs: Sequence[dt.datetime],
) -> tuple[list[str], dict[str, Any]]:
    issues: list[str] = []
    tag = str(receipt.get("run_id") or phase)
    if receipt.get("schema_version") != 2 or receipt.get("artifact_type") != RECEIPT_ARTIFACT_TYPE:
        issues.append(f"RECEIPT_SCHEMA_INVALID:{tag}")
    run_root_value = receipt.get("run_root")
    if not isinstance(run_root_value, str) or not Path(run_root_value).is_absolute():
        issues.append(f"RUN_ROOT_INVALID:{tag}")
        run_root = receipt_path.parent
    else:
        run_root = Path(run_root_value)
        if (
            not run_root.is_dir()
            or not _within(receipt_path, run_root)
            or _path_id(receipt_path.parent) != _path_id(run_root)
        ):
            issues.append(f"RECEIPT_OUTSIDE_RUN_ROOT:{tag}")
        if _is_forbidden_tier_path(run_root):
            issues.append(f"FORBIDDEN_MT5_RUN_ROOT:{tag}")
    execution_id = receipt.get("execution_id")
    sandbox_id = receipt.get("sandbox_id")
    output_root_value = receipt.get("output_root")
    if not isinstance(execution_id, str) or SAFE_ID_RE.fullmatch(execution_id) is None:
        issues.append(f"EXECUTION_ID_INVALID:{tag}")
    if not isinstance(sandbox_id, str) or SAFE_ID_RE.fullmatch(sandbox_id) is None:
        issues.append(f"SANDBOX_ID_INVALID:{tag}")
    if (
        not isinstance(output_root_value, str)
        or not Path(output_root_value).is_absolute()
        or _path_id(Path(output_root_value)) != _path_id(run_root)
    ):
        issues.append(f"OUTPUT_ROOT_INVALID:{tag}")

    started = _parse_utc(receipt.get("started_utc"))
    finished = _parse_utc(receipt.get("finished_utc"))
    if started is None or finished is None or started >= finished:
        issues.append(f"RUN_TIMESTAMPS_INVALID:{tag}")

    if phase == "BASELINE":
        if (
            receipt.get("phase") != "BASELINE"
            or receipt.get("qualification_mode") != BASELINE_MODE
            or receipt.get("qualifying") is not False
            or receipt.get("technical_status") != BASELINE_MODE
            or receipt.get("selected_reference") is not None
        ):
            issues.append(f"BASELINE_MODE_OR_REFERENCE_INVALID:{tag}")
    else:
        if (
            receipt.get("phase") != "QUALIFICATION"
            or receipt.get("qualification_mode") != QUALIFICATION_MODE
            or receipt.get("qualifying") is not True
            or receipt.get("technical_status") != "PASS"
            or not isinstance(receipt.get("selected_reference"), dict)
        ):
            issues.append(f"QUALIFICATION_MODE_OR_REFERENCE_INVALID:{tag}")

    contract = receipt.get("contract")
    if not isinstance(contract, dict):
        issues.append(f"CONTRACT_INVALID:{tag}")
        contract = {}
    scope = spec["scope"]
    expected_static = {
        "ea_id": scope["ea_id"],
        "symbol": scope["symbol"],
        "timeframe": scope["timeframe"],
        "magic": scope["magic"],
        "model": 4,
        "deposit_currency": "EUR",
        "initial_deposit": "100000",
        "leverage": 100,
        "risk_contract_id": selected_candidate.get("contract_id"),
        "RISK_PERCENT": selected_candidate.get("RISK_PERCENT"),
        "RISK_FIXED": selected_candidate.get("RISK_FIXED"),
        "PORTFOLIO_WEIGHT": selected_candidate.get("PORTFOLIO_WEIGHT"),
        "effective_risk_percent": selected_candidate.get("effective_risk_percent"),
        "artifact_sha256s": spec["contract_artifact_sha256s"],
        "data_symbols": spec["frozen_data_contract"]["required_symbols"],
        "segment_contract_sha256": canonical_json_sha(
            {"segments": spec["segments"], "rules": spec["segment_execution_rules"]}
        ),
        "sealed_input_manifest_sha256": sealed_input_manifest_sha256,
        "data_manifest_sha256": data_manifest_sha256,
        "data_snapshot_sha256": data_snapshot_sha256,
        "instrument_manifest_sha256": instrument_manifest_sha256,
        "instrument_snapshot_sha256": instrument_snapshot_sha256,
        "session_calendar_manifest_sha256": session_calendar_manifest_sha256,
        "session_calendar_sha256": session_calendar_sha256,
    }
    if any(contract.get(key) != value for key, value in expected_static.items()):
        issues.append(f"CONTRACT_STATIC_FIELDS_MISMATCH:{tag}")
    for field in (
        "data_manifest_sha256",
        "data_snapshot_sha256",
        "instrument_manifest_sha256",
        "instrument_snapshot_sha256",
        "session_calendar_manifest_sha256",
        "session_calendar_sha256",
    ):
        if not _valid_sha(contract.get(field)):
            issues.append(f"CONTRACT_DYNAMIC_HASH_INVALID:{tag}:{field}")
    risk_percent = _decimal(contract.get("RISK_PERCENT"))
    portfolio_weight = _decimal(contract.get("PORTFOLIO_WEIGHT"))
    effective_risk = _decimal(contract.get("effective_risk_percent"))
    if (
        risk_percent is None
        or portfolio_weight != Decimal("1")
        or effective_risk is None
        or effective_risk != risk_percent * portfolio_weight
    ):
        issues.append(f"EFFECTIVE_RISK_MUST_BIND_PORTFOLIO_WEIGHT_ONE:{tag}")
    declared_contract_sha = receipt.get("contract_sha256")
    if not _valid_sha(declared_contract_sha) or declared_contract_sha != canonical_json_sha(contract):
        issues.append(f"CONTRACT_HASH_INVALID:{tag}")

    expected_sweep = dict(spec["contract_artifact_sha256s"])
    expected_sweep.update(
        {
            "data_manifest": contract.get("data_manifest_sha256"),
            "data_snapshot": contract.get("data_snapshot_sha256"),
            "instrument_manifest": contract.get("instrument_manifest_sha256"),
            "instrument_snapshot": contract.get("instrument_snapshot_sha256"),
            "session_calendar_manifest": contract.get("session_calendar_manifest_sha256"),
            "session_calendar": contract.get("session_calendar_sha256"),
            "segment_contract": expected_static["segment_contract_sha256"],
        }
    )
    sweep = receipt.get("immutable_input_sweep")
    if (
        not isinstance(sweep, dict)
        or sweep.get("unchanged") is not True
        or sweep.get("hashes_start") != expected_sweep
        or sweep.get("hashes_end") != expected_sweep
    ):
        issues.append(f"IMMUTABLE_INPUT_SWEEP_INVALID:{tag}")

    axes = list(spec["identity_axes"])
    aggregate = receipt.get("aggregate")
    generated_paths: list[Path] = [receipt_path]
    if not isinstance(aggregate, dict):
        issues.append(f"AGGREGATE_INVALID:{tag}")
        aggregate = {}

    report_value = receipt.get("report_path")
    report_sha = receipt.get("report_sha256")
    report_path: Path | None = None
    derived_rows: list[dict[str, Any]] = []
    derived_metrics: dict[str, Any] = {}
    if not isinstance(report_value, str) or not Path(report_value).is_absolute() or not _valid_sha(report_sha):
        issues.append(f"REPORT_BINDING_INVALID:{tag}")
    else:
        report_path = Path(report_value)
        generated_paths.append(report_path)
        if (
            not report_path.is_file()
            or not _within(report_path, run_root)
            or _path_id(report_path.parent) != _path_id(run_root)
            or sha256_file(report_path) != report_sha
        ):
            issues.append(f"REPORT_BINDING_INVALID:{tag}")
        else:
            try:
                derived_rows, derived_metrics = _native_report_rows(report_path, "GBPUSD.DWX")
            except (OSError, UnicodeError, ValueError, native_cost_parser.CostEvidenceError) as exc:
                issues.append(f"NATIVE_REPORT_PARSE_INVALID:{tag}:{type(exc).__name__}")

    derived_aggregate = _identity_digests(derived_rows)
    if not derived_rows:
        issues.append(f"AGGREGATE_TRADE_COUNT_INVALID:{tag}")
    if any(aggregate.get(key) != value for key, value in derived_aggregate.items()):
        issues.append(f"AGGREGATE_IDENTITY_NOT_DERIVED_FROM_NATIVE_REPORT:{tag}")
    metrics = receipt.get("report_metrics")
    if metrics != derived_metrics:
        issues.append(f"REPORT_METRICS_NOT_DERIVED_FROM_NATIVE_REPORT:{tag}")
    trade_count = derived_aggregate["trade_count"]
    stream_value = aggregate.get("stream_path")
    if not isinstance(stream_value, str) or not Path(stream_value).is_absolute():
        issues.append(f"AGGREGATE_STREAM_PATH_INVALID:{tag}")
    else:
        stream_path = Path(stream_value)
        generated_paths.append(stream_path)
        if (
            not stream_path.is_file()
            or not _within(stream_path, run_root)
            or _path_id(stream_path.parent) != _path_id(run_root)
            or stream_path.read_bytes() != _canonical_jsonl(derived_rows)
            or sha256_file(stream_path) != derived_aggregate["full_stream_sha256"]
        ):
            issues.append(f"AGGREGATE_STREAM_NOT_DERIVED_FROM_NATIVE_REPORT:{tag}")

    expected_segments = {row["segment_id"]: row for row in spec["segments"]}
    segments = receipt.get("segments")
    segment_trade_sum = 0
    segment_roots: list[Path] = []
    segment_rows: list[dict[str, Any]] = []
    if not isinstance(segments, list) or len(segments) != 4:
        issues.append(f"SEGMENTS_INVALID:{tag}")
        segments = []
    seen_segment_ids: set[str] = set()
    for segment in segments:
        if not isinstance(segment, dict) or segment.get("segment_id") not in expected_segments:
            issues.append(f"SEGMENT_ID_INVALID:{tag}")
            continue
        segment_id = segment["segment_id"]
        if segment_id in seen_segment_ids:
            issues.append(f"SEGMENT_ID_DUPLICATE:{tag}:{segment_id}")
        seen_segment_ids.add(segment_id)
        expected = expected_segments[segment_id]
        for field in (
            "tester_from_date",
            "tester_to_date",
            "score_from_utc",
            "score_to_exclusive_utc",
        ):
            if segment.get(field) != expected[field]:
                issues.append(f"SEGMENT_WINDOW_MISMATCH:{tag}:{segment_id}")
        segment_root_value = segment.get("segment_root")
        segment_root: Path | None = None
        if not isinstance(segment_root_value, str) or not Path(segment_root_value).is_absolute():
            issues.append(f"SEGMENT_ROOT_INVALID:{tag}:{segment_id}")
        else:
            segment_root = Path(segment_root_value)
            segment_roots.append(segment_root)
            expected_segment_root = run_root / "segments" / segment_id
            if (
                not segment_root.is_dir()
                or not _within(segment_root, run_root)
                or _path_id(segment_root) == _path_id(run_root)
                or _path_id(segment_root) != _path_id(expected_segment_root)
            ):
                issues.append(f"SEGMENT_ROOT_INVALID:{tag}:{segment_id}")
        if (
            segment.get("start_flat") is not True
            or segment.get("end_flat") is not True
            or segment.get("cross_gap_position_count") != 0
            or segment.get("cross_gap_pending_order_count") != 0
            or segment.get("tester_forced_exit_count") != 0
            or segment.get("state_carried_from_previous_segment") is not False
        ):
            issues.append(f"SEGMENT_SEAM_STATE_INVALID:{tag}:{segment_id}")

        segment_report_value = segment.get("report_path")
        segment_report_sha = segment.get("report_sha256")
        parsed_segment_rows: list[dict[str, Any]] = []
        if (
            not isinstance(segment_report_value, str)
            or not Path(segment_report_value).is_absolute()
            or not _valid_sha(segment_report_sha)
            or segment_root is None
        ):
            issues.append(f"SEGMENT_REPORT_BINDING_INVALID:{tag}:{segment_id}")
        else:
            segment_report_path = Path(segment_report_value)
            generated_paths.append(segment_report_path)
            if (
                not segment_report_path.is_file()
                or not _within(segment_report_path, segment_root)
                or _path_id(segment_report_path.parent) != _path_id(segment_root)
                or sha256_file(segment_report_path) != segment_report_sha
            ):
                issues.append(f"SEGMENT_REPORT_BINDING_INVALID:{tag}:{segment_id}")
            else:
                try:
                    parsed_segment_rows, _ = _native_report_rows(
                        segment_report_path, "GBPUSD.DWX"
                    )
                except (OSError, UnicodeError, ValueError, native_cost_parser.CostEvidenceError) as exc:
                    issues.append(
                        f"SEGMENT_NATIVE_REPORT_PARSE_INVALID:{tag}:{segment_id}:{type(exc).__name__}"
                    )
        segment_digest = _identity_digests(parsed_segment_rows)
        score_start = _parse_utc(expected.get("score_from_utc"))
        score_end = _parse_utc(expected.get("score_to_exclusive_utc"))
        for parsed_row in parsed_segment_rows:
            try:
                entry_broker_time = dt.datetime.strptime(
                    str(parsed_row["entry_time_mt5_server"]), "%Y.%m.%d %H:%M:%S"
                )
                exit_broker_time = dt.datetime.strptime(
                    str(parsed_row["exit_time_mt5_server"]), "%Y.%m.%d %H:%M:%S"
                )
                entry_time = entry_broker_time.replace(tzinfo=dt.timezone.utc)
                exit_time = exit_broker_time.replace(tzinfo=dt.timezone.utc)
            except (KeyError, ValueError):
                issues.append(f"SEGMENT_NATIVE_TIME_INVALID:{tag}:{segment_id}")
                continue
            if (
                score_start is None
                or score_end is None
                or not (score_start <= entry_time <= exit_time < score_end)
            ):
                issues.append(f"SEGMENT_NATIVE_TRADE_OUTSIDE_SCORE_WINDOW:{tag}:{segment_id}")
            if not session_cutoffs or _weekend_policy_violation(
                entry_broker_time, exit_broker_time, session_cutoffs
            ):
                issues.append(
                    f"OWNER_EFFECTIVE_WEEKEND_FLAT_DEADLINE_VIOLATION:{tag}:{segment_id}"
                )
        if any(segment.get(key) != value for key, value in segment_digest.items()):
            issues.append(f"SEGMENT_IDENTITY_NOT_DERIVED_FROM_NATIVE_REPORT:{tag}:{segment_id}")
        segment_stream_value = segment.get("stream_path")
        if (
            not isinstance(segment_stream_value, str)
            or not Path(segment_stream_value).is_absolute()
            or segment_root is None
        ):
            issues.append(f"SEGMENT_STREAM_INVALID:{tag}:{segment_id}")
        else:
            segment_stream = Path(segment_stream_value)
            generated_paths.append(segment_stream)
            if (
                not segment_stream.is_file()
                or not _within(segment_stream, segment_root)
                or _path_id(segment_stream.parent) != _path_id(segment_root)
                or segment_stream.read_bytes() != _canonical_jsonl(parsed_segment_rows)
                or sha256_file(segment_stream) != segment_digest["full_stream_sha256"]
            ):
                issues.append(f"SEGMENT_STREAM_NOT_DERIVED_FROM_NATIVE_REPORT:{tag}:{segment_id}")
        segment_trade_sum += len(parsed_segment_rows)
        segment_rows.extend(parsed_segment_rows)
    for index, left in enumerate(segment_roots):
        for right in segment_roots[index + 1 :]:
            if _paths_overlap_or_nested(left, right):
                issues.append(f"SEGMENT_ROOTS_NOT_DISTINCT_OR_NESTED:{tag}")
    if segment_trade_sum != trade_count or segment_rows != derived_rows:
        issues.append(f"SEGMENT_ROWS_DO_NOT_RECONSTRUCT_AGGREGATE:{tag}")
    generated_ids = [_path_id(path) for path in generated_paths]
    if len(generated_ids) != len(set(generated_ids)):
        issues.append(f"GENERATED_ARTIFACT_PATH_COLLISION:{tag}")

    costs = receipt.get("cost_axes")
    required_costs = set(spec["required_cost_axes"])
    cost_certified = False
    if not isinstance(costs, dict) or set(costs) != required_costs:
        issues.append(f"COST_AXES_INVALID:{tag}")
    else:
        for axis, evidence in costs.items():
            if not isinstance(evidence, dict) or evidence.get("status") not in {"OPEN", "FAIL"}:
                issues.append(f"COST_AXIS_STATUS_INVALID:{tag}:{axis}")

    run_identity = {
        "execution_id": execution_id,
        "sandbox_id": sandbox_id,
        "output_root": str(run_root.resolve(strict=False)),
        "contract_sha256": declared_contract_sha,
    }
    if receipt.get("run_identity_sha256") != canonical_json_sha(run_identity):
        issues.append(f"RUN_IDENTITY_HASH_INVALID:{tag}")

    metadata = {
        "tag": tag,
        "path": receipt_path,
        "run_root": run_root,
        "output_root": Path(output_root_value) if isinstance(output_root_value, str) else run_root,
        "execution_id": execution_id,
        "sandbox_id": sandbox_id,
        "run_identity_sha256": receipt.get("run_identity_sha256"),
        "started": started,
        "finished": finished,
        "contract_sha256": declared_contract_sha,
        "contract": contract,
        "aggregate": derived_aggregate,
        "report_metrics_sha256": canonical_json_sha(derived_metrics),
        "selected_reference": receipt.get("selected_reference"),
        "generated_paths": generated_paths,
        "cost_axes": costs,
        "cost_certified": cost_certified,
    }
    return issues, metadata


def validate_evidence(
    spec: Mapping[str, Any],
    bundle: Mapping[str, Any],
    *,
    spec_path: Path | None = None,
    verify_anchors: bool = False,
    expected_owner_receipt_sha256s: Mapping[str, str] | None = None,
) -> dict[str, Any]:
    issues = _spec_issues(spec, verify_anchors=verify_anchors)
    if bundle.get("schema_version") != 1 or bundle.get("artifact_type") != BUNDLE_ARTIFACT_TYPE:
        issues.append("EVIDENCE_BUNDLE_SCHEMA_INVALID")
    bound_spec_sha = sha256_file(spec_path) if spec_path is not None else str(bundle.get("spec_sha256") or "")
    if spec_path is not None:
        if (
            bundle.get("spec_path") != str(spec_path.resolve(strict=False))
            or bundle.get("spec_sha256") != sha256_file(spec_path)
        ):
            issues.append("EVIDENCE_SPEC_BINDING_INVALID")
    elif not _valid_sha(bundle.get("spec_sha256")):
        issues.append("EVIDENCE_SPEC_BINDING_INVALID")

    owner_receipt_bindings = bundle.get("owner_receipts")
    owner_receipts: dict[str, dict[str, Any]] = {}
    owner_receipt_paths: list[Path] = []
    if not isinstance(owner_receipt_bindings, Mapping) or set(owner_receipt_bindings) != set(OWNER_GATES):
        issues.append("OWNER_RECEIPT_SET_INVALID")
        owner_receipt_bindings = {}
    for gate_id in OWNER_GATES:
        receipt_issues, receipt_path, receipt_payload, _ = _validate_owner_receipt(
            owner_receipt_bindings.get(gate_id),
            gate_id=gate_id,
            expected_sha256s=expected_owner_receipt_sha256s,
            spec_sha256=bound_spec_sha,
        )
        issues.extend(receipt_issues)
        if receipt_path is not None:
            owner_receipt_paths.append(receipt_path)
        if receipt_payload is not None:
            owner_receipts[gate_id] = receipt_payload

    decision = bundle.get("owner_decision")
    candidates = _candidate_index(spec)
    selected: dict[str, Any] = {}
    decision_time: dt.datetime | None = None
    if not isinstance(decision, dict):
        issues.append("OWNER_DECISION_MISSING")
    else:
        decision_sha = decision.get("decision_sha256")
        decision_time = _parse_utc(decision.get("approved_at_utc"))
        selected = candidates.get(str(decision.get("selected_contract_id")), {})
        risk_receipt = owner_receipts.get("RISK_CONTRACT") or {}
        if (
            decision.get("status") != "APPROVED"
            or decision.get("approved_by") != "OWNER"
            or decision_time is None
            or not _valid_sha(decision_sha)
            or decision_sha != embedded_hash(decision, "decision_sha256")
            or not selected
            or risk_receipt.get("decision") != {
                "selected_contract_id": decision.get("selected_contract_id"),
                "authorization_scope": decision.get("authorization_scope"),
            }
            or risk_receipt.get("approved_at_utc") != decision.get("approved_at_utc")
        ):
            issues.append("OWNER_DECISION_INVALID")
        elif selected.get("owner_selectable") is not True:
            issues.append("OWNER_SELECTION_REJECTED_DIMENSIONAL_DOUBLE_SCALING")
        elif selected.get("current_anchor_compatible") is not True:
            issues.append("OWNER_SELECTION_REQUIRES_NEW_PRESET_REBASE_SPEC")

    (
        data_issues,
        data_manifest_path,
        _data_manifest,
        data_manifest_sha,
        data_snapshot_sha,
        data_control_paths,
    ) = _validate_data_manifest(bundle.get("data_manifest"), spec)
    issues.extend(data_issues)
    (
        instrument_issues,
        instrument_manifest_path,
        _instrument_manifest,
        instrument_manifest_sha,
        instrument_snapshot_sha,
        instrument_control_paths,
    ) = _validate_instrument_manifest(bundle.get("instrument_manifest"), spec)
    issues.extend(instrument_issues)
    (
        session_issues,
        session_calendar_path,
        _session_calendar,
        session_calendar_manifest_sha,
        session_calendar_sha,
        session_cutoffs,
        session_control_paths,
    ) = _validate_session_calendar(bundle.get("session_calendar_manifest"), spec)
    issues.extend(session_issues)

    sealed_input_path: Path | None = None
    sealed_input: dict[str, Any] | None = None
    sealed_input_sha: str | None = None
    sealed_input_time: dt.datetime | None = None
    input_issues, sealed_input_path, sealed_input, sealed_input_sha = _validate_binding(
        bundle.get("sealed_input_manifest"), "SEALED_INPUT_MANIFEST"
    )
    issues.extend(input_issues)
    if sealed_input is not None:
        sealed_input_time = _parse_utc(sealed_input.get("sealed_at_utc"))
        template = sealed_input.get("contract_template")
        sealed_bindings = sealed_input.get("bindings")
        expected_risk = {
            "contract_id": selected.get("contract_id"),
            "RISK_PERCENT": selected.get("RISK_PERCENT"),
            "RISK_FIXED": selected.get("RISK_FIXED"),
            "PORTFOLIO_WEIGHT": selected.get("PORTFOLIO_WEIGHT"),
            "effective_risk_percent": selected.get("effective_risk_percent"),
        }
        expected_bindings = {
            "data_manifest": _binding_descriptor(bundle.get("data_manifest")),
            "instrument_manifest": _binding_descriptor(bundle.get("instrument_manifest")),
            "session_calendar_manifest": _binding_descriptor(
                bundle.get("session_calendar_manifest")
            ),
            "owner_risk_receipt": _binding_descriptor(owner_receipt_bindings.get("RISK_CONTRACT")),
            "owner_input_receipt": _binding_descriptor(owner_receipt_bindings.get("SEALED_INPUT")),
        }
        input_approval = owner_receipts.get("SEALED_INPUT") or {}
        approved_object = canonical_json_sha(
            {
                "contract_template": template,
                "bindings": {
                    key: value
                    for key, value in expected_bindings.items()
                    if key != "owner_input_receipt"
                },
                "selected_risk_contract": expected_risk,
            }
        )
        if (
            sealed_input.get("schema_version") != 1
            or sealed_input.get("artifact_type") != SEALED_INPUT_ARTIFACT_TYPE
            or _structured_payload_issues(sealed_input, artifact_type=SEALED_INPUT_ARTIFACT_TYPE)
            or sealed_input_time is None
            or sealed_input.get("owner_decision_sha256")
            != (decision.get("decision_sha256") if isinstance(decision, dict) else None)
            or sealed_input.get("selected_risk_contract") != expected_risk
            or not isinstance(template, dict)
            or sealed_input.get("contract_template_sha256") != canonical_json_sha(template)
            or sealed_bindings != expected_bindings
            or input_approval.get("approved_object_sha256") != approved_object
        ):
            issues.append("SEALED_INPUT_MANIFEST_CONTRACT_INVALID")

    all_meta: list[dict[str, Any]] = []
    phase_meta: dict[str, list[dict[str, Any]]] = {"BASELINE": [], "QUALIFICATION": []}
    receipt_hashes: list[str] = []
    for phase, field in (
        ("BASELINE", "baseline_receipts"),
        ("QUALIFICATION", "qualification_receipts"),
    ):
        bindings = bundle.get(field)
        if not isinstance(bindings, list) or len(bindings) != 2:
            issues.append(f"{phase}_RECEIPT_COUNT_INVALID")
            continue
        for index, binding in enumerate(bindings):
            binding_issues, path, receipt, actual_sha = _validate_binding(
                binding, f"{phase}_RECEIPT_{index + 1}"
            )
            issues.extend(binding_issues)
            if actual_sha is not None:
                receipt_hashes.append(actual_sha)
            if path is None or receipt is None or not selected:
                continue
            receipt_issues, meta = _receipt_issues(
                spec,
                path,
                receipt,
                phase=phase,
                selected_candidate=selected,
                sealed_input_manifest_sha256=sealed_input_sha,
                data_manifest_sha256=data_manifest_sha,
                data_snapshot_sha256=data_snapshot_sha,
                instrument_manifest_sha256=instrument_manifest_sha,
                instrument_snapshot_sha256=instrument_snapshot_sha,
                session_calendar_manifest_sha256=session_calendar_manifest_sha,
                session_calendar_sha256=session_calendar_sha,
                session_cutoffs=session_cutoffs,
            )
            issues.extend(receipt_issues)
            meta["receipt_sha256"] = actual_sha
            all_meta.append(meta)
            phase_meta[phase].append(meta)

    run_root_paths = [meta["run_root"] for meta in all_meta]
    roots = [_path_id(path) for path in run_root_paths]
    if len(roots) != 4 or any(
        _paths_overlap_or_nested(left, right)
        for index, left in enumerate(run_root_paths)
        for right in run_root_paths[index + 1 :]
    ):
        issues.append("RUN_ROOTS_NOT_PAIRWISE_DISTINCT_OR_NESTED")
    output_root_paths = [meta["output_root"] for meta in all_meta]
    output_roots = [_path_id(path) for path in output_root_paths]
    execution_ids = [str(meta.get("execution_id") or "").casefold() for meta in all_meta]
    sandbox_ids = [str(meta.get("sandbox_id") or "").casefold() for meta in all_meta]
    if len(output_roots) != 4 or any(
        _paths_overlap_or_nested(left, right)
        for index, left in enumerate(output_root_paths)
        for right in output_root_paths[index + 1 :]
    ):
        issues.append("OUTPUT_ROOTS_NOT_GLOBALLY_DISTINCT_OR_NESTED")
    if len(execution_ids) != 4 or len(set(execution_ids)) != 4:
        issues.append("EXECUTION_IDS_NOT_GLOBALLY_CASEFOLD_DISTINCT")
    if len(sandbox_ids) != 4 or len(set(sandbox_ids)) != 4:
        issues.append("SANDBOX_IDS_NOT_GLOBALLY_CASEFOLD_DISTINCT")
    if len(receipt_hashes) != 4 or len(set(receipt_hashes)) != 4:
        issues.append("RECEIPT_HASHES_NOT_PAIRWISE_DISTINCT")
    global_generated_paths = [path for meta in all_meta for path in meta["generated_paths"]]
    global_generated_ids = [_path_id(path) for path in global_generated_paths]
    if len(global_generated_ids) != len(set(global_generated_ids)):
        issues.append("GENERATED_ARTIFACT_PATHS_NOT_GLOBALLY_DISTINCT")

    if len(all_meta) == 4:
        contract_hashes = {meta.get("contract_sha256") for meta in all_meta}
        if len(contract_hashes) != 1 or not all(_valid_sha(value) for value in contract_hashes):
            issues.append("REPEAT_CONTRACT_HASH_MISMATCH")
        for axis in spec["identity_axes"]:
            values = {meta["aggregate"].get(axis) for meta in all_meta}
            if len(values) != 1 or not all(_valid_sha(value) for value in values):
                issues.append(f"REPEAT_IDENTITY_HASH_MISMATCH:{axis}")
        metric_hashes = {meta.get("report_metrics_sha256") for meta in all_meta}
        if len(metric_hashes) != 1:
            issues.append("REPEAT_REPORT_METRICS_MISMATCH")
        if sealed_input is not None:
            templates = []
            for meta in all_meta:
                template = dict(meta["contract"])
                template.pop("sealed_input_manifest_sha256", None)
                templates.append(template)
            if (
                any(template != sealed_input.get("contract_template") for template in templates)
                or len({canonical_json_sha(template) for template in templates}) != 1
            ):
                issues.append("RECEIPT_CONTRACT_NOT_BOUND_BY_SEALED_INPUT")

    frozen = bundle.get("frozen_reference")
    reference_path: Path | None = None
    reference_sha: str | None = None
    seal_path: Path | None = None
    seal: dict[str, Any] | None = None
    seal_file_sha: str | None = None
    sealed_at: dt.datetime | None = None
    if not isinstance(frozen, dict):
        issues.append("FROZEN_REFERENCE_MISSING")
    else:
        reference_value = frozen.get("path")
        reference_sha = frozen.get("sha256")
        if (
            not isinstance(reference_value, str)
            or not Path(reference_value).is_absolute()
            or not _valid_sha(reference_sha)
        ):
            issues.append("FROZEN_REFERENCE_BINDING_INVALID")
        else:
            reference_path = Path(reference_value)
            if not reference_path.is_file() or sha256_file(reference_path) != reference_sha:
                issues.append("FROZEN_REFERENCE_HASH_MISMATCH")
        if frozen.get("provenance") != SEAL_PROVENANCE:
            issues.append("FROZEN_REFERENCE_PROVENANCE_INVALID")
        if frozen.get("independent_reference") is not False:
            issues.append("CONSENSUS_REFERENCE_MUST_NOT_BE_CALLED_INDEPENDENT")
        seal_binding = frozen.get("seal_manifest")
        seal_issues, seal_path, seal, seal_file_sha = _validate_binding(
            seal_binding, "FROZEN_REFERENCE_SEAL"
        )
        issues.extend(seal_issues)

    generated_paths = [path for meta in all_meta for path in meta["generated_paths"]]
    all_run_roots = [meta["run_root"] for meta in all_meta]
    if sealed_input_path is not None:
        if any(_within(sealed_input_path, root) for root in all_run_roots):
            issues.append("SEALED_INPUT_PATH_INSIDE_RUN_ROOT")
        if _is_forbidden_tier_path(sealed_input_path):
            issues.append("SEALED_INPUT_IN_FORBIDDEN_MT5_ROOT")
    if reference_path is not None:
        if any(_within(reference_path, root) for root in all_run_roots):
            issues.append("SELF_REFERENCE_PATH_INSIDE_RUN_ROOT")
        if _path_id(reference_path) in {_path_id(path) for path in generated_paths}:
            issues.append("SELF_REFERENCE_GENERATED_ARTIFACT_SELECTED")
        if _is_forbidden_tier_path(reference_path):
            issues.append("FROZEN_REFERENCE_IN_FORBIDDEN_MT5_ROOT")
    if seal_path is not None:
        if any(_within(seal_path, root) for root in all_run_roots):
            issues.append("SEAL_PATH_INSIDE_RUN_ROOT")
        if reference_path is not None and _path_id(seal_path) == _path_id(reference_path):
            issues.append("SEAL_AND_REFERENCE_PATH_COLLISION")

    control_paths = [
        *owner_receipt_paths,
        *data_control_paths,
        *instrument_control_paths,
        *session_control_paths,
        *([sealed_input_path] if sealed_input_path is not None else []),
        *([reference_path] if reference_path is not None else []),
        *([seal_path] if seal_path is not None else []),
    ]

    baseline_shas = sorted(
        str(meta.get("receipt_sha256")) for meta in phase_meta["BASELINE"]
    )
    qualification_shas = sorted(
        str(meta.get("receipt_sha256")) for meta in phase_meta["QUALIFICATION"]
    )
    if seal is not None:
        sealed_at = _parse_utc(seal.get("sealed_at_utc"))
        decision_sha = decision.get("decision_sha256") if isinstance(decision, dict) else None
        consensus_axes = (
            {axis: phase_meta["BASELINE"][0]["aggregate"].get(axis) for axis in spec["identity_axes"]}
            if len(phase_meta["BASELINE"]) == 2
            else None
        )
        consensus_contract = (
            phase_meta["BASELINE"][0].get("contract_sha256")
            if len(phase_meta["BASELINE"]) == 2
            else None
        )
        baseline_run_bindings = sorted(
            [
                {
                    "run_id": meta["tag"],
                    "receipt_sha256": meta["receipt_sha256"],
                    "contract_sha256": meta["contract_sha256"],
                    "run_identity_sha256": meta["run_identity_sha256"],
                    "execution_id": meta["execution_id"],
                    "sandbox_id": meta["sandbox_id"],
                    "output_root": str(meta["output_root"].resolve(strict=False)),
                }
                for meta in phase_meta["BASELINE"]
            ],
            key=lambda row: str(row["receipt_sha256"]),
        )
        reference_owner_binding = _binding_descriptor(
            owner_receipt_bindings.get("REFERENCE_SEAL")
        )
        approved_reference_object = canonical_json_sha(
            {
                "reference_sha256": reference_sha,
                "source_baseline_receipt_sha256s": baseline_shas,
                "source_baseline_runs": baseline_run_bindings,
                "consensus_contract_sha256": consensus_contract,
                "consensus_identity_sha256s": consensus_axes,
                "owner_decision_sha256": decision_sha,
            }
        )
        reference_approval = owner_receipts.get("REFERENCE_SEAL") or {}
        if (
            seal.get("schema_version") != 1
            or seal.get("artifact_type") != SEAL_ARTIFACT_TYPE
            or _structured_payload_issues(
                seal, artifact_type=SEAL_ARTIFACT_TYPE, hash_field="seal_payload_sha256"
            )
            or seal.get("provenance") != SEAL_PROVENANCE
            or seal.get("independent_reference") is not False
            or sealed_at is None
            or reference_path is None
            or seal.get("reference_path") != str(reference_path.resolve(strict=False))
            or seal.get("reference_sha256") != reference_sha
            or sorted(seal.get("source_baseline_receipt_sha256s") or []) != baseline_shas
            or seal.get("source_baseline_runs") != baseline_run_bindings
            or any(value in qualification_shas for value in seal.get("source_baseline_receipt_sha256s") or [])
            or seal.get("consensus_contract_sha256") != consensus_contract
            or seal.get("consensus_identity_sha256s") != consensus_axes
            or seal.get("owner_decision_sha256") != decision_sha
            or seal.get("owner_receipt") != reference_owner_binding
            or reference_approval.get("approved_object_sha256")
            != approved_reference_object
        ):
            issues.append("OWNER_SEAL_CONTRACT_INVALID")

    if len(phase_meta["BASELINE"]) == 2 and sealed_at is not None:
        finishes = [meta["finished"] for meta in phase_meta["BASELINE"]]
        if any(value is None for value in finishes) or sealed_at <= max(finishes):
            issues.append("SEAL_NOT_AFTER_BASELINE_REPEATS")
    if sealed_input_time is not None and phase_meta["BASELINE"]:
        baseline_starts = [meta["started"] for meta in phase_meta["BASELINE"]]
        if any(value is None for value in baseline_starts) or sealed_input_time >= min(baseline_starts):
            issues.append("SEALED_INPUT_NOT_BEFORE_BASELINE")
        if decision_time is not None and sealed_input_time <= decision_time:
            issues.append("SEALED_INPUT_NOT_AFTER_OWNER_RISK_DECISION")
    if decision_time is not None and phase_meta["BASELINE"]:
        starts = [meta["started"] for meta in phase_meta["BASELINE"]]
        if any(value is None for value in starts) or decision_time >= min(starts):
            issues.append("OWNER_RISK_DECISION_NOT_BEFORE_BASELINE")
    if len(phase_meta["QUALIFICATION"]) == 2 and sealed_at is not None:
        for meta in phase_meta["QUALIFICATION"]:
            if meta["started"] is None or meta["started"] <= sealed_at:
                issues.append(f"QUALIFICATION_NOT_AFTER_SEAL:{meta['tag']}")
            selected_reference = meta["selected_reference"]
            expected_reference = {
                "path": str(reference_path.resolve(strict=False)) if reference_path else None,
                "sha256": reference_sha,
                "provenance": SEAL_PROVENANCE,
                "independent_reference": False,
                "seal_manifest_sha256": seal_file_sha,
                "sealed_input_manifest_sha256": sealed_input_sha,
                "identity_matches": {axis: True for axis in spec["identity_axes"]},
                "reference_trade_count": meta["aggregate"].get("trade_count"),
                "current_trade_count": meta["aggregate"].get("trade_count"),
            }
            if selected_reference != expected_reference:
                issues.append(f"QUALIFICATION_REFERENCE_COMPARISON_INVALID:{meta['tag']}")
            if reference_sha != meta["aggregate"].get("full_stream_sha256"):
                issues.append(f"QUALIFICATION_STREAM_NOT_EQUAL_FROZEN_REFERENCE:{meta['tag']}")

    cost_issues: list[str] = []
    promotion_ready = False
    cost_binding = bundle.get("execution_cost_evidence_manifest")
    if not isinstance(cost_binding, dict):
        cost_issues.append("EXECUTION_COST_MANIFEST_MISSING")
    elif len(phase_meta["QUALIFICATION"]) != 2:
        cost_issues.append("EXECUTION_COST_QUALIFICATION_CONTEXT_INCOMPLETE")
    else:
        cost_path_value = cost_binding.get("path")
        declared_file_sha = cost_binding.get("sha256")
        declared_semantic_sha = cost_binding.get("semantic_contract_sha256")
        declared_axes_sha = cost_binding.get("axis_hashes_sha256")
        contract_sha = phase_meta["QUALIFICATION"][0].get("contract_sha256")
        as_of = max(meta["finished"] for meta in phase_meta["QUALIFICATION"])
        if (
            not isinstance(cost_path_value, str)
            or not Path(cost_path_value).is_absolute()
            or not _valid_sha(declared_file_sha)
            or not _valid_sha(declared_semantic_sha)
            or not _valid_sha(declared_axes_sha)
            or not _valid_sha(contract_sha)
            or as_of is None
        ):
            cost_issues.append("EXECUTION_COST_MANIFEST_BINDING_INVALID")
        else:
            cost_path = Path(cost_path_value)
            control_paths.extend(_execution_cost_control_paths(cost_path))
            required_sleeves = [
                {"ea_id": 10706, "symbol": "GBPUSD.DWX", "timeframe": "H1"}
            ]
            try:
                metadata_start, contracts_start = requal_runner.load_execution_cost_evidence_manifest(
                    cost_path,
                    source_manifest_sha256=str(contract_sha),
                    as_of_utc=as_of,
                    required_sleeves=required_sleeves,
                    window_contract=spec["cost_evaluation_window"],
                )
                axes_start = requal_runner.execution_cost_axis_hash_snapshot(metadata_start)
                metadata_end, contracts_end = requal_runner.load_execution_cost_evidence_manifest(
                    cost_path,
                    source_manifest_sha256=str(contract_sha),
                    as_of_utc=as_of,
                    required_sleeves=required_sleeves,
                    window_contract=spec["cost_evaluation_window"],
                )
                axes_end = requal_runner.execution_cost_axis_hash_snapshot(metadata_end)
            except (requal_runner.RequalError, OSError, ValueError) as exc:
                cost_issues.append(f"EXECUTION_COST_SEMANTIC_VALIDATION_FAILED:{type(exc).__name__}")
            else:
                contract_row = contracts_start.get("10706:GBPUSD.DWX")
                if (
                    metadata_start.get("sha256") != declared_file_sha
                    or metadata_start.get("semantic_contract_sha256") != declared_semantic_sha
                    or canonical_json_sha(axes_start) != declared_axes_sha
                    or metadata_start != metadata_end
                    or contracts_start != contracts_end
                    or axes_start != axes_end
                    or not isinstance(contract_row, dict)
                    or set((contract_row.get("axes") or {})) != set(spec["required_cost_axes"])
                    or any(
                        contract_row["axes"][axis].get("status") != "PASS"
                        for axis in spec["required_cost_axes"]
                    )
                ):
                    cost_issues.append("EXECUTION_COST_SEMANTIC_BINDING_MISMATCH")
                else:
                    promotion_ready = True

    issues.extend(
        _control_topology_issues(control_paths, all_run_roots, generated_paths)
    )

    if issues:
        return _result(
            "INVALID",
            issues,
            technical_identity_pass=False,
            promotion_ready=False,
            registry_change_authorized=False,
            deployment_authorized=False,
            cost_issues=sorted(set(cost_issues)),
        )
    costs_certified = promotion_ready
    promotion_ready = False
    status = (
        "TECHNICAL_PASS_RUNTIME_POLICY_BLOCKED"
        if costs_certified
        else "TECHNICAL_PASS_COST_AND_RUNTIME_POLICY_BLOCKED"
    )
    return _result(
        status,
        [],
        valid=True,
        technical_identity_pass=True,
        promotion_ready=promotion_ready,
        costs_certified=costs_certified,
        cost_issues=sorted(set(cost_issues)),
        runtime_policy_issues=[
            "BOUND_SOURCE_LACKS_HOLIDAY_EARLY_CLOSE_SESSION_CALENDAR_FALLBACK",
            "BOUND_SOURCE_NEWS_RETURNS_PRECEDE_FRIDAY_WEEKEND_RISK_CLOSE",
        ],
        consensus_reference_independent=False,
        registry_change_authorized=False,
        deployment_authorized=False,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--evidence-bundle", type=Path)
    parser.add_argument("--verify-anchors", action="store_true")
    parser.add_argument(
        "--expected-owner-receipt",
        action="append",
        default=[],
        metavar="GATE=SHA256",
        help=(
            "Out-of-band OWNER receipt trust anchor. Required exactly for "
            "RISK_CONTRACT, SEALED_INPUT and REFERENCE_SEAL when validating evidence."
        ),
    )
    return parser


def _parse_owner_trust_anchors(values: Sequence[str]) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for value in values:
        gate, separator, sha = value.partition("=")
        if not separator or gate not in OWNER_GATES or not _valid_sha(sha.lower()) or gate in parsed:
            raise ValueError(f"invalid OWNER trust anchor {value!r}")
        parsed[gate] = sha.lower()
    return parsed


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        owner_trust_anchors = _parse_owner_trust_anchors(args.expected_owner_receipt)
    except ValueError as exc:
        print(json.dumps({"status": "INVALID", "issues": [str(exc)]}, indent=2))
        return 1
    spec = _load_object(args.spec)
    if spec is None:
        print(json.dumps({"status": "INVALID", "issues": ["SPEC_JSON_UNREADABLE"]}, indent=2))
        return 1
    if args.evidence_bundle is None:
        result = validate_spec(spec, verify_anchors=args.verify_anchors)
    else:
        bundle = _load_object(args.evidence_bundle)
        if bundle is None:
            result = {"status": "INVALID", "issues": ["EVIDENCE_BUNDLE_JSON_UNREADABLE"]}
        else:
            result = validate_evidence(
                spec,
                bundle,
                spec_path=args.spec,
                verify_anchors=args.verify_anchors,
                expected_owner_receipt_sha256s=owner_trust_anchors,
            )
    print(json.dumps(result, indent=2, sort_keys=True))
    if result.get("status") == "INVALID":
        return 1
    if result.get("status") in {
        "BLOCKED_OWNER_TRUST_AND_RUNTIME_REMEDIATION",
        "TECHNICAL_PASS_COST_AND_RUNTIME_POLICY_BLOCKED",
        "TECHNICAL_PASS_RUNTIME_POLICY_BLOCKED",
    }:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
