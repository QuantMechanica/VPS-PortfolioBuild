from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import reclassify_compile_profile_failures as reclassify


def _db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.execute(
        """
        CREATE TABLE work_items(
            id TEXT PRIMARY KEY,
            phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,
            status TEXT NOT NULL,
            verdict TEXT,
            evidence_path TEXT,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    conn.commit()
    conn.close()


def _evidence(path: Path, compile_log: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"compile_log": str(compile_log)}), encoding="utf-8")


def test_dry_run_lists_only_latest_eligible_error_106_profile_failure(tmp_path: Path) -> None:
    db = tmp_path / "farm_state.sqlite"
    _db(db)
    missing_log = tmp_path / "missing.log"
    missing_log.write_text(
        "x(4,10) : error 106: file 'Include\\Trade\\Trade.mqh' not found\n",
        encoding="utf-16",
    )
    source_log = tmp_path / "source.log"
    source_log.write_text("x(1,1) : error 256: undeclared identifier\n", encoding="utf-16")
    missing_evidence = tmp_path / "missing.json"
    old_missing_evidence = tmp_path / "old-missing.json"
    source_evidence = tmp_path / "source.json"
    _evidence(missing_evidence, missing_log)
    _evidence(old_missing_evidence, missing_log)
    _evidence(source_evidence, source_log)
    conn = sqlite3.connect(db)
    rows = [
        ("old", "QM5_1", str(old_missing_evidence), "2026-08-22T10:00:00+00:00"),
        ("eligible", "QM5_1", str(missing_evidence), "2026-08-22T11:00:00+00:00"),
        ("source-defect", "QM5_2", str(source_evidence), "2026-08-22T12:00:00+00:00"),
    ]
    for row_id, ea_id, evidence_path, timestamp in rows:
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
            (
                row_id,
                "COMPILE_EA",
                ea_id,
                "failed",
                "COMPILE_FAIL",
                evidence_path,
                json.dumps({"ea_label": f"{ea_id}_fixture", "mq5_sha256": "a" * 64}),
                timestamp,
                timestamp,
            ),
        )
    conn.commit()
    conn.close()

    result = reclassify.build_dry_run(db)

    assert result["mode"] == "dry_run"
    assert result["database_mode"] == "ro"
    assert result["eligible_count"] == 1
    assert [row["work_item_id"] for row in result["eligible_rows"]] == ["eligible"]
    assert result["eligible_rows"][0]["reason"] == "COMPILE_PROFILE_STDLIB_MISSING"
    assert result["mutation_count"] == 0


def test_later_success_or_open_successor_blocks_append_only_eligibility(tmp_path: Path) -> None:
    db = tmp_path / "farm_state.sqlite"
    _db(db)
    log = tmp_path / "missing.log"
    log.write_text(
        "x(6,10) : error 106: file 'Include\\Object.mqh' not found\n",
        encoding="utf-16",
    )
    evidence = tmp_path / "evidence.json"
    _evidence(evidence, log)
    conn = sqlite3.connect(db)
    for row in [
        ("failed-1", "QM5_1", "failed", "COMPILE_FAIL", str(evidence), "2026-08-22T10:00:00+00:00"),
        ("success-1", "QM5_1", "done", "COMPILE_OK", None, "2026-08-22T11:00:00+00:00"),
        ("failed-2", "QM5_2", "failed", "COMPILE_FAIL", str(evidence), "2026-08-22T10:00:00+00:00"),
        ("pending-2", "QM5_2", "pending", None, None, "2026-08-22T11:00:00+00:00"),
    ]:
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
            (
                row[0],
                "COMPILE_EA",
                row[1],
                row[2],
                row[3],
                row[4],
                json.dumps({"mq5_sha256": "b" * 64}),
                row[5],
                row[5],
            ),
        )
    conn.commit()
    conn.close()

    result = reclassify.build_dry_run(db)

    assert result["eligible_count"] == 0
    assert result["matched_signature_count"] == 2
