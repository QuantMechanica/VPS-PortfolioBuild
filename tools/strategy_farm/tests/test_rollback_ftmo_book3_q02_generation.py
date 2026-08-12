import copy
import json
import shutil
import sqlite3
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import rollback_ftmo_book3_q02_generation as subject  # noqa: E402


def _create_db(path: Path) -> None:
    with sqlite3.connect(path) as conn:
        conn.executescript(
            """
            CREATE TABLE work_items (
                id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
                ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
                status TEXT NOT NULL, verdict TEXT, attempt_count INTEGER NOT NULL,
                parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
                payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            );
            CREATE TABLE work_item_holds (
                work_item_id TEXT PRIMARY KEY, hold_code TEXT NOT NULL, reason TEXT NOT NULL,
                active INTEGER NOT NULL, release_on_restart INTEGER NOT NULL,
                created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                released_at TEXT, release_note TEXT
            );
            CREATE TABLE unrelated (id INTEGER PRIMARY KEY, value TEXT NOT NULL);
            INSERT INTO unrelated(id,value) VALUES(1,'preserve-me');
            """
        )


def _insert_generation(path: Path) -> list[dict]:
    operations = []
    with sqlite3.connect(path) as conn:
        conn.row_factory = sqlite3.Row
        for sequence, rung in enumerate(subject.EXPECTED_RUNGS):
            work_id = f"work-{sequence}"
            payload = json.dumps(
                {
                    "measurement_contract": subject.base.FIDELITY_MEASUREMENT_CONTRACT,
                    "measurement_rung": rung,
                    "measurement_sequence": sequence,
                },
                sort_keys=True,
            )
            values = (
                work_id,
                "backtest",
                "Q02",
                "QM5_9936",
                "USDJPY.DWX",
                f"set-{sequence}.set",
                "pending",
                None,
                0,
                None,
                None,
                None,
                payload,
                "2026-07-29T00:00:00+00:00",
                "2026-07-29T00:00:00+00:00",
            )
            conn.execute(
                f"INSERT INTO work_items VALUES({','.join('?' for _ in values)})",
                values,
            )
            hold_values = (
                work_id,
                subject.base.HOLD_CODE,
                subject.base.HOLD_REASON,
                1,
                0,
                "2026-07-29T00:00:00+00:00",
                "2026-07-29T00:00:00+00:00",
                None,
                None,
            )
            conn.execute(
                f"INSERT INTO work_item_holds VALUES({','.join('?' for _ in hold_values)})",
                hold_values,
            )
            work = subject._row_dict(conn, "work_items", "id", work_id)
            hold = subject._row_dict(
                conn, "work_item_holds", "work_item_id", work_id
            )
            operations.append(
                {
                    "sequence": sequence,
                    "measurement_rung": rung,
                    "work_item_id": work_id,
                    "work_item_preimage": work,
                    "hold_preimage": hold,
                }
            )
    return operations


def _plan(tmp_path: Path, db: Path, baseline: Path, flag: Path, operations: list[dict]) -> dict:
    plan = {
        "schema": subject.SCHEMA_PLAN,
        "mode": "dry-run",
        "generated_at_utc": "2026-07-29T00:00:00+00:00",
        "root": str(tmp_path),
        "repo": str(tmp_path),
        "db": {
            "path": str(db),
            "logical_state_sha256": subject.base.sqlite_state_sha256(db),
        },
        "factory_off": {
            "path": str(flag),
            "exists": True,
            "sha256": subject.base.sha256_file(flag),
        },
        "source": {"source_commit": "a" * 40, "head_commit": "a" * 40},
        "prepare_plan_id": "prepare-plan",
        "prepare_snapshot_baseline_manifest_sha256": subject._canonical_sha(
            subject._logical_manifest(baseline)
        ),
        "current_without_generation_manifest_sha256": subject._canonical_sha(
            subject._logical_manifest(
                db,
                exclude_work_item_ids={operation["work_item_id"] for operation in operations},
            )
        ),
        "factory_processes": [],
        "artifacts": [],
        "operation_count": 6,
        "operations": operations,
        "safety": {
            "deletes_only_exact_six_work_items_and_six_holds": True,
            "preserves_all_runtime_artifacts": True,
            "factory_remains_off": True,
            "runs_mt5": False,
        },
        "errors": [],
        "valid": True,
    }
    subject._assign_plan_id(plan)
    return plan


