from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
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
        "terminal": "DEV2",
        "model": 4,
        "period": "M5",
        "requested_runs": 2,
        "max_run_attempts": 4,
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


def _warmup_run(
    name: str,
    *,
    failure: str = "BARS_ZERO",
    reasons: list[str] | None = None,
) -> dict[str, object]:
    return {
        "run": name,
        "status": "INVALID",
        "failure": failure,
        "invalid_report_reasons": reasons or ["BARS_ZERO"],
        "total_trades": 0,
        "profit_factor": "0",
        "profit_factor_raw": "0.00",
        "drawdown": "0",
        "drawdown_raw": "0.00",
        "net_profit": "0",
        "net_profit_raw": "0.00",
        "exit_code": 0,
        "report_size_bytes": 1,
        "report_canonical_path": rf"D:\evidence\raw\{name}\report.htm",
        "tester_log_path": rf"D:\evidence\raw\{name}\tester.log",
    }


def test_frozen_plan_is_one_symbol_four_disjoint_cells_and_two_duplicates(
    tmp_path: Path,
) -> None:
    set_binding = {"path": str(tmp_path / "candidate.set"), "size": 1, "sha256": "a" * 64}
    plan = subject.build_plan("NDX.DWX", set_binding, tmp_path / "run")
    assert plan["single_authorized_symbol"] == "NDX.DWX"
    assert plan["accepted_duplicate_run_count"] == 8
    assert plan["maximum_native_starts"] == 16
    contract = subject.execution_contract()
    assert contract["claim_sequence"] == 3
    assert contract["reserved_counted_alternate_attempt_number"] == 2
    assert contract["prior_claim_sequences"] == 2
    assert contract["maximum_counted_alternate_attempts"] == 2
    assert contract["prior_counted_alternate_attempts"] == 1
    assert contract["claim_creation_alone_does_not_count_as_alternate_attempt"] is True
    assert contract["authorization_scope"] == subject.AUTHORIZATION_SCOPE
    assert Path(contract["native_attempt_claim_path"]).name.endswith("ATTEMPT_003.json")
    assert subject.LAUNCHER_REVISION == 6
    assert contract["native_run_timeout_seconds"] == 28_800
    assert contract["native_per_attempt_overhead_seconds"] == 600
    assert contract["cell_outer_timeout_seconds"] == 119_400
    assert plan["technical_prescreen"]["authorized"] is False
    assert [row["cohort"] for row in plan["cells"]] == ["DEV", "OOS", "OOS", "OOS"]
    assert [(row["from_date"], row["to_date"]) for row in plan["cells"]] == [
        ("2018-07-02", "2022-12-31"),
        ("2023-01-01", "2023-12-31"),
        ("2024-01-01", "2024-12-31"),
        ("2025-01-01", "2025-12-31"),
    ]
    assert all(row["symbol"] == "NDX.DWX" for row in plan["cells"])
    assert all(
        row["model"] == 4
        and row["duplicates"] == 2
        and row["maximum_postflight_acceptable_infrastructure_warmups"] == 2
        and row["maximum_attempts"] == 4
        and row["native_start_budget_is_outcome_independent"] is True
        for row in plan["cells"]
    )
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
        "runner_child",
        "dev2_cleanup_helper",
        "dev2_machine_credential_probe",
        "dev2_machine_credential_helper",
        "dev2_machine_credential",
        "runner_smoke",
        "dev2_lane_contract",
        "tester_groups_canonical",
        "tester_groups_dev2",
        "dev2_symbol_database",
        "infra_retry_contract",
        "report_parser",
        "powershell",
        "python",
        "scheduled_task_helper",
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
    assert payload["schema_version"] == 2
    assert payload["terminal"] == "DEV2"
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
            "runner": {"path": str(tmp_path / "run_dev2_smoke.ps1")},
            "dev2_machine_credential": {
                "path": str(tmp_path / "credential.machine-dpapi.json"),
                "sha256": "c" * 64,
            },
            "dev2_machine_credential_helper": {
                "path": str(tmp_path / "dev2_machine_credential.ps1"),
                "sha256": "d" * 64,
            },
        },
        "plan": {"plan_sha256": "b" * 64},
        "execution_contract": subject.execution_contract(),
    }
    command = subject.runner_command(pre, cell)
    assert "-Terminal" not in command
    assert "-ReportRoot" not in command
    assert Path(command[command.index("-File") + 1]).name == "run_dev2_smoke.ps1"
    assert command[command.index("-Model") + 1] == "4"
    assert command[command.index("-Runs") + 1] == "2"
    assert command[command.index("-MinTrades") + 1] == "0"
    assert command[command.index("-CommissionPerLot") + 1] == "0"
    assert command[command.index("-CommissionPerSideNative") + 1] == "0"
    assert command[command.index("-ExpectedCredentialSha256") + 1] == "c" * 64
    assert command[command.index("-ExpectedHelperSha256") + 1] == "d" * 64
    assert command[-1] == "-SmokeMode"


def _probe_pre(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict[str, object], str]:
    monkeypatch.setattr(subject, "ALLOWED_RUN_ROOT", tmp_path)
    run_root = tmp_path / "run"
    run_root.mkdir()
    paths = {
        "powershell": tmp_path / "pwsh.exe",
        "dev2_machine_credential_probe": tmp_path / "probe_dev2_machine_credential.ps1",
        "dev2_machine_credential_helper": tmp_path / "dev2_machine_credential.ps1",
        "dev2_machine_credential": tmp_path / "credential.machine-dpapi.json",
    }
    for role, path in paths.items():
        path.write_bytes(role.encode("ascii"))
    pre: dict[str, object] = {
        "run_root": str(run_root),
        "bindings": {role: subject.file_binding(path) for role, path in paths.items()},
        "execution_contract": subject.execution_contract(),
    }
    worker_sid = "S-1-5-21-100-200-300-500"
    return pre, worker_sid


