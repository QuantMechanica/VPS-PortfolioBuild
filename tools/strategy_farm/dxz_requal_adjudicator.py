#!/usr/bin/env python3
"""Adjudicate DXZ as-live requalification evidence into a bound candidate book.

This is deliberately a read-only decision layer.  It consumes an original book
manifest, one ``dxz_as_live_requal`` summary and the execution-contract registry.
It never invokes MT5, copies an EX5 or preset, or writes below a tier/live MT5
root.  Only sleeves classified ``KEEP`` or evidence-promoted
``KEEP_CANDIDATE`` are copied into the candidate manifest.

Classification is fail-closed:

* ``KEEP``   - the receipt is cryptographically intact and complete, the exact
  as-live EX5/preset and both evidence streams are bound, and the execution
  contract is promotion ``ELIGIBLE``;
* ``KEEP_CANDIDATE`` - the same receipt gates pass and every open
  ``REQUAL_REQUIRED`` reason is mechanically resolved for exact as-live binary
  retention; repo-rebuild readiness is reported separately and semantic
  reasons are never auto-resolved;
* ``REPAIR`` - the receipt satisfies all evidence gates, but the execution
  contract still has at least one unresolved requalification reason;
* ``BLOCK``  - evidence is absent/failing/inconsistent, the contract is blocked,
  or any required identity binding is missing.

A complete candidate remains non-deployable and requires a separate portfolio
recompute and OWNER decision.  Historical KPIs from the input DRAFT are never
carried forward.  Individual receipts in consistent ``INCOMPLETE`` or
``PASS_PARTIAL`` summaries are adjudicated, but only ``FULL`` + ``PASS`` can
populate a candidate book.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from . import execution_contract_lint
    from . import dxz_as_live_requal as requal_runner
    from . import dxz_target_binary_repro_gate as target_repro_gate
except ImportError:  # pragma: no cover - direct script execution
    import execution_contract_lint  # type: ignore
    import dxz_as_live_requal as requal_runner  # type: ignore
    import dxz_target_binary_repro_gate as target_repro_gate  # type: ignore


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = Path(
    r"D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json"
)
DEFAULT_CONTRACTS = REPO_ROOT / "framework" / "registry" / "dxz23_execution_contracts.json"
DEFAULT_SYMBOL_MATRIX = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
DEFAULT_OUTPUT_ROOT = Path(r"D:\QM\reports\portfolio")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
RUNNER_SCHEMA_VERSION = 2
AS_LIVE_REQUAL = requal_runner.AS_LIVE_REQUAL
TARGET_BINARY_REQUAL = requal_runner.TARGET_BINARY_REQUAL
QUALIFYING_MODES = frozenset(requal_runner.QUALIFYING_MODES)
TARGET_SINGLE_RUN_STATUS = "REPRODUCIBILITY_PENDING"
TARGET_REPRODUCIBILITY_AXES = tuple(target_repro_gate.REQUIRED_IDENTITY_AXES)
TARGET_PAIR_ARTIFACT_TYPE = target_repro_gate.ARTIFACT_TYPE
TARGET_PAIR_SCHEMA_VERSION = target_repro_gate.SCHEMA_VERSION
CANONICAL_LIVE_ROOT = Path(r"C:\QM\mt5\T_Live\MT5_Base")
EXECUTION_COST_AXES = (
    "commission",
    "historical_tester_spread",
    "current_broker_spread_parity",
    "current_broker_swap_rate_parity",
    "slippage_stress",
)
EXECUTION_COST_MANIFEST_TYPE = "DXZ_EXECUTION_COST_EVIDENCE_MANIFEST"
TIER_ROOT_RE = re.compile(r"^(?:T_Live|T(?:10|[1-9]))$", re.IGNORECASE)
PROMOTION_STATUSES = {"ELIGIBLE", "REQUAL_REQUIRED", "BLOCKED"}
CLASSIFICATIONS = ("KEEP", "KEEP_CANDIDATE", "REPAIR", "BLOCK")
ContractIdentity = tuple[int, str | None, str | None, str | None]
ContractProblemKey = ContractIdentity | None
# These tokens describe evidence that a deterministic run can actually close.
# Everything not explicitly listed is semantic/manual and remains open.
MACHINE_RESOLVABLE_REASONS = {"remediated_binary_not_requalified"}
INCLUDE_RE = re.compile(r'^\s*#include\s*[<"](?P<name>[^>"]+)[>"]', re.MULTILINE)


class AdjudicationError(RuntimeError):
    """Raised for an unsafe output request or unreadable top-level input."""


def canonical_json_sha(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def json_artifact_bytes(payload: Mapping[str, Any]) -> bytes:
    """Return the one canonical on-disk encoding used by adjudication bundles."""

    return (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode("utf-8")


def json_artifact_sha(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(json_artifact_bytes(payload)).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AdjudicationError(f"cannot read {label} JSON {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise AdjudicationError(f"{label} must be a JSON object: {path}")
    return payload


def _embedded_hash_valid(payload: Mapping[str, Any], field: str) -> bool:
    declared = payload.get(field)
    if not isinstance(declared, str) or not SHA256_RE.fullmatch(declared.lower()):
        return False
    unsigned = dict(payload)
    unsigned.pop(field, None)
    return canonical_json_sha(unsigned) == declared.lower()


def _valid_sha(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value.lower()) is not None


def target_pair_artifact_bytes(payload: Mapping[str, Any]) -> bytes:
    """Return the immutable on-disk encoding used by the TARGET pair gate."""

    return (
        json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")


def target_pair_artifact_sha(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(target_pair_artifact_bytes(payload)).hexdigest()


def _load_target_pair_input(
    path: Path,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Read one immutable pair artifact and verify its adjacent sidecar."""

    resolved = path.resolve()
    if any(TIER_ROOT_RE.fullmatch(part) for part in resolved.parts):
        raise AdjudicationError(
            f"refusing TARGET pair evidence below tier/live MT5 root: {resolved}"
        )
    pair = _load_object(resolved, "TARGET reproducibility pair")
    artifact_sha = sha256_file(resolved)
    if target_pair_artifact_sha(pair) != artifact_sha:
        raise AdjudicationError(
            "TARGET reproducibility pair is not in its immutable canonical encoding"
        )
    sidecar = resolved.with_name(resolved.name + ".sha256")
    try:
        lines = [
            line.strip()
            for line in sidecar.read_text(encoding="ascii", errors="strict").splitlines()
            if line.strip()
        ]
    except (OSError, UnicodeError) as exc:
        raise AdjudicationError(
            f"TARGET reproducibility pair sidecar missing/unreadable: {sidecar}"
        ) from exc
    if len(lines) != 1:
        raise AdjudicationError(
            "TARGET reproducibility pair sidecar must contain exactly one binding"
        )
    match = target_repro_gate.SIDECAR_RE.fullmatch(lines[0])
    if match is None:
        raise AdjudicationError("TARGET reproducibility pair sidecar is invalid")
    declared_sha = match.group(1).lower()
    declared_name = match.group(2)
    if declared_sha != artifact_sha:
        raise AdjudicationError("TARGET reproducibility pair sidecar hash mismatch")
    if (
        declared_name
        and Path(declared_name.strip()).name.casefold() != resolved.name.casefold()
    ):
        raise AdjudicationError("TARGET reproducibility pair sidecar filename mismatch")
    return pair, {
        "path": str(resolved),
        "artifact_sha256": artifact_sha,
        "sidecar_path": str(sidecar),
        "sidecar_sha256": sha256_file(sidecar),
        "sidecar_declared_sha256": declared_sha,
    }


def _path_identity(path: Path) -> str:
    try:
        resolved = path.resolve()
    except OSError:
        resolved = path.absolute()
    return str(resolved).replace("/", "\\").casefold()


def _artifact_binding_issues(
    binding: Any,
    *,
    repo_root: Path,
    prefix: str,
) -> list[str]:
    if not isinstance(binding, dict):
        return [f"{prefix}_BINDING_INVALID"]
    path = _safe_resolve(binding.get("path"), repo_root)
    expected_sha = binding.get("sha256")
    if path is None or not path.is_file() or not _valid_sha(expected_sha):
        return [f"{prefix}_BINDING_INVALID"]
    if sha256_file(path) != expected_sha:
        return [f"{prefix}_HASH_MISMATCH"]
    return []


def _execution_cost_manifest_issues(
    binding: Any,
    *,
    manifest_sha256: str,
    required_keys: set[str],
    required_sleeves: list[dict[str, Any]],
    window_contract: Mapping[str, Any],
    repo_root: Path,
    as_of: dt.date,
) -> list[str]:
    issues: list[str] = []
    if not isinstance(binding, dict):
        return ["EXECUTION_COST_MANIFEST_MISSING"]
    if binding.get("artifact_type") != EXECUTION_COST_MANIFEST_TYPE:
        issues.append("EXECUTION_COST_MANIFEST_TYPE_INVALID")
    if binding.get("source_manifest_sha256") != manifest_sha256:
        issues.append("EXECUTION_COST_MANIFEST_SOURCE_MISMATCH")
    if binding.get("scope") not in {"GLOBAL", "PER_SLEEVE"}:
        issues.append("EXECUTION_COST_MANIFEST_SCOPE_INVALID")
    covered = binding.get("covered_keys")
    if not isinstance(covered, list) or not required_keys.issubset(
        {str(item).upper() for item in covered}
    ):
        issues.append("EXECUTION_COST_MANIFEST_COVERAGE_INCOMPLETE")
    if (
        binding.get("unchanged") is not True
        or binding.get("end_errors") != []
        or not _valid_sha(binding.get("sha256"))
        or binding.get("sha256_end") != binding.get("sha256")
    ):
        issues.append("EXECUTION_COST_MANIFEST_SWEEP_BINDING_INVALID")
    manifest_path = _safe_resolve(binding.get("path"), repo_root)
    sidecar_path = _safe_resolve(binding.get("sidecar_path"), repo_root)
    if (
        manifest_path is None
        or not manifest_path.is_file()
        or sha256_file(manifest_path) != binding.get("sha256")
    ):
        issues.append("EXECUTION_COST_MANIFEST_FILE_HASH_MISMATCH")
    if (
        sidecar_path is None
        or not sidecar_path.is_file()
        or sha256_file(sidecar_path) != binding.get("sidecar_sha256")
    ):
        issues.append("EXECUTION_COST_MANIFEST_SIDECAR_HASH_MISMATCH")
    try:
        valid_from = dt.datetime.fromisoformat(
            str(binding.get("valid_from_utc") or "").replace("Z", "+00:00")
        ).date()
        valid_until = dt.datetime.fromisoformat(
            str(binding.get("valid_until_utc") or "").replace("Z", "+00:00")
        ).date()
    except ValueError:
        issues.append("EXECUTION_COST_MANIFEST_VALIDITY_INVALID")
    else:
        if not valid_from <= as_of <= valid_until:
            issues.append("EXECUTION_COST_MANIFEST_EXPIRED")
    artifacts = binding.get("bound_artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        issues.append("EXECUTION_COST_MANIFEST_ARTIFACTS_MISSING")
    else:
        for artifact in artifacts:
            issues.extend(
                _artifact_binding_issues(
                    artifact,
                    repo_root=repo_root,
                    prefix="EXECUTION_COST_ARTIFACT",
                )
            )
            if isinstance(artifact, dict):
                issues.extend(
                    _artifact_binding_issues(
                        {
                            "path": artifact.get("sidecar_path"),
                            "sha256": artifact.get("sidecar_sha256"),
                        },
                        repo_root=repo_root,
                        prefix="EXECUTION_COST_ARTIFACT_SIDECAR",
                    )
                )
    if manifest_path is not None and manifest_path.is_file():
        try:
            verified, _contracts = requal_runner.load_execution_cost_evidence_manifest(
                manifest_path,
                source_manifest_sha256=manifest_sha256,
                as_of_utc=dt.datetime.combine(as_of, dt.time(12), tzinfo=dt.UTC),
                required_sleeves=required_sleeves,
                window_contract=window_contract,
            )
        except (requal_runner.RequalError, OSError, ValueError):
            issues.append("EXECUTION_COST_MANIFEST_SEMANTIC_VALIDATION_FAILED")
        else:
            verified["axis_hashes_start"] = (
                requal_runner.execution_cost_axis_hash_snapshot(verified)
            )
            semantic_fields = (
                "manifest_payload_sha256",
                "artifact_type",
                "scope",
                "source_manifest_sha256",
                "valid_from_utc",
                "valid_until_utc",
                "covered_keys",
                "covered_sleeves",
                "evaluation_window",
                "axes",
                "bound_artifacts",
                "semantic_contract_sha256",
                "axis_hashes_start",
            )
            if any(binding.get(field) != verified.get(field) for field in semantic_fields):
                issues.append("EXECUTION_COST_MANIFEST_SEMANTIC_BINDING_MISMATCH")
            current_axis_hashes = requal_runner.execution_cost_axis_hash_snapshot(verified)
            if (
                not isinstance(binding.get("axis_hashes_end"), dict)
                or binding.get("axis_hashes_end") != binding.get("axis_hashes_start")
                or binding.get("axis_hashes_end") != current_axis_hashes
                or set(binding.get("axis_hashes_end") or {}) != set(EXECUTION_COST_AXES)
                or any(
                    not binding["axis_hashes_end"].get(axis)
                    for axis in EXECUTION_COST_AXES
                )
            ):
                issues.append("EXECUTION_COST_AXIS_SWEEP_BINDING_INVALID")
    return sorted(set(issues))


def _key(ea_id: Any, symbol: Any) -> str:
    try:
        numeric = int(ea_id)
    except (TypeError, ValueError):
        numeric = -1
    return f"{numeric}:{str(symbol).upper()}"


def _sleeve_identity_key(
    ea_id: Any,
    symbol: Any,
    timeframe: Any = None,
    variant_id: Any = None,
) -> str:
    pair = _key(ea_id, symbol)
    timeframe_token = str(timeframe).upper() if timeframe is not None else "*"
    variant_token = str(variant_id) if variant_id is not None else "VARIANT_UNSPECIFIED"
    return f"{pair}:{timeframe_token}:{variant_token}"


def _exact_identity(
    ea_id: Any,
    symbol: Any,
    timeframe: Any,
    variant_id: Any = None,
) -> ContractIdentity | None:
    """Return a strict sleeve identity, or ``None`` for malformed input."""

    if not isinstance(ea_id, int) or isinstance(ea_id, bool) or ea_id <= 0:
        return None
    if not isinstance(symbol, str) or not execution_contract_lint.CONTRACT_SYMBOL_RE.fullmatch(symbol):
        return None
    if not isinstance(timeframe, str) or timeframe not in execution_contract_lint.TIMEFRAMES:
        return None
    if variant_id is not None and (
        not isinstance(variant_id, str)
        or not execution_contract_lint.VARIANT_ID_RE.fullmatch(variant_id)
    ):
        return None
    return ea_id, symbol, timeframe, variant_id


def _identity_label(identity: ContractIdentity | None) -> str:
    if identity is None:
        return "INVALID"
    ea_id, symbol, timeframe, variant_id = identity
    if symbol is None:
        return f"{ea_id}:*:LEGACY_EA"
    return f"{ea_id}:{symbol}:{timeframe}:{variant_id or 'VARIANT_UNSPECIFIED'}"


def _safe_resolve(reference: Any, repo_root: Path) -> Path | None:
    if not isinstance(reference, str) or not reference.strip():
        return None
    path = Path(reference)
    return path if path.is_absolute() else repo_root / path


def _manifest_index(manifest: Mapping[str, Any]) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]], list[str]]:
    issues: list[str] = []
    rows = manifest.get("sleeves")
    if not isinstance(rows, list) or not rows:
        return [], {}, ["MANIFEST_SLEEVES_INVALID"]
    sleeves: list[dict[str, Any]] = []
    indexed: dict[str, dict[str, Any]] = {}
    for raw in rows:
        if not isinstance(raw, dict):
            issues.append("MANIFEST_SLEEVE_INVALID")
            continue
        sleeve = dict(raw)
        key = _sleeve_identity_key(
            sleeve.get("ea_id"),
            sleeve.get("symbol"),
            sleeve.get("timeframe"),
            sleeve.get("variant_id"),
        )
        symbol = str(sleeve.get("symbol") or "")
        if key.startswith("-1:") or not symbol.endswith(".DWX"):
            issues.append(f"MANIFEST_IDENTITY_INVALID:{key}")
            continue
        if "timeframe" in sleeve and _exact_identity(
            sleeve.get("ea_id"),
            sleeve.get("symbol"),
            sleeve.get("timeframe"),
            sleeve.get("variant_id"),
        ) is None:
            issues.append(f"MANIFEST_TIMEFRAME_IDENTITY_INVALID:{key}")
            continue
        if "variant_id" in sleeve and "timeframe" not in sleeve:
            issues.append(f"MANIFEST_VARIANT_WITHOUT_TIMEFRAME:{key}")
            continue
        if key in indexed:
            issues.append(f"MANIFEST_DUPLICATE_SLEEVE:{key}")
            continue
        indexed[key] = sleeve
        sleeves.append(sleeve)
    declared = manifest.get("n_sleeves")
    try:
        declared_count = int(declared)
    except (TypeError, ValueError):
        declared_count = -1
    if declared_count != len(rows):
        issues.append("MANIFEST_DECLARED_COUNT_MISMATCH")
    return sleeves, indexed, sorted(set(issues))


