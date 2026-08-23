"""Contract tests for the rebaseline backfill planner."""
from __future__ import annotations

import json
import os
import sqlite3
import sys
from pathlib import Path

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import backfill_planner as planner  # noqa: E402
import rebaseline_census as census  # noqa: E402


def _connection(path: Path | None = None) -> sqlite3.Connection:
    connection = sqlite3.connect(str(path) if path else ":memory:")
    connection.execute(
        "CREATE TABLE work_items ("
        " id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,"
        " setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER DEFAULT 0,"
        " parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT, payload_json TEXT,"
        " created_at TEXT, updated_at TEXT)"
    )
    connection.execute(
        "CREATE TABLE tasks (id TEXT PRIMARY KEY, kind TEXT, status TEXT, source_id TEXT,"
        " card_id TEXT, payload_json TEXT, created_at TEXT, updated_at TEXT)"
    )
    connection.row_factory = sqlite3.Row
    return connection


def _insert(
    connection: sqlite3.Connection,
    row_id: str,
    phase: str,
    ea_id: str,
    symbol: str,
    status: str = "done",
    verdict: str | None = "PASS",
    *,
    created_at: str = "2026-01-01T00:00:00+00:00",
    updated_at: str = "2026-01-01T01:00:00+00:00",
    evidence_path: str = "",
    payload: dict | None = None,
) -> None:
    connection.execute(
        "INSERT INTO work_items "
        "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,evidence_path,claimed_by,"
        "payload_json,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            row_id, "backtest", phase, ea_id, symbol, "fixture.set", status, verdict,
            evidence_path, None, json.dumps(payload or {}), created_at, updated_at,
        ),
    )


def _census_rows(connection: sqlite3.Connection) -> list[dict]:
    return census.compute(connection, None)["pair_rows"]


def test_never_proposes_above_a_hole() -> None:
    connection = _connection()
    _insert(connection, "q02", "Q02", "QM5_1", "EURUSD.DWX")
    _insert(connection, "q04", "Q04", "QM5_1", "EURUSD.DWX")

    result = planner.build_plan(connection, _census_rows(connection))
    row = next(item for item in result["rows"] if item["record_type"] == "PAIR")

    assert row["highest_observed_gate"] == "Q04"
    assert row["highest_contiguous_valid_gate"] == "Q02"
    assert row["target_gate"] == "Q03"
    assert row["action"] == "FILL_MISSING"


def test_q09_portfolio_pass_never_fills_news_hole() -> None:
    connection = _connection()
    payload = {"expected_ex5_sha256": "a" * 64, "expected_setfile_sha256": "b" * 64}
    for gate in planner.GATE_CHAIN[:7]:
        _insert(connection, f"id-{gate}", gate, "QM5_NEWS", "XAUUSD.DWX", payload=payload)
    _insert(
        connection, "portfolio", "Q09_PORTFOLIO", "QM5_NEWS", "XAUUSD.DWX",
        verdict="PASS_PORTFOLIO", payload=payload,
    )
    _insert(
        connection, "news", "Q09_NEWS", "QM5_NEWS", "XAUUSD.DWX",
        verdict="REVIEW_REQUIRED", payload=payload,
    )

    result = planner.build_plan(connection, _census_rows(connection))
    row = next(item for item in result["rows"] if item["record_type"] == "PAIR")

    assert row["highest_contiguous_valid_gate"] == "Q08"
    assert row["target_gate"] == "Q09"
    assert row["action"] == "UNKNOWN"
    assert row["reason"] == "q09_news_manual_review_required"


