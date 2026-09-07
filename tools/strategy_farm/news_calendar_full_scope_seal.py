"""Read-only E1-D full-scope calendar seal/readiness report.

This tool never repairs, publishes, mirrors, repins, or changes a verdict.  It
hash-checks one completed E1-A candidate, reports every measured gate and
residual, verifies the current repin chain, and asks the canonical candidate
ingress to adjudicate the candidate.  A publication multi-plan is constructed
in memory only when all eight measured gates pass and ingress accepts the exact
manifest hash.  Failed or declaration-covered candidates cannot produce a plan.
"""
from __future__ import annotations

import argparse
from collections import Counter
import datetime as dt
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    import news_calendar_candidate_ingress as ingress
    import news_calendar_gate as gate
    import news_calendar_repin as repin
except ModuleNotFoundError:
    from tools.strategy_farm import news_calendar_candidate_ingress as ingress
    from tools.strategy_farm import news_calendar_gate as gate
    from tools.strategy_farm import news_calendar_repin as repin


SCHEMA = "qm.news-calendar-full-scope-seal/v1"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _strict_json(path: Path) -> dict[str, Any]:
    def object_pairs(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key {key!r}: {path}")
            result[key] = value
        return result

    value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=object_pairs)
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def _gate_progress(checks: Mapping[str, Any], footprints: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    if set(checks) != set(ingress.GATES):
        raise ValueError("candidate must contain exactly the eight E1 measured gates")
    rows: list[dict[str, Any]] = []
    for name in ingress.GATES:
        value = checks[name]
        if not isinstance(value, dict) or type(value.get("pass")) is not bool:
            raise ValueError(f"gate {name} lacks an exact boolean pass value")
        residual: dict[str, Any] = {}
        if name == "6.1_anchor_shares":
            failed = value.get("failed_groups") or []
            residual = {
                "failed_groups": len(failed),
                "failed_group_rows": sum(int(item.get("total") or 0) for item in failed),
                "failed_classes": len({str(item.get("class")) for item in failed}),
            }
        elif name == "6.2_coverage":
            fresh = value.get("fresh_exports") or {}
            confirmed = set(value.get("fresh_currencies_with_confirmed_official_anchor") or [])
            residual = {
                "fresh_export_currencies_present": sorted(
                    currency for currency, item in fresh.items() if item.get("present")
                ),
                "fresh_anchor_currencies_confirmed": sorted(confirmed),
                "fresh_anchor_currencies_missing": sorted(set(fresh) - confirmed),
                "unexplained_zero_months": value.get("unexplained_zero_months") or {},
            }
        elif name == "6.5_tick_footprints":
            statuses = Counter(str(item.get("status") or "MISSING_STATUS") for item in footprints)
            residual = {
                "checks": len(footprints),
                "status_counts": dict(sorted(statuses.items())),
                "unresolved_checks": sum(count for status, count in statuses.items() if status != "PASS"),
            }
        elif name == "6.7_detector_clean":
            residual = {
                "failed_or_unverified_high_rows": int(value.get("failed_or_unverified_high_rows") or 0),
                "input_changes": value.get("input_changes") or [],
                "unverified_native_exports": value.get("unverified_native_exports") or [],
            }
        rows.append({
            "gate": name,
            "measured_pass": value["pass"],
            "scope_status": value.get("scope_status"),
            "declaration_is_measured_pass": value.get("declaration_is_measured_pass"),
            "residual": residual,
        })
    return rows


def analyze_candidate(candidate_dir: Path, *, verify_repin_chain: bool = True) -> dict[str, Any]:
    candidate = Path(candidate_dir).resolve()
    manifest_path = candidate / "manifest.json"
    verification_path = candidate / "verification.json"
    manifest = _strict_json(manifest_path)
    verification = _strict_json(verification_path)
    manifest_sha256 = _sha256(manifest_path)
    verification_sha256 = _sha256(verification_path)
    if manifest.get("verification_sha256") != verification_sha256:
        raise ValueError("candidate verification hash differs from manifest binding")

    entries = manifest.get("files")
    if not isinstance(entries, list) or {item.get("name") for item in entries} != set(gate.CALENDAR_NAMES):
        raise ValueError("candidate manifest does not bind the exact calendar pair")
    candidate_files = []
    for name in gate.CALENDAR_NAMES:
        path = candidate / name
        entry = next(item for item in entries if item.get("name") == name)
        parsed = gate._parse_calendar_file(path, name)
        if parsed.sha256 != entry.get("sha256") or parsed.row_count != entry.get("row_count"):
            raise ValueError(f"candidate file differs from manifest binding: {name}")
        candidate_files.append({
            "name": name,
            "path": str(path),
            "sha256": parsed.sha256,
            "row_count": parsed.row_count,
        })

    footprints_path = candidate / "footprint_summary.json"
    footprints_value = json.loads(footprints_path.read_text(encoding="utf-8-sig"))
    if not isinstance(footprints_value, list):
        raise ValueError("footprint summary must be a list")
    checks = verification.get("gates")
    if not isinstance(checks, dict):
        raise ValueError("candidate verification gates must be an object")
    progress = _gate_progress(checks, footprints_value)
    offset_path = candidate / "nonusd_offset_decisions.json"
    offset_decisions = json.loads(offset_path.read_text(encoding="utf-8-sig"))
    if not isinstance(offset_decisions, list):
        raise ValueError("non-USD offset decisions must be a list")

    input_receipts = []
    for item in manifest.get("input_files") or []:
        path = Path(str(item.get("path") or ""))
        expected = str(item.get("sha256") or "")
        actual = _sha256(path) if path.is_file() else None
        input_receipts.append({
            "path": str(path),
            "role": item.get("role"),
            "expected_sha256": expected,
            "actual_sha256": actual,
            "matches": actual == expected,
        })
    changed_inputs = [item for item in input_receipts if not item["matches"]]
    conflict_exports = [
        item for item in manifest.get("input_files") or []
        if Path(str(item.get("path") or "")).name in {
            "T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv",
            "T_EXPORT_USD_HIGH_2025_NATIVE.csv",
        }
    ]

    ingress_result: dict[str, Any]
    try:
        ingress_result = ingress.prepare(gate, candidate, manifest_sha256)
    except (OSError, RuntimeError, ValueError) as exc:
        ingress_result = {"status": "REFUSED", "error": str(exc)}

    repin_result: dict[str, Any]
    if verify_repin_chain:
        try:
            repin_result = repin.verify_chain(
                receipt_dir=repin.DEFAULT_RECEIPT_DIR,
                registry_path=repin.DEFAULT_REGISTRY,
                calendar_path=repin.DEFAULT_CALENDAR,
            )
        except (OSError, RuntimeError, ValueError) as exc:
            repin_result = {"ok": False, "status": "REFUSED", "error": str(exc)}
    else:
        repin_result = {"status": "NOT_RUN_TEST_MODE"}

    failed_gates = [row["gate"] for row in progress if not row["measured_pass"]]
    scoped = bool(manifest.get("declared_inadmissible_ranges") or manifest.get("scoped_review_only"))
    ready = (
        not failed_gates
        and not scoped
        and not changed_inputs
        and ingress_result.get("status") == "VALIDATED"
        and repin_result.get("status") == "PASS"
    )
    multi_plan: dict[str, Any]
    if ready:
        plan = gate.build_multi_principal_publication_plan(
            candidate / gate.PRIMARY_NAME,
            candidate / gate.SECONDARY_NAME,
        )
        multi_plan = {
            "status": "DRY_RUN_PREPARED_IN_MEMORY",
            "plan_sha256": plan["plan_sha256"],
            "bundle_id": plan["manifest"]["bundle_id"],
            "plan": plan,
        }
    else:
        multi_plan = {
            "status": "WITHHELD_FAILED_FULL_SCOPE_ADMISSION",
            "failed_measured_gates": failed_gates,
            "scoped_candidate": scoped,
            "input_integrity_pass": not changed_inputs,
            "current_repin_chain_pass": repin_result.get("status") == "PASS",
            "ingress": ingress_result,
        }

    return {
        "schema": SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "status": "READY_FOR_CEO_RELEASE_REVIEW" if ready else "NOT_READY_FAIL_CLOSED",
        "candidate_dir": str(candidate),
        "candidate_manifest_sha256": manifest_sha256,
        "candidate_verification_sha256": verification_sha256,
        "candidate_files": candidate_files,
        "input_integrity": {
            "checked": len(input_receipts),
            "all_match": not changed_inputs,
            "changed_or_missing": changed_inputs,
        },
        "gate_progress": progress,
        "failed_measured_gates": failed_gates,
        "anchor_residuals": checks["6.1_anchor_shares"].get("failed_groups") or [],
        "footprint_residuals": [
            item for item in footprints_value if item.get("status") != "PASS"
        ],
        "nonusd_offset_decisions": offset_decisions,
        "conflicting_export_records": conflict_exports,
        "candidate_ingress": ingress_result,
        "current_repin_chain": repin_result,
        "multi_plan": multi_plan,
        "repin_record": {
            "status": "WITHHELD_NO_CEO_RELEASE",
            "record_called": False,
            "production_write": False,
        },
        "production_write": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        report = analyze_candidate(args.candidate_dir)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(report, handle, indent=2, sort_keys=True, ensure_ascii=False)
            handle.write("\n")
        print(json.dumps({
            "status": report["status"],
            "output": str(args.output.resolve()),
            "failed_measured_gates": report["failed_measured_gates"],
            "production_write": False,
        }, indent=2, sort_keys=True))
        return 0 if report["status"] == "READY_FOR_CEO_RELEASE_REVIEW" else 2
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc), "production_write": False}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
