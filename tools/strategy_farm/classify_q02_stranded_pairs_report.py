"""Build a read-only classification packet for exhausted Q02/P2 pairs.

The cohort predicate is intentionally identical to
``health.chk_q02_stranded_exhausted_pairs``.  This tool reads one SQLite
snapshot plus row-bound evidence and writes JSON/CSV analysis artifacts.  It
never mutates farm state or enqueues work.
"""
from __future__ import annotations

import argparse
import collections
import csv
import datetime as dt
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_STEM = "2026-07-31_q02_stranded_pairs_classification"
RETRY_CAP = 12
REQUIRED_HEADERS = {
    "ea_id",
    "ea_slug",
    "ea_version",
    "set_version",
    "symbol",
    "timeframe",
    "environment",
    "magic_slot",
    "risk_mode",
    "portfolio_weight",
    "build_hash",
    "author",
    "date",
}
COHORT_SQL = """
SELECT ea_id, symbol
FROM work_items
WHERE phase IN ('Q02','P2')
GROUP BY ea_id, symbol
HAVING SUM(
           CASE
             WHEN status IN ('done','failed')
              AND verdict IS NOT NULL
              AND TRIM(verdict) <> ''
              AND UPPER(verdict) <> 'INFRA_FAIL'
             THEN 1 ELSE 0
           END
       ) = 0
   AND SUM(CASE WHEN status IN ('pending','active') THEN 1 ELSE 0 END) = 0
   AND SUM(CASE WHEN UPPER(verdict) = 'INFRA_FAIL' THEN 1 ELSE 0 END) >= 12
""".strip()


def sha256_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError:
        return None
    return digest.hexdigest()