def test_q10_pass_above_news_hole_is_capped_not_skipped() -> None:
    connection = _connection()
    payload = {"expected_ex5_sha256": "a" * 64, "expected_setfile_sha256": "b" * 64}
    # Q02..Q08 pass, Q09 credited only via a PASS_PORTFOLIO row, and Q10 + Q14
    # pass on top.  The census contiguity walk therefore runs the frontier past
    # Q09 (to Q10/Q14) while the economic Q09_NEWS lane never validly passed.
    for gate in planner.GATE_CHAIN[:7]:
        _insert(connection, f"hole-{gate}", gate, "QM5_HOLE", "XAUUSD.DWX", payload=payload)
    _insert(
        connection, "hole-portfolio", "Q09_PORTFOLIO", "QM5_HOLE", "XAUUSD.DWX",
        verdict="PASS_PORTFOLIO", payload=payload,
    )
    _insert(
        connection, "hole-news", "Q09_NEWS", "QM5_HOLE", "XAUUSD.DWX",
        verdict="REVIEW_REQUIRED", payload=payload,
    )
    _insert(connection, "hole-q10", "Q10", "QM5_HOLE", "XAUUSD.DWX", payload=payload)
    _insert(connection, "hole-q14", "Q14", "QM5_HOLE", "XAUUSD.DWX", payload=payload)

    # A genuinely-complete pair: a valid Q09_NEWS PASS through the whole chain.
    for gate in planner.GATE_CHAIN:
        _insert(connection, f"full-{gate}", gate, "QM5_FULL", "GBPUSD.DWX", payload=payload)

    result = planner.build_plan(connection, _census_rows(connection))
    pairs = {row["ea_id"]: row for row in result["rows"] if row["record_type"] == "PAIR"}
    hole = pairs["QM5_HOLE"]

    # The frontier must be capped at Q08 and re-targeted at the Q09_NEWS hole,
    # not left reported at Q10/Q14 with the hole masked.
    assert hole["highest_contiguous_valid_gate"] == "Q08"
    assert hole["target_gate"] == "Q09"
    assert hole["action"] == "UNKNOWN"
    assert hole["reason"] == "q09_news_manual_review_required"
    # The masked hole must not outrank a genuinely-complete pair.
    assert pairs["QM5_FULL"]["rank"] < hole["rank"]


def test_config_locked_q09_news_is_rebind_not_reusable() -> None:
    connection = _connection()
    payload = {"expected_ex5_sha256": "a" * 64, "expected_setfile_sha256": "b" * 64}
    for gate in planner.GATE_CHAIN[:7]:
        _insert(connection, f"cl-{gate}", gate, "QM5_CL", "USDCHF.DWX", payload=payload)
    _insert(
        connection, "cl-portfolio", "Q09_PORTFOLIO", "QM5_CL", "USDCHF.DWX",
        verdict="PASS_PORTFOLIO", payload=payload,
    )
    _insert(
        connection, "cl-news", "Q09_NEWS", "QM5_CL", "USDCHF.DWX",
        status="failed", verdict="CONFIG_LOCKED", payload=payload,
    )
    _insert(connection, "cl-q10", "Q10", "QM5_CL", "USDCHF.DWX", payload=payload)

    result = planner.build_plan(connection, _census_rows(connection))
    row = next(item for item in result["rows"] if item["record_type"] == "PAIR")

    # CONFIG_LOCKED is a census STALE class; it must be re-bound at Q09, never
    # silently treated as a reusable/valid Q09_NEWS resting state that skips it.
    assert row["highest_contiguous_valid_gate"] == "Q08"
    assert row["target_gate"] == "Q09"
    assert row["action"] == "REBIND_STALE"
    assert row["reason"].startswith("stale_or_contract_gap_at_q09_news")


def test_exact_reusable_full_chain_is_skipped() -> None:
    connection = _connection()
    payload = {
        "gate_contract_version": "v3",
        "expected_ex5_sha256": "a" * 64,
        "expected_setfile_sha256": "b" * 64,
        "from_year": 2017,
        "to_year": 2022,
    }
    for gate in planner.GATE_CHAIN:
        _insert(connection, f"id-{gate}", gate, "QM5_2", "GBPUSD.DWX", payload=payload)

    result = planner.build_plan(connection, _census_rows(connection))
    row = next(item for item in result["rows"] if item["record_type"] == "PAIR")

    assert row["action"] == "SKIP_REUSABLE"
    assert row["enqueue_eligible"] is False
    assert row["farmctl_command"] == ""


def test_does_not_backfill_behind_economic_fail() -> None:
    connection = _connection()
    _insert(connection, "q02", "Q02", "QM5_3", "USDJPY.DWX")
    _insert(connection, "q03", "Q03", "QM5_3", "USDJPY.DWX", verdict="FAIL")
    _insert(connection, "q04", "Q04", "QM5_3", "USDJPY.DWX")

    result = planner.build_plan(connection, _census_rows(connection))
    row = next(item for item in result["rows"] if item["record_type"] == "PAIR")

    assert row["target_gate"] == "Q03"
    assert row["action"] == "STOP_ECONOMIC_FAIL"
    assert row["enqueue_eligible"] is False


