#!/usr/bin/env python3
"""Plan and collect a reproducible Q09_NEWS v2 tester experiment.

The planner creates immutable, per-cell setfiles and a queue-ready manifest.
Execution may be performed by the existing terminal infrastructure.  The
collector then authenticates every cell receipt and artifact before delegating
the economic selection to :mod:`q09_news_contract`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence

try:
    import q09_news_contract as contract
    import q09_news_calendar as calendar_bundle
except ModuleNotFoundError:
    from tools.strategy_farm import q09_news_calendar as calendar_bundle
    from tools.strategy_farm import q09_news_contract as contract


PLAN_SCHEMA = "q09-news-run-plan/v2"
CELL_RECEIPT_SCHEMA = "q09-news-cell-receipt/v2"
CELL_EVIDENCE_SCHEMA = "q09-news-cell-evidence/v2"
COMPLIANCE_MODE_IDS = {"NONE": 0, "DXZ": 1, "FTMO": 2, "5ERS": 3}


class RunnerError(RuntimeError):
    """Raised when a Q09 plan or tester receipt cannot be authenticated."""


def _safe_common_path(value: str) -> str:
    normalized = value.replace("\\", "/").strip("/")
    path = PurePosixPath(normalized)
    if not normalized or path.is_absolute() or ".." in path.parts or ":" in normalized:
        raise RunnerError("calendar_common_relative_path must be safe and relative")
    return str(path)


def _decode_setfile(data: bytes) -> tuple[str, str, bytes]:
    if data.startswith(b"\xff\xfe"):
        return data[2:].decode("utf-16-le"), "utf-16-le", b"\xff\xfe"
    if data.startswith(b"\xfe\xff"):
        return data[2:].decode("utf-16-be"), "utf-16-be", b"\xfe\xff"
    if data.startswith(b"\xef\xbb\xbf"):
        return data[3:].decode("utf-8"), "utf-8", b"\xef\xbb\xbf"
    try:
        return data.decode("utf-8"), "utf-8", b""
    except UnicodeDecodeError:
        return data.decode("cp1252"), "cp1252", b""


def _replace_set_values(text: str, updates: Mapping[str, str]) -> str:
    newline = "\r\n" if "\r\n" in text else "\n"
    remaining = {key.lower(): (key, value) for key, value in updates.items()}
    output: list[str] = []
    for line in text.splitlines():
        if not line or line.lstrip().startswith(";") or "=" not in line:
            output.append(line)
            continue
        key, current = line.split("=", 1)
        update = remaining.pop(key.strip().lower(), None)
        if update is None:
            output.append(line)
            continue
        _, value = update
        suffix = "||" + current.split("||", 1)[1] if "||" in current else ""
        output.append(f"{key}={value}{suffix}")
    if remaining:
        if output and output[-1]:
            output.append("")
        output.append("; Q09_NEWS v2 sealed tester inputs")
        for _, (key, value) in sorted(remaining.items()):
            output.append(f"{key}={value}")
    return newline.join(output) + newline


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def _write_immutable(path: Path, data: bytes) -> None:
    if path.exists():
        if not path.is_file() or path.read_bytes() != data:
            raise RunnerError(f"existing planned artifact contradicts immutable content: {path}")
        return
    _atomic_write(path, data)


def _load_json(path: Path, role: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RunnerError(f"cannot read {role}: {exc}") from exc
    if not isinstance(value, dict):
        raise RunnerError(f"{role} must be a JSON object")
    return value


def _plan_hash(plan: Mapping[str, Any]) -> str:
    unsigned = dict(plan)
    unsigned.pop("plan_sha256", None)
    return hashlib.sha256(contract.canonical_json_bytes(unsigned)).hexdigest()


def _verify_hash(path: Path, expected: str, role: str) -> None:
    if not path.is_file():
        raise RunnerError(f"{role} missing: {path}")
    actual = contract.sha256_file(path)
    if actual != expected:
        raise RunnerError(f"{role} SHA-256 mismatch: expected {expected}, got {actual}")


def _is_prop_target(deployment_target: str) -> bool:
    normalized = deployment_target.strip().upper().replace("-", "_").replace(" ", "_")
    return normalized in {"FTMO", "5ERS", "THE5ERS", "THE_5ERS"}


def _cell_specs(target_compliance: str, expanded: bool) -> list[tuple[str, str, str, int]]:
    specs = [("CONTROL_OFF", "OFF", "NONE", seed) for seed in contract.SEEDS]
    compliances = contract.COMPLIANCE_MODES if expanded else (target_compliance,)
    for compliance in compliances:
        for temporal in contract.TEMPORAL_MODES:
            for seed in contract.SEEDS:
                specs.append(("POLICY_ON", temporal, compliance, seed))
    return specs


def build_run_plan(
    *,
    work_item_id: str,
    candidate_lineage_key: str,
    deployment_target: str,
    q08_work_item_id: str,
    q08_evidence_path: Path,
    baseline_setfile_path: Path,
    ex5_path: Path,
    include_closure_path: Path,
    calendar_manifest_path: Path,
    calendar_common_relative_path: str,
    full_from_utc: str,
    full_to_utc: str,
    selection_from_utc: str,
    selection_to_utc: str,
    holdout_from_utc: str,
    holdout_to_utc: str,
    complete_months: int,
    holdout_complete_months: int,
    tester_model: str,
    cost_profile: str,
    output_root: Path,
    news_or_event_strategy: bool = False,
    force_expanded_matrix: bool = False,
) -> dict[str, Any]:
    """Seal an immutable queue plan and per-cell setfiles."""

    output_root = output_root.resolve()
    source_paths = {
        "q08_evidence": q08_evidence_path.resolve(),
        "baseline_setfile": baseline_setfile_path.resolve(),
        "ex5": ex5_path.resolve(),
        "include_closure": include_closure_path.resolve(),
        "calendar_manifest": calendar_manifest_path.resolve(),
    }
    for role, path in source_paths.items():
        if not path.is_file():
            raise RunnerError(f"{role} missing: {path}")
    try:
        calendar = calendar_bundle.verify_bundle(source_paths["calendar_manifest"].parent)
    except calendar_bundle.CalendarBundleError as exc:
        raise RunnerError(f"calendar bundle verification failed: {exc}") from exc
    if Path(calendar["manifest_path"]).resolve() != source_paths["calendar_manifest"]:
        raise RunnerError("calendar manifest path is not the canonical bundle manifest")
    for field in (
        "bundle_id",
        "content_sha256",
        "coverage_from_utc",
        "coverage_to_utc",
    ):
        if not calendar.get(field):
            raise RunnerError(f"calendar manifest missing {field}")
    target_compliance = contract.compliance_for_target(deployment_target)
    relative_calendar = _safe_common_path(calendar_common_relative_path)
    identities = {
        "q08_work_item_id": q08_work_item_id,
        "q08_evidence_sha256": contract.sha256_file(source_paths["q08_evidence"]),
        "baseline_setfile_sha256": contract.sha256_file(source_paths["baseline_setfile"]),
        "ex5_sha256": contract.sha256_file(source_paths["ex5"]),
        "include_closure_sha256": contract.sha256_file(source_paths["include_closure"]),
    }
    windows = {
        "full_from_utc": full_from_utc,
        "full_to_utc": full_to_utc,
        "selection_from_utc": selection_from_utc,
        "selection_to_utc": selection_to_utc,
        "holdout_from_utc": holdout_from_utc,
        "holdout_to_utc": holdout_to_utc,
        "complete_months": int(complete_months),
        "holdout_complete_months": int(holdout_complete_months),
        "holdout_sealed": True,
    }
    base_material = {
        "candidate_lineage_key": candidate_lineage_key,
        "deployment_target": deployment_target,
        "identities": identities,
        "calendar_bundle": {
            "bundle_id": calendar["bundle_id"],
            "manifest_sha256": contract.sha256_file(source_paths["calendar_manifest"]),
            "content_sha256": calendar["content_sha256"],
            "coverage_from_utc": calendar["coverage_from_utc"],
            "coverage_to_utc": calendar["coverage_to_utc"],
        },
        "windows": windows,
        "tester_model": tester_model,
        "cost_profile": cost_profile,
    }
    paired_base_identity = hashlib.sha256(contract.canonical_json_bytes(base_material)).hexdigest()
    identities["paired_base_identity_sha256"] = paired_base_identity
    # Reuse contract header validation so planner and adjudicator cannot drift.
    header_probe = {
        "schema_version": contract.SCHEMA_VERSION,
        "work_item_id": work_item_id,
        "deployment_target": deployment_target,
        "identities": identities,
        "calendar_bundle": base_material["calendar_bundle"],
        "windows": windows,
    }
    try:
        contract.validate_experiment_header(header_probe)
    except contract.ContractError as exc:
        raise RunnerError(str(exc)) from exc

    expanded = bool(force_expanded_matrix or news_or_event_strategy or _is_prop_target(deployment_target))
    source_bytes = source_paths["baseline_setfile"].read_bytes()
    source_text, encoding, bom = _decode_setfile(source_bytes)
    cells: list[dict[str, Any]] = []
    for arm, temporal, compliance, seed in _cell_specs(target_compliance, expanded):
        run_material = {
            "paired_base_identity_sha256": paired_base_identity,
            "arm": arm,
            "temporal_mode": temporal,
            "compliance_mode": compliance,
            "seed": seed,
        }
        run_identity = hashlib.sha256(contract.canonical_json_bytes(run_material)).hexdigest()
        cell_dir = output_root / "cells" / f"{arm.lower()}__m{contract.TEMPORAL_MODE_IDS[temporal]}__c{COMPLIANCE_MODE_IDS[compliance]}__s{seed}"
        setfile_path = cell_dir / "inputs.set"
        updated = _replace_set_values(
            source_text,
            {
                "qm_rng_seed": str(seed),
                "qm_news_temporal": str(contract.TEMPORAL_MODE_IDS[temporal]),
                "qm_news_compliance": str(COMPLIANCE_MODE_IDS[compliance]),
                "qm_news_calendar_bundle_id": str(calendar["bundle_id"]),
                "qm_news_calendar_expected_sha256": str(calendar["content_sha256"]),
                "qm_news_calendar_common_relative_path": relative_calendar,
            },
        )
        setfile_bytes = bom + updated.encode(encoding)
        _write_immutable(setfile_path, setfile_bytes)
        cells.append(
            {
                **run_material,
                "run_identity_sha256": run_identity,
                "setfile_path": str(setfile_path.resolve()),
                "setfile_sha256": contract.sha256_file(setfile_path),
                "receipt_path": str((cell_dir / "cell_receipt.json").resolve()),
            }
        )
    if source_paths["baseline_setfile"].read_bytes() != source_bytes:
        raise RunnerError("baseline source setfile changed during planning")

    input_manifest = {
        "schema_version": "q09-news-input-manifest/v2",
        "work_item_id": work_item_id,
        "candidate_lineage_key": candidate_lineage_key,
        "deployment_target": deployment_target,
        "target_compliance": target_compliance,
        "source_paths": {key: str(value) for key, value in source_paths.items()},
        "identities": identities,
        "calendar_bundle": base_material["calendar_bundle"] | {"common_relative_path": relative_calendar},
        "windows": windows,
        "tester_model": tester_model,
        "cost_profile": cost_profile,
        "news_or_event_strategy": bool(news_or_event_strategy),
        "matrix_scope": "7x4" if expanded else "7x1_target_compliance",
    }
    input_manifest_path = output_root / "input_manifest.json"
    input_manifest_bytes = contract.canonical_json_bytes(input_manifest)
    _write_immutable(input_manifest_path, input_manifest_bytes)
    plan: dict[str, Any] = {
        "schema_version": PLAN_SCHEMA,
        "work_item_id": work_item_id,
        "candidate_lineage_key": candidate_lineage_key,
        "input_manifest_path": str(input_manifest_path.resolve()),
        "input_manifest_sha256": contract.sha256_file(input_manifest_path),
        "matrix_scope": input_manifest["matrix_scope"],
        "target_compliance": target_compliance,
        "cell_count": len(cells),
        "cells": cells,
    }
    plan["plan_sha256"] = _plan_hash(plan)
    plan_path = output_root / "run_plan.json"
    _write_immutable(plan_path, contract.canonical_json_bytes(plan))
    return {**plan, "plan_path": str(plan_path.resolve())}


def load_run_plan(path: Path) -> dict[str, Any]:
    plan = _load_json(path, "Q09 run plan")
    if plan.get("schema_version") != PLAN_SCHEMA:
        raise RunnerError("unsupported Q09 run-plan schema")
    if plan.get("plan_sha256") != _plan_hash(plan):
        raise RunnerError("Q09 run-plan SHA-256 mismatch")
    if int(plan.get("cell_count", -1)) != len(plan.get("cells", [])):
        raise RunnerError("Q09 run-plan cell_count mismatch")
    return plan


def _validate_source_vintage(input_manifest: Mapping[str, Any]) -> None:
    identities = input_manifest["identities"]
    source_paths = input_manifest["source_paths"]
    checks = {
        "q08_evidence": identities["q08_evidence_sha256"],
        "baseline_setfile": identities["baseline_setfile_sha256"],
        "ex5": identities["ex5_sha256"],
        "include_closure": identities["include_closure_sha256"],
        "calendar_manifest": input_manifest["calendar_bundle"]["manifest_sha256"],
    }
    for role, expected in checks.items():
        _verify_hash(Path(source_paths[role]), expected, role)


def _receipt_to_cell(spec: Mapping[str, Any]) -> dict[str, Any]:
    receipt_path = Path(spec["receipt_path"])
    receipt = _load_json(receipt_path, f"cell receipt {receipt_path}")
    if receipt.get("schema_version") != CELL_RECEIPT_SCHEMA:
        raise RunnerError(f"unsupported cell receipt schema: {receipt_path}")
    for field in ("run_identity_sha256", "paired_base_identity_sha256", "arm", "temporal_mode", "compliance_mode", "seed"):
        if receipt.get(field) != spec.get(field):
            raise RunnerError(f"cell receipt {field} mismatch: {receipt_path}")
    if receipt.get("requested_seed") != spec["seed"] or receipt.get("effective_seed") != spec["seed"]:
        raise RunnerError(f"cell receipt seed authentication failed: {receipt_path}")
    _verify_hash(Path(spec["setfile_path"]), str(spec["setfile_sha256"]), "planned cell setfile")
    if receipt.get("setfile_sha256") != spec["setfile_sha256"]:
        raise RunnerError(f"cell receipt setfile hash mismatch: {receipt_path}")
    artifact_hashes: dict[str, str] = {}
    artifact_paths: dict[str, Path] = {}
    for role in ("report", "evidence"):
        path_field = f"{role}_path"
        hash_field = f"{role}_sha256"
        path = Path(str(receipt.get(path_field, "")))
        expected = str(receipt.get(hash_field, ""))
        _verify_hash(path, expected, f"cell {role}")
        artifact_hashes[hash_field] = expected
        artifact_paths[role] = path
    flat_receipt_hash: str | None = None
    if receipt.get("flat_at_event_receipt_path") or receipt.get("flat_at_event_receipt_sha256"):
        flat_path = Path(str(receipt.get("flat_at_event_receipt_path", "")))
        flat_receipt_hash = str(receipt.get("flat_at_event_receipt_sha256", ""))
        _verify_hash(flat_path, flat_receipt_hash, "flat-at-event receipt")
    metrics = receipt.get("metrics")
    if not isinstance(metrics, Mapping) or not all(key in metrics for key in ("selection", "holdout", "full")):
        raise RunnerError(f"cell receipt metrics incomplete: {receipt_path}")
    evidence_document = _load_json(artifact_paths["evidence"], f"cell evidence {artifact_paths['evidence']}")
    if evidence_document.get("schema_version") != CELL_EVIDENCE_SCHEMA:
        raise RunnerError(f"unsupported cell evidence schema: {artifact_paths['evidence']}")
    evidence_bindings = {
        "run_identity_sha256": spec["run_identity_sha256"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "requested_seed": spec["seed"],
        "effective_seed": spec["seed"],
        "setfile_sha256": spec["setfile_sha256"],
        "report_sha256": artifact_hashes["report_sha256"],
    }
    for field, expected in evidence_bindings.items():
        if evidence_document.get(field) != expected:
            raise RunnerError(f"cell evidence {field} mismatch: {artifact_paths['evidence']}")
    if evidence_document.get("metrics") != metrics:
        raise RunnerError(f"cell receipt metrics contradict hashed cell evidence: {receipt_path}")
    if evidence_document.get("q07_seed_stability_pass") != receipt.get("q07_seed_stability_pass"):
        raise RunnerError(f"cell Q07 stability receipt contradicts hashed evidence: {receipt_path}")
    if evidence_document.get("flat_at_event_receipt_sha256") != flat_receipt_hash:
        raise RunnerError(f"cell flat-at-event receipt contradicts hashed evidence: {receipt_path}")
    return {
        "arm": spec["arm"],
        "temporal_mode": spec["temporal_mode"],
        "compliance_mode": spec["compliance_mode"],
        "seed": spec["seed"],
        "requested_seed": receipt["requested_seed"],
        "effective_seed": receipt["effective_seed"],
        "paired_base_identity_sha256": spec["paired_base_identity_sha256"],
        "run_identity_sha256": spec["run_identity_sha256"],
        "setfile_sha256": spec["setfile_sha256"],
        "evidence_sha256": artifact_hashes["evidence_sha256"],
        "report_sha256": artifact_hashes["report_sha256"],
        "selection": metrics["selection"],
        "holdout": metrics["holdout"],
        "full": metrics["full"],
        "q07_seed_stability_pass": receipt.get("q07_seed_stability_pass"),
        "flat_at_event_receipt_sha256": flat_receipt_hash,
    }


def collect_run_plan(plan_path: Path, *, output_root: Path | None = None) -> dict[str, Any]:
    plan = load_run_plan(plan_path)
    input_path = Path(plan["input_manifest_path"])
    _verify_hash(input_path, str(plan["input_manifest_sha256"]), "Q09 input manifest")
    input_manifest = _load_json(input_path, "Q09 input manifest")
    _validate_source_vintage(input_manifest)
    cells = [_receipt_to_cell(spec) for spec in plan["cells"]]
    payload = {
        "schema_version": contract.SCHEMA_VERSION,
        "work_item_id": input_manifest["work_item_id"],
        "deployment_target": input_manifest["deployment_target"],
        "identities": input_manifest["identities"],
        "calendar_bundle": {
            key: input_manifest["calendar_bundle"][key]
            for key in (
                "bundle_id", "manifest_sha256", "content_sha256", "coverage_from_utc", "coverage_to_utc"
            )
        },
        "windows": input_manifest["windows"],
        "news_or_event_strategy": input_manifest["news_or_event_strategy"],
        "cells": cells,
    }
    result = contract.adjudicate(payload)
    destination = (output_root or plan_path.parent).resolve()
    evidence_path = destination / "q09_news_evidence.json"
    aggregate_path = destination / "aggregate.json"
    _atomic_write(evidence_path, contract.canonical_json_bytes(payload))
    _atomic_write(aggregate_path, contract.canonical_json_bytes(result))
    return {
        "verdict": result["verdict"],
        "adjudication": result,
        "evidence_path": str(evidence_path),
        "evidence_sha256": contract.sha256_file(evidence_path),
        "aggregate_path": str(aggregate_path),
        "aggregate_sha256": contract.sha256_file(aggregate_path),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument("--work-item-id", required=True)
    plan.add_argument("--candidate-lineage-key", required=True)
    plan.add_argument("--deployment-target", required=True)
    plan.add_argument("--q08-work-item-id", required=True)
    plan.add_argument("--q08-evidence", required=True, type=Path)
    plan.add_argument("--baseline-setfile", required=True, type=Path)
    plan.add_argument("--ex5", required=True, type=Path)
    plan.add_argument("--include-closure", required=True, type=Path)
    plan.add_argument("--calendar-manifest", required=True, type=Path)
    plan.add_argument("--calendar-common-relative-path", required=True)
    for name in (
        "full-from-utc", "full-to-utc", "selection-from-utc", "selection-to-utc",
        "holdout-from-utc", "holdout-to-utc",
    ):
        plan.add_argument("--" + name, required=True)
    plan.add_argument("--complete-months", required=True, type=int)
    plan.add_argument("--holdout-complete-months", required=True, type=int)
    plan.add_argument("--tester-model", required=True)
    plan.add_argument("--cost-profile", required=True)
    plan.add_argument("--output-root", required=True, type=Path)
    plan.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    plan.add_argument("--news-or-event-strategy", action="store_true")
    plan.add_argument("--force-expanded-matrix", action="store_true")
    collect = sub.add_parser("collect")
    collect.add_argument("--plan", required=True, type=Path)
    collect.add_argument("--output-root", type=Path)
    collect.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "plan":
        result = build_run_plan(
            work_item_id=args.work_item_id,
            candidate_lineage_key=args.candidate_lineage_key,
            deployment_target=args.deployment_target,
            q08_work_item_id=args.q08_work_item_id,
            q08_evidence_path=args.q08_evidence,
            baseline_setfile_path=args.baseline_setfile,
            ex5_path=args.ex5,
            include_closure_path=args.include_closure,
            calendar_manifest_path=args.calendar_manifest,
            calendar_common_relative_path=args.calendar_common_relative_path,
            full_from_utc=args.full_from_utc,
            full_to_utc=args.full_to_utc,
            selection_from_utc=args.selection_from_utc,
            selection_to_utc=args.selection_to_utc,
            holdout_from_utc=args.holdout_from_utc,
            holdout_to_utc=args.holdout_to_utc,
            complete_months=args.complete_months,
            holdout_complete_months=args.holdout_complete_months,
            tester_model=args.tester_model,
            cost_profile=args.cost_profile,
            output_root=args.output_root,
            news_or_event_strategy=args.news_or_event_strategy,
            force_expanded_matrix=args.force_expanded_matrix,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    result = collect_run_plan(args.plan, output_root=args.output_root)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["verdict"] == "CONFIG_LOCKED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
