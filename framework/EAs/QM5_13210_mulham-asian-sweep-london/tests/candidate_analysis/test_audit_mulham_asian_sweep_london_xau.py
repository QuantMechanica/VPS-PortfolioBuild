from __future__ import annotations

import importlib.util
import json
import sys
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOL = (
    EA_ROOT
    / "tools"
    / "candidate_analysis"
    / "audit_mulham_asian_sweep_london_xau.py"
)
BASE_TOOL = TOOL.with_name("audit_mulham_asian_sweep_london.py")
BUILD_RECEIPT = (
    EA_ROOT / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
)
SPEC = importlib.util.spec_from_file_location(
    "audit_mulham_asian_sweep_london_xau_test_subject", TOOL
)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _venue_payload() -> dict[str, object]:
    return {
        "symbols": {
            "XAUUSD": {
                "asset_class": "commodity",
                "dwx_symbol": "XAUUSD.DWX",
                "contract_size_oz": 100,
                "dxz": {
                    "commission_model": "pct_notional_0.005pct_rt",
                    "per_side_pct": 0.0025,
                    "commission_rt_per_lot_usd_indicative": 20.37,
                },
                "ftmo": {
                    "commission_model": "pct_notional_metals",
                    "commission_rt_per_lot_usd_indicative": 20.37,
                },
                "worst_case_rt_per_lot_usd": 20.37,
            }
        }
    }


def _live_payload() -> dict[str, object]:
    return {
        "model": "max(pct_rate_rt*notional_acct, flat_per_lot_rt*volume)",
        "classes": {
            "commodity": {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 0}
        },
        "symbol_class": {"XAUUSD.DWX": "commodity"},
    }


def _slippage_payload() -> dict[str, object]:
    return {
        "measurement_status": "MEASURED",
        "symbols": {
            "XAUUSD.DWX": {
                "auto_stub": True,
                "stub_source": "farmctl_pump_p5_calibration_autostub",
                "slippage_points": {"avg": 1.0, "p95": 3.0},
                "spread_points": {"median": 20.0, "p95": 60.0},
                "latency_ms": {"avg": 50.0, "p95": 120.0},
            }
        },
    }


def _cost_files(tmp_path: Path) -> tuple[Path, Path, Path]:
    venue = tmp_path / "venue.json"
    live = tmp_path / "live.json"
    slippage = tmp_path / "slippage.json"
    _write_json(venue, _venue_payload())
    _write_json(live, _live_payload())
    _write_json(slippage, _slippage_payload())
    return venue, live, slippage


def _trade(
    day: date,
    sequence: int,
    adjusted_net: Decimal,
    *,
    volume: Decimal = Decimal("1"),
    entry_deal: str | None = None,
) -> subject.TradeRecord:
    entry = datetime.combine(day, time(9, 0))
    exit_at = datetime.combine(day, time(10, 0))
    cost = Decimal("10")
    return subject.TradeRecord(
        sequence=sequence,
        symbol="XAUUSD.DWX",
        side="buy",
        entry_deal=entry_deal or f"{day:%Y%m%d}{sequence:04d}",
        exit_deals=(f"x{day:%Y%m%d}{sequence:04d}",),
        entry_time_broker=entry,
        exit_time_broker=exit_at,
        entry_time_ny=entry - timedelta(hours=7),
        exit_time_ny=exit_at - timedelta(hours=7),
        broker_day=day.isoformat(),
        new_york_day=(day - timedelta(days=1)).isoformat(),
        volume=volume,
        entry_price=Decimal("2000"),
        entry_comment="asian_sweep_fvg_long",
        native_net_usd=adjusted_net + cost,
        venue_cost_usd=cost,
        adjusted_net_usd=adjusted_net,
    )


def _passing_cells() -> dict[str, list[subject.TradeRecord]]:
    dev_start = date(2018, 7, 2)
    cells: dict[str, list[subject.TradeRecord]] = {
        "DEV": [
            _trade(
                dev_start + timedelta(days=index),
                index + 1,
                Decimal("100") if index < 60 else Decimal("-50"),
            )
            for index in range(80)
        ]
    }
    for year in (2023, 2024, 2025):
        start = date(year, 1, 2)
        cells[f"OOS_{year}"] = [
            _trade(
                start + timedelta(days=index),
                index + 1,
                Decimal("100") if index < 10 else Decimal("-50"),
                entry_deal=f"{year}{index + 1:04d}",
            )
            for index in range(15)
        ]
    return cells


