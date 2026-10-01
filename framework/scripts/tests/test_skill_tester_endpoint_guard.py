from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.skill_tester_endpoint_guard import (
    check_endpoint,
    load_terminal_port,
)

# Reproduces the decisive netstat state from the 2026-09-27 QM5_41119 Q07
# incident: a foreign node.exe (PID 33224) listening on port 3000 on both
# the wildcard and dual-stack addresses, observed in
# docs/ops/evidence/2026-09-26_astra_takeover/q07_41119_infra_recovery/diagnostic.json.
INCIDENT_NETSTAT = """
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       1200
  TCP    0.0.0.0:3000           0.0.0.0:0              LISTENING       33224
  TCP    [::]:3000              [::]:0                 LISTENING       33224
  TCP    127.0.0.1:3006         0.0.0.0:0              LISTENING       16344
"""

INCIDENT_TASKLIST_3000 = '"node.exe","33224","Console","1","48,208 K"\n'
INCIDENT_TASKLIST_3006 = '"metatester64.exe","16344","Console","1","61,440 K"\n'

FREE_NETSTAT = """
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       1200
"""


def _registry(tmpdir: str, terminals: dict[str, int] | None = None) -> Path:
    path = Path(tmpdir) / "tester_endpoints.json"
    path.write_text(
        json.dumps({"terminals": terminals if terminals is not None else {"T6": 3006}}),
        encoding="utf-8",
    )
    return path


class TesterEndpointGuardTests(unittest.TestCase):
    def test_registry_assigns_distinct_ports_per_terminal(self) -> None:
        registry_path = Path("framework/registry/tester_endpoints.json")
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        ports = list(data["terminals"].values())
        self.assertEqual(len(ports), len(set(ports)), "terminal ports must be pairwise distinct")
        self.assertNotIn(3000, ports, "the historical default port must stay unassigned as a collision signal")

    def test_free_port_is_safe_to_launch(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            registry_path = _registry(tmpdir)

            def run(args: list[str]) -> str:
                self.assertEqual(args[0], "netstat")
                return FREE_NETSTAT

            result = check_endpoint("T6", registry_path=registry_path, run=run)

        self.assertEqual(result.status, "ok")
        self.assertTrue(result.to_dict()["safe_to_launch"])
        self.assertEqual(result.owners, [])

    def test_foreign_listener_fails_closed_with_owner_identity(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            registry_path = _registry(tmpdir, {"T6": 3000})

            def run(args: list[str]) -> str:
                if args[0] == "netstat":
                    return INCIDENT_NETSTAT
                return INCIDENT_TASKLIST_3000

            result = check_endpoint("T6", registry_path=registry_path, run=run)

        self.assertEqual(result.status, "collision")
        self.assertFalse(result.to_dict()["safe_to_launch"])
        self.assertEqual(len(result.owners), 1)
        self.assertEqual(result.owners[0].pid, 33224)
        self.assertEqual(result.owners[0].image, "node.exe")

    def test_self_owned_listener_still_fails_closed(self) -> None:
        # Even a legitimate MetaTester still bound on the same port (e.g. a
        # previous run that did not clean up) must block a fresh launch --
        # the guard never guesses which listener is "safe to share".
        with tempfile.TemporaryDirectory() as tmpdir:
            registry_path = _registry(tmpdir, {"T6": 3006})

            def run(args: list[str]) -> str:
                if args[0] == "netstat":
                    return INCIDENT_NETSTAT
                return INCIDENT_TASKLIST_3006

            result = check_endpoint("T6", registry_path=registry_path, run=run)

        self.assertEqual(result.status, "collision")
        self.assertEqual(result.owners[0].image, "metatester64.exe")

    def test_unknown_terminal_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            registry_path = _registry(tmpdir, {"T6": 3006})
            result = check_endpoint("T99", registry_path=registry_path, run=lambda args: FREE_NETSTAT)

        self.assertEqual(result.status, "error")
        self.assertIsNone(result.port)

    def test_netstat_failure_fails_closed_not_open(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            registry_path = _registry(tmpdir, {"T6": 3006})

            def run(args: list[str]) -> str:
                raise RuntimeError("netstat timed out")

            result = check_endpoint("T6", registry_path=registry_path, run=run)

        self.assertEqual(result.status, "error")
        self.assertFalse(result.to_dict()["safe_to_launch"])

    def test_unresolved_image_still_reports_collision(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            registry_path = _registry(tmpdir, {"T6": 3000})

            def run(args: list[str]) -> str:
                if args[0] == "netstat":
                    return INCIDENT_NETSTAT
                return ""  # tasklist could not resolve the image

            result = check_endpoint("T6", registry_path=registry_path, run=run)

        self.assertEqual(result.status, "collision")
        self.assertEqual(result.owners[0].pid, 33224)
        self.assertIsNone(result.owners[0].image)

    def test_load_terminal_port_missing_registry_returns_none(self) -> None:
        missing = Path(tempfile.gettempdir()) / "does_not_exist_tester_endpoints.json"
        self.assertIsNone(load_terminal_port("T6", registry_path=missing))


if __name__ == "__main__":
    unittest.main()
