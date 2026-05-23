import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class CascadeChainP2ToP8Tests(unittest.TestCase):
    def _insert_work_item(self, root: Path, *, item_id: str, ea_id: str, phase: str, symbol: str = "EURUSD.DWX") -> None:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  (?, 'backtest', ?, ?, ?, 'dummy.set', 'pending', NULL,
                   0, NULL, NULL, NULL, '{}', ?, ?)
                """,
                (item_id, phase, ea_id, symbol, now, now),
            )
            conn.commit()

    def _write_inputs(self, pipeline_root: Path, ea_id: str, *, p8_fallback: Path) -> None:
        ea_dir = pipeline_root / ea_id
        (ea_dir / "P4").mkdir(parents=True)
        (ea_dir / "P4" / "calibration.json").write_text('{"symbols":{"EURUSD.DWX":{}}}', encoding="utf-8")
        (ea_dir / "P5").mkdir(parents=True)
        (ea_dir / "P5" / "p5_slices.csv").write_text("slice,pf,trades,drawdown_pct\ncovid,1.2,12,5\n", encoding="utf-8")
        (ea_dir / "P3").mkdir(parents=True)
        (ea_dir / "P3" / "sweep_pass_rows.csv").write_text("trade_count,pbo_pct,dsr\n250,2,0.8\n", encoding="utf-8")
        (ea_dir / "P6").mkdir(parents=True)
        (ea_dir / "P6" / "p6_seeds.csv").write_text("seed,seed_pass,profit_factor,trade_count\n42,PASS,1.4,40\n", encoding="utf-8")
        p8_fallback.parent.mkdir(parents=True)
        p8_fallback.write_text("mode,symbol,pf,trades,sharpe,drawdown_pct\nOFF,EURUSD.DWX,1.2,10,0.4,4\n", encoding="utf-8")

    def test_missing_required_chain_input_marks_waiting_input(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            pipeline_root = root / "pipeline"
            self._insert_work_item(root, item_id="wi-p5", ea_id="QM5_9999", phase="P5")

            old_pipeline = farmctl.PIPELINE_REPORT_ROOT
            old_calibration = farmctl.P5_CALIBRATION_JSON
            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            old_active = farmctl.active_mt5_terminals
            try:
                farmctl.PIPELINE_REPORT_ROOT = pipeline_root
                farmctl.P5_CALIBRATION_JSON = root / "missing_calibration.json"
                farmctl.MT5_TERMINALS = ("T1",)
                farmctl._running_mt5_terminals = lambda: set()
                farmctl.active_mt5_terminals = lambda: ["T1"]
                result = farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.PIPELINE_REPORT_ROOT = old_pipeline
                farmctl.P5_CALIBRATION_JSON = old_calibration
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running
                farmctl.active_mt5_terminals = old_active

            with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
                row = conn.execute("SELECT status, verdict, payload_json FROM work_items WHERE id='wi-p5'").fetchone()
            self.assertEqual(row[0], "done")
            self.assertEqual(row[1], "WAITING_INPUT")
            self.assertEqual(result["actions"][0]["action"], "waiting_input")
            payload = json.loads(row[2])
            self.assertIn("P4", payload["missing_inputs"][0])
            self.assertNotEqual(row[1], "PENDING_RUNNER")

    def test_all_chain_inputs_spawn_expected_phase_drivers(self) -> None:
        phases = {
            "P5": ("p5_stress_driver.py", ["--calibration-json", "P4", "--year", "2024", "--out-prefix"]),
            "P5b": ("p5b_noise_driver.py", ["--calibration-json", "P4", "--out-prefix"]),
            "P5c": ("p5c_crisis_slices.py", ["--slices-csv", "p5_slices.csv", "--out-prefix"]),
            "P6": ("p6_multiseed_driver.py", ["--year", "2024", "--seeds", "42,17,99,7,2026", "--out-prefix"]),
            "P7": ("p7_statval.py", ["--sweep-pass-rows", "sweep_pass_rows.csv", "--multiseed-rows", "p6_seeds.csv"]),
            "P8": ("p8_news_driver.py", ["--news-matrix", "news_matrix.csv", "--mode", "all"]),
        }
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            pipeline_root = root / "pipeline"
            fallback_news = root / "news" / "news_matrix.csv"
            self._write_inputs(pipeline_root, "QM5_9999", p8_fallback=fallback_news)
            spawned_cmds: list[list[str]] = []

            class FakeProc:
                pid = 4242

                def __init__(self, cmd, **_kwargs):
                    spawned_cmds.append([str(part) for part in cmd])

            old_pipeline = farmctl.PIPELINE_REPORT_ROOT
            old_news = farmctl.NEWS_MATRIX_FALLBACK
            old_popen = farmctl.subprocess.Popen
            old_terminals = farmctl.MT5_TERMINALS
            old_running = farmctl._running_mt5_terminals
            old_active = farmctl.active_mt5_terminals
            try:
                farmctl.PIPELINE_REPORT_ROOT = pipeline_root
                farmctl.NEWS_MATRIX_FALLBACK = fallback_news
                farmctl.subprocess.Popen = FakeProc
                farmctl.MT5_TERMINALS = tuple(f"T{i}" for i in range(1, 7))
                farmctl._running_mt5_terminals = lambda: set()
                farmctl.active_mt5_terminals = lambda: [f"T{i}" for i in range(1, 7)]
                for idx, phase in enumerate(phases, start=1):
                    self._insert_work_item(root, item_id=f"wi-{phase}", ea_id="QM5_9999", phase=phase, symbol=f"EURUSD{idx}.DWX")
                farmctl.dispatch_work_items(root, timeout_minutes=8)
            finally:
                farmctl.PIPELINE_REPORT_ROOT = old_pipeline
                farmctl.NEWS_MATRIX_FALLBACK = old_news
                farmctl.subprocess.Popen = old_popen
                farmctl.MT5_TERMINALS = old_terminals
                farmctl._running_mt5_terminals = old_running
                farmctl.active_mt5_terminals = old_active

            self.assertEqual(len(spawned_cmds), len(phases))
            joined_by_script = {" ".join(cmd).replace("\\", "/"): cmd for cmd in spawned_cmds}
            for script, needles in phases.values():
                joined = next(text for text in joined_by_script if script in text)
                for needle in needles:
                    self.assertIn(needle, joined)
                self.assertNotIn("run_smoke.ps1", joined)


if __name__ == "__main__":
    unittest.main()