def test_contract_is_frozen_outcome_blind_and_binds_existing_xau_build() -> None:
    contract = subject.validate_analysis_contract()
    assert contract["binding"]["sha256"] == subject.EXPECTED_CONTRACT_SHA256
    assert contract["artifact_bindings"]["set"]["sha256"] == (
        "23970e75ad7c41e682455ddb255473c9e527c2f3a404dbfd74fa8ac9fd363ac6"
    )
    assert contract["artifact_bindings"]["ex5"]["sha256"] == (
        "ffd5a47aa7e7f32759494d4f0e172d785da5d7ccdd5f3cfbfed64aeffbc2943c"
    )
    payload = subject.load_json(subject.CONTRACT_PATH)
    assert payload["outcome_fence"] == {
        "eurusd_native_outcomes_read_to_select_xau": False,
        "metatester_started": False,
        "mt5_terminal_started": False,
        "xau_deal_rows_parsed": False,
        "xau_native_reports_opened": False,
    }


def test_private_profile_does_not_mutate_separately_loaded_eurusd_auditor() -> None:
    spec = importlib.util.spec_from_file_location("qm13210_base_isolation_test", BASE_TOOL)
    assert spec is not None and spec.loader is not None
    base = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = base
    spec.loader.exec_module(base)
    assert base.ANALYSIS_ID == "QM5_13210_MULHAM_ASIAN_SWEEP_LONDON_NATIVE_001"
    assert base.SYMBOL_POLICY.startswith("EURUSD.DWX_")
    base.enforce_symbol_policy("EURUSD.DWX")
    with pytest.raises(base.InvalidEvidence, match="only EURUSD.DWX"):
        base.enforce_symbol_policy("XAUUSD.DWX")


def test_xau_plan_and_runner_are_exact_t1_model4_four_cells_two_duplicates(
    tmp_path: Path,
) -> None:
    set_binding = {
        "path": str(tmp_path / "xau.set"),
        "size": 1,
        "sha256": "a" * 64,
    }
    plan = subject.build_plan("XAUUSD.DWX", set_binding, tmp_path / "run")
    assert plan["single_authorized_symbol"] == "XAUUSD.DWX"
    assert plan["native_run_count"] == 8
    assert [cell["model"] for cell in plan["cells"]] == [4, 4, 4, 4]
    assert [cell["duplicates"] for cell in plan["cells"]] == [2, 2, 2, 2]
    assert [(cell["from_date"], cell["to_date"]) for cell in plan["cells"]] == [
        ("2018-07-02", "2022-12-31"),
        ("2023-01-01", "2023-12-31"),
        ("2024-01-01", "2024-12-31"),
        ("2025-01-01", "2025-12-31"),
    ]
    pre = {
        "bindings": {
            "powershell": {"path": r"C:\pwsh.exe"},
            "runner": {"path": r"C:\run_smoke.ps1"},
        },
        "plan": plan,
    }
    command = subject.runner_command(pre, plan["cells"][0])
    assert command[command.index("-Terminal") + 1] == "T1"
    assert command[command.index("-Symbol") + 1] == "XAUUSD.DWX"
    assert command[command.index("-Model") + 1] == "4"
    assert command[command.index("-Runs") + 1] == "2"
    assert command[command.index("-DispatchVersion") + 1] == (
        "QM5_13210_XAUUSD_MERIT_V1_20260721"
    )
    with pytest.raises(subject.InvalidEvidence, match="only XAUUSD.DWX"):
        subject.build_plan("EURUSD.DWX", set_binding, tmp_path / "eur")
    with pytest.raises(subject.InvalidEvidence, match="only XAUUSD.DWX"):
        subject.build_plan("XAUUSD", set_binding, tmp_path / "suffixless")


def test_xau_set_build_and_binding_paths_are_exact() -> None:
    metadata, inputs = subject.parse_set(
        EA_ROOT
        / "sets"
        / "QM5_13210_mulham-asian-sweep-london_XAUUSD.DWX_M5_backtest.set"
    )
    subject._validate_set_contract("XAUUSD.DWX", metadata, inputs)
    drift = dict(inputs)
    drift["qm_magic_slot_offset"] = "0"
    with pytest.raises(subject.InvalidEvidence, match="input contract drift"):
        subject._validate_set_contract("XAUUSD.DWX", metadata, drift)

    paths = subject._expected_binding_paths("XAUUSD.DWX")
    assert paths["tool"] == TOOL
    assert paths["base_tool"] == BASE_TOOL
    assert paths["xau_contract"] == subject.CONTRACT_PATH
    assert paths["slippage_calibration"] == subject.SLIPPAGE_CALIBRATION_PATH
    assert paths["set"].name.endswith("XAUUSD.DWX_M5_backtest.set")
    bindings = subject._binding_map("XAUUSD.DWX")
    receipt = subject.validate_build_receipt(
        BUILD_RECEIPT, "XAUUSD.DWX", bindings
    )
    assert receipt["setfile_sha256"]["XAUUSD.DWX"] == bindings["set"]["sha256"]


