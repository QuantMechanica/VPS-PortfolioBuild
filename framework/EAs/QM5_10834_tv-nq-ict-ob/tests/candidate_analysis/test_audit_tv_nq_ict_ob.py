from __future__ import annotations

import importlib.util
import json
import sys
from dataclasses import replace
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_tv_nq_ict_ob.py"
)
SPEC = importlib.util.spec_from_file_location("audit_tv_nq_ict_ob", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _factory_evidence(tmp_path: Path) -> dict[str, Path]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    design = tmp_path / "V5_FRAMEWORK_DESIGN.md"
    design.write_text(
        "Symbols carry `.DWX` in research and backtest, stripped only at deploy packaging.\n",
        encoding="utf-8",
    )
    rules = tmp_path / "2026-04-28_seven_backtest_rules.md"
    rules.write_text(
        "### Rule 1 — Test ONLY on `.DWX` symbols\n\n"
        "Every backtest run uses the `.DWX`-suffixed custom symbols, never native broker symbols.\n",
        encoding="utf-8",
    )
    aliases = tmp_path / "execution_symbol_aliases_v1.json"
    _write_json(
        aliases,
        {
            "schema_version": 1,
            "artifact_type": "QM_EXECUTION_SYMBOL_ALIASES",
            "status": "ACTIVE",
            "venues": [
                {
                    "venue_id": "DXZ_LIVE",
                    "symbols": [
                        {"raw_symbol": "NDX", "logical_symbol": "NDX.DWX"}
                    ],
                },
                {
                    "venue_id": "FTMO_TRIAL",
                    "symbols": [
                        {"raw_symbol": "US100.cash", "logical_symbol": "NDX.DWX"}
                    ],
                },
            ],
        },
    )
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text(
        "symbol,asset_class,import_log_path,canonical_name_verified,evidence_line\n"
        "NDX.DWX,indices,Custom/Indices/Index 3/NDX.DWX,true,"
        "historical FAIL_tail_mid_bars live-parity evidence\n",
        encoding="utf-8",
    )
    cost = tmp_path / "venue_cost_model.json"
    _write_json(
        cost,
        {
            "symbols": {
                "NDX": {"asset_class": "index", "alias_of": "US100"},
                "US100": {
                    "asset_class": "index",
                    "dwx_symbol": "NDX.DWX",
                    "dxz": {
                        "commission_rt_per_lot_usd": 5.5,
                        "spread_source": "embedded in .DWX real-tick history",
                    },
                    "ftmo": {"commission_rt_per_lot_usd": 0.0},
                    "worst_case_rt_per_lot_usd": 5.5,
                },
            }
        },
    )
    done = tmp_path / "NDX_DUKASCOPY_REIMPORT.DONE"
    done.write_text(
        "status=OK\ntarget=NDX.DWX\nticks_added=563084925\nbars_updated=2744362\n",
        encoding="utf-8",
    )
    source = tmp_path / "QM_NDX_Reimport_20260718.mq5"
    source.write_text(
        '#define TARGET "NDX.DWX"\nvoid Rebuild(){ CustomTicksAdd(); CustomRatesUpdate(); }\n',
        encoding="utf-8",
    )
    return {
        "v5_framework": design,
        "backtest_rules": rules,
        "aliases": aliases,
        "matrix": matrix,
        "cost": cost,
        "rebuild_done": done,
        "rebuild_source": source,
    }


def _t1_ndx_store(tmp_path: Path) -> Path:
    data_root = tmp_path / "Custom"
    history = data_root / "history" / "NDX.DWX"
    ticks = data_root / "ticks" / "NDX.DWX"
    history.mkdir(parents=True)
    ticks.mkdir(parents=True)
    for year in subject._required_history_years():
        (history / f"{year}.hcc").write_bytes(f"hcc-{year}".encode("ascii"))
    for month in subject._required_tick_months():
        (ticks / f"{month}.tkc").write_bytes(f"tick-{month}".encode("ascii"))
    # Physical files outside the frozen period are legitimate and must not enter
    # the exact receipt closure.
    (ticks / "202601.tkc").write_bytes(b"out-of-range")
    return data_root


def _synthetic_trade(
    day: date,
    sequence: int,
    adjusted_net: Decimal,
    *,
    entry_deal: str | None = None,
) -> subject.TradeRecord:
    entry_ny = datetime.combine(day, time(9, 50))
    exit_ny = datetime.combine(day, time(10, 10))
    venue_cost = Decimal("5.50")
    return subject.TradeRecord(
        sequence=sequence,
        symbol="NDX.DWX",
        side="buy",
        entry_deal=entry_deal or f"{day:%Y%m%d}{sequence:04d}",
        exit_deals=(f"x{day:%Y%m%d}{sequence:04d}",),
        entry_time_broker=entry_ny + timedelta(hours=7),
        exit_time_broker=exit_ny + timedelta(hours=7),
        entry_time_ny=entry_ny,
        exit_time_ny=exit_ny,
        new_york_day=day.isoformat(),
        volume=Decimal("1"),
        native_net_usd=adjusted_net + venue_cost,
        venue_cost_usd=venue_cost,
        adjusted_net_usd=adjusted_net,
    )


def _passing_merit_cells() -> dict[str, list[subject.TradeRecord]]:
    dev_start = date(2018, 7, 2)
    dev = [
        _synthetic_trade(
            dev_start + timedelta(days=index),
            index + 1,
            Decimal("100") if index < 60 else Decimal("-50"),
        )
        for index in range(80)
    ]
    result = {"DEV": dev}
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
        "ea_id": 10834,
        "ea_label": "QM5_10834",
        "expert": r"QM\QM5_10834_tv-nq-ict-ob",
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
        "runs": [
            {"run": name, "status": "OK", "real_ticks_marker": True}
            for name in ("run_01", "run_02")
        ],
    }