def _registry_index(
    registry: Mapping[str, Any],
    *,
    repo_root: Path,
    as_of: dt.date,
) -> tuple[
    dict[ContractIdentity, dict[str, Any]],
    dict[ContractProblemKey, list[str]],
]:
    indexed: dict[ContractIdentity, dict[str, Any]] = {}
    problems: dict[ContractProblemKey, list[str]] = {}
    if registry.get("schema_version") != 2 or not isinstance(registry.get("contracts"), list):
        return {}, {None: ["CONTRACT_REGISTRY_SCHEMA_INVALID"]}
    scopes_by_ea: dict[int, set[str]] = {}
    for raw in registry["contracts"]:
        if not isinstance(raw, dict) or not isinstance(raw.get("ea_id"), int):
            problems.setdefault(None, []).append("CONTRACT_RECORD_INVALID")
            continue
        try:
            identity = execution_contract_lint.execution_contract_identity(raw)
        except ValueError:
            problems.setdefault(None, []).append(
                f"CONTRACT_IDENTITY_INVALID:{raw.get('ea_id')}"
            )
            continue
        ea_id, symbol, _timeframe, _variant_id = identity
        scope = "LEGACY" if symbol is None else "SLEEVE"
        scopes_by_ea.setdefault(ea_id, set()).add(scope)
        if identity in indexed:
            problems.setdefault(identity, []).append("CONTRACT_DUPLICATE_IDENTITY")
            continue
        contract = dict(raw)
        indexed[identity] = contract
        lint_issues = execution_contract_lint.lint_contract(
            contract,
            repo_root=repo_root,
            as_of=as_of,
        )
        if lint_issues:
            problems.setdefault(identity, []).extend(
                f"CONTRACT_LINT:{item.code}" for item in lint_issues if item.severity == "ERROR"
            )
        promotion = contract.get("promotion")
        status = promotion.get("status") if isinstance(promotion, dict) else None
        if status not in PROMOTION_STATUSES:
            problems.setdefault(identity, []).append("CONTRACT_PROMOTION_STATUS_INVALID")
        card = _safe_resolve(contract.get("card_ref"), repo_root)
        source = _safe_resolve(contract.get("source"), repo_root)
        if card is None or contract.get("card_ref") == "MISSING_CANONICAL_APPROVED_CARD":
            problems.setdefault(identity, []).append("CONTRACT_CARD_UNBOUND")
        elif not card.is_file():
            problems.setdefault(identity, []).append("CONTRACT_CARD_MISSING")
        if source is None or not source.is_file():
            problems.setdefault(identity, []).append("CONTRACT_SOURCE_MISSING")
    for ea_id, scopes in scopes_by_ea.items():
        if len(scopes) > 1:
            problems.setdefault(None, []).append(f"CONTRACT_MIXED_SCOPE:{ea_id}")
    return indexed, {key: sorted(set(value)) for key, value in problems.items()}


def _resolve_contract(
    sleeve: Mapping[str, Any],
    receipt: Mapping[str, Any] | None,
    contracts: Mapping[ContractIdentity, dict[str, Any]],
    *,
    manifest_ea_counts: Mapping[int, int],
) -> tuple[dict[str, Any] | None, ContractIdentity | None, ContractIdentity | None, list[str]]:
    """Resolve one source sleeve to exactly one registry contract.

    Sleeve-specific identities take precedence.  Legacy EA-wide contracts are
    accepted only where the source manifest contains exactly one sleeve for the
    EA, so an EA-level policy can never leak across symbols, timeframes or
    named variants.
    """

    ea_id = sleeve.get("ea_id")
    symbol = sleeve.get("symbol")
    if not isinstance(ea_id, int) or not isinstance(symbol, str):
        return None, None, None, ["CONTRACT_REQUEST_IDENTITY_INVALID"]

    manifest_timeframe = sleeve.get("timeframe")
    manifest_variant = sleeve.get("variant_id")
    receipt_job = receipt.get("job") if isinstance(receipt, Mapping) else None
    receipt_timeframe = (
        receipt_job.get("timeframe") if isinstance(receipt_job, Mapping) else None
    )
    receipt_variant = (
        receipt_job.get("variant_id") if isinstance(receipt_job, Mapping) else None
    )
    if manifest_timeframe is not None and receipt_timeframe is not None:
        if manifest_timeframe != receipt_timeframe:
            return None, None, None, ["CONTRACT_REQUEST_TIMEFRAME_MISMATCH"]
    requested_timeframe = manifest_timeframe or receipt_timeframe
    if requested_timeframe is not None and (
        not isinstance(requested_timeframe, str)
        or requested_timeframe not in execution_contract_lint.TIMEFRAMES
    ):
        return None, None, None, ["CONTRACT_REQUEST_TIMEFRAME_INVALID"]
    if manifest_variant is not None and receipt_variant is not None:
        if manifest_variant != receipt_variant:
            return None, None, None, ["CONTRACT_REQUEST_VARIANT_MISMATCH"]
    requested_variant = manifest_variant or receipt_variant
    if requested_variant is not None and (
        not isinstance(requested_variant, str)
        or not execution_contract_lint.VARIANT_ID_RE.fullmatch(requested_variant)
    ):
        return None, None, None, ["CONTRACT_REQUEST_VARIANT_INVALID"]

    same_symbol = sorted(
        (
            identity
            for identity in contracts
            if identity[0] == ea_id and identity[1] == symbol
        ),
        key=_identity_label,
    )
    if requested_timeframe is None:
        timeframes = {identity[2] for identity in same_symbol}
        if len(timeframes) == 1:
            requested_timeframe = next(iter(timeframes))
        elif len(timeframes) > 1:
            return None, None, None, ["CONTRACT_TIMEFRAME_AMBIGUOUS"]

    same_timeframe = [
        identity
        for identity in same_symbol
        if identity[2] == requested_timeframe
    ]
    if requested_variant is None:
        variants = {identity[3] for identity in same_timeframe}
        if len(variants) == 1:
            requested_variant = next(iter(variants))
        elif len(variants) > 1:
            return None, None, None, ["CONTRACT_VARIANT_AMBIGUOUS"]

    resolved_identity = (
        _exact_identity(ea_id, symbol, requested_timeframe, requested_variant)
        if requested_timeframe is not None
        else None
    )
    if resolved_identity is not None and resolved_identity in contracts:
        return (
            contracts[resolved_identity],
            resolved_identity,
            resolved_identity,
            [],
        )

    legacy_identity: ContractIdentity = (ea_id, None, None, None)
    if legacy_identity in contracts:
        if manifest_ea_counts.get(ea_id) == 1:
            if resolved_identity is None:
                legacy_tf = contracts[legacy_identity].get("strategy_timeframe")
                resolved_identity = _exact_identity(
                    ea_id,
                    symbol,
                    legacy_tf,
                    requested_variant,
                )
            if resolved_identity is None:
                return None, None, legacy_identity, ["CONTRACT_REQUEST_IDENTITY_INVALID"]
            return contracts[legacy_identity], resolved_identity, legacy_identity, []
        return (
            None,
            resolved_identity,
            legacy_identity,
            ["CONTRACT_LEGACY_EA_SCOPE_AMBIGUOUS"],
        )

    if same_timeframe and requested_variant is not None:
        expected = ",".join(
            str(identity[3] or "VARIANT_UNSPECIFIED")
            for identity in same_timeframe
        )
        return None, resolved_identity, None, [f"CONTRACT_VARIANT_MISMATCH:{expected}"]
    if same_symbol:
        expected = ",".join(str(identity[2]) for identity in same_symbol)
        return None, resolved_identity, None, [f"CONTRACT_TIMEFRAME_MISMATCH:{expected}"]
    if any(identity[0] == ea_id for identity in contracts):
        return None, resolved_identity, None, ["CONTRACT_SLEEVE_IDENTITY_MISSING"]
    return None, resolved_identity, None, ["CONTRACT_MISSING"]


