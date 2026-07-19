#!/usr/bin/env python
"""Build an immutable, read-only DXZ source-to-live evidence bundle.

The input is a portfolio manifest with a ``sleeves`` array.  Existing portfolio
manifests are accepted, but a sleeve is only considered CLOSED when immutable
qualification bindings are present in the manifest.  A current file path is a
useful diagnostic snapshot; it is not proof of the binary used historically.

T_Live is strictly read-only.  The tool only creates a new evidence directory
outside every discovered live terminal root and refuses to overwrite bundles.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import uuid
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from . import dxz_as_live_requal as requal_runner
except ImportError:  # pragma: no cover - direct script execution
    import dxz_as_live_requal as requal_runner  # type: ignore

try:
    from . import dxz_target_binary_repro_gate as target_pair_gate
except ImportError:  # pragma: no cover - direct script execution
    import dxz_target_binary_repro_gate as target_pair_gate  # type: ignore


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LIVE_ROOT = Path(r"C:\QM\mt5\T_Live")
DEFAULT_CARDS_ROOT = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
DEFAULT_STREAM_ROOT = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades"
)
DEFAULT_HISTORY_ROOT = Path(r"D:\QM\mt5\T6")
DEFAULT_PLATFORM_INCLUDE_ROOT = Path(r"D:\QM\mt5\T6\MQL5\Include")
DEFAULT_COST_MODELS = (
    REPO_ROOT / "framework" / "registry" / "live_commission.json",
    REPO_ROOT / "framework" / "registry" / "tester_defaults.json",
    Path(r"D:\QM\mt5\T6\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt"),
)

AS_LIVE_REQUAL = requal_runner.AS_LIVE_REQUAL
TARGET_BINARY_REQUAL = requal_runner.TARGET_BINARY_REQUAL
QUALIFYING_MODES = frozenset(requal_runner.QUALIFYING_MODES)
TARGET_SINGLE_RUN_STATUS = requal_runner.TARGET_SINGLE_RUN_STATUS
TARGET_PAIR_EVIDENCE_KEY = "target_binary_reproducibility_pair"
TARGET_PAIR_CONTRACTS = frozenset(
    {"card", "artifact_override", "reference", "cost", "window"}
)

INCLUDE_RE = re.compile(r'^\s*#include\s*[<"](?P<name>[^>"]+)[>"]', re.MULTILINE)
DWX_SYMBOL_RE = re.compile(r"\b[A-Z][A-Z0-9]{1,15}\.DWX\b", re.IGNORECASE)
PRESET_MAGIC_RE = re.compile(r"_magic(?P<magic>\d+)(?:_[^.]+)?\.set$", re.IGNORECASE)
HISTORY_YEAR_RE = re.compile(r"^(?P<year>20\d{2})\.hcs$", re.IGNORECASE)
TICK_MONTH_RE = re.compile(r"^(?P<month>20\d{4})\.tkc$", re.IGNORECASE)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_symbol(value: Any) -> str:
    return str(value or "").strip().upper()


def sleeve_key(
    ea_id: Any,
    symbol: Any,
    timeframe: Any = None,
    variant_id: Any = None,
) -> str:
    pair = f"{int(ea_id)}:{normalize_symbol(symbol)}"
    if timeframe is None and variant_id is None:
        return pair
    timeframe_token = str(timeframe or "*").upper()
    variant_token = str(variant_id or "VARIANT_UNSPECIFIED")
    return f"{pair}:{timeframe_token}:{variant_token}"


def path_is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (ValueError, FileNotFoundError, OSError):
        return False


def assert_output_outside_live(output: Path, live_roots: Iterable[Path]) -> None:
    for root in live_roots:
        if path_is_under(output, root):
            raise ValueError(f"refusing to write evidence inside live terminal tree: {output}")


def discover_terminal_roots(live_root: Path) -> list[Path]:
    candidates: list[Path] = []
    if (live_root / "MQL5").is_dir() or (live_root / "logs").is_dir():
        candidates.append(live_root)
    if live_root.is_dir():
        for child in sorted(live_root.iterdir()):
            if child.is_dir() and ((child / "MQL5").is_dir() or (child / "logs").is_dir()):
                candidates.append(child)
    seen: set[str] = set()
    roots: list[Path] = []
    for candidate in candidates:
        try:
            identity = str(candidate.resolve()).casefold()
        except OSError:
            identity = str(candidate.absolute()).casefold()
        if identity not in seen:
            seen.add(identity)
            roots.append(candidate)
    return roots


class ArtifactHasher:
    """Chunked SHA-256 with per-run path/stat caching."""

    def __init__(self) -> None:
        self._cache: dict[tuple[str, int, int], str] = {}

    def sha256(self, path: Path) -> str:
        stat = path.stat()
        key = (str(path.resolve()).casefold(), stat.st_size, stat.st_mtime_ns)
        cached = self._cache.get(key)
        if cached:
            return cached
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
        value = digest.hexdigest()
        self._cache[key] = value
        return value

    def artifact(self, path: Path | None) -> dict[str, Any]:
        if path is None:
            return {"path": None, "exists": False, "sha256": None}
        result: dict[str, Any] = {"path": str(path), "exists": path.is_file(), "sha256": None}
        if not result["exists"]:
            return result
        stat = path.stat()
        result.update(
            {
                "size_bytes": stat.st_size,
                "modified_at_utc": iso_utc(datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc)),
                "sha256": self.sha256(path),
            }
        )
        return result


def aggregate_digest(rows: Iterable[tuple[str, str, int]]) -> str:
    digest = hashlib.sha256()
    for identity, sha256, size in sorted(rows):
        digest.update(identity.replace("\\", "/").encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256.encode("ascii"))
        digest.update(b"\0")
        digest.update(str(size).encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError(f"manifest must be a JSON object: {path}")
    if not isinstance(payload.get("sleeves"), list):
        raise ValueError(f"manifest must contain a sleeves array: {path}")
    return payload


def canonical_json_sha(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def embedded_hash_valid(payload: dict[str, Any], field: str) -> bool:
    declared = str(payload.get(field) or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", declared):
        return False
    unsigned = dict(payload)
    unsigned.pop(field, None)
    return canonical_json_sha(unsigned) == declared


def _read_bound_json(
    binding: Any,
    *,
    manifest_dir: Path,
    repo_root: Path,
    hasher: ArtifactHasher,
    label: str,
) -> tuple[dict[str, Any] | None, dict[str, Any], list[str]]:
    issues: list[str] = []
    if not isinstance(binding, dict):
        return None, {"path": None, "exists": False, "sha256": None}, [f"missing_{label}_binding"]
    path_text = str(binding.get("path") or "").strip()
    path = Path(path_text) if path_text else None
    if path is not None and not path.is_absolute():
        # Lineage artifacts are relative to the candidate bundle, never to an
        # arbitrary repo file with the same name.
        path = manifest_dir / path
    artifact = hasher.artifact(path)
    declared = str(binding.get("artifact_sha256") or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", declared):
        issues.append(f"unbound_{label}_artifact_sha256")
    if not artifact.get("exists"):
        issues.append(f"missing_{label}_artifact")
        return None, artifact, issues
    if declared and declared != artifact.get("sha256"):
        issues.append(f"{label}_artifact_sha256_mismatch")
    try:
        payload = json.loads(Path(str(artifact["path"])).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        issues.append(f"invalid_{label}_json")
        return None, artifact, issues
    if not isinstance(payload, dict):
        issues.append(f"invalid_{label}_object")
        return None, artifact, issues
    return payload, artifact, issues


def _validate_target_pair_sidecar(
    binding: Any,
    *,
    artifact: Mapping[str, Any],
    manifest_dir: Path,
) -> tuple[dict[str, Any], list[str]]:
    """Re-read the immutable TARGET pair sidecar and verify every binding."""

    result: dict[str, Any] = {
        "sidecar_path": None,
        "sidecar_exists": False,
        "sidecar_sha256": None,
        "sidecar_declared_sha256": None,
    }
    issues: list[str] = []
    if not isinstance(binding, Mapping):
        return result, ["target_pair_sidecar_binding_missing"]

    sidecar_text = str(binding.get("sidecar_path") or "").strip()
    if not sidecar_text:
        return result, ["target_pair_sidecar_path_missing"]
    sidecar_path = Path(sidecar_text)
    if not sidecar_path.is_absolute():
        sidecar_path = manifest_dir / sidecar_path
    result["sidecar_path"] = str(sidecar_path)

    artifact_path_text = str(artifact.get("path") or "").strip()
    artifact_path = Path(artifact_path_text) if artifact_path_text else None
    if artifact_path is not None:
        expected_sidecar = artifact_path.with_name(artifact_path.name + ".sha256")
        try:
            is_adjacent = sidecar_path.resolve() == expected_sidecar.resolve()
        except OSError:
            is_adjacent = sidecar_path.absolute() == expected_sidecar.absolute()
        if not is_adjacent:
            issues.append("target_pair_sidecar_path_not_adjacent")

    bound_sidecar_sha = str(binding.get("sidecar_sha256") or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", bound_sidecar_sha):
        issues.append("target_pair_sidecar_binding_sha256_invalid")
    bound_declared_sha = str(
        binding.get("sidecar_declared_sha256") or ""
    ).strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", bound_declared_sha):
        issues.append("target_pair_sidecar_declared_binding_invalid")

    try:
        raw = sidecar_path.read_bytes()
        text = raw.decode("ascii", errors="strict")
    except (OSError, UnicodeError):
        issues.append("target_pair_sidecar_missing_or_unreadable")
        return result, sorted(set(issues))

    result["sidecar_exists"] = True
    actual_sidecar_sha = hashlib.sha256(raw).hexdigest()
    result["sidecar_sha256"] = actual_sidecar_sha
    if bound_sidecar_sha and bound_sidecar_sha != actual_sidecar_sha:
        issues.append("target_pair_sidecar_sha256_mismatch")

    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) != 1:
        issues.append("target_pair_sidecar_binding_count_invalid")
        return result, sorted(set(issues))
    match = target_pair_gate.SIDECAR_RE.fullmatch(lines[0])
    if match is None:
        issues.append("target_pair_sidecar_binding_invalid")
        return result, sorted(set(issues))

    declared_sha = match.group(1).lower()
    declared_name = match.group(2)
    result["sidecar_declared_sha256"] = declared_sha
    if artifact_path is not None and declared_name:
        if Path(declared_name.strip()).name.casefold() != artifact_path.name.casefold():
            issues.append("target_pair_sidecar_filename_mismatch")

    artifact_sha = str(artifact.get("sha256") or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", artifact_sha) or declared_sha != artifact_sha:
        issues.append("target_pair_sidecar_artifact_sha256_mismatch")
    if bound_declared_sha and bound_declared_sha != declared_sha:
        issues.append("target_pair_sidecar_declared_binding_mismatch")

    return result, sorted(set(issues))


def _validate_target_reproducibility_pair(
    candidate: Mapping[str, Any],
    *,
    manifest_path: Path,
    repo_root: Path,
    hasher: ArtifactHasher,
    summary: Mapping[str, Any] | None,
    summary_artifact: Mapping[str, Any],
    expected_manifest_sha: Any,
) -> tuple[dict[str, Any] | None, dict[str, Any], dict[str, Any] | None, list[str]]:
    """Re-read and verify the immutable TARGET two-run pair bound by a candidate."""

    issues: list[str] = []
    raw_binding = candidate.get("source_target_reproducibility_pair")
    binding = dict(raw_binding) if isinstance(raw_binding, Mapping) else None
    candidate_evidence = candidate.get("evidence")
    evidence_binding = (
        candidate_evidence.get(TARGET_PAIR_EVIDENCE_KEY)
        if isinstance(candidate_evidence, Mapping)
        else None
    )
    if binding is None:
        issues.append("candidate_target_pair_binding_missing")
    if evidence_binding != raw_binding:
        issues.append("candidate_target_pair_evidence_binding_mismatch")

    pair, artifact, read_issues = _read_bound_json(
        raw_binding,
        manifest_dir=manifest_path.parent,
        repo_root=repo_root,
        hasher=hasher,
        label="target_reproducibility_pair",
    )
    issues.extend(read_issues)
    sidecar_artifact, sidecar_issues = _validate_target_pair_sidecar(
        raw_binding,
        artifact=artifact,
        manifest_dir=manifest_path.parent,
    )
    artifact.update(sidecar_artifact)
    issues.extend(sidecar_issues)
    if binding is not None:
        actual_file_sha = artifact.get("sha256")
        if (
            binding.get("artifact_sha256") != actual_file_sha
            or binding.get("sha256") != actual_file_sha
        ):
            issues.append("target_pair_file_binding_mismatch")
        if binding.get("status") != "PASS":
            issues.append("target_pair_binding_status_not_pass")
        if binding.get("qualification_mode") != TARGET_BINARY_REQUAL:
            issues.append("target_pair_binding_mode_mismatch")
        if binding.get("source_manifest_sha256") != expected_manifest_sha:
            issues.append("target_pair_binding_manifest_mismatch")

    if pair is None:
        return None, artifact, binding, sorted(set(issues))

    if pair.get("artifact_type") != target_pair_gate.ARTIFACT_TYPE:
        issues.append("target_pair_artifact_type_invalid")
    if pair.get("schema_version") != target_pair_gate.SCHEMA_VERSION:
        issues.append("target_pair_schema_invalid")
    if pair.get("status") != "PASS":
        issues.append("target_pair_status_not_pass")
    if pair.get("qualification_mode") != TARGET_BINARY_REQUAL:
        issues.append("target_pair_mode_mismatch")
    if pair.get("deployment_eligible") is not False:
        issues.append("target_pair_deployment_contract_invalid")
    if pair.get("issues") != []:
        issues.append("target_pair_issues_not_empty")
    if pair.get("source_manifest_sha256") != expected_manifest_sha:
        issues.append("target_pair_manifest_mismatch")
    if not embedded_hash_valid(pair, "pair_payload_sha256"):
        issues.append("target_pair_payload_sha256_invalid")
    if binding is not None and (
        binding.get("payload_sha256") != pair.get("pair_payload_sha256")
    ):
        issues.append("target_pair_payload_binding_mismatch")
    if binding is not None and any(
        binding.get(field) != pair.get(field)
        for field in ("status", "qualification_mode", "source_manifest_sha256")
    ):
        issues.append("target_pair_state_binding_mismatch")

    runner_gap = pair.get("runner_contract_gap")
    if (
        not isinstance(runner_gap, Mapping)
        or runner_gap.get("status") != "CLOSED"
        or runner_gap.get("missing_required_axes") != []
    ):
        issues.append("target_pair_runner_contract_gap_open")
    run_intervals = pair.get("run_intervals")
    if (
        not isinstance(run_intervals, Mapping)
        or run_intervals.get("serial_non_overlapping") is not True
        or not isinstance(run_intervals.get("summary_a"), Mapping)
        or not isinstance(run_intervals.get("summary_b"), Mapping)
    ):
        issues.append("target_pair_run_intervals_not_serial")

    axes = pair.get("identity_axes")
    required_axes = set(target_pair_gate.REQUIRED_IDENTITY_AXES)
    try:
        expected_sleeves = int(candidate.get("n_source_sleeves"))
    except (TypeError, ValueError):
        expected_sleeves = -1
    if not isinstance(axes, Mapping) or set(axes) != required_axes:
        issues.append("target_pair_identity_axes_incomplete")
    elif any(
        not isinstance(axes.get(axis), Mapping)
        or axes[axis].get("status") != "PASS"
        or axes[axis].get("missing_sleeves") != []
        or axes[axis].get("mismatched_sleeves") != []
        or axes[axis].get("invalid_sleeves") != []
        or (
            expected_sleeves >= 0
            and len(axes[axis].get("matched_sleeves") or []) != expected_sleeves
        )
        for axis in required_axes
    ):
        issues.append("target_pair_identity_axis_not_pass")

    contracts = pair.get("contracts")
    if not isinstance(contracts, Mapping) or set(contracts) != TARGET_PAIR_CONTRACTS:
        issues.append("target_pair_contracts_incomplete")
    elif any(
        not isinstance(row, Mapping)
        or row.get("status") != "PASS"
        or row.get("hash_bound") is not True
        for row in contracts.values()
    ):
        issues.append("target_pair_contract_not_pass")

    compared = pair.get("compared_sleeves")
    if (
        not isinstance(compared, list)
        or not compared
        or (expected_sleeves >= 0 and len(compared) != expected_sleeves)
        or any(
            not isinstance(row, Mapping)
            or row.get("status") != "PASS"
            or not isinstance(row.get("identity_axes"), Mapping)
            or set(row.get("identity_axes") or {}) != required_axes
            or any(
                row["identity_axes"].get(axis) != "PASS" for axis in required_axes
            )
            for row in (compared if isinstance(compared, list) else [])
        )
    ):
        issues.append("target_pair_compared_sleeves_not_pass")

    if summary is None:
        issues.append("target_pair_current_summary_unavailable")
    else:
        current_binding = {
            "file_sha256": summary_artifact.get("sha256"),
            "payload_sha256": summary.get("summary_sha256"),
            "run_id": summary.get("run_id"),
        }
        pair_summaries = [pair.get("summary_a"), pair.get("summary_b")]
        if not any(
            isinstance(row, Mapping)
            and all(row.get(field) == value for field, value in current_binding.items())
            and isinstance(row.get("path"), str)
            and Path(str(row.get("path"))).resolve()
            == Path(str(summary_artifact.get("path"))).resolve()
            for row in pair_summaries
        ):
            issues.append("target_pair_current_summary_not_bound")
        if (
            not all(isinstance(row, Mapping) for row in pair_summaries)
            or pair_summaries[0].get("run_id") == pair_summaries[1].get("run_id")
            or pair_summaries[0].get("file_sha256")
            == pair_summaries[1].get("file_sha256")
        ):
            issues.append("target_pair_runs_not_distinct")

    return pair, artifact, binding, sorted(set(issues))


def _target_pair_adjudication_binding_issues(
    candidate_binding: Mapping[str, Any] | None,
    adjudication: Mapping[str, Any] | None,
) -> list[str]:
    """Require adjudication to carry the exact pair binding admitted by candidate."""

    evidence = adjudication.get("evidence") if isinstance(adjudication, Mapping) else None
    adjudication_binding = (
        evidence.get(TARGET_PAIR_EVIDENCE_KEY) if isinstance(evidence, Mapping) else None
    )
    if candidate_binding is None:
        return ["candidate_target_pair_binding_missing"]
    if adjudication_binding != candidate_binding:
        return ["adjudication_target_pair_binding_mismatch"]
    return []


def candidate_qualification_chain(
    payload: dict[str, Any],
    *,
    manifest_path: Path,
    repo_root: Path,
    hasher: ArtifactHasher,
) -> dict[str, Any]:
    """Verify the FULL/PASS requal -> PASS adjudication -> complete candidate chain."""

    status = str(payload.get("status") or "")
    applicable = (
        payload.get("kind") == "dxz_bound_candidate_book"
        or status.startswith("BOUND_CANDIDATE_")
        or "source_requalification" in payload
        or "source_adjudication" in payload
        or "source_target_reproducibility_pair" in payload
    )
    candidate_artifact = hasher.artifact(manifest_path)
    if not applicable:
        return {
            "applicable": False,
            "status": "NOT_APPLICABLE",
            "issues": [],
            "candidate": {
                **candidate_artifact,
                "status": status or None,
                "payload_sha256": payload.get("candidate_manifest_sha256"),
            },
            "adjudication": None,
            "requalification": None,
            "target_reproducibility_pair": None,
        }

    issues: list[str] = []
    if payload.get("schema_version") != 2:
        issues.append("candidate_schema_invalid")
    if payload.get("kind") != "dxz_bound_candidate_book":
        issues.append("candidate_kind_invalid")
    if status != "BOUND_CANDIDATE_COMPLETE":
        issues.append("candidate_status_not_complete")
    if not embedded_hash_valid(payload, "candidate_manifest_sha256"):
        issues.append("candidate_payload_sha256_invalid")
    gate = payload.get("book_qualification_gate")
    observed_mode: str | None = None
    if not isinstance(gate, dict) or gate.get("eligible") is not True:
        issues.append("candidate_book_gate_not_eligible")
    else:
        if gate.get("observed_scope") != "FULL":
            issues.append("candidate_book_gate_scope_not_full")
        if gate.get("observed_summary_status") != "PASS":
            issues.append("candidate_book_gate_summary_not_pass")
        raw_mode = gate.get("observed_qualification_mode")
        observed_mode = raw_mode if isinstance(raw_mode, str) else None
        if observed_mode not in QUALIFYING_MODES:
            issues.append("candidate_book_gate_mode_not_qualifying")
        required_mode = gate.get("required_qualification_mode")
        required_modes = gate.get("required_qualification_modes")
        if isinstance(required_modes, list):
            if observed_mode not in required_modes:
                issues.append("candidate_book_gate_mode_contract_mismatch")
        elif required_mode != observed_mode:
            issues.append("candidate_book_gate_mode_contract_mismatch")
        if gate.get("observed_qualification_status") != "QUALIFIED":
            issues.append("candidate_book_gate_qualification_not_pass")
        if gate.get("cost_certified") is not True:
            issues.append("candidate_book_gate_cost_not_certified")
    sleeves = payload.get("sleeves")
    if not isinstance(sleeves, list) or not sleeves:
        issues.append("candidate_sleeves_invalid")
        sleeves = []
    try:
        declared = int(payload.get("n_sleeves"))
        source_count = int(payload.get("n_source_sleeves"))
    except (TypeError, ValueError):
        declared = source_count = -1
    if declared != len(sleeves) or source_count != len(sleeves):
        issues.append("candidate_sleeve_count_mismatch")
    for sleeve in sleeves:
        if not isinstance(sleeve, dict):
            issues.append("candidate_sleeve_not_object")
            continue
        qualification = sleeve.get("qualification")
        if not isinstance(qualification, dict) or qualification.get("status") not in {
            "BOUND_PASS",
            "BOUND_PASS_EVIDENCE_PROMOTED",
        }:
            issues.append("candidate_sleeve_qualification_not_bound_pass")
        elif qualification.get("qualification_mode") != observed_mode:
            issues.append("candidate_sleeve_mode_mismatch")
        elif qualification.get("qualification_status") != "QUALIFIED":
            issues.append("candidate_sleeve_qualification_status_not_pass")
        elif (
            observed_mode == TARGET_BINARY_REQUAL
            and qualification.get("single_run_qualification_status")
            != TARGET_SINGLE_RUN_STATUS
        ):
            issues.append("candidate_sleeve_target_single_run_status_invalid")
        elif qualification.get("cost_certified") is not True:
            issues.append("candidate_sleeve_cost_not_certified")
        native_evidence = (
            qualification.get("native_report_execution_evidence")
            if isinstance(qualification, dict)
            else None
        )
        if (
            not isinstance(native_evidence, dict)
            or native_evidence.get("real_ticks_certified") is not True
            or " ".join(str(native_evidence.get("history_quality") or "").split()).casefold()
            != "100% real ticks"
        ):
            issues.append("candidate_sleeve_real_tick_evidence_invalid")
        if not isinstance(sleeve.get("artifact_bindings"), dict):
            issues.append("candidate_sleeve_artifact_bindings_missing")
        try:
            int(sleeve["trades"])
        except (KeyError, TypeError, ValueError):
            issues.append("candidate_sleeve_trades_missing")

    source_manifest = payload.get("source_manifest")
    expected_manifest_sha = (
        source_manifest.get("sha256") if isinstance(source_manifest, dict) else None
    )
    required_source_qualification_status = (
        TARGET_SINGLE_RUN_STATUS
        if observed_mode == TARGET_BINARY_REQUAL
        else "QUALIFIED"
    )

    summary, summary_artifact, summary_issues = _read_bound_json(
        payload.get("source_requalification"),
        manifest_dir=manifest_path.parent,
        repo_root=repo_root,
        hasher=hasher,
        label="requal_summary",
    )
    issues.extend(summary_issues)
    requal_binding = payload.get("source_requalification")
    if isinstance(requal_binding, dict):
        if requal_binding.get("scope") != "FULL":
            issues.append("candidate_requal_binding_scope_not_full")
        if requal_binding.get("status") != "PASS":
            issues.append("candidate_requal_binding_status_not_pass")
        if requal_binding.get("qualification_mode") != observed_mode:
            issues.append("candidate_requal_binding_mode_mismatch")
        if (
            requal_binding.get("qualification_status")
            != required_source_qualification_status
        ):
            issues.append("candidate_requal_binding_qualification_not_pass")
        if (
            observed_mode == TARGET_BINARY_REQUAL
            and requal_binding.get("effective_qualification_status") != "QUALIFIED"
        ):
            issues.append("candidate_requal_binding_effective_status_not_qualified")
        if requal_binding.get("cost_certified") is not True:
            issues.append("candidate_requal_binding_cost_not_certified")
    if summary is not None:
        if summary.get("schema_version") != 2:
            issues.append("requal_summary_schema_invalid")
        runner_start = summary.get("runner_sha256_start", summary.get("runner_sha256"))
        if (
            not re.fullmatch(r"[0-9a-f]{64}", str(runner_start or ""))
            or runner_start != summary.get("runner_sha256_end")
            or summary.get("runner_unchanged") is not True
        ):
            issues.append("requal_summary_runner_binding_invalid")
        if summary.get("scope") != "FULL":
            issues.append("requal_summary_scope_not_full")
        if summary.get("status") != "PASS":
            issues.append("requal_summary_status_not_pass")
        if (
            summary.get("manifest_sha256") != expected_manifest_sha
            or summary.get("manifest_sha256_end") != expected_manifest_sha
            or summary.get("manifest_unchanged") is not True
        ):
            issues.append("requal_summary_manifest_sweep_binding_invalid")
        reference_snapshot = summary.get("reference_snapshot")
        if (
            not isinstance(reference_snapshot, dict)
            or reference_snapshot.get("status") != "PASS"
            or reference_snapshot.get("seal_verified") is not True
            or reference_snapshot.get("errors") != []
            or reference_snapshot.get("source_manifest_sha256")
            != expected_manifest_sha
            or summary.get("reference_snapshot_end") != reference_snapshot
            or summary.get("reference_snapshot_unchanged") is not True
        ):
            issues.append("requal_summary_reference_snapshot_binding_invalid")
        if summary.get("qualification_mode") != observed_mode:
            issues.append("requal_summary_mode_mismatch")
        if observed_mode == AS_LIVE_REQUAL:
            if summary.get("artifact_override_manifest") is not None:
                issues.append("requal_summary_artifact_override_forbidden")
        elif observed_mode == TARGET_BINARY_REQUAL:
            if not isinstance(summary.get("artifact_override_manifest"), dict):
                issues.append("requal_summary_target_artifact_override_missing")
            if summary.get("artifact_override_manifest_unchanged") is not True:
                issues.append("requal_summary_target_artifact_override_changed")
            if summary.get("sandbox_derivations_unchanged") is not True:
                issues.append("requal_summary_target_sandbox_derivation_changed")
            if summary.get("live_source_unchanged") is not True:
                issues.append("requal_summary_target_live_source_changed")
        if summary.get("qualification_status") != required_source_qualification_status:
            issues.append("requal_summary_qualification_not_pass")
        cost = summary.get("cost_evidence")
        if (
            summary.get("cost_certified") is not True
            or not isinstance(cost, dict)
            or cost.get("status") != "CERTIFIED"
            or cost.get("cost_certified") is not True
            or cost.get("reasons") != []
            or cost.get("unknown_symbols") != []
            or cost.get("degraded_symbols") != []
            or cost.get("required_axes") != list(requal_runner.EXECUTION_COST_AXES)
            or not isinstance(cost.get("axes"), dict)
            or set(cost.get("axes") or {}) != set(requal_runner.EXECUTION_COST_AXES)
            or any(
                (cost.get("axes") or {}).get(axis, {}).get("status") != "PASS"
                for axis in requal_runner.EXECUTION_COST_AXES
            )
        ):
            issues.append("requal_summary_cost_not_certified")
        registry_binding = summary.get("cost_registry")
        if (
            not isinstance(registry_binding, dict)
            or registry_binding.get("unchanged") is not True
            or not re.fullmatch(
                r"[0-9a-f]{64}", str(registry_binding.get("sha256_start") or "")
            )
            or registry_binding.get("sha256_start")
            != registry_binding.get("sha256_end")
            or not isinstance(cost, dict)
            or registry_binding.get("path") not in cost.get("registry_paths", [])
            or registry_binding.get("sha256_start")
            not in cost.get("registry_sha256s", [])
        ):
            issues.append("requal_summary_cost_registry_binding_invalid")
        cost_manifest_binding = summary.get("execution_cost_evidence_manifest")
        cost_manifest_path: Path | None = None
        if isinstance(cost_manifest_binding, dict):
            raw_cost_path = str(cost_manifest_binding.get("path") or "").strip()
            if raw_cost_path:
                cost_manifest_path = Path(raw_cost_path)
                if not cost_manifest_path.is_absolute():
                    summary_path_text = str(summary_artifact.get("path") or "")
                    cost_manifest_path = Path(summary_path_text).parent / cost_manifest_path
        required_cost_sleeves = [
            {
                "ea_id": receipt["job"].get("ea_id"),
                "symbol": receipt["job"].get("symbol"),
                "timeframe": receipt["job"].get("timeframe"),
                **(
                    {"variant_id": receipt["job"].get("variant_id")}
                    if "variant_id" in receipt["job"]
                    else {}
                ),
            }
            for receipt in (summary.get("receipts") or [])
            if isinstance(receipt, dict) and isinstance(receipt.get("job"), dict)
        ]
        if cost_manifest_path is None or expected_manifest_sha is None:
            issues.append("requal_summary_cost_manifest_missing")
        else:
            try:
                verified_cost, _contracts = (
                    requal_runner.load_execution_cost_evidence_manifest(
                        cost_manifest_path,
                        source_manifest_sha256=expected_manifest_sha,
                        as_of_utc=utc_now(),
                        required_sleeves=required_cost_sleeves,
                        window_contract=(
                            summary.get("window_contract")
                            if isinstance(summary.get("window_contract"), dict)
                            else {}
                        ),
                    )
                )
            except (requal_runner.RequalError, OSError, ValueError):
                issues.append("requal_summary_cost_manifest_semantic_invalid")
            else:
                verified_cost["axis_hashes_start"] = (
                    requal_runner.execution_cost_axis_hash_snapshot(verified_cost)
                )
                semantic_fields = (
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
                )
                if not isinstance(cost_manifest_binding, dict) or any(
                    cost_manifest_binding.get(field) != verified_cost.get(field)
                    for field in semantic_fields
                ):
                    issues.append("requal_summary_cost_manifest_binding_mismatch")
                current_axis_hashes = (
                    requal_runner.execution_cost_axis_hash_snapshot(verified_cost)
                )
                if (
                    cost_manifest_binding.get("sha256_end")
                    != cost_manifest_binding.get("sha256")
                    or cost_manifest_binding.get("unchanged") is not True
                    or cost_manifest_binding.get("end_errors") != []
                    or cost_manifest_binding.get("axis_hashes_end")
                    != cost_manifest_binding.get("axis_hashes_start")
                    or cost_manifest_binding.get("axis_hashes_end") != current_axis_hashes
                    or set(cost_manifest_binding.get("axis_hashes_end") or {})
                    != set(requal_runner.EXECUTION_COST_AXES)
                    or any(
                        not cost_manifest_binding["axis_hashes_end"].get(axis)
                        for axis in requal_runner.EXECUTION_COST_AXES
                    )
                ):
                    issues.append("requal_summary_cost_axis_sweep_binding_invalid")
                for receipt in summary.get("receipts") or []:
                    if not isinstance(receipt, dict) or not isinstance(receipt.get("job"), dict):
                        issues.append("requal_receipt_cost_binding_invalid")
                        continue
                    receipt_cost = receipt.get("cost_evidence")
                    identity = {
                        "ea_id": receipt["job"].get("ea_id"),
                        "symbol": str(receipt["job"].get("symbol") or "").upper(),
                        "timeframe": str(receipt["job"].get("timeframe") or "").upper(),
                        **(
                            {"variant_id": receipt["job"].get("variant_id")}
                            if "variant_id" in receipt["job"]
                            else {}
                        ),
                    }
                    if (
                        receipt.get("cost_certified") is not True
                        or not isinstance(receipt_cost, dict)
                        or receipt_cost.get("status") != "CERTIFIED"
                        or receipt_cost.get("cost_certified") is not True
                        or receipt_cost.get("reasons") != []
                        or receipt_cost.get("required_axes")
                        != list(requal_runner.EXECUTION_COST_AXES)
                        or not isinstance(receipt_cost.get("axes"), dict)
                        or set(receipt_cost.get("axes") or {})
                        != set(requal_runner.EXECUTION_COST_AXES)
                    ):
                        issues.append("requal_receipt_cost_binding_invalid")
                        continue
                    for axis in requal_runner.EXECUTION_COST_AXES:
                        axis_row = receipt_cost["axes"].get(axis)
                        matches = [
                            row
                            for row in verified_cost["axes"][axis]
                            if identity in (row.get("covered_sleeves") or [])
                        ]
                        if not isinstance(axis_row, dict) or len(matches) != 1:
                            issues.append(f"requal_receipt_cost_axis_invalid:{axis}")
                            continue
                        evidence = axis_row.get("evidence")
                        evidence_fields = (
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
                            axis_row.get("status") != "PASS"
                            or axis_row.get("source")
                            != "IMMUTABLE_EXTERNAL_EXECUTION_COST_EVIDENCE"
                            or axis_row.get("reasons") != []
                            or not isinstance(evidence, dict)
                            or any(
                                evidence.get(field) != matches[0].get(field)
                                for field in evidence_fields
                            )
                            or canonical_json_sha(axis_row.get("parameters"))
                            != matches[0].get("parameters_sha256")
                            or canonical_json_sha(axis_row.get("scenarios"))
                            != matches[0].get("scenarios_sha256")
                            or canonical_json_sha(axis_row.get("results"))
                            != matches[0].get("results_sha256")
                        ):
                            issues.append(f"requal_receipt_cost_axis_invalid:{axis}")
        if not embedded_hash_valid(summary, "summary_sha256"):
            issues.append("requal_summary_payload_sha256_invalid")
        if isinstance(requal_binding, dict) and (
            requal_binding.get("payload_sha256") != summary.get("summary_sha256")
        ):
            issues.append("requal_summary_payload_binding_mismatch")
        if isinstance(requal_binding, dict) and (
            requal_binding.get("run_id") != summary.get("run_id")
            or requal_binding.get("scope") != summary.get("scope")
            or requal_binding.get("status") != summary.get("status")
        ):
            issues.append("requal_summary_state_binding_mismatch")
        if isinstance(requal_binding, dict) and (
            requal_binding.get("qualification_mode") != summary.get("qualification_mode")
            or requal_binding.get("qualification_status")
            != summary.get("qualification_status")
            or requal_binding.get("window_contract") != summary.get("window_contract")
            or requal_binding.get("cost_certified") != summary.get("cost_certified")
            or requal_binding.get("cost_registry") != summary.get("cost_registry")
        ):
            issues.append("requal_summary_qualification_binding_mismatch")
        expected_counts = {"PASS": len(sleeves)}
        if summary.get("counts") != expected_counts:
            issues.append("requal_summary_counts_not_all_pass")
        if summary.get("n_jobs") != len(sleeves) or summary.get("manifest_jobs") != len(sleeves):
            issues.append("requal_summary_job_count_mismatch")

    target_pair: dict[str, Any] | None = None
    target_pair_artifact: dict[str, Any] = {
        "path": None,
        "exists": False,
        "sha256": None,
    }
    target_pair_binding: dict[str, Any] | None = None
    if observed_mode == TARGET_BINARY_REQUAL:
        (
            target_pair,
            target_pair_artifact,
            target_pair_binding,
            target_pair_issues,
        ) = _validate_target_reproducibility_pair(
            payload,
            manifest_path=manifest_path,
            repo_root=repo_root,
            hasher=hasher,
            summary=summary,
            summary_artifact=summary_artifact,
            expected_manifest_sha=expected_manifest_sha,
        )
        issues.extend(target_pair_issues)

    adjudication, adjudication_artifact, adjudication_issues = _read_bound_json(
        payload.get("source_adjudication"),
        manifest_dir=manifest_path.parent,
        repo_root=repo_root,
        hasher=hasher,
        label="adjudication",
    )
    issues.extend(adjudication_issues)
    adjudication_binding = payload.get("source_adjudication")
    if isinstance(adjudication_binding, dict) and adjudication_binding.get("verdict") != "PASS":
        issues.append("candidate_adjudication_binding_not_pass")
    if adjudication is not None:
        if adjudication.get("verdict") != "PASS":
            issues.append("adjudication_verdict_not_pass")
        if not embedded_hash_valid(adjudication, "adjudication_sha256"):
            issues.append("adjudication_payload_sha256_invalid")
        if isinstance(adjudication_binding, dict) and (
            adjudication_binding.get("payload_sha256") != adjudication.get("adjudication_sha256")
        ):
            issues.append("adjudication_payload_binding_mismatch")
        adjudication_gate = adjudication.get("book_qualification_gate")
        if not isinstance(adjudication_gate, dict) or adjudication_gate.get("eligible") is not True:
            issues.append("adjudication_book_gate_not_eligible")
        contract = adjudication.get("candidate_contract")
        if not isinstance(contract, dict) or contract.get("observed_status") != "BOUND_CANDIDATE_COMPLETE":
            issues.append("adjudication_candidate_contract_not_complete")
        evidence = adjudication.get("evidence")
        bound_summary = evidence.get("as_live_summary") if isinstance(evidence, dict) else None
        if not isinstance(bound_summary, dict):
            issues.append("adjudication_requal_binding_missing")
        elif (
            bound_summary.get("artifact_sha256") != summary_artifact.get("sha256")
            or (summary is not None and bound_summary.get("payload_sha256") != summary.get("summary_sha256"))
        ):
            issues.append("adjudication_requal_binding_mismatch")
    if observed_mode == TARGET_BINARY_REQUAL:
        issues.extend(
            _target_pair_adjudication_binding_issues(
                target_pair_binding,
                adjudication,
            )
        )

    return {
        "applicable": True,
        "status": "PASS" if not issues else "FAIL",
        "issues": sorted(set(issues)),
        "required": {
            "candidate_status": "BOUND_CANDIDATE_COMPLETE",
            "requal_scope": "FULL",
            "requal_status": "PASS",
            "adjudication_verdict": "PASS",
            "qualification_mode": observed_mode,
            "qualification_status": "QUALIFIED",
            "cost_certified": True,
        },
        "candidate": {
            **candidate_artifact,
            "status": status,
            "payload_sha256": payload.get("candidate_manifest_sha256"),
        },
        "adjudication": {
            **adjudication_artifact,
            "verdict": adjudication.get("verdict") if adjudication else None,
            "payload_sha256": adjudication.get("adjudication_sha256") if adjudication else None,
        },
        "requalification": {
            **summary_artifact,
            "scope": summary.get("scope") if summary else None,
            "status": summary.get("status") if summary else None,
            "payload_sha256": summary.get("summary_sha256") if summary else None,
        },
        "target_reproducibility_pair": (
            {
                **target_pair_artifact,
                "status": target_pair.get("status") if target_pair else None,
                "payload_sha256": (
                    target_pair.get("pair_payload_sha256") if target_pair else None
                ),
            }
            if observed_mode == TARGET_BINARY_REQUAL
            else None
        ),
    }


def resolve_manifest_path(value: Any, manifest_dir: Path, repo_root: Path = REPO_ROOT) -> Path | None:
    text = str(value or "").strip()
    if not text:
        return None
    path = Path(text)
    if path.is_absolute():
        return path
    repo_candidate = repo_root / path
    manifest_candidate = manifest_dir / path
    if repo_candidate.exists() or text.replace("\\", "/").startswith(("framework/", "tools/", "docs/")):
        return repo_candidate
    return manifest_candidate


def nested_value(row: dict[str, Any], *keys: str) -> Any:
    qualification = row.get("qualification") if isinstance(row.get("qualification"), dict) else {}
    bindings = row.get("artifact_bindings") if isinstance(row.get("artifact_bindings"), dict) else {}
    for key in keys:
        if row.get(key) not in (None, ""):
            return row[key]
        if qualification.get(key) not in (None, ""):
            return qualification[key]
        if bindings.get(key) not in (None, ""):
            return bindings[key]
    return None


def declared_hash(row: dict[str, Any], artifact_name: str) -> str | None:
    value = nested_value(
        row,
        f"qualified_{artifact_name}_sha256",
        f"{artifact_name}_sha256",
    )
    if value is None:
        return None
    text = str(value).strip().lower()
    return text if re.fullmatch(r"[0-9a-f]{64}", text) else None


def compare_hash(expected: str | None, actual: str | None) -> dict[str, Any]:
    if not expected:
        return {"status": "UNBOUND", "expected_sha256": None, "actual_sha256": actual}
    if not actual:
        return {"status": "MISSING", "expected_sha256": expected, "actual_sha256": None}
    return {
        "status": "MATCH" if expected.casefold() == actual.casefold() else "MISMATCH",
        "expected_sha256": expected,
        "actual_sha256": actual,
    }


def find_ea_dir(repo_root: Path, ea_id: int, label: str | None) -> Path | None:
    eas_root = repo_root / "framework" / "EAs"
    if label:
        exact = eas_root / label
        if exact.is_dir():
            return exact
    matches = sorted(path for path in eas_root.glob(f"QM5_{ea_id}_*") if path.is_dir())
    return matches[0] if len(matches) == 1 else None


def discover_card(ea_dir: Path | None, label: str, cards_roots: list[Path]) -> Path | None:
    for root in cards_roots:
        exact = root / f"{label}.md"
        if exact.is_file():
            return exact
    if ea_dir:
        local = ea_dir / "docs" / "strategy_card.md"
        if local.is_file():
            return local
    return None


def discover_set(ea_dir: Path | None, label: str, symbol: str) -> Path | None:
    if not ea_dir:
        return None
    candidates = sorted((ea_dir / "sets").glob(f"*{symbol}*backtest.set"))
    if not candidates:
        candidates = sorted((ea_dir / "sets").glob("*backtest.set"))
    if len(candidates) == 1:
        return candidates[0]
    exact_prefix = [path for path in candidates if path.name.startswith(label) and "stress" not in path.name.lower()]
    return exact_prefix[0] if len(exact_prefix) == 1 else None


def _include_identity(path: Path, roots: list[Path]) -> str:
    for root in roots:
        try:
            return f"{root.name}/{path.resolve().relative_to(root.resolve())}".replace("\\", "/")
        except (ValueError, OSError):
            continue
    return str(path.resolve()).replace("\\", "/")


def resolve_include_tree(source: Path | None, include_roots: list[Path], hasher: ArtifactHasher) -> dict[str, Any]:
    if source is None or not source.is_file():
        return {"aggregate_sha256": None, "file_count": 0, "files": [], "unresolved": []}
    roots = [root for root in include_roots if root.is_dir()]
    visited: set[str] = set()
    records: list[dict[str, Any]] = []
    unresolved: set[str] = set()

    def resolve(token: str, current: Path) -> Path | None:
        normalized = token.replace("\\", os.sep).replace("/", os.sep)
        candidates = [current.parent / normalized, *(root / normalized for root in roots)]
        for candidate in candidates:
            if candidate.is_file():
                return candidate
        return None

    def walk(current: Path) -> None:
        identity = str(current.resolve()).casefold()
        if identity in visited:
            return
        visited.add(identity)
        try:
            text = current.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError:
            text = current.read_text(encoding="cp1252", errors="replace")
        for match in INCLUDE_RE.finditer(text):
            token = match.group("name").strip()
            target = resolve(token, current)
            if target is None:
                unresolved.add(token)
                continue
            target_artifact = hasher.artifact(target)
            target_artifact["identity"] = _include_identity(target, roots)
            if str(target.resolve()).casefold() not in visited:
                records.append(target_artifact)
            walk(target)

    walk(source)
    unique = {str(Path(row["path"]).resolve()).casefold(): row for row in records}
    files = sorted(unique.values(), key=lambda row: str(row["identity"]))
    digest_rows = [
        (str(row["identity"]), str(row["sha256"]), int(row["size_bytes"]))
        for row in files
        if row.get("sha256")
    ]
    return {
        "aggregate_sha256": aggregate_digest(digest_rows) if digest_rows else None,
        "file_count": len(files),
        "files": files,
        "unresolved": sorted(unresolved),
    }


def discover_live_ex5(label: str, terminal_roots: list[Path]) -> Path | None:
    for root in terminal_roots:
        for relative in (
            Path("MQL5") / "Experts" / "Live EAs" / f"{label}.ex5",
            Path("MQL5") / "Experts" / "QM" / f"{label}.ex5",
        ):
            candidate = root / relative
            if candidate.is_file():
                return candidate
    return None


def discover_live_preset(
    magic: int | None,
    terminal_roots: list[Path],
    preset_tag: str | None = None,
) -> tuple[Path | None, list[str]]:
    if magic is None:
        return None, []
    matches: list[Path] = []
    for root in terminal_roots:
        preset_root = root / "MQL5" / "Presets"
        if not preset_root.is_dir():
            continue
        for path in preset_root.glob("slot*.set"):
            found = PRESET_MAGIC_RE.search(path.name)
            if found and int(found.group("magic")) == magic:
                matches.append(path)
    unique = sorted({str(path.resolve()).casefold(): path for path in matches}.values())
    selectable = unique
    if preset_tag:
        selectable = [path for path in unique if preset_tag.casefold() in path.name.casefold()]
    return (selectable[0] if len(selectable) == 1 else None), [str(path) for path in unique]


def parse_set_values(path: Path | None) -> dict[str, str]:
    if path is None or not path.is_file():
        return {}
    try:
        text = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        text = path.read_text(encoding="cp1252", errors="replace")
    values: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def compare_set_value(expected: Any, actual: Any) -> bool:
    if actual is None:
        return False
    try:
        return Decimal(str(expected).strip()) == Decimal(str(actual).strip())
    except (InvalidOperation, ValueError):
        return str(expected).strip().casefold() == str(actual).strip().casefold()


def stream_stats(path: Path | None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "valid_json_records": 0,
        "invalid_json_records": 0,
        "trade_count": 0,
        "event_counts": {},
        "symbols": [],
        "entry_from_utc": None,
        "exit_to_utc": None,
        "net_sum": 0.0,
    }
    if path is None or not path.is_file():
        return result
    events: Counter[str] = Counter()
    symbols: set[str] = set()
    entries: list[int] = []
    exits: list[int] = []
    net_sum = 0.0
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError:
                result["invalid_json_records"] += 1
                continue
            if not isinstance(row, dict):
                result["invalid_json_records"] += 1
                continue
            result["valid_json_records"] += 1
            event = str(row.get("event") or "")
            events[event] += 1
            if event == "TRADE_CLOSED" or not event:
                result["trade_count"] += 1
            if row.get("symbol"):
                symbols.add(normalize_symbol(row["symbol"]))
            for field, target in (("entry_time", entries), ("time", exits)):
                try:
                    target.append(int(row[field]))
                except (KeyError, TypeError, ValueError):
                    pass
            try:
                net_sum += float(row.get("net") or 0.0)
            except (TypeError, ValueError):
                pass
    result["event_counts"] = dict(sorted(events.items()))
    result["symbols"] = sorted(symbols)
    result["net_sum"] = round(net_sum, 8)
    if entries:
        result["entry_from_utc"] = iso_utc(datetime.fromtimestamp(min(entries), tz=timezone.utc))
    if exits:
        result["exit_to_utc"] = iso_utc(datetime.fromtimestamp(max(exits), tz=timezone.utc))
    return result


def _history_candidates(root: Path, category: str, symbol: str) -> list[Path]:
    return [
        root / "Tester" / "bases" / "Darwinex-Live" / category / symbol,
        root / "bases" / "Darwinex-Live" / category / symbol,
        root / "Darwinex-Live" / category / symbol,
        root / category / symbol,
    ]


def history_fingerprint(
    symbol: str,
    history_roots: list[Path],
    hasher: ArtifactHasher,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "symbol": symbol,
        "valid_dwx_symbol": symbol.endswith(".DWX"),
        "root": None,
        "aggregate_sha256": None,
        "file_count": 0,
        "total_bytes": 0,
        "bar_year_from": None,
        "bar_year_to": None,
        "tick_month_from": None,
        "tick_month_to": None,
        "files": [],
        "requested_root_count": len(history_roots),
        "location_count": 0,
        "missing_roots": [],
        "consistent_across_roots": None,
        "locations": [],
    }
    if not result["valid_dwx_symbol"]:
        return result
    locations: list[dict[str, Any]] = []
    missing_roots: list[str] = []
    for root in history_roots:
        history_dir = next((p for p in _history_candidates(root, "history", symbol) if p.is_dir()), None)
        ticks_dir = next((p for p in _history_candidates(root, "ticks", symbol) if p.is_dir()), None)
        if not history_dir and not ticks_dir:
            missing_roots.append(str(root))
            continue
        files: list[tuple[str, Path]] = []
        if history_dir:
            files.extend((f"history/{path.name}", path) for path in history_dir.glob("*.hcs") if path.is_file())
        if ticks_dir:
            files.extend((f"ticks/{path.name}", path) for path in ticks_dir.glob("*.tkc") if path.is_file())
        records: list[dict[str, Any]] = []
        years: list[str] = []
        months: list[str] = []
        for identity, path in sorted(files):
            artifact = hasher.artifact(path)
            artifact["identity"] = identity
            records.append(artifact)
            if match := HISTORY_YEAR_RE.match(path.name):
                years.append(match.group("year"))
            if match := TICK_MONTH_RE.match(path.name):
                months.append(match.group("month"))
        digest_rows = [
            (str(row["identity"]), str(row["sha256"]), int(row["size_bytes"]))
            for row in records
            if row.get("sha256")
        ]
        locations.append(
            {
                "root": str(root),
                "aggregate_sha256": aggregate_digest(digest_rows) if digest_rows else None,
                "file_count": len(records),
                "total_bytes": sum(int(row.get("size_bytes") or 0) for row in records),
                "bar_year_from": min(years) if years else None,
                "bar_year_to": max(years) if years else None,
                "tick_month_from": min(months) if months else None,
                "tick_month_to": max(months) if months else None,
                "files": records,
            }
        )
    if not locations:
        result["missing_roots"] = missing_roots
        return result
    primary = locations[0]
    nonempty_digests = [str(row["aggregate_sha256"]) for row in locations if row.get("aggregate_sha256")]
    result.update(primary)
    result.update(
        {
            "requested_root_count": len(history_roots),
            "location_count": len(locations),
            "missing_roots": missing_roots,
            "consistent_across_roots": (
                len(locations) == len(history_roots)
                and bool(nonempty_digests)
                and len(set(nonempty_digests)) == 1
            ),
            "locations": locations,
        }
    )
    return result


def _extract_history_symbols(main_symbol: str, paths: Iterable[Path | None], declared: Any) -> list[str]:
    symbols = {normalize_symbol(main_symbol)}
    if isinstance(declared, list):
        symbols.update(normalize_symbol(value) for value in declared)
    for path in paths:
        if path is None or not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError:
            text = path.read_text(encoding="cp1252", errors="replace")
        symbols.update(match.group(0).upper() for match in DWX_SYMBOL_RE.finditer(text))
    return sorted(symbol for symbol in symbols if symbol)


def _manifest_expected_count(payload: dict[str, Any]) -> int:
    try:
        return int(payload.get("n_sleeves"))
    except (TypeError, ValueError):
        return len(payload.get("sleeves") or [])


def build_evidence(
    manifest_path: Path,
    *,
    repo_root: Path = REPO_ROOT,
    live_root: Path = DEFAULT_LIVE_ROOT,
    cards_roots: list[Path] | None = None,
    stream_root: Path = DEFAULT_STREAM_ROOT,
    history_roots: list[Path] | None = None,
    include_roots: list[Path] | None = None,
    cost_models: list[Path] | None = None,
    sandbox_roots: list[Path] | None = None,
    live_preset_tag: str | None = None,
    generated_at: datetime | None = None,
) -> dict[str, Any]:
    payload = load_json(manifest_path)
    generated_at = generated_at or utc_now()
    cards_roots = cards_roots or [DEFAULT_CARDS_ROOT]
    history_roots = history_roots or [DEFAULT_HISTORY_ROOT]
    include_roots = include_roots or [repo_root / "framework" / "Include", DEFAULT_PLATFORM_INCLUDE_ROOT]
    cost_models = cost_models or list(DEFAULT_COST_MODELS)
    sandbox_roots = sandbox_roots or []
    terminal_roots = discover_terminal_roots(live_root)
    hasher = ArtifactHasher()
    manifest_artifact = hasher.artifact(manifest_path)
    qualification_chain = candidate_qualification_chain(
        payload,
        manifest_path=manifest_path,
        repo_root=repo_root,
        hasher=hasher,
    )

    cost_records = [hasher.artifact(path) for path in cost_models]
    cost_digest_rows = [
        (str(row["path"]), str(row["sha256"]), int(row["size_bytes"]))
        for row in cost_records
        if row.get("sha256")
    ]
    cost_bundle = {
        "aggregate_sha256": aggregate_digest(cost_digest_rows) if cost_digest_rows else None,
        "files": cost_records,
        "missing_count": sum(1 for row in cost_records if not row.get("exists")),
    }

    history_cache: dict[str, dict[str, Any]] = {}
    rows: list[dict[str, Any]] = []
    keys_seen: set[str] = set()
    duplicate_keys: set[str] = set()
    manifest_dir = manifest_path.parent

    for sleeve in payload["sleeves"]:
        if not isinstance(sleeve, dict):
            rows.append({"status": "FAIL", "issues": ["sleeve_not_object"], "raw": sleeve})
            continue
        issues: list[str] = []
        unbound: list[str] = []
        try:
            ea_id = int(sleeve.get("ea_id"))
        except (TypeError, ValueError):
            rows.append({"status": "FAIL", "issues": ["invalid_ea_id"], "raw": sleeve})
            continue
        symbol = normalize_symbol(sleeve.get("symbol"))
        key = sleeve_key(
            ea_id,
            symbol,
            sleeve.get("timeframe"),
            sleeve.get("variant_id"),
        )
        if key in keys_seen:
            duplicate_keys.add(key)
        keys_seen.add(key)
        if not symbol.endswith(".DWX"):
            issues.append("symbol_not_literal_dwx")

        label_value = str(sleeve.get("ea_label") or "").strip()
        ea_dir = find_ea_dir(repo_root, ea_id, label_value or None)
        label = label_value or (ea_dir.name if ea_dir else f"QM5_{ea_id}")

        mq5_path = resolve_manifest_path(nested_value(sleeve, "mq5_path"), manifest_dir, repo_root)
        if mq5_path is None and ea_dir:
            mq5_path = ea_dir / f"{label}.mq5"
        qualified_ex5_path = resolve_manifest_path(
            nested_value(sleeve, "qualified_ex5_path", "ex5_path"), manifest_dir, repo_root
        )
        if qualified_ex5_path is None and ea_dir:
            qualified_ex5_path = ea_dir / f"{label}.ex5"
        card_path = resolve_manifest_path(nested_value(sleeve, "strategy_card", "card_path"), manifest_dir, repo_root)
        if card_path is None:
            card_path = discover_card(ea_dir, label, cards_roots)
        set_path = resolve_manifest_path(
            nested_value(sleeve, "qualified_set_path", "backtest_set", "set_path"), manifest_dir, repo_root
        )
        if set_path is None:
            set_path = discover_set(ea_dir, label, symbol)
        stream_path = resolve_manifest_path(
            nested_value(sleeve, "qualified_stream_path", "q08_stream", "stream_path"), manifest_dir, repo_root
        )
        if stream_path is None:
            stream_path = stream_root / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"

        explicit_live_ex5 = resolve_manifest_path(nested_value(sleeve, "live_ex5_path"), manifest_dir, repo_root)
        live_ex5_path = explicit_live_ex5 or discover_live_ex5(label, terminal_roots)
        explicit_live_preset = resolve_manifest_path(nested_value(sleeve, "live_preset_path"), manifest_dir, repo_root)
        try:
            magic = int(sleeve["magic_number"]) if sleeve.get("magic_number") is not None else None
        except (TypeError, ValueError):
            magic = None
            issues.append("invalid_magic_number")
        discovered_preset, preset_matches = discover_live_preset(magic, terminal_roots, live_preset_tag)
        live_preset_path = explicit_live_preset or discovered_preset
        selected_candidates = [path for path in preset_matches if not live_preset_tag or live_preset_tag.casefold() in Path(path).name.casefold()]
        if not explicit_live_preset and len(selected_candidates) > 1:
            issues.append("ambiguous_live_preset")

        artifacts = {
            "strategy_card": hasher.artifact(card_path),
            "mq5": hasher.artifact(mq5_path),
            "qualified_ex5_path_snapshot": hasher.artifact(qualified_ex5_path),
            "qualified_set_path_snapshot": hasher.artifact(set_path),
            "qualified_q08_stream_path_snapshot": hasher.artifact(stream_path),
            "live_ex5": hasher.artifact(live_ex5_path),
            "live_preset": hasher.artifact(live_preset_path),
        }
        for name in ("strategy_card", "mq5", "qualified_ex5_path_snapshot", "qualified_set_path_snapshot", "qualified_q08_stream_path_snapshot", "live_ex5", "live_preset"):
            if not artifacts[name].get("exists"):
                issues.append(f"missing_{name}")

        includes = resolve_include_tree(mq5_path, include_roots, hasher)
        if includes["file_count"] == 0:
            issues.append("missing_include_tree")
        if includes["unresolved"]:
            issues.append("unresolved_includes")

        symbols = _extract_history_symbols(symbol, (mq5_path, set_path), sleeve.get("history_symbols"))
        histories: list[dict[str, Any]] = []
        for history_symbol in symbols:
            if history_symbol not in history_cache:
                history_cache[history_symbol] = history_fingerprint(history_symbol, history_roots, hasher)
            fingerprint = history_cache[history_symbol]
            histories.append(fingerprint)
            if not fingerprint.get("valid_dwx_symbol"):
                issues.append(f"invalid_history_symbol:{history_symbol}")
            elif not fingerprint.get("aggregate_sha256"):
                issues.append(f"missing_history:{history_symbol}")
            elif fingerprint.get("location_count") != fingerprint.get("requested_root_count"):
                issues.append(f"history_missing_on_sandbox:{history_symbol}")
            elif fingerprint.get("consistent_across_roots") is False:
                issues.append(f"history_hash_mismatch_across_sandboxes:{history_symbol}")

        stats = stream_stats(stream_path)
        expected_trades = sleeve.get("trades")
        trade_comparison: dict[str, Any] = {
            "expected": expected_trades,
            "actual": stats["trade_count"],
            "status": "UNBOUND" if expected_trades is None else "MATCH",
        }
        if expected_trades is not None:
            try:
                trade_comparison["status"] = "MATCH" if int(expected_trades) == int(stats["trade_count"]) else "MISMATCH"
            except (TypeError, ValueError):
                trade_comparison["status"] = "INVALID_EXPECTATION"
        if trade_comparison["status"] in {"MISMATCH", "INVALID_EXPECTATION"}:
            issues.append("qualified_trade_count_mismatch")
        elif trade_comparison["status"] == "UNBOUND":
            unbound.append("qualified_trade_count")

        declared_card = declared_hash(sleeve, "strategy_card")
        declared_ex5 = declared_hash(sleeve, "ex5")
        declared_set = declared_hash(sleeve, "set")
        declared_stream = declared_hash(sleeve, "stream")
        declared_live_preset = declared_hash(sleeve, "live_preset")
        bindings = {
            "strategy_card": compare_hash(
                declared_card, artifacts["strategy_card"].get("sha256")
            ),
            "qualified_ex5_path": compare_hash(
                declared_ex5, artifacts["qualified_ex5_path_snapshot"].get("sha256")
            ),
            "live_ex5_vs_qualified": compare_hash(declared_ex5, artifacts["live_ex5"].get("sha256")),
            "qualified_set_path": compare_hash(
                declared_set, artifacts["qualified_set_path_snapshot"].get("sha256")
            ),
            "qualified_stream_path": compare_hash(
                declared_stream, artifacts["qualified_q08_stream_path_snapshot"].get("sha256")
            ),
            "live_preset": compare_hash(declared_live_preset, artifacts["live_preset"].get("sha256")),
            "live_ex5_vs_current_qualified_path_snapshot": compare_hash(
                artifacts["qualified_ex5_path_snapshot"].get("sha256"), artifacts["live_ex5"].get("sha256")
            ),
        }
        required_bindings = (
            "strategy_card",
            "qualified_ex5_path",
            "live_ex5_vs_qualified",
            "qualified_set_path",
            "qualified_stream_path",
            "live_preset",
        )
        for binding_name in required_bindings:
            status = bindings[binding_name]["status"]
            if status == "UNBOUND":
                unbound.append(binding_name)
            elif status != "MATCH":
                issues.append(f"binding_{binding_name}_{status.lower()}")

        set_expectation = sleeve.get("set_file_expectation")
        live_values = parse_set_values(live_preset_path)
        set_value_checks: list[dict[str, Any]] = []
        if isinstance(set_expectation, dict):
            for name, expected in sorted(set_expectation.items()):
                actual = live_values.get(str(name))
                status = "MATCH" if compare_set_value(expected, actual) else "MISMATCH"
                set_value_checks.append({"name": name, "expected": expected, "actual": actual, "status": status})
                if status != "MATCH":
                    issues.append(f"live_preset_value_mismatch:{name}")

        if cost_bundle["missing_count"]:
            issues.append("missing_cost_model")
        status = "FAIL" if issues else ("UNBOUND" if unbound else "CLOSED")
        rows.append(
            {
                "key": key,
                "ea_id": ea_id,
                "ea_label": label,
                "symbol": symbol,
                "magic_number": magic,
                "status": status,
                "issues": sorted(set(issues)),
                "unbound": sorted(set(unbound)),
                "artifacts": artifacts,
                "includes": includes,
                "history_symbols": symbols,
                "history": histories,
                "q08_stream_stats": stats,
                "qualified_trade_count": trade_comparison,
                "bindings": bindings,
                "live_preset_candidates": preset_matches,
                "live_preset_value_checks": set_value_checks,
                "cost_model_aggregate_sha256": cost_bundle["aggregate_sha256"],
            }
        )

    if duplicate_keys:
        for row in rows:
            if row.get("key") in duplicate_keys:
                row.setdefault("issues", []).append("duplicate_manifest_sleeve_key")
                row["issues"] = sorted(set(row["issues"]))
                row["status"] = "FAIL"

    expected_count = _manifest_expected_count(payload)
    closed_count = sum(1 for row in rows if row.get("status") == "CLOSED")
    unbound_count = sum(1 for row in rows if row.get("status") == "UNBOUND")
    failed_count = sum(1 for row in rows if row.get("status") == "FAIL")
    sleeves_with_unbound_bindings = sum(1 for row in rows if row.get("unbound"))
    unbound_binding_count = sum(len(row.get("unbound") or []) for row in rows)
    current_path_live_match_count = sum(
        1
        for row in rows
        if (row.get("bindings") or {})
        .get("live_ex5_vs_current_qualified_path_snapshot", {})
        .get("status")
        == "MATCH"
    )
    current_path_live_mismatch_count = sum(
        1
        for row in rows
        if (row.get("bindings") or {})
        .get("live_ex5_vs_current_qualified_path_snapshot", {})
        .get("status")
        == "MISMATCH"
    )
    global_issues: list[str] = []
    if expected_count != len(rows):
        global_issues.append("manifest_declared_count_mismatch")
    if not terminal_roots:
        global_issues.append("no_live_terminal_roots")
    if cost_bundle["missing_count"]:
        global_issues.append("missing_cost_models")
    if qualification_chain["applicable"] and qualification_chain["status"] != "PASS":
        global_issues.extend(
            f"qualification_chain:{issue}" for issue in qualification_chain["issues"]
        )
    global_issues = sorted(set(global_issues))
    verdict = "FAIL" if failed_count or global_issues else ("UNBOUND" if unbound_count else "PASS")
    return {
        "schema_version": 1,
        "kind": "dxz_truth_chain_evidence",
        "generated_at_utc": iso_utc(generated_at),
        "verdict": verdict,
        "global_issues": global_issues,
        "read_only_contract": {
            "live_root": str(live_root),
            "terminal_roots": [str(root) for root in terminal_roots],
            "live_access": "READ_ONLY",
            "writes_under_live_root": False,
            "test_sandboxes": [str(root) for root in sandbox_roots],
            "live_preset_tag": live_preset_tag,
        },
        "input_manifest": {
            **manifest_artifact,
            "book": payload.get("book"),
            "status": payload.get("status"),
            "declared_sleeve_count": expected_count,
        },
        "qualification_chain": qualification_chain,
        "cost_models": cost_bundle,
        "summary": {
            "declared_sleeve_count": expected_count,
            "processed_sleeve_count": len(rows),
            "closed_count": closed_count,
            "unbound_count": unbound_count,
            "failed_count": failed_count,
            "sleeves_with_unbound_bindings": sleeves_with_unbound_bindings,
            "unbound_binding_count": unbound_binding_count,
            "current_path_live_ex5_match_count": current_path_live_match_count,
            "current_path_live_ex5_mismatch_count": current_path_live_mismatch_count,
            "unique_history_symbol_count": len(history_cache),
        },
        "sleeves": rows,
    }


def write_bundle(
    output_dir: Path,
    evidence: dict[str, Any],
    manifest_path: Path,
    live_roots: list[Path],
) -> dict[str, Any]:
    assert_output_outside_live(output_dir, live_roots)
    if output_dir.exists():
        raise FileExistsError(f"immutable evidence bundle already exists: {output_dir}")
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    temp_dir = output_dir.parent / f".{output_dir.name}.tmp-{uuid.uuid4().hex}"
    assert_output_outside_live(temp_dir, live_roots)
    temp_dir.mkdir(parents=False, exist_ok=False)
    try:
        evidence_path = temp_dir / "truth_chain.json"
        manifest_copy = temp_dir / f"input_manifest{manifest_path.suffix or '.json'}"
        evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        shutil.copyfile(manifest_path, manifest_copy)
        hasher = ArtifactHasher()
        sums = {
            evidence_path.name: hasher.sha256(evidence_path),
            manifest_copy.name: hasher.sha256(manifest_copy),
        }
        sums_path = temp_dir / "SHA256SUMS"
        sums_path.write_text(
            "".join(f"{digest}  {name}\n" for name, digest in sorted(sums.items())),
            encoding="ascii",
        )
        temp_dir.replace(output_dir)
    except Exception:
        shutil.rmtree(temp_dir, ignore_errors=True)
        raise
    return {
        "path": str(output_dir),
        "truth_chain": str(output_dir / "truth_chain.json"),
        "manifest_copy": str(output_dir / f"input_manifest{manifest_path.suffix or '.json'}"),
        "sha256sums": str(output_dir / "SHA256SUMS"),
        "overwrite_allowed": False,
    }


def default_output_dir(now: datetime | None = None) -> Path:
    stamp = (now or utc_now()).strftime("%Y%m%dT%H%M%SZ")
    return Path(r"D:\QM\reports\evidence\dxz_truth_chain") / stamp


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="Portfolio manifest JSON")
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    parser.add_argument("--live-root", default=str(DEFAULT_LIVE_ROOT))
    parser.add_argument("--cards-root", action="append", default=None)
    parser.add_argument("--stream-root", default=str(DEFAULT_STREAM_ROOT))
    parser.add_argument("--history-root", action="append", default=None)
    parser.add_argument("--include-root", action="append", default=None)
    parser.add_argument(
        "--sandbox-root",
        action="append",
        default=None,
        help="Isolated tester root; repeat for DXZ_Truth_1..4. Supplies history and platform includes.",
    )
    parser.add_argument("--cost-model", action="append", default=None)
    parser.add_argument(
        "--live-preset-tag",
        default=None,
        help="Require this deployment tag in a live preset filename when a magic has archived candidates",
    )
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--no-bundle", action="store_true", help="Print evidence only; create no bundle")
    parser.add_argument("--quiet", action="store_true", help="Suppress JSON stdout; bundle content is unchanged")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    manifest_path = Path(args.manifest)
    repo_root = Path(args.repo_root)
    live_root = Path(args.live_root)
    terminal_roots = discover_terminal_roots(live_root)
    sandbox_roots = [Path(path) for path in args.sandbox_root] if args.sandbox_root else []
    history_roots = (
        [Path(path) for path in args.history_root]
        if args.history_root
        else (sandbox_roots or [DEFAULT_HISTORY_ROOT])
    )
    if args.include_root:
        include_roots = [Path(path) for path in args.include_root]
    else:
        include_roots = [repo_root / "framework" / "Include"]
        include_roots.extend(root / "MQL5" / "Include" for root in sandbox_roots)
        if not sandbox_roots:
            include_roots.append(DEFAULT_PLATFORM_INCLUDE_ROOT)
    evidence = build_evidence(
        manifest_path,
        repo_root=repo_root,
        live_root=live_root,
        cards_roots=[Path(path) for path in args.cards_root] if args.cards_root else [DEFAULT_CARDS_ROOT],
        stream_root=Path(args.stream_root),
        history_roots=history_roots,
        include_roots=include_roots,
        cost_models=[Path(path) for path in args.cost_model] if args.cost_model else list(DEFAULT_COST_MODELS),
        sandbox_roots=sandbox_roots,
        live_preset_tag=args.live_preset_tag,
    )
    if not args.no_bundle:
        output_dir = Path(args.output_dir) if args.output_dir else default_output_dir()
        protected = [live_root, *terminal_roots]
        evidence["bundle"] = write_bundle(output_dir, evidence, manifest_path, protected)
    if not args.quiet:
        print(json.dumps(evidence, indent=2, sort_keys=True))
    return {"PASS": 0, "UNBOUND": 1, "FAIL": 2}[str(evidence["verdict"])]


if __name__ == "__main__":
    raise SystemExit(main())