def test_frozen_plan_is_one_symbol_four_disjoint_cells_and_two_duplicates(
    tmp_path: Path,
) -> None:
    set_binding = {"path": str(tmp_path / "candidate.set"), "size": 1, "sha256": "a" * 64}
    plan = subject.build_plan("NDX.DWX", set_binding, tmp_path / "run")
    assert plan["single_authorized_symbol"] == "NDX.DWX"
    assert plan["native_run_count"] == 8
    assert plan["technical_prescreen"]["authorized"] is False
    assert [row["cohort"] for row in plan["cells"]] == ["DEV", "OOS", "OOS", "OOS"]
    assert [(row["from_date"], row["to_date"]) for row in plan["cells"]] == [
        ("2018-07-02", "2022-12-31"),
        ("2023-01-01", "2023-12-31"),
        ("2024-01-01", "2024-12-31"),
        ("2025-01-01", "2025-12-31"),
    ]
    assert all(row["symbol"] == "NDX.DWX" for row in plan["cells"])
    assert all(row["model"] == 4 and row["duplicates"] == 2 for row in plan["cells"])
    subject.validate_window_contract()


@pytest.mark.parametrize("symbol", ["WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX", "NDX"])
def test_symbol_policy_allows_only_factory_ndx_dwx(symbol: str) -> None:
    with pytest.raises(subject.InvalidEvidence):
        subject.enforce_symbol_policy(symbol)
    subject.enforce_symbol_policy("NDX.DWX")


def test_hash_binding_role_closure_is_explicit() -> None:
    assert subject.REQUIRED_BINDING_ROLES == {
        "card",
        "pine",
        "spec",
        "mq5",
        "ex5",
        "set",
        "matrix",
        "cost",
        "live_commission",
        "v5_framework",
        "backtest_rules",
        "aliases",
        "rebuild_done",
        "rebuild_source",
        "runner",
        "report_parser",
        "powershell",
        "tool",
    }


