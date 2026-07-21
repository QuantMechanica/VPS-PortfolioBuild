from __future__ import annotations

import ast
import importlib.util
import json
import sqlite3
import sys
import tempfile
import unittest
from contextlib import nullcontext
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


def function_source(name: str) -> str:
    source = TOOL.read_text(encoding="utf-8")
    tree = ast.parse(source)
    node = next(
        item
        for item in tree.body
        if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))
        and item.name == name
    )
    rendered = ast.get_source_segment(source, node)
    assert rendered is not None
    return rendered


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
        self.assertEqual(cell["cell_id"], A.CELL_ID)
        self.assertEqual(cell["from_date"], "2022-07-01")
        self.assertEqual(cell["to_date"], "2022-12-31")
        self.assertEqual((cell["timeframe"], cell["model"]), ("M5", 4))
        self.assertEqual((cell["duplicates"], cell["maximum_attempts"]), (2, 4))
        authorization_source = function_source("validate_authorization")
        self.assertIn("payload[\"authorized_cells\"] != plan_cell_ids", authorization_source)
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
                    A.OLD_WORKITEM_ID, "failed", "INFRA_FAIL", 1, None, None,
                    {"final_failure": "summary_missing", "closure_artifact_path": str(A.OLD_CLOSURE_PATH.resolve()), "closure_artifact_sha256": closure_binding["sha256"], "strategy_merit_adjudicated": False},
                ),
                (
                    A.DUPLICATE_WORKITEM_ID, "failed", "INVALID", 0, None, None,
                    {"duplicate_of": A.SP500_RESULT_WORKITEM_ID, "superseded_by": A.SP500_RESULT_WORKITEM_ID},
                ),
                (A.SP500_RESULT_WORKITEM_ID, "done", "FAIL", 0, str(sp500), None, {}),
            ]
            connection = sqlite3.connect(database)
            try:
                connection.execute("CREATE TABLE work_items(id TEXT,ea_id TEXT,status TEXT,verdict TEXT,attempt_count INTEGER,evidence_path TEXT,claimed_by TEXT,payload_json TEXT)")
                connection.executemany(
                    "INSERT INTO work_items VALUES(?,'QM5_13209',?,?,?,?,?,?)",
                    [(item, status, verdict, attempts, evidence, claimed_by, json.dumps(payload)) for item, status, verdict, attempts, evidence, claimed_by, payload in rows],
                )
                connection.commit()
            finally:
                connection.close()
            expected = {"path": str(sp500), "size": len(b"opaque"), "sha256": A.B.sha256_file(sp500)}
            with mock.patch.object(A, "FACTORY_DB_PATH", database), mock.patch.object(A, "SP500_EVIDENCE_PATH", sp500), mock.patch.object(A, "EXPECTED_SP500_EVIDENCE", expected):
                self.assertEqual(A.validate_factory_database_gate()["status"], "PASS")
                connection = sqlite3.connect(database)
                try:
                    connection.execute("UPDATE work_items SET claimed_by='stale-worker' WHERE id=?", (A.OLD_WORKITEM_ID,))
                    connection.commit()
                finally:
                    connection.close()
                with self.assertRaises(A.InvalidEvidence):
                    A.validate_factory_database_gate()
                connection = sqlite3.connect(database)
                try:
                    connection.execute("UPDATE work_items SET claimed_by=NULL WHERE id=?", (A.OLD_WORKITEM_ID,))
                    connection.execute("UPDATE work_items SET evidence_path='closure.json' WHERE id=?", (A.OLD_WORKITEM_ID,))
                    connection.commit()
                finally:
                    connection.close()
                with self.assertRaises(A.InvalidEvidence):
                    A.validate_factory_database_gate()

    def test_terminal_closure_is_exact_and_outcome_blind(self) -> None:
        closure = A.validate_terminal_closure()
        self.assertEqual(closure["binding"], A.EXPECTED_TERMINAL_CLOSURE)
        self.assertEqual(closure["classification"], "DEV2_CUSTOM_HISTORY_TOPOLOGY_DRIFT")
        payload = A.B.load_json(A.TERMINAL_CLOSURE_PATH)
        failure = payload["infrastructure_failure"]
        self.assertEqual(failure["unexpected_addition"], "WS30.DWX")
        self.assertEqual(
            failure["expected_custom_history_symbols"],
            [
                "EURUSD.DWX",
                "GBPUSD.DWX",
                "GDAXI.DWX",
                "NDX.DWX",
                "USDJPY.DWX",
                "XAUUSD.DWX",
            ],
        )
        self.assertEqual(failure["failure_stage"], "PRE_MT5_CUSTOM_HISTORY_TOPOLOGY_GATE")
        self.assertFalse(failure["mt5_terminal_started"])
        self.assertFalse(failure["metatester_started"])
        self.assertFalse(failure["native_run_root_created"])
        self.assertFalse(payload["outcome_fence"]["economic_report_present"])
        self.assertFalse(payload["outcome_fence"]["economic_report_opened"])
        self.assertFalse(payload["outcome_fence"]["strategy_merit_adjudicated"])
        self.assertIsNone(payload["outcome_fence"]["merit_verdict"])
        source = function_source("validate_terminal_closure")
        for forbidden in (
            ".read_text(",
            "_parse_dev2_controller_json",
            "_audit_cell",
            "audit_native_report",
            "parse_report",
        ):
            self.assertNotIn(forbidden, source)

    def test_terminal_closure_hash_drift_fails_closed(self) -> None:
        drifted = {**A.EXPECTED_TERMINAL_CLOSURE, "sha256": "0" * 64}
        with mock.patch.object(A, "EXPECTED_TERMINAL_CLOSURE", drifted):
            with self.assertRaises(A.InvalidEvidence):
                A.validate_terminal_closure()

    def test_terminal_closure_blocks_every_execution_or_retry_surface(self) -> None:
        calls = (
            ("PRE", lambda: A.preflight("NDX.DWX", Path("data"), Path("build"), A.RUN_ROOT)),
            (
                "LAUNCH",
                lambda: A.launch_detached(
                    A.PRE_RECEIPT_PATH,
                    "0" * 64,
                    A.AUTHORIZATION_PATH,
                    A.STATE_PATH,
                    resume=False,
                ),
            ),
            (
                "RESUME",
                lambda: A.launch_detached(
                    A.PRE_RECEIPT_PATH,
                    "0" * 64,
                    A.AUTHORIZATION_PATH,
                    A.STATE_PATH,
                    resume=True,
                ),
            ),
            ("WORKER", lambda: A._worker_run(A.JOB_PATH)),
            (
                "POST",
                lambda: A.postflight(A.PRE_RECEIPT_PATH, "0" * 64, A.STATE_PATH),
            ),
            ("RETRY", lambda: A._block_terminal_operation("RETRY")),
            (
                "ATTEMPT_002",
                lambda: A._assert_run_root(A.RUN_NAMESPACE_ROOT / "ATTEMPT_002"),
            ),
        )
        for operation, call in calls:
            with self.subTest(operation=operation):
                with self.assertRaisesRegex(A.AuthorizationError, operation):
                    call()

    def test_wrong_symbol_still_fails_contract_validation(self) -> None:
        with self.assertRaises(A.InvalidEvidence):
            A.build_plan("NDX", {}, A.RUN_ROOT)

    def test_source_never_reads_or_emits_process_command_lines(self) -> None:
        text = TOOL.read_text(encoding="utf-8")
        self.assertNotIn("Win32_Process.CommandLine", text)
        self.assertNotIn("SELECT CommandLine", text)
        self.assertIn('"command_lines_read": False', text)

    def test_worker_is_outcome_blind_and_main_never_delegates_to_base_worker(self) -> None:
        worker = function_source("_worker_run")
        for forbidden in (
            "_BASE_WORKER_RUN",
            "B._worker_run",
            "_parse_dev2_controller_json",
            "_audit_cell",
            ".read_text(",
            "runner_result =",
        ):
            self.assertNotIn(forbidden, worker)
        worker_tree = ast.parse(worker)
        load_json_args = {
            ast.unparse(call.args[0])
            for call in ast.walk(worker_tree)
            if isinstance(call, ast.Call)
            and isinstance(call.func, ast.Attribute)
            and isinstance(call.func.value, ast.Name)
            and call.func.value.id == "B"
            and call.func.attr == "load_json"
            and call.args
        }
        self.assertEqual(load_json_args, {"job_path", "state_path"})

        post = function_source("postflight")
        self.assertIn("stdout_path.read_text", post)
        self.assertIn("B._parse_dev2_controller_json", post)
        self.assertIn("B._audit_cell", post)
        main = function_source("main")
        self.assertIn("return _worker_run(args.job)", main)
        self.assertNotIn("_BASE_WORKER_RUN", TOOL.read_text(encoding="utf-8"))

    def test_opaque_sealer_hashes_files_without_text_or_json_reads(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output_root = root / "controller"
            native_root = root / "20260721T120000Z_0123456789abcdef0123456789abcdef"
            summary = native_root / "output" / "smoke" / "QM5_13209" / "run" / "summary.json"
            native_result = native_root / "output" / "result.json"
            report = summary.parent / "raw" / "run_01" / "report.htm"
            stdout = output_root / "controller.stdout.log"
            stderr = output_root / "controller.stderr.log"
            for path, payload in (
                (summary, b'{"opaque":"summary"}'),
                (native_result, b'{"opaque":"result"}'),
                (report, b"<html>opaque</html>"),
                (stdout, b'{"opaque":"controller"}'),
                (stderr, b""),
            ):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(payload)
            attempt: dict[str, object] = {}
            with mock.patch.object(A.B, "_find_dev2_summary", return_value=summary), mock.patch.object(
                Path,
                "read_text",
                side_effect=AssertionError("outcome content read before POST"),
            ):
                A._seal_controller_attempt(output_root, native_root, attempt)
            self.assertEqual(attempt["runner_result"], None)
            self.assertFalse(attempt["controller_output_opened"])
            self.assertFalse(attempt["native_output_opened"])
            self.assertEqual(attempt["native_result"], A.B.file_binding(native_result))
            self.assertEqual(attempt["summary"], A.B.file_binding(summary))
            sealed_paths = {row["path"] for row in attempt["sealed_artifacts"]}
            self.assertEqual(
                sealed_paths,
                {str(path.resolve()) for path in (summary, native_result, report, stdout, stderr)},
            )

    def test_launch_state_and_receipt_artifact_types_are_qm13209_specific(self) -> None:
        self.assertEqual(A.JOB_ARTIFACT_TYPE, "QM5_13209_NDX_PRESCREEN_NATIVE_LAUNCH_JOB")
        self.assertEqual(A.STATE_ARTIFACT_TYPE, "QM5_13209_NDX_PRESCREEN_NATIVE_LAUNCH_STATE")
        self.assertEqual(
            A.POST_ARTIFACT_TYPE,
            "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_POST_RECEIPT",
        )
        source = TOOL.read_text(encoding="utf-8")
        for inherited in (
            "QM5_10834_NATIVE_LAUNCH_JOB",
            "QM5_10834_NATIVE_LAUNCH_STATE",
            "QM5_10834_OUTCOME_FENCED_POST_RECEIPT",
        ):
            self.assertNotIn(inherited, source)
        invalid = A.invalid_receipt("POST", A.InvalidEvidence("test"))
        self.assertEqual(
            invalid["artifact_type"], "QM5_13209_NDX_PRESCREEN_POST_INVALID"
        )

    def test_scheduler_unregister_is_idempotent_and_helper_has_delete_path(self) -> None:
        pre: dict[str, object] = {}
        job = {"scheduler": {"task_name": "QM_QM13209_NDX_AUDIT_" + "a" * 24}}
        responses = [
            {"state": "Absent", "exists": False, "cleanup": "UNREGISTERED"},
            {"state": "Absent", "exists": False, "cleanup": "ALREADY_ABSENT"},
        ]
        with mock.patch.object(A.B, "_scheduler_call", side_effect=responses) as call:
            first = A._unregister_scheduler(pre, job)
            second = A._unregister_scheduler(pre, job)
        self.assertEqual((first["status"], first["cleanup"]), ("PASS", "UNREGISTERED"))
        self.assertEqual((second["status"], second["cleanup"]), ("PASS", "ALREADY_ABSENT"))
        self.assertEqual(
            [entry.args[1] for entry in call.call_args_list],
            ["Unregister", "Unregister"],
        )
        helper = A.SCHEDULED_TASK_HELPER_PATH.read_text(encoding="utf-8")
        for required in (
            "'Unregister'",
            "'RunWorker'",
            "Unregister-ScheduledTask",
            "finally",
            "UNREGISTERED",
            "ALREADY_ABSENT",
        ):
            self.assertIn(required, helper)

    def test_terminal_helper_blocks_register_start_and_worker_before_task_access(self) -> None:
        helper = A.SCHEDULED_TASK_HELPER_PATH.read_text(encoding="utf-8")
        guard = helper.index("$terminallyClosedOperations")
        task_access = helper.index("$identity = Get-QmIdentity")
        self.assertLess(guard, task_access)
        for operation in ("Register", "Start", "RunWorker"):
            self.assertIn(f"'{operation}'", helper[guard:task_access])
        self.assertIn("permanently blocked", helper[guard:task_access])

    def test_partial_register_and_start_failures_unregister_without_relaunch(self) -> None:
        for failing_operation, expected_operations in (
            ("Register", ["Identity", "Register", "Unregister"]),
            ("Start", ["Identity", "Register", "Start", "Unregister"]),
        ):
            with self.subTest(failing_operation=failing_operation), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                pre_path = root / "pre.json"
                authorization_path = root / "authorization.json"
                state_path = root / "state.json"
                job_path = root / "launch_job.json"
                claim_path = root / "claim.json"
                lock_path = root / "lock"
                pre = {
                    "plan": {"plan_sha256": "1" * 64},
                    "bindings": {
                        "scheduled_task_helper": {"path": "helper"},
                        "python": {"path": "python"},
                        "tool": {"path": "tool"},
                    },
                }
                authorization = {
                    "binding": {"path": str(authorization_path), "size": 1, "sha256": "2" * 64},
                    "payload_sha256": "3" * 64,
                }
                operations: list[str] = []
                task_name = "QM_QM13209_NDX_AUDIT_" + "b" * 24

                def scheduler_call(_pre: object, operation: str, _job: object = None) -> dict[str, object]:
                    operations.append(operation)
                    if operation == "Identity":
                        return {"principal_sid": "S-1-5-21-1"}
                    if operation == failing_operation:
                        raise A.AuthorizationError(f"synthetic {operation} failure")
                    if operation == "Unregister":
                        return {
                            "state": "Absent",
                            "exists": False,
                            "cleanup": "UNREGISTERED",
                        }
                    return {"state": "Ready"}

                def pending_state(*_args: object, **_kwargs: object) -> dict[str, object]:
                    return {
                        "artifact_type": A.STATE_ARTIFACT_TYPE,
                        "analysis_id": A.ANALYSIS_ID,
                        "status": "PENDING",
                        "worker_pid": None,
                        "scheduler_cleanup": {"status": "PENDING"},
                    }

                with mock.patch.multiple(
                    A,
                    PRE_RECEIPT_PATH=pre_path,
                    AUTHORIZATION_PATH=authorization_path,
                    STATE_PATH=state_path,
                    JOB_PATH=job_path,
                    CLAIM_PATH=claim_path,
                    LOCK_PATH=lock_path,
                ), mock.patch.object(
                    A, "_block_terminal_operation"
                ), mock.patch.object(A.B, "native_launch_lock", return_value=nullcontext()), mock.patch.object(
                    A, "assert_pre_receipt", return_value=pre
                ), mock.patch.object(
                    A, "validate_current_research_data_gate"
                ), mock.patch.object(
                    A, "validate_authorization", return_value=authorization
                ), mock.patch.object(
                    A, "_validate_launch_job"
                ), mock.patch.object(
                    A, "initial_launch_state", side_effect=pending_state
                ), mock.patch.object(
                    A.B, "scheduled_task_name", return_value=task_name
                ), mock.patch.object(
                    A.B, "required_scheduled_task_timeout", return_value=3600
                ), mock.patch.object(
                    A.B, "_scheduler_call", side_effect=scheduler_call
                ):
                    with self.assertRaises(A.AuthorizationError):
                        A.launch_detached(
                            pre_path,
                            "4" * 64,
                            authorization_path,
                            state_path,
                            resume=False,
                        )
                self.assertEqual(operations, expected_operations)
                terminal = A.B.load_json(state_path)
                self.assertEqual(terminal["status"], "INVALID_LAUNCH")
                self.assertEqual(terminal["scheduler_cleanup"]["status"], "PASS")
                self.assertEqual(terminal["scheduler_cleanup"]["state"], "Absent")

    def test_cleanup_failure_invalidates_even_a_complete_worker_state(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            state_path = Path(temp) / "state.json"
            A.B.atomic_json(
                state_path,
                {"status": "COMPLETE", "worker_pid": 123, "scheduler_cleanup": {}},
                replace=False,
            )
            A._persist_scheduler_cleanup(
                state_path,
                {"status": "FAIL", "operation": "Unregister", "state": "UNKNOWN"},
                launch_failure=False,
            )
            state = A.B.load_json(state_path)
            self.assertEqual(state["status"], "INVALID_SCHEDULER_CLEANUP")
            self.assertIsNone(state["worker_pid"])


if __name__ == "__main__":
    unittest.main()
