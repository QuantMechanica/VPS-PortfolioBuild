"""2026-09-04: farmctl._running_mt5_terminals enumerates terminal64.exe natively
(Toolhelp32 + QueryFullProcessImageNameW) instead of spawning PowerShell on
every worker claim iteration; the CIM scan remains the fallback."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import farmctl  # noqa: E402


def test_terminal_ids_parsed_from_image_paths():
    paths = [
        r"D:\QM\mt5\T1\terminal64.exe",
        r"D:\QM\mt5\T10\terminal64.exe",
        r"d:\qm\mt5\t7\TERMINAL64.EXE",
        r"C:\QM\mt5\T_Live\terminal64.exe",      # live terminal: never a factory id
        r"D:\QM\mt5\T13\terminal64.exe",          # outside T1..T12
        r"D:\QM\mt5\T2\metatester64.exe",         # tester, not the terminal
        "",
        None,
    ]
    assert farmctl._terminal_ids_from_image_paths(paths) == {"T1", "T10", "T7"}


@pytest.mark.skipif(sys.platform != "win32", reason="Toolhelp32 is Windows-only")
def test_native_enumeration_returns_a_set_of_factory_ids():
    result = farmctl._running_mt5_terminal_ids_native()
    assert result is None or isinstance(result, set)
    if result is not None:
        assert all(farmctl._MT5_TERMINAL_IMAGE_RE.search(f"\\{t}\\terminal64.exe") for t in result)


def test_running_terminals_prefers_native_and_caches(monkeypatch):
    monkeypatch.setattr(farmctl, "active_mt5_terminals", lambda: ["T1", "T2", "T3"])
    monkeypatch.setattr(farmctl, "_running_mt5_terminal_ids_native", lambda: {"T2", "T9"})
    calls = []
    monkeypatch.setattr(farmctl.subprocess, "run", lambda *a, **k: calls.append(a) or (_ for _ in ()).throw(AssertionError("PowerShell must not run when native works")))
    farmctl._running_mt5_cache["ts"] = 0.0
    farmctl._running_mt5_cache["value"] = None
    assert farmctl._running_mt5_terminals() == {"T2"}          # T9 is not an allowed terminal
    assert calls == []
    monkeypatch.setattr(farmctl, "_running_mt5_terminal_ids_native", lambda: {"T1"})
    assert farmctl._running_mt5_terminals() == {"T2"}          # served from the 4 s cache
    farmctl._running_mt5_cache["ts"] = 0.0
    assert farmctl._running_mt5_terminals() == {"T1"}


def test_running_terminals_falls_back_to_powershell_when_native_unavailable(monkeypatch):
    monkeypatch.setattr(farmctl, "active_mt5_terminals", lambda: ["T1", "T2"])
    monkeypatch.setattr(farmctl, "_running_mt5_terminal_ids_native", lambda: None)

    class _Proc:
        returncode = 0
        stdout = "T2\nT5\n"

    monkeypatch.setattr(farmctl.subprocess, "run", lambda *a, **k: _Proc())
    farmctl._running_mt5_cache["ts"] = 0.0
    farmctl._running_mt5_cache["value"] = None
    assert farmctl._running_mt5_terminals() == {"T2"}
