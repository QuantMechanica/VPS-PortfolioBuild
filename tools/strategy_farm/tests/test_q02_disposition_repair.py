from __future__ import annotations

import copy
import datetime as dt
import json
import sqlite3
from pathlib import Path
from typing import Any

import pytest

from tools.strategy_farm import q02_disposition_repair as repair


class _FixtureMutationLock:
    def __init__(self, path: Path, *, owner: str) -> None:
        self.path = Path(path)
        self.owner = owner

    def __enter__(self) -> "_FixtureMutationLock":
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        return None


def _write_json(path: Path, value: Any) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    return path


def _schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
          ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
          status TEXT NOT NULL, verdict TEXT, attempt_count INTEGER NOT NULL,
          parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
          payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        );
        CREATE TABLE events(
          id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT NOT NULL,
          entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
          event TEXT NOT NULL, detail_json TEXT NOT NULL
        );
        CREATE TABLE agent_tasks(
          id TEXT PRIMARY KEY, task_type TEXT NOT NULL, state TEXT NOT NULL,
          priority INTEGER NOT NULL, required_capabilities_json TEXT NOT NULL,
          assigned_agent TEXT, budget_class TEXT NOT NULL, parent_id TEXT,
          artifact_path TEXT, verdict TEXT, payload_json TEXT NOT NULL,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          required_skills_json TEXT NOT NULL
        );
        """
    )


def _execution_identity() -> dict[str, Any]:
    return {
        "stable_during_run": True,
        "expert_binary": {
            "source_matches_deployed": True,
            "stable_during_run": True,
        },
        "setfile": {
            "source_matches_deployed": True,
            "stable_during_run": True,
        },
    }


def _fixture(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    active_rows: int = 0,
) -> dict[str, Any]:
    monkeypatch.setattr(repair, "FactoryMutationLock", _FixtureMutationLock)
    repo = tmp_path / "repo"
    state = tmp_path / "state"
    reports = tmp_path / "reports"
    repo.mkdir(parents=True)
    state.mkdir(parents=True)
    db = state / "farm_state.sqlite"
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    _schema(conn)

    expected_rows: list[dict[str, Any]] = []
    preimages: dict[str, dict[str, Any]] = {}
    for index, work_item_id in enumerate(repair.TARGET_IDS):
        ea_id = f"QM5_{7000 + index}"
        symbol = f"SYM{index}.DWX"
        evidence = {
            "evidence_schema": "run_smoke/v2",
            "result": "PASS",
            "ea_id": 7000 + index,
            "symbol": symbol,
            "runs": [{"status": "OK", "total_trades": index + 1}],
            "execution_identity": _execution_identity(),
        }
        evidence_path = _write_json(reports / work_item_id / "summary.json", evidence)
        payload = json.dumps(
            {"fixture": index, "historical": True},
            sort_keys=True,
            separators=(",", ":"),
        )
        values = (
            work_item_id,
            "backtest",
            "Q02",
            ea_id,
            symbol,
            str((repo / f"target-{index}.set").resolve()),
            "failed",
            "INFRA_FAIL",
            index,
            f"parent-{index}",
            str(evidence_path.resolve()),
            None,
            payload,
            "2026-07-20T00:00:00Z",
            f"2026-07-{20 + index:02d}T01:00:00Z",
        )
        conn.execute("INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", values)
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        preimages[work_item_id] = dict(row)
        evidence_sha = repair.sha256_file(evidence_path)
        expected_rows.append(
            {
                "id": work_item_id,
                "ea_id": ea_id,
                "symbol": symbol,
                "phase": "Q02",
                "status": "failed",
                "verdict": "INFRA_FAIL",
                "claimed_by": None,
                "evidence_path": str(evidence_path.resolve()),
                "evidence_sha256": evidence_sha,
                "payload_sha256": repair.payload_sha256(payload),
                "updated_at": values[-1],
                "summary_result": "PASS",
                "ok_runs": 1,
                "total_trades": index + 1,
            }
        )
    for index in range(active_rows):
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                f"active-{index}",
                "backtest",
                "Q03",
                "QM5_1",
                "OTHER.DWX",
                "other.set",
                "active",
                None,
                0,
                None,
                None,
                "T1",
                "{}",
                "2026-08-01T00:00:00Z",
                "2026-08-01T00:00:00Z",
            ),
        )

    authority_plan = {
        "schema": repair.AUTHORITY_PLAN_SCHEMA,
        "authority_required": "separate APPROVED exact-plan task",
        "operation": repair.AUTHORITY_PLAN_OPERATION,
        "rows": expected_rows,
    }
    authority_sha = repair.canonical_sha256(authority_plan)
    authority_bytes = len(repair.canonical_json_bytes(authority_plan))
    monkeypatch.setattr(repair, "ACCEPTED_AUTHORITY_PLAN_SHA256", authority_sha)
    monkeypatch.setattr(repair, "ACCEPTED_AUTHORITY_PLAN_BYTES", authority_bytes)

    authority_payload = {
        "brief": (
            f"accepted {authority_sha} {repair.AUTHORITY_PLAN_SCHEMA}; "
            "Legacy-summary bindings explicitly accepted; "
            "Sunday 2026-08-02 Factory-OFF window"
        ),
        "predecessor": "27086064",
        "reviewer_after": "claude",
    }
    predecessor_payload = {
        "review_close_state": "APPROVED",
        "review_close_verdict": (
            f"DISPOSITION-REPAIR PLAN REVIEWED AND ACCEPTED sha {authority_sha[:8]}"
        ),
    }
    task_values = (
        repair.AUTHORITY_TASK_ID,
        "ops_issue",
        "IN_PROGRESS",
        66,
        '["code","ops"]',
        "codex",
        "standard",
        None,
        None,
        None,
        json.dumps(authority_payload, sort_keys=True),
        "2026-08-01T01:16:46Z",
        "2026-08-01T01:16:46Z",
        "[]",
    )
    predecessor_values = (
        repair.PREDECESSOR_TASK_ID,
        "ops_issue",
        "APPROVED",
        67,
        '["code","ops"]',
        "codex",
        "standard",
        None,
        None,
        "APPROVED",
        json.dumps(predecessor_payload, sort_keys=True),
        "2026-08-01T00:31:36Z",
        "2026-08-01T01:16:18Z",
        "[]",
    )
    conn.execute("INSERT INTO agent_tasks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)", task_values)
    conn.execute(
        "INSERT INTO agent_tasks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)", predecessor_values
    )
    conn.commit()
    conn.close()

    flag = state / "FACTORY_OFF.flag"
    flag.write_text("OWNER Sunday maintenance\n", encoding="utf-8")
    paths = repair.RuntimePaths(
        db=db,
        repo=repo,
        factory_off_flag=flag,
        backup_dir=state / "backups",
        mutation_lock=state / "FACTORY_MUTATION.lock",
    )
    return {
        "db": db,
        "paths": paths,
        "flag_sha": repair.sha256_file(flag),
        "authority_sha": authority_sha,
        "preimages": preimages,
        "plan_out": tmp_path / "plan.json",
        "receipt_out": tmp_path / "dry-run.json",
        "journal_out": tmp_path / "journal.json",
    }


def _set_now(
    monkeypatch: pytest.MonkeyPatch,
    value: dt.datetime,
) -> None:
    assert value.tzinfo is not None
    monkeypatch.setattr(repair, "current_utc", lambda: value.astimezone(dt.UTC))


def _dry(fixture: dict[str, Any]) -> dict[str, Any]:
    return repair.dry_run(
        fixture["plan_out"], fixture["receipt_out"], fixture["paths"]
    )


def _rows(db: Path) -> dict[str, dict[str, Any]]:
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    result = {
        work_item_id: dict(conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone())
        for work_item_id in repair.TARGET_IDS
    }
    conn.close()
    return result


def test_dry_run_binds_full_preimages_and_does_not_mutate(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 1, 12, tzinfo=dt.UTC))
    before = fixture["db"].read_bytes()
    result = _dry(fixture)
    after = fixture["db"].read_bytes()
    plan, plan_sha = repair.load_json_strict(fixture["plan_out"], "test plan")
    assert before == after
    assert result["status"] == "READY_FOR_AUTHORIZED_WINDOW"
    assert result["mutation_performed"] is False
    assert result["window_snapshot"]["date_gate_open"] is False
    assert result["execution_plan"]["sha256"] == plan_sha
    assert plan["authority"]["canonical_plan_sha256"] == fixture["authority_sha"]
    assert len(plan["targets"]) == 10
    assert set(plan["targets"][0]["full_preimage"]) == set(repair.WORK_ITEM_COLUMNS)


def test_apply_refuses_outside_sunday_before_backup_or_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 1, 12, tzinfo=dt.UTC))
    dry = _dry(fixture)
    with pytest.raises(repair.DispositionRepairError, match="outside authorized"):
        repair.apply_plan(
            fixture["plan_out"],
            dry["execution_plan"]["sha256"],
            fixture["authority_sha"],
            fixture["flag_sha"],
            fixture["journal_out"],
            fixture["paths"],
        )
    assert _rows(fixture["db"]) == fixture["preimages"]
    assert not fixture["paths"].backup_dir.exists()
    assert not fixture["journal_out"].exists()


def test_apply_all_ten_then_guarded_revert_restores_exact_preimages(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 2, 10, tzinfo=dt.UTC))
    dry = _dry(fixture)
    applied = repair.apply_plan(
        fixture["plan_out"],
        dry["execution_plan"]["sha256"],
        fixture["authority_sha"],
        fixture["flag_sha"],
        fixture["journal_out"],
        fixture["paths"],
    )
    assert applied["status"] == "APPLIED"
    assert applied["row_count"] == 10
    assert Path(applied["backup"]["path"]).is_file()
    assert applied["backup"]["quick_check"] == "ok"
    post_rows = _rows(fixture["db"])
    for work_item_id, row in post_rows.items():
        pre = fixture["preimages"][work_item_id]
        assert row["status"] == "done" and row["verdict"] == "PASS"
        for retained in ("attempt_count", "parent_task_id", "evidence_path", "created_at"):
            assert row[retained] == pre[retained]
        audit = json.loads(row["payload_json"])["q02_disposition_repair"]
        assert audit["authority_plan_sha256"] == fixture["authority_sha"]
        assert audit["rerun_or_enqueue_performed"] is False

    conn = sqlite3.connect(fixture["db"])
    assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 11
    assert conn.execute("PRAGMA quick_check").fetchone()[0] == "ok"
    conn.close()

    reverted = repair.revert_journal(
        fixture["journal_out"],
        applied["journal_sha256"],
        fixture["flag_sha"],
        fixture["paths"],
    )
    assert reverted["status"] == "REVERTED"
    assert _rows(fixture["db"]) == fixture["preimages"]
    conn = sqlite3.connect(fixture["db"])
    assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 22
    assert conn.execute("PRAGMA quick_check").fetchone()[0] == "ok"
    conn.close()


def test_apply_refuses_active_work_before_backup(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch, active_rows=1)
    _set_now(monkeypatch, dt.datetime(2026, 8, 2, 10, tzinfo=dt.UTC))
    dry = _dry(fixture)
    with pytest.raises(repair.DispositionRepairError, match="zero active work items"):
        repair.apply_plan(
            fixture["plan_out"],
            dry["execution_plan"]["sha256"],
            fixture["authority_sha"],
            fixture["flag_sha"],
            fixture["journal_out"],
            fixture["paths"],
        )
    assert _rows(fixture["db"]) == fixture["preimages"]
    assert not fixture["paths"].backup_dir.exists()


def test_preimage_drift_aborts_before_any_row_changes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 2, 10, tzinfo=dt.UTC))
    dry = _dry(fixture)
    drifted_id = repair.TARGET_IDS[4]
    conn = sqlite3.connect(fixture["db"])
    conn.execute("UPDATE work_items SET updated_at='drifted' WHERE id=?", (drifted_id,))
    conn.commit()
    conn.close()
    with pytest.raises(repair.DispositionRepairError, match="authority plan"):
        repair.apply_plan(
            fixture["plan_out"],
            dry["execution_plan"]["sha256"],
            fixture["authority_sha"],
            fixture["flag_sha"],
            fixture["journal_out"],
            fixture["paths"],
        )
    rows = _rows(fixture["db"])
    assert all(row["status"] == "failed" for row in rows.values())
    assert not fixture["paths"].backup_dir.exists()


def test_mid_cohort_failure_rolls_back_every_cas(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 2, 10, tzinfo=dt.UTC))
    dry = _dry(fixture)
    original = repair._cas_full_preimage
    calls = 0

    def fail_second(
        conn: sqlite3.Connection,
        preimage: dict[str, Any],
        postimage: dict[str, Any],
    ) -> None:
        nonlocal calls
        calls += 1
        if calls == 2:
            raise repair.DispositionRepairError("injected cohort failure")
        original(conn, preimage, postimage)

    monkeypatch.setattr(repair, "_cas_full_preimage", fail_second)
    with pytest.raises(repair.DispositionRepairError, match="injected cohort failure"):
        repair.apply_plan(
            fixture["plan_out"],
            dry["execution_plan"]["sha256"],
            fixture["authority_sha"],
            fixture["flag_sha"],
            fixture["journal_out"],
            fixture["paths"],
        )
    assert _rows(fixture["db"]) == fixture["preimages"]
    conn = sqlite3.connect(fixture["db"])
    assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 0
    conn.close()
    assert not fixture["journal_out"].exists()
    assert len(list(fixture["paths"].backup_dir.glob("*.sqlite"))) == 1


def test_revert_refuses_one_drifted_postimage_without_partial_restore(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 2, 10, tzinfo=dt.UTC))
    dry = _dry(fixture)
    applied = repair.apply_plan(
        fixture["plan_out"],
        dry["execution_plan"]["sha256"],
        fixture["authority_sha"],
        fixture["flag_sha"],
        fixture["journal_out"],
        fixture["paths"],
    )
    drifted_id = repair.TARGET_IDS[-1]
    conn = sqlite3.connect(fixture["db"])
    conn.execute("UPDATE work_items SET claimed_by='T1' WHERE id=?", (drifted_id,))
    conn.commit()
    conn.close()
    with pytest.raises(repair.DispositionRepairError, match="partial/drifted"):
        repair.revert_journal(
            fixture["journal_out"],
            applied["journal_sha256"],
            fixture["flag_sha"],
            fixture["paths"],
        )
    rows = _rows(fixture["db"])
    assert all(row["status"] == "done" for row in rows.values())
    assert rows[drifted_id]["claimed_by"] == "T1"
    conn = sqlite3.connect(fixture["db"])
    assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 11
    conn.close()


def test_tampered_execution_plan_is_rejected_by_raw_hash(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    _set_now(monkeypatch, dt.datetime(2026, 8, 2, 10, tzinfo=dt.UTC))
    dry = _dry(fixture)
    plan = json.loads(fixture["plan_out"].read_text(encoding="utf-8"))
    plan["targets"][0]["full_preimage"]["attempt_count"] += 1
    fixture["plan_out"].write_text(json.dumps(plan) + "\n", encoding="utf-8")
    with pytest.raises(repair.DispositionRepairError, match="execution-plan SHA-256 mismatch"):
        repair.apply_plan(
            fixture["plan_out"],
            dry["execution_plan"]["sha256"],
            fixture["authority_sha"],
            fixture["flag_sha"],
            fixture["journal_out"],
            fixture["paths"],
        )


def test_schema_less_summary_requires_explicit_legacy_binding(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    work_item_id = repair.TARGET_IDS[0]
    conn = sqlite3.connect(fixture["db"])
    conn.row_factory = sqlite3.Row
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
    evidence_path = Path(row["evidence_path"])
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    evidence.pop("evidence_schema")
    evidence.pop("execution_identity")
    _write_json(evidence_path, evidence)
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
    monkeypatch.delitem(repair.LEGACY_SUMMARY_BINDINGS, work_item_id)
    with pytest.raises(repair.DispositionRepairError, match="lacks an explicit accepted legacy"):
        repair._evidence_facts(row)
    facts = {
        "evidence_sha256": repair.sha256_file(evidence_path),
        "ok_runs": 1,
        "total_trades": 1,
    }
    monkeypatch.setitem(repair.LEGACY_SUMMARY_BINDINGS, work_item_id, facts)
    assert repair._evidence_facts(row)["legacy_binding_explicitly_accepted"] is True
    conn.close()
