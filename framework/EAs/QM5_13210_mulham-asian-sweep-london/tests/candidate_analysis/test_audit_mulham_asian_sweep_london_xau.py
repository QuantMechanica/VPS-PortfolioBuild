from __future__ import annotations

import importlib.util
import json
import subprocess
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
    return json.loads(json.dumps(subject.XAU_CALIBRATION_PROJECTION))


def _cost_files(tmp_path: Path) -> tuple[Path, Path]:
    venue = tmp_path / "venue.json"
    live = tmp_path / "live.json"
    _write_json(venue, _venue_payload())
    _write_json(live, _live_payload())
    return venue, live


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


def test_finalized_contract_binds_source_adapter_and_only_attempt002() -> None:
    receipt = subject.validate_analysis_contract()
    payload = subject.load_json(subject.CONTRACT_PATH)
    assert payload["status"] == "FINALIZED_OUTCOME_BLIND"
    assert set(payload["artifact_bindings"]) == subject.FINAL_ARTIFACT_ROLES
    assert payload["artifact_bindings"]["adapter"] == receipt["artifact_bindings"][
        "adapter"
    ]
    assert "scheduled_task_helper" in payload["artifact_bindings"]
    assert "attempt001_closure" in payload["artifact_bindings"]
    assert payload["run_namespace"]["attempt_id"] == "ATTEMPT_002"
    assert payload["infrastructure_alternate"]["attempt003_plus_forbidden"] is True
    assert "finalization" not in payload


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
    plan = subject.build_plan(
        "XAUUSD.DWX", set_binding, subject.ALLOWED_RUN_ROOT
    )
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
    with pytest.raises(subject.InvalidEvidence, match="single frozen root"):
        subject.build_plan("XAUUSD.DWX", set_binding, tmp_path / "sibling")


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
    assert "slippage_calibration" not in paths
    assert paths["set"].name.endswith("XAUUSD.DWX_M5_backtest.set")
    assert subject.file_binding(paths["tool"]) == subject.file_binding(TOOL)
    assert subject.file_binding(paths["xau_contract"]) == subject.file_binding(
        subject.CONTRACT_PATH
    )


def test_updated_build_receipt_is_ready_for_post_commit_freeze() -> None:
    artifacts = {
        role: subject.file_binding(path)
        for role, path in subject._artifact_contract_paths().items()
    }
    receipt = subject._validate_bound_build_receipt(
        artifacts, "9e6c17e1e954aa6854afcc93dc72b64926316fd1"
    )
    assert receipt["compile_errors"] == 0
    assert receipt["compile_warnings"] == 0
    assert receipt["setfile_sha256"]["XAUUSD.DWX"] == artifacts["set"]["sha256"]


