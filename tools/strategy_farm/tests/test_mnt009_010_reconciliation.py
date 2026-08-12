from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import reconcile_terminal_work_items as subject  # noqa: E402


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _runtime(tmp_path: Path, *, factory_off: bool = True) -> tuple[Path, Path, Path]:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    db = root / farmctl.DB_REL
    flag = farmctl.factory_off_flag_path(root)
    if factory_off:
        flag.write_text('{"off_at":"test"}\n', encoding="utf-8")
    return root, db, flag


def _insert_task(
    db: Path,
    task_id: str,
    *,
    kind: str = "backtest_q03",
    status: str = "pending",
    ea_id: str = "QM5_9001",
) -> None:
    now = "2026-07-29T10:00:00+00:00"
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            INSERT INTO tasks(id,kind,status,source_id,card_id,payload_json,created_at,updated_at)
            VALUES (?,?,?,NULL,?, ?,?,?)
            """,
            (
                task_id,
                kind,
                status,
                ea_id,
                json.dumps({"ea_id": ea_id, "phase": kind.replace("backtest_", "").upper()}),
                now,
                now,
            ),
        )
        conn.commit()


def _insert_work_item(
    db: Path,
    item_id: str,
    *,
    status: str,
    verdict: str | None,
    payload: dict | None = None,
    parent_id: str | None = None,
    phase: str = "Q03",
    symbol: str = "EURUSD.DWX",
    evidence_path: str | None = None,
) -> None:
    now = "2026-07-29T10:00:00+00:00"
    legacy_null = status in {"done", "failed"} and verdict is None
    with sqlite3.connect(db) as conn:
        if legacy_null:
            # Seed a pre-guard historical defect, then reinstall the forward
            # trigger immediately after the fixture insert.
            conn.execute("DROP TRIGGER trg_work_items_terminal_requires_verdict_insert")
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
            ) VALUES (?, 'backtest', ?, 'QM5_9001', ?, 'test.set', ?, ?, 0,
                      ?, ?, NULL, ?, ?, ?)
            """,
            (
                item_id,
                phase,
                symbol,
                status,
                verdict,
                parent_id,
                evidence_path,
                json.dumps(payload or {}, sort_keys=True),
                now,
                now,
            ),
        )
        conn.commit()
    if legacy_null:
        farmctl.init_db(db.parent.parent)


@pytest.mark.parametrize(
    ("reason", "category", "status", "verdict"),
    [
        (
            next(iter(subject.PARK_REASONS)),
            "NDX_HISTORY_REPAIR_PARK",
            "failed",
            "INFRA_FAIL",
        ),
        (
            subject.BASKET_SUPERSEDE_REASON,
            "CROSS_SECTIONAL_PAIR_SUPERSEDED",
            "done",
            "SUPERSEDED_BY_LOGICAL_BASKET",
        ),
        (
            subject.OWNER_RETIRE_REASON,
            "OWNER_USDJPY_ONLY_ADMISSION",
            "done",
            "RETIRE",
        ),
    ],
)
def test_null_taxonomy_is_exact_and_never_claims_test_evidence(
    reason: str, category: str, status: str, verdict: str
) -> None:
    row = {
        "status": "failed",
        "verdict": None,
        "payload_json": json.dumps({"invalidated_reason": reason}),
    }
    result = subject.classify_null_disposition(row)
    assert result["eligible"] is True
    assert result["category"] == category
    assert result["target_status"] == status
    assert result["target_verdict"] == verdict
    assert result["evidence_kind"] == "legacy_db_state_disposition_not_test_result"


def test_null_taxonomy_blocks_unknown_reason() -> None:
    row = {
        "status": "failed",
        "verdict": None,
        "payload_json": json.dumps({"invalidated_reason": "similar but unapproved"}),
    }
    result = subject.classify_null_disposition(row)
    assert result["eligible"] is False
    assert result["reason"] == "unknown_invalidated_reason"


def test_manifest_json_duplicate_keys_fail_closed(tmp_path: Path) -> None:
    manifest = tmp_path / "duplicate.json"
    manifest.write_text(
        '{"schema_version":"mnt009-010-reconciliation/v1",'
        '"schema_version":"mnt009-010-reconciliation/v1"}',
        encoding="utf-8",
    )
    with pytest.raises(subject.ReconciliationError, match="duplicate JSON object key"):
        subject._load_manifest(manifest)


