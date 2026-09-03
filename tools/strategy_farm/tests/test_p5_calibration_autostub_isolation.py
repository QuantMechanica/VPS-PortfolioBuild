"""Regression: the P5 calibration autostub writer must never touch the tracked
production registry during a test run (router task 1258a0c5).

Root cause: ``farmctl.P5_CALIBRATION_JSON`` is a module constant frozen at import
against the real ``REPO_ROOT``. The pump autostub
(``_auto_stub_p5_calibration`` -> ``stub_source=farmctl_pump_p5_calibration_autostub``)
used that frozen constant directly and is pump-auto-committed via
``ARTIFACT_COMMIT_ALLOWLIST``, so a cascade test that seeds a synthetic Q05 symbol
(e.g. ``QM5_9993_GBPJPY_AUDJPY_COINTEGRATION_D1``) and monkeypatches ``REPO_ROOT``
to a tmp repo still wrote the synthetic block into the tracked file, which could
then be committed into production. The writer now resolves the path dynamically via
``_p5_calibration_path()`` (env override wins, else the current ``REPO_ROOT``).
"""
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


SYNTHETIC_SYMBOL = "QM5_9993_GBPJPY_AUDJPY_COINTEGRATION_D1"
CAL_REL = ("framework", "calibrations", "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json")


def _seed_pending_q05(root: Path, symbol: str) -> None:
    """Seed one Q05 pending work item so the autostub SELECT picks up ``symbol``."""
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with sqlite3.connect(root / farmctl.DB_REL) as seed:
        seed.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
            "status, verdict, attempt_count, evidence_path, payload_json, "
            "created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                "wi-q05-synth", "backtest", "Q05", "QM5_9993", symbol,
                "dummy.set", "pending", None, 0, "synthetic-evidence.json",
                "{}", now, now,
            ),
        )
        seed.commit()


class P5CalibrationAutostubIsolationTests(unittest.TestCase):
    def _production_registry(self) -> Path:
        # The frozen module constant is bound to the REAL repo checkout.
        return farmctl.P5_CALIBRATION_JSON

    def _snapshot_production(self):
        reg = self._production_registry()
        return reg.read_bytes() if reg.exists() else None

    def _assert_production_untouched(self, before) -> None:
        after = self._snapshot_production()
        self.assertEqual(
            before, after,
            "autostub mutated the tracked production calibration registry",
        )
        if after is not None:
            self.assertNotIn(
                SYNTHETIC_SYMBOL, after.decode("utf-8", "replace"),
                "synthetic test symbol leaked into the production registry",
            )

    def test_autostub_via_monkeypatched_repo_root_never_touches_production(self) -> None:
        """Mirrors the failing cascade test: REPO_ROOT is monkeypatched to a tmp repo."""
        before = self._snapshot_production()
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            tmp_cal = repo_root.joinpath(*CAL_REL)
            tmp_cal.parent.mkdir(parents=True)
            tmp_cal.write_text('{"symbols": {}}\n', encoding="utf-8")
            _seed_pending_q05(root, SYNTHETIC_SYMBOL)

            old_repo_root = farmctl.REPO_ROOT
            with mock.patch.dict(os.environ, {}, clear=False):
                os.environ.pop("QM_P5_CALIBRATION_JSON", None)
                try:
                    farmctl.REPO_ROOT = repo_root
                    with farmctl.connect(root) as conn:
                        added = farmctl._auto_stub_p5_calibration(root, conn)
                finally:
                    farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(
                any(a["symbol"] == SYNTHETIC_SYMBOL for a in added),
                "autostub should have stubbed the seeded synthetic symbol",
            )
            written = json.loads(tmp_cal.read_text(encoding="utf-8"))
            self.assertIn(SYNTHETIC_SYMBOL, written["symbols"])
            self.assertEqual(
                written["symbols"][SYNTHETIC_SYMBOL]["stub_source"],
                "farmctl_pump_p5_calibration_autostub",
            )
        self._assert_production_untouched(before)

    def test_autostub_env_override_wins_and_production_untouched(self) -> None:
        before = self._snapshot_production()
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            override_cal = Path(tmp) / "override_calibration.json"
            override_cal.write_text('{"symbols": {}}\n', encoding="utf-8")
            _seed_pending_q05(root, SYNTHETIC_SYMBOL)

            with mock.patch.dict(
                os.environ, {"QM_P5_CALIBRATION_JSON": str(override_cal)}
            ):
                with farmctl.connect(root) as conn:
                    added = farmctl._auto_stub_p5_calibration(root, conn)

            self.assertTrue(any(a["symbol"] == SYNTHETIC_SYMBOL for a in added))
            written = json.loads(override_cal.read_text(encoding="utf-8"))
            self.assertIn(SYNTHETIC_SYMBOL, written["symbols"])
        self._assert_production_untouched(before)

    def test_production_path_resolves_to_framework_calibrations_without_override(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("QM_P5_CALIBRATION_JSON", None)
            resolved = farmctl._p5_calibration_path()
        expected = farmctl.REPO_ROOT.joinpath(*CAL_REL)
        self.assertEqual(resolved, expected)
        # With no override and the default REPO_ROOT, the resolver matches the
        # frozen production constant exactly (production default unchanged).
        self.assertEqual(resolved, farmctl.P5_CALIBRATION_JSON)
        self.assertEqual(resolved.parts[-3:], CAL_REL)

    def test_env_override_takes_precedence_over_repo_root(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            override = Path(tmp) / "elsewhere.json"
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = Path(tmp) / "repo"
                with mock.patch.dict(
                    os.environ, {"QM_P5_CALIBRATION_JSON": str(override)}
                ):
                    self.assertEqual(farmctl._p5_calibration_path(), override)
            finally:
                farmctl.REPO_ROOT = old_repo_root


if __name__ == "__main__":
    unittest.main()
