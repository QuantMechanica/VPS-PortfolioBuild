from __future__ import annotations

import importlib.util
import json
import sqlite3
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from decimal import Decimal
from pathlib import Path
from unittest import mock


HERE = Path(__file__).resolve()
TOOL = (
    HERE.parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_mulham_pm_range_sweep_ndx_prescreen.py"
)
SPEC = importlib.util.spec_from_file_location("qm13209_ndx_prescreen_under_test", TOOL)
assert SPEC is not None and SPEC.loader is not None
A = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = A
SPEC.loader.exec_module(A)


def trade(sequence: int, native: str, adjusted: str, *, day: int) -> object:
    entry = datetime(2022, 7, day, 17, 0)
    exit_time = entry + timedelta(hours=1)
    return A.TradeRecord(
        sequence=sequence,
        symbol="NDX.DWX",
        side="buy",
        entry_deal=f"in-{sequence}",
        exit_deals=(f"out-{sequence}",),
        entry_time_broker=entry,
        exit_time_broker=exit_time,
        entry_time_ny=entry - timedelta(hours=7),
        exit_time_ny=exit_time - timedelta(hours=7),
        new_york_day=(entry - timedelta(hours=7)).date().isoformat(),
        volume=Decimal("1"),
        native_net_usd=Decimal(native),
        venue_cost_usd=Decimal("5.50"),
        adjusted_net_usd=Decimal(adjusted),
    )