def json_obj(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(raw or "{}")
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def ea_number(ea_id: str) -> int:
    match = re.search(r"(\d+)(?!.*\d)", ea_id)
    return int(match.group(1)) if match else 10**12


def setfile_audit(path_text: str) -> dict[str, Any]:
    path = Path(path_text)
    result: dict[str, Any] = {
        "path": str(path),
        "exists": path.is_file(),
        "sha256": sha256_file(path),
        "findings": [],
        "missing_headers": [],
        "duplicate_headers": {},
        "duplicate_inputs": {},
    }
    if not path.is_file():
        result["findings"] = ["SETFILE_MISSING"]
        return result

    headers: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    inputs: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    try:
        lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    except OSError:
        result["findings"] = ["SETFILE_UNREADABLE"]
        return result

    for line_number, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith((";", "#")):
            body = line.lstrip(";#").strip()
            if ":" in body:
                key, value = body.split(":", 1)
                headers[key.strip().casefold()].append(
                    {"line": line_number, "value": value.strip()}
                )
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            inputs[key.strip().casefold()].append(
                {"line": line_number, "value": value.strip()}
            )

    missing = sorted(REQUIRED_HEADERS - set(headers))
    if missing:
        result["findings"].append("SETFILE_HEADER_INCOMPLETE")
        result["missing_headers"] = missing

    for label, values, destination in (
        ("HEADER", headers, "duplicate_headers"),
        ("INPUT", inputs, "duplicate_inputs"),
    ):
        duplicates = {key: rows for key, rows in values.items() if len(rows) > 1}
        result[destination] = duplicates
        if any(
            len({row["value"] for row in rows}) == 1
            for rows in duplicates.values()
        ):
            result["findings"].append(f"SETFILE_{label}_DUPLICATE_IDENTICAL")
        if any(
            len({row["value"] for row in rows}) > 1
            for rows in duplicates.values()
        ):
            result["findings"].append(f"SETFILE_{label}_DUPLICATE_CONFLICT")

    result["findings"] = sorted(set(result["findings"]))
    return result


def summary_info(row: dict[str, Any]) -> dict[str, Any] | None:
    raw_path = row.get("evidence_path")
    if not raw_path:
        return None
    path = Path(str(raw_path))
    if path.name.casefold() != "summary.json" or not path.is_file():
        return None
    try:
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {"path": str(path), "sha256": sha256_file(path), "parse_error": True}
    if not isinstance(summary, dict):
        return {"path": str(path), "sha256": sha256_file(path), "parse_error": True}

    runs = [run for run in (summary.get("runs") or []) if isinstance(run, dict)]
    statuses = [str(run.get("status") or "").upper() for run in runs]
    trades = sum(int(run.get("total_trades") or 0) for run in runs)
    result = str(summary.get("result") or "").upper()
    reason_classes = [
        str(value).upper() for value in (summary.get("reason_classes") or [])
    ]
    payload = row["payload"]
    identity = summary.get("execution_identity") or {}
    expert = identity.get("expert_binary") or {}
    setfile = identity.get("setfile") or {}

    checks = {
        "ea_matches": (
            str(summary.get("ea_label") or f"QM5_{summary.get('ea_id')}")
            == row["ea_id"]
        ),
        "symbol_matches": str(summary.get("symbol") or "") == row["symbol"],
        "all_runs_ok": bool(runs) and all(status == "OK" for status in statuses),
        "news_calendar_ok": (
            str((summary.get("news_calendar") or {}).get("status") or "").upper()
            == "OK"
        ),
        "execution_stable": identity.get("stable_during_run") is True,
        "expert_source_matches_deployed": expert.get("source_matches_deployed") is True,
        "setfile_source_matches_deployed": setfile.get("source_matches_deployed") is True,
        "expected_ex5_matches": (
            not payload.get("expected_ex5_sha256")
            or str((expert.get("source") or {}).get("sha256") or "").casefold()
            == str(payload.get("expected_ex5_sha256") or "").casefold()
        ),
        "expected_setfile_matches": (
            not payload.get("expected_setfile_sha256")
            or str((setfile.get("source") or {}).get("sha256") or "").casefold()
            == str(payload.get("expected_setfile_sha256") or "").casefold()
        ),
        "expected_from_matches": (
            not payload.get("expected_from_date")
            or summary.get("from_date") == payload.get("expected_from_date")
        ),
        "expected_to_matches": (
            not payload.get("expected_to_date")
            or summary.get("to_date") == payload.get("expected_to_date")
        ),
    }

    aggregate_type = None
    if (
        result == "FAIL"
        and bool(runs)
        and all(status == "OK" for status in statuses)
        and trades == 0
        and "MIN_TRADES_NOT_MET" in reason_classes
    ):
        aggregate_type = "ZERO_TRADES"
    elif (
        result == "PASS"
        and bool(runs)
        and all(status == "OK" for status in statuses)
        and trades > 0
        and reason_classes == ["OK"]
    ):
        aggregate_type = "POSITIVE_PASS"

    zero_identity_valid = bool(
        aggregate_type == "ZERO_TRADES" and all(checks.values())
    )
    news = summary.get("news_calendar") or {}
    try:
        calendar_age = float(news.get("age_hours"))
    except (TypeError, ValueError):
        calendar_age = None

    return {
        "path": str(path),
        "sha256": sha256_file(path),
        "parse_error": False,
        "schema": summary.get("evidence_schema"),
        "result": result,
        "reason_classes": reason_classes,
        "run_statuses": statuses,
        "total_trades": trades,
        "aggregate_type": aggregate_type,
        "zero_identity_valid": zero_identity_valid,
        "identity_checks": checks,
        "news_calendar_status": news.get("status"),
        "news_calendar_age_hours": calendar_age,
    }


def direct_reason(row: dict[str, Any]) -> str | None:
    payload = row["payload"]
    parts: list[str] = []
    for field in ("verdict_reason", "final_failure"):
        if payload.get(field):
            parts.append(str(payload[field]))
    if isinstance(payload.get("reason_classes"), list):
        parts.extend(str(value) for value in payload["reason_classes"])
    if row.get("summary"):
        parts.extend(str(value) for value in row["summary"].get("reason_classes") or [])
    text = ";".join(parts).upper()
    if "NEWS_CALENDAR" in text or "CALENDAR_STALE" in text:
        return "CALENDAR_HARD"
    if "SETFILE_MISSING" in text:
        return "SETFILE_MISSING"
    if "SHARED_BASES" in text or "LOCK_STORM" in text:
        return "SHARED_BASES_LOCK_STORM"
    if "LOG_BOMB" in text:
        return "LOG_BOMB"
    if "ACTIVE_TIMEOUT" in text:
        return "ACTIVE_TIMEOUT"
    if "NO_HISTORY" in text:
        return "NO_HISTORY_TRANSIENT"
    if "NO_REAL_TICKS" in text:
        return "NO_REAL_TICKS"
    if "BARS_ZERO" in text:
        return "BARS_ZERO"
    if "ONINIT" in text:
        return "ONINIT_FAILED"
    if "TIMEOUT" in text or "METATESTER_HUNG" in text:
        return "TIMEOUT_METATESTER_HUNG"
    if "REPORT_MISSING" in text:
        return "REPORT_MISSING"
    return None


def row_reason(row: dict[str, Any]) -> str:
    payload = row["payload"]
    return str(
        payload.get("verdict_reason")
        or payload.get("final_failure")
        or payload.get("prior_failure")
        or "MISSING_REASON"
    )


def load_registry(path: Path) -> dict[str, dict[str, str]]:
    registry: dict[str, dict[str, str]] = {}
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for record in csv.DictReader(handle):
            raw = str(record.get("ea_id") or "").strip()
            match = re.fullmatch(r"(?:QM5_)?(\d+)", raw)
            if match:
                registry[f"QM5_{int(match.group(1))}"] = record
    return registry


def read_snapshot(db_path: Path) -> tuple[list[tuple[str, str]], list[dict[str, Any]], dict[str, Any]]:
    uri = f"file:{db_path.as_posix()}?mode=ro"
    con = sqlite3.connect(uri, uri=True)
    con.row_factory = sqlite3.Row
    con.execute("BEGIN")
    metadata = {
        "sqlite_data_version": int(con.execute("PRAGMA data_version").fetchone()[0]),
        "sqlite_schema_version": int(con.execute("PRAGMA schema_version").fetchone()[0]),
    }
    cohort_pairs = [
        (str(row["ea_id"]), str(row["symbol"])) for row in con.execute(COHORT_SQL)
    ]
    rows = [
        dict(row)
        for row in con.execute(
            f"""
            WITH cohort AS ({COHORT_SQL})
            SELECT wi.*
            FROM work_items wi
            JOIN cohort c USING (ea_id, symbol)
            WHERE wi.phase IN ('Q02','P2')
            ORDER BY wi.ea_id, wi.symbol, wi.updated_at, wi.id
            """
        )
    ]
    con.commit()
    con.close()
    return cohort_pairs, rows, metadata


def build_records(
    rows: list[dict[str, Any]],
    registry: dict[str, dict[str, str]],
) -> tuple[list[dict[str, Any]], collections.Counter[str]]:
    by_pair: dict[tuple[str, str], list[dict[str, Any]]] = collections.defaultdict(list)
    row_reason_counts: collections.Counter[str] = collections.Counter()
    for row in rows:
        row["payload"] = json_obj(row.get("payload_json"))
        row["summary"] = summary_info(row)
        by_pair[(str(row["ea_id"]), str(row["symbol"]))].append(row)
        if str(row.get("verdict") or "").upper() == "INFRA_FAIL":
            row_reason_counts[row_reason(row)] += 1

    records: list[dict[str, Any]] = []
    for pair in sorted(by_pair, key=lambda key: (ea_number(key[0]), key[1])):
        pair_rows = by_pair[pair]
        latest = pair_rows[-1]
        set_audit = setfile_audit(str(latest["setfile_path"]))
        valid_zero_rows = [
            row
            for row in pair_rows
            if row.get("summary") and row["summary"].get("zero_identity_valid")
        ]
        positive_pass_rows = [
            row
            for row in pair_rows
            if row.get("summary")
            and row["summary"].get("aggregate_type") == "POSITIVE_PASS"
        ]

        source = latest
        if valid_zero_rows:
            classification = "VALID_ZERO_TRADES"
            primary_cause = "VALID_ZERO_TRADES"
            source = valid_zero_rows[-1]
            proposed_action = "RETIRE_DRAFT_AFTER_CLAUDE_REVIEW"
            note = (
                "Identity-valid row-bound aggregate: completed OK run, zero trades, "
                "MIN_TRADES_NOT_MET."
            )
        elif "SETFILE_MISSING" in set_audit["findings"]:
            classification = "INVALID_EVIDENCE_DEFECT"
            primary_cause = "SETFILE_MISSING"
            proposed_action = "REPAIR_SETFILE_BEFORE_ANY_CANARY"
            note = "Latest bound setfile path is absent on the canonical checkout."
        elif positive_pass_rows:
            classification = "INVALID_EVIDENCE_DEFECT"
            primary_cause = "ROW_BOUND_PASS_DISPOSITION_MISMATCH"
            source = positive_pass_rows[-1]
            proposed_action = "REVIEW_DISPOSITION_REPAIR_NO_RERUN"
            note = (
                "Row-bound aggregate says PASS/OK with positive trades while the "
                "database row remains INFRA_FAIL."
            )
        elif set_audit["findings"]:
            classification = "INVALID_EVIDENCE_DEFECT"
            primary_cause = set_audit["findings"][0]
            proposed_action = "REPAIR_SETFILE_EVIDENCE_BEFORE_ANY_CANARY"
            note = "Current bound setfile fails the static header/duplicate audit."
        else:
            informative = [
                (row, direct_reason(row))
                for row in reversed(pair_rows)
                if direct_reason(row)
            ]
            if informative:
                source, primary_cause = informative[0]
                classification = "INVALID_EVIDENCE_DEFECT"
                proposed_action = "REPAIR_OR_PREFLIGHT_THEN_GOVERNED_CANARY"
                note = (
                    "Most recent row carrying a specific failure signature supplies "
                    "the primary cause."
                )
            else:
                classification = "UNCLEAR"
                primary_cause = "SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE"
                proposed_action = "FORENSIC_REVIEW_NO_REQUEUE"
                note = (
                    "Only generic summary-missing history remains; no readable "
                    "row-bound aggregate or specific failure signature."
                )

        summaries = [
            row["summary"]
            for row in pair_rows
            if row.get("summary") and not row["summary"].get("parse_error")
        ]
        calendar_hard_count = sum(
            1
            for summary in summaries
            if str(summary.get("news_calendar_status") or "").upper() != "OK"
            or (
                summary.get("news_calendar_age_hours") is not None
                and float(summary["news_calendar_age_hours"]) > 336
            )
        )
        historical_lock_storm = any(
            "SHARED_BASES" in json.dumps(row["payload"], sort_keys=True).upper()
            or "LOCK_STORM" in json.dumps(row["payload"], sort_keys=True).upper()
            for row in pair_rows
        )
        source_summary = source.get("summary") or {}
        valid_aggregate_row = valid_zero_rows[-1] if valid_zero_rows else (
            positive_pass_rows[-1] if positive_pass_rows else None
        )
        valid_summary = (valid_aggregate_row or {}).get("summary") or {}
        ea_dir = Path(str(latest["setfile_path"])).parent.parent
        ex5_paths = (
            sorted(str(path) for path in ea_dir.glob("*.ex5"))
            if ea_dir.is_dir()
            else []
        )
        reg = registry.get(pair[0], {})

        records.append(
            {
                "ea_id": pair[0],
                "symbol": pair[1],
                "classification": classification,
                "primary_cause": primary_cause,
                "infra_row_count": sum(
                    1
                    for row in pair_rows
                    if str(row.get("verdict") or "").upper() == "INFRA_FAIL"
                ),
                "total_q02_p2_rows": len(pair_rows),
                "open_row_count": sum(
                    1
                    for row in pair_rows
                    if str(row.get("status") or "").lower() in {"pending", "active"}
                ),
                "noninfra_terminal_count": sum(
                    1
                    for row in pair_rows
                    if str(row.get("status") or "").lower() in {"done", "failed"}
                    and str(row.get("verdict") or "").strip()
                    and str(row.get("verdict") or "").upper() != "INFRA_FAIL"
                ),
                "latest_work_item_id": latest["id"],
                "latest_updated_at": latest["updated_at"],
                "source_work_item_id": source["id"],
                "source_updated_at": source["updated_at"],
                "source_status": source["status"],
                "source_attempt_count": source["attempt_count"],
                "source_verdict_reason": source["payload"].get("verdict_reason"),
                "source_final_failure": source["payload"].get("final_failure"),
                "source_evidence_path": source.get("evidence_path"),
                "source_evidence_exists": bool(
                    source.get("evidence_path")
                    and Path(str(source["evidence_path"])).is_file()
                ),
                "source_evidence_sha256": (
                    sha256_file(Path(str(source["evidence_path"])))
                    if source.get("evidence_path")
                    else None
                ),
                "source_log_path": source["payload"].get("log_path"),
                "source_log_exists": bool(
                    source["payload"].get("log_path")
                    and Path(str(source["payload"]["log_path"])).is_file()
                ),
                "source_report_root": source["payload"].get("report_root"),
                "source_aggregate_result": source_summary.get("result"),
                "source_aggregate_reason_classes": (
                    source_summary.get("reason_classes") or []
                ),
                "source_aggregate_total_trades": source_summary.get("total_trades"),
                "valid_aggregate_work_item_id": (
                    valid_aggregate_row["id"] if valid_aggregate_row else None
                ),
                "valid_aggregate_path": valid_summary.get("path"),
                "valid_aggregate_sha256": valid_summary.get("sha256"),
                "valid_aggregate_type": valid_summary.get("aggregate_type"),
                "valid_aggregate_total_trades": valid_summary.get("total_trades"),
                "valid_zero_identity_checks": (
                    valid_summary.get("identity_checks") if valid_zero_rows else None
                ),
                "row_bound_summary_count": len(summaries),
                "calendar_hard_summary_count": calendar_hard_count,
                "historical_lock_storm": historical_lock_storm,
                "latest_setfile_path": set_audit["path"],
                "latest_setfile_exists": set_audit["exists"],
                "latest_setfile_sha256": set_audit["sha256"],
                "setfile_findings": set_audit["findings"],
                "setfile_missing_headers": set_audit["missing_headers"],
                "setfile_duplicate_headers": set_audit["duplicate_headers"],
                "setfile_duplicate_inputs": set_audit["duplicate_inputs"],
                "registry_status": reg.get("status"),
                "registry_slug": reg.get("slug"),
                "canonical_ex5_paths": ex5_paths,
                "proposed_action": proposed_action,
                "classification_note": note,
                "canary_selected": False,
            }
        )
    return records, row_reason_counts


def add_canary_proposal(
    records: list[dict[str, Any]],
    cause_counts: collections.Counter[str],
) -> list[dict[str, Any]]:
    top_causes = [
        "ONINIT_FAILED",
        "ACTIVE_TIMEOUT",
        "BARS_ZERO",
        "NO_HISTORY_TRANSIENT",
        "LOG_BOMB",
    ]
    controls = {
        "ONINIT_FAILED": {
            "expected": (
                "One identity-bound terminal Q02 disposition: PASS, "
                "MIN_TRADES_NOT_MET, or deterministic INVALID with an attributable "
                "init event; never another generic INFRA label."
            ),
            "abort": (
                "Stop the cause group after the first recurrent ONINIT_FAILED lacking "
                "a row-bound init event, or any EX5/setfile/calendar identity mismatch."
            ),
            "precondition": (
                "Explain or repair the exact init failure first; revalidate current "
                "EX5, setfile and calendar hashes."
            ),
        },
        "ACTIVE_TIMEOUT": {
            "expected": (
                "The progress-aware reaper permits completion, or records a justified "
                "no-progress/absolute-ceiling stop with bound progress evidence."
            ),
            "abort": (
                "Stop after any reap while forward progress is present, any reap "
                "without progress evidence, or any vanished terminal disposition."
            ),
            "precondition": (
                "Confirm the progress-aware reaper commit is deployed and the row is "
                "mechanically eligible."
            ),
        },
        "BARS_ZERO": {
            "expected": (
                "Cold-cache handling produces nonzero bars and a valid terminal report, "
                "or a deterministic INVALID history diagnosis."
            ),
            "abort": (
                "Stop after the first recurrent BARS_ZERO following successful "
                "symbol/date coverage preflight; do not fan out to another terminal."
            ),
            "precondition": (
                "Read-only symbol/date coverage and cache preflight must pass on the "
                "assigned terminal."
            ),
        },
        "NO_HISTORY_TRANSIENT": {
            "expected": (
                "The requested date range is available and the run reaches a valid "
                "terminal report without NO_HISTORY."
            ),
            "abort": (
                "Stop after the first recurrent NO_HISTORY/BARS_ZERO after coverage "
                "preflight, or evidence that the requested range is unavailable."
            ),
            "precondition": (
                "Read-only history-range validation must cover the exact requested "
                "window; no history re-import is authorized."
            ),
        },
        "LOG_BOMB": {
            "expected": (
                "A repaired EA produces a bounded journal and a valid terminal report "
                "without LOG_BOMB."
            ),
            "abort": (
                "Kill the single canary at the configured log-bomb guard and stop the "
                "cause group on the first LOG_BOMB signature or unbounded journal growth."
            ),
            "precondition": (
                "Code/logging repair and focused regression proof first. Never flip the "
                "poison source row; create one governed successor referencing it."
            ),
        },
    }

    groups: list[dict[str, Any]] = []
    for cause in top_causes:
        candidates = [
            record
            for record in records
            if record["primary_cause"] == cause
            and record["source_work_item_id"] == record["latest_work_item_id"]
            and str(record.get("registry_status") or "").casefold() == "active"
            and record["latest_setfile_exists"]
            and bool(record["canonical_ex5_paths"])
            and record["source_evidence_exists"]
            and int(record["source_attempt_count"] or 0) < RETRY_CAP
        ]
        candidates.sort(
            key=lambda record: (
                str(record["source_updated_at"]),
                ea_number(record["ea_id"]),
                record["symbol"],
            ),
            reverse=True,
        )
        selected: list[dict[str, Any]] = []
        used_eas: set[str] = set()
        for candidate in candidates:
            if candidate["ea_id"] in used_eas:
                continue
            selected.append(candidate)
            used_eas.add(candidate["ea_id"])
            if len(selected) == 2:
                break
        for sequence, candidate in enumerate(selected, 1):
            candidate["canary_selected"] = True
            candidate["canary_group"] = cause
            candidate["canary_sequence"] = sequence
            candidate["canary_execution_mode"] = (
                "NEW_GOVERNED_SUCCESSOR_AFTER_REPAIR"
                if cause == "LOG_BOMB"
                else "GOVERNED_SINGLE_ROW_REQUEUE_AFTER_REVIEW"
            )
        groups.append(
            {
                "cause": cause,
                "cohort_pair_count": cause_counts[cause],
                "release_policy": (
                    "Sequential: row 2 remains unqueued until row 1 has a reviewed "
                    "terminal disposition."
                ),
                **controls[cause],
                "candidates": [
                    {
                        "sequence": index + 1,
                        "ea_id": candidate["ea_id"],
                        "symbol": candidate["symbol"],
                        "target_work_item_id": candidate["latest_work_item_id"],
                        "diagnostic_source_work_item_id": candidate[
                            "source_work_item_id"
                        ],
                        "evidence_path": candidate["source_evidence_path"],
                        "setfile_path": candidate["latest_setfile_path"],
                        "execution_mode": (
                            "NEW_GOVERNED_SUCCESSOR_AFTER_REPAIR"
                            if cause == "LOG_BOMB"
                            else "GOVERNED_SINGLE_ROW_REQUEUE_AFTER_REVIEW"
                        ),
                    }
                    for index, candidate in enumerate(selected)
                ],
            }
        )
    return groups


def write_csv(records: list[dict[str, Any]], path: Path) -> None:
    columns = [
        "ea_id",
        "symbol",
        "classification",
        "primary_cause",
        "infra_row_count",
        "total_q02_p2_rows",
        "open_row_count",
        "noninfra_terminal_count",
        "latest_work_item_id",
        "latest_updated_at",
        "source_work_item_id",
        "source_updated_at",
        "source_status",
        "source_attempt_count",
        "source_verdict_reason",
        "source_final_failure",
        "source_evidence_path",
        "source_evidence_exists",
        "source_evidence_sha256",
        "source_log_path",
        "source_log_exists",
        "source_report_root",
        "source_aggregate_result",
        "source_aggregate_reason_classes",
        "source_aggregate_total_trades",
        "valid_aggregate_work_item_id",
        "valid_aggregate_path",
        "valid_aggregate_sha256",
        "valid_aggregate_type",
        "valid_aggregate_total_trades",
        "row_bound_summary_count",
        "calendar_hard_summary_count",
        "historical_lock_storm",
        "latest_setfile_path",
        "latest_setfile_exists",
        "latest_setfile_sha256",
        "setfile_findings",
        "setfile_missing_headers",
        "registry_status",
        "registry_slug",
        "canonical_ex5_paths",
        "proposed_action",
        "canary_selected",
        "canary_group",
        "canary_sequence",
        "canary_execution_mode",
        "classification_note",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for record in records:
            flat = dict(record)
            for field in (
                "source_aggregate_reason_classes",
                "setfile_findings",
                "setfile_missing_headers",
                "canonical_ex5_paths",
            ):
                flat[field] = "|".join(str(value) for value in (flat.get(field) or []))
            writer.writerow(flat)


def build_report(db_path: Path, repo: Path, output_dir: Path, stem: str) -> dict[str, Any]:
    registry_path = repo / "framework" / "registry" / "ea_id_registry.csv"
    registry = load_registry(registry_path)
    cohort_pairs, rows, snapshot_meta = read_snapshot(db_path)
    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    records, row_reason_counts = build_records(rows, registry)
    class_counts = collections.Counter(record["classification"] for record in records)
    cause_counts = collections.Counter(record["primary_cause"] for record in records)
    canary_groups = add_canary_proposal(records, cause_counts)
    top_canary_count = sum(
        cause_counts[cause]
        for cause in (
            "ONINIT_FAILED",
            "ACTIVE_TIMEOUT",
            "BARS_ZERO",
            "NO_HISTORY_TRANSIENT",
            "LOG_BOMB",
        )
    )
    defect_count = class_counts["INVALID_EVIDENCE_DEFECT"]

    retire_draft = [
        {
            "ea_id": record["ea_id"],
            "symbol": record["symbol"],
            "work_item_id": record["valid_aggregate_work_item_id"],
            "aggregate_path": record["valid_aggregate_path"],
            "aggregate_sha256": record["valid_aggregate_sha256"],
            "trades": record["valid_aggregate_total_trades"],
            "action": "RETIRE_CANDIDATE_ONLY",
        }
        for record in records
        if record["classification"] == "VALID_ZERO_TRADES"
    ]
    overlay_counts = {
        "latest_setfile_missing_pairs": sum(
            "SETFILE_MISSING" in record["setfile_findings"] for record in records
        ),
        "latest_setfile_header_incomplete_pairs": sum(
            "SETFILE_HEADER_INCOMPLETE" in record["setfile_findings"]
            for record in records
        ),
        "latest_setfile_duplicate_identical_pairs": sum(
            any("DUPLICATE_IDENTICAL" in finding for finding in record["setfile_findings"])
            for record in records
        ),
        "latest_setfile_duplicate_conflict_pairs": sum(
            any("DUPLICATE_CONFLICT" in finding for finding in record["setfile_findings"])
            for record in records
        ),
        "historical_lock_storm_pairs": sum(
            record["historical_lock_storm"] for record in records
        ),
        "readable_row_bound_summaries": sum(
            record["row_bound_summary_count"] for record in records
        ),
        "calendar_hard_summaries": sum(
            record["calendar_hard_summary_count"] for record in records
        ),
    }
    row_signature_material = [
        {
            key: row.get(key)
            for key in (
                "id",
                "phase",
                "ea_id",
                "symbol",
                "setfile_path",
                "status",
                "verdict",
                "attempt_count",
                "evidence_path",
                "payload_json",
                "created_at",
                "updated_at",
            )
        }
        for row in rows
    ]
    row_signature = hashlib.sha256(
        json.dumps(
            row_signature_material,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        ).encode("utf-8")
    ).hexdigest()

    examples_by_class: dict[str, list[dict[str, Any]]] = {}
    for classification in (
        "VALID_ZERO_TRADES",
        "INVALID_EVIDENCE_DEFECT",
        "UNCLEAR",
    ):
        members = [
            record for record in records if record["classification"] == classification
        ]
        if classification == "INVALID_EVIDENCE_DEFECT":
            chosen: list[dict[str, Any]] = []
            for cause in ("ONINIT_FAILED", "ACTIVE_TIMEOUT", "BARS_ZERO"):
                match = next(
                    (
                        record
                        for record in members
                        if record["primary_cause"] == cause
                        and record["source_evidence_exists"]
                    ),
                    None,
                )
                if match:
                    chosen.append(match)
        else:
            chosen = members[:3]
        examples_by_class[classification] = [
            {
                "ea_id": record["ea_id"],
                "symbol": record["symbol"],
                "primary_cause": record["primary_cause"],
                "work_item_id": record["source_work_item_id"],
                "aggregate_or_evidence_path": record["source_evidence_path"],
                "valid_aggregate_path": record["valid_aggregate_path"],
                "fallback_log_path": record["source_log_path"],
                "report_root": record["source_report_root"],
            }
            for record in chosen
        ]

    document = {
        "schema": "qm.q02_stranded_pairs_classification.v1",
        "generated_at_utc": generated_at,
        "mode": "READ_ONLY_ANALYSIS_AND_PROPOSAL_ONLY",
        "task_id": "5589f742-8071-4aed-942a-2773b90df27f",
        "source": {
            "database": str(db_path),
            **snapshot_meta,
            "cohort_sql": COHORT_SQL,
            "retry_cap": RETRY_CAP,
            "cohort_pair_count": len(cohort_pairs),
            "cohort_work_item_count": len(rows),
            "cohort_rows_sha256": row_signature,
            "read_completed_at_utc": generated_at,
            "registry_path": str(registry_path),
            "registry_sha256": sha256_file(registry_path),
        },
        "classification_contract": {
            "precedence": [
                "identity-valid completed zero-trade aggregate => VALID_ZERO_TRADES",
                "current setfile absent => INVALID_EVIDENCE_DEFECT/SETFILE_MISSING",
                "row-bound PASS/OK positive-trade aggregate stored as INFRA => disposition mismatch",
                "current setfile header/duplicate defect => INVALID_EVIDENCE_DEFECT",
                "most recent row with a specific direct verdict/final/aggregate reason => INVALID_EVIDENCE_DEFECT",
                "otherwise => UNCLEAR",
            ],
            "zero_trade_identity_requirement": (
                "All identity checks in valid_zero_identity_checks must be true."
            ),
            "generic_summary_missing_policy": (
                "Generic summary_missing labels alone are not promoted to a causal defect."
            ),
            "setfile_duplicate_policy": (
                "Comments are excluded; case-insensitive duplicate header and input keys "
                "are split into identical and conflicting value classes."
            ),
        },
        "summary": {
            "classification_counts": dict(sorted(class_counts.items())),
            "primary_cause_counts": dict(
                sorted(cause_counts.items(), key=lambda item: (-item[1], item[0]))
            ),
            "overlay_counts": overlay_counts,
            "row_level_reason_counts": dict(
                sorted(row_reason_counts.items(), key=lambda item: (-item[1], item[0]))
            ),
        },
        "examples_by_class": examples_by_class,
        "retire_draft": retire_draft,
        "governed_canary_proposal": {
            "status": "PROPOSAL_ONLY_NOT_AUTHORIZED_NOT_EXECUTED",
            "top_cause_definition": (
                "Five largest actionable runtime/evidence primary causes; "
                f"{top_canary_count}/{defect_count} defect pairs "
                f"({100.0 * top_canary_count / defect_count:.1f}%)."
            ),
            "total_candidate_rows": sum(
                len(group["candidates"]) for group in canary_groups
            ),
            "global_preconditions": [
                "Claude review of this classification and the exact candidate list.",
                "OWNER authorization for the bounded sequential canary.",
                "Immediate read-only revalidation: target row still terminal INFRA_FAIL; pair has no pending/active successor or non-infra disposition.",
                "Canonical EX5 and setfile exist and hashes match row-bound expectations.",
                "News calendar source and FILE_COMMON copies are fresh and identical; qm_news_stale_max_hours remains <=336.",
                "Backtest setfile uses RISK_FIXED > 0 and RISK_PERCENT = 0.",
                "No active T1-T10 backtest is interrupted.",
            ],
            "global_abort": (
                "On any identity mismatch, live successor, recurrent unexplained "
                "infrastructure signature, or missing terminal evidence: stop; enqueue "
                "nothing else."
            ),
            "groups": canary_groups,
        },
        "no_candidate_categories": {
            "CALENDAR_HARD": (
                f"{overlay_counts['calendar_hard_summaries']} directly evidenced "
                "calendar-hard summaries across "
                f"{overlay_counts['readable_row_bound_summaries']} readable "
                "row-bound summaries; no candidate is proposed without a qualifying pair."
            ),
            "SETFILE_DUPLICATE": (
                f"{overlay_counts['latest_setfile_duplicate_identical_pairs'] + overlay_counts['latest_setfile_duplicate_conflict_pairs']} "
                "current cohort pairs with identical/conflicting duplicate header or "
                "input keys; repair the setfile before any canary."
            ),
            "SETFILE_HEADER_INCOMPLETE": (
                f"{cause_counts['SETFILE_HEADER_INCOMPLETE']} pairs; repair evidence "
                "headers before considering a run."
            ),
            "SETFILE_MISSING": (
                f"{cause_counts['SETFILE_MISSING']} pairs; restore/regenerate a "
                "canonical setfile before considering a run."
            ),
            "ROW_BOUND_PASS_DISPOSITION_MISMATCH": (
                f"{cause_counts['ROW_BOUND_PASS_DISPOSITION_MISMATCH']} pairs; review "
                "a guarded disposition repair, not a rerun."
            ),
            "UNCLEAR": (
                f"{class_counts['UNCLEAR']} pairs; forensic recovery of logs/aggregates "
                "first, no blind requeue."
            ),
        },
        "records": records,
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / f"{stem}.json"
    csv_path = output_dir / f"{stem}.csv"
    json_path.write_text(
        json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    write_csv(records, csv_path)
    return {
        "csv": str(csv_path),
        "csv_sha256": sha256_file(csv_path),
        "json": str(json_path),
        "json_sha256": sha256_file(json_path),
        "generated_at_utc": generated_at,
        "cohort_pairs": len(cohort_pairs),
        "cohort_rows": len(rows),
        "classification_counts": dict(class_counts),
        "cause_counts": dict(cause_counts),
        "overlay_counts": overlay_counts,
        "canary_rows": sum(len(group["candidates"]) for group in canary_groups),
        "retire_rows": len(retire_draft),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--stem", default=DEFAULT_STEM)
    args = parser.parse_args()
    output_dir = args.output_dir or args.repo / "docs" / "ops" / "evidence"
    result = build_report(args.db, args.repo, output_dir, args.stem)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