def test_ranking_frontier_then_remaining_then_age() -> None:
    connection = _connection()
    # Q08 frontier must lead Q05 frontier regardless of age.
    for gate in planner.GATE_CHAIN[:7]:
        _insert(connection, f"high-{gate}", gate, "QM5_HIGH", "EURUSD.DWX",
                created_at="2026-08-01T00:00:00+00:00")
    # Same Q05 frontier twice: older pair must lead younger pair.
    for ea_id, created in (
        ("QM5_OLD", "2025-01-01T00:00:00+00:00"),
        ("QM5_NEW", "2026-07-01T00:00:00+00:00"),
    ):
        for gate in planner.GATE_CHAIN[:4]:
            _insert(connection, f"{ea_id}-{gate}", gate, ea_id, "GBPUSD.DWX",
                    created_at=created)

    result = planner.build_plan(connection, _census_rows(connection))
    pairs = [row for row in result["rows"] if row["record_type"] == "PAIR"]

    assert [row["ea_id"] for row in pairs] == ["QM5_HIGH", "QM5_OLD", "QM5_NEW"]
    assert [row["rank"] for row in pairs] == [1, 2, 3]


def test_global_economic_identity_is_deduplicated(tmp_path: Path) -> None:
    connection = _connection()
    evidence = tmp_path / "q02.json"
    evidence.write_text("{}", encoding="utf-8")
    payload = {
        "gate_contract_version": "v3",
        "expected_ex5_sha256": "a" * 64,
        "expected_setfile_sha256": "b" * 64,
        "from_year": 2017,
        "to_year": 2022,
    }
    for ea_id in ("QM5_DEDUP_A", "QM5_DEDUP_B"):
        _insert(
            connection, f"{ea_id}-q02", "Q02", ea_id, "EURUSD.DWX",
            evidence_path=str(evidence), payload=payload,
        )

    result = planner.build_plan(connection, _census_rows(connection))
    pairs = [row for row in result["rows"] if row["record_type"] == "PAIR"]

    assert pairs[0]["action"] == "FILL_MISSING"
    assert pairs[0]["enqueue_eligible"] is True
    assert pairs[1]["action"] == "SKIP_REUSABLE"
    assert pairs[1]["reason"] == "global_economic_run_dedup"
    assert pairs[1]["duplicate_of_rank"] == pairs[0]["rank"]


@pytest.mark.parametrize(
    "argv",
    [
        ["--apply", "--max-rows", "1"],
        ["--apply", "--i-understand-append-only"],
        ["--apply", "--i-understand-append-only", "--max-rows", "0"],
    ],
)
def test_apply_refuses_without_both_guards(argv: list[str]) -> None:
    with pytest.raises(SystemExit) as error:
        planner.main(argv)
    assert error.value.code == 2