def _write_plan(path: Path, plan: dict) -> str:
    path.write_text(
        json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return subject.base.sha256_file(path)


def _patch_apply_environment(
    monkeypatch: pytest.MonkeyPatch, plan: dict
) -> None:
    roles = {
        "rollback_controller",
        "prepare_controller",
        "factory_mutation_lock",
        "isolated_runner",
        "prepare_manifest",
        "prepare_receipt",
        "prepare_pre_snapshot",
        "failed_runner_receipt",
        "failed_runner_pre_snapshot",
        "failed_runner_worker_log",
        "failed_runner_harvest",
        "failed_runner_report_tree",
    }
    monkeypatch.setattr(subject, "_source_identity", lambda *_args, **_kwargs: {})
    monkeypatch.setattr(subject, "_verify_artifacts", lambda _plan: None)
    monkeypatch.setattr(
        subject,
        "_artifact_map",
        lambda _artifacts: {role: {"path": role} for role in roles},
    )
    monkeypatch.setattr(subject, "build_plan", lambda **_kwargs: copy.deepcopy(plan))
    monkeypatch.setattr(subject.base, "_factory_processes", lambda: [])
    monkeypatch.setattr(
        subject.base, "DEFAULT_ARTIFACT_ROOT", Path(str(plan["root"]))
    )


def test_logical_manifest_exclusion_proves_only_generation_diff(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline.sqlite"
    current = tmp_path / "current.sqlite"
    _create_db(baseline)
    shutil.copy2(baseline, current)
    operations = _insert_generation(current)

    excluded = {operation["work_item_id"] for operation in operations}
    assert subject._logical_manifest(
        current, exclude_work_item_ids=excluded
    ) == subject._logical_manifest(baseline)
    assert subject._logical_manifest(current) != subject._logical_manifest(baseline)


def test_historical_snapshot_rejects_nonempty_wal_sidecar(tmp_path: Path) -> None:
    snapshot = tmp_path / "historical.sqlite"
    _create_db(snapshot)
    Path(str(snapshot) + "-wal").write_bytes(b"unbound-wal")

    with pytest.raises(subject.ContractError, match="non-empty WAL"):
        subject._logical_manifest(snapshot, immutable=True)


def test_apply_deletes_only_bound_preimages_and_restores_logical_baseline(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    baseline = tmp_path / "baseline.sqlite"
    current = tmp_path / "current.sqlite"
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text("OFF\n", encoding="utf-8")
    _create_db(baseline)
    shutil.copy2(baseline, current)
    operations = _insert_generation(current)
    plan = _plan(tmp_path, current, baseline, flag, operations)
    manifest = tmp_path / "plan.json"
    manifest_sha = _write_plan(manifest, plan)
    _patch_apply_environment(monkeypatch, plan)

    receipt = subject.apply_plan(
        manifest_path=manifest,
        expected_manifest_sha256=manifest_sha,
        confirm_plan_id=plan["plan_id"],
        expected_factory_off_sha256=plan["factory_off"]["sha256"],
        expected_db_state_sha256=plan["db"]["logical_state_sha256"],
        expected_source_commit="a" * 40,
        snapshot_path=tmp_path / "runtime" / "rollback-pre.sqlite",
        receipt_path=tmp_path / "runtime" / "rollback-receipt.json",
    )

    assert receipt["action"] == "rollback_failed_generation"
    assert len(receipt["deleted_work_items"]) == 6
    assert len(receipt["deleted_holds"]) == 6
    assert subject._logical_manifest(current) == subject._logical_manifest(baseline)
    with sqlite3.connect(current) as conn:
        assert conn.execute("SELECT value FROM unrelated WHERE id=1").fetchone()[0] == "preserve-me"
        assert conn.execute("SELECT count(*) FROM work_items").fetchone()[0] == 0
        assert conn.execute("SELECT count(*) FROM work_item_holds").fetchone()[0] == 0


def test_full_preimage_drift_refuses_without_deleting_generation(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    baseline = tmp_path / "baseline.sqlite"
    current = tmp_path / "current.sqlite"
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text("OFF\n", encoding="utf-8")
    _create_db(baseline)
    shutil.copy2(baseline, current)
    operations = _insert_generation(current)
    with sqlite3.connect(current) as conn:
        conn.execute(
            "UPDATE work_items SET updated_at='drift' WHERE id=?",
            (operations[0]["work_item_id"],),
        )
    plan = _plan(tmp_path, current, baseline, flag, operations)
    manifest = tmp_path / "plan.json"
    manifest_sha = _write_plan(manifest, plan)
    _patch_apply_environment(monkeypatch, plan)

    with pytest.raises(subject.ContractError, match="work item full-preimage drift"):
        subject.apply_plan(
            manifest_path=manifest,
            expected_manifest_sha256=manifest_sha,
            confirm_plan_id=plan["plan_id"],
            expected_factory_off_sha256=plan["factory_off"]["sha256"],
            expected_db_state_sha256=plan["db"]["logical_state_sha256"],
            expected_source_commit="a" * 40,
            snapshot_path=tmp_path / "runtime" / "rollback-pre.sqlite",
            receipt_path=tmp_path / "runtime" / "rollback-receipt.json",
        )

    with sqlite3.connect(current) as conn:
        assert conn.execute("SELECT count(*) FROM work_items").fetchone()[0] == 6
        assert conn.execute("SELECT count(*) FROM work_item_holds").fetchone()[0] == 6


def test_rehashed_manifest_with_empty_artifact_set_is_rejected_before_outputs(
    tmp_path: Path,
) -> None:
    baseline = tmp_path / "baseline.sqlite"
    current = tmp_path / "current.sqlite"
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text("OFF\n", encoding="utf-8")
    _create_db(baseline)
    shutil.copy2(baseline, current)
    operations = _insert_generation(current)
    plan = _plan(tmp_path, current, baseline, flag, operations)
    assert plan["artifacts"] == []
    manifest = tmp_path / "plan.json"
    manifest_sha = _write_plan(manifest, plan)

    with pytest.raises(subject.ContractError, match="artifact role set is not exact"):
        subject.apply_plan(
            manifest_path=manifest,
            expected_manifest_sha256=manifest_sha,
            confirm_plan_id=plan["plan_id"],
            expected_factory_off_sha256=plan["factory_off"]["sha256"],
            expected_db_state_sha256=plan["db"]["logical_state_sha256"],
            expected_source_commit="a" * 40,
            snapshot_path=tmp_path / "must-not-exist.sqlite",
            receipt_path=tmp_path / "must-not-exist.json",
        )

    assert not (tmp_path / "must-not-exist.sqlite").exists()
    assert not (tmp_path / "must-not-exist.json").exists()
    assert not (tmp_path / "must-not-exist.json.intent.json").exists()
