from __future__ import annotations

import importlib.util
import json
import sys
from dataclasses import replace
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_mulham_asian_sweep_london.py"
)
HELPER = TOOL.with_name("run_outcome_fenced_task.ps1")
BUILD_RECEIPT = (
    Path(__file__).resolve().parents[2]
    / "docs"
    / "candidate-analysis"
    / "build_receipt_20260720.json"
)
SPEC = importlib.util.spec_from_file_location(
    "audit_mulham_asian_sweep_london", TOOL
)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _research_store(tmp_path: Path) -> Path:
    root = tmp_path / "Custom"
    history = root / "history" / "EURUSD.DWX"
    ticks = root / "ticks" / "EURUSD.DWX"
    history.mkdir(parents=True)
    ticks.mkdir(parents=True)
    for year in range(2018, 2026):
        (history / f"{year}.hcc").write_bytes(f"hcc-{year}".encode("ascii"))
    for month in subject._required_tick_months():
        (ticks / f"{month}.tkc").write_bytes(f"tick-{month}".encode("ascii"))
    return root


def _synthetic_trade(
    day: date,
    sequence: int,
    adjusted_net: Decimal,
    *,
    entry_deal: str | None = None,
) -> subject.TradeRecord:
    entry = datetime.combine(day, time(9, 0))
    exit_time = datetime.combine(day, time(10, 0))
    cost = Decimal("6.00")
    return subject.TradeRecord(
        sequence=sequence,
        symbol="EURUSD.DWX",
        side="buy",
        entry_deal=entry_deal or f"{day:%Y%m%d}{sequence:04d}",
        exit_deals=(f"x{day:%Y%m%d}{sequence:04d}",),
        entry_time_broker=entry,
        exit_time_broker=exit_time,
        entry_time_ny=entry - timedelta(hours=7),
        exit_time_ny=exit_time - timedelta(hours=7),
        broker_day=day.isoformat(),
        new_york_day=(day - timedelta(days=1)).isoformat(),
        volume=Decimal("1"),
        entry_price=Decimal("1.20"),
        entry_comment="asian_sweep_fvg_long",
        native_net_usd=adjusted_net + cost,
        venue_cost_usd=cost,
        adjusted_net_usd=adjusted_net,
    )


def _passing_merit_cells() -> dict[str, list[subject.TradeRecord]]:
    dev_start = date(2018, 7, 2)
    result: dict[str, list[subject.TradeRecord]] = {
        "DEV": [
            _synthetic_trade(
                dev_start + timedelta(days=index),
                index + 1,
                Decimal("100") if index < 60 else Decimal("-50"),
            )
            for index in range(80)
        ]
    }
    for year in (2023, 2024, 2025):
        start = date(year, 1, 2)
        result[f"OOS_{year}"] = [
            _synthetic_trade(
                start + timedelta(days=index),
                index + 1,
                Decimal("100") if index < 10 else Decimal("-50"),
                entry_deal=f"{year}{index + 1:04d}",
            )
            for index in range(15)
        ]
    return result


def _runner_summary(cell: dict[str, object]) -> dict[str, object]:
    return {
        "result": "PASS",
        "ea_id": 13210,
        "ea_label": "QM5_13210",
        "expert": r"QM\QM5_13210_mulham-asian-sweep-london",
        "symbol": cell["symbol"],
        "terminal": "T1",
        "model": 4,
        "period": "M5",
        "requested_runs": 2,
        "attempted_runs": 2,
        "non_ok_attempts": 0,
        "deterministic": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "model4_log_marker_detected": True,
        "commission_group": {
            "commission_per_lot": "0",
            "commission_per_side_native": "0",
            "restored_to_canonical": True,
        },
        "news_calendar": {
            "status": "OK",
            "primary_path": str(subject.NEWS_PRIMARY_PATH),
            "secondary_path": str(subject.NEWS_SECONDARY_PATH),
            "missing_paths": [],
        },
        "runs": [
            {"run": name, "status": "OK", "real_ticks_marker": True}
            for name in ("run_01", "run_02")
        ],
    }


