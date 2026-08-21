from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import resource_headroom as headroom  # noqa: E402
import start_terminal_workers as starter  # noqa: E402


def snapshot(disk: float, ram: float, commit: float) -> dict:
    return {
        "schema": headroom.SCHEMA,
        "probe_ok": True,
        "disk_free_gb": disk,
        "ram_free_gb": ram,
        "commit_free_gb": commit,
        "errors": [],
    }


def test_simulated_low_headroom_throttles_new_workers_without_stopping_live_workers() -> None:
    decision = headroom.concurrency_decision(
        snapshot(45.0, 10.0, 30.0), installed_workers=10, running_workers=3
    )
    assert decision["state"] == "THROTTLED"
    assert decision["allow_new_workers"] is False
    assert decision["max_workers"] == 3
    discovered = {"T1": [101], "T2": [102], "T3": [103]}
    governed = starter._governed_terminals(starter.TERMINALS, discovered, decision)
    assert governed == ("T1", "T2", "T3")

    saturated = headroom.concurrency_decision(
        snapshot(45.0, 10.0, 30.0), installed_workers=10, running_workers=10
    )
    assert saturated["state"] == "THROTTLED"
    assert saturated["max_workers"] == 10  # observation/throttle, never an interrupt order
    assert saturated["allow_new_workers"] is False


def test_high_headroom_opens_all_installed_workers() -> None:
    decision = headroom.concurrency_decision(
        snapshot(200.0, 100.0, 120.0), installed_workers=10, running_workers=2
    )
    assert decision["state"] == "OPEN"
    assert decision["max_workers"] == 10
    assert decision["allow_new_workers"] is True


def test_probe_error_fails_closed_for_new_workers() -> None:
    decision = headroom.concurrency_decision(
        {"probe_ok": False, "disk_free_gb": None, "ram_free_gb": 20, "commit_free_gb": 40},
        installed_workers=10,
        running_workers=4,
    )
    assert decision["state"] == "TELEMETRY_ERROR"
    assert decision["max_workers"] == 4
    assert decision["allow_new_workers"] is False


def test_implausible_reclaim_is_a_telemetry_error() -> None:
    result = headroom.validate_reclaim(
        expected_deleted_bytes=512 * 1024 ** 2,
        free_before_gb=100.0,
        free_after_gb=115.0,
    )
    assert result["status"] == "TELEMETRY_ERROR"
    assert result["reason"] == "implausible_free_space_gain"


def test_plausible_reclaim_is_ok() -> None:
    result = headroom.validate_reclaim(
        expected_deleted_bytes=2 * 1024 ** 3,
        free_before_gb=100.0,
        free_after_gb=101.8,
    )
    assert result["status"] == "OK"


def test_purger_routes_observed_delta_through_the_validated_policy() -> None:
    source = (ROOT / "tools" / "strategy_farm" / "tester_cache_purge.ps1").read_text(
        encoding="utf-8"
    )
    assert "resource_headroom.py" in source
    assert "validate-reclaim" in source
    assert "TELEMETRY_ERROR scope=busy_scratch" in source
    assert "TELEMETRY_ERROR scope=idle_cache" in source
    assert "telemetry_status=" in source
    assert "before_bytes=" in source and "after_bytes=" in source
    assert "target_outside_tester_root" in source
    assert "if ($telemetryErrors.Count -gt 0) { exit 2 }" in source
