from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import farmctl, schema_hardening
from tools.strategy_farm.artifact_identity import prepare_completion


HASH_A = "a" * 64
HASH_B = "b" * 64
HASH_C = "c" * 64


def _legacy_db(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(path)
    con.execute(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
          ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
          status TEXT NOT NULL CHECK(status IN ('pending','active','done','failed')),
          verdict TEXT, attempt_count INTEGER NOT NULL DEFAULT 0,
          parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
          payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          verdict_taxonomy_stored TEXT, clean_status_stored TEXT,
          gate_contract_version TEXT
        )
        """
    )
    con.execute("CREATE INDEX idx_work_items_status_kind ON work_items(status,kind)")
    return con


def _insert(con: sqlite3.Connection, wid: str, status: str, verdict: str | None, payload: dict) -> None:
    con.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          payload_json,created_at,updated_at,verdict_taxonomy_stored,clean_status_stored
        ) VALUES(?,?,?,?,?,?,?,?,0,?,?,?,?,?)
        """,
        (wid, "backtest", "Q02", "QM5_1", "EURUSD.DWX", "x.set", status, verdict,
         json.dumps(payload, sort_keys=True), "2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z",
         payload.get("verdict_taxonomy"), status),
    )


def test_prepare_completion_fails_closed_without_bound_identity() -> None:
    payload = {"verdict_taxonomy": "strategy"}
    verdict, taxonomy, identity, missing = prepare_completion(
        phase="Q02", kind="backtest", payload=payload, summary={},
        verdict="PASS", taxonomy="strategy",
    )
    assert verdict == "INFRA_FAIL"
    assert taxonomy == "infra"
    assert set(missing) == {
        "ex5_sha256", "setfile_sha256", "data_window_start", "data_window_end",
    }
    assert identity["ex5_sha256"] is None
    assert payload["verdict_reason"] == "ARTIFACT_IDENTITY_MISSING"


def test_sh2_backfill_is_typed_indexed_and_idempotent(tmp_path: Path) -> None:
    con = _legacy_db(tmp_path / "farm.sqlite")
    _insert(con, "bound", "done", "PASS", {
        "expected_ex5_sha256": HASH_A,
        "expected_setfile_sha256": HASH_B,
        "expected_mq5_sha256": HASH_C,
        "build_hash": "build-17",
        "from_date": "2017.01.01",
        "to_date": "2022.12.31",
        "verdict_taxonomy": "strategy",
    })
    first = farmctl.ensure_work_item_artifact_identity_schema(con)
    second = farmctl.ensure_work_item_artifact_identity_schema(con)
    row = con.execute(
        "SELECT ex5_sha256,setfile_sha256,mq5_sha256,build_id,data_window_start,data_window_end "
        "FROM work_items WHERE id='bound'"
    ).fetchone()
    indexes = {r[1] for r in con.execute("PRAGMA index_list(work_items)")}
    con.close()
    assert first["rows_backfilled"] == 1
    assert second["rows_backfilled"] == 0
    assert row == (HASH_A, HASH_B, HASH_C, "build-17", "2017.01.01", "2022.12.31")
    assert "idx_work_items_ex5_sha256" in indexes
    assert "idx_work_items_news_calendar_sha256" in indexes


def test_sh3_rebuild_preserves_history_and_constrains_new_writes(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    backup = tmp_path / "pre_sh3.sqlite"
    con = _legacy_db(db)
    _insert(con, "contradiction", "done", "INFRA_FAIL", {"verdict_taxonomy": "infra"})
    _insert(con, "pending", "pending", None, {})
    con.commit()

    before = con.execute("SELECT * FROM work_items ORDER BY id").fetchall()
    result = schema_hardening.migrate_sh3(con, backup)
    after = con.execute(
        "SELECT " + ",".join(row[1] for row in con.execute("PRAGMA table_info(work_items)")
                              if row[1] not in set(schema_hardening.IDENTITY_COLUMNS)
                              | {"verdict_taxonomy", "sh3_enforced"})
        + " FROM work_items ORDER BY id"
    ).fetchall()
    assert after == before
    assert result["before_count"] == result["after_count"] == 2
    assert result["before_digest"] == result["after_digest"]
    assert backup.is_file()
    validated = schema_hardening.validate_sh3(con)
    assert validated["historical_status_contradiction_count"] == 1
    assert validated["historical_status_contradictions"][0]["id"] == "contradiction"

    _insert(con, "new-missing", "pending", None, {})
    con.execute(
        "UPDATE work_items SET status='done',verdict='PASS',"
        "payload_json=? WHERE id='new-missing'",
        (json.dumps({"verdict_taxonomy": "strategy"}),),
    )
    missing = con.execute(
        "SELECT status,verdict,verdict_taxonomy,payload_json,sh3_enforced "
        "FROM work_items WHERE id='new-missing'"
    ).fetchone()
    assert missing[:3] == ("failed", "INFRA_FAIL", "infra")
    assert json.loads(missing[3])["verdict_reason"] == "ARTIFACT_IDENTITY_MISSING"
    assert missing[4] == 1

    _insert(con, "new-bound", "pending", None, {})
    bound_payload = {
        "verdict_taxonomy": "strategy", "expected_ex5_sha256": HASH_A,
        "expected_setfile_sha256": HASH_B, "expected_from_date": "2017.01.01",
        "expected_to_date": "2022.12.31",
    }
    con.execute(
        "UPDATE work_items SET status='done',verdict='PASS',payload_json=? WHERE id='new-bound'",
        (json.dumps(bound_payload),),
    )
    bound = con.execute(
        "SELECT status,verdict,verdict_taxonomy,ex5_sha256,setfile_sha256,"
        "data_window_start,data_window_end FROM work_items WHERE id='new-bound'"
    ).fetchone()
    assert bound == (
        "done", "PASS", "strategy", HASH_A, HASH_B, "2017.01.01", "2022.12.31",
    )

    with pytest.raises(sqlite3.IntegrityError):
        _insert(con, "done-without-verdict", "done", None, {})
    with pytest.raises(sqlite3.IntegrityError):
        _insert(con, "failed-without-taxonomy", "failed", "INFRA_FAIL", {})
    with pytest.raises(sqlite3.IntegrityError):
        con.execute(
            "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,"
            "attempt_count,payload_json,created_at,updated_at) VALUES("
            "'blank-phase','backtest','','QM5_1','EURUSD.DWX','x.set','pending',0,'{}',"
            "'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')"
        )
    con.close()