def test_xau_cost_is_notional_commodity_plus_blocking_center_slippage(
    tmp_path: Path,
) -> None:
    venue, live, slippage = _cost_files(tmp_path)
    schedule = subject.resolve_cost_schedule(
        venue, "XAUUSD.DWX", live, slippage
    )
    assert schedule["dxz_pct_notional_rt"] == "0.00005"
    assert schedule["ftmo_pct_notional_rt"] == "0.00005"
    assert schedule["ftmo_rt_per_lot_usd"] == "0"
    assert schedule["contract_size_base_per_lot"] == "100"
    assert schedule["merit_slippage_points_per_side"] == "1"
    assert schedule["p95_slippage_points_per_side"] == "3"
    assert schedule["slippage_proxy"]["classification"].endswith(
        "NOT_XAU_LIVE_FILL_MEASUREMENT"
    )

    entry = SimpleNamespace(
        direction="in",
        symbol="XAUUSD.DWX",
        volume=Decimal("2"),
        commission=Decimal("0"),
        swap=Decimal("0"),
        kind="buy",
        deal="10",
        time=datetime(2025, 7, 7, 9, 0),
        price=Decimal("2000"),
        comment="asian_sweep_fvg_long",
        raw_net=Decimal("0"),
    )
    close = SimpleNamespace(
        direction="out",
        symbol="XAUUSD.DWX",
        volume=Decimal("2"),
        commission=Decimal("0"),
        swap=Decimal("0"),
        kind="sell",
        deal="11",
        time=datetime(2025, 7, 7, 10, 0),
        price=Decimal("2001"),
        comment="",
        raw_net=Decimal("100"),
    )
    trade = subject._reconstruct_trades(
        [entry, close], "XAUUSD.DWX", schedule
    )[0]
    # Commission: 2000 * 100oz * 2 lots * 0.00005 = $20.
    # Center slippage: entry+exit * 1 point * $1/point * 2 lots = $4.
    assert trade.venue_cost_usd == Decimal("24.00")
    assert trade.adjusted_net_usd == Decimal("76.00")
    p95 = subject._p95_stress_trades([trade])[0]
    # Increment from center 1 point/side to p95 3 points/side is another $8.
    assert p95.venue_cost_usd == Decimal("32.00")
    assert p95.adjusted_net_usd == Decimal("68.00")


def test_xau_cost_and_slippage_contracts_fail_closed(tmp_path: Path) -> None:
    venue, live, slippage = _cost_files(tmp_path)
    bad_venue = _venue_payload()
    bad_venue["symbols"]["XAUUSD"]["asset_class"] = "forex"  # type: ignore[index]
    _write_json(venue, bad_venue)
    with pytest.raises(subject.InvalidEvidence, match="venue-cost registry"):
        subject.resolve_cost_schedule(venue, "XAUUSD.DWX", live, slippage)

    _write_json(venue, _venue_payload())
    bad_live = _live_payload()
    bad_live["classes"]["commodity"]["flat_per_lot_rt"] = 5  # type: ignore[index]
    _write_json(live, bad_live)
    with pytest.raises(subject.InvalidEvidence, match="commodity closure"):
        subject.resolve_cost_schedule(venue, "XAUUSD.DWX", live, slippage)

    _write_json(live, _live_payload())
    bad_slippage = _slippage_payload()
    bad_slippage["symbols"]["XAUUSD.DWX"]["slippage_points"]["p95"] = 2  # type: ignore[index]
    _write_json(slippage, bad_slippage)
    with pytest.raises(subject.InvalidEvidence, match="slippage-proxy"):
        subject.resolve_cost_schedule(venue, "XAUUSD.DWX", live, slippage)


