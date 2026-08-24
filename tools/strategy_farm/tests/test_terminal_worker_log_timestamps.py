"""at_utc completeness for cpu_high_pause / claim_declined (router task cf97e8c3).

Forensics 2026-08-24_throughput_forensics.md section 4: neither JSON line
carried a timestamp, so exact per-hour histograms could only be reconstructed
via fragile line-bracketing heuristics. This is a pure logging change -- no
behavior/threshold/sleep logic is touched, only an added "at_utc" field.
"""
import io
import json
import sys
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


def _iso_utc_or_fail(value):
    # datetime.fromisoformat parses the exact "at_utc" shape this repo already
    # uses elsewhere (datetime.now(timezone.utc).isoformat()); anything else
    # raises, which is what we want a broken emission to do here.
    parsed = datetime.fromisoformat(value)
    assert parsed.tzinfo is not None, "at_utc must be timezone-aware"


def test_claim_declined_emission_has_at_utc(monkeypatch):
    monkeypatch.setattr(terminal_worker.time, "sleep", lambda *a, **k: None)
    buf = io.StringIO()
    with redirect_stdout(buf):
        terminal_worker._pause_after_unclaimed(
            {"reason": "no_pending_claimable", "lock": None}, "T7"
        )
    lines = [ln for ln in buf.getvalue().splitlines() if ln.strip()]
    assert lines, "expected at least one emitted JSON line"
    payload = json.loads(lines[-1])
    assert payload["event"] == "claim_declined"
    assert "at_utc" in payload
    _iso_utc_or_fail(payload["at_utc"])
    # Unrelated fields are unchanged -- pure logging addition.
    assert payload["reason"] == "no_pending_claimable"
    assert payload["terminal"] == "T7"


def test_cpu_high_pause_emission_has_at_utc(monkeypatch, tmp_path):
    class _StopLoop(Exception):
        pass

    monkeypatch.setattr(terminal_worker, "_disk_free_gb", lambda root: 1_000.0)
    monkeypatch.setattr(terminal_worker, "_free_ram_gb", lambda: 64.0)
    monkeypatch.setattr(terminal_worker, "_cpu_load_percent", lambda: 99.9)
    terminal_worker._RESOURCE_LATCH["ram_low"] = False
    terminal_worker._RESOURCE_LATCH["cpu_high"] = False

    def _sleep_then_stop(*args, **kwargs):
        raise _StopLoop()

    monkeypatch.setattr(terminal_worker.time, "sleep", _sleep_then_stop)
    monkeypatch.setattr(terminal_worker, "_STOP", False)

    buf = io.StringIO()
    with redirect_stdout(buf):
        try:
            terminal_worker.run_loop(tmp_path, "T3", timeout_seconds=1)
        except _StopLoop:
            pass

    events = [json.loads(ln) for ln in buf.getvalue().splitlines() if ln.strip()]
    cpu_events = [e for e in events if e.get("event") == "cpu_high_pause"]
    assert cpu_events, f"expected a cpu_high_pause emission, got events={events}"
    payload = cpu_events[-1]
    assert "at_utc" in payload
    _iso_utc_or_fail(payload["at_utc"])
    assert payload["terminal"] == "T3"
    assert payload["hysteresis_latched"] is True
