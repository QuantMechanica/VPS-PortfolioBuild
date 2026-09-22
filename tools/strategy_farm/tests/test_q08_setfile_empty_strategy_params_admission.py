import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402

EMPTY_SETFILE = """;==========================================================
; QM Set File
;==========================================================
qm_magic_slot_offset=0
RISK_FIXED=1000
RISK_PERCENT=0
; strategy-specific params from card must be appended below this line
; card_defaults_source=not_found
"""

PARAM_SETFILE = """;==========================================================
; QM Set File
;==========================================================
qm_magic_slot_offset=0
RISK_FIXED=1000
RISK_PERCENT=0
; strategy-specific params from card must be appended below this line
strategy_signal_tf=PERIOD_D1
strategy_rsrs_period=20
strategy_entry_threshold=0.80
strategy_exit_threshold=0.50
strategy_atr_period=14
strategy_atr_sl_mult=2.00
"""


class Q08BaselineSetfileAdmissionTests(unittest.TestCase):
    def test_empty_setfile_without_ablation_marker_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            path = Path(tmp) / "QM5_90001_demo_NDX.DWX_D1_backtest.set"
            path.write_text(EMPTY_SETFILE, encoding="utf-8")
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(path), "NDX.DWX"
            )
            self.assertFalse(ok)
            self.assertEqual(
                detail["reason"], "SETFILE_EMPTY_STRATEGY_PARAMS"
            )
            self.assertEqual(detail["strategy_parameter_count"], 0)
            self.assertEqual(detail["symbol"], "NDX.DWX")

    def test_setfile_with_strategy_params_admitted(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            path = Path(tmp) / "QM5_90001_demo_NDX.DWX_D1_backtest.set"
            path.write_text(PARAM_SETFILE, encoding="utf-8")
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(path), "NDX.DWX"
            )
            self.assertTrue(ok)
            self.assertEqual(detail["reason"], "strategy_params_present")
            self.assertEqual(detail["strategy_parameter_count"], 6)

    def test_same_symbol_ablation_sibling_rescues_empty_baseline(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            sets_dir = Path(tmp)
            empty = sets_dir / "QM5_90001_demo_NDX.DWX_D1_backtest.set"
            empty.write_text(EMPTY_SETFILE, encoding="utf-8")
            (sets_dir / "QM5_90001_demo_NDX.DWX_D1_backtest_ablation_00.set").write_text(
                PARAM_SETFILE, encoding="utf-8"
            )
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(empty), "NDX.DWX"
            )
            self.assertTrue(ok)
            self.assertEqual(detail["reason"], "ablation_setfile_marker_present")

    def test_other_symbol_ablation_sibling_does_not_rescue(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            sets_dir = Path(tmp)
            empty = sets_dir / "QM5_90001_demo_NDX.DWX_D1_backtest.set"
            empty.write_text(EMPTY_SETFILE, encoding="utf-8")
            (sets_dir / "QM5_90001_demo_SP500.DWX_D1_backtest_ablation_00.set").write_text(
                PARAM_SETFILE, encoding="utf-8"
            )
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(empty), "NDX.DWX"
            )
            self.assertFalse(ok)
            self.assertEqual(detail["reason"], "SETFILE_EMPTY_STRATEGY_PARAMS")

    def test_ablation_named_bound_setfile_admitted(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            path = (
                Path(tmp)
                / "QM5_90001_demo_GDAXI.DWX_H1_backtest_ablation_00.set"
            )
            path.write_text(PARAM_SETFILE, encoding="utf-8")
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(path), "GDAXI.DWX"
            )
            self.assertTrue(ok)
            self.assertEqual(detail["reason"], "ablation_setfile_bound")

    def test_missing_setfile_defers_to_caller_exists_check(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            path = Path(tmp) / "gone_NDX.DWX_D1_backtest.set"
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(path), "NDX.DWX"
            )
            self.assertTrue(ok)
            self.assertEqual(detail["reason"], "setfile_exists_deferred")

    def test_unparseable_setfile_defers_to_sweep_triage(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            path = Path(tmp) / "QM5_90001_demo_NDX.DWX_D1_backtest.set"
            path.write_text("strategy_a=1\nstrategy_a=2\n", encoding="utf-8")
            ok, detail = farmctl._q08_baseline_setfile_admission(
                str(path), "NDX.DWX"
            )
            self.assertTrue(ok)
            self.assertEqual(detail["reason"], "setfile_parse_deferred")


class Q08CascadeEnqueueAdmissionTests(unittest.TestCase):
    def _enqueue_q08(self, setfile_text: str) -> dict:
        tmp_obj = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(tmp_obj.cleanup)
        root = Path(tmp_obj.name)
        repo_root = root / "repo"
        ea_dir = repo_root / "framework" / "EAs" / "QM5_9999_demo"
        sets_dir = ea_dir / "sets"
        sets_dir.mkdir(parents=True)
        (ea_dir / "QM5_9999_demo.ex5").write_text("compiled", encoding="utf-8")
        setfile = sets_dir / "QM5_9999_demo_NDX.DWX_D1_backtest.set"
        setfile.write_text(setfile_text, encoding="utf-8")
        farmctl.init_db(root)
        db = root / "state" / "farm_state.sqlite"
        now = farmctl.utc_now()
        with sqlite3.connect(db) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   verdict, attempt_count, payload_json, created_at, updated_at)
                VALUES
                  ('q07-pass', 'backtest', 'Q07', 'QM5_9999', 'NDX.DWX',
                   ?, 'done', 'PASS', 0, '{}', ?, ?)
                """,
                (str(setfile), now, now),
            )
            conn.commit()
        old_repo_root = farmctl.REPO_ROOT
        try:
            farmctl.REPO_ROOT = repo_root
            # This suite isolates the strategy-parameter admission gate.  The
            # promotion identity/window contracts have dedicated authenticated
            # fixtures in test_q08_promotion_repair.py.
            with mock.patch.object(
                farmctl,
                "_q08_promotion_execution_binding",
                return_value=(True, {"compile_record": {"work_item_id": "fixture"}}),
            ), mock.patch.object(
                farmctl,
                "_attach_q08_dsr_context",
                return_value={"status": "SEALED"},
            ):
                return farmctl.enqueue_cascade_backtest_for_ea(
                    root, "QM5_9999", "Q08"
                )
        finally:
            farmctl.REPO_ROOT = old_repo_root

    def test_empty_strategy_params_enqueue_refused(self) -> None:
        result = self._enqueue_q08(EMPTY_SETFILE)
        self.assertTrue(result["enqueued"])
        self.assertEqual(result["created"], [])
        self.assertEqual(result["requeued"], [])
        q08_skips = [
            row for row in result["skipped"]
            if row.get("reason") == "SETFILE_EMPTY_STRATEGY_PARAMS"
        ]
        self.assertEqual(len(q08_skips), 1)
        self.assertEqual(q08_skips[0]["symbol"], "NDX.DWX")

    def test_strategy_params_enqueue_admitted(self) -> None:
        result = self._enqueue_q08(PARAM_SETFILE)
        self.assertTrue(result["enqueued"])
        self.assertEqual(len(result["created"]), 1)
        self.assertEqual(result["created"][0]["symbol"], "NDX.DWX")
        self.assertEqual(
            [row for row in result["skipped"]
             if row.get("reason") == "SETFILE_EMPTY_STRATEGY_PARAMS"],
            [],
        )


if __name__ == "__main__":
    unittest.main()