def test_xau_semantic_news_projection_is_usd_only() -> None:
    trade = _trade(date(2025, 1, 2), 1, Decimal("100"))
    far_usd = [
        subject.NewsEvent(datetime(2025, 1, 2, 12, 0), "USD", "HIGH")
    ]
    receipt = subject.validate_trade_semantics([trade], far_usd)
    assert receipt["no_fill_inside_bound_usd_high_impact_blackout"] is True
    assert "no_fill_inside_bound_eur_usd_high_impact_blackout" not in receipt
    with pytest.raises(subject.InvalidEvidence, match="only bound USD"):
        subject.validate_trade_semantics(
            [trade],
            [subject.NewsEvent(datetime(2025, 1, 2, 12, 0), "EUR", "HIGH")],
        )


def test_base_merit_gates_use_center_cost_and_p95_axis_is_blocking() -> None:
    merit = subject.evaluate_merit(_passing_cells())
    assert merit["status"] == "PASS"
    assert merit["contract"] == subject.MERIT_GATES
    stress = merit["xau_p95_slippage_stress"]
    assert stress["points_per_side"] == "3"
    assert len(stress["gates"]) == 10
    assert all(row["status"] == "PASS" for row in stress["gates"])


def test_p95_axis_can_reject_a_center_pass(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        subject,
        "_BASE_EVALUATE_MERIT",
        lambda _cells: {
            "contract": subject.MERIT_GATES,
            "gates": [{"gate_id": "CENTER", "status": "PASS"}],
            "status": "PASS",
        },
    )
    cells = {
        "DEV": [_trade(date(2020, 1, 2), 1, Decimal("3"))],
        "OOS_2023": [_trade(date(2023, 1, 2), 1, Decimal("3"))],
        "OOS_2024": [_trade(date(2024, 1, 2), 1, Decimal("3"))],
        "OOS_2025": [_trade(date(2025, 1, 2), 1, Decimal("3"))],
    }
    merit = subject.evaluate_merit(cells)
    assert merit["status"] == "FAIL"
    assert any(
        row["gate_id"] == "XAU_P95_OOS_POOLED_NET"
        and row["status"] == "FAIL"
        for row in merit["gates"]
    )


def test_authorization_is_xau_only_and_separate_from_eurusd(
    tmp_path: Path,
) -> None:
    now = datetime(2026, 7, 21, 8, 0, tzinfo=timezone.utc)
    payload = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": subject.ANALYSIS_ID,
        "pre_receipt_sha256": "a" * 64,
        "scope": subject.AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": "XAUUSD.DWX",
        "authorized_cells": [window.cell_id for window in subject.WINDOWS],
        "duplicates_per_cell": 2,
        "model": 4,
        "authorize_native_outcomes": True,
        "created_utc": "2026-07-21T07:55:00Z",
        "expires_utc": "2026-07-21T19:55:00Z",
    }
    path = tmp_path / "authorization.json"
    _write_json(path, payload)
    subject.validate_authorization(path, "a" * 64, now=now)
    payload["authorized_symbol"] = "EURUSD.DWX"
    _write_json(path, payload)
    with pytest.raises(subject.AuthorizationError, match="authorization drift"):
        subject.validate_authorization(path, "a" * 64, now=now)


def test_contract_semantic_tamper_is_rejected(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    payload = subject.load_json(subject.CONTRACT_PATH)
    payload["execution_cost_contract"]["commission"]["rate_round_turn"] = "0"
    tampered = tmp_path / "contract.json"
    _write_json(tampered, payload)
    monkeypatch.setattr(subject, "EXPECTED_CONTRACT_SHA256", subject.sha256_file(tampered))
    with pytest.raises(subject.InvalidEvidence, match="execution-cost contract"):
        subject.validate_analysis_contract(tampered)


def test_cli_has_no_cost_merit_or_terminal_override_surface() -> None:
    parser = subject.build_parser()
    subparsers = next(
        action for action in parser._actions if getattr(action, "choices", None)
    )
    pre_options = {
        option
        for action in subparsers.choices["pre"]._actions
        for option in action.option_strings
    }
    launch_options = {
        option
        for action in subparsers.choices["launch"]._actions
        for option in action.option_strings
    }
    forbidden = {
        "--terminal",
        "--model",
        "--duplicates",
        "--commission",
        "--slippage",
        "--profit-factor",
        "--min-trades",
    }
    assert not (pre_options | launch_options) & forbidden
    assert {"base_tool", "xau_contract", "slippage_calibration"} <= (
        subject.REQUIRED_BINDING_ROLES
    )
