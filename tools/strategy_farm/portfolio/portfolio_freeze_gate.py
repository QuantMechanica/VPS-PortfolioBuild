"""Fail-closed truth-chain and input-SHA gate for admission/resize book artifacts.

The gate is intentionally separate from strategy screening.  Q09 may continue to
produce a candidate verdict, but no admission/resize process should emit a *new book*
unless this validator passes against the exact files used for that computation.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
ALLOWED_PURPOSES = {"admission", "resize"}


class FreezeGateError(ValueError):
    """The truth-chain is not PASS or the gate is not bound to the actual inputs."""


@dataclass(frozen=True)
class FreezeGateEvidence:
    gate_path: Path
    gate_sha256: str
    purpose: str
    truth_chain_path: Path
    truth_chain_sha256: str
    truth_chain_status: str
    candidate_manifest_sha256: str
    adjudication_sha256: str
    requal_summary_sha256: str

    def as_dict(self) -> dict[str, str]:
        return {
            "gate_path": str(self.gate_path),
            "gate_sha256": self.gate_sha256,
            "purpose": self.purpose,
            "truth_chain_path": str(self.truth_chain_path),
            "truth_chain_sha256": self.truth_chain_sha256,
            "truth_chain_status": self.truth_chain_status,
            "candidate_manifest_sha256": self.candidate_manifest_sha256,
            "adjudication_sha256": self.adjudication_sha256,
            "requal_summary_sha256": self.requal_summary_sha256,
        }


def validate_admission_resize_freeze_gate(
    gate_path: Path,
    *,
    purpose: str,
    actual_inputs: Mapping[str, str],
    actual_stream_sha256: Mapping[str, str],
) -> FreezeGateEvidence:
    """Validate a machine gate against every actual content hash.

    Gate schema version 1::

        {
          "schema_version": 1,
          "gate_type": "ADMISSION_RESIZE_FREEZE",
          "allowed_purposes": ["admission", "resize"],
          "truth_chain": {
            "status": "PASS",
            "artifact_path": "truth_chain.json",
            "artifact_sha256": "...",
            "candidate_manifest_sha256": "...",
            "adjudication_sha256": "...",
            "requal_summary_sha256": "..."
          },
          "inputs": {
            "resize_config_sha256": "...",
            "stream_manifest_sha256": "...",
            "commission_registry_sha256": "...",
            "streams": {"100:EURUSD.DWX": "..."}
          }
        }

    The truth-chain artifact is independently read and SHA-checked.  Admission
    and resize additionally require the bound-candidate qualification chain:
    ``FULL`` + ``PASS`` requalification, adjudication ``PASS``, and candidate
    status ``BOUND_CANDIDATE_COMPLETE``.  The gate binds the exact candidate,
    adjudication and requal-summary artifact hashes reported by that chain.
    Merely writing PASS into the gate is therefore insufficient. Expected and
    actual stream key sets must match.
    """

    requested_purpose = str(purpose).strip().lower()
    if requested_purpose not in ALLOWED_PURPOSES:
        raise FreezeGateError(f"unsupported gate purpose {purpose!r}")
    gate = Path(gate_path).resolve(strict=True)
    try:
        payload = json.loads(gate.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise FreezeGateError(f"invalid freeze gate {gate}: {exc}") from exc
    if payload.get("schema_version") != 1:
        raise FreezeGateError("freeze gate schema_version must be 1")
    if payload.get("gate_type") != "ADMISSION_RESIZE_FREEZE":
        raise FreezeGateError("gate_type must be ADMISSION_RESIZE_FREEZE")
    allowed = payload.get("allowed_purposes")
    if not isinstance(allowed, list) or requested_purpose not in {
        str(item).strip().lower() for item in allowed
    }:
        raise FreezeGateError(f"freeze gate does not allow purpose {requested_purpose!r}")

    truth = payload.get("truth_chain")
    if not isinstance(truth, Mapping):
        raise FreezeGateError("truth_chain object is required")
    if truth.get("status") != "PASS":
        raise FreezeGateError("truth_chain.status must be PASS")
    truth_path = _resolve_below_gate(gate, truth.get("artifact_path"), "truth_chain.artifact_path")
    expected_truth_sha = _required_sha(
        truth.get("artifact_sha256"), "truth_chain.artifact_sha256"
    )
    actual_truth_sha = sha256_file(truth_path)
    if expected_truth_sha != actual_truth_sha:
        raise FreezeGateError(
            f"truth-chain SHA mismatch: expected {expected_truth_sha}, got {actual_truth_sha}"
        )
    try:
        truth_payload = json.loads(truth_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise FreezeGateError(f"invalid truth-chain artifact {truth_path}: {exc}") from exc
    truth_status = truth_payload.get(
        "truth_chain_status", truth_payload.get("status", truth_payload.get("verdict"))
    )
    if truth_status != "PASS":
        raise FreezeGateError(
            f"truth-chain artifact status is {truth_status!r}, expected 'PASS'"
        )

    chain = truth_payload.get("qualification_chain")
    if not isinstance(chain, Mapping) or chain.get("applicable") is not True:
        raise FreezeGateError("truth-chain candidate qualification_chain is required")
    if chain.get("status") != "PASS":
        raise FreezeGateError("truth-chain candidate qualification_chain must be PASS")
    candidate = chain.get("candidate")
    adjudication = chain.get("adjudication")
    requalification = chain.get("requalification")
    if not all(isinstance(item, Mapping) for item in (candidate, adjudication, requalification)):
        raise FreezeGateError("truth-chain qualification lineage artifacts are required")
    if candidate.get("status") != "BOUND_CANDIDATE_COMPLETE":
        raise FreezeGateError("candidate status must be BOUND_CANDIDATE_COMPLETE")
    if adjudication.get("verdict") != "PASS":
        raise FreezeGateError("adjudication verdict must be PASS")
    if requalification.get("scope") != "FULL" or requalification.get("status") != "PASS":
        raise FreezeGateError("requalification must be FULL + PASS")

    candidate_sha = _required_sha(candidate.get("sha256"), "qualification_chain.candidate.sha256")
    adjudication_sha = _required_sha(
        adjudication.get("sha256"), "qualification_chain.adjudication.sha256"
    )
    requal_summary_sha = _required_sha(
        requalification.get("sha256"), "qualification_chain.requalification.sha256"
    )
    lineage_bindings = {
        "candidate_manifest_sha256": candidate_sha,
        "adjudication_sha256": adjudication_sha,
        "requal_summary_sha256": requal_summary_sha,
    }
    for name, observed_sha in lineage_bindings.items():
        expected_sha = _required_sha(truth.get(name), f"truth_chain.{name}")
        if expected_sha != observed_sha:
            raise FreezeGateError(
                f"truth-chain lineage SHA mismatch for {name}: "
                f"expected {expected_sha}, got {observed_sha}"
            )

    inputs = payload.get("inputs")
    if not isinstance(inputs, Mapping):
        raise FreezeGateError("inputs object is required")
    declared_streams = inputs.get("streams")
    if not isinstance(declared_streams, Mapping):
        raise FreezeGateError("inputs.streams object is required")

    actual_scalar = {str(name): _required_sha(value, f"actual_inputs[{name!r}]") for name, value in actual_inputs.items()}
    if not actual_scalar:
        raise FreezeGateError("actual_inputs may not be empty")
    for name, actual_sha in sorted(actual_scalar.items()):
        expected_sha = _required_sha(inputs.get(name), f"inputs.{name}")
        if expected_sha != actual_sha:
            raise FreezeGateError(
                f"input SHA mismatch for {name}: expected {expected_sha}, got {actual_sha}"
            )

    actual_streams = {
        str(label): _required_sha(value, f"actual_stream_sha256[{label!r}]")
        for label, value in actual_stream_sha256.items()
    }
    expected_labels = {str(label) for label in declared_streams}
    if expected_labels != set(actual_streams):
        raise FreezeGateError(
            "stream SHA key mismatch: "
            f"missing={sorted(set(actual_streams)-expected_labels)!r}, "
            f"extra={sorted(expected_labels-set(actual_streams))!r}"
        )
    if not actual_streams:
        raise FreezeGateError("at least one stream SHA is required")
    for label, actual_sha in sorted(actual_streams.items()):
        expected_sha = _required_sha(declared_streams.get(label), f"inputs.streams[{label!r}]")
        if expected_sha != actual_sha:
            raise FreezeGateError(
                f"stream SHA mismatch for {label}: expected {expected_sha}, got {actual_sha}"
            )

    return FreezeGateEvidence(
        gate_path=gate,
        gate_sha256=sha256_file(gate),
        purpose=requested_purpose,
        truth_chain_path=truth_path,
        truth_chain_sha256=actual_truth_sha,
        truth_chain_status="PASS",
        candidate_manifest_sha256=candidate_sha,
        adjudication_sha256=adjudication_sha,
        requal_summary_sha256=requal_summary_sha,
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _required_sha(value: Any, label: str) -> str:
    text = str(value or "").strip().lower()
    if not SHA256_RE.fullmatch(text):
        raise FreezeGateError(f"{label} must be a SHA256 hex digest")
    return text


def _resolve_below_gate(gate: Path, value: Any, label: str) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise FreezeGateError(f"{label} is required")
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = gate.parent / candidate
    try:
        return candidate.resolve(strict=True)
    except OSError as exc:
        raise FreezeGateError(f"{label} does not exist: {candidate}") from exc
