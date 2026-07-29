from __future__ import annotations

import json
from pathlib import Path

import pytest

from framework.scripts import reconcile_dispatch_state as rds


def _state(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "dedup": {
                    "open-a": {"terminal": "T1", "ts": 1, "job": {"ea_id": "QM5_1"}},
                    "open-b": {"terminal": "T2", "status": "scheduled", "ts": 2},
                    "done": {"terminal": "T1", "status": "complete", "completed_ts": 3},
                },
                "running": {"T1": 3, "T2": 3},
                "phase_matrix_index": {"QM5_1_v1_Q02": {"phase_verdict": "PASS"}},
                "pending_matrix_jobs": {},
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def test_plan_is_read_only_and_reports_inconsistent_capacity(tmp_path: Path) -> None:
    state = tmp_path / "dispatch_state.json"
    _state(state)
    before = rds.sha256_file(state)

    plan = rds.build_plan(state)

    assert plan["unfinished_count"] == 2
    assert plan["running_total"] == 6
    assert plan["capacity_counter_consistent"] is False
    assert rds.sha256_file(state) == before


def test_apply_archives_unfinished_and_preserves_phase_matrix(tmp_path: Path) -> None:
    state = tmp_path / "dispatch_state.json"
    _state(state)
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    backup = tmp_path / "dispatch_state.pre.json"
    phase_before = rds.canonical_sha256(json.loads(state.read_text())["phase_matrix_index"])

    result = rds.apply_reconciliation(
        state,
        expected_state_sha256=rds.sha256_file(state),
        factory_off_flag=flag,
        expected_factory_off_sha256=rds.sha256_file(flag),
        backup_path=backup,
        reason="unit test",
        process_probe=lambda: [],
    )

    assert backup.exists()
    updated = json.loads(state.read_text(encoding="utf-8"))
    assert set(updated["dedup"]) == {"done"}
    assert set(updated["dispatch_history"]) == {"open-a", "open-b"}
    assert updated["dispatch_history"]["open-a"]["status"] == "abandoned_factory_off"
    assert all(value == 0 for value in updated["running"].values())
    assert rds.canonical_sha256(updated["phase_matrix_index"]) == phase_before
    assert result["phase_matrix_sha256_after"] == phase_before
    assert result["unfinished_archived"] == 2


def test_apply_fails_closed_on_live_factory_process(tmp_path: Path) -> None:
    state = tmp_path / "dispatch_state.json"
    _state(state)
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")

    with pytest.raises(RuntimeError, match="still running"):
        rds.apply_reconciliation(
            state,
            expected_state_sha256=rds.sha256_file(state),
            factory_off_flag=flag,
            expected_factory_off_sha256=rds.sha256_file(flag),
            backup_path=tmp_path / "backup.json",
            reason="unit test",
            process_probe=lambda: [{"terminal": "T3", "pid": 42}],
        )
    assert not (tmp_path / "backup.json").exists()
    assert json.loads(state.read_text())["running"] == {"T1": 3, "T2": 3}


def test_apply_rejects_hash_drift_and_existing_backup(tmp_path: Path) -> None:
    state = tmp_path / "dispatch_state.json"
    _state(state)
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="SHA-256 mismatch"):
        rds.apply_reconciliation(
            state,
            expected_state_sha256="0" * 64,
            factory_off_flag=flag,
            expected_factory_off_sha256=rds.sha256_file(flag),
            backup_path=tmp_path / "backup.json",
            reason="unit test",
            process_probe=lambda: [],
        )
    backup = tmp_path / "backup.json"
    backup.write_text("do not overwrite", encoding="utf-8")
    with pytest.raises(FileExistsError):
        rds.apply_reconciliation(
            state,
            expected_state_sha256=rds.sha256_file(state),
            factory_off_flag=flag,
            expected_factory_off_sha256=rds.sha256_file(flag),
            backup_path=backup,
            reason="unit test",
            process_probe=lambda: [],
        )
