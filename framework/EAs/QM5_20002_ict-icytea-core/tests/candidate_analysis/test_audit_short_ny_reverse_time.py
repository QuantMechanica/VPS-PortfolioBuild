from __future__ import annotations

import importlib.util
import json
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_short_ny_reverse_time.py"
)
SPEC = importlib.util.spec_from_file_location("audit_short_ny_reverse_time", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def test_contract_v2_binds_both_news_inputs_and_fill_invalid_gate() -> None:
    contract = subject.load_contract()
    assert contract["schema_version"] == 2
    assert contract["contract_revision"] == 2
    assert len(contract["data_bindings"]["news_calendars"]) == 2
    assert contract["execution_integrity_gates"]["violation_disposition"] == "INVALID"


def test_four_cell_plan_is_exact_and_model4() -> None:
    contract = subject.load_contract()
    cells, _ = subject.validate_sets(contract)
    plan = subject.build_plan(cells, 28800)
    assert plan["cell_count"] == 4
    assert plan["total_native_runs"] == 8
    assert plan["model"] == 4
    assert len({cell["cell_id"] for cell in plan["cells"]}) == 4
    for cell in plan["cells"]:
        args = cell["runner_arguments"]
        assert args[args.index("-Model") + 1] == "4"
        assert args[args.index("-Runs") + 1] == "2"
        assert args[args.index("-CommissionPerLot") + 1] == "0"
        assert args[args.index("-CommissionPerSideNative") + 1] == "0"


def test_expected_model4_data_fence_stops_at_202112() -> None:
    paths = subject._expected_data_paths()
    ticks = [path for path in paths if "\\ticks\\" in path]
    assert len(paths) == 113
    assert len(ticks) == 102
    assert all("2022" not in path for path in paths)
    assert any(path.endswith("201710.tkc") for path in ticks)
    assert any(path.endswith("202112.tkc") for path in ticks)


def test_broker_new_york_conversion_matches_frozen_minus_seven_hours() -> None:
    for broker in (
        datetime(2019, 1, 15, 14, 0),
        datetime(2019, 7, 15, 14, 0),
        datetime(2020, 3, 8, 14, 0),
        datetime(2020, 11, 1, 14, 0),
    ):
        assert subject.broker_to_new_york(broker) == broker.replace(hour=7)


def test_news_blackout_is_inclusive_and_symbol_specific() -> None:
    events = [
        (datetime(2020, 1, 2, 13, 30), "USD", "HIGH"),
        (datetime(2020, 1, 2, 15, 0), "JPY", "HIGH"),
    ]
    news = {"events": events, "times": [row[0] for row in events]}
    assert subject.news_blackout(news, datetime(2020, 1, 2, 13, 0), "EURUSD.DWX")
    assert subject.news_blackout(news, datetime(2020, 1, 2, 14, 0), "GBPUSD.DWX")
    assert not subject.news_blackout(news, datetime(2020, 1, 2, 14, 1), "EURUSD.DWX")
    assert not subject.news_blackout(news, datetime(2020, 1, 2, 15, 0), "EURUSD.DWX")


def test_input_equivalence_is_typed_but_not_permissive() -> None:
    assert subject._input_equivalent("0.0", "0,00")
    assert subject._input_equivalent("true", "TRUE")
    assert subject._input_equivalent("16385", "16385")
    assert not subject._input_equivalent("true", "1")
    assert not subject._input_equivalent("high", "HIGH")


def test_cost_and_slippage_are_applied_per_side_volume() -> None:
    row = {
        "volume": Decimal("1.25"),
        "raw_net": Decimal("100.00"),
        "external_cost": Decimal("7.50"),
    }
    assert subject._scenario_net(row, 0) == Decimal("92.50")
    assert subject._scenario_net(row, 2) == Decimal("87.50")
    assert subject._scenario_net(row, 5) == Decimal("80.00")


def test_duplicate_fingerprint_includes_deal_and_run_identity() -> None:
    payload = [{"time": "2020-01-01T12:00:00", "deal": "2", "price": "1.1"}]
    baseline = subject.canonical_sha256(payload)
    assert baseline == subject.canonical_sha256(json.loads(json.dumps(payload)))
    payload[0]["price"] = "1.10001"
    assert baseline != subject.canonical_sha256(payload)


def test_authorization_rejects_wrong_pre_binding(tmp_path: Path) -> None:
    auth = tmp_path / "authorization.json"
    auth.write_text(
        json.dumps(
            {
                "analysis_id": subject.ANALYSIS_ID,
                "pre_receipt_sha256": "a" * 64,
                "scope": "QM5_20002_4_CELLS_X_2_DUPLICATES_MODEL4",
                "mt5_execution_authorized": True,
                "authorized_by": "OWNER",
                "authorized_utc": "2026-07-20T02:00:00Z",
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(subject.AuthorizationError, match="pre_receipt_sha256"):
        subject.validate_authorization(auth, "b" * 64)


def test_pre_cli_fails_closed_before_any_launch_when_compile_missing(tmp_path: Path) -> None:
    receipt = tmp_path / "pre_reject.json"
    rc = subject.main(
        [
            "pre",
            "--compile-evidence",
            str(tmp_path / "missing.json"),
            "--receipt",
            str(receipt),
        ]
    )
    assert rc == 2
    payload = json.loads(receipt.read_text(encoding="utf-8"))
    assert payload["status"] == "REJECT"
    assert payload["artifact_type"] == "QM5_20002_SHORT_NY_PRE_REJECTION"


def test_profit_factor_states_are_fail_closed() -> None:
    pf, state = subject.profit_factor([Decimal("2"), Decimal("-1")])
    assert pf == Decimal("2") and state == "FINITE"
    assert subject._pf_pass(pf, state, Decimal("1.35"))
    pf, state = subject.profit_factor([Decimal("2"), Decimal("1")])
    assert pf is None and state == "INFINITE_NO_LOSSES"
    assert subject._pf_pass(pf, state, Decimal("100"))
    pf, state = subject.profit_factor([])
    assert not subject._pf_pass(pf, state, Decimal("1"))