def test_matrix_accepts_ndx_namespace_despite_live_parity_fail_note(tmp_path: Path) -> None:
    evidence = _factory_evidence(tmp_path)
    row = subject._matrix_row("NDX.DWX", evidence["matrix"])
    assert row == {
        "symbol": "NDX.DWX",
        "asset_class": "indices",
        "import_log_path": "Custom/Indices/Index 3/NDX.DWX",
        "canonical_name_verified": "true",
    }
    assert "evidence_line" not in row

    evidence["matrix"].write_text(
        evidence["matrix"].read_text(encoding="utf-8").replace(
            "Custom/Indices/Index 3/NDX.DWX", "Custom/Indices/Wrong/NDX.DWX"
        ),
        encoding="utf-8",
    )
    with pytest.raises(subject.InvalidEvidence, match="import path drift"):
        subject._matrix_row("NDX.DWX", evidence["matrix"])


def test_backtest_data_receipt_is_exact_atomic_and_outcome_blind(
    tmp_path: Path,
) -> None:
    evidence = _factory_evidence(tmp_path / "factory")
    data_root = _t1_ndx_store(tmp_path / "t1")
    payload = subject.freeze_backtest_data(
        "NDX.DWX", terminal_data_root=data_root, evidence_paths=evidence
    )
    assert payload["coverage"] == {
        "from_date": "2018-07-02",
        "to_date": "2025-12-31",
        "history_year_first": 2018,
        "history_year_last": 2025,
        "history_file_count": 8,
        "tick_month_first": "201807",
        "tick_month_last": "202512",
        "tick_file_count": 90,
    }
    assert payload["totals"]["files"] == 98
    assert all("202601.tkc" not in row["path"] for row in payload["files"])
    assert payload["outcome_fence"]["strategy_outcomes_read"] is False
    assert (
        payload["namespace_contract"][
            "live_ohlc_tail_parity_required_for_research_merit"
        ]
        is False
    )

    receipt = tmp_path / "receipt.json"
    subject.atomic_json(receipt, payload, replace=False)
    validated = subject.validate_backtest_data_receipt(
        receipt,
        "NDX.DWX",
        terminal_data_root=data_root,
        evidence_paths=evidence,
    )
    assert validated["receipt"]["sha256"]
    assert set(validated["factory_evidence"]) == subject.DATA_FACTORY_EVIDENCE_ROLES
    with pytest.raises(subject.InvalidEvidence, match="refusing to replace evidence"):
        subject.atomic_json(receipt, payload, replace=False)

    malicious = json.loads(json.dumps(payload))
    extra_path = data_root / "ticks" / "NDX.DWX" / "202601.tkc"
    malicious["files"].append(
        {
            "kind": "ticks",
            "period": "202601",
            **subject.stable_file_binding(extra_path),
        }
    )
    extra_receipt = tmp_path / "extra.json"
    _write_json(extra_receipt, malicious)
    with pytest.raises(subject.InvalidEvidence, match="exactly 98 files"):
        subject.validate_backtest_data_receipt(
            extra_receipt,
            "NDX.DWX",
            terminal_data_root=data_root,
            evidence_paths=evidence,
        )

    bound_tick = data_root / "ticks" / "NDX.DWX" / "202512.tkc"
    bound_tick.write_bytes(b"tampered-bound-tick")
    with pytest.raises(subject.InvalidEvidence, match="drift"):
        subject.validate_backtest_data_receipt(
            receipt,
            "NDX.DWX",
            terminal_data_root=data_root,
            evidence_paths=evidence,
        )
    bound_tick.unlink()
    with pytest.raises(subject.InvalidEvidence, match="required file missing"):
        subject.freeze_backtest_data(
            "NDX.DWX", terminal_data_root=data_root, evidence_paths=evidence
        )


