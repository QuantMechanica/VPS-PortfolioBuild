"""Fleet-wide claim stagger + resource hysteresis (OWNER 2026-08-15).

The conftest autouse fixture zeroes CLAIM_SPACING_SECONDS for the rest of the
suite; these tests pin their own spacing explicitly.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker  # noqa: E402


def test_spacing_fails_open_without_ledger_history(monkeypatch):
    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 60.0)
    assert terminal_worker._claim_spacing_remaining_seconds(None, "2026-08-15T10:00:00+00:00") == 0.0
    assert terminal_worker._claim_spacing_remaining_seconds("", "2026-08-15T10:00:00+00:00") == 0.0


def test_spacing_fails_open_on_unparseable_ledger_timestamp(monkeypatch):
    # test_ultracode_wsa_claim seeds literal 't' / 'not-a-timestamp' rows; the
    # stagger is a ramp-shaping aid and must never wedge on such history.
    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 60.0)
    assert terminal_worker._claim_spacing_remaining_seconds("t", "2026-08-15T10:00:00+00:00") == 0.0


def test_spacing_blocks_inside_window_and_admits_after(monkeypatch):
    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 60.0)
    wait = terminal_worker._claim_spacing_remaining_seconds(
        "2026-08-15T10:00:00+00:00", "2026-08-15T10:00:10+00:00"
    )
    assert 49.0 < wait <= 50.0
    assert terminal_worker._claim_spacing_remaining_seconds(
        "2026-08-15T10:00:00+00:00", "2026-08-15T10:01:00+00:00"
    ) == 0.0


def test_spacing_handles_naive_utc_now_format(monkeypatch):
    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 60.0)
    wait = terminal_worker._claim_spacing_remaining_seconds(
        "2026-08-15T10:00:00", "2026-08-15T10:00:30"
    )
    assert 29.0 < wait <= 30.0


def test_spacing_fails_open_on_clock_skew(monkeypatch):
    monkeypatch.setattr(terminal_worker, "CLAIM_SPACING_SECONDS", 60.0)
    assert terminal_worker._claim_spacing_remaining_seconds(
        "2026-08-15T11:00:00+00:00", "2026-08-15T10:00:00+00:00"
    ) == 0.0


def test_resource_hysteresis_thresholds_are_ordered():
    # RAM resumes strictly ABOVE its trip floor; CPU resumes strictly BELOW
    # its trip ceiling — otherwise the latch degenerates to a plain threshold.
    assert terminal_worker.RAM_RESUME_FREE_GB > terminal_worker.RAM_MIN_FREE_GB
    assert terminal_worker.CPU_RESUME_LOAD_PERCENT < terminal_worker.CPU_MAX_LOAD_PERCENT


def test_cpu_load_percent_baseline_and_range():
    terminal_worker._CPU_SAMPLE_PREV.clear()
    assert terminal_worker._cpu_load_percent() == 0.0
    second = terminal_worker._cpu_load_percent()
    assert 0.0 <= second <= 100.0
