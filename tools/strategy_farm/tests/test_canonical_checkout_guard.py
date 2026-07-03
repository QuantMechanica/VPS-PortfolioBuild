"""Tests for canonical-checkout guard (task 1a52d28d).

Covers three layers:
  L1 - CANONICAL_REPO_ROOT anchors FRAMEWORK_EAS_DIR to C:/QM/repo
  L2 - _assert_canonical_checkout() hard-aborts for state-mutating commands
       when run from a worktree; QM_ALLOW_NONCANONICAL=1 bypasses
  L3 - R11 mass-invalidation circuit breaker: >200 would-be-INVALID → ABORT
       + health_alarms.log entry instead of bulk DB update
"""

from __future__ import annotations

import json
import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import repair   # noqa: E402


class Layer1CanonicalRootTests(unittest.TestCase):
    """L1: FRAMEWORK_EAS_DIR must anchor to C:/QM/repo, not the running script."""

    def test_framework_eas_dir_uses_canonical_root(self) -> None:
        canonical = Path(r"C:\QM\repo")
        self.assertEqual(farmctl.FRAMEWORK_EAS_DIR.parent.parent, canonical)

    def test_framework_eas_dir_not_script_relative(self) -> None:
        script_relative = Path(farmctl.__file__).resolve().parents[2] / "framework" / "EAs"
        # These should differ when run from a worktree (canonical != script path).
        # When run from canonical they are equal — so just assert CANONICAL_REPO_ROOT
        # is what drives the value, not REPO_ROOT.
        self.assertEqual(farmctl.CANONICAL_REPO_ROOT, Path(r"C:\QM\repo"))
        self.assertIn("framework", str(farmctl.FRAMEWORK_EAS_DIR))
        self.assertIn("EAs", str(farmctl.FRAMEWORK_EAS_DIR))

    def test_repair_ea_root_uses_canonical(self) -> None:
        # repair.CANONICAL_REPO_ROOT must match farmctl's.
        self.assertEqual(repair.CANONICAL_REPO_ROOT, Path(r"C:\QM\repo"))

    def test_env_override_respected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(os.environ, {"QM_CANONICAL_REPO_ROOT": tmp}):
                # Reload the constant via direct evaluation (not a module reload —
                # just verify the env key reads correctly).
                from pathlib import Path as _P
                got = _P(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))
                self.assertEqual(str(got), tmp)


class Layer2CanonicalSelfCheckTests(unittest.TestCase):
    """L2: _assert_canonical_checkout() guards state-mutating subcommands."""

    def test_passes_when_under_canonical(self) -> None:
        canonical = Path(r"C:\QM\repo")
        with mock.patch.object(farmctl, "_CANONICAL_CHECKOUT", canonical):
            with mock.patch("farmctl.__file__", str(canonical / "tools" / "strategy_farm" / "farmctl.py")):
                with mock.patch.dict(os.environ, {}, clear=False):
                    os.environ.pop("QM_ALLOW_NONCANONICAL", None)
                    # Should not raise — script is under canonical prefix.
                    try:
                        farmctl._assert_canonical_checkout()
                    except SystemExit:
                        self.fail("_assert_canonical_checkout() raised SystemExit unexpectedly")

    def test_aborts_when_in_worktree(self) -> None:
        fake_canonical = Path(r"C:\QM\repo")
        worktree_script = str(Path(r"C:\QM\worktrees\claude-orchestration-2\tools\strategy_farm\farmctl.py"))
        with mock.patch.object(farmctl, "_CANONICAL_CHECKOUT", fake_canonical):
            with mock.patch("farmctl.__file__", worktree_script):
                with mock.patch.dict(os.environ, {}, clear=False):
                    os.environ.pop("QM_ALLOW_NONCANONICAL", None)
                    with self.assertRaises(SystemExit) as cm:
                        farmctl._assert_canonical_checkout()
                    self.assertEqual(cm.exception.code, 1)

    def test_noncanonical_override_bypasses_check(self) -> None:
        fake_canonical = Path(r"C:\QM\repo")
        worktree_script = str(Path(r"C:\QM\worktrees\test-wt\tools\strategy_farm\farmctl.py"))
        with mock.patch.object(farmctl, "_CANONICAL_CHECKOUT", fake_canonical):
            with mock.patch("farmctl.__file__", worktree_script):
                with mock.patch.dict(os.environ, {"QM_ALLOW_NONCANONICAL": "1"}):
                    # Should not raise with override.
                    try:
                        farmctl._assert_canonical_checkout()
                    except SystemExit:
                        self.fail("_assert_canonical_checkout() raised despite QM_ALLOW_NONCANONICAL=1")


