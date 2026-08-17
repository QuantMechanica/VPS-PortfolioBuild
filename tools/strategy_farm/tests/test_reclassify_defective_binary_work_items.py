from __future__ import annotations

import json
from pathlib import Path
import sqlite3

import pytest

from tools.strategy_farm import reclassify_defective_binary_work_items as repair


HASH = "a" * 64


def _create_db(path: Path, evidence_dir: Path) -> None:
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE work_items (
              id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
              setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
              parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
              payload_json TEXT, created_at TEXT, updated_at TEXT
            );
            CREATE TABLE work_item_transition_ledger (
              seq INTEGER PRIMARY KEY AUTOINCREMENT, idempotency_key TEXT UNIQUE,
              ts TEXT, work_item_id TEXT, action TEXT, from_status TEXT, to_status TEXT,
              from_verdict TEXT, to_verdict TEXT, from_claimed_by TEXT,
              to_claimed_by TEXT, reason TEXT, run_id TEXT, detail_json TEXT
            );
            CREATE TABLE events (
              id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT, entity_type TEXT,
              entity_id TEXT, event TEXT, detail_json TEXT
            );
            """
        )
        for item_id, symbol, verdict, expected_hash in (
            ("one", "EURUSD.DWX", "FAIL", HASH),
            ("two", "NDX.DWX", "ZERO_TRADES", HASH),
            ("other", "GBPUSD.DWX", "FAIL", "b" * 64),
        ):
            evidence = evidence_dir / f"{item_id}.json"
            evidence.write_text("{}\n", encoding="utf-8")
            payload = {
                "expected_ex5_sha256": expected_hash,
                "staged_ex5": {"required_sha256": expected_hash},
                "verdict_reason": "old",
                "verdict_taxonomy": "strategy",
            }
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    item_id,
                    "backtest",
                    "Q02",
                    "QM5_20177",
                    symbol,
                    f"{symbol}.set",
                    "done",
                    verdict,
                    0,
                    None,
                    str(evidence),
                    None,
                    json.dumps(payload),
                    "2026-01-01T00:00:00+00:00",
                    "2026-01-02T00:00:00+00:00",
                ),
            )


def test_hash_keyed_plan_apply_is_exact_backed_up_and_audited(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    evidence_dir = tmp_path / "evidence"
    evidence_dir.mkdir()
    _create_db(db, evidence_dir)
    plan = repair.build_plan(
        db,
        ea_id="QM5_20177",
        phase="Q02",
        expected_ex5_sha256=HASH,
        expected_ids=["one", "two"],
        authority_task_id="task-1",
        reason="confirmed defective binary",
        evidence_path="docs/ops/evidence/task-1.md",
        planned_at_utc="2026-08-17T03:00:00+00:00",
    )
    receipt = repair.apply_plan(
        plan,
        expected_plan_sha256=repair.plan_sha256(plan),
        db=db,
        backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "FACTORY_MUTATION.lock",
    )

    assert Path(receipt["backup_path"]).is_file()
    assert {row["verdict"] for row in receipt["rows"]} == {"DRAFT_DEFECT"}
    with sqlite3.connect(db) as conn:
        rows = conn.execute("SELECT id,verdict,payload_json FROM work_items ORDER BY id").fetchall()
        assert [(row[0], row[1]) for row in rows] == [
            ("one", "DRAFT_DEFECT"),
            ("other", "FAIL"),
            ("two", "DRAFT_DEFECT"),
        ]
        changed_payloads = [json.loads(row[2]) for row in rows if row[0] in {"one", "two"}]
        assert all(payload["verdict_taxonomy"] == "implementation" for payload in changed_payloads)
        assert all(payload["strategy_verdict_voided_by_defective_binary"] for payload in changed_payloads)
        assert conn.execute("SELECT COUNT(*) FROM work_item_transition_ledger").fetchone()[0] == 2
        assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 2


def test_plan_refuses_an_incomplete_hash_keyed_id_set(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    evidence_dir = tmp_path / "evidence"
    evidence_dir.mkdir()
    _create_db(db, evidence_dir)
    with pytest.raises(repair.ReclassificationError, match="target set mismatch"):
        repair.build_plan(
            db,
            ea_id="QM5_20177",
            phase="Q02",
            expected_ex5_sha256=HASH,
            expected_ids=["one"],
            authority_task_id="task-1",
            reason="confirmed defective binary",
            evidence_path="docs/ops/evidence/task-1.md",
        )