def _target_summary_binding_issues(
    summary: Mapping[str, Any],
    *,
    manifest_sha256: str,
) -> list[str]:
    """Validate TARGET-only immutable artifact and isolation bindings.

    This validates one technical run.  It deliberately does not declare the
    run qualified: book admission additionally requires a separate immutable
    two-run reproduction pair.
    """

    issues: list[str] = []
    override = summary.get("artifact_override_manifest")
    if not isinstance(override, Mapping):
        return ["SUMMARY_TARGET_ARTIFACT_OVERRIDE_MISSING"]
    raw_path = override.get("path")
    if not isinstance(raw_path, str) or not raw_path.strip():
        issues.append("SUMMARY_TARGET_ARTIFACT_OVERRIDE_PATH_INVALID")
    else:
        try:
            verified, _rows = requal_runner.load_artifact_override_manifest(
                Path(raw_path),
                qualification_mode=TARGET_BINARY_REQUAL,
                source_manifest_sha256=manifest_sha256,
            )
        except (requal_runner.RequalError, OSError, ValueError):
            issues.append("SUMMARY_TARGET_ARTIFACT_OVERRIDE_SEMANTIC_INVALID")
        else:
            semantic_fields = (
                "path",
                "sha256",
                "sidecar_path",
                "sidecar_sha256",
                "schema_version",
                "artifact_type",
                "artifact_payload_sha256",
                "source_manifest_sha256",
                "qualification_mode",
                "rows",
                "bound_artifacts",
            )
            if any(override.get(field) != verified.get(field) for field in semantic_fields):
                issues.append("SUMMARY_TARGET_ARTIFACT_OVERRIDE_BINDING_MISMATCH")
    if (
        override.get("artifact_type") != requal_runner.TARGET_ARTIFACT_MANIFEST_TYPE
        or override.get("qualification_mode") != TARGET_BINARY_REQUAL
        or override.get("source_manifest_sha256") != manifest_sha256
        or not _valid_sha(override.get("sha256"))
        or not _valid_sha(override.get("sidecar_sha256"))
        or not _valid_sha(override.get("artifact_payload_sha256"))
    ):
        issues.append("SUMMARY_TARGET_ARTIFACT_OVERRIDE_BINDING_INVALID")
    bound_artifacts = override.get("bound_artifacts")
    if not isinstance(bound_artifacts, list) or not bound_artifacts:
        issues.append("SUMMARY_TARGET_ARTIFACT_BINDINGS_EMPTY")
    else:
        identities: set[tuple[int, str, str, str | None]] = set()
        for row in bound_artifacts:
            if not isinstance(row, Mapping):
                issues.append("SUMMARY_TARGET_ARTIFACT_BINDING_INVALID")
                continue
            try:
                identity = (
                    int(row.get("ea_id")),
                    str(row.get("symbol")),
                    str(row.get("timeframe")),
                    str(row.get("variant_id")) if row.get("variant_id") is not None else None,
                )
            except (TypeError, ValueError):
                issues.append("SUMMARY_TARGET_ARTIFACT_BINDING_INVALID")
                continue
            if identity in identities:
                issues.append("SUMMARY_TARGET_ARTIFACT_DUPLICATE_IDENTITY")
            identities.add(identity)
            for kind in ("ex5", "set"):
                path_text = row.get(f"{kind}_path")
                if (
                    not isinstance(path_text, str)
                    or any(TIER_ROOT_RE.fullmatch(part) for part in Path(path_text).parts)
                    or not _valid_sha(row.get(f"{kind}_sha256"))
                ):
                    issues.append(f"SUMMARY_TARGET_{kind.upper()}_BINDING_INVALID")
    if (
        summary.get("artifact_override_manifest_sha256_end") != override.get("sha256")
        or summary.get("artifact_override_manifest_unchanged") is not True
    ):
        issues.append("SUMMARY_TARGET_ARTIFACT_OVERRIDE_SWEEP_BINDING_INVALID")
    end = summary.get("artifact_override_end_snapshot")
    if (
        not isinstance(end, Mapping)
        or end.get("manifest_sha256") != override.get("sha256")
        or end.get("sidecar_sha256") != override.get("sidecar_sha256")
    ):
        issues.append("SUMMARY_TARGET_ARTIFACT_OVERRIDE_END_INVALID")
    if (
        summary.get("canonical_live_artifacts_used") is not False
        or summary.get("live_source_snapshot") != summary.get("live_source_snapshot_end")
        or summary.get("live_source_unchanged") is not True
    ):
        issues.append("SUMMARY_TARGET_T_LIVE_READ_ONLY_BINDING_INVALID")
    derivations = summary.get("sandbox_derivations")
    if (
        not isinstance(derivations, list)
        or not derivations
        or summary.get("sandbox_derivations_end") != derivations
        or summary.get("sandbox_derivations_unchanged") is not True
    ):
        issues.append("SUMMARY_TARGET_SANDBOX_DERIVATION_BINDING_INVALID")
    else:
        for row in derivations:
            if not isinstance(row, Mapping):
                issues.append("SUMMARY_TARGET_SANDBOX_DERIVATION_BINDING_INVALID")
                continue
            for field in ("sandbox_root", "source_base_root"):
                value = row.get(field)
                if not isinstance(value, str) or any(
                    TIER_ROOT_RE.fullmatch(part) for part in Path(value).parts
                ):
                    issues.append("SUMMARY_TARGET_SANDBOX_DERIVATION_PATH_INVALID")
    return sorted(set(issues))


def _summary_integrity_issues(
    summary: Mapping[str, Any],
    *,
    manifest_sha256: str,
    manifest_keys: set[str],
    manifest_count: int,
    repo_root: Path,
    as_of: dt.date,
) -> list[str]:
    issues: list[str] = []
    if summary.get("schema_version") != RUNNER_SCHEMA_VERSION:
        issues.append("SUMMARY_SCHEMA_INVALID")
    if not _embedded_hash_valid(summary, "summary_sha256"):
        issues.append("SUMMARY_SHA256_INVALID")
    if summary.get("manifest_sha256") != manifest_sha256:
        issues.append("SUMMARY_MANIFEST_SHA256_MISMATCH")
    if (
        summary.get("manifest_sha256_end") != manifest_sha256
        or summary.get("manifest_unchanged") is not True
    ):
        issues.append("SUMMARY_MANIFEST_SWEEP_BINDING_INVALID")
    reference_snapshot = summary.get("reference_snapshot")
    if (
        not isinstance(reference_snapshot, dict)
        or reference_snapshot.get("seal_verified") is not True
        or reference_snapshot.get("errors") != []
        or reference_snapshot.get("status") != "PASS"
        or reference_snapshot.get("source_manifest_sha256") != manifest_sha256
        or not _valid_sha(reference_snapshot.get("manifest_sha256"))
        or not _valid_sha(reference_snapshot.get("seal_sha256"))
        or not isinstance(reference_snapshot.get("snapshot_root"), str)
        or not reference_snapshot.get("snapshot_root")
        or summary.get("reference_snapshot_end") != reference_snapshot
        or summary.get("reference_snapshot_unchanged") is not True
    ):
        issues.append("SUMMARY_REFERENCE_SNAPSHOT_BINDING_INVALID")
    qualification_mode = summary.get("qualification_mode")
    if qualification_mode not in QUALIFYING_MODES:
        issues.append("SUMMARY_QUALIFICATION_MODE_NOT_AS_LIVE")
    elif qualification_mode == AS_LIVE_REQUAL:
        if summary.get("artifact_override_manifest") is not None:
            issues.append("SUMMARY_ARTIFACT_OVERRIDE_FORBIDDEN")
    elif qualification_mode == TARGET_BINARY_REQUAL:
        issues.extend(
            _target_summary_binding_issues(
                summary,
                manifest_sha256=manifest_sha256,
            )
        )
    if (
        not isinstance(summary.get("live_root"), str)
        or _path_identity(Path(summary["live_root"])) != _path_identity(CANONICAL_LIVE_ROOT)
        or not isinstance(summary.get("canonical_live_root"), str)
        or _path_identity(Path(summary["canonical_live_root"]))
        != _path_identity(CANONICAL_LIVE_ROOT)
        or summary.get("canonical_live_root_pinned") is not True
    ):
        issues.append("SUMMARY_CANONICAL_LIVE_ROOT_NOT_PINNED")
    if summary.get("status") in {"PASS", "PASS_PARTIAL"}:
        expected_qualification_status = (
            "QUALIFIED"
            if qualification_mode == AS_LIVE_REQUAL
            else TARGET_SINGLE_RUN_STATUS
            if qualification_mode == TARGET_BINARY_REQUAL
            else None
        )
        if summary.get("qualification_status") != expected_qualification_status:
            issues.append("SUMMARY_QUALIFICATION_STATUS_INVALID_FOR_MODE")
    if summary.get("deployment_eligible") is not False:
        issues.append("SUMMARY_DEPLOYMENT_FLAG_INVALID")
    runner_start = summary.get("runner_sha256_start", summary.get("runner_sha256"))
    runner_end = summary.get("runner_sha256_end")
    if (
        not _valid_sha(runner_start)
        or runner_start != runner_end
        or summary.get("runner_unchanged") is not True
    ):
        issues.append("SUMMARY_RUNNER_BINDING_INVALID")
    window = summary.get("window_contract")
    if not isinstance(window, dict) or any(
        not isinstance(window.get(field), str) or not window.get(field)
        for field in (
            "requested_from_date",
            "requested_to_date",
            "effective_from_date",
            "effective_to_date",
        )
    ):
        issues.append("SUMMARY_WINDOW_CONTRACT_INVALID")
    else:
        try:
            requested_from = dt.date.fromisoformat(window["requested_from_date"])
            requested_to = dt.date.fromisoformat(window["requested_to_date"])
            effective_from = dt.date.fromisoformat(window["effective_from_date"])
            effective_to = dt.date.fromisoformat(window["effective_to_date"])
        except (TypeError, ValueError):
            issues.append("SUMMARY_WINDOW_CONTRACT_INVALID")
        else:
            if not (
                requested_from <= effective_from <= effective_to <= requested_to
            ):
                issues.append("SUMMARY_WINDOW_CONTRACT_INVALID")
            for field in (
                "requested_from_date",
                "requested_to_date",
                "effective_from_date",
                "effective_to_date",
            ):
                if summary.get(field) != window.get(field):
                    issues.append("SUMMARY_WINDOW_BINDING_MISMATCH")
    cost = summary.get("cost_evidence")
    if summary.get("status") in {"PASS", "PASS_PARTIAL"} and (
        summary.get("cost_certified") is not True
        or not isinstance(cost, dict)
        or cost.get("status") != "CERTIFIED"
        or cost.get("cost_certified") is not True
        or cost.get("reasons") != []
        or cost.get("required_axes") != list(EXECUTION_COST_AXES)
        or not isinstance(cost.get("axes"), dict)
        or set(cost.get("axes") or {}) != set(EXECUTION_COST_AXES)
        or any(
            (cost.get("axes") or {}).get(axis, {}).get("status") != "PASS"
            for axis in EXECUTION_COST_AXES
        )
    ):
        issues.append("SUMMARY_COST_EVIDENCE_NOT_CERTIFIED")
    elif summary.get("status") in {"PASS", "PASS_PARTIAL"} and (
        not isinstance(cost.get("registry_paths"), list)
        or not cost.get("registry_paths")
        or not isinstance(cost.get("registry_sha256s"), list)
        or not cost.get("registry_sha256s")
        or any(not _valid_sha(value) for value in cost.get("registry_sha256s", []))
    ):
        issues.append("SUMMARY_COST_REGISTRY_UNBOUND")
    if summary.get("status") in {"PASS", "PASS_PARTIAL"}:
        registry_binding = summary.get("cost_registry")
        if (
            not isinstance(registry_binding, dict)
            or not isinstance(registry_binding.get("path"), str)
            or registry_binding.get("unchanged") is not True
            or not _valid_sha(registry_binding.get("sha256_start"))
            or registry_binding.get("sha256_start") != registry_binding.get("sha256_end")
            or not isinstance(cost, dict)
            or registry_binding.get("path") not in cost.get("registry_paths", [])
            or registry_binding.get("sha256_start")
            not in cost.get("registry_sha256s", [])
        ):
            issues.append("SUMMARY_COST_REGISTRY_SWEEP_BINDING_INVALID")
        manifest_binding = summary.get("execution_cost_evidence_manifest")
        selected_cost_sleeves = [
            {
                "ea_id": raw["job"].get("ea_id"),
                "symbol": raw["job"].get("symbol"),
                "timeframe": raw["job"].get("timeframe"),
                **(
                    {"variant_id": raw["job"].get("variant_id")}
                    if "variant_id" in raw["job"]
                    else {}
                ),
            }
            for raw in (summary.get("receipts") or [])
            if isinstance(raw, dict) and isinstance(raw.get("job"), dict)
        ]
        selected_cost_keys = {
            requal_runner._cost_sleeve_key(raw)
            for raw in selected_cost_sleeves
        }
        issues.extend(
            f"SUMMARY_{item}"
            for item in _execution_cost_manifest_issues(
                manifest_binding,
                manifest_sha256=manifest_sha256,
                required_keys=selected_cost_keys,
                required_sleeves=selected_cost_sleeves,
                window_contract=window if isinstance(window, dict) else {},
                repo_root=repo_root,
                as_of=as_of,
            )
        )
        start_binding = cost.get("execution_cost_evidence_manifest") if isinstance(cost, dict) else None
        if not isinstance(manifest_binding, dict) or not isinstance(start_binding, dict):
            issues.append("SUMMARY_EXECUTION_COST_MANIFEST_COST_BINDING_INVALID")
        else:
            for field in (
                "path",
                "sha256",
                "sidecar_path",
                "sidecar_sha256",
                "manifest_payload_sha256",
                "artifact_type",
                "scope",
                "source_manifest_sha256",
                "valid_from_utc",
                "valid_until_utc",
                "covered_keys",
                "covered_sleeves",
                "evaluation_window",
                "axes",
                "bound_artifacts",
                "semantic_contract_sha256",
                "axis_hashes_start",
            ):
                if start_binding.get(field) != manifest_binding.get(field):
                    issues.append("SUMMARY_EXECUTION_COST_MANIFEST_COST_BINDING_INVALID")
                    break
    receipts = summary.get("receipts")
    if not isinstance(receipts, list):
        return sorted(set(issues + ["SUMMARY_RECEIPTS_INVALID"]))
    try:
        declared_jobs = int(summary.get("n_jobs"))
    except (TypeError, ValueError):
        declared_jobs = -1
    if declared_jobs != len(receipts):
        issues.append("SUMMARY_JOB_COUNT_MISMATCH")
    try:
        declared_manifest_jobs = int(summary.get("manifest_jobs"))
    except (TypeError, ValueError):
        declared_manifest_jobs = -1
    if declared_manifest_jobs != manifest_count:
        issues.append("SUMMARY_MANIFEST_JOB_COUNT_MISMATCH")
    scope = str(summary.get("scope") or "")
    if scope not in {"FULL", "PARTIAL"}:
        issues.append("SUMMARY_SCOPE_INVALID")
    elif scope == "FULL" and declared_jobs != manifest_count:
        issues.append("SUMMARY_FULL_SCOPE_JOB_COUNT_MISMATCH")
    elif scope == "PARTIAL" and not 0 < declared_jobs < manifest_count:
        issues.append("SUMMARY_PARTIAL_SCOPE_JOB_COUNT_INVALID")
    counts: dict[str, int] = {}
    receipt_keys: list[str] = []
    receipt_manifest_fallbacks: dict[str, str] = {}
    for receipt in receipts:
        if not isinstance(receipt, dict):
            issues.append("SUMMARY_RECEIPT_INVALID")
            continue
        status = str(receipt.get("status") or "UNKNOWN")
        counts[status] = counts.get(status, 0) + 1
        job = receipt.get("job")
        if isinstance(job, dict):
            receipt_key = _sleeve_identity_key(
                job.get("ea_id"),
                job.get("symbol"),
                job.get("timeframe"),
                job.get("variant_id"),
            )
            receipt_keys.append(receipt_key)
            receipt_manifest_fallbacks[receipt_key] = _sleeve_identity_key(
                job.get("ea_id"),
                job.get("symbol"),
                None,
                job.get("variant_id"),
            )
    if summary.get("counts") != counts:
        issues.append("SUMMARY_COUNTS_MISMATCH")
    all_pass = counts == {"PASS": len(receipts)} and bool(receipts)
    if all_pass:
        expected_status = "PASS" if scope == "FULL" else "PASS_PARTIAL"
    elif set(counts).issubset({"PASS", "BLOCKED"}) and counts.get("BLOCKED"):
        expected_status = "INCOMPLETE"
    else:
        expected_status = "FAIL"
    if summary.get("status") != expected_status:
        issues.append("SUMMARY_STATUS_MISMATCH")
    if len(receipt_keys) != len(set(receipt_keys)):
        issues.append("SUMMARY_DUPLICATE_RECEIPT")
    extra = {
        key
        for key in receipt_keys
        if key not in manifest_keys
        and receipt_manifest_fallbacks.get(key) not in manifest_keys
    }
    if extra:
        issues.extend(f"SUMMARY_EXTRA_RECEIPT:{key}" for key in sorted(extra))
    return sorted(set(issues))