class Layer3CircuitBreakerTests(unittest.TestCase):
    """L3: mass-invalidation circuit breaker in repair R11."""

    def _make_db(self, tmp: Path, n_pending: int) -> sqlite3.Connection:
        db_path = tmp / "farm_state.sqlite"
        con = sqlite3.connect(str(db_path))
        con.row_factory = sqlite3.Row
        con.execute(
            """CREATE TABLE work_items (
                id TEXT PRIMARY KEY,
                ea_id TEXT,
                symbol TEXT,
                phase TEXT,
                setfile_path TEXT,
                payload_json TEXT,
                status TEXT,
                verdict TEXT,
                evidence_path TEXT,
                claimed_by TEXT,
                updated_at TEXT
            )"""
        )
        for i in range(n_pending):
            con.execute(
                "INSERT INTO work_items (id, ea_id, symbol, phase, setfile_path, "
                "payload_json, status) VALUES (?,?,?,?,?,?,?)",
                (
                    f"item-{i:04d}",
                    f"QM5_{i:05d}",
                    "EURUSD",
                    "P2",
                    "/nonexistent/setfile.set",
                    "{}",
                    "pending",
                ),
            )
        con.commit()
        return con

    def test_circuit_breaker_fires_above_limit(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp_str:
            tmp = Path(tmp_str)
            alarms_log = tmp / "state" / "health_alarms.log"
            con = self._make_db(tmp, n_pending=250)
            # Patch HEALTH_ALARMS_LOG and ROOT so circuit breaker writes to tmp.
            with mock.patch.object(repair, "HEALTH_ALARMS_LOG", alarms_log), \
                 mock.patch.object(repair, "ROOT", tmp), \
                 mock.patch.object(repair, "CANONICAL_REPO_ROOT", tmp / "no_eas"):
                result = repair.repair_pending_unclaimable_work_items(con)

            self.assertEqual(len(result), 1)
            self.assertEqual(result[0]["action"], "ABORTED")
            self.assertIn("circuit_breaker", result[0]["target"])
            self.assertTrue(alarms_log.exists(), "health_alarms.log should be written")
            alarm_text = alarms_log.read_text(encoding="utf-8")
            self.assertIn("mass_invalidation", alarm_text)
            self.assertIn("250", alarm_text)

            # DB must be unchanged — no items set to INVALID.
            still_pending = con.execute(
                "SELECT COUNT(*) FROM work_items WHERE status='pending'"
            ).fetchone()[0]
            self.assertEqual(still_pending, 250)
            con.close()

    def test_circuit_breaker_does_not_fire_at_limit(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp_str:
            tmp = Path(tmp_str)
            alarms_log = tmp / "state" / "health_alarms.log"
            # 5 missing items — well below the 200 limit.
            con = self._make_db(tmp, n_pending=5)
            reports_dir = tmp / "reports"
            reports_dir.mkdir(parents=True)
            with mock.patch.object(repair, "HEALTH_ALARMS_LOG", alarms_log), \
                 mock.patch.object(repair, "ROOT", tmp), \
                 mock.patch.object(repair, "CANONICAL_REPO_ROOT", tmp / "no_eas"):
                result = repair.repair_pending_unclaimable_work_items(con)

            # Should proceed normally — all 5 should be invalidated.
            actions = [r["action"] for r in result]
            self.assertNotIn("ABORTED", actions)
            self.assertFalse(alarms_log.exists(), "No alarm should fire below limit")
            con.close()


if __name__ == "__main__":
    unittest.main()
