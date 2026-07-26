"""Stopgap worker keeper for the dead InteractiveToken task class (2026-07-26).

WHY THIS EXISTS
---------------
After a Windows session handover, the Task Scheduler queues every
``LogonType=Interactive`` task forever instead of running it (event 110 then
325, never 200; ``LastTaskResult`` 0x800710E0). ``QM_StrategyFarm_WorkerDedupe``
is in that class, and ``factory_watchdog.ps1`` delegates ALL healing to it by
design — the watchdog runs as SYSTEM and must never spawn workers directly
because session-0 children die 0xC0000142. So while the class is dead the
factory has no working self-healing at all: on 2026-07-26 the fleet bled
9 -> 7 -> 6 repeatedly and only manual spawner runs restored it.

This keeper is the interim substitute, not the fix. The fix is ticket 7abd518a
(give the SYSTEM watchdog a WTSQueryUserToken + CreateProcessAsUser spawn path).
Delete this file once that lands.

WHAT IT DOES
------------
Runs inside the interactive factory session — which is the whole point, since a
worker spawned from here inherits a valid session handle. Every cycle it asks
``start_terminal_workers.py --dedupe`` to fill missing slots. That spawner is
idempotent (it only starts terminals with no live worker, and each worker holds
a named mutex, so duplicates are structurally impossible) and it never
interrupts a running backtest.

It stays out of the way of OWNER intent: while ``FACTORY_OFF.flag`` exists it
does nothing at all.

STOPPING IT
-----------
    Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" |
      Where-Object { $_.CommandLine -match 'interactive_worker_keeper' } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(r"C:\QM\repo")
FARM_ROOT = Path(r"D:\QM\strategy_farm")
SPAWNER = REPO_ROOT / "tools" / "strategy_farm" / "start_terminal_workers.py"
FACTORY_OFF_FLAG = FARM_ROOT / "state" / "FACTORY_OFF.flag"
LOG_PATH = FARM_ROOT / "logs" / "interactive_worker_keeper.log"
CYCLE_SECONDS = 60
CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
_WORKER_RE = re.compile(r"terminal_worker\.py.*--terminal\s+(T(?:[1-9]|10))\b", re.IGNORECASE)


def _log(event: str, **fields: object) -> None:
    line = json.dumps(
        {"ts": datetime.now(timezone.utc).isoformat(), "event": event, **fields},
        sort_keys=True,
    )
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass
    print(line, flush=True)


def _live_workers() -> set[str] | None:
    """Terminals with a live worker, or None when the probe itself failed.

    None must never be treated as "nothing is running" — that would spawn into
    a healthy fleet on a transient probe error.
    """
    command = (
        "Get-CimInstance Win32_Process -Filter \"Name='python.exe' OR Name='pythonw.exe'\" "
        "| Select-Object -ExpandProperty CommandLine"
    )
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=60,
            creationflags=CREATE_NO_WINDOW,
        )
    except Exception as exc:  # noqa: BLE001 - probe must never kill the keeper
        _log("probe_failed", error=str(exc))
        return None
    if result.returncode != 0:
        _log("probe_failed", returncode=result.returncode)
        return None
    found: set[str] = set()
    for line in (result.stdout or "").splitlines():
        match = _WORKER_RE.search(line)
        if match:
            found.add(match.group(1).upper())
    return found


def _expected_terminals() -> set[str]:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))
    import start_terminal_workers as spawner  # noqa: PLC0415 - path set above

    return set(spawner._installed_terminals(Path(r"D:\QM\mt5")))


def _run_spawner() -> str:
    proc = subprocess.run(
        [
            sys.executable,
            str(SPAWNER),
            "--repo-root", str(REPO_ROOT),
            "--farm-root", str(FARM_ROOT),
            "--dedupe",
        ],
        capture_output=True,
        text=True,
        errors="replace",
        timeout=300,
        creationflags=CREATE_NO_WINDOW,
    )
    return (proc.stdout or "").strip().splitlines()[-1] if proc.stdout.strip() else ""


def main() -> int:
    _log("keeper_start", cycle_seconds=CYCLE_SECONDS)
    while True:
        try:
            if FACTORY_OFF_FLAG.exists():
                _log("skip_factory_off")
            else:
                expected = _expected_terminals()
                live = _live_workers()
                if live is None:
                    _log("skip_probe_unknown")
                else:
                    missing = sorted(expected - live)
                    if missing:
                        _log("respawning", missing=missing, live=sorted(live))
                        _log("spawner_result", result=_run_spawner())
        except Exception as exc:  # noqa: BLE001 - the keeper must outlive any single cycle
            _log("cycle_error", error=repr(exc))
        time.sleep(CYCLE_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
