#!/usr/bin/env python3
"""Strict, source-only W8 outcome dossier for the DXZ and FTMO target lanes.

The dossier binds both canonical target rulepacks and exact evidence identities.
It deliberately stops at ``READY_FOR_OWNER_DECISION``.  It cannot authorize a
Factory, scheduler, MT5, purchase, deployment, money, or AutoTrading action.

Evidence may be absent, approximate, or unsealed in an input draft so that an
honest ``NO_GO`` dossier can still be produced.  Such evidence can never be
weighted away.  Invalid identifiers, hashes, criteria, or rulepack bindings are
contract errors and are rejected rather than interpreted.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from copy import deepcopy
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence

from tools.strategy_farm.target_rulepacks import (
    DEFAULT_RULEPACK_DIR,
    TargetRulepack,
    load_rulepack,
)


SCHEMA_VERSION = "qm.target-outcome-dossier/v1"
EVIDENCE_SEAL_SCHEMA_VERSION = "qm.target-outcome-evidence-seal/v1"
DEFAULT_SCHEMA_PATH = Path(__file__).with_name("schemas") / "target_outcome_dossier_v1.schema.json"
DEFAULT_EVIDENCE_ROOT = Path(__file__).resolve().parents[2]
RULEPACK_IDS = ("DXZ_BETTER_BOOK_V1", "FTMO_2S_100K_SWING_V1")
LANE_IDS = ("dxz", "ftmo")
OUTCOME_STATES = {"NO_GO", "READY_FOR_OWNER_DECISION"}
CRITERION_STATES = {"PASS", "FAIL", "NOT_MEASURED", "PENDING_OWNER"}
Q08_STATES = {"SUPPORTED", "CONDITIONAL", "INSUFFICIENT", "CONTRADICTED", "INVALID"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$")
UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$")
DECIMAL_RE = re.compile(r"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$")

DXZ_EVIDENCE_KEYS = (
    "incumbent_book_manifest",
    "challenger_book_manifest",
    "execution_bundle",
    "simulation",
    "prospective_shadow",
    "probation",
)
FTMO_EVIDENCE_KEYS = (
    "book_manifest",
    "execution_bundle",
    "simulation",
    "prospective_shadow",
)
EVIDENCE_REF_KEYS = {
    "evidence_id",
    "path",
    "artifact_sha256",
    "fidelity",
    "seal_state",
    "seal_path",
    "seal_sha256",
}
EVIDENCE_SEAL_KEYS = {
    "schema_version",
    "evidence_id",
    "lane",
    "slot",
    "artifact_path",
    "artifact_sha256",
    "fidelity",
}
CRITERION_ROW_KEYS = {"criterion_id", "status", "evidence_ids"}
DXZ_METRIC_KEYS = {
    "six_month_return_percent",
    "six_month_max_drawdown_percent",
    "return_drawdown_ratio",
}
DXZ_OBSERVATION_KEYS = {
    "official_criteria",
    "internal_criteria",
    "q08_verdict",
    "evidence_debt_visible",
    "incumbent_metrics",
    "challenger_metrics",
    "darwin_replica_metrics_present",
    "synchronized_outer_validation_pass",
    "probation",
}
DXZ_PROBATION_KEYS = {
    "completed_days",
    "operational_defects",
    "actual_darwin_metrics_observed",
}
FTMO_OBSERVATION_KEYS = {
    "official_criteria",
    "internal_criteria",
    "q08_verdict",
    "evidence_debt_visible",
    "rule_snapshot_age_days",
    "execution_fidelity_unadjudicated_mismatches",
    "complete_mtm_evidence",
    "phase1_pass_probability_percent",
    "phase1_lower_95_percent_bound_percent",
    "breach_probability_upper_95_percent_bound_percent",
    "phase2_conditional_pass_probability_percent",
    "joint_two_phase_pass_probability_percent",
    "completed_free_trial_runs",
    "free_trial_operational_defects",
    "prediction_bands_respected",
}
ROOT_KEYS = {
    "schema_version",
    "dossier_id",
    "created_at_utc",
    "rulepack_bindings",
    "evidence",
    "observations",
    "evaluation",
    "runtime_action",
    "factory_action",
    "mt5_action",
    "purchase_action",
    "deployment_action",
    "owner_decision_required",
    "dossier_sha256",
}


class TargetOutcomeDossierError(ValueError):
    """The target outcome dossier violates its fail-closed contract."""


@dataclass(frozen=True)
class DossierWriteReceipt:
    path: Path
    dossier_id: str
    dossier_sha256: str
    bytes_written: int


def _fail(path: str, message: str) -> None:
    raise TargetOutcomeDossierError(f"{path}: {message}")


def _duplicate_key_guard(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise TargetOutcomeDossierError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def _reject_float(raw: str) -> Any:
    raise TargetOutcomeDossierError(f"floating-point JSON value rejected: {raw}")


def _reject_constant(raw: str) -> Any:
    raise TargetOutcomeDossierError(f"non-finite JSON value rejected: {raw}")


def _strict_loads(raw: bytes) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_duplicate_key_guard,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise TargetOutcomeDossierError(f"invalid JSON: {exc}") from exc


def _reject_non_json_or_floats(value: Any, path: str = "$") -> None:
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        _fail(path, "floating-point values are forbidden; use canonical decimal strings")
    if isinstance(value, list):
        for index, child in enumerate(value):
            _reject_non_json_or_floats(child, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, child in value.items():
            if not isinstance(key, str):
                _fail(path, "object keys must be strings")
            _reject_non_json_or_floats(child, f"{path}.{key}")
        return
    _fail(path, f"unsupported JSON value type {type(value).__name__}")


def canonical_json_bytes(value: Any, *, file_form: bool = False) -> bytes:
    _reject_non_json_or_floats(value)
    raw = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return raw + (b"\n" if file_form else b"")


def canonical_dossier_sha256(dossier: Mapping[str, Any]) -> str:
    unsigned = {key: value for key, value in dossier.items() if key != "dossier_sha256"}
    return hashlib.sha256(canonical_json_bytes(unsigned)).hexdigest()


def _exact_keys(value: Any, expected: set[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    missing = sorted(expected - set(value))
    extra = sorted(set(value) - expected)
    if missing or extra:
        _fail(path, f"key set mismatch; missing={missing}, extra={extra}")
    return value


def _string(value: Any, path: str, *, max_length: int = 4096) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        _fail(path, "must be a non-empty trimmed string")
    if len(value) > max_length:
        _fail(path, f"must be at most {max_length} characters")
    return value


def _identifier(value: Any, path: str) -> str:
    text = _string(value, path, max_length=128)
    if not IDENTIFIER_RE.fullmatch(text):
        _fail(path, "must be a canonical identifier")
    return text


def _sha(value: Any, path: str) -> str:
    text = _string(value, path, max_length=64)
    if not SHA256_RE.fullmatch(text):
        _fail(path, "must be a lowercase SHA-256 digest")
    return text


def _utc(value: Any, path: str) -> str:
    text = _string(value, path, max_length=40)
    if not UTC_RE.fullmatch(text):
        _fail(path, "must be an RFC3339 UTC timestamp ending in Z")
    try:
        from datetime import datetime

        parsed = datetime.fromisoformat(text[:-1] + "+00:00")
        if parsed.utcoffset() is None or parsed.utcoffset().total_seconds() != 0:
            raise ValueError
    except ValueError as exc:
        raise TargetOutcomeDossierError(f"{path}: invalid UTC timestamp") from exc
    return text


def _logical_path(value: Any, path: str) -> str:
    text = _string(value, path, max_length=1024)
    candidate = PurePosixPath(text)
    if (
        text.startswith("/")
        or "\\" in text
        or ":" in candidate.parts[0]
        or any(part in {"", ".", ".."} for part in candidate.parts)
        or candidate.as_posix() != text
    ):
        _fail(path, "must be a normalized relative POSIX evidence path")
    return text


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise TargetOutcomeDossierError(f"cannot read evidence file {path}: {exc}") from exc
    return digest.hexdigest()


def _resolve_evidence_file(
    evidence_root: Path | str,
    logical_path: str,
    contract_path: str,
) -> Path:
    root = Path(evidence_root)
    try:
        resolved_root = root.resolve(strict=True)
    except OSError as exc:
        raise TargetOutcomeDossierError(
            f"{contract_path}: evidence root is unavailable: {root}: {exc}"
        ) from exc
    if not resolved_root.is_dir():
        _fail(contract_path, "evidence root must resolve to a directory")
    candidate = resolved_root.joinpath(*PurePosixPath(logical_path).parts)
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as exc:
        raise TargetOutcomeDossierError(
            f"{contract_path}: evidence file is unavailable: {logical_path}: {exc}"
        ) from exc
    try:
        resolved.relative_to(resolved_root)
    except ValueError as exc:
        raise TargetOutcomeDossierError(
            f"{contract_path}: evidence file resolves outside the allowed root"
        ) from exc
    if not resolved.is_file():
        _fail(contract_path, "evidence path must resolve to a regular file")
    return resolved


def _nullable_bool(value: Any, path: str) -> bool | None:
    if value is not None and not isinstance(value, bool):
        _fail(path, "must be boolean or null")
    return value


def _nullable_int(value: Any, path: str) -> int | None:
    if value is not None and (type(value) is not int or value < 0):
        _fail(path, "must be a non-negative integer or null")
    return value


def _canonical_decimal(
    value: Any,
    path: str,
    *,
    minimum: Decimal | None = None,
    maximum: Decimal | None = None,
    minimum_exclusive: bool = False,
) -> str | None:
    if value is None:
        return None
    if isinstance(value, float):
        _fail(path, "floating-point values are forbidden; use a canonical decimal string")
    text = _string(value, path, max_length=64)
    if not DECIMAL_RE.fullmatch(text):
        _fail(path, "must be a canonical decimal string or null")
    try:
        number = Decimal(text)
    except InvalidOperation as exc:
        raise TargetOutcomeDossierError(f"{path}: invalid decimal") from exc
    if not number.is_finite() or text == "-0":
        _fail(path, "must be a finite canonical decimal")
    if "." in text and text.endswith("0"):
        _fail(path, "must not contain trailing fractional zeroes")
    if minimum is not None and (
        number < minimum or (minimum_exclusive and number == minimum)
    ):
        operator = ">" if minimum_exclusive else ">="
        _fail(path, f"must be {operator} {minimum}")
    if maximum is not None and number > maximum:
        _fail(path, f"must be <= {maximum}")
    return text


def _decimal(value: str | None) -> Decimal | None:
    return Decimal(value) if value is not None else None


def _load_rulepacks(rulepack_dir: Path | str) -> tuple[TargetRulepack, TargetRulepack]:
    loaded = tuple(load_rulepack(rulepack_id, rulepack_dir=rulepack_dir) for rulepack_id in RULEPACK_IDS)
    if tuple(pack.target for pack in loaded) != ("DARWINEX_ZERO", "FTMO"):
        _fail("rulepacks", "DXZ/FTMO target order mismatch")
    return loaded  # type: ignore[return-value]


def _rulepack_bindings(packs: Sequence[TargetRulepack]) -> list[dict[str, str]]:
    return [
        {
            "rulepack_id": pack.rulepack_id,
            "target": pack.target,
            "canonical_sha256": pack.canonical_sha256,
        }
        for pack in packs
    ]


def _normalize_evidence_ref(value: Any, path: str) -> dict[str, Any] | None:
    if value is None:
        return None
    row = _exact_keys(value, EVIDENCE_REF_KEYS, path)
    out = {
        "evidence_id": _identifier(row["evidence_id"], f"{path}.evidence_id"),
        "path": _logical_path(row["path"], f"{path}.path"),
        "artifact_sha256": _sha(row["artifact_sha256"], f"{path}.artifact_sha256"),
        "fidelity": _string(row["fidelity"], f"{path}.fidelity", max_length=16),
        "seal_state": _string(row["seal_state"], f"{path}.seal_state", max_length=16),
        "seal_path": row["seal_path"],
        "seal_sha256": row["seal_sha256"],
    }
    if out["fidelity"] not in {"EXACT", "APPROXIMATE"}:
        _fail(f"{path}.fidelity", "must be EXACT or APPROXIMATE")
    if out["seal_state"] not in {"SEALED", "UNSEALED"}:
        _fail(f"{path}.seal_state", "must be SEALED or UNSEALED")
    if out["seal_path"] is not None:
        out["seal_path"] = _logical_path(out["seal_path"], f"{path}.seal_path")
    if out["seal_sha256"] is not None:
        out["seal_sha256"] = _sha(out["seal_sha256"], f"{path}.seal_sha256")
    if out["seal_state"] == "SEALED" and (
        out["seal_path"] is None or out["seal_sha256"] is None
    ):
        _fail(path, "SEALED evidence requires seal_path and seal_sha256")
    if out["seal_state"] == "UNSEALED" and (
        out["seal_path"] is not None or out["seal_sha256"] is not None
    ):
        _fail(path, "UNSEALED evidence must not declare seal_path or seal_sha256")
    return out


def _verify_evidence_ref(
    *,
    lane: str,
    slot: str,
    row: Mapping[str, Any],
    evidence_root: Path | str,
    path: str,
) -> dict[str, str | None]:
    artifact_path = _resolve_evidence_file(evidence_root, row["path"], f"{path}.path")
    actual_artifact_sha = _sha256_file(artifact_path)
    if actual_artifact_sha != row["artifact_sha256"]:
        _fail(f"{path}.artifact_sha256", "does not match the evidence file bytes")

    seal_identity: str | None = None
    if row["seal_state"] == "SEALED":
        seal_path = _resolve_evidence_file(
            evidence_root, row["seal_path"], f"{path}.seal_path"
        )
        if seal_path == artifact_path:
            _fail(f"{path}.seal_path", "seal and artifact must be distinct files")
        try:
            seal_bytes = seal_path.read_bytes()
        except OSError as exc:
            raise TargetOutcomeDossierError(
                f"{path}.seal_path: cannot read seal file: {exc}"
            ) from exc
        actual_seal_sha = hashlib.sha256(seal_bytes).hexdigest()
        if actual_seal_sha != row["seal_sha256"]:
            _fail(f"{path}.seal_sha256", "does not match the seal file bytes")
        seal_payload = _strict_loads(seal_bytes)
        seal = _exact_keys(seal_payload, EVIDENCE_SEAL_KEYS, f"{path}.seal")
        expected_seal = {
            "schema_version": EVIDENCE_SEAL_SCHEMA_VERSION,
            "evidence_id": row["evidence_id"],
            "lane": lane,
            "slot": slot,
            "artifact_path": row["path"],
            "artifact_sha256": row["artifact_sha256"],
            "fidelity": row["fidelity"],
        }
        if seal != expected_seal:
            _fail(f"{path}.seal", "does not exactly bind this lane, slot, and artifact")
        seal_identity = os.path.normcase(str(seal_path)).casefold()

    return {
        "artifact_path": os.path.normcase(str(artifact_path)).casefold(),
        "artifact_sha256": row["artifact_sha256"],
        "seal_path": seal_identity,
        "seal_sha256": row["seal_sha256"],
    }


def _normalize_evidence(
    value: Any,
    *,
    evidence_root: Path | str,
) -> dict[str, dict[str, dict[str, Any] | None]]:
    if value is None:
        value = {}
    if not isinstance(value, dict):
        _fail("$.evidence", "must be an object")
    extra_lanes = sorted(set(value) - set(LANE_IDS))
    if extra_lanes:
        _fail("$.evidence", f"unknown target lanes: {extra_lanes}")
    out: dict[str, dict[str, dict[str, Any] | None]] = {}
    for lane, keys in (("dxz", DXZ_EVIDENCE_KEYS), ("ftmo", FTMO_EVIDENCE_KEYS)):
        raw_lane = value.get(lane) or {}
        if not isinstance(raw_lane, dict):
            _fail(f"$.evidence.{lane}", "must be an object")
        extra = sorted(set(raw_lane) - set(keys))
        if extra:
            _fail(f"$.evidence.{lane}", f"unknown evidence fields: {extra}")
        out[lane] = {
            key: _normalize_evidence_ref(raw_lane.get(key), f"$.evidence.{lane}.{key}")
            for key in keys
        }
    ids = [
        row["evidence_id"]
        for lane in out.values()
        for row in lane.values()
        if row is not None
    ]
    if len(ids) != len(set(ids)):
        _fail("$.evidence", "evidence_id values must be globally unique")

    identities: dict[str, list[tuple[str, dict[str, str | None]]]] = {
        lane: [] for lane in LANE_IDS
    }
    for lane, rows in out.items():
        for slot, row in rows.items():
            if row is None:
                continue
            path = f"$.evidence.{lane}.{slot}"
            identities[lane].append(
                (
                    slot,
                    _verify_evidence_ref(
                        lane=lane,
                        slot=slot,
                        row=row,
                        evidence_root=evidence_root,
                        path=path,
                    ),
                )
            )

    for identity_key in (
        "artifact_path",
        "artifact_sha256",
        "seal_path",
        "seal_sha256",
    ):
        dxz_values = {
            identity[identity_key]
            for _, identity in identities["dxz"]
            if identity[identity_key] is not None
        }
        ftmo_values = {
            identity[identity_key]
            for _, identity in identities["ftmo"]
            if identity[identity_key] is not None
        }
        reused = sorted(dxz_values & ftmo_values)
        if reused:
            _fail(
                "$.evidence",
                f"cross-lane evidence reuse via {identity_key} is forbidden: {reused}",
            )
    return out


def _criterion_ids(payload: Mapping[str, Any], kind: str) -> tuple[str, ...]:
    if kind == "official":
        return tuple(row["rule_id"] for row in payload["official_rules"])
    return tuple(row["criterion_id"] for row in payload["evaluation_profile"]["go_criteria"])


def _normalize_criteria(
    value: Any,
    *,
    expected_ids: Sequence[str],
    path: str,
) -> list[dict[str, Any]]:
    if value is None:
        return []
    if not isinstance(value, list):
        _fail(path, "must be an array")
    order = {criterion_id: index for index, criterion_id in enumerate(expected_ids)}
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, value_row in enumerate(value):
        row_path = f"{path}[{index}]"
        row = _exact_keys(value_row, CRITERION_ROW_KEYS, row_path)
        criterion_id = _string(row["criterion_id"], f"{row_path}.criterion_id", max_length=128)
        if criterion_id not in order:
            _fail(f"{row_path}.criterion_id", "not declared by the bound rulepack")
        if criterion_id in seen:
            _fail(row_path, "duplicate criterion_id")
        status = _string(row["status"], f"{row_path}.status", max_length=24)
        if status not in CRITERION_STATES:
            _fail(f"{row_path}.status", "unsupported criterion status")
        evidence_ids = row["evidence_ids"]
        if not isinstance(evidence_ids, list) or not evidence_ids:
            _fail(f"{row_path}.evidence_ids", "must be a non-empty array")
        normalized_ids = [
            _identifier(item, f"{row_path}.evidence_ids[{evidence_index}]")
            for evidence_index, item in enumerate(evidence_ids)
        ]
        if normalized_ids != sorted(set(normalized_ids)):
            _fail(f"{row_path}.evidence_ids", "must be unique and lexically sorted")
        rows.append(
            {
                "criterion_id": criterion_id,
                "status": status,
                "evidence_ids": normalized_ids,
            }
        )
        seen.add(criterion_id)
    rows.sort(key=lambda row: order[row["criterion_id"]])
    return rows


def _normalize_q08(value: Any, path: str) -> str | None:
    if value is None:
        return None
    text = _string(value, path, max_length=24)
    if text not in Q08_STATES:
        _fail(path, "unsupported Q08-v3 evidence verdict")
    return text


def _normalize_dxz_metrics(value: Any, path: str) -> dict[str, str | None]:
    if value is None:
        value = {}
    if not isinstance(value, dict):
        _fail(path, "must be an object")
    extra = sorted(set(value) - DXZ_METRIC_KEYS)
    if extra:
        _fail(path, f"unknown metric fields: {extra}")
    return {
        "return_drawdown_ratio": _canonical_decimal(
            value.get("return_drawdown_ratio"),
            f"{path}.return_drawdown_ratio",
            minimum=Decimal("0"),
            minimum_exclusive=True,
        ),
        "six_month_max_drawdown_percent": _canonical_decimal(
            value.get("six_month_max_drawdown_percent"),
            f"{path}.six_month_max_drawdown_percent",
            minimum=Decimal("0"),
            maximum=Decimal("100"),
        ),
        "six_month_return_percent": _canonical_decimal(
            value.get("six_month_return_percent"),
            f"{path}.six_month_return_percent",
            minimum=Decimal("-100"),
        ),
    }


def _normalize_observations(
    value: Any,
    *,
    dxz_payload: Mapping[str, Any],
    ftmo_payload: Mapping[str, Any],
) -> dict[str, Any]:
    if value is None:
        value = {}
    if not isinstance(value, dict):
        _fail("$.observations", "must be an object")
    extra_lanes = sorted(set(value) - set(LANE_IDS))
    if extra_lanes:
        _fail("$.observations", f"unknown target lanes: {extra_lanes}")

    dxz = value.get("dxz") or {}
    if not isinstance(dxz, dict):
        _fail("$.observations.dxz", "must be an object")
    extra = sorted(set(dxz) - DXZ_OBSERVATION_KEYS)
    if extra:
        _fail("$.observations.dxz", f"unknown fields: {extra}")
    probation = dxz.get("probation") or {}
    if not isinstance(probation, dict):
        _fail("$.observations.dxz.probation", "must be an object")
    probation_extra = sorted(set(probation) - DXZ_PROBATION_KEYS)
    if probation_extra:
        _fail("$.observations.dxz.probation", f"unknown fields: {probation_extra}")
    dxz_out = {
        "official_criteria": _normalize_criteria(
            dxz.get("official_criteria"),
            expected_ids=_criterion_ids(dxz_payload, "official"),
            path="$.observations.dxz.official_criteria",
        ),
        "internal_criteria": _normalize_criteria(
            dxz.get("internal_criteria"),
            expected_ids=_criterion_ids(dxz_payload, "internal"),
            path="$.observations.dxz.internal_criteria",
        ),
        "q08_verdict": _normalize_q08(dxz.get("q08_verdict"), "$.observations.dxz.q08_verdict"),
        "evidence_debt_visible": _nullable_bool(dxz.get("evidence_debt_visible"), "$.observations.dxz.evidence_debt_visible"),
        "incumbent_metrics": _normalize_dxz_metrics(dxz.get("incumbent_metrics"), "$.observations.dxz.incumbent_metrics"),
        "challenger_metrics": _normalize_dxz_metrics(dxz.get("challenger_metrics"), "$.observations.dxz.challenger_metrics"),
        "darwin_replica_metrics_present": _nullable_bool(dxz.get("darwin_replica_metrics_present"), "$.observations.dxz.darwin_replica_metrics_present"),
        "synchronized_outer_validation_pass": _nullable_bool(dxz.get("synchronized_outer_validation_pass"), "$.observations.dxz.synchronized_outer_validation_pass"),
        "probation": {
            "completed_days": _nullable_int(probation.get("completed_days"), "$.observations.dxz.probation.completed_days"),
            "operational_defects": _nullable_int(probation.get("operational_defects"), "$.observations.dxz.probation.operational_defects"),
            "actual_darwin_metrics_observed": _nullable_bool(probation.get("actual_darwin_metrics_observed"), "$.observations.dxz.probation.actual_darwin_metrics_observed"),
        },
    }

    ftmo = value.get("ftmo") or {}
    if not isinstance(ftmo, dict):
        _fail("$.observations.ftmo", "must be an object")
    ftmo_extra = sorted(set(ftmo) - FTMO_OBSERVATION_KEYS)
    if ftmo_extra:
        _fail("$.observations.ftmo", f"unknown fields: {ftmo_extra}")
    ftmo_out: dict[str, Any] = {
        "official_criteria": _normalize_criteria(
            ftmo.get("official_criteria"),
            expected_ids=_criterion_ids(ftmo_payload, "official"),
            path="$.observations.ftmo.official_criteria",
        ),
        "internal_criteria": _normalize_criteria(
            ftmo.get("internal_criteria"),
            expected_ids=_criterion_ids(ftmo_payload, "internal"),
            path="$.observations.ftmo.internal_criteria",
        ),
        "q08_verdict": _normalize_q08(ftmo.get("q08_verdict"), "$.observations.ftmo.q08_verdict"),
        "evidence_debt_visible": _nullable_bool(ftmo.get("evidence_debt_visible"), "$.observations.ftmo.evidence_debt_visible"),
        "rule_snapshot_age_days": _nullable_int(ftmo.get("rule_snapshot_age_days"), "$.observations.ftmo.rule_snapshot_age_days"),
        "execution_fidelity_unadjudicated_mismatches": _nullable_int(ftmo.get("execution_fidelity_unadjudicated_mismatches"), "$.observations.ftmo.execution_fidelity_unadjudicated_mismatches"),
        "complete_mtm_evidence": _nullable_bool(ftmo.get("complete_mtm_evidence"), "$.observations.ftmo.complete_mtm_evidence"),
        "phase1_pass_probability_percent": _canonical_decimal(ftmo.get("phase1_pass_probability_percent"), "$.observations.ftmo.phase1_pass_probability_percent", minimum=Decimal("0"), maximum=Decimal("100")),
        "phase1_lower_95_percent_bound_percent": _canonical_decimal(ftmo.get("phase1_lower_95_percent_bound_percent"), "$.observations.ftmo.phase1_lower_95_percent_bound_percent", minimum=Decimal("0"), maximum=Decimal("100")),
        "breach_probability_upper_95_percent_bound_percent": _canonical_decimal(ftmo.get("breach_probability_upper_95_percent_bound_percent"), "$.observations.ftmo.breach_probability_upper_95_percent_bound_percent", minimum=Decimal("0"), maximum=Decimal("100")),
        "phase2_conditional_pass_probability_percent": _canonical_decimal(ftmo.get("phase2_conditional_pass_probability_percent"), "$.observations.ftmo.phase2_conditional_pass_probability_percent", minimum=Decimal("0"), maximum=Decimal("100")),
        "joint_two_phase_pass_probability_percent": _canonical_decimal(ftmo.get("joint_two_phase_pass_probability_percent"), "$.observations.ftmo.joint_two_phase_pass_probability_percent", minimum=Decimal("0"), maximum=Decimal("100")),
        "completed_free_trial_runs": _nullable_int(ftmo.get("completed_free_trial_runs"), "$.observations.ftmo.completed_free_trial_runs"),
        "free_trial_operational_defects": _nullable_int(ftmo.get("free_trial_operational_defects"), "$.observations.ftmo.free_trial_operational_defects"),
        "prediction_bands_respected": _nullable_bool(ftmo.get("prediction_bands_respected"), "$.observations.ftmo.prediction_bands_respected"),
    }
    phase1 = _decimal(ftmo_out["phase1_pass_probability_percent"])
    phase1_lower = _decimal(ftmo_out["phase1_lower_95_percent_bound_percent"])
    phase2 = _decimal(ftmo_out["phase2_conditional_pass_probability_percent"])
    joint = _decimal(ftmo_out["joint_two_phase_pass_probability_percent"])
    if phase1 is not None and phase1_lower is not None and phase1_lower > phase1:
        _fail(
            "$.observations.ftmo.phase1_lower_95_percent_bound_percent",
            "must not exceed the phase-1 point estimate",
        )
    if joint is not None and phase1 is not None and joint > phase1:
        _fail(
            "$.observations.ftmo.joint_two_phase_pass_probability_percent",
            "must not exceed the phase-1 pass probability",
        )
    if joint is not None and phase2 is not None and joint > phase2:
        _fail(
            "$.observations.ftmo.joint_two_phase_pass_probability_percent",
            "must not exceed the conditional phase-2 pass probability",
        )
    return {"dxz": dxz_out, "ftmo": ftmo_out}


def _evidence_evaluation(lane: str, evidence: Mapping[str, Any]) -> tuple[str, list[str]]:
    failures: list[str] = []
    for key, row in evidence[lane].items():
        if row is None:
            failures.append(f"missing:{key}")
            continue
        if row["fidelity"] != "EXACT":
            failures.append(f"approximate:{key}")
        if row["seal_state"] != "SEALED" or row["seal_sha256"] is None:
            failures.append(f"unsealed:{key}")
    return ("PASS" if not failures else "NO_GO", failures)


def _criteria_evaluation(
    rows: Sequence[Mapping[str, Any]],
    expected_ids: Sequence[str],
    *,
    evidence_ids: set[str],
    owner_gate_id: str | None,
) -> tuple[str, list[str], list[str]]:
    by_id = {row["criterion_id"]: row for row in rows}
    failures: list[str] = []
    missing: list[str] = []
    for criterion_id in expected_ids:
        row = by_id.get(criterion_id)
        if row is None:
            missing.append(criterion_id)
            continue
        expected_status = "PENDING_OWNER" if criterion_id == owner_gate_id else "PASS"
        if row["status"] != expected_status:
            failures.append(f"{criterion_id}:{row['status']}")
        unresolved = sorted(set(row["evidence_ids"]) - evidence_ids)
        failures.extend(f"{criterion_id}:unresolved_evidence:{item}" for item in unresolved)
    if missing or failures:
        return "NO_GO", missing, failures
    return ("PENDING_OWNER" if owner_gate_id else "PASS"), [], []


def _go_parameter(payload: Mapping[str, Any], criterion_id: str, parameter: str) -> Any:
    for row in payload["evaluation_profile"]["go_criteria"]:
        if row["criterion_id"] == criterion_id:
            if parameter not in row["parameters"]:
                _fail("rulepack", f"{criterion_id} lacks parameter {parameter}")
            return row["parameters"][parameter]
    _fail("rulepack", f"missing go criterion {criterion_id}")


def _metric_check(
    check_id: str,
    *,
    source_criterion_id: str,
    actual: Any,
    operator: str,
    threshold: Any,
    passed: bool,
) -> dict[str, str]:
    def display(value: Any) -> str:
        if value is None:
            return "MISSING"
        if isinstance(value, bool):
            return "true" if value else "false"
        return str(value)

    return {
        "check_id": check_id,
        "source_criterion_id": source_criterion_id,
        "status": "PASS" if passed else "FAIL",
        "actual": display(actual),
        "operator": operator,
        "threshold": display(threshold),
    }


def _q08_check(observation: Mapping[str, Any], source: str) -> dict[str, str]:
    verdict = observation["q08_verdict"]
    debt = observation["evidence_debt_visible"]
    passed = verdict == "SUPPORTED" or (verdict == "CONDITIONAL" and debt is True)
    return _metric_check(
        "q08_target_evidence",
        source_criterion_id=source,
        actual=f"{verdict or 'MISSING'};debt_visible={debt}",
        operator="SUPPORTED_OR_CONDITIONAL_WITH_VISIBLE_DEBT",
        threshold="PASS",
        passed=passed,
    )


def _compare_decimal(actual: str | None, threshold: str | None, operator: str) -> bool:
    left = _decimal(actual)
    right = _decimal(threshold)
    if left is None or right is None:
        return False
    if operator == ">":
        return left > right
    if operator == ">=":
        return left >= right
    if operator == "<=":
        return left <= right
    _fail("evaluation", f"unknown decimal operator {operator}")


def _dxz_metric_checks(observation: Mapping[str, Any], payload: Mapping[str, Any]) -> list[dict[str, str]]:
    incumbent = observation["incumbent_metrics"]
    challenger = observation["challenger_metrics"]
    minimum_days = _go_parameter(payload, "dxz_probation_required", "minimum_days")
    probation = observation["probation"]
    return [
        _q08_check(observation, "dxz_q08_target_evidence_v1"),
        _metric_check(
            "challenger_six_month_return_improves",
            source_criterion_id="dxz_synchronized_outer_validation",
            actual=challenger["six_month_return_percent"],
            operator=">",
            threshold=incumbent["six_month_return_percent"],
            passed=_compare_decimal(challenger["six_month_return_percent"], incumbent["six_month_return_percent"], ">"),
        ),
        _metric_check(
            "challenger_six_month_drawdown_not_worse",
            source_criterion_id="dxz_synchronized_outer_validation",
            actual=challenger["six_month_max_drawdown_percent"],
            operator="<=",
            threshold=incumbent["six_month_max_drawdown_percent"],
            passed=_compare_decimal(challenger["six_month_max_drawdown_percent"], incumbent["six_month_max_drawdown_percent"], "<="),
        ),
        _metric_check(
            "challenger_return_drawdown_ratio_improves",
            source_criterion_id="dxz_synchronized_outer_validation",
            actual=challenger["return_drawdown_ratio"],
            operator=">",
            threshold=incumbent["return_drawdown_ratio"],
            passed=_compare_decimal(challenger["return_drawdown_ratio"], incumbent["return_drawdown_ratio"], ">"),
        ),
        _metric_check(
            "darwin_replica_metrics_present",
            source_criterion_id="dxz_darwin_replica_validation",
            actual=observation["darwin_replica_metrics_present"],
            operator="==",
            threshold=True,
            passed=observation["darwin_replica_metrics_present"] is True,
        ),
        _metric_check(
            "synchronized_outer_validation_pass",
            source_criterion_id="dxz_synchronized_outer_validation",
            actual=observation["synchronized_outer_validation_pass"],
            operator="==",
            threshold=True,
            passed=observation["synchronized_outer_validation_pass"] is True,
        ),
        _metric_check(
            "probation_minimum_days",
            source_criterion_id="dxz_probation_required",
            actual=probation["completed_days"],
            operator=">=",
            threshold=minimum_days,
            passed=probation["completed_days"] is not None and probation["completed_days"] >= minimum_days,
        ),
        _metric_check(
            "probation_operational_defects",
            source_criterion_id="dxz_probation_required",
            actual=probation["operational_defects"],
            operator="==",
            threshold=0,
            passed=probation["operational_defects"] == 0,
        ),
        _metric_check(
            "probation_actual_darwin_metrics",
            source_criterion_id="dxz_probation_required",
            actual=probation["actual_darwin_metrics_observed"],
            operator="==",
            threshold=True,
            passed=probation["actual_darwin_metrics_observed"] is True,
        ),
    ]


def _ftmo_metric_checks(observation: Mapping[str, Any], payload: Mapping[str, Any]) -> list[dict[str, str]]:
    max_age = _go_parameter(payload, "ftmo_rule_snapshot_fresh", "maximum_age_days")
    max_mismatches = _go_parameter(payload, "ftmo_execution_fidelity_closed", "unadjudicated_mismatches")
    point_min = _go_parameter(payload, "ftmo_phase1_probability_gate", "point_estimate_min_percent")
    lower_min = _go_parameter(payload, "ftmo_phase1_probability_gate", "lower_95_percent_bound_min_percent")
    breach_max = _go_parameter(payload, "ftmo_breach_probability_gate", "upper_95_percent_bound_max_percent")
    phase2_min = _go_parameter(payload, "ftmo_two_phase_probability_gate", "phase2_conditional_min_percent")
    joint_min = _go_parameter(payload, "ftmo_two_phase_probability_gate", "joint_two_phase_min_percent")
    min_runs = _go_parameter(payload, "ftmo_free_trial_gate", "minimum_runs")
    max_defects = _go_parameter(payload, "ftmo_free_trial_gate", "operational_defects_allowed")
    return [
        _q08_check(observation, "ftmo_q08_target_evidence_v1"),
        _metric_check(
            "rule_snapshot_age_days",
            source_criterion_id="ftmo_rule_snapshot_fresh",
            actual=observation["rule_snapshot_age_days"],
            operator="<=",
            threshold=max_age,
            passed=observation["rule_snapshot_age_days"] is not None and observation["rule_snapshot_age_days"] <= max_age,
        ),
        _metric_check(
            "execution_fidelity_unadjudicated_mismatches",
            source_criterion_id="ftmo_execution_fidelity_closed",
            actual=observation["execution_fidelity_unadjudicated_mismatches"],
            operator="<=",
            threshold=max_mismatches,
            passed=observation["execution_fidelity_unadjudicated_mismatches"] is not None and observation["execution_fidelity_unadjudicated_mismatches"] <= max_mismatches,
        ),
        _metric_check(
            "complete_mtm_evidence",
            source_criterion_id="ftmo_complete_mtm_evidence",
            actual=observation["complete_mtm_evidence"],
            operator="==",
            threshold=True,
            passed=observation["complete_mtm_evidence"] is True,
        ),
        _metric_check(
            "phase1_pass_probability",
            source_criterion_id="ftmo_phase1_probability_gate",
            actual=observation["phase1_pass_probability_percent"],
            operator=">=",
            threshold=point_min,
            passed=_compare_decimal(observation["phase1_pass_probability_percent"], point_min, ">="),
        ),
        _metric_check(
            "phase1_lower_95_percent_bound",
            source_criterion_id="ftmo_phase1_probability_gate",
            actual=observation["phase1_lower_95_percent_bound_percent"],
            operator=">=",
            threshold=lower_min,
            passed=_compare_decimal(observation["phase1_lower_95_percent_bound_percent"], lower_min, ">="),
        ),
        _metric_check(
            "official_rule_breach_upper_95_percent_bound",
            source_criterion_id="ftmo_breach_probability_gate",
            actual=observation["breach_probability_upper_95_percent_bound_percent"],
            operator="<=",
            threshold=breach_max,
            passed=_compare_decimal(observation["breach_probability_upper_95_percent_bound_percent"], breach_max, "<="),
        ),
        _metric_check(
            "phase2_conditional_pass_probability",
            source_criterion_id="ftmo_two_phase_probability_gate",
            actual=observation["phase2_conditional_pass_probability_percent"],
            operator=">=",
            threshold=phase2_min,
            passed=_compare_decimal(observation["phase2_conditional_pass_probability_percent"], phase2_min, ">="),
        ),
        _metric_check(
            "joint_two_phase_pass_probability",
            source_criterion_id="ftmo_two_phase_probability_gate",
            actual=observation["joint_two_phase_pass_probability_percent"],
            operator=">=",
            threshold=joint_min,
            passed=_compare_decimal(observation["joint_two_phase_pass_probability_percent"], joint_min, ">="),
        ),
        _metric_check(
            "completed_free_trial_runs",
            source_criterion_id="ftmo_free_trial_gate",
            actual=observation["completed_free_trial_runs"],
            operator=">=",
            threshold=min_runs,
            passed=observation["completed_free_trial_runs"] is not None and observation["completed_free_trial_runs"] >= min_runs,
        ),
        _metric_check(
            "free_trial_operational_defects",
            source_criterion_id="ftmo_free_trial_gate",
            actual=observation["free_trial_operational_defects"],
            operator="<=",
            threshold=max_defects,
            passed=observation["free_trial_operational_defects"] is not None and observation["free_trial_operational_defects"] <= max_defects,
        ),
        _metric_check(
            "prediction_bands_respected",
            source_criterion_id="ftmo_free_trial_gate",
            actual=observation["prediction_bands_respected"],
            operator="==",
            threshold=True,
            passed=observation["prediction_bands_respected"] is True,
        ),
    ]


def _lane_evaluation(
    lane: str,
    *,
    evidence: Mapping[str, Any],
    observation: Mapping[str, Any],
    payload: Mapping[str, Any],
) -> dict[str, Any]:
    evidence_status, evidence_failures = _evidence_evaluation(lane, evidence)
    known_evidence = {
        row["evidence_id"]
        for row in evidence[lane].values()
        if row is not None
    }
    official_status, official_missing, official_failures = _criteria_evaluation(
        observation["official_criteria"],
        _criterion_ids(payload, "official"),
        evidence_ids=known_evidence,
        owner_gate_id=None,
    )
    owner_gate = "dxz_owner_money_gate" if lane == "dxz" else "ftmo_owner_purchase_gate"
    internal_status, internal_missing, internal_failures = _criteria_evaluation(
        observation["internal_criteria"],
        _criterion_ids(payload, "internal"),
        evidence_ids=known_evidence,
        owner_gate_id=owner_gate,
    )
    checks = (
        _dxz_metric_checks(observation, payload)
        if lane == "dxz"
        else _ftmo_metric_checks(observation, payload)
    )
    failed_checks = [row["check_id"] for row in checks if row["status"] != "PASS"]
    ready = (
        evidence_status == "PASS"
        and official_status == "PASS"
        and internal_status == "PENDING_OWNER"
        and not failed_checks
    )
    reasons = [f"evidence:{item}" for item in evidence_failures]
    reasons.extend(f"official:missing:{item}" for item in official_missing)
    reasons.extend(f"official:{item}" for item in official_failures)
    reasons.extend(f"internal:missing:{item}" for item in internal_missing)
    reasons.extend(f"internal:{item}" for item in internal_failures)
    reasons.extend(f"metric:{item}" for item in failed_checks)
    if ready:
        reasons = ["all pre-OWNER criteria pass; a separate signed OWNER decision remains required"]
    return {
        "status": "READY_FOR_OWNER_DECISION" if ready else "NO_GO",
        "evidence_status": evidence_status,
        "evidence_failures": evidence_failures,
        "official_criteria": {
            "status": official_status,
            "missing_ids": official_missing,
            "failures": official_failures,
        },
        "internal_criteria": {
            "status": internal_status,
            "missing_ids": internal_missing,
            "failures": internal_failures,
        },
        "metric_checks": checks,
        "reasons": reasons,
    }


def _evaluate(
    evidence: Mapping[str, Any],
    observations: Mapping[str, Any],
    packs: Sequence[TargetRulepack],
) -> dict[str, Any]:
    payloads = {"dxz": packs[0].as_dict(), "ftmo": packs[1].as_dict()}
    lanes = {
        lane: _lane_evaluation(
            lane,
            evidence=evidence,
            observation=observations[lane],
            payload=payloads[lane],
        )
        for lane in LANE_IDS
    }
    overall_ready = all(row["status"] == "READY_FOR_OWNER_DECISION" for row in lanes.values())
    return {
        "overall_status": "READY_FOR_OWNER_DECISION" if overall_ready else "NO_GO",
        "dxz": lanes["dxz"],
        "ftmo": lanes["ftmo"],
        "authority_ceiling": "READY_FOR_OWNER_DECISION",
    }


def build_target_outcome_dossier(
    *,
    dossier_id: str,
    created_at_utc: str,
    evidence: Mapping[str, Any] | None,
    observations: Mapping[str, Any] | None,
    rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR,
    evidence_root: Path | str = DEFAULT_EVIDENCE_ROOT,
) -> dict[str, Any]:
    """Build and seal a deterministic W8 dossier without any runtime action."""

    packs = _load_rulepacks(rulepack_dir)
    normalized_evidence = _normalize_evidence(evidence, evidence_root=evidence_root)
    normalized_observations = _normalize_observations(
        observations,
        dxz_payload=packs[0].as_dict(),
        ftmo_payload=packs[1].as_dict(),
    )
    dossier: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "dossier_id": _identifier(dossier_id, "$.dossier_id"),
        "created_at_utc": _utc(created_at_utc, "$.created_at_utc"),
        "rulepack_bindings": _rulepack_bindings(packs),
        "evidence": normalized_evidence,
        "observations": normalized_observations,
        "evaluation": _evaluate(normalized_evidence, normalized_observations, packs),
        "runtime_action": "NONE",
        "factory_action": "NONE",
        "mt5_action": "NONE",
        "purchase_action": "NONE",
        "deployment_action": "NONE",
        "owner_decision_required": True,
    }
    dossier["dossier_sha256"] = canonical_dossier_sha256(dossier)
    validate_target_outcome_dossier(
        dossier,
        rulepack_dir=rulepack_dir,
        evidence_root=evidence_root,
    )
    return dossier


def validate_target_outcome_dossier(
    dossier: Mapping[str, Any],
    *,
    rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR,
    evidence_root: Path | str = DEFAULT_EVIDENCE_ROOT,
) -> None:
    """Validate identity, rulepack bindings, evaluation, and authority ceiling."""

    _reject_non_json_or_floats(dossier)
    root = _exact_keys(dossier, ROOT_KEYS, "$")
    if root["schema_version"] != SCHEMA_VERSION:
        _fail("$.schema_version", "unsupported schema version")
    _identifier(root["dossier_id"], "$.dossier_id")
    _utc(root["created_at_utc"], "$.created_at_utc")
    packs = _load_rulepacks(rulepack_dir)
    expected_bindings = _rulepack_bindings(packs)
    if root["rulepack_bindings"] != expected_bindings:
        _fail("$.rulepack_bindings", "must exactly bind both current canonical rulepacks")
    evidence = _normalize_evidence(root["evidence"], evidence_root=evidence_root)
    observations = _normalize_observations(
        root["observations"],
        dxz_payload=packs[0].as_dict(),
        ftmo_payload=packs[1].as_dict(),
    )
    if evidence != root["evidence"]:
        _fail("$.evidence", "must use normalized exact shape")
    if observations != root["observations"]:
        _fail("$.observations", "must use normalized exact shape")
    expected_evaluation = _evaluate(evidence, observations, packs)
    if root["evaluation"] != expected_evaluation:
        _fail("$.evaluation", "does not match deterministic rulepack evaluation")
    if root["evaluation"].get("overall_status") not in OUTCOME_STATES:
        _fail("$.evaluation.overall_status", "unsupported outcome")
    for key in (
        "runtime_action",
        "factory_action",
        "mt5_action",
        "purchase_action",
        "deployment_action",
    ):
        if root[key] != "NONE":
            _fail(f"$.{key}", "must remain NONE")
    if root["owner_decision_required"] is not True:
        _fail("$.owner_decision_required", "must remain true")
    declared = _sha(root["dossier_sha256"], "$.dossier_sha256")
    actual = canonical_dossier_sha256(root)
    if declared != actual:
        _fail("$.dossier_sha256", "canonical dossier hash mismatch")


def load_target_outcome_dossier(
    path: Path | str,
    *,
    rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR,
    evidence_root: Path | str = DEFAULT_EVIDENCE_ROOT,
) -> dict[str, Any]:
    source = Path(path)
    value = _strict_loads(source.read_bytes())
    if not isinstance(value, dict):
        _fail("$", "root must be an object")
    validate_target_outcome_dossier(
        value,
        rulepack_dir=rulepack_dir,
        evidence_root=evidence_root,
    )
    return deepcopy(value)


def write_new_target_outcome_dossier(
    dossier: Mapping[str, Any],
    path: Path | str,
    *,
    rulepack_dir: Path | str = DEFAULT_RULEPACK_DIR,
    evidence_root: Path | str = DEFAULT_EVIDENCE_ROOT,
) -> DossierWriteReceipt:
    """Create one dossier with exclusive-create semantics; never overwrite."""

    validate_target_outcome_dossier(
        dossier,
        rulepack_dir=rulepack_dir,
        evidence_root=evidence_root,
    )
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    raw = canonical_json_bytes(dossier, file_form=True)
    try:
        with destination.open("xb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise TargetOutcomeDossierError(
            f"refusing to overwrite existing target outcome dossier: {destination}"
        ) from exc
    return DossierWriteReceipt(
        path=destination,
        dossier_id=str(dossier["dossier_id"]),
        dossier_sha256=str(dossier["dossier_sha256"]),
        bytes_written=len(raw),
    )


__all__ = [
    "DEFAULT_EVIDENCE_ROOT",
    "DEFAULT_SCHEMA_PATH",
    "DossierWriteReceipt",
    "EVIDENCE_SEAL_SCHEMA_VERSION",
    "SCHEMA_VERSION",
    "TargetOutcomeDossierError",
    "build_target_outcome_dossier",
    "canonical_dossier_sha256",
    "canonical_json_bytes",
    "load_target_outcome_dossier",
    "validate_target_outcome_dossier",
    "write_new_target_outcome_dossier",
]