def test_open_ro_uses_read_only_uri(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    connection = sqlite3.connect(database)
    connection.execute("CREATE TABLE marker (value TEXT)")
    connection.commit()
    connection.close()

    readonly = planner.open_ro(database)
    assert readonly.execute("PRAGMA query_only").fetchone()[0] == 1
    with pytest.raises(sqlite3.OperationalError):
        readonly.execute("INSERT INTO marker VALUES ('forbidden')")
    readonly.close()


def test_stdlib_compile_fail_is_infra_only_when_log_reachable(tmp_path: Path) -> None:
    connection = _connection()
    compile_log = tmp_path / "compile.log"
    compile_log.write_text(
        "QM_Common.mqh: error 106: file 'Include\\Trade\\Trade.mqh' not found",
        encoding="utf-8",
    )
    evidence = tmp_path / "compile_evidence.json"
    evidence.write_text(json.dumps({"compile_log": str(compile_log)}), encoding="utf-8")
    _insert(
        connection, "compile-1", "COMPILE_EA", "QM5_4", "", status="failed",
        verdict="COMPILE_FAIL", evidence_path=str(evidence),
    )
    missing_evidence = tmp_path / "missing.json"
    _insert(
        connection, "compile-2", "COMPILE_EA", "QM5_5", "", status="failed",
        verdict="COMPILE_FAIL", evidence_path=str(missing_evidence),
    )

    result = planner.build_plan(connection, [])
    rows = {row["ea_id"]: row for row in result["rows"]}

    assert rows["QM5_4"]["action"] == "RERUN_INFRA"
    assert rows["QM5_4"]["enqueue_eligible"] is False
    assert rows["QM5_5"]["action"] == "UNKNOWN"


def test_deterministic_oninit_failure_is_never_rerun(tmp_path: Path) -> None:
    connection = _connection()
    payload = {"expected_ex5_sha256": "a" * 64, "expected_setfile_sha256": "b" * 64}
    for gate in planner.GATE_CHAIN[:4]:
        _insert(connection, f"pass-{gate}", gate, "QM5_PIN", "XAUUSD.DWX", payload=payload)
    evidence = tmp_path / "q06.json"
    evidence.write_text(
        json.dumps({"reason": "invalid_summary:ONINIT_FAILED,INPUTSVALID"}),
        encoding="utf-8",
    )
    _insert(
        connection, "q06-pin", "Q06", "QM5_PIN", "XAUUSD.DWX",
        status="done", verdict="INFRA_FAIL", evidence_path=str(evidence), payload=payload,
    )

    result = planner.build_plan(connection, _census_rows(connection))
    row = next(item for item in result["rows"] if item["record_type"] == "PAIR")

    assert row["action"] == "STOP_DETERMINISTIC_INFRA"
    assert row["reason"] == "oninit_failed_inputsvalid_framework_pin_requires_code_fix"
    assert row["enqueue_eligible"] is False
    assert row["farmctl_command"] == ""


def test_ea_defect_compile_class_is_never_rerun(tmp_path: Path) -> None:
    connection = _connection()
    evidence = tmp_path / "compile_evidence.json"
    evidence.write_text(
        json.dumps({"compile_result": {"failure_classes": ["EA_Q08_MAE_HOOK_MISSING"]}}),
        encoding="utf-8",
    )
    _insert(
        connection, "compile-defect", "COMPILE_EA", "QM5_DEFECT", "",
        status="failed", verdict="COMPILE_FAIL", evidence_path=str(evidence),
    )

    result = planner.build_plan(connection, [])
    row = result["rows"][0]

    assert row["action"] == "STOP_DETERMINISTIC_INFRA"
    assert row["reason"] == "compile_fail_ea_defect_requires_code_fix"
    assert row["enqueue_eligible"] is False


def test_append_only_apply_uses_argv_without_shell(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    class Completed:
        returncode = 0
        stdout = "{}"
        stderr = ""

    def fake_run(argv, **kwargs):
        calls.append(argv)
        assert "shell" not in kwargs
        return Completed()

    monkeypatch.setattr(planner.subprocess, "run", fake_run)
    argv = [
        sys.executable, "tools/strategy_farm/farmctl.py", "enqueue-backtest",
        "--append-only-rerun-of", "old-id",
    ]
    rows = [{
        "rank": 1, "ea_id": "QM5_6", "symbol": "EURUSD.DWX",
        "action": "RERUN_INFRA", "enqueue_eligible": True,
        "command_argv_json": json.dumps(argv),
    }]

    receipt = planner.apply_plan(rows, 1, Path.cwd())

    assert receipt["attempted"] == 1
    assert calls == [argv]


def test_apply_respects_symbol_cap(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    class Completed:
        returncode = 0
        stdout = "{}"
        stderr = ""

    monkeypatch.setattr(
        planner.subprocess,
        "run",
        lambda argv, **_kwargs: calls.append(argv) or Completed(),
    )
    rows = []
    for rank in range(1, 4):
        argv = [sys.executable, "tools/strategy_farm/farmctl.py", "enqueue-backtest"]
        rows.append({
            "rank": rank, "ea_id": f"QM5_{rank}", "symbol": "XAUUSD.DWX",
            "action": "FILL_MISSING", "enqueue_eligible": True,
            "active_symbol_count": 2, "active_symbol_cap": 3,
            "command_argv_json": json.dumps(argv),
        })

    receipt = planner.apply_plan(rows, 3, Path.cwd())

    assert receipt["attempted"] == 1
    assert len(calls) == 1