def _target_pair_validation(
    pair: Mapping[str, Any] | None,
    metadata: Mapping[str, Any] | None,
    *,
    summary: Mapping[str, Any],
    summary_path: str,
    summary_sha256: str,
    manifest_sha256: str,
    manifest_count: int,
    manifest_keys: set[str] | None = None,
) -> tuple[list[str], dict[str, Any] | None]:
    """Validate that a PASS pair exactly binds this TARGET summary and book."""

    if not isinstance(pair, Mapping):
        return ["TARGET_REPRODUCIBILITY_PAIR_MISSING"], None
    issues: list[str] = []
    metadata = metadata if isinstance(metadata, Mapping) else {}
    artifact_sha = metadata.get("artifact_sha256")
    if not _valid_sha(artifact_sha):
        issues.append("TARGET_PAIR_ARTIFACT_SHA256_INVALID")
    elif artifact_sha != target_pair_artifact_sha(pair):
        issues.append("TARGET_PAIR_ARTIFACT_SHA256_MISMATCH")
    if not isinstance(metadata.get("path"), str) or not metadata.get("path"):
        issues.append("TARGET_PAIR_PATH_MISSING")
    if not _valid_sha(metadata.get("sidecar_sha256")):
        issues.append("TARGET_PAIR_SIDECAR_SHA256_INVALID")
    if metadata.get("sidecar_declared_sha256") != artifact_sha:
        issues.append("TARGET_PAIR_SIDECAR_BINDING_MISMATCH")

    if pair.get("artifact_type") != TARGET_PAIR_ARTIFACT_TYPE:
        issues.append("TARGET_PAIR_ARTIFACT_TYPE_INVALID")
    if pair.get("schema_version") != TARGET_PAIR_SCHEMA_VERSION:
        issues.append("TARGET_PAIR_SCHEMA_VERSION_INVALID")
    if pair.get("qualification_mode") != TARGET_BINARY_REQUAL:
        issues.append("TARGET_PAIR_QUALIFICATION_MODE_INVALID")
    if pair.get("status") != "PASS":
        issues.append("TARGET_PAIR_STATUS_NOT_PASS")
    if pair.get("deployment_eligible") is not False:
        issues.append("TARGET_PAIR_DEPLOYMENT_FLAG_INVALID")
    if pair.get("issues") != []:
        issues.append("TARGET_PAIR_ISSUES_PRESENT")
    if not _embedded_hash_valid(pair, "pair_payload_sha256"):
        issues.append("TARGET_PAIR_PAYLOAD_SHA256_INVALID")
    if pair.get("source_manifest_sha256") != manifest_sha256:
        issues.append("TARGET_PAIR_SOURCE_MANIFEST_MISMATCH")

    contracts = pair.get("contracts")
    required_contracts = {
        "card",
        "artifact_override",
        "reference",
        "cost",
        "window",
    }
    if not isinstance(contracts, Mapping) or set(contracts) != required_contracts:
        issues.append("TARGET_PAIR_CONTRACT_SET_INVALID")
    elif any(
        not isinstance(contracts.get(name), Mapping)
        or contracts[name].get("status") != "PASS"
        or contracts[name].get("hash_bound") is not True
        for name in required_contracts
    ):
        issues.append("TARGET_PAIR_CONTRACT_NOT_PASS")

    axes = pair.get("identity_axes")
    if not isinstance(axes, Mapping) or set(axes) != set(TARGET_REPRODUCIBILITY_AXES):
        issues.append("TARGET_PAIR_IDENTITY_AXIS_SET_INVALID")
    else:
        for axis in TARGET_REPRODUCIBILITY_AXES:
            row = axes.get(axis)
            if (
                not isinstance(row, Mapping)
                or row.get("status") != "PASS"
                or row.get("missing_sleeves") != []
                or row.get("mismatched_sleeves") != []
                or row.get("invalid_sleeves") != []
                or len(row.get("matched_sleeves") or []) != manifest_count
            ):
                issues.append(f"TARGET_PAIR_IDENTITY_AXIS_NOT_PASS:{axis}")

    gap = pair.get("runner_contract_gap")
    if (
        not isinstance(gap, Mapping)
        or gap.get("status") != "CLOSED"
        or gap.get("missing_required_axes") != []
    ):
        issues.append("TARGET_PAIR_RUNNER_CONTRACT_GAP_OPEN")
    intervals = pair.get("run_intervals")
    if (
        not isinstance(intervals, Mapping)
        or intervals.get("serial_non_overlapping") is not True
        or not isinstance(intervals.get("summary_a"), Mapping)
        or not isinstance(intervals.get("summary_b"), Mapping)
    ):
        issues.append("TARGET_PAIR_RUN_INTERVALS_NOT_SERIAL")

    compared = pair.get("compared_sleeves")
    compared_keys: list[str] = []
    if not isinstance(compared, list) or len(compared) != manifest_count:
        issues.append("TARGET_PAIR_COMPARED_SLEEVE_COUNT_MISMATCH")
    else:
        for row in compared:
            if not isinstance(row, Mapping) or row.get("status") != "PASS":
                issues.append("TARGET_PAIR_COMPARED_SLEEVE_NOT_PASS")
                continue
            row_axes = row.get("identity_axes")
            if (
                not isinstance(row_axes, Mapping)
                or set(row_axes) != set(TARGET_REPRODUCIBILITY_AXES)
                or any(row_axes.get(axis) != "PASS" for axis in TARGET_REPRODUCIBILITY_AXES)
            ):
                issues.append("TARGET_PAIR_COMPARED_SLEEVE_AXES_INVALID")
            try:
                compared_keys.append(
                    _sleeve_identity_key(
                        row.get("ea_id"),
                        row.get("symbol"),
                        row.get("timeframe"),
                        None
                        if row.get("variant_id")
                        in (None, "", "VARIANT_UNSPECIFIED")
                        else row.get("variant_id"),
                    )
                )
            except (TypeError, ValueError):
                issues.append("TARGET_PAIR_COMPARED_SLEEVE_IDENTITY_INVALID")
        if len(compared_keys) != len(set(compared_keys)):
            issues.append("TARGET_PAIR_COMPARED_SLEEVE_DUPLICATE")
        if manifest_keys is not None:
            if any(":*:" in key for key in manifest_keys):
                issues.append("TARGET_PAIR_SOURCE_MANIFEST_IDENTITY_NOT_EXACT")
            elif set(compared_keys) != manifest_keys:
                issues.append("TARGET_PAIR_COMPARED_SLEEVE_SET_MISMATCH")

    summary_matches: list[str] = []
    expected_summary_payload_sha = summary.get("summary_sha256")
    expected_summary_path = _path_identity(Path(summary_path))
    for label in ("summary_a", "summary_b"):
        bound = pair.get(label)
        if not isinstance(bound, Mapping):
            issues.append(f"TARGET_PAIR_{label.upper()}_BINDING_MISSING")
            continue
        if not _valid_sha(bound.get("file_sha256")):
            issues.append(f"TARGET_PAIR_{label.upper()}_FILE_SHA256_INVALID")
        if not _valid_sha(bound.get("payload_sha256")):
            issues.append(f"TARGET_PAIR_{label.upper()}_PAYLOAD_SHA256_INVALID")
        if (
            bound.get("file_sha256") == summary_sha256
            and bound.get("payload_sha256") == expected_summary_payload_sha
            and bound.get("run_id") == summary.get("run_id")
            and isinstance(bound.get("path"), str)
            and _path_identity(Path(str(bound.get("path")))) == expected_summary_path
        ):
            summary_matches.append(label)
    if len(summary_matches) != 1:
        issues.append("TARGET_PAIR_CURRENT_SUMMARY_BINDING_NOT_EXACT")
    summary_a = pair.get("summary_a")
    summary_b = pair.get("summary_b")
    if isinstance(summary_a, Mapping) and isinstance(summary_b, Mapping):
        if (
            summary_a.get("run_id") == summary_b.get("run_id")
            or summary_a.get("file_sha256") == summary_b.get("file_sha256")
        ):
            issues.append("TARGET_PAIR_RUNS_NOT_DISTINCT")

    binding = {
        "path": metadata.get("path"),
        "artifact_sha256": artifact_sha,
        "sha256": artifact_sha,
        "payload_sha256": pair.get("pair_payload_sha256"),
        "sidecar_path": metadata.get("sidecar_path"),
        "sidecar_sha256": metadata.get("sidecar_sha256"),
        "sidecar_declared_sha256": metadata.get("sidecar_declared_sha256"),
        "status": pair.get("status"),
        "qualification_mode": pair.get("qualification_mode"),
        "source_manifest_sha256": pair.get("source_manifest_sha256"),
        "current_summary_role": summary_matches[0] if len(summary_matches) == 1 else None,
        "summary_a_run_id": (
            summary_a.get("run_id") if isinstance(summary_a, Mapping) else None
        ),
        "summary_b_run_id": (
            summary_b.get("run_id") if isinstance(summary_b, Mapping) else None
        ),
    }
    return sorted(set(issues)), binding


def _target_card_contract_issues(
    card_contract: Any,
    contract: Mapping[str, Any],
    resolved_identity: ContractIdentity,
    *,
    repo_root: Path,
) -> list[str]:
    if (
        not isinstance(card_contract, Mapping)
        or not isinstance(card_contract.get("path"), str)
        or not _valid_sha(card_contract.get("sha256"))
        or resolved_identity[1] is None
        or resolved_identity[2] is None
        or resolved_identity[3] is None
    ):
        return ["RECEIPT_TARGET_CARD_CONTRACT_UNBOUND"]
    try:
        verified_card = requal_runner.resolve_card_contract_binding(
            dict(card_contract),
            manifest_dir=repo_root,
            required=True,
            identity_label=_identity_label(resolved_identity),
            expected_identity=(
                resolved_identity[0],
                resolved_identity[1],
                resolved_identity[2],
                resolved_identity[3],
            ),
        )
    except (OSError, requal_runner.RequalError, ValueError):
        return ["RECEIPT_TARGET_CARD_CONTRACT_INVALID_OR_UNAPPROVED"]
    registry_card = _safe_resolve(contract.get("card_ref"), repo_root)
    if (
        verified_card is None
        or registry_card is None
        or not registry_card.is_file()
        or Path(verified_card["path"]).resolve() != registry_card.resolve()
        or verified_card["sha256"] != sha256_file(registry_card)
    ):
        return ["RECEIPT_TARGET_CARD_NOT_EXACT_REGISTRY_CARD"]
    return []


