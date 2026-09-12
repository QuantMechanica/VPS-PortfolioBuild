from __future__ import annotations

import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.dukascopy import monthly_refresh as refresh


NOW = dt.datetime(2026, 9, 12, 12, 0, tzinfo=dt.timezone.utc)


def _approval(tmp_path: Path) -> tuple[Path, Path, Path]:
    farm = tmp_path / "farm"
    state = farm / "state"
    state.mkdir(parents=True)
    off = state / "FACTORY_OFF.flag"
    off.write_bytes(b"governed pause\n")
    p3 = tmp_path / "p3.json"
    p3.write_text(json.dumps({"status": "PASS", "pass_count": 37}), encoding="utf-8")
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "archive_write_authorized": True,
                "refresh_month": "2026-08",
                "target_year": 2026,
            }
        ),
        encoding="utf-8",
    )
    approval = {
        "schema_version": refresh.SCHEMA,
        "decision_id": "OWNER-DEC-DUKASCOPY-MONTHLY-20260912",
        "owner_signature": "OWNER fixture",
        "claude_review_task_id": "review-fixture",
        "claude_review_verdict": "APPROVED",
        "signed_at_utc": "2026-09-12T10:00:00+00:00",
        "window_start_utc": "2026-09-12T11:00:00+00:00",
        "window_end_utc": "2026-09-12T13:00:00+00:00",
        "refresh_month": "2026-08",
        "archive_write_authorized": True,
        "factory_off_sha256": refresh.sha256_file(off),
        "p3_summary_path": str(p3),
        "p3_summary_sha256": refresh.sha256_file(p3),
        "manifest_update_path": str(manifest),
        "manifest_update_sha256": refresh.sha256_file(manifest),
        "approval_sha256": "",
    }
    approval["approval_sha256"] = hashlib.sha256(
        refresh.canonical_bytes(approval, omit="approval_sha256")
    ).hexdigest()
    path = tmp_path / "approval.json"
    path.write_text(json.dumps(approval), encoding="utf-8")
    return farm, off, path


def test_previous_month_handles_year_boundary() -> None:
    assert refresh.previous_month(dt.date(2026, 1, 3)) == "2025-12"
    assert refresh.previous_month(dt.date(2026, 9, 3)) == "2026-08"


def test_default_invocation_is_off_and_writes_no_artifact(capsys) -> None:
    assert refresh.main(["--refresh-month", "2026-08"]) == 0
    result = json.loads(capsys.readouterr().out)
    assert result["status"] == "DEFAULT_OFF"
    assert result["archive_write_performed"] is False


def test_valid_signed_update_authenticates(tmp_path: Path) -> None:
    _farm, off, approval = _approval(tmp_path)
    result = refresh.validate_approval(
        approval, refresh_month="2026-08", factory_off_path=off, now=NOW
    )
    assert result["archive_write_authorized"] is True


def test_missing_or_changed_manifest_hash_fails_closed(tmp_path: Path) -> None:
    _farm, off, approval = _approval(tmp_path)
    payload = json.loads(approval.read_text(encoding="utf-8"))
    payload["manifest_update_sha256"] = "0" * 64
    payload["approval_sha256"] = hashlib.sha256(
        refresh.canonical_bytes(payload, omit="approval_sha256")
    ).hexdigest()
    approval.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(refresh.RefreshError, match="manifest_update hash mismatch"):
        refresh.validate_approval(
            approval, refresh_month="2026-08", factory_off_path=off, now=NOW
        )


def test_active_claim_count_is_read_only(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    with sqlite3.connect(database) as conn:
        conn.execute("CREATE TABLE work_items(status TEXT)")
        conn.executemany("INSERT INTO work_items VALUES(?)", [("active",), ("pending",)])
    before = database.read_bytes()
    assert refresh.active_claim_count(database) == 1
    assert database.read_bytes() == before


def test_archive_year_lock_rejects_concurrent_writer(tmp_path: Path) -> None:
    lock = tmp_path / "state" / "year.lock"
    descriptor = refresh.acquire_year_lock(lock, {"writer": "first"})
    try:
        with pytest.raises(refresh.RefreshError, match="already held"):
            refresh.acquire_year_lock(lock, {"writer": "second"})
    finally:
        refresh.release_year_lock(lock, descriptor)


def test_t_live_paths_are_forbidden(tmp_path: Path) -> None:
    with pytest.raises(refresh.RefreshError, match="T_Live"):
        refresh._assert_safe_path(Path(r"D:\QM\mt5\T_Live\Bases\Custom"), "output")


def test_scheduler_definition_is_double_default_off() -> None:
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / "config" / "monthly_refresh.task.json").read_text())
    installer = (root / "install_monthly_refresh_task.ps1").read_text(encoding="utf-8")
    assert config["status"] == "PROPOSED_DISABLED"
    assert config["execution"]["default_result"] == "DEFAULT_OFF"
    assert "<Enabled>false</Enabled>" in installer
    assert "Disable-ScheduledTask" in installer
    assert "Start-ScheduledTask" not in installer
