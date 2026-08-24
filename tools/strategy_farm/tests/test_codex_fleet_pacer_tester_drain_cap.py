"""Tests for the tester-drain Codex host cap (router task 32c7b01f), following
docs/ops/evidence/2026-08-24_throughput_forensics.md recommendation 4.

Pure decision-logic coverage plus one real-DB test for the active-count
reader. No process spawning, no farm mutation.
"""
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import codex_fleet_pacer as pacer  # noqa: E402


def test_tester_drain_saturated_below_threshold():
    assert pacer.tester_drain_saturated(6, threshold=7) is False


def test_tester_drain_saturated_at_threshold():
    assert pacer.tester_drain_saturated(7, threshold=7) is True


def test_tester_drain_saturated_above_threshold():
    assert pacer.tester_drain_saturated(9, threshold=7) is True


def test_tester_drain_saturated_fails_open_on_unreadable_signal():
    # None means the DB read failed -- must never block pacing.
    assert pacer.tester_drain_saturated(None, threshold=7) is False


def test_should_hold_false_when_drain_not_saturated():
    assert pacer.should_hold_for_tester_drain_cap(
        active_count=3, total_codex_hosts=20, threshold=7, max_hosts=8
    ) is False


def test_should_hold_false_when_saturated_but_hosts_below_ceiling():
    assert pacer.should_hold_for_tester_drain_cap(
        active_count=8, total_codex_hosts=5, threshold=7, max_hosts=8
    ) is False


def test_should_hold_true_when_saturated_and_hosts_at_ceiling():
    assert pacer.should_hold_for_tester_drain_cap(
        active_count=8, total_codex_hosts=8, threshold=7, max_hosts=8
    ) is True


def test_should_hold_true_when_saturated_and_hosts_above_ceiling():
    assert pacer.should_hold_for_tester_drain_cap(
        active_count=9, total_codex_hosts=22, threshold=7, max_hosts=8
    ) is True


def test_should_hold_false_when_signal_unreadable_even_with_many_hosts():
    assert pacer.should_hold_for_tester_drain_cap(
        active_count=None, total_codex_hosts=22, threshold=7, max_hosts=8
    ) is False


def test_tester_drain_cap_enabled_default(monkeypatch):
    monkeypatch.delenv(pacer.DISABLE_TESTER_DRAIN_CAP_ENV, raising=False)
    assert pacer.tester_drain_cap_enabled() is True


def test_tester_drain_cap_disabled_via_rollback_flag(monkeypatch):
    monkeypatch.setenv(pacer.DISABLE_TESTER_DRAIN_CAP_ENV, "1")
    assert pacer.tester_drain_cap_enabled() is False


def test_read_tester_drain_active_count_real_db(tmp_path):
    db_path = tmp_path / "farm_state.sqlite"
    conn = sqlite3.connect(db_path)
    conn.execute(
        "CREATE TABLE work_items (id TEXT PRIMARY KEY, status TEXT, phase TEXT)"
    )
    rows = [
        ("a", "active", "Q02"), ("b", "active", "Q07"), ("c", "pending", "Q02"),
        ("d", "active", "Q10_NEWS"), ("e", "done", "Q04"),
    ]
    conn.executemany("INSERT INTO work_items VALUES (?,?,?)", rows)
    conn.commit()
    conn.close()

    count = pacer.read_tester_drain_active_count(db_path)
    assert count == 3


def test_read_tester_drain_active_count_missing_db_fails_open(tmp_path):
    missing = tmp_path / "does_not_exist.sqlite"
    assert pacer.read_tester_drain_active_count(missing) is None