def _receipt_issues(
    receipt: Mapping[str, Any],
    sleeve: Mapping[str, Any],
    contract: Mapping[str, Any],
    resolved_identity: ContractIdentity,
    *,
    summary: Mapping[str, Any],
    repo_root: Path,
) -> list[str]:
    issues: list[str] = []
    if receipt.get("schema_version") != RUNNER_SCHEMA_VERSION:
        issues.append("RECEIPT_SCHEMA_INVALID")
    if not _embedded_hash_valid(receipt, "receipt_sha256"):
        issues.append("RECEIPT_SHA256_INVALID")
    if receipt.get("status") != "PASS":
        issues.append(f"RECEIPT_STATUS_{str(receipt.get('status') or 'MISSING').upper()}")
    blockers = receipt.get("blockers")
    if blockers != []:
        issues.append("RECEIPT_HAS_BLOCKERS")
    if receipt.get("technical_status") != "PASS":
        issues.append("RECEIPT_TECHNICAL_STATUS_NOT_PASS")
    qualification_mode = summary.get("qualification_mode")
    if (
        qualification_mode not in QUALIFYING_MODES
        or receipt.get("qualification_mode") != qualification_mode
    ):
        issues.append("RECEIPT_QUALIFICATION_MODE_MISMATCH")
    elif qualification_mode == AS_LIVE_REQUAL:
        if receipt.get("artifact_override_manifest") is not None:
            issues.append("RECEIPT_ARTIFACT_OVERRIDE_FORBIDDEN")
        if receipt.get("artifact_source") != "CANONICAL_T_LIVE":
            issues.append("RECEIPT_ARTIFACT_SOURCE_NOT_CANONICAL_LIVE")
        if receipt.get("qualification_status") != "QUALIFIED":
            issues.append("RECEIPT_QUALIFICATION_STATUS_NOT_QUALIFIED")
    elif qualification_mode == TARGET_BINARY_REQUAL:
        target_override = summary.get("artifact_override_manifest")
        if (
            not isinstance(target_override, Mapping)
            or receipt.get("artifact_override_manifest") != target_override
        ):
            issues.append("RECEIPT_TARGET_ARTIFACT_OVERRIDE_MISMATCH")
        if receipt.get("artifact_source") != requal_runner.TARGET_ARTIFACT_SOURCE:
            issues.append("RECEIPT_TARGET_ARTIFACT_SOURCE_INVALID")
        if receipt.get("qualification_status") != TARGET_SINGLE_RUN_STATUS:
            issues.append("RECEIPT_TARGET_REPRODUCIBILITY_STATUS_INVALID")

        job = receipt.get("job") if isinstance(receipt.get("job"), Mapping) else {}
        target_rows = (
            target_override.get("bound_artifacts")
            if isinstance(target_override, Mapping)
            else []
        )
        matches = [
            row
            for row in (target_rows or [])
            if isinstance(row, Mapping)
            and row.get("ea_id") == job.get("ea_id")
            and row.get("symbol") == job.get("symbol")
            and row.get("timeframe") == job.get("timeframe")
            and row.get("variant_id") == job.get("variant_id")
        ]
        identity = receipt.get("identity")
        if not isinstance(identity, Mapping) or len(matches) != 1:
            issues.append("RECEIPT_TARGET_ARTIFACT_IDENTITY_UNBOUND")
        else:
            target_row = matches[0]
            if (
                identity.get("source_ex5_sha256") != target_row.get("ex5_sha256")
                or identity.get("source_ex5_sha256_before") != target_row.get("ex5_sha256")
                or identity.get("staged_ex5_sha256") != target_row.get("ex5_sha256")
                or identity.get("source_set_sha256") != target_row.get("set_sha256")
                or identity.get("source_set_sha256_before") != target_row.get("set_sha256")
                or identity.get("staged_preset_sha256") != target_row.get("set_sha256")
                or identity.get("artifact_source") != requal_runner.TARGET_ARTIFACT_SOURCE
            ):
                issues.append("RECEIPT_TARGET_ARTIFACT_HASH_BINDING_INVALID")
        execution = receipt.get("execution")
        if (
            not isinstance(execution, Mapping)
            or not isinstance(execution.get("sandbox_derivation"), Mapping)
            or execution.get("sandbox_derivation_end")
            != execution.get("sandbox_derivation")
            or execution.get("sandbox_derivation_unchanged") is not True
        ):
            issues.append("RECEIPT_TARGET_SANDBOX_DERIVATION_INVALID")
        reproducibility = receipt.get("reproducibility_identity")
        axes = reproducibility if isinstance(reproducibility, Mapping) else {}
        if axes.get("schema_version") != 1:
            issues.append("RECEIPT_TARGET_REPRODUCIBILITY_IDENTITY_INVALID")
        for axis in TARGET_REPRODUCIBILITY_AXES:
            row = axes.get(axis)
            if (
                not isinstance(row, Mapping)
                or row.get("complete") is not True
                or not isinstance(row.get("count"), int)
                or row.get("count") < 1
                or not _valid_sha(row.get("sha256"))
            ):
                issues.append(f"RECEIPT_TARGET_REPRODUCIBILITY_AXIS_INVALID:{axis}")
        issues.extend(
            _target_card_contract_issues(
                receipt.get("card_contract"),
                contract,
                resolved_identity,
                repo_root=repo_root,
            )
        )
    if receipt.get("deployment_eligible") is not False:
        issues.append("RECEIPT_DEPLOYMENT_FLAG_INVALID")
    if receipt.get("runner_sha256") != summary.get(
        "runner_sha256_start", summary.get("runner_sha256")
    ):
        issues.append("RECEIPT_RUNNER_SHA256_MISMATCH")
    if receipt.get("window_contract") != summary.get("window_contract"):
        issues.append("RECEIPT_WINDOW_CONTRACT_MISMATCH")
    elif isinstance(receipt.get("window_contract"), dict):
        for field in (
            "requested_from_date",
            "requested_to_date",
            "effective_from_date",
            "effective_to_date",
        ):
            if receipt.get(field) != receipt["window_contract"].get(field):
                issues.append("RECEIPT_WINDOW_BINDING_MISMATCH")

    preset_contract = receipt.get("live_preset_contract")
    if (
        not isinstance(preset_contract, dict)
        or preset_contract.get("unchanged") is not True
        or any(
            not isinstance(preset_contract.get(stage), dict)
            or preset_contract[stage].get("status") != "PASS"
            or preset_contract[stage].get("blockers") != []
            for stage in ("before", "staged", "after")
        )
        or preset_contract.get("before") != preset_contract.get("after")
    ):
        issues.append("RECEIPT_LIVE_PRESET_CONTRACT_INVALID")

    cost = receipt.get("cost_evidence")
    if (
        receipt.get("cost_certified") is not True
        or not isinstance(cost, dict)
        or cost.get("status") != "CERTIFIED"
        or cost.get("cost_certified") is not True
        or cost.get("reasons") != []
        or cost.get("required_axes") != list(EXECUTION_COST_AXES)
        or not isinstance(cost.get("axes"), dict)
        or set(cost.get("axes") or {}) != set(EXECUTION_COST_AXES)
    ):
        issues.append("RECEIPT_COST_EVIDENCE_NOT_CERTIFIED")
    else:
        registry_ref = cost.get("registry_path")
        registry = _safe_resolve(registry_ref, repo_root)
        if (
            registry is None
            or not registry.is_file()
            or not _valid_sha(cost.get("registry_sha256"))
            or sha256_file(registry) != cost.get("registry_sha256")
        ):
            issues.append("RECEIPT_COST_REGISTRY_BINDING_INVALID")
        for axis in EXECUTION_COST_AXES:
            axis_row = cost["axes"].get(axis)
            if (
                not isinstance(axis_row, dict)
                or axis_row.get("status") != "PASS"
                or axis_row.get("source")
                != "IMMUTABLE_EXTERNAL_EXECUTION_COST_EVIDENCE"
                or axis_row.get("reasons") != []
                or not isinstance(axis_row.get("parameters"), dict)
                or not axis_row.get("parameters")
                or not isinstance(axis_row.get("scenarios"), list)
                or not axis_row.get("scenarios")
                or not isinstance(axis_row.get("results"), dict)
            ):
                issues.append(f"RECEIPT_COST_AXIS_NOT_CERTIFIED:{axis}")
                continue
            issues.extend(
                f"RECEIPT_COST_AXIS_{axis.upper()}:{item}"
                for item in _artifact_binding_issues(
                    axis_row.get("evidence"),
                    repo_root=repo_root,
                    prefix="EVIDENCE",
                )
            )
            summary_manifest_axes = (
                (summary.get("execution_cost_evidence_manifest") or {}).get("axes")
                if isinstance(summary.get("execution_cost_evidence_manifest"), dict)
                else None
            )
            expected_axis_rows = (
                summary_manifest_axes.get(axis)
                if isinstance(summary_manifest_axes, dict)
                else None
            )
            receipt_job = receipt.get("job") if isinstance(receipt.get("job"), dict) else {}
            receipt_identity = {
                "ea_id": receipt_job.get("ea_id"),
                "symbol": str(receipt_job.get("symbol") or "").upper(),
                "timeframe": str(receipt_job.get("timeframe") or "").upper(),
                **(
                    {"variant_id": receipt_job.get("variant_id")}
                    if "variant_id" in receipt_job
                    else {}
                ),
            }
            matching = [
                row
                for row in (expected_axis_rows or [])
                if isinstance(row, dict)
                and receipt_identity in (row.get("covered_sleeves") or [])
            ]
            evidence = axis_row.get("evidence")
            expected_evidence_fields = (
                "path",
                "sha256",
                "sidecar_path",
                "sidecar_sha256",
                "schema_version",
                "artifact_type",
                "axis",
                "evidence_type",
                "status",
                "artifact_payload_sha256",
                "source_manifest_sha256",
                "covered_sleeves",
                "evaluation_window",
                "valid_from_utc",
                "valid_until_utc",
            )
            if (
                len(matching) != 1
                or not isinstance(evidence, dict)
                or any(
                    evidence.get(field) != matching[0].get(field)
                    for field in expected_evidence_fields
                )
                or canonical_json_sha(axis_row["parameters"])
                != matching[0].get("parameters_sha256")
                or canonical_json_sha(axis_row["scenarios"])
                != matching[0].get("scenarios_sha256")
                or canonical_json_sha(axis_row["results"])
                != matching[0].get("results_sha256")
            ):
                issues.append(f"RECEIPT_COST_AXIS_SEMANTIC_BINDING_INVALID:{axis}")
        summary_manifest = summary.get("execution_cost_evidence_manifest")
        receipt_manifest = receipt.get("execution_cost_evidence_manifest")
        cost_manifest = cost.get("execution_cost_evidence_manifest")
        if not all(
            isinstance(item, dict)
            for item in (summary_manifest, receipt_manifest, cost_manifest)
        ):
            issues.append("RECEIPT_EXECUTION_COST_MANIFEST_BINDING_INVALID")
        else:
            for field in (
                "path",
                "sha256",
                "sidecar_path",
                "sidecar_sha256",
                "manifest_payload_sha256",
                "scope",
                "source_manifest_sha256",
                "valid_from_utc",
                "valid_until_utc",
                "covered_keys",
                "covered_sleeves",
                "evaluation_window",
                "axes",
                "bound_artifacts",
                "semantic_contract_sha256",
                "axis_hashes_start",
            ):
                if not (
                    receipt_manifest.get(field)
                    == cost_manifest.get(field)
                    == summary_manifest.get(field)
                ):
                    issues.append("RECEIPT_EXECUTION_COST_MANIFEST_BINDING_INVALID")
                    break

    execution_evidence = receipt.get("native_report_execution_evidence")
    if not isinstance(execution_evidence, dict):
        issues.append("RECEIPT_NATIVE_EXECUTION_EVIDENCE_MISSING")
    else:
        quality = " ".join(
            str(execution_evidence.get("history_quality") or "").split()
        ).casefold()
        if quality != "100% real ticks" or execution_evidence.get(
            "real_ticks_certified"
        ) is not True:
            issues.append("RECEIPT_HISTORY_QUALITY_NOT_REAL_TICKS")
        for field in ("bars", "ticks", "symbol_count"):
            value = execution_evidence.get(field)
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                issues.append(f"RECEIPT_NATIVE_{field.upper()}_INVALID")

    job = receipt.get("job")
    if not isinstance(job, dict):
        return sorted(set(issues + ["RECEIPT_JOB_INVALID"]))
    (
        identity_ea,
        identity_symbol,
        identity_timeframe,
        identity_variant_id,
    ) = resolved_identity
    comparisons = {
        "EA_ID": (job.get("ea_id"), sleeve.get("ea_id")),
        "SYMBOL": (str(job.get("symbol") or "").upper(), str(sleeve.get("symbol") or "").upper()),
        "EA_LABEL": (job.get("ea_label"), sleeve.get("ea_label")),
        "CONTRACT_EA_ID": (job.get("ea_id"), identity_ea),
        "CONTRACT_SYMBOL": (str(job.get("symbol") or "").upper(), identity_symbol),
        "TIMEFRAME": (str(job.get("timeframe") or "").upper(), identity_timeframe),
        "VARIANT": (job.get("variant_id"), identity_variant_id),
        "CONTRACT_STRATEGY_TIMEFRAME": (
            identity_timeframe,
            contract.get("strategy_timeframe"),
        ),
    }
    if sleeve.get("timeframe") is not None:
        comparisons["MANIFEST_TIMEFRAME"] = (
            str(job.get("timeframe") or "").upper(),
            sleeve.get("timeframe"),
        )
    for label, (observed, expected) in comparisons.items():
        if observed != expected:
            issues.append(f"RECEIPT_{label}_MISMATCH")
    if job.get("manifest_trades") != sleeve.get("trades"):
        issues.append("RECEIPT_MANIFEST_TRADES_MISMATCH")

    identity = receipt.get("identity")
    if not isinstance(identity, dict):
        return sorted(set(issues + ["RECEIPT_IDENTITY_INVALID"]))
    required_hashes = (
        "live_ex5_sha256",
        "live_ex5_sha256_before",
        "staged_ex5_sha256",
        "live_preset_sha256",
        "live_preset_sha256_before",
        "staged_preset_sha256",
        "tester_ini_sha256",
        "native_report_sha256",
        "report_trade_stream_sha256",
        "q08_stream_sha256",
        "reference_stream_sha256",
        "reference_expected_sha256",
    )
    for field in required_hashes:
        if not _valid_sha(identity.get(field)):
            issues.append(f"RECEIPT_{field.upper()}_UNBOUND")
    if identity.get("live_ex5_sha256") != identity.get("staged_ex5_sha256"):
        issues.append("RECEIPT_EX5_STAGING_MISMATCH")
    if identity.get("live_ex5_sha256") != identity.get("live_ex5_sha256_before"):
        issues.append("RECEIPT_EX5_SOURCE_CHANGED")
    if identity.get("live_preset_sha256") != identity.get("staged_preset_sha256"):
        issues.append("RECEIPT_PRESET_STAGING_MISMATCH")
    if identity.get("live_preset_sha256") != identity.get("live_preset_sha256_before"):
        issues.append("RECEIPT_PRESET_SOURCE_CHANGED")
    if identity.get("reference_stream_sha256") != identity.get(
        "reference_expected_sha256"
    ):
        issues.append("RECEIPT_REFERENCE_EXPECTED_HASH_MISMATCH")
    if not isinstance(identity.get("reference_frozen_relative_path"), str) or not identity.get(
        "reference_frozen_relative_path"
    ):
        issues.append("RECEIPT_REFERENCE_FROZEN_PATH_UNBOUND")
    historical_axis = (
        cost.get("axes", {}).get("historical_tester_spread")
        if isinstance(cost, dict)
        else None
    )
    historical_native = (
        historical_axis.get("native_report_evidence")
        if isinstance(historical_axis, dict)
        else None
    )
    if (
        not isinstance(historical_native, dict)
        or historical_native.get("native_report_sha256")
        != identity.get("native_report_sha256")
        or historical_native.get("history_quality")
        != (
            execution_evidence.get("history_quality")
            if isinstance(execution_evidence, dict)
            else None
        )
        or historical_native.get("real_ticks_certified") is not True
    ):
        issues.append("RECEIPT_HISTORICAL_SPREAD_NATIVE_BINDING_INVALID")

    capture = receipt.get("common_stream_capture")
    if not isinstance(capture, dict):
        issues.append("RECEIPT_Q08_CAPTURE_INVALID")
    else:
        if capture.get("captured") is not True:
            issues.append("RECEIPT_Q08_NOT_CAPTURED")
        if capture.get("restored") is not True:
            issues.append("RECEIPT_COMMON_STREAM_NOT_RESTORED")
        if capture.get("stream_sha256") != identity.get("q08_stream_sha256"):
            issues.append("RECEIPT_Q08_HASH_MISMATCH")

    if receipt.get("manifest_count_match") is not True:
        issues.append("RECEIPT_MANIFEST_COUNT_NOT_MATCHED")
    if receipt.get("reference_close_sequence_match") is not True:
        issues.append("RECEIPT_REFERENCE_SEQUENCE_NOT_MATCHED")
    if receipt.get("q08_reference_signal_identity_match") is not True:
        issues.append("RECEIPT_REFERENCE_SIGNAL_IDENTITY_NOT_MATCHED")
    if receipt.get("q08_reference_outcome_sign_match") is not True:
        issues.append("RECEIPT_REFERENCE_OUTCOME_SIGN_NOT_MATCHED")
    observed = receipt.get("observed_trade_stats")
    if not isinstance(observed, dict) or observed.get("trades") != sleeve.get("trades"):
        issues.append("RECEIPT_OBSERVED_TRADES_MISMATCH")

    execution = receipt.get("execution")
    if not isinstance(execution, dict):
        issues.append("RECEIPT_EXECUTION_INVALID")
    else:
        if execution.get("timed_out") is not False or execution.get("exit_code") != 0:
            issues.append("RECEIPT_EXECUTION_NOT_CLEAN")
        if execution.get("currency") != "EUR" or execution.get("deposit") != 100_000:
            issues.append("RECEIPT_TESTER_ACCOUNT_CONTRACT_MISMATCH")
        window = summary.get("window_contract") if isinstance(summary.get("window_contract"), dict) else {}
        expected_from = str(window.get("requested_from_date") or "").replace("-", ".")
        expected_to = str(window.get("requested_to_date") or "").replace("-", ".")
        if execution.get("from_date") != expected_from or execution.get("to_date") != expected_to:
            issues.append("RECEIPT_TEST_WINDOW_MISMATCH")
        for field in (
            "requested_from_date",
            "requested_to_date",
            "effective_from_date",
            "effective_to_date",
        ):
            if execution.get(field) != window.get(field):
                issues.append("RECEIPT_EXECUTION_WINDOW_BINDING_MISMATCH")
    return sorted(set(issues))