def test_plan_cli_and_bindings_are_exactly_eurusd_research_only(
    tmp_path: Path,
) -> None:
    set_binding = {
        "path": str(tmp_path / "candidate.set"),
        "size": 1,
        "sha256": "a" * 64,
    }
    plan = subject.build_plan("EURUSD.DWX", set_binding, tmp_path / "run")
    assert plan["single_authorized_symbol"] == "EURUSD.DWX"
    assert plan["native_run_count"] == 8
    assert [cell["model"] for cell in plan["cells"]] == [4, 4, 4, 4]
    assert [cell["duplicates"] for cell in plan["cells"]] == [2, 2, 2, 2]
    assert [(cell["from_date"], cell["to_date"]) for cell in plan["cells"]] == [
        ("2018-07-02", "2022-12-31"),
        ("2023-01-01", "2023-12-31"),
        ("2024-01-01", "2024-12-31"),
        ("2025-01-01", "2025-12-31"),
    ]
    with pytest.raises(subject.InvalidEvidence, match="only EURUSD.DWX"):
        subject.build_plan("XAUUSD.DWX", set_binding, tmp_path / "other")

    parser = subject.build_parser()
    subparsers = next(
        action for action in parser._actions if getattr(action, "choices", None)
    )
    pre_options = {
        option
        for action in subparsers.choices["pre"]._actions
        for option in action.option_strings
    }
    assert "--research-data-receipt" in pre_options
    assert "--validation-receipt" not in pre_options
    assert {
        "research_dossier",
        "research_extraction",
        "research_batch_receipt",
        "scheduled_task_helper",
        "python",
        "news_primary",
        "news_secondary",
    } <= subject.REQUIRED_BINDING_ROLES


def test_prepare_and_validate_exact_research_store_closure(tmp_path: Path) -> None:
    store = _research_store(tmp_path)
    manifest = tmp_path / "data_manifest.json"
    readiness = tmp_path / "research_readiness.json"
    prepared = subject.prepare_research_data_artifacts(
        "EURUSD.DWX",
        manifest,
        readiness,
        terminal_data_root=store,
    )
    assert prepared["status"] == "PASS"
    assert prepared["file_count"] == 98
    assert prepared["outcome_files_opened"] is False

    validated = subject.validate_data_manifest(
        manifest, "EURUSD.DWX", terminal_data_root=store
    )
    receipt = subject.validate_research_readiness_receipt(
        readiness, "EURUSD.DWX", validated["manifest"]["sha256"]
    )
    assert len(validated["files"]) == 98
    assert receipt["scope"]["model"] == 4
    assert receipt["scope"]["live_parity_required"] is False
    assert receipt["scope"]["deployment_routing_evaluated"] is False

    extra = store / "history" / "EURUSD.DWX" / "2017.hcc"
    extra.write_bytes(b"out-of-scope")
    mutated = subject.load_json(manifest)
    mutated["files"].append(subject.file_binding(extra))
    _write_json(manifest, mutated)
    with pytest.raises(subject.InvalidEvidence, match="HCC year closure drift"):
        subject.validate_data_manifest(
            manifest, "EURUSD.DWX", terminal_data_root=store
        )


