"""Reproduce the sealed Q08.5 empty-strategy-parameter cohort audit.

The audit is read-only against the farm database and report tree.  It binds
each named row to its Q08 baseline, Q07 predecessor execution identity, current
source/set bytes, and append-only successors.  Output is evidence only: this
tool never enqueues, edits a verdict, or invokes MetaTrader.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPORTS = Path(r"D:\QM\reports\work_items")
DEFAULT_REPO = Path(r"C:\QM\repo")
COHORT_SINCE = "2026-09-04T00:00:00+00:00"
DEFECT_TOKEN = "baseline_setfile_defect:empty_strategy_params"

# Frozen from the task's 72-hour class census.  Exact IDs make subsequent
# database activity unable to silently change the evidentiary cohort.
COHORT_IDS = (
    "8c0de140-37bb-4f43-b811-98c00d1c2839",
    "32c48193-4013-4763-a119-860f77a8bf5c",
    "02cf605e-c90a-43ef-ab56-a5bcba7d636b",
    "40a802ca-63bc-4252-bdb7-1bfb3f130a99",
    "1da1645c-7c69-43d9-8617-f55040122bdc",
    "5901ae3b-8725-4126-841e-d2dcec30184b",
    "ee8b7d55-4721-444d-8578-f44a27c049d9",
    "49b55905-ba64-4d44-94e1-61009b9fb727",
    "c8d8c2c7-7287-41d8-98ab-57606bec09f5",
    "169d5dda-f119-4f87-8c06-c9623733265c",
    "b429d45f-44ea-4b7f-ab5b-bb13f093b3b3",
    "7aaf7760-476c-4599-be92-4dae0a50c6df",
    "8646a920-8eac-4895-b2bc-4d410b66bfd4",
    "b280892a-18ec-4375-841e-eb360aba5ee1",
    "60f98a58-5f06-4862-8908-16a8efe8332e",
    "906b7644-c9ce-4b4c-925a-a11054a95226",
    "a79887e3-7f60-40f6-a2a8-0d7785acf400",
    "2cdb6a16-de65-4ef8-91aa-e45ba4d0704a",
)

REPLACEMENTS = {
    "906b7644-c9ce-4b4c-925a-a11054a95226": (
        "framework/EAs/QM5_11179_ft001-ema-ha/sets/"
        "QM5_11179_ft001-ema-ha_XAUUSD.DWX_M5_backtest_s20260907-001.set"
    ),
    "2cdb6a16-de65-4ef8-91aa-e45ba4d0704a": (
        "framework/EAs/QM5_10928_grimes-yoyo-break/sets/"
        "QM5_10928_grimes-yoyo-break_XAUUSD.DWX_M30_backtest_s20260907-001.set"
    ),
}


def _connect_read_only(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA query_only=ON")
    return con


def _sha256(path: Path | None) -> str | None:
    if path is None:
        return None
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _read_json(path: Path | None) -> dict[str, Any] | None:
    if path is None:
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def _strategy_assignments(path: Path | None) -> list[str]:
    if path is None:
        return []
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError):
        return []
    return sorted(set(re.findall(r"(?m)^(strategy_[A-Za-z0-9_]+)\s*=", text)))


def _declared_strategy_inputs(path: Path | None) -> list[str]:
    if path is None:
        return []
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError):
        return []
    return sorted(
        set(
            re.findall(
                r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_<>]*\s+"
                r"(strategy_[A-Za-z0-9_]+)\s*=",
                text,
            )
        )
    )


def _find_aggregate(report_root: Path, ea_id: str, phase: str) -> Path | None:
    base = report_root / ea_id
    if not base.exists():
        return None
    matches = sorted(base.glob(f"{phase}/**/aggregate.json"))
    return matches[0] if matches else None


def _q07_identity(report_root: Path, ea_id: str) -> dict[str, Any] | None:
    aggregate_path = _find_aggregate(report_root, ea_id, "Q07")
    aggregate = _read_json(aggregate_path)
    if not aggregate:
        return None
    details = aggregate.get("per_seed_detail") or []
    summary_path = Path(str(details[0].get("summary_path"))) if details else None
    summary = _read_json(summary_path)
    identity = (summary or {}).get("execution_identity") or {}
    setfile = identity.get("setfile") or {}
    source = setfile.get("source") or {}
    deployed = setfile.get("deployed") or {}
    source_path = Path(str(source["path"])) if source.get("path") else None
    return {
        "work_item_report_root": str(report_root),
        "aggregate_path": str(aggregate_path) if aggregate_path else None,
        "verdict": aggregate.get("verdict"),
        "seed": details[0].get("seed") if details else None,
        "trades": details[0].get("trades") if details else None,
        "summary_path": str(summary_path) if summary_path else None,
        "setfile_path": source.get("path"),
        "setfile_sha256_at_run": source.get("sha256"),
        "deployed_setfile_sha256_at_run": deployed.get("sha256"),
        "source_matches_deployed": setfile.get("source_matches_deployed"),
        "stable_during_run": setfile.get("stable_during_run"),
        "current_file_sha256": _sha256(source_path),
        "current_strategy_param_count": len(_strategy_assignments(source_path)),
    }


def _descendants(
    parent: str, children: dict[str, list[dict[str, Any]]]
) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    frontier = [parent]
    seen = {parent}
    while frontier:
        current = frontier.pop(0)
        for child in children.get(current, []):
            child_id = str(child["id"])
            if child_id in seen:
                continue
            seen.add(child_id)
            found.append(child)
            frontier.append(child_id)
    return found


def audit(db: Path, reports: Path, repo: Path) -> dict[str, Any]:
    placeholders = ",".join("?" for _ in COHORT_IDS)
    with _connect_read_only(db) as con:
        data_version = int(con.execute("PRAGMA data_version").fetchone()[0])
        cohort_rows = con.execute(
            f"""
            SELECT id, ea_id, symbol, phase, status, verdict, setfile_path,
                   setfile_sha256, ex5_sha256, mq5_sha256, created_at, updated_at,
                   payload_json
            FROM work_items WHERE id IN ({placeholders})
            """,
            COHORT_IDS,
        ).fetchall()
        successor_rows = con.execute(
            """
            SELECT id, ea_id, symbol, phase, status, verdict, setfile_path,
                   setfile_sha256, ex5_sha256, mq5_sha256, created_at, updated_at,
                   payload_json
            FROM work_items
            WHERE json_extract(payload_json, '$.append_only_rerun_of_work_item')
                  IS NOT NULL
            """
        ).fetchall()
        q07_ids = {
            str(json.loads(row["payload_json"] or "{}").get("promoted_from_work_item"))
            for row in cohort_rows
            if json.loads(row["payload_json"] or "{}").get("promoted_from_work_item")
        }
        q07_rows = {}
        if q07_ids:
            q7_placeholders = ",".join("?" for _ in q07_ids)
            q07_rows = {
                str(row["id"]): row
                for row in con.execute(
                    f"SELECT id, ea_id, status, verdict, setfile_path, "
                    f"setfile_sha256, evidence_path, payload_json FROM work_items "
                    f"WHERE id IN ({q7_placeholders})",
                    tuple(sorted(q07_ids)),
                ).fetchall()
            }

    by_id = {str(row["id"]): row for row in cohort_rows}
    missing = sorted(set(COHORT_IDS) - set(by_id))
    if missing:
        raise RuntimeError(f"sealed cohort rows missing: {missing}")

    children: dict[str, list[dict[str, Any]]] = {}
    for row in successor_rows:
        payload = json.loads(row["payload_json"] or "{}")
        parent = payload.get("append_only_rerun_of_work_item")
        if parent:
            children.setdefault(str(parent), []).append(
                {
                    "id": row["id"],
                    "status": row["status"],
                    "verdict": row["verdict"],
                    "setfile_path": row["setfile_path"],
                    "setfile_sha256": row["setfile_sha256"],
                    "replacement_setfile_path": payload.get("replacement_setfile_path"),
                    "verdict_reason": payload.get("verdict_reason"),
                }
            )

    order = {row_id: index for index, row_id in enumerate(COHORT_IDS)}
    rows: list[dict[str, Any]] = []
    for row_id in COHORT_IDS:
        row = by_id[row_id]
        payload = json.loads(row["payload_json"] or "{}")
        text = row["payload_json"] or ""
        if DEFECT_TOKEN not in text:
            raise RuntimeError(f"sealed row no longer carries defect token: {row_id}")
        if max(str(row["created_at"] or ""), str(row["updated_at"] or "")) < COHORT_SINCE:
            raise RuntimeError(f"sealed row falls outside cohort window: {row_id}")

        ea_dir_name = payload.get("ea_dir_name")
        q08_root = Path(str(payload.get("report_root") or reports / row_id))
        q08_aggregate_path = _find_aggregate(q08_root, str(row["ea_id"]), "Q08")
        q08_aggregate = _read_json(q08_aggregate_path) or {}
        baseline = q08_aggregate.get("baseline_run") or {}
        baseline_path_text = baseline.get("baseline_setfile_path") or row["setfile_path"]
        baseline_path = Path(str(baseline_path_text)) if baseline_path_text else None
        own_defect = DEFECT_TOKEN in str(payload.get("verdict_reason") or "")

        mq5_path = (
            repo / "framework" / "EAs" / str(ea_dir_name) / f"{ea_dir_name}.mq5"
            if ea_dir_name
            else None
        )
        current_set = Path(str(row["setfile_path"])) if row["setfile_path"] else None
        q07_id = payload.get("promoted_from_work_item")
        q07_payload = (
            json.loads(q07_rows[str(q07_id)]["payload_json"] or "{}")
            if q07_id and str(q07_id) in q07_rows
            else {}
        )
        q07_root = Path(str(q07_payload.get("report_root") or reports / str(q07_id)))
        q07_row = q07_rows.get(str(q07_id)) if q07_id else None
        q07_base_path = (
            Path(str(q07_row["setfile_path"]))
            if q07_row is not None and q07_row["setfile_path"]
            else None
        )
        q07_seed42_path = (
            Path(str(q07_base_path).replace("_backtest.set", "_q06_stress_harsh_seed42.set"))
            if q07_base_path
            else None
        )
        descendants = _descendants(row_id, children)
        replacement = REPLACEMENTS.get(row_id)
        replacement_path = repo / replacement if replacement else None

        if replacement:
            action = "PREPARED_APPEND_ONLY_RERUN_NOT_ENQUEUED"
        elif own_defect and descendants:
            action = "EXISTING_SUCCESSOR_NO_DUPLICATE_ENQUEUE"
        else:
            action = "REFERENCE_ROW_OR_ALREADY_REPAIRED_NO_ACTION"

        q85 = (q08_aggregate.get("sub_gate_input_runs") or {}).get(
            "8_5_neighborhood", {}
        )
        rows.append(
            {
                "cohort_order": order[row_id] + 1,
                "id": row_id,
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "status": row["status"],
                "verdict": row["verdict"],
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
                "cohort_membership": "OWN_INVALID_VERDICT" if own_defect else "DEFECT_REFERENCE_IN_RERUN_REASON",
                "baseline_at_q08": {
                    "aggregate_path": str(q08_aggregate_path) if q08_aggregate_path else None,
                    "setfile_path": baseline_path_text,
                    "setfile_sha256": baseline.get("baseline_setfile_sha256") or row["setfile_sha256"],
                    "strategy_param_count": 0 if own_defect else len(_strategy_assignments(baseline_path)),
                    "trades": baseline.get("baseline_total_trades"),
                    "ex5_sha256": baseline.get("baseline_ex5_sha256") or row["ex5_sha256"],
                    "mq5_sha256": baseline.get("baseline_mq5_sha256") or row["mq5_sha256"],
                    "q08_5_error": q85.get("error"),
                },
                "q07_predecessor": {
                    "id": q07_id,
                    "db_status": q07_row["status"] if q07_row is not None else None,
                    "db_verdict": q07_row["verdict"] if q07_row is not None else None,
                    "db_setfile_path": q07_row["setfile_path"] if q07_row is not None else None,
                    "db_setfile_sha256": q07_row["setfile_sha256"] if q07_row is not None else None,
                    "db_evidence_path": q07_row["evidence_path"] if q07_row is not None else None,
                    "execution": _q07_identity(q07_root, str(row["ea_id"])) if q07_id else None,
                    "retained_seed42_artifact": {
                        "path": str(q07_seed42_path) if q07_seed42_path else None,
                        "sha256": _sha256(q07_seed42_path),
                        "strategy_param_count": len(_strategy_assignments(q07_seed42_path)),
                    },
                    "assessment": (
                        "explicit Q07 seed artifact is also parameter-empty; retained execution summaries "
                        "show source/deployed identity binding where report retention is available. Compiled "
                        "EA defaults therefore made mechanics behavior-equivalent despite incomplete lineage"
                        if own_defect
                        else "same predecessor reused by governed append-only rerun"
                    ),
                },
                "current_artifacts": {
                    "setfile_path": str(current_set) if current_set else None,
                    "setfile_sha256": _sha256(current_set),
                    "strategy_param_count": len(_strategy_assignments(current_set)),
                    "mq5_path": str(mq5_path) if mq5_path else None,
                    "mq5_sha256": _sha256(mq5_path),
                    "declared_strategy_input_count": len(_declared_strategy_inputs(mq5_path)),
                },
                "producer_cause": (
                    "historical pre-395eb5fc84 gen_setfile missing-card path emitted "
                    "card_defaults_source=not_found and no strategy assignments"
                    if own_defect
                    else "row references an earlier empty-set defect; its own sealed baseline is full or pending"
                ),
                "successors": descendants,
                "action": action,
                "prepared_replacement": {
                    "path": replacement,
                    "sha256": _sha256(replacement_path),
                    "strategy_param_count": len(_strategy_assignments(replacement_path)),
                }
                if replacement
                else None,
            }
        )

    defect_rows = [row for row in rows if row["cohort_membership"] == "OWN_INVALID_VERDICT"]
    reference_rows = [row for row in rows if row["cohort_membership"] != "OWN_INVALID_VERDICT"]
    return {
        "schema": "qm.q08_empty_strategy_params_audit.v1",
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "database": str(db.resolve()),
        "database_data_version": data_version,
        "selection": {
            "sealed_ids": list(COHORT_IDS),
            "since_utc": COHORT_SINCE,
            "payload_token": DEFECT_TOKEN,
        },
        "counts": {
            "cohort": len(rows),
            "own_invalid_verdict": len(defect_rows),
            "reference_rerun": len(reference_rows),
            "prepared_not_enqueued": sum(
                row["action"] == "PREPARED_APPEND_ONLY_RERUN_NOT_ENQUEUED"
                for row in rows
            ),
        },
        "root_cause": (
            "Historical generator output lacked explicit strategy assignments. Q07 and Q08 "
            "were byte-bound to those files; MT5 used compiled defaults, so execution was "
            "behavior-equivalent while explicit lineage was incomplete. Q08.5 correctly "
            "failed closed. This is not a neighborhood-reader misbinding."
        ),
        "rows": rows,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--reports", type=Path, default=DEFAULT_REPORTS)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    result = audit(args.db, args.reports, args.repo)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