def _contract_file_binding(contract: Mapping[str, Any], repo_root: Path) -> dict[str, Any]:
    source = _safe_resolve(contract.get("source"), repo_root)
    card = _safe_resolve(contract.get("card_ref"), repo_root)
    return {
        "contract_sha256": canonical_json_sha(contract),
        "source_path": str(source) if source else None,
        "source_sha256": sha256_file(source) if source and source.is_file() else None,
        "card_path": str(card) if card else None,
        "card_sha256": sha256_file(card) if card and card.is_file() else None,
    }


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def _controlled_source_tree(source: Path, repo_root: Path) -> dict[str, Any]:
    """Hash repo-controlled MQL inputs and report their newest mtime.

    Platform-library includes are intentionally not claimed here.  Missing
    ``QM/...`` includes are blockers; unresolved MetaQuotes standard-library
    includes are recorded but are not mistaken for repo-controlled source.
    """

    include_root = repo_root / "framework" / "include"
    roots = (source.parent, include_root)
    pending = [source]
    visited: set[str] = set()
    records: list[dict[str, Any]] = []
    unresolved_controlled: set[str] = set()
    unresolved_platform: set[str] = set()
    while pending:
        current = pending.pop()
        identity = str(current.resolve()).casefold()
        if identity in visited:
            continue
        visited.add(identity)
        if not current.is_file() or not _is_within(current, repo_root):
            unresolved_controlled.add(str(current))
            continue
        stat = current.stat()
        records.append(
            {
                "path": str(current.resolve()),
                "sha256": sha256_file(current),
                "size_bytes": stat.st_size,
                "modified_ns": stat.st_mtime_ns,
            }
        )
        text = current.read_text(encoding="utf-8-sig", errors="replace")
        for match in INCLUDE_RE.finditer(text):
            token = match.group("name").strip()
            normalized = token.replace("\\", "/")
            candidates = [
                current.parent / Path(normalized),
                include_root / Path(normalized),
            ]
            target = next((item for item in candidates if item.is_file()), None)
            if target is not None and _is_within(target, repo_root):
                pending.append(target)
            elif normalized.casefold().startswith("qm/"):
                unresolved_controlled.add(token)
            else:
                unresolved_platform.add(token)
    records.sort(key=lambda item: str(item["path"]).casefold())
    digest_rows = [
        {"path": item["path"], "sha256": item["sha256"], "size_bytes": item["size_bytes"]}
        for item in records
    ]
    return {
        "aggregate_sha256": canonical_json_sha(digest_rows) if records else None,
        "file_count": len(records),
        "newest_modified_ns": max((int(item["modified_ns"]) for item in records), default=None),
        "files": records,
        "unresolved_controlled": sorted(unresolved_controlled),
        "unresolved_platform": sorted(unresolved_platform),
    }


def _promotion_resolution(
    contract: Mapping[str, Any],
    receipt: Mapping[str, Any],
    *,
    repo_root: Path,
) -> dict[str, Any]:
    """Resolve only reasons that a perfect receipt can prove mechanically."""

    promotion = contract.get("promotion") if isinstance(contract.get("promotion"), dict) else {}
    reasons = [str(item) for item in promotion.get("block_reasons", [])]
    source = _safe_resolve(contract.get("source"), repo_root)
    repo_ex5 = source.with_suffix(".ex5") if source is not None else None
    identity = receipt.get("identity") if isinstance(receipt.get("identity"), dict) else {}
    live_ex5_sha = identity.get("live_ex5_sha256")
    blockers: list[str] = []
    rebuild_blockers: list[str] = []
    source_tree: dict[str, Any] | None = None
    repo_ex5_sha: str | None = None
    repo_ex5_modified_ns: int | None = None

    machine_reasons = [item for item in reasons if item in MACHINE_RESOLVABLE_REASONS]
    semantic_reasons = [item for item in reasons if item not in MACHINE_RESOLVABLE_REASONS]
    resolved: list[str] = []
    if machine_reasons:
        # _promotion_resolution is called only after the full receipt gate has
        # passed.  That receipt qualifies the exact preserved live EX5.  It does
        # not automatically qualify a different/current repo build.
        resolved.extend(machine_reasons)
        if source is None or not source.is_file():
            rebuild_blockers.append("PROMOTION_SOURCE_MISSING")
        else:
            source_tree = _controlled_source_tree(source, repo_root)
            if source_tree["unresolved_controlled"]:
                rebuild_blockers.append("PROMOTION_CONTROLLED_INCLUDE_UNRESOLVED")
        if repo_ex5 is None or not repo_ex5.is_file():
            rebuild_blockers.append("PROMOTION_REPO_EX5_MISSING")
        else:
            repo_ex5_sha = sha256_file(repo_ex5)
            repo_ex5_modified_ns = repo_ex5.stat().st_mtime_ns
            if repo_ex5_sha != live_ex5_sha:
                rebuild_blockers.append("PROMOTION_LIVE_REPO_EX5_MISMATCH")
        if (
            source_tree is not None
            and repo_ex5_modified_ns is not None
            and source_tree.get("newest_modified_ns") is not None
            and repo_ex5_modified_ns < int(source_tree["newest_modified_ns"])
        ):
            rebuild_blockers.append("PROMOTION_REPO_EX5_PREDATES_SOURCE_TREE")

    unresolved = sorted(set(semantic_reasons + [item for item in machine_reasons if item not in resolved]))
    rebuild_blockers = sorted(set(rebuild_blockers))
    rebuild_status = "BOUND_TO_RECEIPT" if machine_reasons and not rebuild_blockers else "REQUAL_REQUIRED"
    resolution_scope = (
        "AS_LIVE_AND_CURRENT_REPO_BINARY"
        if rebuild_status == "BOUND_TO_RECEIPT"
        else "AS_LIVE_BINARY_RETENTION_ONLY"
        if machine_reasons
        else "NONE"
    )
    return {
        "policy": "ONLY_EXPLICIT_MACHINE_REASONS_AUTO_RESOLVE",
        "resolution_scope": resolution_scope,
        "machine_resolvable_allowlist": sorted(MACHINE_RESOLVABLE_REASONS),
        "requested_reasons": reasons,
        "resolved_reasons": sorted(set(resolved)),
        "unresolved_reasons": unresolved,
        "blockers": sorted(set(blockers)),
        "repo_rebuild_status": rebuild_status,
        "repo_rebuild_blockers": rebuild_blockers,
        "repo_ex5": {
            "path": str(repo_ex5) if repo_ex5 else None,
            "sha256": repo_ex5_sha,
            "modified_ns": repo_ex5_modified_ns,
            "matches_receipt_live_ex5": bool(repo_ex5_sha and repo_ex5_sha == live_ex5_sha),
        },
        "controlled_source_tree": source_tree,
    }


