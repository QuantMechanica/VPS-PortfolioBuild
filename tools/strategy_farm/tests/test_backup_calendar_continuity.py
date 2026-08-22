from __future__ import annotations

import datetime as dt
from pathlib import Path

from tools.strategy_farm import silent_failure_monitor as monitor


def _write(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_missing_day_remains_alarm_after_later_success(tmp_path: Path) -> None:
    log = tmp_path / "backup.log"
    _write(
        log,
        [
            "=== QM nightly backup end 2026-08-17 04:46:00Z elapsed=00:01:00 failures=0 ===",
            "2026-08-18 05:00:06Z FATAL drive G: not available after 15min wait",
            "=== QM nightly backup end 2026-08-19 04:46:00Z elapsed=00:01:00 failures=0 ===",
        ],
    )
    result = monitor.check_backup_calendar_continuity(
        log,
        now=dt.datetime(2026, 8, 19, 7, tzinfo=dt.timezone.utc),
        start_date=dt.date(2026, 8, 18),
    )
    assert result["status"] == monitor.FAIL
    assert "2026-08-18" in result["detail"]
    assert "drive G:" in result["detail"]


def test_complete_date_sequence_is_ok(tmp_path: Path) -> None:
    log = tmp_path / "backup.log"
    _write(
        log,
        [
            "=== QM nightly backup end 2026-08-18 04:46:00Z elapsed=00:01:00 failures=0 ===",
            "=== QM nightly backup end 2026-08-19 04:46:00Z elapsed=00:01:00 failures=0 ===",
        ],
    )
    result = monitor.check_backup_calendar_continuity(
        log,
        now=dt.datetime(2026, 8, 19, 7, tzinfo=dt.timezone.utc),
        start_date=dt.date(2026, 8, 18),
    )
    assert result["status"] == monitor.OK


def test_current_day_is_not_due_before_cutoff(tmp_path: Path) -> None:
    log = tmp_path / "backup.log"
    _write(
        log,
        [
            "=== QM nightly backup end 2026-08-18 04:46:00Z elapsed=00:01:00 failures=0 ===",
            "=== QM nightly backup end 2026-08-19 04:46:00Z elapsed=00:01:00 failures=0 ===",
        ],
    )
    result = monitor.check_backup_calendar_continuity(
        log,
        now=dt.datetime(2026, 8, 20, 5, 59, tzinfo=dt.timezone.utc),
        start_date=dt.date(2026, 8, 18),
    )
    assert result["status"] == monitor.OK
