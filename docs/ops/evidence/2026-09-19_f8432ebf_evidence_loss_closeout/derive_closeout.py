#!/usr/bin/env python3
"""Reproduce the f8432ebf evidence-loss inventory and rerun plan.

This reader never invokes the evidence watcher, never changes the farm database, and
never enqueues work.  Its only writes are the two CSVs and the bound summary beside
this script.
"""

from __future__ import annotations

import csv
import datetime as dt
import hashlib
import json
import sqlite3
from collections import Counter, defaultdict
from pathlib import Path


TASK_ID = "f8432ebf-7f91-422f-8fd6-628c2f86e46c"
REPO = Path("C:/QM/repo")
OUT = REPO / "docs/ops/evidence/2026-09-19_f8432ebf_evidence_loss_closeout"
BASELINE = REPO / "artifacts/evidence_cohort_baseline.json"
M05_FORENSICS = (
    REPO
    / "docs/ops/evidence/2026-09-05_m05_recovery/per_path_forensics.json"
)
DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
QUARANTINE = Path("D:/QM/reports/_retention_quarantine")
REPORTS = Path("D:/QM/reports")
RETENTION_LOG = REPORTS / "state/report_retention.log"
ORIGINAL_COHORT_CUTOFF = "2026-09-14T23:59:59Z"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_sha(value: object) -> str:
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def logical_evidence_exists(path: str) -> bool:
    literal = Path(path)
    return literal.exists() or Path(f"{literal}.gz").exists()


def iso_from_ns(value: int) -> str:
    return dt.datetime.fromtimestamp(value / 1_000_000_000, dt.timezone.utc).isoformat()