def test_preflight_wires_research_readiness_without_live_parity_gate(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(subject, "ALLOWED_RUN_ROOT", tmp_path)
    manifest = tmp_path / "manifest.json"
    readiness = tmp_path / "readiness.json"
    _write_json(manifest, {"synthetic": "manifest"})
    _write_json(readiness, {"synthetic": "research-readiness"})
    data = {
        "manifest": subject.file_binding(manifest),
        "coverage": {
            "from_date": date(2018, 7, 2),
            "to_date": date(2025, 12, 31),
        },
        "files": [],
    }
    scope = {
        "hcc_years": "2018..2025",
        "tkc_months": "201807..202512",
        "model": 4,
        "live_parity_required": False,
        "deployment_routing_evaluated": False,
    }
    monkeypatch.setattr(subject, "validate_data_manifest", lambda *_args, **_kwargs: data)
    monkeypatch.setattr(
        subject,
        "validate_research_readiness_receipt",
        lambda *_args, **_kwargs: {
            "research_store": "T1_CUSTOM_SYMBOL_STORE",
            "purpose": "RESEARCH_BACKTEST_ONLY",
            "scope": scope,
        },
    )
    pre = subject.preflight(
        "EURUSD.DWX",
        readiness,
        manifest,
        BUILD_RECEIPT,
        tmp_path / "run",
    )
    assert pre["status"] == "PASS"
    assert pre["symbol_policy"]["authorized_symbol"] == "EURUSD.DWX"
    assert pre["symbol_policy"]["live_parity_required"] is False
    assert pre["symbol_policy"]["deployment_routing_evaluated"] is False
    assert pre["research_readiness_identity"]["scope"] == scope
    assert pre["outcome_fence"]["native_reports_opened"] is False
    assert "validation_receipt" not in pre


def test_build_receipt_binds_exact_source_binary_spec_card_set_and_compile() -> None:
    bindings = subject._binding_map("EURUSD.DWX")
    receipt = subject.validate_build_receipt(
        BUILD_RECEIPT, "EURUSD.DWX", bindings
    )
    assert receipt["build_commit"] == "b86eafe5cd20a359a71614ea8fcaddbd88977f4e"
    assert receipt["compile_errors"] == 0
    assert receipt["compile_warnings"] == 0
    assert receipt["source_sha256"] == bindings["mq5"]["sha256"]
    assert receipt["ex5_sha256"] == bindings["ex5"]["sha256"]


def test_worst_of_cost_news_session_and_pending_fill_checks(tmp_path: Path) -> None:
    venue = tmp_path / "venue_cost_model.json"
    live = tmp_path / "live_commission.json"
    _write_json(
        venue,
        {
            "symbols": {
                "EURUSD": {
                    "asset_class": "forex",
                    "dwx_symbol": "EURUSD.DWX",
                    "dxz": {
                        "commission_rt_base_ccy": 5,
                        "commission_rt_per_lot_usd_indicative": 5.85,
                    },
                    "ftmo": {"commission_rt_per_lot_usd": 5},
                    "worst_case_rt_per_lot_usd": 5.85,
                }
            }
        },
    )
    _write_json(
        live,
        {
            "model": "max(pct_rate_rt*notional_acct, flat_per_lot_rt*volume)",
            "classes": {
                "forex": {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 5}
            },
            "symbol_class": {"EURUSD.DWX": "forex"},
        },
    )
    schedule = subject.resolve_cost_schedule(venue, "EURUSD.DWX", live)
    entry = SimpleNamespace(
        direction="in",
        symbol="EURUSD.DWX",
        volume=Decimal("2"),
        commission=Decimal("0"),
        swap=Decimal("0"),
        kind="buy",
        deal="10",
        time=datetime(2025, 7, 7, 9, 0),
        price=Decimal("1.20"),
        comment="asian_sweep_fvg_long",
        raw_net=Decimal("0"),
    )
    close = SimpleNamespace(
        direction="out",
        symbol="EURUSD.DWX",
        volume=Decimal("2"),
        commission=Decimal("0"),
        swap=Decimal("0"),
        kind="sell",
        deal="11",
        time=datetime(2025, 7, 7, 19, 55),
        price=Decimal("1.21"),
        comment="",
        raw_net=Decimal("100"),
    )
    trades = subject._reconstruct_trades([entry, close], "EURUSD.DWX", schedule)
    assert trades[0].venue_cost_usd == Decimal("12.00")
    assert trades[0].adjusted_net_usd == Decimal("88.00")
    far_news = [subject.NewsEvent(datetime(2025, 7, 7, 12, 0), "USD", "HIGH")]
    assert subject.validate_trade_semantics(trades, far_news)["status"] == "PASS"

    entry_utc = subject.broker_to_utc(trades[0].entry_time_broker)
    blocked_news = [subject.NewsEvent(entry_utc, "EUR", "HIGH")]
    with pytest.raises(subject.InvalidEvidence, match="high-impact blackout"):
        subject.validate_trade_semantics(trades, blocked_news)
    with pytest.raises(subject.InvalidEvidence, match="owned Asian-sweep"):
        subject.validate_trade_semantics(
            [replace(trades[0], entry_comment="foreign_order")], far_news
        )
    with pytest.raises(subject.InvalidEvidence, match="outside half-open"):
        subject.validate_trade_semantics(
            [replace(trades[0], entry_time_broker=datetime(2025, 7, 7, 12, 0))],
            far_news,
        )


def test_duplicate_identity_and_runner_summary_are_fail_closed() -> None:
    trade = _synthetic_trade(date(2025, 1, 2), 1, Decimal("10"))
    baseline = subject.NativeRunAudit({}, "a" * 64, "b" * 64, [trade])
    subject.require_duplicate_identity([baseline, baseline])
    drift = subject.NativeRunAudit({}, "c" * 64, "b" * 64, [trade])
    with pytest.raises(subject.InvalidEvidence, match="Deal sequence drift"):
        subject.require_duplicate_identity([baseline, drift])

    cell = {"symbol": "EURUSD.DWX"}
    summary = _runner_summary(cell)
    subject.validate_runner_summary(summary, cell)
    summary["commission_group"]["commission_per_lot"] = "5"
    with pytest.raises(subject.InvalidEvidence, match="commission"):
        subject.validate_runner_summary(summary, cell)


def test_all_frozen_merit_gates_can_pass_and_valid_miss_is_fail() -> None:
    cells = _passing_merit_cells()
    passed = subject.evaluate_merit(cells)
    assert passed["status"] == "PASS"
    assert all(row["status"] == "PASS" for row in passed["gates"])
    assert passed["contract"] == subject.MERIT_GATES

    cells["OOS_2025"] = cells["OOS_2025"][:11]
    failed = subject.evaluate_merit(cells)
    assert failed["status"] == "FAIL"
    assert next(
        row for row in failed["gates"] if row["gate_id"] == "OOS_2025_MIN_TRADES"
    )["status"] == "FAIL"
    invalid = subject.invalid_receipt(
        "POST", subject.InvalidEvidence("broken evidence")
    )
    assert invalid["status"] == "INVALID"
    assert invalid["artifact_type"] == "QM5_13210_POST_INVALID"


def test_persisted_s4u_task_contract_and_timeout() -> None:
    helper = HELPER.read_text(encoding="utf-8-sig")
    assert "-LogonType S4U" in helper
    assert "-RunLevel Highest" in helper
    assert "-MultipleInstances IgnoreNew" in helper
    assert "New-ScheduledTaskTrigger" not in helper
    assert "Register-ScheduledTask" in helper
    assert " -Force" not in helper
    assert "_run-plan --job" in helper
    assert "CommandLine" not in helper
    assert "Win32_Process" not in helper
    assert "$beforeLastRunUtc" in helper
    assert "$newInvocationObserved" in helper
    assert "-gt $beforeLastRunUtc" in helper
    assert "'Identity', 'Probe', 'Register', 'Inspect', 'Start'" in helper
    assert "exists = $false" in helper
    pre = {"plan": {"cells": [{"cell_id": row.cell_id} for row in subject.WINDOWS]}}
    assert subject.cell_outer_timeout_seconds() == 59_400
    assert subject.required_scheduled_task_timeout(pre) == 241_200


def test_launch_persists_only_safe_scheduler_metadata(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    run_root = tmp_path / "run"
    pre_path = tmp_path / "pre.json"
    authorization_path = tmp_path / "authorization.json"
    state_path = run_root / "launch_state.json"
    pre_sha = "a" * 64
    dummy_binding = {
        "path": str(tmp_path / "bound.file"),
        "size": 1,
        "sha256": "b" * 64,
    }
    bindings = {
        "tool": dict(dummy_binding),
        "scheduled_task_helper": dict(dummy_binding),
        "python": dict(dummy_binding),
        "powershell": dict(dummy_binding),
        "runner": dict(dummy_binding),
        "set": dict(dummy_binding),
    }
    plan = subject.build_plan("EURUSD.DWX", bindings["set"], run_root)
    pre = {
        "run_root": str(run_root.resolve()),
        "bindings": bindings,
        "plan": plan,
    }
    authorization = {
        "binding": {
            "path": str(authorization_path.resolve()),
            "size": 1,
            "sha256": "c" * 64,
        },
        "payload_sha256": "d" * 64,
        "payload": {},
    }
    calls: list[str] = []

    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_args: pre)
    monkeypatch.setattr(subject, "validate_current_research_gate", lambda *_args: None)
    monkeypatch.setattr(
        subject, "validate_authorization", lambda *_args, **_kwargs: authorization
    )

    def fake_scheduler(
        _pre: object, operation: str, _job: object | None = None
    ) -> dict[str, object]:
        calls.append(operation)
        if operation == "Identity":
            return {"principal_sid": "S-1-5-21-13210"}
        return {"state": "Running" if operation == "Start" else "Ready"}

    monkeypatch.setattr(subject, "_scheduler_call", fake_scheduler)
    result = subject.launch_persistent_task(
        pre_path,
        pre_sha,
        authorization_path,
        state_path,
        resume=False,
    )
    assert result["status"] == "LAUNCHED_PERSISTED_TASK"
    assert calls == ["Identity", "Register", "Start"]
    job_text = (run_root / "launch_job.json").read_text(encoding="utf-8")
    state_text = state_path.read_text(encoding="utf-8")
    persisted = (job_text + state_text).casefold()
    assert "runner_command" not in persisted
    assert "command_line" not in persisted
    assert "-eaid" not in persisted
    assert "scheduled_task_helper" not in persisted
    state = subject.load_json(state_path)
    assert state["status"] == "PENDING_SCHEDULED"
    assert state["scheduler"]["logon_type"] == "S4U"
    assert state["scheduler"]["multiple_instances"] == "IgnoreNew"
    assert state["launches"][0]["status"] == "START_REQUESTED"

    # Simulate the CLI/session disappearing after Start but before a worker can
    # register.  Once the task is observed Ready and the outcome fence is clear,
    # an explicit resume closes the orphan request instead of poisoning POST.
    resumed = subject.launch_persistent_task(
        pre_path,
        pre_sha,
        authorization_path,
        state_path,
        resume=True,
    )
    assert resumed["status"] == "RESUMED_PERSISTED_TASK"
    assert calls == ["Identity", "Register", "Start", "Register", "Inspect", "Start"]
    state = subject.load_json(state_path)
    assert [row["status"] for row in state["launches"]] == [
        "ABANDONED_PRESTART",
        "START_REQUESTED",
    ]
    assert state["launches"][0].get("worker_pid") is None
    assert state["launches"][0]["reason"] == "TASK_NOT_RUNNING_AND_OUTCOME_FENCE_CLEAR"


def test_explicit_resume_recovers_only_the_outcome_free_orphan_job_gap(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    run_root = tmp_path / "orphan-run"
    pre_path = tmp_path / "pre.json"
    authorization_path = tmp_path / "authorization.json"
    state_path = run_root / "launch_state.json"
    job_path = run_root / "launch_job.json"
    pre_sha = "e" * 64
    dummy_binding = {
        "path": str(tmp_path / "bound.file"),
        "size": 1,
        "sha256": "f" * 64,
    }
    bindings = {
        "tool": dict(dummy_binding),
        "scheduled_task_helper": dict(dummy_binding),
        "python": dict(dummy_binding),
        "powershell": dict(dummy_binding),
        "runner": dict(dummy_binding),
        "set": dict(dummy_binding),
    }
    pre = {
        "run_root": str(run_root.resolve()),
        "bindings": bindings,
        "plan": subject.build_plan("EURUSD.DWX", bindings["set"], run_root),
    }
    authorization = {
        "binding": {
            "path": str(authorization_path.resolve()),
            "size": 1,
            "sha256": "1" * 64,
        },
        "payload_sha256": "2" * 64,
        "payload": {},
    }
    calls: list[str] = []

    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_args: pre)
    monkeypatch.setattr(subject, "validate_current_research_gate", lambda *_args: None)
    monkeypatch.setattr(
        subject, "validate_authorization", lambda *_args, **_kwargs: authorization
    )

    def fake_scheduler(
        _pre: object, operation: str, _job: object | None = None
    ) -> dict[str, object]:
        calls.append(operation)
        if operation == "Identity":
            return {"principal_sid": "S-1-5-21-13210"}
        if operation == "Probe":
            return {"exists": False, "state": "Absent"}
        return {"exists": True, "state": "Running" if operation == "Start" else "Ready"}

    monkeypatch.setattr(subject, "_scheduler_call", fake_scheduler)
    real_atomic_json = subject.atomic_json

    def crash_between_job_and_state(
        path: Path, payload: object, *, replace: bool
    ) -> str:
        if Path(path).resolve() == state_path.resolve():
            raise OSError("simulated death between job and state")
        return real_atomic_json(path, payload, replace=replace)

    monkeypatch.setattr(subject, "atomic_json", crash_between_job_and_state)
    with pytest.raises(OSError, match="between job and state"):
        subject.launch_persistent_task(
            pre_path,
            pre_sha,
            authorization_path,
            state_path,
            resume=False,
        )
    assert job_path.is_file()
    assert not state_path.exists()
    assert calls == ["Identity"]

    monkeypatch.setattr(subject, "atomic_json", real_atomic_json)
    with pytest.raises(subject.AuthorizationError, match="explicit --resume"):
        subject.launch_persistent_task(
            pre_path,
            pre_sha,
            authorization_path,
            state_path,
            resume=False,
        )

    unexpected = run_root / "unexpected.log"
    unexpected.write_text("must fail closed", encoding="utf-8")
    with pytest.raises(subject.AuthorizationError, match="otherwise empty run root"):
        subject.launch_persistent_task(
            pre_path,
            pre_sha,
            authorization_path,
            state_path,
            resume=True,
        )
    unexpected.unlink()

    recovered = subject.launch_persistent_task(
        pre_path,
        pre_sha,
        authorization_path,
        state_path,
        resume=True,
    )
    assert recovered["status"] == "RESUMED_PERSISTED_TASK"
    assert calls == ["Identity", "Probe", "Register", "Inspect", "Start"]
    state = subject.load_json(state_path)
    assert state["orphan_job_recovery"]["status"] == (
        "RECOVERED_PREOUTCOME_ATOMIC_WRITE_GAP"
    )
    assert state["orphan_job_recovery"]["task_absence_proved"] is True
    assert [row["status"] for row in state["launches"]] == [
        "ABANDONED_PRESTART",
        "START_REQUESTED",
    ]
    assert state["launches"][0]["reason"] == (
        "ORPHAN_JOB_RECOVERED_WITHOUT_STATE_TASK_OR_ARTIFACTS"
    )


def test_resume_rejects_completed_or_outcome_bearing_cells(tmp_path: Path) -> None:
    pending = {
        "status": "PENDING_SCHEDULED",
        "worker_pid": None,
        "finished_utc": None,
        "cells": [
            {"cell_id": row.cell_id, "status": "PENDING", "attempts": []}
            for row in subject.WINDOWS
        ],
    }
    assert subject.resume_eligible(pending)
    completed = json.loads(json.dumps(pending))
    completed["cells"][0]["status"] = "COMPLETE"
    assert not subject.resume_eligible(completed)
    interrupted = json.loads(json.dumps(pending))
    interrupted["status"] = "INTERRUPTED_RESUMABLE"
    interrupted["cells"][0].update(
        {
            "status": "INTERRUPTED_NO_OUTCOME",
            "attempts": [{"summary": None, "outcome_artifacts": []}],
        }
    )
    assert subject.resume_eligible(interrupted)
    interrupted["cells"][0]["attempts"][0]["outcome_artifacts"] = [
        {"path": str(tmp_path / "report.htm")}
    ]
    assert not subject.resume_eligible(interrupted)