def test_cost_schedule_uses_exact_worst_of_dxz_and_ftmo(tmp_path: Path) -> None:
    path = _factory_evidence(tmp_path)["cost"]
    payload = json.loads(path.read_text(encoding="utf-8"))
    schedule = subject.resolve_cost_schedule(path, "NDX.DWX")
    assert schedule["alias_chain"] == ["NDX", "US100"]
    assert schedule["dxz_rt_per_lot_usd"] == "5.5"
    assert schedule["ftmo_rt_per_lot_usd"] == "0"
    assert schedule["worst_rt_per_lot_usd"] == "5.5"
    payload["symbols"]["US100"]["worst_case_rt_per_lot_usd"] = 5.49
    _write_json(path, payload)
    with pytest.raises(subject.InvalidEvidence, match="worst-case drift"):
        subject.resolve_cost_schedule(path, "NDX.DWX")

    payload["symbols"]["NDX"]["alias_of"] = "NDX"
    _write_json(path, payload)
    with pytest.raises(subject.InvalidEvidence, match="alias cycle"):
        subject.resolve_cost_schedule(path, "NDX.DWX")


def test_ndx_set_contract_requires_magic_slot_zero() -> None:
    metadata = {"symbol": "NDX.DWX", "timeframe": "M5"}
    inputs = {
        "qm_ea_id": "10834",
        "qm_magic_slot_offset": "0",
        "RISK_FIXED": "1000",
        "RISK_PERCENT": "0",
        "strategy_entry_start_hhmm": "945",
        "strategy_entry_end_hhmm": "1015",
        "strategy_target_r": "2.0",
    }
    subject._validate_set_contract("NDX.DWX", metadata, inputs)
    inputs["qm_magic_slot_offset"] = "1"
    with pytest.raises(subject.InvalidEvidence, match="set input contract drift"):
        subject._validate_set_contract("NDX.DWX", metadata, inputs)


def test_effective_input_contract_closes_defaults_set_values_and_enums(
    tmp_path: Path,
) -> None:
    source = tmp_path / "candidate.mq5"
    include = tmp_path / "common.mqh"
    source.write_text(
        "enum Mode { MODE_A=0, MODE_B=1 };\n"
        "input int count=4;\n"
        "input Mode mode=MODE_A;\n"
        "input bool enabled=true;\n",
        encoding="utf-8",
    )
    include.write_text("input double fee=0.0;\n", encoding="utf-8")
    contract = subject.effective_input_contract(
        source,
        [subject.file_binding(include)],
        {"mode": "MODE_B", "fee": "0.7000"},
    )
    assert contract["count"]["canonical"] == "4"
    assert contract["mode"]["canonical"] == "1"
    assert contract["enabled"]["canonical"] == "true"
    assert contract["fee"]["canonical"] == "0.7"
    with pytest.raises(subject.InvalidEvidence, match="absent"):
        subject.effective_input_contract(
            source, [subject.file_binding(include)], {"unknown": "1"}
        )


def test_stale_build_receipt_is_expected_fail_closed_not_merit_fail(tmp_path: Path) -> None:
    hashes = {
        "mq5": "1" * 64,
        "ex5": "2" * 64,
        "spec": "3" * 64,
        "pine": "4" * 64,
        "set": "5" * 64,
    }
    bindings = {
        role: {"path": str(tmp_path / role), "size": 0, "sha256": digest}
        for role, digest in hashes.items()
    }
    receipt = tmp_path / "build.json"
    _write_json(
        receipt,
        {
            "ea_id": "QM5_10834",
            "build_check_passed": True,
            "compile_succeeded": True,
            "build_commit": "a" * 40,
            "source_sha256": hashes["mq5"],
            "ex5_sha256": hashes["ex5"],
            "spec_sha256": "f" * 64,
            "primary_source_sha256": hashes["pine"],
            "setfile_sha256": {"NDX.DWX": hashes["set"]},
        },
    )
    with pytest.raises(subject.InvalidEvidence, match="spec_sha256"):
        subject.validate_build_receipt(receipt, "NDX.DWX", bindings)