def _candidate_sleeve(
    sleeve: Mapping[str, Any],
    contract: Mapping[str, Any],
    receipt: Mapping[str, Any],
    resolved_contract_identity: ContractIdentity,
    *,
    repo_root: Path,
    summary_path: str,
    summary_sha256: str,
    classification: str,
    effective_qualification_status: str | None = None,
    target_pair_binding: Mapping[str, Any] | None = None,
    promotion_resolution: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    identity = receipt["identity"]
    execution = receipt["execution"]
    allowed = (
        "ea_id",
        "symbol",
        "timeframe",
        "variant_id",
        "ea_label",
        "magic_number",
        "weight",
        "risk_percent",
        "trades",
        "new_candidate",
    )
    row = {field: sleeve.get(field) for field in allowed if field in sleeve}
    (
        contract_ea_id,
        contract_symbol,
        contract_timeframe,
        contract_variant_id,
    ) = resolved_contract_identity
    row["timeframe"] = contract_timeframe
    if contract_variant_id is not None:
        row["variant_id"] = contract_variant_id
    execution_contract = {
        "ea_id": contract_ea_id,
        "symbol": contract_symbol,
        "timeframe": contract_timeframe,
        "variant_id": contract_variant_id,
        "identity": _identity_label(resolved_contract_identity),
        "registry_scope": (
            "SLEEVE"
            if contract.get("symbol") is not None
            else "LEGACY_EA_UNIQUE_FALLBACK"
        ),
        "strategy_timeframe": contract.get("strategy_timeframe"),
        "bar_gate_timeframe": contract.get("bar_gate_timeframe"),
        "friday_close": contract.get("friday_close"),
        "calendar": contract.get("calendar"),
    }
    routing = contract.get("darwinex_zero_routing")
    if isinstance(routing, dict):
        execution_contract["darwinex_zero_routing"] = dict(routing)
    row["execution_contract"] = execution_contract
    contract_binding = _contract_file_binding(contract, repo_root)
    ordinal = int(receipt.get("job", {}).get("ordinal") or 0)
    run_slug = (
        f"{ordinal:02d}_{int(sleeve['ea_id'])}_"
        f"{str(sleeve['symbol']).replace('.', '_')}"
    )
    run_dir = Path(summary_path).parent / "runs" / run_slug
    artifact_bindings = {
        "execution_contract_sha256": contract_binding["contract_sha256"],
        "strategy_card": contract_binding["card_path"],
        "strategy_card_sha256": contract_binding["card_sha256"],
        "mq5_path": contract_binding["source_path"],
        "mq5_sha256": contract_binding["source_sha256"],
        # The as-live qualification deliberately binds the preserved live EX5
        # and preset.  It does not silently substitute a current repo build or
        # a historical backtest preset.
        "qualified_ex5_path": identity.get("live_ex5_path"),
        "qualified_ex5_sha256": identity.get("live_ex5_sha256"),
        "qualified_set_path": identity.get("live_preset_path"),
        "qualified_set_sha256": identity.get("live_preset_sha256"),
        "qualified_stream_path": str(run_dir / "q08_stream.jsonl"),
        "qualified_stream_sha256": identity.get("q08_stream_sha256"),
        "live_ex5_path": identity.get("live_ex5_path"),
        "live_ex5_sha256": identity.get("live_ex5_sha256"),
        "live_preset_path": identity.get("live_preset_path"),
        "qualified_live_preset_path": identity.get("live_preset_path"),
        "qualified_live_preset_sha256": identity.get("live_preset_sha256"),
        "receipt_path": str(run_dir / "receipt.json"),
        "receipt_sha256": receipt.get("receipt_sha256"),
        "tester_ini_sha256": identity.get("tester_ini_sha256"),
        "native_report_path": str(run_dir / "report.htm"),
        "native_report_sha256": identity.get("native_report_sha256"),
        "report_trade_stream_path": str(run_dir / "report_trade_stream.jsonl"),
        "qualified_report_stream_sha256": identity.get("report_trade_stream_sha256"),
        "reference_stream_path": identity.get("reference_stream_path"),
        "reference_stream_sha256": identity.get("reference_stream_sha256"),
    }
    row["artifact_bindings"] = artifact_bindings
    row["qualification"] = {
        "status": (
            "BOUND_PASS_EVIDENCE_PROMOTED"
            if classification == "KEEP_CANDIDATE"
            else "BOUND_PASS"
        ),
        "classification": classification,
        "contract_identity": _identity_label(resolved_contract_identity),
        "qualification_mode": receipt.get("qualification_mode"),
        "qualification_status": (
            effective_qualification_status or receipt.get("qualification_status")
        ),
        "single_run_qualification_status": receipt.get("qualification_status"),
        "window_contract": receipt.get("window_contract"),
        "cost_certified": receipt.get("cost_certified"),
        "cost_evidence": receipt.get("cost_evidence"),
        "execution_cost_evidence_manifest": receipt.get(
            "execution_cost_evidence_manifest"
        ),
        "native_report_execution_evidence": receipt.get(
            "native_report_execution_evidence"
        ),
        "from_date": execution.get("from_date"),
        "to_date": execution.get("to_date"),
        "currency": execution.get("currency"),
        "deposit": execution.get("deposit"),
        "observed_trade_stats": receipt.get("observed_trade_stats"),
        "native_metrics": receipt.get("native_metrics"),
        "source_requalification": {
            "summary_path": summary_path,
            "summary_artifact_sha256": summary_sha256,
            "receipt_path": artifact_bindings["receipt_path"],
            "receipt_payload_sha256": receipt.get("receipt_sha256"),
        },
    }
    if target_pair_binding is not None:
        row["qualification"]["target_reproducibility_pair"] = dict(
            target_pair_binding
        )
    if promotion_resolution is not None:
        row["qualification"]["promotion_resolution"] = dict(promotion_resolution)
    return row


def adjudicate(
    manifest: Mapping[str, Any],
    summary: Mapping[str, Any],
    registry: Mapping[str, Any],
    *,
    manifest_sha256: str,
    summary_sha256: str,
    registry_sha256: str,
    manifest_path: str,
    summary_path: str,
    registry_path: str,
    target_repro_pair: Mapping[str, Any] | None = None,
    target_repro_pair_metadata: Mapping[str, Any] | None = None,
    repo_root: Path = REPO_ROOT,
    symbol_matrix_path: Path | None = None,
    as_of: dt.date | None = None,
    generated_utc: str | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return ``(adjudication, candidate_manifest)`` without writing files."""

    as_of = as_of or dt.date.today()
    generated_utc = generated_utc or dt.datetime.now(dt.UTC).isoformat()
    matrix_path = (symbol_matrix_path or DEFAULT_SYMBOL_MATRIX).resolve()
    non_order_routable, matrix_error = execution_contract_lint.load_non_order_routable_symbols(
        matrix_path
    )
    explicit_routes, route_rows_error = execution_contract_lint.load_symbol_routing_rows(
        matrix_path
    )
    sleeves, manifest_by_key, manifest_issues = _manifest_index(manifest)
    contracts, contract_problems = _registry_index(registry, repo_root=repo_root, as_of=as_of)
    manifest_ea_counts: dict[int, int] = {}
    for sleeve in sleeves:
        ea_id = int(sleeve["ea_id"])
        manifest_ea_counts[ea_id] = manifest_ea_counts.get(ea_id, 0) + 1
    global_blockers = list(manifest_issues)
    if matrix_error:
        global_blockers.append("SYMBOL_ROUTABILITY_MATRIX_INVALID")
    routed_contracts = {
        identity: contract["darwinex_zero_routing"]
        for identity, contract in contracts.items()
        if isinstance(contract.get("darwinex_zero_routing"), dict)
    }
    if routed_contracts:
        if route_rows_error:
            global_blockers.append("SYMBOL_ROUTING_MATRIX_STRUCTURED_INVALID")
        for identity, routing in routed_contracts.items():
            identity_label = _identity_label(identity)
            source_ref = Path(str(routing.get("source_registry") or ""))
            source_matrix = source_ref if source_ref.is_absolute() else repo_root / source_ref
            try:
                path_matches = source_matrix.resolve() == matrix_path
            except OSError:
                path_matches = False
            if not path_matches:
                global_blockers.append(
                    f"SYMBOL_ROUTING_MATRIX_PATH_MISMATCH:{identity_label}"
                )
            test_symbol = str(routing.get("test_symbol") or "").upper()
            row = explicit_routes.get(test_symbol)
            route_matches = row is not None and (
                str(row.get("live_order_symbol") or "").upper()
                == str(routing.get("live_order_symbol") or "").upper()
                and str(row.get("live_order_status") or "").upper()
                == execution_contract_lint.MATRIX_ORDER_ROUTABLE_STATUS
                and str(row.get("routing_evidence_ref") or "").replace("\\", "/")
                == str(routing.get("evidence_ref") or "").replace("\\", "/")
            )
            if not route_matches:
                global_blockers.append(
                    f"SYMBOL_ROUTING_MATRIX_CONTRACT_MISMATCH:{identity_label}"
                )
    if None in contract_problems:
        global_blockers.extend(contract_problems[None])
    global_blockers.extend(
        _summary_integrity_issues(
            summary,
            manifest_sha256=manifest_sha256,
            manifest_keys=set(manifest_by_key),
            manifest_count=len(sleeves),
            repo_root=repo_root,
            as_of=as_of,
        )
    )
    observed_qualification_mode = summary.get("qualification_mode")
    target_pair_issues: list[str] = []
    target_pair_binding: dict[str, Any] | None = None
    if observed_qualification_mode == TARGET_BINARY_REQUAL:
        target_pair_issues, target_pair_binding = _target_pair_validation(
            target_repro_pair,
            target_repro_pair_metadata,
            summary=summary,
            summary_path=summary_path,
            summary_sha256=summary_sha256,
            manifest_sha256=manifest_sha256,
            manifest_count=len(sleeves),
            manifest_keys=set(manifest_by_key),
        )
    elif target_repro_pair is not None or target_repro_pair_metadata is not None:
        target_pair_issues = ["TARGET_REPRODUCIBILITY_PAIR_FORBIDDEN_FOR_AS_LIVE"]
    if target_pair_issues:
        global_blockers.extend(
            f"TARGET_PAIR:{reason}" for reason in target_pair_issues
        )
    global_blockers = sorted(set(global_blockers))
    effective_qualification_status = (
        "QUALIFIED"
        if observed_qualification_mode == TARGET_BINARY_REQUAL
        and not target_pair_issues
        else summary.get("qualification_status")
    )

    receipt_rows: list[dict[str, Any]] = []
    receipts = summary.get("receipts")
    if isinstance(receipts, list):
        for raw in receipts:
            if not isinstance(raw, dict) or not isinstance(raw.get("job"), dict):
                continue
            receipt_rows.append(raw)

    decisions: list[dict[str, Any]] = []
    qualified_sleeves: list[dict[str, Any]] = []
    for sleeve in sleeves:
        ea_id = int(sleeve["ea_id"])
        key = _key(ea_id, sleeve["symbol"])
        receipt_candidates = [
            raw
            for raw in receipt_rows
            if raw["job"].get("ea_id") == ea_id
            and str(raw["job"].get("symbol") or "").upper()
            == str(sleeve["symbol"]).upper()
            and (
                sleeve.get("timeframe") is None
                or raw["job"].get("timeframe") == sleeve.get("timeframe")
            )
            and raw["job"].get("variant_id") == sleeve.get("variant_id")
        ]
        receipt_resolution_issues: list[str] = []
        if len(receipt_candidates) == 1:
            receipt = receipt_candidates[0]
        elif len(receipt_candidates) > 1:
            receipt = None
            receipt_resolution_issues.append("RECEIPT_IDENTITY_AMBIGUOUS")
        else:
            receipt = None
        contract, resolved_identity, registry_identity, resolution_issues = _resolve_contract(
            sleeve,
            receipt,
            contracts,
            manifest_ea_counts=manifest_ea_counts,
        )
        reasons: list[str] = list(global_blockers)
        reasons.extend(receipt_resolution_issues)
        reasons.extend(resolution_issues)
        classification = "BLOCK"
        promotion_resolution: dict[str, Any] | None = None

        symbol = str(sleeve["symbol"]).upper()
        if symbol in non_order_routable:
            reasons.append(f"SYMBOL_NON_ORDER_ROUTABLE:{symbol}")

        if contract is not None and registry_identity is not None:
            reasons.extend(contract_problems.get(registry_identity, []))
        if (
            observed_qualification_mode == TARGET_BINARY_REQUAL
            and resolved_identity is not None
            and registry_identity != resolved_identity
        ):
            reasons.append("TARGET_REQUIRES_EXACT_REGISTRY_CONTRACT_IDENTITY")
        if receipt is None:
            reasons.append("RECEIPT_MISSING")
        if (
            not reasons
            and contract is not None
            and receipt is not None
            and resolved_identity is not None
        ):
            receipt_problems = _receipt_issues(
                receipt,
                sleeve,
                contract,
                resolved_identity,
                summary=summary,
                repo_root=repo_root,
            )
            reasons.extend(receipt_problems)
            if not receipt_problems:
                promotion = contract["promotion"]["status"]
                if promotion == "ELIGIBLE":
                    classification = "KEEP"
                    qualified_sleeves.append(
                        _candidate_sleeve(
                            sleeve,
                            contract,
                            receipt,
                            resolved_identity,
                            repo_root=repo_root,
                            summary_path=summary_path,
                            summary_sha256=summary_sha256,
                            classification=classification,
                            effective_qualification_status=str(
                                effective_qualification_status
                            ),
                            target_pair_binding=target_pair_binding,
                        )
                    )
                elif promotion == "REQUAL_REQUIRED":
                    promotion_resolution = _promotion_resolution(
                        contract,
                        receipt,
                        repo_root=repo_root,
                    )
                    if (
                        promotion_resolution["resolved_reasons"]
                        and not promotion_resolution["unresolved_reasons"]
                        and not promotion_resolution["blockers"]
                    ):
                        classification = "KEEP_CANDIDATE"
                        qualified_sleeves.append(
                            _candidate_sleeve(
                                sleeve,
                                contract,
                                receipt,
                                resolved_identity,
                                repo_root=repo_root,
                                summary_path=summary_path,
                                summary_sha256=summary_sha256,
                                classification=classification,
                                effective_qualification_status=str(
                                    effective_qualification_status
                                ),
                                target_pair_binding=target_pair_binding,
                                promotion_resolution=promotion_resolution,
                            )
                        )
                    else:
                        classification = "REPAIR"
                        reasons.extend(
                            f"CONTRACT_REQUAL:{reason}"
                            for reason in promotion_resolution["unresolved_reasons"]
                        )
                        reasons.extend(
                            f"CONTRACT_REQUAL_EVIDENCE:{reason}"
                            for reason in promotion_resolution["blockers"]
                        )
                else:
                    classification = "BLOCK"
                    reasons.extend(
                        f"CONTRACT_BLOCK:{reason}"
                        for reason in contract["promotion"].get("block_reasons", [])
                    )
        elif (
            contract is not None
            and isinstance(contract.get("promotion"), Mapping)
            and contract["promotion"].get("status") == "BLOCKED"
        ):
            reasons.extend(
                f"CONTRACT_BLOCK:{reason}"
                for reason in contract["promotion"].get("block_reasons", [])
            )

        decisions.append(
            {
                "key": key,
                "sleeve_identity": _identity_label(resolved_identity),
                "ea_id": ea_id,
                "symbol": sleeve["symbol"],
                "timeframe": resolved_identity[2] if resolved_identity else None,
                "variant_id": resolved_identity[3] if resolved_identity else None,
                "contract_identity": _identity_label(resolved_identity),
                "registry_contract_identity": _identity_label(registry_identity),
                "contract_status": (
                    str(contract["promotion"].get("status"))
                    if contract is not None
                    and isinstance(contract.get("promotion"), Mapping)
                    and contract["promotion"].get("status") in PROMOTION_STATUSES
                    else "MISSING"
                ),
                "classification": classification,
                "reasons": sorted(set(reasons)),
                "receipt_sha256": receipt.get("receipt_sha256") if receipt else None,
                "contract_sha256": canonical_json_sha(contract) if contract else None,
                "promotion_resolution": promotion_resolution,
            }
        )

    counts = {name: sum(1 for item in decisions if item["classification"] == name) for name in CLASSIFICATIONS}
    if counts["BLOCK"]:
        verdict = "BLOCK"
    elif counts["REPAIR"]:
        verdict = "REPAIR"
    elif counts["KEEP"] + counts["KEEP_CANDIDATE"] == len(sleeves) and sleeves:
        verdict = "PASS"
    else:
        verdict = "BLOCK"

    source_binding = {
        "path": manifest_path,
        "sha256": manifest_sha256,
        "declared_status": manifest.get("status"),
    }
    requalification_binding = {
        "path": summary_path,
        "artifact_sha256": summary_sha256,
        "sha256": summary_sha256,
        "payload_sha256": summary.get("summary_sha256"),
        "run_id": summary.get("run_id"),
        "scope": summary.get("scope"),
        "status": summary.get("status"),
        "qualification_mode": summary.get("qualification_mode"),
        "qualification_status": summary.get("qualification_status"),
        "effective_qualification_status": effective_qualification_status,
        "window_contract": summary.get("window_contract"),
        "cost_certified": summary.get("cost_certified"),
        "cost_evidence": summary.get("cost_evidence"),
        "cost_registry": summary.get("cost_registry"),
        "execution_cost_evidence_manifest": summary.get(
            "execution_cost_evidence_manifest"
        ),
    }
    evidence_binding = {
        "as_live_summary": dict(requalification_binding),
        "execution_contract_registry": {
            "path": registry_path,
            "artifact_sha256": registry_sha256,
            "sha256": registry_sha256,
        },
        "symbol_routability_matrix": {
            "path": str(matrix_path),
            "sha256": sha256_file(matrix_path) if matrix_error is None else None,
            "non_order_routable_symbols": sorted(non_order_routable),
            "explicit_test_to_live_routes": {
                symbol: {
                    "live_order_symbol": row.get("live_order_symbol"),
                    "live_order_status": row.get("live_order_status"),
                    "routing_evidence_ref": row.get("routing_evidence_ref"),
                }
                for symbol, row in sorted(explicit_routes.items())
            },
            "structured_route_error": route_rows_error,
        },
    }
    if target_pair_binding is not None:
        evidence_binding["target_binary_reproducibility_pair"] = dict(
            target_pair_binding
        )
    book_gate_reasons: list[str] = []
    if global_blockers:
        book_gate_reasons.append("SUMMARY_OR_INPUT_INTEGRITY_INVALID")
    if summary.get("scope") != "FULL":
        book_gate_reasons.append("SUMMARY_SCOPE_NOT_FULL")
    if summary.get("status") != "PASS":
        book_gate_reasons.append(f"SUMMARY_STATUS_NOT_PASS:{summary.get('status')}")
    if observed_qualification_mode not in QUALIFYING_MODES:
        book_gate_reasons.append(
            f"SUMMARY_MODE_NOT_QUALIFYING:{summary.get('qualification_mode')}"
        )
    expected_qualification_status = (
        "QUALIFIED"
        if observed_qualification_mode == AS_LIVE_REQUAL
        else TARGET_SINGLE_RUN_STATUS
        if observed_qualification_mode == TARGET_BINARY_REQUAL
        else None
    )
    if summary.get("qualification_status") != expected_qualification_status:
        book_gate_reasons.append(
            f"SUMMARY_QUALIFICATION_NOT_PASS:{summary.get('qualification_status')}"
        )
    if target_pair_issues:
        book_gate_reasons.extend(
            f"TARGET_PAIR:{reason}" for reason in target_pair_issues
        )
    if summary.get("cost_certified") is not True:
        book_gate_reasons.append("SUMMARY_COST_NOT_CERTIFIED")
    book_candidate_eligible = not book_gate_reasons
    candidate_sleeves = qualified_sleeves if book_candidate_eligible else []
    candidate_status = (
        "BOUND_CANDIDATE_COMPLETE"
        if len(candidate_sleeves) == len(sleeves) and sleeves
        else "BOUND_CANDIDATE_PARTIAL"
        if candidate_sleeves
        else "NO_BOOK_CANDIDATE"
        if not book_candidate_eligible
        else "NO_BOUND_SLEEVES"
    )
    candidate = {
        "schema_version": 2,
        "kind": "dxz_bound_candidate_book",
        "book": manifest.get("book", "DXZ"),
        "status": candidate_status,
        "generated_utc": generated_utc,
        "as_of": as_of.isoformat(),
        "source_manifest": source_binding,
        "source_requalification": requalification_binding,
        "evidence": dict(evidence_binding),
        "n_source_sleeves": len(sleeves),
        "n_validated_sleeves": len(qualified_sleeves),
        "n_sleeves": len(candidate_sleeves),
        "total_risk_pct": round(
            sum(float(item.get("risk_percent") or 0.0) for item in candidate_sleeves), 9
        ),
        "kpis": None,
        "portfolio_recompute_required": True,
        "deployment_eligible": False,
        "manual_owner_approval_required": True,
        "autotrading_action": "NONE",
        "deployment_action": "NONE",
        "book_qualification_gate": {
            "eligible": book_candidate_eligible,
            "required_scope": "FULL",
            "required_summary_status": "PASS",
            "observed_scope": summary.get("scope"),
            "observed_summary_status": summary.get("status"),
            "required_qualification_mode": observed_qualification_mode,
            "observed_qualification_mode": summary.get("qualification_mode"),
            "required_qualification_status": "QUALIFIED",
            "observed_qualification_status": effective_qualification_status,
            "cost_certified": summary.get("cost_certified"),
            "reasons": book_gate_reasons,
        },
        "sleeves": candidate_sleeves,
        "validated_sleeves_not_admitted": (
            [
                {
                    "key": item["key"],
                    "classification": item["classification"],
                    "receipt_sha256": item["receipt_sha256"],
                    "book_gate_reasons": book_gate_reasons,
                }
                for item in decisions
                if item["classification"] in {"KEEP", "KEEP_CANDIDATE"}
            ]
            if not book_candidate_eligible
            else []
        ),
        "excluded_sleeves": [
            {
                "key": item["key"],
                "classification": item["classification"],
                "reasons": sorted(
                    set(
                        item["reasons"]
                        + (
                            [f"BOOK_GATE:{reason}" for reason in book_gate_reasons]
                            if item["classification"] in {"KEEP", "KEEP_CANDIDATE"}
                            else []
                        )
                    )
                ),
            }
            for item in decisions
            if (
                item["classification"] not in {"KEEP", "KEEP_CANDIDATE"}
                or not book_candidate_eligible
            )
        ],
    }
    if target_pair_binding is not None:
        candidate["source_target_reproducibility_pair"] = dict(
            target_pair_binding
        )
    classification_rank = {"KEEP": 0, "KEEP_CANDIDATE": 1, "REPAIR": 2, "BLOCK": 3}
    ea_decisions: dict[int, str] = {}
    for item in decisions:
        ea_id = int(item["ea_id"])
        observed = str(item["classification"])
        current = ea_decisions.get(ea_id)
        if current is None or classification_rank[observed] > classification_rank[current]:
            ea_decisions[ea_id] = observed
    distinct_ea_counts = {
        name: sum(1 for value in ea_decisions.values() if value == name)
        for name in CLASSIFICATIONS
    }
    contract_status_rank = {
        "ELIGIBLE": 0,
        "REQUAL_REQUIRED": 1,
        "BLOCKED": 2,
        "MISSING": 3,
    }
    sleeve_contract_statuses: list[str] = [
        str(item["contract_status"]) for item in decisions
    ]
    distinct_contract_statuses: dict[int, str] = {}
    for item in decisions:
        ea_id = int(item["ea_id"])
        status = str(item["contract_status"])
        current = distinct_contract_statuses.get(ea_id)
        if current is None or contract_status_rank[status] > contract_status_rank[current]:
            distinct_contract_statuses[ea_id] = status
    all_contract_statuses = sorted(PROMOTION_STATUSES | {"MISSING"})
    contract_status_counts = {
        "sleeves": {
            status: sleeve_contract_statuses.count(status)
            for status in all_contract_statuses
        },
        "distinct_eas": {
            status: sum(1 for value in distinct_contract_statuses.values() if value == status)
            for status in all_contract_statuses
        },
    }
    adjudication = {
        "schema_version": 2,
        "kind": "dxz_requal_adjudication",
        "generated_utc": generated_utc,
        "as_of": as_of.isoformat(),
        "verdict": verdict,
        "counts": counts,
        "distinct_ea_counts": distinct_ea_counts,
        "source_contract_status_counts": contract_status_counts,
        "n_source_sleeves": len(sleeves),
        "global_blockers": global_blockers,
        "source_manifest": source_binding,
        "evidence": dict(evidence_binding),
        "book_qualification_gate": candidate["book_qualification_gate"],
        "candidate_contract": {
            "required_status": "BOUND_CANDIDATE_COMPLETE",
            "observed_status": candidate_status,
            "source_sleeves": len(sleeves),
            "candidate_sleeves": len(candidate_sleeves),
        },
        "decisions": decisions,
        "policy": {
            "KEEP": (
                "complete PASS receipt plus ELIGIBLE execution contract and "
                "an order-routable DXZ symbol"
            ),
            "KEEP_CANDIDATE": (
                "complete PASS receipt plus fully evidence-resolved machine-only "
                "REQUAL_REQUIRED reasons"
            ),
            "REPAIR": "complete PASS receipt plus unresolved REQUAL_REQUIRED reason",
            "BLOCK": (
                "missing/failing/unbound evidence, BLOCKED/invalid contract, or "
                "a non-order-routable DXZ symbol"
            ),
            "machine_resolvable_reasons": sorted(MACHINE_RESOLVABLE_REASONS),
            "semantic_reasons_auto_resolve": False,
            "candidate_rule": (
                "only a FULL/PASS summary may admit KEEP or KEEP_CANDIDATE sleeves; "
                "candidate is never deployable"
            ),
        },
    }
    adjudication["adjudication_sha256"] = canonical_json_sha(adjudication)
    # The candidate is serialized beside adjudication.json.  Its binding covers
    # the exact bytes written by write_bundle as well as the adjudication's
    # independently verifiable canonical payload digest.  Adjudication does not
    # point back to the candidate, avoiding a circular hash contract.
    candidate["source_adjudication"] = {
        "path": "adjudication.json",
        "artifact_sha256": json_artifact_sha(adjudication),
        "sha256": json_artifact_sha(adjudication),
        "payload_sha256": adjudication["adjudication_sha256"],
        "verdict": adjudication["verdict"],
    }
    candidate["evidence"]["adjudication"] = dict(candidate["source_adjudication"])
    candidate["candidate_manifest_sha256"] = canonical_json_sha(candidate)
    return adjudication, candidate


def validate_output_dir(path: Path, inputs: Iterable[Path]) -> Path:
    resolved = path.resolve()
    if any(TIER_ROOT_RE.fullmatch(part) for part in resolved.parts):
        raise AdjudicationError(f"refusing output below tier/live MT5 root: {resolved}")
    input_paths = {item.resolve() for item in inputs}
    if resolved in input_paths:
        raise AdjudicationError(f"output collides with an input file: {resolved}")
    if resolved.exists():
        raise AdjudicationError(f"immutable output directory already exists: {resolved}")
    return resolved


def write_bundle(
    output_dir: Path,
    *,
    adjudication: Mapping[str, Any],
    candidate: Mapping[str, Any],
    manifest_path: Path,
    summary_path: Path,
    registry_path: Path,
    target_pair_path: Path | None = None,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=False)
    outputs = {
        "adjudication.json": dict(adjudication),
        "candidate_bound_manifest.json": dict(candidate),
        "input_manifest.json": _load_object(manifest_path, "manifest"),
        "input_summary.json": _load_object(summary_path, "summary"),
        "input_execution_contracts.json": _load_object(registry_path, "registry"),
    }
    if target_pair_path is not None:
        outputs["input_target_reproducibility_pair.json"] = _load_object(
            target_pair_path, "TARGET reproducibility pair"
        )
    for name, payload in outputs.items():
        (output_dir / name).write_bytes(json_artifact_bytes(payload))
    checksums = [
        f"{sha256_file(output_dir / name)}  {name}"
        for name in sorted(outputs)
    ]
    (output_dir / "SHA256SUMS").write_text("\n".join(checksums) + "\n", encoding="ascii")


def default_output_dir() -> Path:
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    return DEFAULT_OUTPUT_ROOT / f"dxz23_requal_adjudication_{stamp}"


def parser() -> argparse.ArgumentParser:
    argp = argparse.ArgumentParser(description=__doc__)
    argp.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    argp.add_argument("--summary", type=Path, required=True)
    argp.add_argument("--contracts", type=Path, default=DEFAULT_CONTRACTS)
    argp.add_argument("--symbol-matrix", type=Path, default=DEFAULT_SYMBOL_MATRIX)
    argp.add_argument(
        "--target-reproducibility-pair",
        type=Path,
        help=(
            "immutable PASS output from dxz_target_binary_repro_gate; required "
            "when the summary mode is TARGET_BINARY_REQUAL"
        ),
    )
    argp.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    argp.add_argument("--as-of", default=dt.date.today().isoformat())
    argp.add_argument("--output-dir", type=Path)
    return argp


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    manifest_path = args.manifest.resolve()
    summary_path = args.summary.resolve()
    registry_path = args.contracts.resolve()
    symbol_matrix_path = args.symbol_matrix.resolve()
    repo_root = args.repo_root.resolve()
    manifest = _load_object(manifest_path, "manifest")
    summary = _load_object(summary_path, "summary")
    registry = _load_object(registry_path, "registry")
    target_pair_path = (
        args.target_reproducibility_pair.resolve()
        if args.target_reproducibility_pair is not None
        else None
    )
    target_pair: dict[str, Any] | None = None
    target_pair_metadata: dict[str, Any] | None = None
    if target_pair_path is not None:
        target_pair, target_pair_metadata = _load_target_pair_input(target_pair_path)
    adjudication, candidate = adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=sha256_file(manifest_path),
        summary_sha256=sha256_file(summary_path),
        registry_sha256=sha256_file(registry_path),
        manifest_path=str(manifest_path),
        summary_path=str(summary_path),
        registry_path=str(registry_path),
        target_repro_pair=target_pair,
        target_repro_pair_metadata=target_pair_metadata,
        repo_root=repo_root,
        symbol_matrix_path=symbol_matrix_path,
        as_of=dt.date.fromisoformat(args.as_of),
    )
    output_dir = validate_output_dir(
        args.output_dir or default_output_dir(),
        tuple(
            path
            for path in (
                manifest_path,
                summary_path,
                registry_path,
                target_pair_path,
            )
            if path is not None
        ),
    )
    write_bundle(
        output_dir,
        adjudication=adjudication,
        candidate=candidate,
        manifest_path=manifest_path,
        summary_path=summary_path,
        registry_path=registry_path,
        target_pair_path=target_pair_path,
    )
    print(
        json.dumps(
            {
                "verdict": adjudication["verdict"],
                "counts": adjudication["counts"],
                "candidate_sleeves": candidate["n_sleeves"],
                "output": str(output_dir),
            },
            sort_keys=True,
        )
    )
    return {"PASS": 0, "REPAIR": 1, "BLOCK": 2}[str(adjudication["verdict"])]


if __name__ == "__main__":
    raise SystemExit(main())
