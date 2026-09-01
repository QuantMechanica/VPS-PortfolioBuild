from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import recover_legacy_opt_census as recovery
from tools.strategy_farm import terminal_worker


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
  id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
  ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
  status TEXT NOT NULL, verdict TEXT, attempt_count INTEGER NOT NULL DEFAULT 0,
  parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
  payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  verdict_taxonomy_stored TEXT, clean_status_stored TEXT,
  gate_contract_version TEXT, ex5_sha256 TEXT, setfile_sha256 TEXT,
  mq5_sha256 TEXT, include_closure_sha256 TEXT, build_id TEXT,
  data_window_start TEXT, data_window_end TEXT, news_calendar_sha256 TEXT,
  verdict_taxonomy TEXT, sh3_enforced INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE work_item_holds (
  work_item_id TEXT PRIMARY KEY, hold_code TEXT NOT NULL, reason TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1, release_on_restart INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  released_at TEXT, release_note TEXT
);
"""


def _row(
    work_item_id: str,
    *,
    status: str,
    verdict: str | None,
    payload: dict,
    parent_task_id: str | None = None,
) -> dict:
    return {
        "id": work_item_id,
        "kind": "backtest",
        "phase": "OPT_CENSUS",
        "ea_id": recovery.MEASUREMENT_EA_ID,
        "symbol": recovery.SYMBOL,
        "setfile_path": f"C:\\cells\\{work_item_id}.set",
        "status": status,
        "verdict": verdict,
        "attempt_count": 0,
        "parent_task_id": parent_task_id,
        "evidence_path": None if status == "pending" else f"C:\\evidence\\{work_item_id}.json",
        "claimed_by": None,
        "payload_json": json.dumps(payload, sort_keys=True),
        "created_at": "2026-08-22T00:00:00+00:00",
        "updated_at": "2026-08-22T00:00:00+00:00",
        "verdict_taxonomy_stored": "open" if status == "pending" else "measurement",
        "clean_status_stored": status,
        "gate_contract_version": "legacy",
        "ex5_sha256": recovery.EX5_SHA256 if status == "done" else None,
        "setfile_sha256": "a" * 64 if status == "done" else None,
        "mq5_sha256": recovery.SOURCE_SHA256 if status == "done" else None,
        "include_closure_sha256": None,
        "build_id": None,
        "data_window_start": "2019.01.01",
        "data_window_end": "2019.12.31",
        "news_calendar_sha256": None,
        "verdict_taxonomy": "measurement" if status == "done" else "open",
        "sh3_enforced": 1,
    }


def _insert(conn: sqlite3.Connection, row: dict) -> None:
    keys = tuple(row)
    conn.execute(
        f"INSERT INTO work_items({','.join(keys)}) VALUES({','.join('?' for _ in keys)})",
        tuple(row[key] for key in keys),
    )


def _plan(tmp_path: Path, pending: tuple[dict, ...], done: tuple[dict, ...]) -> recovery.RecoveryPlan:
    declaration_sha = "d" * 64
    q12_id = "q12-recovery"
    q12_payload = {
        "schema": "qm.opt-fork-routing/v1",
        "role": "PATTERN",
        "phase": "Q12",
        "routing_revision": "dl089-annual-wf-cells-v1",
        "pattern_filter_sweep": {"declaration_sha256": declaration_sha},
    }
    q12_payload_json = json.dumps(q12_payload, sort_keys=True)
    q12_row = {
        "id": q12_id,
        "kind": "analytic",
        "phase": "Q12",
        "ea_id": recovery.SUBJECT_EA_ID,
        "symbol": recovery.SYMBOL,
        "setfile_path": "C:\\parent.set",
        "status": "pending",
        "verdict": None,
        "attempt_count": 0,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": q12_payload_json,
        "created_at": "2026-09-01T00:00:00+00:00",
        "updated_at": "2026-09-01T00:00:00+00:00",
        "gate_contract_version": "v4",
        "ex5_sha256": "1" * 64,
        "setfile_sha256": "2" * 64,
        "mq5_sha256": "3" * 64,
        "verdict_taxonomy": "open",
        "sh3_enforced": 1,
    }
    sealed = {
        "cells": [row["_cell"] for row in (*done, *pending)],
        "program_id": recovery.PROGRAM_ID,
    }
    return recovery.RecoveryPlan(
        q12_work_item_id=q12_id,
        q12_payload=q12_payload,
        q12_payload_json=q12_payload_json,
        q12_row=q12_row,
        declaration={"declaration_sha256": declaration_sha},
        legacy_ledger={},
        sealed_ledger=sealed,
        pending_rows=pending,
        done_rows=done,
        done_adoption={},
        registration={},
        q04_diagnostic={},
        paths={"sealed_ledger": tmp_path / "ledger.json"},
        bindings={
            "binary": {"path": "C:\\ea.ex5"},
            "source": {"path": "C:\\ea.mq5"},
        },
        base_setfile_bytes=b"",
    )


def test_pending_only_cas_preserves_completed_row(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(recovery, "EXPECTED_PENDING", 2)
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(WORK_ITEMS_DDL)
    base_payload = {
        "schema": "qm.opt-census.v1",
        "program_id": recovery.PROGRAM_ID,
        "cell_key": "cell",
        "year": 2019,
        "arm": "baseline",
        "direction": "NONE",
        "predicate_id": 0,
        "from_date": "2019.01.01",
        "to_date": "2019.12.31",
    }
    done = _row("done", status="done", verdict="MEASURED", payload=base_payload)
    pending_a = _row("pending-a", status="pending", verdict=None, payload=base_payload)
    pending_b = _row("pending-b", status="pending", verdict=None, payload=base_payload)
    for row in (done, pending_a, pending_b):
        _insert(conn, row)
    conn.commit()
    done_db = dict(conn.execute("SELECT * FROM work_items WHERE id='done'").fetchone())
    pending_db = []
    for work_item_id in ("pending-a", "pending-b"):
        value = dict(conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone())
        value["_cell"] = {
            "work_item_id": work_item_id,
            "cell_key": "cell",
            "year": 2019,
            "arm": "baseline",
            "direction": "NONE",
            "predicate_id": 0,
            "from_date": "2019.01.01",
            "to_date": "2019.12.31",
        }
        value["_setfile_sha256"] = "b" * 64
        pending_db.append(value)
    done_db["_cell"] = {"work_item_id": "done"}
    done_before = tuple(conn.execute("SELECT * FROM work_items WHERE id='done'").fetchone())
    plan = _plan(tmp_path, tuple(pending_db), (done_db,))

    result = recovery.apply_database_recovery(conn, plan)

    assert result["pending_rows_repaired"] == 2
    assert result["verdict_rows_touched"] == 0
    assert tuple(conn.execute("SELECT * FROM work_items WHERE id='done'").fetchone()) == done_before
    for work_item_id in ("pending-a", "pending-b"):
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        payload = json.loads(row["payload_json"])
        assert row["parent_task_id"] == plan.q12_work_item_id
        assert row["verdict"] is None and row["claimed_by"] is None
        assert row["gate_contract_version"] == "legacy"
        assert terminal_worker._is_governed_dl089_census_payload(payload) is True
    hold = conn.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?",
        (plan.q12_work_item_id,),
    ).fetchone()
    assert tuple(hold) == (recovery.REVIEW_HOLD_CODE, 1)


def test_pending_only_cas_refuses_claimed_or_verdict_row(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(recovery, "EXPECTED_PENDING", 1)
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(WORK_ITEMS_DDL)
    payload = {
        "schema": "qm.opt-census.v1",
        "program_id": recovery.PROGRAM_ID,
        "cell_key": "cell",
        "year": 2019,
        "arm": "baseline",
        "direction": "NONE",
        "predicate_id": 0,
        "from_date": "2019.01.01",
        "to_date": "2019.12.31",
    }
    pending = _row("pending", status="pending", verdict=None, payload=payload)
    _insert(conn, pending)
    planned = dict(conn.execute("SELECT * FROM work_items WHERE id='pending'").fetchone())
    planned["_cell"] = {
        "work_item_id": "pending",
        "cell_key": "cell",
        "year": 2019,
        "arm": "baseline",
        "direction": "NONE",
        "predicate_id": 0,
        "from_date": "2019.01.01",
        "to_date": "2019.12.31",
    }
    planned["_setfile_sha256"] = "b" * 64
    plan = _plan(tmp_path, (planned,), ())
    conn.execute("UPDATE work_items SET claimed_by='T1' WHERE id='pending'")
    conn.commit()

    with pytest.raises(recovery.RecoveryError, match="pending CAS preimage changed"):
        recovery.apply_database_recovery(conn, plan)

    assert conn.execute("SELECT count(*) FROM work_items WHERE phase='Q12'").fetchone()[0] == 0


def test_recovered_base_setfile_enforces_risk_and_pattern_neutrality(tmp_path: Path) -> None:
    cell = tmp_path / "baseline.set"
    cell.write_text(
        "\n".join(
            [
                "; opt_census_schema: qm.opt-census.v1",
                "; opt_census_cell_key: P:2019:baseline",
                "; opt_census_from_date: 2019.01.01",
                "; opt_census_to_date: 2019.12.31",
                "; environment: backtest",
                "qm_ea_id=41097",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "qm_news_stale_max_hours=336",
                *[f"{key}=0" for key in recovery.census.SET_KEYS],
                "",
            ]
        ),
        encoding="utf-8",
    )
    ledger = {"cells": [{"year": 2019, "arm": "baseline", "setfile_path": str(cell)}]}

    recovered = recovery._base_setfile_from_baseline(ledger).decode("utf-8")

    assert recovered.startswith("; environment: backtest")
    assert "RISK_FIXED=1000" in recovered
    assert "RISK_PERCENT=0" in recovered
    assert all(f"{key}=0" in recovered for key in recovery.census.SET_KEYS)


def test_recovered_base_setfile_refuses_news_ceiling_above_336(tmp_path: Path) -> None:
    cell = tmp_path / "baseline.set"
    cell.write_text(
        "\n".join(
            [
                "; opt_census_schema: qm.opt-census.v1",
                "; opt_census_cell_key: P:2019:baseline",
                "; opt_census_from_date: 2019.01.01",
                "; opt_census_to_date: 2019.12.31",
                "; environment: backtest",
                "qm_ea_id=41097",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "qm_news_stale_max_hours=337",
                *[f"{key}=0" for key in recovery.census.SET_KEYS],
                "",
            ]
        ),
        encoding="utf-8",
    )
    ledger = {"cells": [{"year": 2019, "arm": "baseline", "setfile_path": str(cell)}]}

    with pytest.raises(recovery.RecoveryError, match="news stale ceiling"):
        recovery._base_setfile_from_baseline(ledger)