def test_multiline_native_report_inputs_are_all_parsed() -> None:
    class Core:
        FIELD_ALIASES = {"inputs": {"inputs"}}

        @staticmethod
        def _norm(value: str) -> str:
            return value.strip().rstrip(":").casefold()

        @staticmethod
        def _clean_text(value: str) -> str:
            return value.strip()

    ordered, mapping = subject._report_inputs(
        Core,
        [
            ["Inputs:", "qm_ea_id=10834"],
            ["", "RISK_FIXED=1000", "strategy_bias_mode=0"],
            ["Symbol:", "NDX.DWX"],
        ],
    )
    assert ordered == [
        "qm_ea_id=10834",
        "RISK_FIXED=1000",
        "strategy_bias_mode=0",
    ]
    assert mapping == {
        "qm_ea_id": "10834",
        "RISK_FIXED": "1000",
        "strategy_bias_mode": "0",
    }


def test_runner_command_freezes_model4_two_duplicates_zero_native_cost(
    tmp_path: Path,
) -> None:
    set_binding = {"path": str(tmp_path / "candidate.set"), "size": 1, "sha256": "a" * 64}
    cell = subject.build_plan("NDX.DWX", set_binding, tmp_path / "run")["cells"][0]
    pre = {
        "bindings": {
            "powershell": {"path": str(tmp_path / "pwsh.exe")},
            "runner": {"path": str(tmp_path / "run_smoke.ps1")},
        },
        "plan": {"plan_sha256": "b" * 64},
    }
    command = subject.runner_command(pre, cell)
    assert command[command.index("-Terminal") + 1] == "T1"
    assert command[command.index("-Model") + 1] == "4"
    assert command[command.index("-Runs") + 1] == "2"
    assert command[command.index("-MinTrades") + 1] == "0"
    assert command[command.index("-CommissionPerLot") + 1] == "0"
    assert command[command.index("-CommissionPerSideNative") + 1] == "0"
    assert command[-1] == "-SmokeMode"


def test_trade_reconstruction_applies_external_cost_once_and_checks_session() -> None:
    entry = SimpleNamespace(
        direction="in",
        symbol="NDX.DWX",
        volume=Decimal("2"),
        commission=Decimal("0"),
        swap=Decimal("0"),
        kind="buy",
        deal="10",
        time=datetime(2025, 2, 3, 16, 50),
        raw_net=Decimal("0"),
    )
    close = SimpleNamespace(
        direction="out",
        symbol="NDX.DWX",
        volume=Decimal("2"),
        commission=Decimal("0"),
        swap=Decimal("0"),
        kind="sell",
        deal="11",
        time=datetime(2025, 2, 3, 17, 10),
        raw_net=Decimal("100"),
    )
    trades = subject._reconstruct_trades([entry, close], "NDX.DWX", Decimal("5.50"))
    assert len(trades) == 1
    assert trades[0].venue_cost_usd == Decimal("11.00")
    assert trades[0].adjusted_net_usd == Decimal("89.00")
    assert subject.validate_trade_semantics(trades)["status"] == "PASS"

    outside = replace(
        trades[0],
        entry_time_ny=datetime(2025, 2, 3, 10, 15),
    )
    with pytest.raises(subject.InvalidEvidence, match="outside half-open"):
        subject.validate_trade_semantics([outside])
    late = replace(trades[0], exit_time_ny=datetime(2025, 2, 3, 10, 20))
    with pytest.raises(subject.InvalidEvidence, match="not flat"):
        subject.validate_trade_semantics([late])
    second = replace(trades[0], sequence=2, entry_deal="12")
    with pytest.raises(subject.InvalidEvidence, match="more than one entry"):
        subject.validate_trade_semantics([trades[0], second])


def test_duplicate_identity_requires_exact_deal_sequence_and_fingerprint() -> None:
    trade = _synthetic_trade(date(2025, 1, 2), 1, Decimal("10"))
    baseline = subject.NativeRunAudit({}, "a" * 64, "b" * 64, [trade])
    subject.require_duplicate_identity([baseline, baseline])
    drift = subject.NativeRunAudit({}, "c" * 64, "b" * 64, [trade])
    with pytest.raises(subject.InvalidEvidence, match="Deal sequence drift"):
        subject.require_duplicate_identity([baseline, drift])