def test_evidence_resolver_rejects_arbitrary_payload_path(tmp_path: Path) -> None:
    runtime = tmp_path / "farm"
    arbitrary = tmp_path / "outside" / "summary.json"
    arbitrary.parent.mkdir()
    arbitrary.write_text('{"verdict":"INFRA_FAIL"}\n', encoding="utf-8")
    assert subject.resolve_existing_evidence(
        {"summary_path": str(arbitrary), "report_root": str(arbitrary.parent)},
        work_item_id="wi-lineage",
        runtime_root=runtime,
    ) is None


def test_forward_trigger_rejects_terminal_transition_without_verdict(tmp_path: Path) -> None:
    _, db, _ = _runtime(tmp_path)
    _insert_work_item(db, "wi-open", status="pending", verdict=None)
    with sqlite3.connect(db) as conn, pytest.raises(
        sqlite3.IntegrityError, match="terminal work_item requires verdict"
    ):
        conn.execute("UPDATE work_items SET status='failed' WHERE id='wi-open'")


def test_forward_trigger_rejects_terminal_insert_without_verdict(tmp_path: Path) -> None:
    _, db, _ = _runtime(tmp_path)
    now = "2026-07-29T10:00:00+00:00"
    with sqlite3.connect(db) as conn, pytest.raises(
        sqlite3.IntegrityError, match="terminal work_item requires verdict"
    ):
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
            ) VALUES ('wi-bad-insert','backtest','Q03','QM5_9001','EURUSD.DWX',
                      'test.set','failed',NULL,0,NULL,NULL,NULL,'{}',?,?)
            """,
            (now, now),
        )


def test_versioned_parent_taxonomy_covers_stable_families_and_refuses_placeholder() -> None:
    assert farmctl.PARENT_CHILD_VERDICT_TAXONOMY_VERSION == "qm-parent-child-verdicts/v1"
    for verdict in (
        "PASS_SOFT",
        "PASS_LOWFREQ",
        "PASS_PORTFOLIO",
        "FAIL_HARD",
        "FAIL_PORTFOLIO",
        "RETIRE",
        "SUPERSEDED_BY_LOGICAL_BASKET",
    ):
        assert verdict in farmctl.CANONICAL_PARENT_CHILD_VERDICTS
    assert "PENDING_RUNNER" not in farmctl.CANONICAL_PARENT_CHILD_VERDICTS
    assert "WAITING_INPUT" not in farmctl.CANONICAL_PARENT_CHILD_VERDICTS


@pytest.mark.parametrize("verdict", [None, "PENDING_RUNNER", "FUTURE_UNKNOWN"])
def test_parent_cas_refuses_null_and_noncanonical_children(
    tmp_path: Path, verdict: str | None
) -> None:
    root, db, _ = _runtime(tmp_path)
    _insert_task(db, "parent-refused")
    _insert_work_item(
        db, "wi-refused", status="failed", verdict=verdict, parent_id="parent-refused"
    )
    result = farmctl.aggregate_finished_parent_cas(
        root, "parent-refused", source="test"
    )
    assert result["closed"] is False
    assert result["reason"] == "child_contract_refused"
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT status FROM tasks WHERE id='parent-refused'"
        ).fetchone()[0] == "pending"


def test_factory_off_parent_pass_is_closed_and_progression_durably_deferred(
    tmp_path: Path,
) -> None:
    root, db, _ = _runtime(tmp_path)
    _insert_task(db, "parent-pass")
    _insert_work_item(
        db, "wi-pass", status="done", verdict="PASS", parent_id="parent-pass"
    )
    result = farmctl.aggregate_finished_parent_cas(root, "parent-pass", source="test")
    assert result["closed"] is True
    assert result["verdict"] == "PASS"
    assert result["auto_next"] is None
    assert result["progression"]["status"] == "DEFERRED_FACTORY_OFF"
    assert result["progression"]["next_phase"] == "Q04"
    with sqlite3.connect(db) as conn:
        payload = json.loads(conn.execute(
            "SELECT payload_json FROM tasks WHERE id='parent-pass'"
        ).fetchone()[0])
        assert payload["classification"]["progression"]["status"] == "DEFERRED_FACTORY_OFF"
        assert conn.execute(
            "SELECT count(*) FROM tasks WHERE kind='backtest_q04'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT count(*) FROM parent_task_transition_ledger"
        ).fetchone()[0] == 1
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute("DELETE FROM parent_task_transition_ledger")


def test_parent_close_and_auto_enqueue_share_global_factory_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root, db, flag = _runtime(tmp_path, factory_off=False)
    assert not flag.exists()
    _insert_task(db, "parent-on")
    _insert_work_item(
        db, "wi-on", status="done", verdict="PASS", parent_id="parent-on"
    )
    observed: dict[str, bool] = {}

    def fake_enqueue(_root: Path, parent_id: str, phase: str) -> dict:
        observed["lock_held"] = farmctl.path_for_factory_flag(flag).is_file()
        assert parent_id == "parent-on"
        assert phase == "Q04"
        return {"enqueued": True, "task_id": "next", "work_items_created": []}

    monkeypatch.setattr(farmctl, "enqueue_backtest", fake_enqueue)
    result = farmctl.aggregate_finished_parent_cas(root, "parent-on", source="test")
    assert result["closed"] is True
    assert observed == {"lock_held": True}
    assert result["auto_next"]["task_id"] == "next"
    assert not farmctl.path_for_factory_flag(flag).exists()


def test_factory_off_appearing_after_parent_close_defers_without_enqueue(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root, db, flag = _runtime(tmp_path, factory_off=False)
    _insert_task(db, "parent-off-race")
    _insert_work_item(
        db,
        "wi-off-race",
        status="done",
        verdict="PASS",
        parent_id="parent-off-race",
    )
    original_progress = farmctl._auto_enqueue_parent_progression

    def inject_off_then_progress(_root: Path, result: dict) -> None:
        # Factory_OFF intentionally publishes its flag before waiting for the
        # mutation lock to drain. Simulate that exact interleaving.
        flag.write_text('{"off_at":"race"}\n', encoding="utf-8")
        original_progress(_root, result)

    def forbidden_enqueue(*_args, **_kwargs):
        raise AssertionError("next-phase enqueue crossed FACTORY_OFF")

    monkeypatch.setattr(farmctl, "_auto_enqueue_parent_progression", inject_off_then_progress)
    monkeypatch.setattr(farmctl, "enqueue_backtest", forbidden_enqueue)
    result = farmctl.aggregate_finished_parent_cas(
        root, "parent-off-race", source="off-race-test"
    )
    assert result["closed"] is True
    assert result["auto_next"] is None
    assert result["progression"]["status"] == "DEFERRED_FACTORY_OFF"
    with sqlite3.connect(db) as conn:
        payload = json.loads(conn.execute(
            "SELECT payload_json FROM tasks WHERE id='parent-off-race'"
        ).fetchone()[0])
        assert payload["classification"]["progression"]["status"] == "DEFERRED_FACTORY_OFF"
        assert conn.execute(
            "SELECT count(*) FROM tasks WHERE kind='backtest_q04'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT count(*) FROM parent_task_transition_ledger"
        ).fetchone()[0] == 2


def test_parent_cas_has_single_winner(tmp_path: Path) -> None:
    root, db, _ = _runtime(tmp_path)
    _insert_task(db, "parent-race")
    _insert_work_item(
        db, "wi-race", status="failed", verdict="INFRA_FAIL", parent_id="parent-race"
    )
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(
            lambda _: farmctl.aggregate_finished_parent_cas(
                root, "parent-race", source="race-test"
            ),
            range(2),
        ))
    assert sum(bool(result.get("closed")) for result in results) == 1
    assert {result["reason"] for result in results if not result.get("closed")} <= {
        "factory_mutation_lock_busy",
        "parent_already_done",
    }
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT count(*) FROM parent_task_transition_ledger"
        ).fetchone()[0] == 1

def test_plan_and_apply_bind_only_existing_artifact_and_close_after_null_migration(
    tmp_path: Path,
) -> None:
    root, db, flag = _runtime(tmp_path)
    report_root = root / "reports" / "work_items" / "wi-evidence"
    report_root.mkdir(parents=True)
    summary = report_root / "summary.json"
    summary.write_text('{"verdict":"INFRA_FAIL"}\n', encoding="utf-8")
    null_report_root = root / "reports" / "work_items" / "wi-null"
    null_report_root.mkdir(parents=True)
    null_summary = null_report_root / "summary.json"
    null_summary.write_text('{"verdict":"INFRA_FAIL"}\n', encoding="utf-8")

    _insert_task(db, "parent-null")
    _insert_work_item(
        db,
        "wi-null",
        status="failed",
        verdict=None,
        payload={
            "invalidated_reason": next(iter(subject.PARK_REASONS)),
            "report_root": str(null_report_root),
        },
        parent_id="parent-null",
        symbol="NDX.DWX",
    )
    _insert_work_item(
        db,
        "wi-evidence",
        status="failed",
        verdict="INFRA_FAIL",
        payload={"report_root": str(report_root)},
    )
    _insert_work_item(
        db,
        "wi-missing",
        status="failed",
        verdict="INVALID",
        payload={"report_root": str(tmp_path / "does-not-exist")},
    )

    plan = subject.plan_reconciliation(db, flag)
    assert plan["apply_ready"] is True
    assert plan["census"]["terminal_null_verdict_rows"] == 1
    assert plan["census"]["existing_evidence_bindings_planned"] == 2
    assert plan["census"]["evidence_bindings_inside_null_dispositions"] == 1
    assert plan["census"]["evidence_still_unbound"] == 1
    assert plan["census"]["evidence_binding_status"] == "PARTIAL"
    assert plan["apply_scope_status"] == "SAFE_PARTIAL_RECONCILIATION"
    assert plan["maintenance_status"]["MNT-009"]["status"] == "PARTIAL"
    assert plan["census"]["parent_closures_planned_after_mnt009"] == 1
    assert plan["parent_close_operations"][0]["target"]["verdict"] == "INFRA_FAIL"
    manifest = tmp_path / "plan.json"
    subject.write_json_atomic(manifest, plan)
    snapshot = tmp_path / "pre.sqlite"
    receipt = tmp_path / "receipt.json"

    result = subject.apply_manifest(
        manifest_path=manifest,
        expected_manifest_sha256=_sha(manifest),
        expected_db_file_sha256=plan["database"]["file_sha256"],
        expected_db_logical_sha256=plan["database"]["logical_sha256"],
        expected_factory_off_sha256=plan["factory_off"]["sha256"],
        snapshot_path=snapshot,
        receipt_path=receipt,
    )
    assert result["operation_counts"] == {
        "evidence_bindings": 2,
        "null_dispositions": 1,
        "parent_closures": 1,
    }
    assert result["auto_enqueue_during_factory_off"] is False
    assert result["maintenance_status"]["MNT-009"]["status"] == "PARTIAL"
    assert result["maintenance_status"]["MNT-010"]["status"] == "COMPLETED_RUNTIME"
    assert snapshot.is_file() and receipt.is_file()
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        null_row = conn.execute("SELECT * FROM work_items WHERE id='wi-null'").fetchone()
        evidence_row = conn.execute(
            "SELECT * FROM work_items WHERE id='wi-evidence'"
        ).fetchone()
        missing_row = conn.execute(
            "SELECT * FROM work_items WHERE id='wi-missing'"
        ).fetchone()
        parent = conn.execute("SELECT * FROM tasks WHERE id='parent-null'").fetchone()
        assert (null_row["status"], null_row["verdict"], null_row["evidence_path"]) == (
            "failed",
            "INFRA_FAIL",
            str(null_summary),
        )
        disposition = json.loads(null_row["payload_json"])["mnt009_legacy_disposition"]
        assert disposition["evidence_kind"] == "legacy_db_state_disposition_not_test_result"
        assert evidence_row["evidence_path"] == str(summary)
        assert missing_row["evidence_path"] is None
        assert parent["status"] == "done"
        assert json.loads(parent["payload_json"])["classification"]["verdict"] == "INFRA_FAIL"
        assert conn.execute(
            "SELECT count(*) FROM work_item_transition_ledger"
        ).fetchone()[0] == 2
        assert conn.execute(
            "SELECT count(*) FROM parent_task_transition_ledger"
        ).fetchone()[0] == 1

    post_plan = subject.plan_reconciliation(db, flag, scan_evidence=False)
    assert post_plan["census"]["terminal_null_verdict_rows"] == 0
    assert post_plan["census"]["physical_parent_zombies"] == 0
    assert post_plan["maintenance_status"]["MNT-009"]["null_verdict_scope"] == (
        "NO_ACTION_REQUIRED"
    )
    assert post_plan["maintenance_status"]["MNT-010"]["status"] == (
        "NO_ACTION_REQUIRED"
    )


def test_apply_rejects_manifest_hash_before_database_mutation(tmp_path: Path) -> None:
    _, db, flag = _runtime(tmp_path)
    plan = subject.plan_reconciliation(db, flag)
    manifest = tmp_path / "plan.json"
    subject.write_json_atomic(manifest, plan)
    before = subject.sqlite_logical_sha256(db)
    with pytest.raises(subject.ReconciliationError, match="manifest SHA-256"):
        subject.apply_manifest(
            manifest_path=manifest,
            expected_manifest_sha256="0" * 64,
            expected_db_file_sha256=plan["database"]["file_sha256"],
            expected_db_logical_sha256=plan["database"]["logical_sha256"],
            expected_factory_off_sha256=plan["factory_off"]["sha256"],
            snapshot_path=tmp_path / "pre.sqlite",
            receipt_path=tmp_path / "receipt.json",
        )
    assert subject.sqlite_logical_sha256(db) == before
    assert not (tmp_path / "pre.sqlite").exists()