def test_xau_cost_is_notional_commodity_plus_blocking_center_slippage(
    tmp_path: Path,
) -> None:
    venue, live = _cost_files(tmp_path)
    schedule = subject.resolve_cost_schedule(
        venue, "XAUUSD.DWX", live, _slippage_payload()
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
    venue, live = _cost_files(tmp_path)
    bad_venue = _venue_payload()
    bad_venue["symbols"]["XAUUSD"]["asset_class"] = "forex"  # type: ignore[index]
    _write_json(venue, bad_venue)
    with pytest.raises(subject.InvalidEvidence, match="venue-cost registry"):
        subject.resolve_cost_schedule(venue, "XAUUSD.DWX", live, _slippage_payload())

    _write_json(venue, _venue_payload())
    bad_live = _live_payload()
    bad_live["classes"]["commodity"]["flat_per_lot_rt"] = 5  # type: ignore[index]
    _write_json(live, bad_live)
    with pytest.raises(subject.InvalidEvidence, match="commodity closure"):
        subject.resolve_cost_schedule(venue, "XAUUSD.DWX", live, _slippage_payload())

    _write_json(live, _live_payload())
    bad_slippage = _slippage_payload()
    bad_slippage["slippage_points_per_side"]["p95_stress"] = "2"  # type: ignore[index]
    with pytest.raises(subject.InvalidEvidence, match="calibration projection"):
        subject.resolve_cost_schedule(venue, "XAUUSD.DWX", live, bad_slippage)


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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
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
    monkeypatch.setattr(subject, "ATTEMPT_002_AUTHORIZATION_PATH", path)
    _write_json(path, payload)
    subject.validate_authorization(path, "a" * 64, now=now)
    payload["authorized_symbol"] = "EURUSD.DWX"
    _write_json(path, payload)
    with pytest.raises(subject.AuthorizationError, match="authorization drift"):
        subject.validate_authorization(path, "a" * 64, now=now)


def test_contract_semantic_and_symbolspec_tamper_are_rejected(tmp_path: Path) -> None:
    payload = subject.load_json(subject.CONTRACT_PATH)
    payload["execution_cost_contract"]["commission"]["rate_round_turn"] = "0"
    tampered = tmp_path / "contract.json"
    _write_json(tampered, payload)
    with pytest.raises(subject.InvalidEvidence, match="draft contract semantic"):
        subject.validate_draft_contract(tampered)

    payload = subject.load_json(subject.CONTRACT_PATH)
    payload["symbol_spec_contract"]["contract_size_oz_per_lot"] = "1"
    _write_json(tampered, payload)
    with pytest.raises(subject.InvalidEvidence, match="draft contract semantic"):
        subject.validate_draft_contract(tampered)


def test_final_payload_binds_adapter_and_stable_xau_only_projection() -> None:
    bindings = {
        role: {"path": f"C:/frozen/{role}", "size": 1, "sha256": role[0] * 64}
        for role in subject.FINAL_ARTIFACT_ROLES
    }
    payload = subject._finalized_contract_payload(
        "a" * 40, "2026-07-21T08:00:00Z", bindings
    )
    assert payload["artifact_bindings"]["adapter"] == bindings["adapter"]
    assert set(payload["artifact_bindings"]) == subject.FINAL_ARTIFACT_ROLES
    assert payload["xau_calibration_projection"] == (
        subject.XAU_CALIBRATION_PROJECTION
    )
    assert "slippage_calibration" not in payload["artifact_bindings"]


def test_finalized_adapter_binding_rejects_byte_tamper(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = {role: tmp_path / role for role in subject.FINAL_ARTIFACT_ROLES}
    for role, path in paths.items():
        path.write_bytes(f"frozen-{role}".encode("ascii"))
    bindings = {role: subject.file_binding(path) for role, path in paths.items()}
    monkeypatch.setattr(subject, "_artifact_contract_paths", lambda: paths)
    validated = subject._validate_contract_artifact_bindings(bindings)
    assert validated["adapter"] == bindings["adapter"]
    paths["adapter"].write_bytes(b"tampered-adapter")
    with pytest.raises(subject.InvalidEvidence, match="drift"):
        subject._validate_contract_artifact_bindings(bindings)


def test_pre_and_assert_bind_the_same_finalized_adapter_bytes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    adapter = subject.file_binding(TOOL)
    helper = subject.file_binding(
        EA_ROOT / "tools" / "candidate_analysis" / "run_outcome_fenced_task.ps1"
    )
    closure_binding = subject.file_binding(subject.ATTEMPT_001_CLOSURE_PATH)
    closure = {
        "binding": closure_binding,
        "status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "control_bindings": {},
        "native_start_count": 0,
        "task_absent": True,
    }
    infra = {"attempt002_is_only_authorized_alternate": True}
    frozen = {
        "artifact_bindings": {
            "adapter": adapter,
            "scheduled_task_helper": helper,
            "attempt001_closure": closure_binding,
        },
        "binding": {"sha256": "a" * 64},
        "infrastructure_alternate": infra,
    }
    base_pre = {
        "bindings": {
            "tool": adapter,
            "scheduled_task_helper": helper,
            "attempt001_closure": closure_binding,
        },
        "cost_schedule": subject.ATTEMPT_002_COST_SCHEDULE,
    }
    readiness = tmp_path / "readiness.json"
    manifest = tmp_path / "manifest.json"
    readiness.write_bytes(b"readiness")
    manifest.write_bytes(b"manifest")
    monkeypatch.setattr(
        subject,
        "ATTEMPT_002_INPUT_BINDINGS",
        {
            "research_readiness_receipt": subject.file_binding(readiness),
            "data_manifest": subject.file_binding(manifest),
        },
    )
    monkeypatch.setattr(
        subject,
        "validate_attempt001_invalid_infrastructure_closure",
        lambda *args, **kwargs: closure,
    )
    monkeypatch.setattr(subject, "_contract_receipt", lambda: frozen)
    monkeypatch.setattr(subject, "_assert_pristine_one_shot_namespace", lambda: None)
    monkeypatch.setattr(subject, "_assert_no_sibling_or_prior_namespace", lambda: None)
    monkeypatch.setattr(subject, "_assert_finalized_contract_committed", lambda: None)
    monkeypatch.setattr(subject, "_BASE_PREFLIGHT", lambda *_args: dict(base_pre))
    pre = subject.preflight(
        "XAUUSD.DWX",
        readiness,
        manifest,
        subject.BUILD_RECEIPT_PATH,
        subject.ALLOWED_RUN_ROOT,
    )
    assert pre["xau_preregistration"] == frozen
    assert pre["attempt_id"] == "ATTEMPT_002"
    assert pre["attempt001_invalid_infrastructure_closure"] == closure
    pre_path = tmp_path / "pre.json"
    monkeypatch.setattr(subject, "ATTEMPT_002_PRE_RECEIPT_PATH", pre_path)
    monkeypatch.setattr(subject, "_BASE_ASSERT_PRE_RECEIPT", lambda *_args: pre)
    assert subject.assert_pre_receipt(pre_path, "b" * 64) == pre

    drifted = json.loads(json.dumps(frozen))
    drifted["artifact_bindings"]["scheduled_task_helper"]["sha256"] = "c" * 64
    monkeypatch.setattr(subject, "_contract_receipt", lambda: drifted)
    with pytest.raises(subject.InvalidEvidence, match="scheduled_task_helper bytes"):
        subject.assert_pre_receipt(pre_path, "b" * 64)


def test_sibling_prior_and_legacy_xau_namespaces_fail_closed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    family = tmp_path / "QM5_13210"
    namespace = family / "XAUUSD_MULHAM_NATIVE_001"
    attempt001 = namespace / "ATTEMPT_001"
    exact = namespace / "ATTEMPT_002"
    legacy = family / "XAUUSD_DWX"
    monkeypatch.setattr(subject, "RUN_FAMILY_ROOT", family)
    monkeypatch.setattr(subject, "RUN_NAMESPACE_ROOT", namespace)
    monkeypatch.setattr(subject, "ATTEMPT_001_RUN_ROOT", attempt001)
    monkeypatch.setattr(subject, "ALLOWED_RUN_ROOT", exact)
    monkeypatch.setattr(subject, "LEGACY_RUN_ROOT", legacy)
    monkeypatch.setattr(
        subject,
        "validate_attempt001_invalid_infrastructure_closure",
        lambda *args, **kwargs: {"status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND"},
    )
    attempt001.mkdir(parents=True)
    exact.mkdir(parents=True)
    subject._assert_pristine_one_shot_namespace()

    sibling = namespace / "ATTEMPT_003"
    sibling.mkdir()
    with pytest.raises(subject.InvalidEvidence, match=r"ATTEMPT_003\+"):
        subject._assert_pristine_one_shot_namespace()
    sibling.rmdir()
    legacy.mkdir()
    with pytest.raises(subject.InvalidEvidence, match="legacy/prior XAU"):
        subject._assert_pristine_one_shot_namespace()


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
        "--resume",
    }
    assert not (pre_options | launch_options) & forbidden
    assert {"attempt001_closure", "base_tool", "xau_contract"} <= (
        subject.REQUIRED_BINDING_ROLES
    )
    assert "slippage_calibration" not in subject.REQUIRED_BINDING_ROLES
    finalize_options = {
        option
        for action in subparsers.choices["finalize-contract"]._actions
        for option in action.option_strings
    }
    assert "--source-commit" in finalize_options


@pytest.mark.parametrize(
    "task_name",
    [
        "QM_QM13210_AUDIT_" + ("a" * 24),
        "QM_QM13210_XAU_AUDIT_" + ("0" * 24),
    ],
)
def test_scheduled_task_helper_accepts_exact_eur_and_xau_prefixes(
    task_name: str,
) -> None:
    helper = EA_ROOT / "tools" / "candidate_analysis" / "run_outcome_fenced_task.ps1"
    completed = subprocess.run(
        [
            str(subject.B.POWERSHELL_PATH),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(helper),
            "-Operation",
            "Identity",
            "-TaskName",
            task_name,
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert completed.returncode == 0, completed.stderr


@pytest.mark.parametrize(
    "task_name",
    [
        "QM_QM13210_AUDIT_" + ("A" * 24),
        "QM_QM13210_XAU_AUDIT_" + ("a" * 23),
        "QM_QM13210_XAU_AUDIT_" + ("a" * 25),
        "QM_QM13210_XAUUSD_AUDIT_" + ("a" * 24),
        "QM_QM13210_XAU_AUDIT_" + ("g" * 24),
        "QM_QM13210_AUDIT_XAU_" + ("a" * 24),
    ],
)
def test_scheduled_task_helper_rejects_near_prefixes(task_name: str) -> None:
    helper = EA_ROOT / "tools" / "candidate_analysis" / "run_outcome_fenced_task.ps1"
    completed = subprocess.run(
        [
            str(subject.B.POWERSHELL_PATH),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(helper),
            "-Operation",
            "Identity",
            "-TaskName",
            task_name,
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert completed.returncode != 0


def test_attempt001_closure_binds_control_files_and_zero_native_starts(
    tmp_path: Path,
) -> None:
    validated = subject.validate_attempt001_invalid_infrastructure_closure(
        probe_task_absence=False
    )
    assert validated["native_start_count"] == 0
    assert validated["task_absent"] is True
    assert set(validated["control_bindings"]) == {
        "pre_receipt",
        "authorization",
        "launch_job",
        "launch_state",
    }

    payload = subject.load_json(subject.ATTEMPT_001_CLOSURE_PATH)
    payload["native_start_proof"]["native_start_count"] = 1
    tampered = tmp_path / "tampered_closure.json"
    _write_json(tampered, payload)
    with pytest.raises(subject.InvalidEvidence, match="closure semantic drift"):
        subject.validate_attempt001_invalid_infrastructure_closure(
            tampered, probe_task_absence=False
        )


def test_attempt002_is_the_only_execution_namespace_and_resume_is_forbidden(
    tmp_path: Path,
) -> None:
    subject._assert_exact_run_root(subject.ATTEMPT_002_RUN_ROOT)
    with pytest.raises(subject.InvalidEvidence, match="single frozen root"):
        subject._assert_exact_run_root(subject.ATTEMPT_001_RUN_ROOT)
    with pytest.raises(subject.InvalidEvidence, match="single frozen root"):
        subject._assert_exact_run_root(subject.RUN_NAMESPACE_ROOT / "ATTEMPT_003")
    with pytest.raises(subject.AuthorizationError, match="resume is forbidden"):
        subject.launch_persistent_task(
            subject.ATTEMPT_002_PRE_RECEIPT_PATH,
            "a" * 64,
            subject.ATTEMPT_002_AUTHORIZATION_PATH,
            subject.ATTEMPT_002_STATE_PATH,
            resume=True,
        )
    with pytest.raises(subject.InvalidEvidence, match="POST receipt"):
        subject._assert_exact_control_path(
            tmp_path / "post.json", subject.ATTEMPT_002_POST_RECEIPT_PATH, "POST receipt"
        )