def test_drawdown_percent_uses_peak_at_each_drawdown_not_later_global_peak() -> None:
    rows = [
        _synthetic_trade(date(2023, 1, 2), 1, Decimal("10000")),
        _synthetic_trade(date(2023, 1, 3), 2, Decimal("-11000")),
        _synthetic_trade(date(2023, 1, 4), 3, Decimal("101000")),
    ]
    metrics = subject.performance(rows)
    assert Decimal(metrics["maximum_close_drawdown_percent"]) == Decimal("10.0")


def test_all_frozen_merit_gates_can_pass_and_a_valid_miss_is_fail() -> None:
    cells = _passing_merit_cells()
    result = subject.evaluate_merit(cells)
    assert result["status"] == "PASS"
    assert all(row["status"] == "PASS" for row in result["gates"])
    assert result["contract"] == subject.MERIT_GATES

    cells["OOS_2025"] = cells["OOS_2025"][:11]
    failed = subject.evaluate_merit(cells)
    assert failed["status"] == "FAIL"
    assert next(
        row for row in failed["gates"] if row["gate_id"] == "OOS_2025_MIN_TRADES"
    )["status"] == "FAIL"


def test_merit_thresholds_are_versioned_and_absent_from_cli() -> None:
    assert subject.MERIT_GATES["dev"]["minimum_trades"] == 80
    assert subject.MERIT_GATES["dev"]["minimum_cost_profit_factor"] == "1.20"
    assert subject.MERIT_GATES["each_oos_year"]["minimum_trades"] == 12
    assert subject.MERIT_GATES["oos_pooled"]["minimum_trades"] == 45
    assert subject.MERIT_GATES["leave_best_oos_year_out"]["minimum_cost_profit_factor"] == "1.05"
    parser = subject.build_parser()
    subparsers = next(action for action in parser._actions if getattr(action, "choices", None))
    options = {
        option
        for command in subparsers.choices.values()
        for action in command._actions
        for option in getattr(action, "option_strings", [])
    }
    assert not any("threshold" in option or "minimum" in option or "drawdown" in option for option in options)
    freeze_options = {
        option
        for action in subparsers.choices["freeze-data"]._actions
        for option in action.option_strings
    }
    pre_options = {
        option
        for action in subparsers.choices["pre"]._actions
        for option in action.option_strings
    }
    assert freeze_options == {"-h", "--help", "--symbol", "--receipt"}
    assert "--data-receipt" in pre_options
    assert "--validation-receipt" not in pre_options
    assert "--data-manifest" not in pre_options


def test_runner_summary_requires_exactly_two_model4_marked_duplicates() -> None:
    cell = {"symbol": "NDX.DWX"}
    summary = _runner_summary(cell)
    subject.validate_runner_summary(summary, cell)
    summary["runs"][1]["real_ticks_marker"] = False
    with pytest.raises(subject.InvalidEvidence, match="Model-4 marker"):
        subject.validate_runner_summary(summary, cell)


def test_authorization_is_owner_scoped_short_lived_and_pre_bound(tmp_path: Path) -> None:
    now = datetime(2026, 7, 20, 12, 0, tzinfo=timezone.utc)
    payload = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": subject.ANALYSIS_ID,
        "pre_receipt_sha256": "a" * 64,
        "scope": "QM5_10834_NDX_4_CELLS_X_2_DUPLICATES_MODEL4",
        "authorized_by": "OWNER",
        "authorized_symbol": "NDX.DWX",
        "authorized_cells": [window.cell_id for window in subject.WINDOWS],
        "duplicates_per_cell": 2,
        "model": 4,
        "authorize_native_outcomes": True,
        "created_utc": (now - timedelta(minutes=1)).isoformat(),
        "expires_utc": (now + timedelta(hours=1)).isoformat(),
    }
    path = tmp_path / "authorization.json"
    _write_json(path, payload)
    assert subject.validate_authorization(path, "a" * 64, now=now)["binding"]["sha256"]
    payload["authorized_symbol"] = "WS30.DWX"
    _write_json(path, payload)
    with pytest.raises(subject.AuthorizationError, match="drift"):
        subject.validate_authorization(path, "a" * 64, now=now)