class NdxPrescreenContractTests(unittest.TestCase):
    def test_frozen_identity_and_single_cell_plan(self) -> None:
        plan = A.build_plan("NDX.DWX", {"path": "set", "size": 1, "sha256": "0" * 64}, A.RUN_ROOT)
        self.assertEqual(A.ANALYSIS_ID, "QM5_13209_MULHAM_PM_RANGE_SWEEP_NDX_PRESCREEN_NATIVE_001")
        self.assertEqual(len(plan["cells"]), 1)
        cell = plan["cells"][0]
        self.assertEqual(cell["from_date"], "2022-07-01")
        self.assertEqual(cell["to_date"], "2022-12-31")
        self.assertEqual((cell["timeframe"], cell["model"]), ("M5", 4))
        self.assertEqual((cell["duplicates"], cell["maximum_attempts"]), (2, 4))
        self.assertEqual(A.RUN_ROOT, Path(r"D:\QM\reports\candidate_analysis\QM5_13209\NDX_PM_RANGE_SWEEP_NATIVE_001\ATTEMPT_001"))

    def test_review_build_contract_and_outcome_blind_old_closure(self) -> None:
        self.assertEqual(A.validate_build_receipt()["review"]["sha256"], A.EXPECTED_REVIEW["sha256"])
        self.assertEqual(A.validate_analysis_contract()["status"], "IMPLEMENTED_REVIEW_APPROVED_NOT_AUTHORIZED_NOT_LAUNCHED")
        closure = A.validate_old_workitem_closure()
        self.assertIn("NO_MERIT_VERDICT", closure["status"])

    def test_data_receipt_semantics_without_rehashing_native_corpus(self) -> None:
        validated = A.validate_backtest_data_receipt(verify_files=False)
        self.assertEqual(validated["file_count"], 98)
        self.assertEqual((validated["history_files"], validated["tick_files"]), (8, 90))
        self.assertFalse(validated["historical_factory_bindings_replayed"])

    def test_current_alias_magic_cost_and_tester_semantics_are_projected(self) -> None:
        projected = A.validate_current_ndx_semantics()
        self.assertEqual(projected["aliases"], {"DXZ_LIVE": "NDX", "FTMO_TRIAL": "US100.cash"})
        self.assertEqual(projected["magic"], 132090001)
        self.assertEqual(projected["cost_rt_per_lot_usd"], "5.50")
        self.assertEqual(projected["tester"], {"deposit": 100000, "currency": "USD", "leverage": 100})

    def test_runner_command_is_exact_ndx_m5_model4_100k(self) -> None:
        pre = {
            "execution_contract": A.execution_contract(),
            "bindings": {
                "powershell": {"path": r"C:\pwsh.exe"},
                "runner": {"path": r"C:\run_dev2_smoke.ps1"},
                "dev2_machine_credential": {"sha256": "1" * 64},
                "dev2_machine_credential_helper": {"sha256": "2" * 64},
            },
        }
        cell = A.build_plan("NDX.DWX", {"path": r"C:\ndx.set", "size": 1, "sha256": "0" * 64}, A.RUN_ROOT)["cells"][0]
        command = A.runner_command(pre, cell)
        joined = " ".join(command)
        for fragment in ("-EAId 13209", "-Symbol NDX.DWX", "-Period M5", "-Model 4", "-Runs 2", "-TesterDepositOverride 100000"):
            self.assertIn(fragment, joined)
        self.assertIn("-CommissionPerLot 0", joined)

    def test_merit_requires_both_profit_factors_five_trades_and_positive_adjusted_net(self) -> None:
        winners = [trade(i, "110", "104.50", day=i) for i in range(1, 5)]
        loser = trade(5, "-100", "-105.50", day=5)
        result = A.evaluate_merit({"PRESCREEN_2022H2": [*winners, loser]})
        self.assertEqual(result["status"], "PASS")
        failed = A.evaluate_merit({"PRESCREEN_2022H2": [*winners[:3], loser]})
        self.assertEqual(failed["status"], "FAIL")
        self.assertEqual(failed["gates"][0]["gate_id"], "MIN_TRADES")

    def test_lifecycle_rejects_late_entry_and_second_trade_same_day(self) -> None:
        first = trade(1, "100", "94.50", day=1)
        second = trade(2, "100", "94.50", day=1)
        with self.assertRaises(A.InvalidEvidence):
            A.validate_trade_semantics([first, second])
        late = trade(3, "100", "94.50", day=2)
        late = late.__class__(**{**late.__dict__, "entry_time_broker": datetime(2022, 7, 2, 19, 0)})
        with self.assertRaises(A.InvalidEvidence):
            A.validate_trade_semantics([late])

    def test_factory_db_gate_requires_null_evidence_for_closures(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            database = root / "farm.sqlite"
            sp500 = root / "summary.json"
            sp500.write_bytes(b"opaque")
            closure_binding = A.B.file_binding(A.OLD_CLOSURE_PATH)
            rows = [
                (
                    A.OLD_WORKITEM_ID, "failed", "INFRA_FAIL", 1, None,
                    {"final_failure": "summary_missing", "closure_artifact_path": str(A.OLD_CLOSURE_PATH.resolve()), "closure_artifact_sha256": closure_binding["sha256"], "strategy_merit_adjudicated": False},
                ),
                (
                    A.DUPLICATE_WORKITEM_ID, "failed", "INVALID", 0, None,
                    {"duplicate_of": A.SP500_RESULT_WORKITEM_ID, "superseded_by": A.SP500_RESULT_WORKITEM_ID},
                ),
                (A.SP500_RESULT_WORKITEM_ID, "done", "FAIL", 0, str(sp500), {}),
            ]
            connection = sqlite3.connect(database)
            try:
                connection.execute("CREATE TABLE work_items(id TEXT,ea_id TEXT,status TEXT,verdict TEXT,attempt_count INTEGER,evidence_path TEXT,payload_json TEXT)")
                connection.executemany(
                    "INSERT INTO work_items VALUES(?,'QM5_13209',?,?,?,?,?)",
                    [(item, status, verdict, attempts, evidence, json.dumps(payload)) for item, status, verdict, attempts, evidence, payload in rows],
                )
                connection.commit()
            finally:
                connection.close()
            expected = {"path": str(sp500), "size": len(b"opaque"), "sha256": A.B.sha256_file(sp500)}
            with mock.patch.object(A, "FACTORY_DB_PATH", database), mock.patch.object(A, "SP500_EVIDENCE_PATH", sp500), mock.patch.object(A, "EXPECTED_SP500_EVIDENCE", expected):
                self.assertEqual(A.validate_factory_database_gate()["status"], "PASS")
                connection = sqlite3.connect(database)
                try:
                    connection.execute("UPDATE work_items SET evidence_path='closure.json' WHERE id=?", (A.OLD_WORKITEM_ID,))
                    connection.commit()
                finally:
                    connection.close()
                with self.assertRaises(A.InvalidEvidence):
                    A.validate_factory_database_gate()

    def test_resume_and_wrong_paths_fail_before_any_launch(self) -> None:
        with self.assertRaises(A.AuthorizationError):
            A.launch_detached(A.PRE_RECEIPT_PATH, "0" * 64, A.AUTHORIZATION_PATH, A.STATE_PATH, resume=True)
        with self.assertRaises(A.InvalidEvidence):
            A.build_plan("NDX", {}, A.RUN_ROOT)

    def test_source_never_reads_or_emits_process_command_lines(self) -> None:
        text = TOOL.read_text(encoding="utf-8")
        self.assertNotIn("Win32_Process.CommandLine", text)
        self.assertNotIn("SELECT CommandLine", text)
        self.assertIn('"command_lines_read": False', text)


if __name__ == "__main__":
    unittest.main()
