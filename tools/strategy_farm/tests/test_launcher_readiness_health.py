from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import silent_failure_monitor as monitor  # noqa: E402


def _journal(path: Path, *rows: dict) -> None:
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")


def test_current_boot_exit_two_remains_fail_after_verifier_repair(tmp_path: Path) -> None:
    journal = tmp_path / "launchers.jsonl"
    _journal(journal, {
        "launcher": "FTMO",
        "ts_utc": "2026-09-09T16:44:50.270Z",
        "exit_code": 2,
        "reason": "profile_contract_failed",
    })

    result = monitor.check_launcher_readiness(
        {"boot_utc": "2026-09-09T16:43:53Z"},
        launcher="FTMO",
        check_name="ftmo_launcher_readiness",
        verifier=tmp_path / "verifier.ps1",
        journal_path=journal,
        verifier_result=(0, "VERIFIED"),
    )

    assert result["status"] == monitor.FAIL
    assert result["value"] == 2
    assert "current-boot" in result["detail"]
    assert "next successful FTMO launcher run" in result["action_hint"]


def test_later_current_boot_exit_zero_clears_launcher_failure(tmp_path: Path) -> None:
    journal = tmp_path / "launchers.jsonl"
    _journal(
        journal,
        {"launcher": "FTMO", "ts_utc": "2026-09-09T16:44:50Z", "exit_code": 2, "reason": "profile_contract_failed"},
        {"launcher": "FTMO", "ts_utc": "2026-09-09T18:40:00Z", "exit_code": 0, "reason": "already_running"},
    )

    result = monitor.check_launcher_readiness(
        {"boot_utc": "2026-09-09T16:43:53Z"},
        launcher="FTMO",
        check_name="ftmo_launcher_readiness",
        verifier=tmp_path / "verifier.ps1",
        journal_path=journal,
        verifier_result=(0, "VERIFIED"),
    )

    assert result["status"] == monitor.OK
    assert result["value"] == 0


def test_nonzero_verifier_fails_even_after_successful_launcher(tmp_path: Path) -> None:
    journal = tmp_path / "launchers.jsonl"
    _journal(journal, {
        "launcher": "DXZ", "ts_utc": "2026-09-09T16:44:55Z", "exit_code": 0, "reason": "launched",
    })

    result = monitor.check_launcher_readiness(
        {"boot_utc": "2026-09-09T16:43:53Z"},
        launcher="DXZ",
        check_name="t_live_launcher_readiness",
        verifier=tmp_path / "verifier.ps1",
        journal_path=journal,
        verifier_result=(1, "contract mismatch"),
    )

    assert result["status"] == monitor.FAIL
    assert result["value"] == 1
    assert "verifier_rc=1" in result["detail"]
