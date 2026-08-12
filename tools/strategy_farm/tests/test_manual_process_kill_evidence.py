from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import manual_process_kill_evidence as evidence


def _terminal_snapshot(path: str = r"C:\QM\mt5\T3\MT5_Base\terminal64.exe") -> dict:
    return {
        "process_id": 1234,
        "image_path": path,
        "command_line": f'"{path}" /portable',
        "process_created_at_utc": "2026-07-31T12:00:00Z",
    }


def _worker_snapshot() -> dict:
    return {
        "process_id": 2345,
        "image_path": (
            r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
        ),
        "command_line": (
            r"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe "
            r"-u C:\QM\repo\tools\strategy_farm\terminal_worker.py "
            r"--terminal T10 --root D:\QM\strategy_farm"
        ),
        "process_created_at_utc": "2026-07-31T12:01:00Z",
    }


def test_terminal_snapshot_requires_exact_path_anchor_and_excludes_live() -> None:
    normalized = evidence.validate_snapshot(_terminal_snapshot(), "terminal")
    assert normalized["terminal"] == "T3"
    assert normalized["path_anchored"] is True
    assert normalized["t_live_excluded"] is True

    with pytest.raises(evidence.ManualKillEvidenceError, match="T_Live"):
        evidence.validate_snapshot(
            _terminal_snapshot(r"C:\QM\mt5\T_Live\MT5_Base\terminal64.exe"),
            "terminal",
        )
    with pytest.raises(evidence.ManualKillEvidenceError, match="T1-T10"):
        evidence.validate_snapshot(
            _terminal_snapshot(r"C:\Temp\T3\terminal64.exe"),
            "terminal",
        )


def test_worker_snapshot_requires_canonical_script_and_terminal_binding() -> None:
    normalized = evidence.validate_snapshot(_worker_snapshot(), "worker")
    assert normalized["terminal"] == "T10"
    assert normalized["target_type"] == "worker"

    wrong = _worker_snapshot()
    wrong["command_line"] = wrong["command_line"].replace(
        r"C:\QM\repo\tools\strategy_farm\terminal_worker.py",
        r"C:\Temp\terminal_worker.py",
    )
    with pytest.raises(evidence.ManualKillEvidenceError, match="canonical"):
        evidence.validate_snapshot(wrong, "worker")


def test_record_is_durable_and_explicitly_non_destructive(tmp_path: Path) -> None:
    target = tmp_path / "manual_process_kills.jsonl"

    record = evidence.record_manual_kill_intent(
        process_id=1234,
        target_type="terminal",
        actor="codex-test",
        reason="OWNER-approved stuck terminal recovery",
        authority_ref="TASK-test-123",
        evidence_path=target,
        snapshot=_terminal_snapshot(),
    )

    persisted = [json.loads(line) for line in target.read_text(encoding="utf-8").splitlines()]
    assert persisted == [record]
    assert record["actor"] == "codex-test"
    assert record["reason"] == "OWNER-approved stuck terminal recovery"
    assert record["authority_ref"] == "TASK-test-123"
    assert record["recorder"]["process_mutated"] is False
    assert record["target"]["image_path"].startswith("C:\\QM\\mt5\\T3\\")


def test_recorder_source_has_no_process_termination_primitive() -> None:
    source = Path(evidence.__file__).read_text(encoding="utf-8").lower()
    forbidden = ("stop-process", "taskkill", "terminateprocess", ".kill(")
    assert all(token not in source for token in forbidden)
