"""Deterministic MNT-023 trigger for a DXZ next-book review.

This classifier does not deploy, reweight, or touch a terminal.  It only turns a
hash-bound, like-for-like OOS comparison into one of ``BETTER``,
``MATERIAL_BUT_REVIEW`` or ``NO_MATERIAL_GAIN``.  ``BETTER`` is the
OWNER-ratified 2026-07-29 contract: OOS Sharpe improves by at least 0.06 while
MaxDD worsens by no more than 0.05 percentage points.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Mapping


SCHEMA_VERSION = 1
MIN_OOS_SHARPE_DELTA = 0.06
MAX_DD_WORSENING_PP = 0.05
MATERIAL_DD_IMPROVEMENT_PP = 0.05
EPSILON = 1e-12
CLASSES = {"BETTER", "MATERIAL_BUT_REVIEW", "NO_MATERIAL_GAIN"}


class ContractError(ValueError):
    """Raised when evidence is incomplete or not like-for-like."""


def canonical_sha256(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _number(value: Any, field: str) -> float:
    if isinstance(value, bool):
        raise ContractError(f"{field} must be numeric")
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise ContractError(f"{field} must be numeric") from exc
    if not math.isfinite(result):
        raise ContractError(f"{field} must be finite")
    return result


def _book(payload: Mapping[str, Any], name: str, basis_sha: str) -> dict[str, Any]:
    raw = payload.get(name)
    if not isinstance(raw, Mapping):
        raise ContractError(f"{name} must be an object")
    if "live_probation" in raw or "live_metrics" in raw:
        raise ContractError(f"{name} mixes live/probation evidence into the OOS comparison")
    book_id = str(raw.get("book_id") or "").strip()
    if not book_id:
        raise ContractError(f"{name}.book_id is required")
    if str(raw.get("comparison_basis_sha256") or "").lower() != basis_sha:
        raise ContractError(f"{name}.comparison_basis_sha256 mismatch")
    evidence_sha = str(raw.get("evidence_sha256") or "").strip().lower()
    if len(evidence_sha) != 64 or any(ch not in "0123456789abcdef" for ch in evidence_sha):
        raise ContractError(f"{name}.evidence_sha256 must be SHA-256")
    metrics = raw.get("oos_metrics")
    if not isinstance(metrics, Mapping):
        raise ContractError(f"{name}.oos_metrics must be an object")
    robustness = str(raw.get("robustness_status") or "").strip().upper()
    if robustness not in {"PASS", "REVIEW", "FAIL"}:
        raise ContractError(f"{name}.robustness_status must be PASS, REVIEW or FAIL")
    return {
        "book_id": book_id,
        "evidence_sha256": evidence_sha,
        "oos_sharpe": _number(metrics.get("sharpe"), f"{name}.oos_metrics.sharpe"),
        "max_drawdown_pct": _number(
            metrics.get("max_drawdown_pct"), f"{name}.oos_metrics.max_drawdown_pct"
        ),
        "robustness_status": robustness,
        "correlation_contribution": str(raw.get("correlation_contribution") or "UNKNOWN").upper(),
        "operational_complexity": str(raw.get("operational_complexity") or "UNKNOWN").upper(),
    }


def classify(payload: Mapping[str, Any]) -> dict[str, Any]:
    if payload.get("schema_version") != SCHEMA_VERSION:
        raise ContractError(f"schema_version must be {SCHEMA_VERSION}")
    basis = payload.get("comparison_basis")
    if not isinstance(basis, Mapping) or not basis:
        raise ContractError("comparison_basis must be a non-empty object")
    declared_basis_sha = str(payload.get("comparison_basis_sha256") or "").strip().lower()
    actual_basis_sha = canonical_sha256(basis)
    if declared_basis_sha != actual_basis_sha:
        raise ContractError(
            f"comparison_basis_sha256 mismatch: expected {actual_basis_sha}, got {declared_basis_sha}"
        )

    incumbent = _book(payload, "incumbent", actual_basis_sha)
    challenger = _book(payload, "challenger", actual_basis_sha)
    if incumbent["book_id"] == challenger["book_id"]:
        raise ContractError("incumbent and challenger book_id must differ")

    sharpe_delta = challenger["oos_sharpe"] - incumbent["oos_sharpe"]
    dd_delta = challenger["max_drawdown_pct"] - incumbent["max_drawdown_pct"]
    sharpe_gate = sharpe_delta + EPSILON >= MIN_OOS_SHARPE_DELTA
    dd_gate = dd_delta <= MAX_DD_WORSENING_PP + EPSILON
    robustness_gate = challenger["robustness_status"] == "PASS"

    review_flags: list[str] = []
    if not sharpe_gate:
        review_flags.append("SHARPE_DELTA_BELOW_0_06")
    if not dd_gate:
        review_flags.append("DD_WORSENING_ABOVE_0_05PP")
    if not robustness_gate:
        review_flags.append("CHALLENGER_ROBUSTNESS_NOT_PASS")
    if challenger["correlation_contribution"] in {"WORSENS", "UNKNOWN"}:
        review_flags.append("CORRELATION_AXIS_REQUIRES_REVIEW")
    if challenger["operational_complexity"] in {"HIGHER", "UNKNOWN"}:
        review_flags.append("OPERATIONAL_COMPLEXITY_REQUIRES_REVIEW")

    if sharpe_gate and dd_gate and robustness_gate:
        trigger_class = "BETTER"
    elif sharpe_gate or dd_delta <= -MATERIAL_DD_IMPROVEMENT_PP + EPSILON:
        trigger_class = "MATERIAL_BUT_REVIEW"
    else:
        trigger_class = "NO_MATERIAL_GAIN"

    return {
        "schema_version": SCHEMA_VERSION,
        "trigger_class": trigger_class,
        "deployment_action": "NONE",
        "owner_review_unlocked": trigger_class == "BETTER",
        "comparison_basis_sha256": actual_basis_sha,
        "incumbent_book_id": incumbent["book_id"],
        "challenger_book_id": challenger["book_id"],
        "deltas": {
            "oos_sharpe": round(sharpe_delta, 12),
            "max_drawdown_pp": round(dd_delta, 12),
        },
        "gates": {
            "min_oos_sharpe_delta": MIN_OOS_SHARPE_DELTA,
            "max_dd_worsening_pp": MAX_DD_WORSENING_PP,
            "sharpe_pass": sharpe_gate,
            "drawdown_pass": dd_gate,
            "robustness_pass": robustness_gate,
        },
        "review_flags": review_flags,
        "live_probation": payload.get("live_probation"),
        "decision_note": "BETTER unlocks OWNER review only; it never deploys automatically.",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    payload = json.loads(args.input.read_text(encoding="utf-8-sig"))
    result = classify(payload)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContractError, OSError, json.JSONDecodeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2))
        raise SystemExit(2)
