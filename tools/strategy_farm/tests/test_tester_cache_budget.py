from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path
from types import SimpleNamespace


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import poison_pill_quarantine as quarantine  # noqa: E402
import terminal_worker  # noqa: E402
import tester_cache_budget as budget  # noqa: E402


def _write_bytes(path: Path, count: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x" * count)


def test_budget_is_default_off_and_invalid_values_do_not_arm(tmp_path: Path) -> None:
    assert budget.arm(tmp_path, "T1", environ={}) == {
        "schema": budget.SCHEMA,
        "enabled": False,
        "configuration": "absent",
        "environment_variable": budget.ENV_BUDGET_GB,
    }
    invalid = budget.arm(
        tmp_path, "T1", environ={budget.ENV_BUDGET_GB: "not-a-number"}
    )
    assert invalid["enabled"] is False
    assert invalid["configuration"] == "invalid_or_non_positive"


def test_snapshot_counts_only_bases_and_agent_trees(
    tmp_path: Path, monkeypatch,
) -> None:
    tester = tmp_path / "T3" / "Tester"
    _write_bytes(tester / "bases" / "Darwinex-Demo" / "ticks" / "XAU.tkc", 11)
    _write_bytes(tester / "Agent-127.0.0.1-3000" / "bases" / "peer.hcc", 13)
    _write_bytes(tester / "cache" / "not-tick-cache.opt", 101)
    _write_bytes(tester / "logs" / "journal.log", 103)
    monkeypatch.setattr(
        budget.shutil,
        "disk_usage",
        lambda _path: SimpleNamespace(free=100 * budget.GIB),
    )

    measured = budget.snapshot(tmp_path, "T3")

    assert measured["ok"] is True
    assert measured["cache_bytes"] == 24
    assert measured["file_count"] == 2
    assert all("\\cache" not in path.lower() for path in measured["roots"])
    assert all("\\logs" not in path.lower() for path in measured["roots"])


def test_growth_budget_and_disk_reserve_both_trip(
    tmp_path: Path, monkeypatch,
) -> None:
    tester = tmp_path / "T4" / "Tester"
    payload = tester / "bases" / "ticks" / "XAU.tkc"
    _write_bytes(payload, 8)
    free = {"bytes": 80 * budget.GIB}
    monkeypatch.setattr(
        budget.shutil,
        "disk_usage",
        lambda _path: SimpleNamespace(free=free["bytes"]),
    )
    state = budget.arm(
        tmp_path,
        "T4",
        environ={budget.ENV_BUDGET_GB: str(16 / budget.GIB)},
    )
    _write_bytes(payload, 25)

    growth_trip = budget.sample(state)

    assert growth_trip["tripped"] is True
    assert growth_trip["trigger"] == "growth_budget"
    assert growth_trip["growth_bytes"] == 17
    assert growth_trip["verdict_reason"] == budget.VERDICT_REASON

    _write_bytes(payload, 8)
    free["bytes"] = 47 * budget.GIB
    floor_state = budget.arm(
        tmp_path,
        "T4",
        environ={budget.ENV_BUDGET_GB: "12"},
    )
    floor_trip = budget.sample(floor_state)
    assert floor_trip["tripped"] is True
    assert floor_trip["trigger"] == "disk_stop_reserve"
    assert floor_state["effective_budget_bytes"] == 0
    assert floor_trip["free_bytes"] > floor_trip["disk_stop_bytes"]


def test_ledger_confirmed_hidden_universes_receive_multisymbol_admission() -> None:
    for ea_id in ("QM5_9107", "QM5_1540", "QM5_1536", "QM5_10316"):
        item = {"ea_id": ea_id, "symbol": "XAUUSD.DWX"}
        assert terminal_worker._work_item_is_multisymbol(item, {}, frozenset()) is True
        assert (
            terminal_worker._multisymbol_commit_class(item, {}, True)
            == terminal_worker.MULTISYMBOL_COMMIT_CLASS_HEAVY
        )


def _minimal_work_items(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE work_items (
          id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT, phase TEXT, status TEXT,
          verdict TEXT, evidence_path TEXT, payload_json TEXT, updated_at TEXT
        );
        """
    )
    quarantine.ensure_schema(conn)


def _cache_failure(
    conn: sqlite3.Connection, item_id: str, updated_at: str,
    *, ea_id: str = "QM5_9107", symbol: str = "XAUUSD.DWX",
) -> None:
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?)",
        (
            item_id,
            ea_id,
            symbol,
            "Q02",
            "failed",
            "INFRA_FAIL",
            f"evidence/{item_id}.json",
            json.dumps({"verdict_reason": budget.VERDICT_REASON}),
            updated_at,
        ),
    )


def test_exact_pair_hold_activates_on_second_distinct_hit_and_release_resets() -> None:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    _minimal_work_items(conn)
    _cache_failure(conn, "one", "2026-09-15T00:00:01+00:00")
    first = quarantine.record_tester_cache_budget_hit(
        conn,
        "QM5_9107",
        "XAUUSD.DWX",
        evidence_path="evidence/one.json",
        now="2026-09-15T00:00:02+00:00",
    )
    assert first["active"] is False
    assert first["hit_count"] == 1
    assert conn.execute("SELECT COUNT(*) FROM poison_pill_quarantine").fetchone()[0] == 0

    _cache_failure(conn, "two", "2026-09-15T00:00:03+00:00")
    second = quarantine.record_tester_cache_budget_hit(
        conn,
        "QM5_9107",
        "XAUUSD.DWX",
        evidence_path="evidence/two.json",
        now="2026-09-15T00:00:04+00:00",
    )
    assert second["active"] is True
    row = conn.execute("SELECT * FROM poison_pill_quarantine").fetchone()
    assert row["phase"] == budget.PAIR_HOLD_PHASE
    assert row["verdict_reason"] == budget.VERDICT_REASON
    assert row["consecutive_failures"] == 2

    conn.execute(
        "UPDATE poison_pill_quarantine SET active=0,released_at=? WHERE ea_id=? AND symbol=? AND phase='*'",
        ("2026-09-15T00:00:05+00:00", "QM5_9107", "XAUUSD.DWX"),
    )
    _cache_failure(conn, "three", "2026-09-15T00:00:06+00:00")
    after_release = quarantine.record_tester_cache_budget_hit(
        conn,
        "QM5_9107",
        "XAUUSD.DWX",
        evidence_path="evidence/three.json",
        now="2026-09-15T00:00:07+00:00",
    )
    assert after_release["active"] is False
    assert after_release["hit_count"] == 1


def _insert_farm_item(
    root: Path,
    item_id: str,
    *,
    status: str,
    claimed_by: str | None,
) -> None:
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.execute(
            """INSERT INTO work_items
               (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                created_at,updated_at)
               VALUES(?,?,?,?,?,?,?,NULL,0,NULL,NULL,?,?,?,?)""",
            (
                item_id,
                "backtest",
                "Q02",
                "QM5_9107",
                "XAUUSD.DWX",
                "fixture.set",
                status,
                claimed_by,
                json.dumps({"pid": 123456}),
                now,
                now,
            ),
        )
        conn.commit()


def test_worker_budget_abort_is_durable_infra_fail(
    tmp_path: Path, monkeypatch,
) -> None:
    root = tmp_path / "farm"
    report_root = tmp_path / "reports" / "cache-abort"
    _insert_farm_item(root, "cache-abort", status="active", claimed_by="T2")
    ledger = tmp_path / "cache-ledger.jsonl"
    monkeypatch.setenv("QM_TESTER_CACHE_BUDGET_LEDGER", str(ledger))
    state = {
        "schema": budget.SCHEMA,
        "enabled": True,
        "configured_budget_bytes": 10,
        "effective_budget_bytes": 10,
        "baseline_cache_bytes": 5,
        "last_cache_bytes": 17,
        "peak_growth_bytes": 12,
        "initial_free_bytes": 60 * budget.GIB,
        "minimum_free_bytes": 59 * budget.GIB,
        "samples": 2,
        "sample_errors": 0,
        "baseline_source": "pre_spawn",
    }
    decision = {
        "tripped": True,
        "trigger": "growth_budget",
        "verdict_reason": budget.VERDICT_REASON,
        "growth_bytes": 12,
        "free_bytes": 59 * budget.GIB,
        "disk_stop_bytes": 40 * budget.GIB,
    }

    result = terminal_worker._record_tester_cache_budget_exceeded(
        root,
        {
            "id": "cache-abort",
            "ea_id": "QM5_9107",
            "symbol": "XAUUSD.DWX",
            "phase": "Q02",
            "parent_task_id": None,
        },
        "T2",
        {"pid": 123456, "report_root": str(report_root)},
        state,
        decision,
        run_seconds=33.0,
        runner_stopped=True,
        terminal_stopped=True,
    )

    assert result["action"] == "tester_cache_budget_exceeded"
    assert result["status"] == "failed"
    assert result["verdict"] == "INFRA_FAIL"
    evidence_path = Path(result["evidence_path"])
    assert evidence_path.is_file()
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        row = conn.execute(
            "SELECT status,verdict,verdict_taxonomy,claimed_by,evidence_path,payload_json "
            "FROM work_items WHERE id='cache-abort'"
        ).fetchone()
    assert row[:4] == ("failed", "INFRA_FAIL", "infra", None)
    assert Path(row[4]) == evidence_path
    payload = json.loads(row[5])
    assert payload["verdict_reason"] == budget.VERDICT_REASON
    assert payload["tester_cache_pair_hold"]["hit_count"] == 1
    assert ledger.is_file()
    assert json.loads(ledger.read_text(encoding="utf-8"))["outcome"] == "budget_exceeded"


def test_pending_claim_sql_excludes_wildcard_pair_hold(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    _insert_farm_item(root, "pending", status="pending", claimed_by=None)
    with farmctl.connect(root) as conn:
        conn.execute(
            """INSERT INTO poison_pill_quarantine
               (ea_id,symbol,phase,active,verdict_reason,consecutive_failures,
                successes_ever,evidence_path,quarantined_at,updated_at)
               VALUES('QM5_9107','XAUUSD.DWX','*',1,?,2,0,'evidence.json',?,?)""",
            (budget.VERDICT_REASON, farmctl.utc_now(), farmctl.utc_now()),
        )
        rows = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    assert not any(str(row["id"]) == "pending" for row in rows)


def test_targeted_factory_off_claim_cannot_bypass_pair_hold(
    tmp_path: Path, monkeypatch,
) -> None:
    root = tmp_path / "farm"
    _insert_farm_item(root, "targeted", status="pending", claimed_by=None)
    (root / "state" / "FACTORY_OFF.flag").write_text("test\n", encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """INSERT INTO poison_pill_quarantine
               (ea_id,symbol,phase,active,verdict_reason,consecutive_failures,
                successes_ever,evidence_path,quarantined_at,updated_at)
               VALUES('QM5_9107','XAUUSD.DWX','*',1,?,2,0,'evidence.json',?,?)""",
            (budget.VERDICT_REASON, now, now),
        )
        conn.commit()
    monkeypatch.setattr(
        terminal_worker.farmctl,
        "_news_calendar_preflight",
        lambda **_kwargs: {"ok": True},
    )
    monkeypatch.setattr(terminal_worker, "_multisymbol_ea_ids", lambda: frozenset())

    result = terminal_worker.claim_specific_atomic(root, "T1", "targeted")

    assert result["claimed"] is False
    assert result["reason"] == "poison_pill_quarantined"
    assert result["quarantine"]["phase"] == "*"
