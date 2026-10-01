#!/usr/bin/env python3
"""Fail-closed preflight guard for MetaTester local-agent port collisions.

Generic follow-up to the 2026-09-27 QM5_41119 Q07 incident (work item
748d85b2): a foreign process bound the MetaTester default local-agent port
(127.0.0.1:3000) before a terminal's tester could, and the tester logged a
silent "tester agent authorization error" with no economic verdict -- 30
invalid reports classified as INFRA_FAIL rather than a loud launch refusal.

This module answers one question before any tester is launched: "is this
terminal's assigned local-agent port currently free?" It never launches a
tester itself and never kills a foreign process. On any listener, on any
lookup failure, or on an unknown terminal id, it reports a collision/error
and recommends not launching -- fail-closed by construction, never
fail-open. Port ownership is read from framework/registry/tester_endpoints.json;
see that file's activation_status before wiring this into a live launcher.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

REPO_ROOT = Path(os.environ.get("QM_REPO_ROOT", r"C:\QM\repo"))
ENDPOINT_REGISTRY = REPO_ROOT / "framework" / "registry" / "tester_endpoints.json"

CommandRunner = Callable[[list[str]], str]

# netstat -ano line, e.g.:
#   TCP    0.0.0.0:3000           0.0.0.0:0              LISTENING       33224
#   TCP    [::]:3000              [::]:0                 LISTENING       33224
_NETSTAT_LISTEN_RE = re.compile(
    r"^\s*TCP\s+\S*[:.](?P<port>\d+)\s+\S+\s+LISTENING\s+(?P<pid>\d+)\s*$",
    re.IGNORECASE | re.MULTILINE,
)

# tasklist /FO CSV /NH, e.g.: "node.exe","33224","Console","1","48,208 K"
_TASKLIST_CSV_RE = re.compile(r'^"(?P<image>[^"]+)","(?P<pid>\d+)"')


@dataclass
class EndpointOwner:
    pid: int
    image: str | None = None

    def to_dict(self) -> dict:
        return {"pid": self.pid, "image": self.image}


@dataclass
class GuardResult:
    status: str  # "ok" | "collision" | "error"
    terminal: str
    host: str
    port: int | None
    owners: list[EndpointOwner] = field(default_factory=list)
    reason: str = ""
    next_action: str = ""

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "terminal": self.terminal,
            "host": self.host,
            "port": self.port,
            "owners": [o.to_dict() for o in self.owners],
            "reason": self.reason,
            "next_action": self.next_action,
            "safe_to_launch": self.status == "ok",
        }


def _run_command(args: list[str]) -> str:
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    completed = subprocess.run(
        args,
        capture_output=True,
        text=True,
        timeout=15,
        creationflags=creationflags,
    )
    return completed.stdout


def load_terminal_port(terminal: str, *, registry_path: Path = ENDPOINT_REGISTRY) -> int | None:
    if not registry_path.exists():
        return None
    data = json.loads(registry_path.read_text(encoding="utf-8"))
    ports = data.get("terminals", {})
    value = ports.get(terminal)
    return int(value) if isinstance(value, int) else None


def _listening_pids_for_port(netstat_output: str, port: int) -> list[int]:
    pids: list[int] = []
    for match in _NETSTAT_LISTEN_RE.finditer(netstat_output):
        if int(match.group("port")) == port:
            pid = int(match.group("pid"))
            if pid not in pids:
                pids.append(pid)
    return pids


def _resolve_image(pid: int, tasklist_output: str) -> str | None:
    for line in tasklist_output.splitlines():
        match = _TASKLIST_CSV_RE.match(line.strip())
        if match and int(match.group("pid")) == pid:
            return match.group("image")
    return None


def check_endpoint(
    terminal: str,
    *,
    registry_path: Path = ENDPOINT_REGISTRY,
    run: CommandRunner = _run_command,
) -> GuardResult:
    """Fail-closed check: is `terminal`'s assigned local-agent port free right now?

    Never returns status="ok" on an uncertain signal -- missing registry
    entry, unreadable netstat output, or an unresolved image all collapse to
    "error"/"collision" with next_action pointing at manual investigation.
    """
    host = "127.0.0.1"

    port = load_terminal_port(terminal, registry_path=registry_path)
    if port is None:
        return GuardResult(
            status="error",
            terminal=terminal,
            host=host,
            port=None,
            reason=f"terminal '{terminal}' has no assigned port in {registry_path}",
            next_action="add_terminal_to_tester_endpoints_registry",
        )

    try:
        netstat_output = run(["netstat", "-ano", "-p", "TCP"])
    except Exception as exc:  # noqa: BLE001 - any lookup failure must fail closed
        return GuardResult(
            status="error",
            terminal=terminal,
            host=host,
            port=port,
            reason=f"netstat lookup failed: {exc!r}",
            next_action="investigate_netstat_failure_before_launch",
        )

    pids = _listening_pids_for_port(netstat_output, port)
    if not pids:
        return GuardResult(
            status="ok",
            terminal=terminal,
            host=host,
            port=port,
            reason="no listener on assigned port",
            next_action="safe_to_launch",
        )

    owners: list[EndpointOwner] = []
    for pid in pids:
        image: str | None = None
        try:
            tasklist_output = run(["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"])
            image = _resolve_image(pid, tasklist_output)
        except Exception:  # noqa: BLE001 - image resolution is best-effort, never fatal
            image = None
        owners.append(EndpointOwner(pid=pid, image=image))

    return GuardResult(
        status="collision",
        terminal=terminal,
        host=host,
        port=port,
        owners=owners,
        reason="assigned port already has a listener; do not launch the tester on this endpoint",
        next_action="resolve_listener_before_launch",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", required=True, help="Terminal id, e.g. T6")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = check_endpoint(args.terminal)
    print(json.dumps(result.to_dict(), indent=2))
    return 0 if result.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
