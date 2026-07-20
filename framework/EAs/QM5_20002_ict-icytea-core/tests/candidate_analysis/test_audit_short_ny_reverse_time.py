from __future__ import annotations

import importlib.util
import json
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

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


def test_contract_v3_binds_source_corrections_news_and_fill_invalid_gate() -> None:
    contract = subject.load_contract()
    assert contract["schema_version"] == 2
    assert contract["contract_revision"] == 3
    assert len(contract["data_bindings"]["news_calendars"]) == 2
    assert contract["execution_integrity_gates"]["violation_disposition"] == "INVALID"
    assert contract["revision_3_causal_semantics"][
        "pre_sweep_fvg_may_satisfy_displacement"
    ] is False
    assert contract["revision_3_calendar_and_runtime_safety"][
        "broker_d1_levels_forbidden"
    ] is True


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


def test_news_binding_seals_effective_qmdev1_file_common(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    seed_root = tmp_path / "seed"
    common_root = tmp_path / "common"
    seed_root.mkdir()
    common_root.mkdir()
    seed = seed_root / "calendar.csv"
    mirror = common_root / seed.name
    seed.write_bytes(b"datetime,currency,impact\n2020.01.01 12:00,USD,High\n")
    mirror.write_bytes(seed.read_bytes())
    digest = subject.sha256_file(seed)
    monkeypatch.setattr(subject, "DEV1_COMMON_FILES_ROOT", common_root)
    result = subject.validate_news_bindings(
        {
            "data_bindings": {
                "news_calendars": [
                    {"role": "TEST", "path": str(seed), "sha256": digest}
                ]
            }
        }
    )
    assert result[0]["binding"]["sha256"] == digest
    assert result[0]["tester_common_binding"]["sha256"] == digest


def test_news_binding_rejects_effective_mirror_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    seed_root = tmp_path / "seed"
    common_root = tmp_path / "common"
    seed_root.mkdir()
    common_root.mkdir()
    seed = seed_root / "calendar.csv"
    seed.write_bytes(b"seed")
    (common_root / seed.name).write_bytes(b"drift")
    monkeypatch.setattr(subject, "DEV1_COMMON_FILES_ROOT", common_root)
    with pytest.raises(subject.AuditError, match="SHA-256 drift"):
        subject.validate_news_bindings(
            {
                "data_bindings": {
                    "news_calendars": [
                        {
                            "role": "TEST",
                            "path": str(seed),
                            "sha256": subject.sha256_file(seed),
                        }
                    ]
                }
            }
        )


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


def test_opening_fill_gate_rejects_outside_kz_and_bound_news() -> None:
    outside = subject.NativeAudit(
        receipt={},
        deals=[SimpleNamespace(direction="in", time=datetime(2020, 1, 2, 13, 59), deal="1")],
        fragments=[],
        trades=[],
    )
    with pytest.raises(subject.PostflightError, match="OUTSIDE_NY_07_10"):
        subject._validate_opening_fills(
            outside, "EURUSD.DWX", {"events": [], "times": []}
        )

    news_time = datetime(2020, 1, 2, 12, 0)
    inside_news = subject.NativeAudit(
        receipt={},
        deals=[SimpleNamespace(direction="in", time=datetime(2020, 1, 2, 14, 0), deal="2")],
        fragments=[],
        trades=[],
    )
    with pytest.raises(subject.PostflightError, match="INSIDE_BOUND_NEWS_BLACKOUT_UNION"):
        subject._validate_opening_fills(
            inside_news,
            "EURUSD.DWX",
            {"events": [(news_time, "USD", "HIGH")], "times": [news_time]},
        )


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


def test_detached_timeout_leaves_inner_controller_cleanup_margin() -> None:
    pre = {
        "plan": {
            "duplicates_per_cell": 2,
            "cells": [
                {"runner_arguments": ["-TimeoutSeconds", "28800"]},
                {"runner_arguments": ["-TimeoutSeconds", "28800"]},
            ],
        }
    }
    assert subject.required_controller_timeout(pre) == 59040


def test_worker_seals_exactly_two_native_artifact_sets(tmp_path: Path) -> None:
    report_dir = tmp_path / "report"
    runs = []
    for name in ("run_01", "run_02"):
        run_dir = report_dir / "raw" / name
        run_dir.mkdir(parents=True)
        report = run_dir / "report.htm"
        log = run_dir / "tester.log"
        ini = run_dir / "tester.ini"
        report.write_text("report", encoding="utf-8")
        log.write_text("log", encoding="utf-8")
        ini.write_text("[Tester]", encoding="utf-8")
        runs.append(
            {
                "run": name,
                "status": "OK",
                "exit_code": 0,
                "report_canonical_path": str(report),
                "tester_log_path": str(log),
            }
        )
    summary = report_dir / "summary.json"
    summary.write_text(
        json.dumps({"report_dir": str(report_dir), "runs": runs}), encoding="utf-8"
    )
    sealed = subject._seal_summary_artifacts(summary)
    assert [row["run"] for row in sealed["run_artifacts"]] == ["run_01", "run_02"]
    assert all(row["report"]["sha256"] for row in sealed["run_artifacts"])

    runs.append(dict(runs[-1], run="run_03"))
    summary.write_text(
        json.dumps({"report_dir": str(report_dir), "runs": runs}), encoding="utf-8"
    )
    with pytest.raises(subject.AuditError, match="exactly the two"):
        subject._seal_summary_artifacts(summary)


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
