"""Reservation-corpse class: holder-PID liveness pruning in farmctl.terminal_reservations.

Dead run_smoke pwsh holders left reservations blocking terminals for hours —
three recurrences on 2026-08-11 alone (T8 midday, T2/T7 evening, throughput
30/h -> 6/h). terminal_reservations() now drops entries whose PID-encoded
holder ('run_smoke:<pid>:<token>', framework/scripts/run_smoke.ps1:632) is
verifiably dead; ambiguity keeps the entry (fail conservative). OWNER-ratified
2026-08-11 ("Go, alles freigegeben"), evidence:
docs/ops/evidence/2026-08-11_ramp10_soak_evaluation.md
"""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _write_reservations(root: Path, entries: dict) -> None:
    path = root / farmctl.TERMINAL_RESERVATIONS_REL
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"reservations": entries}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _entry(reserved_by: str, minutes: int = 60) -> dict:
    now = dt.datetime.now(dt.timezone.utc)
    return {
        "terminal": "T1",
        "reserved_by": reserved_by,
        "reason": "run_smoke_custom_history_admission",
        "created_at_utc": now.isoformat(),
        "until_utc": (now + dt.timedelta(minutes=minutes)).isoformat(),
    }


def test_holder_pid_parser() -> None:
    assert farmctl._reservation_holder_pid("run_smoke:1234:abc") == 1234
    assert farmctl._reservation_holder_pid("run_smoke:12x4:abc") is None
    assert farmctl._reservation_holder_pid("codex-test") is None
    assert farmctl._reservation_holder_pid("run-smoke-owner") is None
    assert farmctl._reservation_holder_pid("") is None
    assert farmctl._reservation_holder_pid(None) is None


def test_dead_holder_reservation_pruned(tmp_path, monkeypatch) -> None:
    _write_reservations(tmp_path, {"T1": _entry("run_smoke:99999:tok")})
    monkeypatch.setattr(farmctl, "_reservation_holder_alive", lambda pid: False)
    assert farmctl.terminal_reservations(tmp_path) == {}
    assert farmctl.terminal_reservation(tmp_path, "T1") is None


def test_alive_holder_reservation_kept(tmp_path, monkeypatch) -> None:
    _write_reservations(tmp_path, {"T1": _entry("run_smoke:4242:tok")})
    monkeypatch.setattr(farmctl, "_reservation_holder_alive", lambda pid: True)
    assert "T1" in farmctl.terminal_reservations(tmp_path)


def test_ambiguous_liveness_keeps_reservation(tmp_path, monkeypatch) -> None:
    _write_reservations(tmp_path, {"T1": _entry("run_smoke:4242:tok")})
    monkeypatch.setattr(farmctl, "_reservation_holder_alive", lambda pid: None)
    assert "T1" in farmctl.terminal_reservations(tmp_path)


def test_non_pid_holder_stays_ttl_governed(tmp_path, monkeypatch) -> None:
    _write_reservations(tmp_path, {"T1": _entry("codex-test")})

    def _must_not_probe(pid):
        raise AssertionError("non-PID holders must not be liveness-probed")

    monkeypatch.setattr(farmctl, "_reservation_holder_alive", _must_not_probe)
    assert "T1" in farmctl.terminal_reservations(tmp_path)


def test_expired_entry_still_pruned_before_liveness(tmp_path, monkeypatch) -> None:
    _write_reservations(tmp_path, {"T1": _entry("run_smoke:4242:tok", minutes=-5)})
    monkeypatch.setattr(farmctl, "_reservation_holder_alive", lambda pid: True)
    assert farmctl.terminal_reservations(tmp_path) == {}


def test_real_probe_detects_own_process_and_exited_child() -> None:
    if sys.platform != "win32":
        assert farmctl._reservation_holder_alive(os.getpid()) is None
        return
    assert farmctl._reservation_holder_alive(os.getpid()) is True
    child = subprocess.Popen(
        [sys.executable, "-c", "pass"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    child.wait(timeout=30)
    # The Popen handle keeps the PID from being recycled, so the probe must see
    # a terminated (not STILL_ACTIVE) process.
    assert farmctl._reservation_holder_alive(child.pid) is False