def test_resume_only_accepts_no_outcome_interruption_and_stale_start() -> None:
    pending_cells = [
        {"cell_id": window.cell_id, "status": "PENDING", "attempts": []}
        for window in subject.WINDOWS
    ]
    assert subject.resume_eligible(
        {"status": "PENDING", "worker_pid": None, "cells": pending_cells}
    )
    interrupted = [dict(row) for row in pending_cells]
    interrupted[0] = {
        "cell_id": "DEV",
        "status": "INTERRUPTED_NO_OUTCOME",
        "attempts": [{"summary": None, "outcome_artifacts": []}],
    }
    state = {"status": "INTERRUPTED_RESUMABLE", "worker_pid": None, "cells": interrupted}
    assert subject.resume_eligible(state)
    interrupted[0]["attempts"][0]["summary"] = {"sha256": "a" * 64}
    assert not subject.resume_eligible(state)

    now = datetime(2026, 7, 20, 12, 0, tzinfo=timezone.utc)
    stale = {
        "status": "STARTING_WORKER",
        "worker_pid": None,
        "updated_utc": (now - timedelta(minutes=6)).isoformat(),
        "cells": pending_cells,
    }
    assert subject.resume_eligible(stale, now=now)
    stale["updated_utc"] = (now - timedelta(minutes=1)).isoformat()
    assert not subject.resume_eligible(stale, now=now)


def test_resume_archives_non_outcome_logs_and_resets_accepted_attempt_count(
    tmp_path: Path,
) -> None:
    run_root = tmp_path / "run"
    output_root = run_root / "native" / "DEV"
    output_root.mkdir(parents=True)
    (output_root / "controller.stdout.log").write_text("non-outcome", encoding="utf-8")
    cell = {"cell_id": "NDX_DWX_DEV", "output_root": str(output_root)}
    state_cell = {
        "cell_id": "NDX_DWX_DEV",
        "status": "INTERRUPTED_NO_OUTCOME",
        "attempts": [{"summary": None, "outcome_artifacts": [], "exit_code": 2}],
    }
    subject._archive_interrupted_no_outcome({"run_root": str(run_root)}, cell, state_cell)
    assert state_cell["status"] == "PENDING"
    assert state_cell["attempts"] == []
    assert len(state_cell["interruptions"]) == 1
    assert not output_root.exists()
    archived = state_cell["interruptions"][0]
    assert archived["artifacts"][0]["sha256"]


def test_outcome_artifact_makes_interrupted_cell_non_resumable(tmp_path: Path) -> None:
    output_root = tmp_path / "run" / "native" / "DEV"
    output_root.mkdir(parents=True)
    (output_root / "report.html").write_text("opaque outcome", encoding="utf-8")
    state_cell = {
        "status": "INTERRUPTED_NO_OUTCOME",
        "attempts": [{"summary": None, "outcome_artifacts": []}],
    }
    with pytest.raises(subject.InvalidEvidence, match="outcome artifact appeared"):
        subject._archive_interrupted_no_outcome(
            {"run_root": str(tmp_path / "run")},
            {"cell_id": "NDX_DWX_DEV", "output_root": str(output_root)},
            state_cell,
        )


def test_invalid_receipt_is_distinct_from_valid_merit_fail() -> None:
    receipt = subject.invalid_receipt("POST", subject.InvalidEvidence("broken evidence"))
    assert receipt["status"] == "INVALID"
    assert receipt["artifact_type"] == "QM5_10834_POST_INVALID"
    merit = _passing_merit_cells()
    merit["DEV"] = merit["DEV"][:79]
    assert subject.evaluate_merit(merit)["status"] == "FAIL"