def test_same_worker_machine_credential_probe_is_exactly_bound_before_claim(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pre, worker_sid = _probe_pre(tmp_path, monkeypatch)

    def fake_run(command: list[str], **_kwargs: object) -> SimpleNamespace:
        receipt_path = Path(command[command.index("-ReceiptPath") + 1])
        _kwargs["stdout"].write(b"PASS QM_DEV2_MACHINE_CREDENTIAL_PRECLAIM_PROBE\n")
        _write_json(
            receipt_path,
            {
                "schema_version": 1,
                "artifact_type": "QM_DEV2_MACHINE_CREDENTIAL_PRECLAIM_PROBE",
                "status": "PASS",
                "created_utc": datetime.now(timezone.utc).isoformat(),
                "worker_principal_sid": worker_sid,
                "expected_account": "QMDev2",
                "credential_account_sid": "S-1-5-21-100-200-300-1001",
                "credential_path": pre["bindings"]["dev2_machine_credential"]["path"],
                "credential_sha256": pre["bindings"]["dev2_machine_credential"]["sha256"],
                "helper_path": pre["bindings"]["dev2_machine_credential_helper"]["path"],
                "helper_sha256": pre["bindings"]["dev2_machine_credential_helper"]["sha256"],
                "native_counting_boundary_crossed": False,
                "dev2_run_directory_created": False,
                "metatester_started": False,
            },
        )
        assert command[command.index("-ExpectedCredentialSha256") + 1] == pre["bindings"][
            "dev2_machine_credential"
        ]["sha256"]
        assert command[command.index("-ExpectedHelperSha256") + 1] == pre["bindings"][
            "dev2_machine_credential_helper"
        ]["sha256"]
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(subject.subprocess, "run", fake_run)
    execution = subject._execute_machine_credential_preclaim_probe(pre)
    validated = subject.validate_machine_credential_preclaim_probe(
        execution, pre, worker_sid
    )
    assert validated["status"] == "PASS"
    assert validated["receipt_payload_sha256"]
    assert subject.validate_bound_machine_credential_preclaim_probe(
        validated, pre, worker_sid
    ) == validated

    receipt_path = Path(validated["receipt"]["path"])
    receipt = subject.load_json(receipt_path)
    receipt["native_counting_boundary_crossed"] = True
    _write_json(receipt_path, receipt)
    tampered = dict(execution)
    tampered["receipt"] = subject.file_binding(receipt_path)
    with pytest.raises(subject.InvalidEvidence, match="identity/binding drift"):
        subject.validate_machine_credential_preclaim_probe(tampered, pre, worker_sid)


def test_preclaim_failure_state_never_claims_or_crosses_outcome_fence(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    claim_path = tmp_path / "claims" / "attempt003.json"
    monkeypatch.setattr(subject, "NATIVE_ATTEMPT_CLAIM_PATH", claim_path)
    state_path = tmp_path / "launch_state.json"
    state = _preoutcome_state("RUNNING")
    state["worker_pid"] = 123
    persisted = subject._persist_invalid_preclaim_state(
        state_path,
        state,
        {"status": "COMPLETED_UNVALIDATED", "exit_code": 1},
        subject.InvalidEvidence("credential probe failed"),
    )
    assert persisted["status"] == "INVALID_PREFLIGHT"
    assert persisted["worker_pid"] is None
    assert persisted["attempt_claim"] is None
    assert persisted["active_cell"] is None
    assert persisted["outcome_possible_since_utc"] is None
    assert all(cell["status"] == "PENDING" and cell["attempts"] == [] for cell in persisted["cells"])
    assert not claim_path.exists()


def _infra_retry_002_fixture(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[Path, dict[str, object], Path, Path]:
    prior_root = tmp_path / "prior"
    prior_root.mkdir()
    prior_pre = prior_root / "pre_receipt.json"
    prior_state = prior_root / "launch_state.json"
    prior_pre.write_bytes(b"prior-pre")
    prior_state.write_bytes(b"prior-state")
    pre_sha = subject.sha256_file(prior_pre)
    state_sha = subject.sha256_file(prior_state)
    monkeypatch.setattr(subject, "PRIOR_INFRA_RUN_ROOT", prior_root)
    monkeypatch.setattr(subject, "PRIOR_INFRA_PRE_SHA256", pre_sha)
    monkeypatch.setattr(subject, "PRIOR_INFRA_STATE_SHA256", state_sha)
    controller_root = tmp_path / "controller_preflight"
    controller_root.mkdir()
    controller_pre = controller_root / "pre_receipt.json"
    controller_state = controller_root / "launch_state.json"
    controller_pre.write_bytes(b"controller-pre")
    controller_state.write_bytes(b"controller-state")
    controller_pre_sha = subject.sha256_file(controller_pre)
    controller_state_sha = subject.sha256_file(controller_state)
    monkeypatch.setattr(subject, "CONTROLLER_PREFLIGHT_RUN_ROOT", controller_root)
    monkeypatch.setattr(subject, "CONTROLLER_PREFLIGHT_PRE_SHA256", controller_pre_sha)
    monkeypatch.setattr(subject, "CONTROLLER_PREFLIGHT_STATE_SHA256", controller_state_sha)

    ea_root = tmp_path / "ea"
    set_path = ea_root / "sets" / f"{subject.EXPERT_NAME}_{subject.RESEARCH_SYMBOL}_M5_backtest.set"
    set_path.parent.mkdir(parents=True)
    set_path.write_bytes(b"frozen-set")
    ex5_path = ea_root / "experts" / "candidate.ex5"
    ex5_path.parent.mkdir(parents=True)
    ex5_path.write_bytes(b"frozen-ex5")
    cost_path = ea_root / "cost.json"
    cost_path.write_bytes(b"frozen-cost")
    monkeypatch.setattr(subject, "EA_ROOT", ea_root)
    monkeypatch.setattr(subject, "EX5_PATH", ex5_path)
    monkeypatch.setattr(subject, "COST_PATH", cost_path)

    native_root = tmp_path / "prior_native_attempt"
    prior_pre = native_root / "pre_receipt.json"
    prior_state = native_root / "launch_state.json"
    prior_claim = tmp_path / "claims" / "attempt_001.json"
    dev2_run_id = "20260720T185245Z_dbe5955f706048be92ec916523b2e2f7"
    dev2_root = tmp_path / "dev2" / dev2_run_id
    dev2_result = dev2_root / "output" / "result.json"
    controller_stderr = native_root / "native" / "DEV" / "controller.stderr.log"
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_RUN_ROOT", native_root)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_CLAIM_PATH", prior_claim)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_DEV2_RUN_ID", dev2_run_id)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_DEV2_RUN_ROOT", dev2_root)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_DEV2_RESULT_PATH", dev2_result)
    monkeypatch.setattr(
        subject, "PRIOR_NATIVE_ATTEMPT_CONTROLLER_STDERR_PATH", controller_stderr
    )

    frozen_bindings = {
        "ex5": subject.file_binding(ex5_path),
        "set": subject.file_binding(set_path),
        "cost": subject.file_binding(cost_path),
    }
    plan_sha = "7" * 64
    cells = [
        {
            "cell_id": f"{subject.RESEARCH_SYMBOL.replace('.', '_')}_{window.cell_id}",
            "symbol": subject.RESEARCH_SYMBOL,
            "cohort": window.cohort,
            "from_date": window.from_date.isoformat(),
            "to_date": window.to_date.isoformat(),
            "timeframe": subject.TIMEFRAME,
            "model": 4,
            "duplicates": subject.DUPLICATES,
            "maximum_postflight_acceptable_infrastructure_warmups": subject.MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL,
            "maximum_attempts": subject.MAX_ATTEMPTS_PER_CELL,
            "native_start_budget_is_outcome_independent": True,
            "set": frozen_bindings["set"],
            "output_root": str((native_root / "native" / window.cell_id).resolve()),
        }
        for window in subject.WINDOWS
    ]
    prior_pre_payload = {
        "schema_version": subject.SCHEMA_VERSION,
        "artifact_type": "QM5_10834_OUTCOME_FENCED_PRE_RECEIPT",
        "status": "PASS",
        "analysis_id": subject.ANALYSIS_ID,
        "run_root": str(native_root.resolve()),
        "outcome_fence": {
            "native_reports_opened": False,
            "deal_rows_parsed": False,
            "market_values_parsed": False,
            "mt5_terminal_started": False,
            "metatester_started": False,
        },
        "bindings": frozen_bindings,
        "merit_contract": subject.MERIT_GATES,
        "symbol_policy": {"authorized_symbol": subject.RESEARCH_SYMBOL},
        "plan": {
            "plan_sha256": plan_sha,
            "single_authorized_symbol": subject.RESEARCH_SYMBOL,
            "accepted_duplicate_run_count": len(subject.WINDOWS) * subject.DUPLICATES,
            "maximum_native_starts": len(subject.WINDOWS) * subject.MAX_ATTEMPTS_PER_CELL,
            "cells": cells,
        },
    }
    _write_json(prior_pre, prior_pre_payload)
    prior_pre_sha = subject.sha256_file(prior_pre)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_PRE_SHA256", prior_pre_sha)

    controller_stderr.parent.mkdir(parents=True, exist_ok=True)
    controller_stderr.write_text(
        "CHILD_PRECHECK_FAILED\n"
        "run_dev2_smoke.ps1:1064\n"
        f"{dev2_root / 'output' / 'run.log'}\n",
        encoding="utf-8",
    )
    controller_stderr_sha = subject.sha256_file(controller_stderr)
    monkeypatch.setattr(
        subject,
        "PRIOR_NATIVE_ATTEMPT_CONTROLLER_STDERR_SHA256",
        controller_stderr_sha,
    )

    prior_claim_payload = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_DEV2_NATIVE_ATTEMPT_CLAIM",
        "analysis_id": subject.ANALYSIS_ID,
        "attempt_number": 1,
        "maximum_alternate_attempts": 1,
        "classification": "ATOMIC_GLOBAL_ONE_SHOT_NATIVE_EXECUTION_CLAIM",
        "pre_receipt": subject.file_binding(prior_pre),
        "run_root": str(native_root.resolve()),
        "launch_state_path": str(prior_state.resolve()),
        "plan_sha256": plan_sha,
        "ea_binary": frozen_bindings["ex5"],
        "set": frozen_bindings["set"],
    }
    _write_json(prior_claim, prior_claim_payload)
    prior_claim_sha = subject.sha256_file(prior_claim)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_CLAIM_SHA256", prior_claim_sha)

    stdout_path = native_root / "native" / "DEV" / "controller.stdout.log"
    stdout_path.write_bytes(b"")
    state_cells: list[dict[str, object]] = [
        {
            "cell_id": cells[0]["cell_id"],
            "status": "INVALID_TERMINAL_OUTPUT",
            "attempts": [
                {
                    "exit_code": 1,
                    "native_root": None,
                    "summary": None,
                    "runner_result": None,
                    "outcome_artifacts": [],
                    "stdout": subject.file_binding(stdout_path),
                    "stderr": subject.file_binding(controller_stderr),
                }
            ],
        },
        *[
            {"cell_id": cell["cell_id"], "status": "PENDING", "attempts": []}
            for cell in cells[1:]
        ],
    ]
    prior_state_payload = {
        "schema_version": subject.SCHEMA_VERSION,
        "launcher_revision": 4,
        "artifact_type": "QM5_10834_NATIVE_LAUNCH_STATE",
        "analysis_id": subject.ANALYSIS_ID,
        "status": "INVALID_TERMINAL",
        "worker_pid": None,
        "finished_utc": None,
        "pre_receipt_path": str(prior_pre.resolve()),
        "pre_receipt_sha256": prior_pre_sha,
        "plan_sha256": plan_sha,
        "attempt_claim": subject.file_binding(prior_claim),
        "outcome_possible_since_utc": "2026-07-20T18:52:45Z",
        "active_cell": {
            "cell_id": cells[0]["cell_id"],
            "status": "OUTCOME_POSSIBLE_NO_RESUME",
        },
        "cells": state_cells,
    }
    _write_json(prior_state, prior_state_payload)
    prior_state_sha = subject.sha256_file(prior_state)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_STATE_SHA256", prior_state_sha)

    result_payload = {
        "schema_version": 2,
        "run_id": dev2_run_id,
        "success": False,
        "error_code": "CHILD_PRECHECK_FAILED",
        "error_message": "DEV2 metatester selected pre-existing listener port 3004 (owners=1234).",
        "run_smoke_exit_code": None,
        "agent_port_proof": {
            "status": "NOT_RUN",
            "listeners": [],
            "metatester_path": str((subject.TERMINAL_ROOT / "metatester64.exe").resolve()),
        },
    }
    _write_json(dev2_result, result_payload)
    result_sha = subject.sha256_file(dev2_result)
    monkeypatch.setattr(subject, "PRIOR_NATIVE_ATTEMPT_DEV2_RESULT_SHA256", result_sha)

    payload = {
        "schema_version": 2,
        "artifact_type": "QM5_10834_INFRA_RETRY_CONTRACT",
        "status": "AUTHORIZED_INFRA_PORT_RETRY_002_ONCE",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "candidate": {
            "ea_id": "QM5_10834",
            "analysis_id": subject.ANALYSIS_ID,
            "symbol": "NDX.DWX",
            "timeframe": "M5",
            "model": 4,
        },
        "prior_attempt": {
            "terminal": "T1",
            "run_root": str(prior_root),
            "pre_receipt_sha256": pre_sha,
            "launch_state_sha256": state_sha,
            "terminal_status": "INVALID_TERMINAL",
            "reason_classes": [
                "BARS_ZERO",
                "INCOMPLETE_RUNS",
                "HISTORY_SYNCHRONIZATION_ERROR",
            ],
            "completed_cells": 0,
            "strategy_outcomes_read": False,
            "strategy_merit_adjudicated": False,
        },
        "controller_preflight": {
            "run_root": str(controller_root),
            "pre_receipt_sha256": controller_pre_sha,
            "launch_state_sha256": controller_state_sha,
            "terminal_status": "INVALID_TERMINAL",
            "cause": "QMDEV2_ACCOUNT_DISABLED_AT_REST",
            "dev2_process_started": False,
            "dev2_run_directory_created": False,
            "native_report_created": False,
            "strategy_outcomes_read": False,
            "counts_toward_alternate_attempts": False,
            "remediation": "CONTROLLER_JIT_ENABLE_WITH_SYSTEM_TTL_CLEANUP_LEASE_AND_VERIFIED_DISARM",
        },
        "prior_native_attempt": subject._prior_native_attempt_contract(),
        "retry": dict(subject.INFRA_RETRY_002_POLICY),
        "classification": "OUTCOME_BLIND_INFRASTRUCTURE_PORT_RETRY_002_ONLY",
    }
    contract = tmp_path / "retry.json"
    _write_json(contract, payload)
    return contract, payload, native_root, dev2_root