def iso_from_stat(value: float) -> str:
    return dt.datetime.fromtimestamp(value, dt.timezone.utc).isoformat()


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    entries: dict[str, dict[str, object]] = baseline["entries"]

    first_loss: dict[str, str] = {}
    for loss in baseline["losses"]:
        work_item_id = loss["work_item_id"]
        observed = loss.get("observed_missing_at_utc")
        if observed and (
            work_item_id not in first_loss or observed < first_loss[work_item_id]
        ):
            first_loss[work_item_id] = observed

    m05_all = json.loads(M05_FORENSICS.read_text(encoding="utf-8"))
    m05 = {
        row["work_item_id"]: row for row in m05_all if row.get("within_156") is True
    }
    assert len(m05) == 156, len(m05)

    currently_missing = {
        work_item_id
        for work_item_id, row in entries.items()
        if not logical_evidence_exists(str(row["evidence_path"]))
    }
    assert set(m05).issubset(currently_missing)

    quarantine_rows: dict[str, Path] = {}
    for work_item_id in sorted(currently_missing - set(m05)):
        observed = first_loss.get(work_item_id)
        if not observed or observed > ORIGINAL_COHORT_CUTOFF:
            continue
        original = Path(str(entries[work_item_id]["evidence_path"]))
        relative = original.relative_to(REPORTS)
        matches = sorted(QUARANTINE.glob(f"*/{relative.as_posix()}"))
        if matches:
            assert len(matches) == 1, (work_item_id, matches)
            quarantine_rows[work_item_id] = matches[0]

    assert len(quarantine_rows) == 16, len(quarantine_rows)
    original_ids = set(m05) | set(quarantine_rows)
    assert len(original_ids) == 172
    post_cutoff_ids = currently_missing - original_ids
    assert len(post_cutoff_ids) == 5, len(post_cutoff_ids)

    retention_lines = RETENTION_LOG.read_text(encoding="utf-8", errors="replace").splitlines()
    selected_retention_lines: list[str] = []
    forensic_rows: list[dict[str, object]] = []

    for work_item_id in sorted(m05):
        source = m05[work_item_id]
        baseline_row = entries[work_item_id]
        events = source["exact_target_events"]
        assert len(events) == 1, (work_item_id, len(events))
        event = events[0]
        receipt_entry = event["entry"]
        recovered = source["classification"] == "RECOVERED_COPY"
        assert source["classification"] in {"RECOVERED_COPY", "IRRECOVERABLE"}

        if recovered:
            restoration = source["restoration"]
            last_mtime = restoration["source_mtime_utc"]
            preserved_path = restoration["output_path"]
            process_class = "DL090_REPORT_RETENTION_QUARANTINE_THEN_C_RELOCATION"
            outcome = "RECOVERED_COPY"
        else:
            last_mtime = iso_from_ns(int(receipt_entry["mtime_ns"]))
            preserved_path = ""
            process_class = "OWNER_BACKUP_RETENTION_PHASE2_DELETE_NONRETAINED"
            outcome = "IRRECOVERABLE_LOCAL"

        forensic_rows.append(
            {
                "work_item_id": work_item_id,
                "ea_id": baseline_row["ea_id"],
                "symbol": baseline_row["symbol"],
                "phase": baseline_row["phase"],
                "verdict": baseline_row["verdict"],
                "original_evidence_path": baseline_row["evidence_path"],
                "first_missing_utc": source["first_missing_literal_utc"],
                "last_known_file_mtime_utc": last_mtime,
                "last_known_size_bytes": receipt_entry["size"],
                "post_removal_parent_mtime_utc": source["original_parent_mtime_utc"],
                "process_class": process_class,
                "receipt_action": event["batch_action"],
                "receipt_disposition": receipt_entry["disposition"],
                "receipt_batch_path": event["batch_path"],
                "receipt_exact_paths": event["exact_paths"],
                "receipt_line": event["line"],
                "receipt_completed_utc": event["batch_completed_at"],
                "outcome": outcome,
                "preserved_evidence_path": preserved_path,
                "source_forensics_path": str(M05_FORENSICS),
            }
        )

    for work_item_id, preserved in sorted(quarantine_rows.items()):
        baseline_row = entries[work_item_id]
        snapshot = preserved.relative_to(QUARANTINE).parts[0]
        needle = f"_retention_quarantine\\{snapshot}"
        hits = [
            (number, line)
            for number, line in enumerate(retention_lines, start=1)
            if needle.lower() in line.lower() and "QUARANTINED" in line
        ]
        assert len(hits) == 1, (work_item_id, snapshot, hits)
        line_number, receipt_line = hits[0]
        selected_retention_lines.append(receipt_line)
        stat = preserved.stat()
        parent = Path(str(baseline_row["evidence_path"])).parent
        parent_mtime = iso_from_stat(parent.stat().st_mtime) if parent.exists() else ""
        forensic_rows.append(
            {
                "work_item_id": work_item_id,
                "ea_id": baseline_row["ea_id"],
                "symbol": baseline_row["symbol"],
                "phase": baseline_row["phase"],
                "verdict": baseline_row["verdict"],
                "original_evidence_path": baseline_row["evidence_path"],
                "first_missing_utc": first_loss[work_item_id],
                "last_known_file_mtime_utc": iso_from_stat(stat.st_mtime),
                "last_known_size_bytes": stat.st_size,
                "post_removal_parent_mtime_utc": parent_mtime,
                "process_class": "DL090_REPORT_RETENTION_QUARANTINE",
                "receipt_action": "QUARANTINED",
                "receipt_disposition": "AGE_OUT_NON_PASS",
                "receipt_batch_path": str(RETENTION_LOG),
                "receipt_exact_paths": str(preserved),
                "receipt_line": line_number,
                "receipt_completed_utc": receipt_line.split(" ", 1)[0],
                "outcome": "RECOVERABLE_D_QUARANTINE",
                "preserved_evidence_path": str(preserved),
                "source_forensics_path": str(preserved),
            }
        )

    forensic_rows.sort(
        key=lambda row: (
            str(row["first_missing_utc"]),
            str(row["work_item_id"]),
        )
    )
    assert len(forensic_rows) == 172

    connection = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True, timeout=30)
    connection.row_factory = sqlite3.Row
    pass_rows = [
        dict(row)
        for row in connection.execute(
            """
            SELECT id, ea_id, symbol, phase, verdict, data_window_start,
                   data_window_end, created_at, updated_at
            FROM work_items
            WHERE verdict LIKE 'PASS%'
            """
        )
    ]
    connection.close()

    pass_by_id = {row["id"]: row for row in pass_rows}
    pass_by_cell: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for row in pass_rows:
        pass_by_cell[(row["ea_id"], row["symbol"], row["phase"])].append(row)

    lost_pass_ids = sorted(
        work_item_id
        for work_item_id in original_ids
        if str(entries[work_item_id]["verdict"]).startswith("PASS")
    )
    assert len(lost_pass_ids) == 95

    plan_rows: list[dict[str, object]] = []
    excluded_with_comparable_sibling = 0
    for work_item_id in lost_pass_ids:
        candidate = pass_by_id[work_item_id]
        start = candidate["data_window_start"]
        end = candidate["data_window_end"]

        # A sibling substitutes only when both window bounds are known and equal.
        # NULL bounds are not evidence of equivalence and therefore fail closed into
        # the regeneration plan.
        siblings = []
        if start and end:
            siblings = [
                row
                for row in pass_by_cell[
                    (candidate["ea_id"], candidate["symbol"], candidate["phase"])
                ]
                if row["id"] != work_item_id
                and row["data_window_start"] == start
                and row["data_window_end"] == end
            ]
        if siblings:
            excluded_with_comparable_sibling += 1
            continue

        minutes = 3.0 if candidate["phase"] == "Q03" else 11.1
        plan_rows.append(
            {
                "work_item_id": work_item_id,
                "ea_id": candidate["ea_id"],
                "symbol": candidate["symbol"],
                "phase": candidate["phase"],
                "data_window_start": start or "UNKNOWN_FAIL_CLOSED",
                "data_window_end": end or "UNKNOWN_FAIL_CLOSED",
                "comparable_pass_sibling_count": 0,
                "estimated_tester_minutes": f"{minutes:.1f}",
                "priority_policy": "LOW_DEFAULT_NO_QUEUE_JUMP",
                "ram_class_policy": "AUTOMATIC_AT_CLAIM",
                "append_only_command": (
                    "python C:/QM/repo/tools/strategy_farm/farmctl.py "
                    f"enqueue-backtest --append-only-rerun-of {work_item_id} "
                    f"--phase {candidate['phase']} --rerun-reason \"P0 evidence "
                    f"regeneration, router task {TASK_ID}, 2026-08-31 retention loss\""
                ),
            }
        )

    plan_rows.sort(
        key=lambda row: (
            str(row["phase"]),
            str(row["ea_id"]),
            str(row["symbol"]),
            str(row["work_item_id"]),
        )
    )
    assert len(plan_rows) == 81, len(plan_rows)
    assert excluded_with_comparable_sibling == 14

    forensic_fields = [
        "work_item_id",
        "ea_id",
        "symbol",
        "phase",
        "verdict",
        "original_evidence_path",
        "first_missing_utc",
        "last_known_file_mtime_utc",
        "last_known_size_bytes",
        "post_removal_parent_mtime_utc",
        "process_class",
        "receipt_action",
        "receipt_disposition",
        "receipt_batch_path",
        "receipt_exact_paths",
        "receipt_line",
        "receipt_completed_utc",
        "outcome",
        "preserved_evidence_path",
        "source_forensics_path",
    ]
    plan_fields = [
        "work_item_id",
        "ea_id",
        "symbol",
        "phase",
        "data_window_start",
        "data_window_end",
        "comparable_pass_sibling_count",
        "estimated_tester_minutes",
        "priority_policy",
        "ram_class_policy",
        "append_only_command",
    ]
    write_csv(OUT / "lost_directory_forensics.csv", forensic_fields, forensic_rows)
    write_csv(OUT / "sole_pass_regeneration_plan.csv", plan_fields, plan_rows)

    phase_mix = Counter(str(row["phase"]) for row in plan_rows)
    process_mix = Counter(str(row["process_class"]) for row in forensic_rows)
    outcome_mix = Counter(str(row["outcome"]) for row in forensic_rows)
    total_minutes = sum(float(row["estimated_tester_minutes"]) for row in plan_rows)
    db_projection = sorted(
        (
        {
            key: row[key]
            for key in (
                "id",
                "ea_id",
                "symbol",
                "phase",
                "verdict",
                "data_window_start",
                "data_window_end",
                "created_at",
                "updated_at",
            )
        }
        for row in pass_rows
        if row["id"] in lost_pass_ids
        or (row["ea_id"], row["symbol"], row["phase"])
        in {
            (
                pass_by_id[work_item_id]["ea_id"],
                pass_by_id[work_item_id]["symbol"],
                pass_by_id[work_item_id]["phase"],
            )
            for work_item_id in lost_pass_ids
        }
        ),
        key=lambda row: str(row["id"]),
    )

    summary = {
        "schema": "qm.f8432ebf-evidence-loss-closeout/v1",
        "task_id": TASK_ID,
        "source_bindings": {
            "baseline_path": str(BASELINE),
            "baseline_sha256": sha256(BASELINE),
            "m05_forensics_path": str(M05_FORENSICS),
            "m05_forensics_sha256": sha256(M05_FORENSICS),
            "m05_recovery_commit": "80a577273df55b6797d318f7034f06314cd57862",
            "backup_retention_execution_commit": "99143f421feccc325778dce4ef685b3c9616e6db",
            "relevant_pass_db_projection_sha256": canonical_sha(db_projection),
            "selected_report_retention_receipts_sha256": canonical_sha(
                sorted(set(selected_retention_lines))
            ),
        },
        "original_cohort": {
            "rows": 172,
            "verdicts": dict(
                sorted(Counter(str(entries[item]["verdict"]) for item in original_ids).items())
            ),
            "process_classes": dict(sorted(process_mix.items())),
            "outcomes": dict(sorted(outcome_mix.items())),
            "all_pass_rows_exactly_receipt_deleted": all(
                row["process_class"]
                == "OWNER_BACKUP_RETENTION_PHASE2_DELETE_NONRETAINED"
                for row in forensic_rows
                if str(row["verdict"]).startswith("PASS")
            ),
        },
        "current_watch_snapshot": {
            "missing_rows": len(currently_missing),
            "original_rows": len(original_ids),
            "post_cutoff_rows": len(post_cutoff_ids),
            "post_cutoff_verdicts": dict(
                sorted(
                    Counter(
                        str(entries[item]["verdict"]) for item in post_cutoff_ids
                    ).items()
                )
            ),
            "post_cutoff_pass_rows": sum(
                str(entries[item]["verdict"]).startswith("PASS")
                for item in post_cutoff_ids
            ),
        },
        "regeneration_plan": {
            "lost_pass_rows": 95,
            "planned_measurement_cells": 81,
            "excluded_rows_with_same_ea_symbol_phase_and_known_equal_window": 14,
            "null_window_bounds_fail_closed": True,
            "phase_mix": dict(sorted(phase_mix.items())),
            "estimated_tester_minutes": round(total_minutes, 1),
            "estimated_tester_hours": round(total_minutes / 60, 2),
            "estimate_basis": {
                "Q03_minutes_each": 3.0,
                "Q05_Q06_Q07_minutes_each": 11.1,
                "source": "2026-09-14 plan's bound health latency proxy (p50/p90)",
            },
            "enqueued": False,
        },
        "mutations": {
            "watcher_baseline_rewritten": False,
            "database_written": False,
            "work_enqueued": False,
            "terminal_started": False,
        },
    }
    (OUT / "derived_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
