from __future__ import annotations

import datetime as dt
import os
from pathlib import Path

from tools.strategy_farm import health


def test_measured_incident_is_a_blocking_positive_control() -> None:
    result = health._evaluate_disk_scratch_rate(
        free_gb=112.0,
        measurement={
            "window_minutes": 20,
            "files": 646,
            "recent_gb": 32.67,
            "rate_gb_per_hour": 98.0,
            "read_errors": 0,
            "by_terminal": {"T6": {"files": 646, "gb": 29.19}},
        },
    )

    assert result["status"] == "FAIL"
    assert result["value"]["projected_runway_hours"] == 1.14
    assert "98.0GB/h" in result["detail"]


def test_measurement_is_confined_to_factory_agent_bar_scratch(tmp_path: Path) -> None:
    now = dt.datetime.now(dt.timezone.utc)
    in_scope = tmp_path / "T6" / "Tester" / "Agent-127.0.0.1-3003" / "temp" / "bar123.tmp"
    out_of_scope_live = tmp_path / "T_Live" / "Tester" / "Agent-127.0.0.1-3003" / "temp" / "bar456.tmp"
    out_of_scope_mask = tmp_path / "T6" / "Tester" / "Agent-127.0.0.1-3003" / "temp" / "ticks.tmp"
    for path in (in_scope, out_of_scope_live, out_of_scope_mask):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"x" * 1024)
        os.utime(path, (now.timestamp(), now.timestamp()))

    measured = health._measure_busy_scratch_writes(
        mt5_root=tmp_path,
        now=now,
        window_minutes=20,
    )

    assert measured["files"] == 1
    assert set(measured["by_terminal"]) == {"T6"}


def test_rate_runway_check_is_registered_as_blocking() -> None:
    matches = [row for row in health.ALL_CHECKS if row[0] == "disk_scratch_rate_runway"]
    assert matches == [("disk_scratch_rate_runway", health.chk_disk_scratch_rate_runway, False)]