def test_infra_retry_contract_is_outcome_blind_attempt_002_and_binds_prior_port_conflict(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    contract, payload, native_root, _ = _infra_retry_002_fixture(tmp_path, monkeypatch)
    assert subject._validate_infra_retry_002_contract(contract) == payload

    payload["retry"] = {**subject.INFRA_RETRY_002_POLICY, "maximum_alternate_attempts": 3}
    _write_json(contract, payload)
    with pytest.raises(subject.InvalidEvidence, match="attempt-002 policy"):
        subject._validate_infra_retry_002_contract(contract)

    payload["retry"] = dict(subject.INFRA_RETRY_002_POLICY)
    _write_json(contract, payload)
    (native_root / "native" / "DEV" / "report.htm").write_bytes(b"")
    with pytest.raises(subject.InvalidEvidence, match="native outcome artifact"):
        subject._validate_infra_retry_002_contract(contract)


def test_retry_003_contract_separates_claim_sequence_from_counted_attempt(
    tmp_path: Path,
) -> None:
    payload = subject.validate_infra_retry_contract()
    retry = payload["retry"]
    assert retry["claim_sequence"] == 3
    assert retry["reserved_counted_alternate_attempt_number"] == 2
    assert retry["prior_claim_sequences"] == 2
    assert retry["prior_counted_alternate_attempts"] == 1
    prior = payload["prior_uncounted_claim_sequence_002"]
    assert prior["cause"] == "S4U_CURRENT_USER_DPAPI_IMPORT_FAILED"
    assert prior["counts_toward_claim_sequence"] is True
    assert prior["counts_toward_counted_alternate_attempts"] is False
    assert prior["native_counting_boundary_crossed"] is False

    tampered = json.loads(json.dumps(payload))
    tampered["retry"]["reserved_counted_alternate_attempt_number"] = 3
    path = tmp_path / "retry003.json"
    _write_json(path, tampered)
    with pytest.raises(subject.InvalidEvidence, match="claim/count policy"):
        subject.validate_infra_retry_contract(path)


def test_dev2_controller_result_binds_lane_scripts_and_tester_groups() -> None:
    lane_sha = "1" * 64
    child_sha = "2" * 64
    smoke_sha = "3" * 64
    groups_sha = "4" * 64
    cleanup_sha = "5" * 64
    credential_sha = "6" * 64
    credential_helper_sha = "7" * 64
    pre = {
        "bindings": {
            "dev2_lane_contract": {"sha256": lane_sha},
            "runner_child": {"sha256": child_sha},
            "runner_smoke": {"sha256": smoke_sha},
            "dev2_cleanup_helper": {"sha256": cleanup_sha},
            "dev2_machine_credential": {"sha256": credential_sha},
            "dev2_machine_credential_helper": {"sha256": credential_helper_sha},
            "tester_groups_canonical": {"sha256": groups_sha},
        }
    }
    run_id = "20260720T170000Z_" + "a" * 32
    result = {
        "schema_version": 2,
        "success": True,
        "run_smoke_exit_code": 0,
        "run_id": run_id,
        "lane_contract_sha256": lane_sha,
        "child_sha256": child_sha,
        "run_smoke_sha256": smoke_sha,
        "cleanup_helper_sha256": cleanup_sha,
        "machine_credential_sha256": credential_sha,
        "machine_credential_helper_sha256": credential_helper_sha,
        "tester_groups_post_child_sha256": groups_sha,
        "tester_groups_restored_sha256": groups_sha,
        "dev2_account_initially_enabled": False,
        "dev2_account_enabled_by_controller": True,
        "dev2_account_restored_disabled": True,
        "cleanup_lease_registered": True,
        "cleanup_lease_disarmed": True,
    }
    assert subject.validate_dev2_controller_result(result, pre) == run_id
    result["child_sha256"] = "f" * 64
    with pytest.raises(subject.InvalidEvidence, match="runtime binding drift"):
        subject.validate_dev2_controller_result(result, pre)


def _controller_envelope() -> dict[str, object]:
    return {
        "schema_version": 2,
        "success": True,
        "run_smoke_exit_code": 0,
        "run_id": "20260720T170000Z_" + "c" * 32,
        "lane_contract_sha256": "1" * 64,
        "child_sha256": "2" * 64,
        "run_smoke_sha256": "3" * 64,
        "machine_credential_sha256": "6" * 64,
        "machine_credential_helper_sha256": "7" * 64,
        "agent_port_proof": {
            "status": "PASS",
            "listeners": [{"local_port": 3000, "process_id": 42}],
        },
        "tester_groups_post_child_sha256": "4" * 64,
        "tester_groups_restored_sha256": "4" * 64,
        "dev2_account_initially_enabled": False,
        "dev2_account_enabled_by_controller": True,
        "dev2_account_restored_disabled": True,
        "cleanup_helper_sha256": "5" * 64,
        "cleanup_lease_registered": True,
        "cleanup_lease_disarmed": True,
    }


def test_dev2_controller_parser_selects_pretty_outer_envelope() -> None:
    result = _controller_envelope()
    stdout = "controller log before\n" + json.dumps(result, indent=2) + "\ncontroller log after\n"
    assert subject._parse_dev2_controller_json(stdout) == result


def test_dev2_controller_parser_rejects_ambiguous_outer_envelopes() -> None:
    encoded = json.dumps(_controller_envelope(), indent=2)
    with pytest.raises(subject.InvalidEvidence, match="exactly one.*found 2"):
        subject._parse_dev2_controller_json(encoded + "\n" + encoded)


def test_dev2_controller_parser_rejects_nested_proof_without_envelope() -> None:
    nested = {"agent_port_proof": {"listeners": [{"local_port": 3000}]}}
    with pytest.raises(subject.InvalidEvidence, match="exactly one.*found 0"):
        subject._parse_dev2_controller_json(json.dumps(nested, indent=2))


def test_scheduler_parser_keeps_scheduler_error_semantics() -> None:
    payload = {"operation": "Identity", "principal_sid": "S-1-5-18"}
    assert subject._parse_scheduler_json("log\n" + json.dumps(payload)) == payload
    with pytest.raises(subject.AuthorizationError, match="no JSON object"):
        subject._parse_scheduler_json("log only")


def test_scheduler_start_requires_fresh_start_ack(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    scheduler = {
        "task_name": "QM_QM10834_AUDIT_" + "a" * 24,
        "principal_sid": "S-1-5-21-1",
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": 60,
    }
    pre = {
        "bindings": {
            "powershell": {"path": str(tmp_path / "pwsh.exe")},
            "scheduled_task_helper": {"path": str(tmp_path / "helper.ps1")},
            "python": {"path": str(tmp_path / "python.exe")},
            "tool": {"path": str(tmp_path / "audit.py")},
        }
    }
    job = {"state_path": str(tmp_path / "launch_state.json"), "scheduler": scheduler}
    payload = {"operation": "Start", **scheduler, "state": "Ready"}

    def completed() -> SimpleNamespace:
        return SimpleNamespace(returncode=0, stdout=json.dumps(payload), stderr="")

    monkeypatch.setattr(subject.subprocess, "run", lambda *_args, **_kwargs: completed())
    with pytest.raises(subject.AuthorizationError, match="fresh task start"):
        subject._scheduler_call(pre, "Start", job)
    payload["fresh_start_ack"] = True
    assert subject._scheduler_call(pre, "Start", job)["fresh_start_ack"] is True


def test_dev2_summary_identity_is_exact_and_unambiguous(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runs_root = tmp_path / "runs"
    monkeypatch.setattr(subject, "DEV2_RUNS_ROOT", runs_root)
    run_id = "20260720T170000Z_" + "b" * 32
    summary = runs_root / run_id / "output" / "smoke" / "QM5_10834" / "tag" / "summary.json"
    _write_json(summary, {"result": "PASS"})
    assert subject._find_dev2_summary(run_id) == summary.resolve()
    second = runs_root / run_id / "output" / "smoke" / subject.EXPERT_NAME / "tag2" / "summary.json"
    _write_json(second, {"result": "PASS"})
    with pytest.raises(subject.InvalidEvidence, match="found 2"):
        subject._find_dev2_summary(run_id)


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
    warmups, accepted = subject.validate_runner_summary(summary, cell)
    assert warmups == []
    assert [row["run"] for row in accepted] == ["run_01", "run_02"]
    summary["runs"][1]["real_ticks_marker"] = False
    with pytest.raises(subject.InvalidEvidence, match="Model-4 marker"):
        subject.validate_runner_summary(summary, cell)


def test_runner_summary_accepts_only_bounded_pre_ok_infrastructure_warmups() -> None:
    cell = {"symbol": "NDX.DWX"}
    summary = _runner_summary(cell)
    summary["runs"] = [
        {
            "run": "run_01",
            "status": "INVALID",
            "failure": "BARS_ZERO",
            "invalid_report_reasons": ["BARS_ZERO"],
            "total_trades": 0,
            "profit_factor": "0",
            "profit_factor_raw": "0.00",
            "drawdown": "0",
            "drawdown_raw": "0.00",
            "net_profit": "0",
            "net_profit_raw": "0.00",
            "exit_code": 0,
            "report_size_bytes": 1,
            "report_canonical_path": r"D:\evidence\raw\run_01\report.htm",
            "tester_log_path": r"D:\evidence\raw\run_01\tester.log",
        },
        {"run": "run_02", "status": "OK", "real_ticks_marker": True},
        {"run": "run_03", "status": "OK", "real_ticks_marker": True},
    ]
    summary["attempted_runs"] = 3
    summary["non_ok_attempts"] = 1
    warmups, accepted = subject.validate_runner_summary(summary, cell)
    assert [row["run"] for row in warmups] == ["run_01"]
    assert [row["run"] for row in accepted] == ["run_02", "run_03"]

    summary["runs"][0]["failure"] = "ONINIT_FAILED"
    with pytest.raises(subject.InvalidEvidence, match="non-infrastructure warm-up"):
        subject.validate_runner_summary(summary, cell)


def test_runner_summary_accepts_two_prefix_warmups_including_no_history() -> None:
    cell = {"symbol": "NDX.DWX"}
    summary = _runner_summary(cell)
    summary["runs"] = [
        _warmup_run("run_01"),
        _warmup_run(
            "run_02",
            failure="NO_HISTORY",
            reasons=["NO_HISTORY_LOG", "HISTORY_CONTEXT_INVALID", "BARS_ZERO"],
        ),
        {"run": "run_03", "status": "OK", "real_ticks_marker": True},
        {"run": "run_04", "status": "OK", "real_ticks_marker": True},
    ]
    summary["attempted_runs"] = 4
    summary["non_ok_attempts"] = 2
    warmups, accepted = subject.validate_runner_summary(summary, cell)
    assert [row["run"] for row in warmups] == ["run_01", "run_02"]
    assert [row["run"] for row in accepted] == ["run_03", "run_04"]


@pytest.mark.parametrize(("field", "value"), [("attempted_runs", True), ("non_ok_attempts", False)])
def test_runner_summary_rejects_boolean_attempt_counters(field: str, value: bool) -> None:
    cell = {"symbol": "NDX.DWX"}
    summary = _runner_summary(cell)
    summary[field] = value
    with pytest.raises(subject.InvalidEvidence, match="attempt counters"):
        subject.validate_runner_summary(summary, cell)


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("total_trades", 1, "zero-trade"),
        ("net_profit", "0.01", "zero-result"),
        ("exit_code", False, "artifact identity"),
    ],
)
def test_runner_summary_rejects_warmups_with_outcome_or_invalid_exit_identity(
    field: str, value: object, message: str
) -> None:
    cell = {"symbol": "NDX.DWX"}
    summary = _runner_summary(cell)
    warmup = {
        "run": "run_01",
        "status": "INVALID",
        "failure": "BARS_ZERO",
        "invalid_report_reasons": ["BARS_ZERO"],
        "total_trades": 0,
        "profit_factor": "0",
        "profit_factor_raw": "0.00",
        "drawdown": "0",
        "drawdown_raw": "0.00",
        "net_profit": "0",
        "net_profit_raw": "0.00",
        "exit_code": 0,
        "report_size_bytes": 1,
        "report_canonical_path": r"D:\evidence\raw\run_01\report.htm",
        "tester_log_path": r"D:\evidence\raw\run_01\tester.log",
    }
    warmup[field] = value
    summary["runs"] = [warmup, *summary["runs"]]
    summary["runs"][1]["run"] = "run_02"
    summary["runs"][2]["run"] = "run_03"
    summary["attempted_runs"] = 3
    summary["non_ok_attempts"] = 1
    with pytest.raises(subject.InvalidEvidence, match=message):
        subject.validate_runner_summary(summary, cell)


def test_runner_summary_rejects_hidden_non_infrastructure_reason() -> None:
    cell = {"symbol": "NDX.DWX"}
    summary = _runner_summary(cell)
    warmup = {
        "run": "run_01",
        "status": "INVALID",
        "failure": "BARS_ZERO",
        "invalid_report_reasons": ["BARS_ZERO", "ONINIT_FAILED"],
        "total_trades": 0,
        "profit_factor": "0",
        "profit_factor_raw": "0.00",
        "drawdown": "0",
        "drawdown_raw": "0.00",
        "net_profit": "0",
        "net_profit_raw": "0.00",
        "exit_code": 0,
        "report_size_bytes": 1,
        "report_canonical_path": r"D:\evidence\raw\run_01\report.htm",
        "tester_log_path": r"D:\evidence\raw\run_01\tester.log",
    }
    summary["runs"] = [warmup, *summary["runs"]]
    summary["runs"][1]["run"] = "run_02"
    summary["runs"][2]["run"] = "run_03"
    summary["attempted_runs"] = 3
    summary["non_ok_attempts"] = 1
    with pytest.raises(subject.InvalidEvidence, match="non-infrastructure warm-up"):
        subject.validate_runner_summary(summary, cell)

    summary["runs"] = [
        {"run": "run_01", "status": "OK", "real_ticks_marker": True},
        {"run": "run_02", "status": "INVALID", "failure": "BARS_ZERO"},
        {"run": "run_03", "status": "OK", "real_ticks_marker": True},
    ]
    with pytest.raises(subject.InvalidEvidence, match="non-infrastructure warm-up"):
        subject.validate_runner_summary(summary, cell)


def test_authorization_is_owner_scoped_short_lived_and_pre_bound(tmp_path: Path) -> None:
    now = datetime(2026, 7, 20, 12, 0, tzinfo=timezone.utc)
    payload = {
        "schema_version": 2,
        "artifact_type": "QM5_10834_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": subject.ANALYSIS_ID,
        "pre_receipt_sha256": "a" * 64,
        "scope": subject.AUTHORIZATION_SCOPE,
        "claim_sequence": 3,
        "reserved_counted_alternate_attempt_number": 2,
        "prior_claim_sequences": 2,
        "maximum_counted_alternate_attempts": 2,
        "prior_counted_alternate_attempts": 1,
        "claim_creation_alone_does_not_count_as_alternate_attempt": True,
        "alternate_attempt_counting_boundary": subject.ALTERNATE_ATTEMPT_COUNTING_BOUNDARY,
        "same_worker_machine_credential_probe_required_before_claim": True,
        "authorized_by": "OWNER",
        "authorized_symbol": "NDX.DWX",
        "authorized_cells": [window.cell_id for window in subject.WINDOWS],
        "duplicates_per_cell": 2,
        "maximum_postflight_acceptable_infrastructure_warmups_per_cell": 2,
        "maximum_attempts_per_cell": 4,
        "maximum_native_starts": 16,
        "native_start_budget_is_outcome_independent": True,
        "postflight_acceptable_infrastructure_warmup_verdicts": ["BARS_ZERO", "NO_HISTORY"],
        "postflight_warmups_must_precede_accepted_duplicates": True,
        "postflight_warmups_must_be_zero_trade_zero_result": True,
        "postflight_rejects_every_nonprefix_or_nonzero_warmup": True,
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


def test_global_native_attempt_claim_is_atomic_and_pre_bound(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    claim_path = tmp_path / "claims" / "attempt.json"
    monkeypatch.setattr(subject, "NATIVE_ATTEMPT_CLAIM_PATH", claim_path)
    run_root = tmp_path / "run"
    state_path = run_root / "launch_state.json"
    pre_path = run_root / "pre_receipt.json"
    _write_json(pre_path, {"receipt": "sealed"})
    pre_sha = subject.sha256_file(pre_path)
    bound_files: dict[str, dict[str, object]] = {}
    for role in ("infra_retry_contract", "ex5", "set"):
        path = tmp_path / f"{role}.bin"
        path.write_bytes(role.encode("ascii"))
        bound_files[role] = subject.file_binding(path)
    authorization_path = tmp_path / "authorization.json"
    _write_json(authorization_path, {"authorized": True})
    authorization = {
        "binding": subject.file_binding(authorization_path),
        "payload_sha256": "9" * 64,
    }
    preclaim_probe = {
        "status": "PASS",
        "exit_code": 0,
        "timed_out": False,
        "receipt": {"path": "probe.json", "size": 1, "sha256": "6" * 64},
        "receipt_payload_sha256": "7" * 64,
    }
    pre = {
        "run_root": str(run_root),
        "plan": {"plan_sha256": "8" * 64},
        "bindings": bound_files,
    }

    claim = subject.claim_native_attempt(
        pre_path, pre_sha, pre, state_path, authorization, preclaim_probe
    )
    payload = subject.validate_native_attempt_claim(
        claim, pre_path, pre_sha, pre, state_path, authorization, preclaim_probe
    )
    assert payload["claim_sequence"] == 3
    assert payload["reserved_counted_alternate_attempt_number"] == 2
    assert payload["prior_claim_sequences"] == 2
    assert payload["maximum_counted_alternate_attempts"] == 2
    assert payload["prior_counted_alternate_attempts"] == 1
    assert payload["authorization_scope"] == subject.AUTHORIZATION_SCOPE
    assert payload["classification"] == "ATOMIC_GLOBAL_OUTCOME_BLIND_DPAPI_RETRY_CLAIM_003_COUNTED_ALTERNATE_002"
    with pytest.raises(subject.InvalidEvidence, match="refusing to replace evidence"):
        subject.claim_native_attempt(
            pre_path, pre_sha, pre, state_path, authorization, preclaim_probe
        )
    with pytest.raises(subject.AuthorizationError, match="already claimed"):
        subject._assert_native_attempt_unclaimed("test")


def test_global_native_attempt_claim_has_exactly_one_concurrent_winner(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    claim_path = tmp_path / "claims" / "attempt.json"
    monkeypatch.setattr(subject, "NATIVE_ATTEMPT_CLAIM_PATH", claim_path)
    run_root = tmp_path / "run"
    state_path = run_root / "launch_state.json"
    pre_path = run_root / "pre_receipt.json"
    _write_json(pre_path, {"receipt": "sealed"})
    pre_sha = subject.sha256_file(pre_path)
    bindings: dict[str, dict[str, object]] = {}
    for role in ("infra_retry_contract", "ex5", "set"):
        path = tmp_path / f"{role}.bin"
        path.write_bytes(role.encode("ascii"))
        bindings[role] = subject.file_binding(path)
    authorization_path = tmp_path / "authorization.json"
    _write_json(authorization_path, {"authorized": True})
    authorization = {
        "binding": subject.file_binding(authorization_path),
        "payload_sha256": "9" * 64,
    }
    preclaim_probe = {
        "status": "PASS",
        "exit_code": 0,
        "timed_out": False,
        "receipt": {"path": "probe.json", "size": 1, "sha256": "6" * 64},
        "receipt_payload_sha256": "7" * 64,
    }
    pre = {
        "run_root": str(run_root),
        "plan": {"plan_sha256": "8" * 64},
        "bindings": bindings,
    }
    barrier = threading.Barrier(2)

    def contend() -> str:
        barrier.wait(timeout=5)
        try:
            subject.claim_native_attempt(
                pre_path,
                pre_sha,
                pre,
                state_path,
                authorization,
                preclaim_probe,
            )
            return "SUCCESS"
        except subject.InvalidEvidence:
            return "REJECTED"

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = [future.result(timeout=10) for future in (pool.submit(contend), pool.submit(contend))]
    assert sorted(results) == ["REJECTED", "SUCCESS"]


def test_native_launch_lock_contends_across_processes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    lock_path = tmp_path / "claims" / "native.lock"
    monkeypatch.setattr(subject, "NATIVE_LAUNCH_LOCK_PATH", lock_path)
    code = (
        "import importlib.util,pathlib,sys;"
        "spec=importlib.util.spec_from_file_location('lock_subject',sys.argv[1]);"
        "mod=importlib.util.module_from_spec(spec);sys.modules[spec.name]=mod;spec.loader.exec_module(mod);"
        "mod.NATIVE_LAUNCH_LOCK_PATH=pathlib.Path(sys.argv[2]);"
        "ctx=mod.native_launch_lock(timeout_seconds=5);ctx.__enter__();"
        "print('LOCKED',flush=True);sys.stdin.readline();ctx.__exit__(None,None,None)"
    )
    child = subprocess.Popen(
        [sys.executable, "-c", code, str(TOOL), str(lock_path)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "LOCKED"
        with pytest.raises(subject.AuthorizationError, match="timed out acquiring"):
            with subject.native_launch_lock(timeout_seconds=0.2):
                pass
    finally:
        if child.stdin is not None:
            child.stdin.write("release\n")
            child.stdin.flush()
        child.wait(timeout=10)
    assert child.returncode == 0


def test_launch_entrypoint_holds_global_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    events: list[str] = []

    class LockProbe:
        def __enter__(self) -> None:
            events.append("lock_enter")

        def __exit__(self, *_args: object) -> None:
            events.append("lock_exit")

    def fake_launch(*_args: object, **_kwargs: object) -> dict[str, str]:
        events.append("launch")
        return {"status": "TEST"}

    monkeypatch.setattr(subject, "native_launch_lock", lambda: LockProbe())
    monkeypatch.setattr(subject, "_launch_detached_locked", fake_launch)
    result = subject.launch_detached(
        tmp_path / "pre.json",
        "a" * 64,
        tmp_path / "authorization.json",
        tmp_path / "launch_state.json",
        resume=True,
    )
    assert result == {"status": "TEST"}
    assert events == ["lock_enter", "launch", "lock_exit"]


@pytest.mark.parametrize("scheduler_state", ["Running", "Queued", "Unknown", "Disabled"])
def test_resume_rejects_every_scheduler_state_except_exact_ready(
    tmp_path: Path,
    scheduler_state: str,
) -> None:
    with pytest.raises(subject.AuthorizationError, match="not exactly Ready"):
        subject._refresh_resume_state_after_inspect(
            {"state": scheduler_state},
            tmp_path / "launch_state.json",
            {},
            {},
            tmp_path / "pre.json",
            "a" * 64,
            {},
        )


def test_resume_rereads_inspect_mutation_and_never_replaces_crossed_state(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    run_root = tmp_path / "run"
    state_path = run_root / "launch_state.json"
    job_path = run_root / "launch_job.json"
    pre_path = run_root / "pre_receipt.json"
    authorization_identity = {
        "binding": {"path": str(tmp_path / "authorization.json")},
        "payload_sha256": "9" * 64,
    }
    job = {"authorization": authorization_identity, "scheduler": {"task_name": "task"}}
    initial = {"status": "PENDING", "outcome_possible_since_utc": None}
    crossed = {
        "status": "RUNNING",
        "outcome_possible_since_utc": "2026-07-20T12:00:00+00:00",
    }
    _write_json(job_path, job)
    _write_json(state_path, initial)
    _write_json(pre_path, {"sealed": True})
    pre = {"run_root": str(run_root)}
    starts: list[str] = []

    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_args: pre)
    monkeypatch.setattr(subject, "validate_current_research_data_gate", lambda *_args: None)
    monkeypatch.setattr(
        subject,
        "validate_authorization",
        lambda *_args: authorization_identity,
    )
    monkeypatch.setattr(subject, "_validate_launch_job", lambda *_args: None)
    monkeypatch.setattr(subject, "_assert_native_attempt_unclaimed", lambda *_args: None)

    def outcome_fence(state: dict[str, object], *_args: object) -> None:
        if state.get("outcome_possible_since_utc") is not None:
            raise subject.AuthorizationError("crossed outcome fence")

    def scheduler_call(_pre: object, operation: str, _job: object) -> dict[str, object]:
        if operation == "Inspect":
            _write_json(state_path, crossed)
            return {"state": "Ready"}
        if operation == "Start":
            starts.append(operation)
        return {"state": "Ready"}

    monkeypatch.setattr(subject, "_assert_resume_outcome_fence", outcome_fence)
    monkeypatch.setattr(subject, "_scheduler_call", scheduler_call)
    with pytest.raises(subject.AuthorizationError, match="crossed outcome fence"):
        subject._launch_detached_locked(
            pre_path,
            "a" * 64,
            tmp_path / "authorization.json",
            state_path,
            resume=True,
        )
    assert subject.load_json(state_path) == crossed
    assert starts == []


def test_resume_rechecks_global_claim_created_during_inspect(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    state_path = tmp_path / "run" / "launch_state.json"
    job_path = state_path.with_name("launch_job.json")
    pre_path = state_path.with_name("pre_receipt.json")
    authorization = {
        "binding": {"path": str(tmp_path / "authorization.json")},
        "payload_sha256": "9" * 64,
    }
    job = {"authorization": authorization, "scheduler": {"task_name": "task"}}
    state = {"status": "PENDING", "sentinel": "unchanged"}
    _write_json(job_path, job)
    _write_json(state_path, state)
    _write_json(pre_path, {"sealed": True})
    claim_path = tmp_path / "claims" / "attempt.json"
    monkeypatch.setattr(subject, "NATIVE_ATTEMPT_CLAIM_PATH", claim_path)
    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_args: {"run_root": str(state_path.parent)})
    monkeypatch.setattr(subject, "validate_current_research_data_gate", lambda *_args: None)
    monkeypatch.setattr(subject, "validate_authorization", lambda *_args: authorization)
    monkeypatch.setattr(subject, "_validate_launch_job", lambda *_args: None)
    monkeypatch.setattr(subject, "_assert_resume_outcome_fence", lambda *_args: None)

    def scheduler_call(_pre: object, operation: str, _job: object) -> dict[str, object]:
        if operation == "Inspect":
            _write_json(claim_path, {"claimed": True})
        return {"state": "Ready"}

    monkeypatch.setattr(subject, "_scheduler_call", scheduler_call)
    with pytest.raises(subject.AuthorizationError, match="already claimed"):
        subject._launch_detached_locked(
            pre_path,
            "a" * 64,
            tmp_path / "authorization.json",
            state_path,
            resume=True,
        )
    assert subject.load_json(state_path) == state


def test_native_artifacts_are_bound_to_exact_cell_raw_run_directory(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output_root = tmp_path / "controller_cell"
    expected_raw = tmp_path / "dev2_native" / "output" / "smoke" / "QM5_10834" / "tag" / "raw"
    run_root = expected_raw / "run_01"
    run_root.mkdir(parents=True)
    report = run_root / "report.htm"
    log = run_root / "tester.log"
    ini = run_root / "tester.ini"
    report.write_text("opaque", encoding="utf-8")
    log.write_text("opaque", encoding="utf-8")
    ini.write_text("[Tester]\n", encoding="utf-8")
    sealed = {path.resolve(): subject.file_binding(path) for path in (report, log, ini)}
    row = {
        "run": "run_01",
        "report_canonical_path": str(report),
        "tester_log_path": str(log),
        "report_size_bytes": report.stat().st_size,
    }
    cell = {"cell_id": "DEV", "output_root": str(output_root)}
    monkeypatch.setattr(subject, "validate_tester_ini", lambda *_args: None)
    assert subject._bound_native_run_artifacts(row, sealed, cell, expected_raw) == (
        report.resolve(),
        log.resolve(),
        ini.resolve(),
    )

    escaped_root = tmp_path / "other" / "raw" / "run_01"
    escaped_root.mkdir(parents=True)
    escaped_report = escaped_root / "report.htm"
    escaped_log = escaped_root / "tester.log"
    escaped_ini = escaped_root / "tester.ini"
    for path in (escaped_report, escaped_log, escaped_ini):
        path.write_text("opaque", encoding="utf-8")
    escaped_sealed = {
        path.resolve(): subject.file_binding(path)
        for path in (escaped_report, escaped_log, escaped_ini)
    }
    escaped_row = {
        "run": "run_01",
        "report_canonical_path": str(escaped_report),
        "tester_log_path": str(escaped_log),
        "report_size_bytes": escaped_report.stat().st_size,
    }
    with pytest.raises(subject.InvalidEvidence, match="exact raw/run_01 directory"):
        subject._bound_native_run_artifacts(
            escaped_row, escaped_sealed, cell, expected_raw
        )

    wrong_size = dict(row)
    wrong_size["report_size_bytes"] = report.stat().st_size + 1
    with pytest.raises(subject.InvalidEvidence, match="sealed binding"):
        subject._bound_native_run_artifacts(wrong_size, sealed, cell, expected_raw)

    reused_log = dict(row)
    reused_log["tester_log_path"] = str(report)
    with pytest.raises(subject.InvalidEvidence, match="exact raw/run_01 directory"):
        subject._bound_native_run_artifacts(reused_log, sealed, cell, expected_raw)


def _preoutcome_state(status: str = "PENDING") -> dict[str, object]:
    pending_cells = [
        {"cell_id": window.cell_id, "status": "PENDING", "attempts": []}
        for window in subject.WINDOWS
    ]
    return {
        "launcher_revision": subject.LAUNCHER_REVISION,
        "status": status,
        "worker_pid": None,
        "finished_utc": None,
        "active_cell": None,
        "attempt_claim": None,
        "preclaim_probe": None,
        "outcome_possible_since_utc": None,
        "cells": pending_cells,
    }


def test_worker_bootstrap_claim_is_locked_and_second_worker_cannot_overwrite_running(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    state_path = tmp_path / "launch_state.json"
    job_binding = {"path": str(tmp_path / "launch_job.json"), "size": 1, "sha256": "1" * 64}
    authorization = {"binding": {"path": "authorization.json"}, "payload_sha256": "2" * 64}
    job = {"authorization": authorization, "scheduler": {"task_name": "task"}}
    state = _preoutcome_state()
    state.update({"job": job_binding, "launches": []})
    _write_json(state_path, state)
    monkeypatch.setattr(subject, "NATIVE_LAUNCH_LOCK_PATH", tmp_path / "claims" / "native.lock")
    monkeypatch.setattr(subject, "_assert_resume_outcome_fence", lambda *_args: None)

    claimed = subject._claim_worker_bootstrap_state(
        state_path, job_binding, job, {}, authorization
    )
    assert claimed["status"] == "RUNNING"
    assert len(claimed["launches"]) == 1
    with pytest.raises(subject.AuthorizationError, match="not armed"):
        subject._claim_worker_bootstrap_state(
            state_path, job_binding, job, {}, authorization
        )
    persisted = subject.load_json(state_path)
    assert persisted["status"] == "RUNNING"
    assert len(persisted["launches"]) == 1


@pytest.mark.parametrize("status", ["PENDING", "PENDING_RESUME", "RUNNING"])
def test_resume_accepts_only_strict_preoutcome_state(status: str) -> None:
    assert subject.resume_eligible(_preoutcome_state(status))


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("launcher_revision", 1),
        ("status", "COMPLETE"),
        ("finished_utc", "2026-07-20T12:00:00+00:00"),
        ("error", "failure"),
        ("worker_error", {"type": "AuditError"}),
        ("active_cell", {"cell_id": "DEV"}),
        ("attempt_claim", {"sha256": "a" * 64}),
        ("preclaim_probe", {"status": "PASS"}),
        ("outcome_possible_since_utc", "2026-07-20T12:00:00+00:00"),
    ],
)
def test_resume_rejects_every_legacy_or_outcome_surface(field: str, value: object) -> None:
    state = _preoutcome_state()
    state[field] = value
    assert not subject.resume_eligible(state)
    attempted = _preoutcome_state()
    attempted["cells"][0]["attempts"] = [{"summary": None}]
    assert not subject.resume_eligible(attempted)
    complete = _preoutcome_state()
    complete["cells"][0]["status"] = "COMPLETE"
    assert not subject.resume_eligible(complete)


def test_persisted_task_timeout_covers_all_cells_and_cleanup_margin(tmp_path: Path) -> None:
    pre = {
        "run_root": str(tmp_path),
        "plan": {
            "cells": [
                {"output_root": str(tmp_path / window.cell_id)}
                for window in subject.WINDOWS
            ]
        }
    }
    assert subject.RUN_ATTEMPT_OVERHEAD_SECONDS == 600
    assert subject.CELL_CONTROLLER_TIMEOUT_SECONDS == 119_400
    assert subject.required_scheduled_task_timeout(pre) == 481_320


def test_persisted_launch_job_binds_s4u_helper_python_plan_and_state(
    tmp_path: Path,
) -> None:
    state_path = tmp_path / "launch_state.json"
    pre_path = tmp_path / "pre.json"
    pre_sha256 = "b" * 64
    helper = {"path": "helper.ps1", "size": 1, "sha256": "1" * 64}
    python = {"path": "python.exe", "size": 1, "sha256": "2" * 64}
    tool = {"path": "audit.py", "size": 1, "sha256": "3" * 64}
    pre = {
        "plan": {
            "plan_sha256": "c" * 64,
            "cells": [
                {"output_root": str(tmp_path / window.cell_id)}
                for window in subject.WINDOWS
            ],
        },
        "bindings": {
            "scheduled_task_helper": helper,
            "python": python,
            "tool": tool,
        },
    }
    scheduler = {
        "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
        "task_name": subject.scheduled_task_name(pre_sha256, state_path),
        "task_path": "\\",
        "principal_sid": "S-1-5-21-123-456-789-500",
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": 481_320,
        "helper": helper,
        "python": python,
    }
    job = {
        "schema_version": subject.SCHEMA_VERSION,
        "launcher_revision": subject.LAUNCHER_REVISION,
        "artifact_type": "QM5_10834_NATIVE_LAUNCH_JOB",
        "analysis_id": subject.ANALYSIS_ID,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256,
        "state_path": str(state_path.resolve()),
        "plan_sha256": "c" * 64,
        "authorization": {
            "binding": {"path": "authorization.json", "size": 1, "sha256": "4" * 64},
            "payload_sha256": "5" * 64,
        },
        "tool": tool,
        "scheduler": scheduler,
    }
    subject._validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
    scheduler["run_level"] = "Limited"
    with pytest.raises(subject.AuthorizationError, match="identity/plan/tool drift"):
        subject._validate_launch_job(job, pre, pre_path, pre_sha256, state_path)


def test_persisted_helper_is_s4u_triggerless_and_never_overwrites_task() -> None:
    helper = subject.SCHEDULED_TASK_HELPER_PATH.read_text(encoding="utf-8-sig")
    assert "-LogonType S4U" in helper
    assert "-RunLevel Highest" in helper
    assert "-MultipleInstances IgnoreNew" in helper
    assert "New-ScheduledTaskTrigger" not in helper
    assert "Register-ScheduledTask" in helper
    assert " -Force" not in helper
    assert "_run-plan --job" in helper
    assert "$priorLastRunUtc" in helper
    assert "$startRequestedUtc" in helper
    assert "$freshStartAck" in helper
    assert "fresh_start_ack" in helper


def test_resume_fence_rejects_any_native_worker_artifact(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(subject, "ALLOWED_RUN_ROOT", tmp_path.parent)
    state_path = tmp_path / "launch_state.json"
    job_path = tmp_path / "launch_job.json"
    _write_json(job_path, {"immutable": True})
    output_roots = [tmp_path / "native" / window.cell_id for window in subject.WINDOWS]
    pre = {
        "run_root": str(tmp_path),
        "plan": {
            "cells": [
                {"cell_id": window.cell_id, "output_root": str(output_root)}
                for window, output_root in zip(subject.WINDOWS, output_roots)
            ]
        }
    }
    authorization = {"binding": {"path": "auth"}, "payload_sha256": "a" * 64}
    scheduler = {"task_name": "QM_QM10834_AUDIT_" + "a" * 24}
    job = {
        "authorization": authorization,
        "scheduler": scheduler,
        "pre_receipt_path": "pre.json",
        "pre_receipt_sha256": "b" * 64,
        "plan_sha256": "c" * 64,
    }
    state = _preoutcome_state()
    state.update(
        {
            "job": subject.file_binding(job_path),
            "authorization": authorization,
            "scheduler": scheduler,
            "pre_receipt_path": "pre.json",
            "pre_receipt_sha256": "b" * 64,
            "plan_sha256": "c" * 64,
        }
    )
    subject._assert_resume_outcome_fence(state, job, pre, state_path)
    output_roots[0].mkdir(parents=True)
    (output_roots[0] / "controller.stdout.log").write_text("started", encoding="utf-8")
    with pytest.raises(subject.AuthorizationError, match="artifact tree is non-empty"):
        subject._assert_resume_outcome_fence(state, job, pre, state_path)

def test_resume_fence_rejects_preclaim_probe_artifacts(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(subject, "ALLOWED_RUN_ROOT", tmp_path.parent)
    state_path = tmp_path / "launch_state.json"
    job_path = tmp_path / "launch_job.json"
    _write_json(job_path, {"immutable": True})
    pre = {
        "run_root": str(tmp_path),
        "plan": {
            "cells": [
                {"cell_id": window.cell_id, "output_root": str(tmp_path / "native" / window.cell_id)}
                for window in subject.WINDOWS
            ]
        },
    }
    authorization = {"binding": {"path": "auth"}, "payload_sha256": "a" * 64}
    scheduler = {"task_name": "QM_QM10834_AUDIT_" + "a" * 24}
    job = {
        "authorization": authorization,
        "scheduler": scheduler,
        "pre_receipt_path": "pre.json",
        "pre_receipt_sha256": "b" * 64,
        "plan_sha256": "c" * 64,
    }
    state = _preoutcome_state()
    state.update(
        {
            "job": subject.file_binding(job_path),
            "authorization": authorization,
            "scheduler": scheduler,
            "pre_receipt_path": "pre.json",
            "pre_receipt_sha256": "b" * 64,
            "plan_sha256": "c" * 64,
        }
    )
    probe_paths = subject._machine_credential_probe_paths(pre)
    probe_paths["control_root"].mkdir(parents=True)
    probe_paths["stderr"].write_bytes(b"preclaim started")
    with pytest.raises(subject.AuthorizationError, match="preclaim probe artifacts"):
        subject._assert_resume_outcome_fence(state, job, pre, state_path)


def test_worker_persists_outcome_fence_before_native_subprocess() -> None:
    source = TOOL.read_text(encoding="utf-8-sig")
    worker_start = source.index("def _worker_run(")
    probe = source.index("_execute_machine_credential_preclaim_probe(pre)", worker_start)
    claim = source.index('state["attempt_claim"] = claim_native_attempt(', probe)
    active = source.index('state["active_cell"]', claim)
    marker = source.index('state["outcome_possible_since_utc"]', worker_start)
    checkpoint = source.index("atomic_json(state_path, state, replace=True)", marker)
    native_start = source.index("completed = subprocess.run(", checkpoint)
    assert worker_start < probe < claim < active < marker < checkpoint < native_start
    assert "DETACHED_PROCESS" not in source
    assert "def _spawn_worker" not in source

def test_invalid_receipt_is_distinct_from_valid_merit_fail() -> None:
    receipt = subject.invalid_receipt("POST", subject.InvalidEvidence("broken evidence"))
    assert receipt["status"] == "INVALID"
    assert receipt["artifact_type"] == "QM5_10834_POST_INVALID"
    merit = _passing_merit_cells()
    merit["DEV"] = merit["DEV"][:79]
    assert subject.evaluate_merit(merit)["status"] == "FAIL"
