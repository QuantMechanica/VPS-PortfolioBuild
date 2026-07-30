from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_book3_standalone_evaluator as evaluator


EVALUATOR_SOURCE_COMMIT = "2" * 40
INCLUDE_TREE_SHA256 = "b" * 64
EXPECTED_BASE_SUCCESS_KEYS = {
    "worker_exit_code_zero",
    "work_item_done",
    "work_item_pass",
    "work_item_unclaimed",
    "work_item_evidence_valid",
    "post_run_stream_valid",
    "execution_inputs_unchanged",
    "runtime_sources_unchanged",
    "payload_contract_revalidated",
    "fidelity_receipt_unchanged",
    "process_tree_quiescent",
}
EXPECTED_DIAGNOSTIC_SUCCESS_KEYS = EXPECTED_BASE_SUCCESS_KEYS | {
    "diagnostic_q08_valid",
    "diagnostic_v2_r2_unchanged",
    "diagnostic_hold_unchanged",
}


@pytest.fixture(autouse=True)
def _stable_evaluator_git_source(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        evaluator,
        "_git_source_state",
        lambda repo_root, paths: {"head": EVALUATOR_SOURCE_COMMIT, "dirty": []},
    )


def _evaluator_source_binding() -> dict[str, object]:
    return {
        "repo_root": str(evaluator.REPO_ROOT),
        "source_commit": EVALUATOR_SOURCE_COMMIT,
        "source_scope_clean": True,
        "artifacts": [
            {
                "role": role,
                "path": str(path),
                "sha256": evaluator.sha256_file(path),
                "bytes": path.stat().st_size,
            }
            for role, path in evaluator.EVALUATOR_SOURCE_PATHS.items()
        ],
    }


def _day(
    number: int,
    *,
    realized: float = 0.0,
    low: float = 0.0,
    opens: int = 1,
    flat_start: bool = True,
    flat_end: bool = True,
) -> evaluator.DailyObservation:
    return evaluator.DailyObservation(
        day=dt.date(2024, 1, 1) + dt.timedelta(days=number),
        realized=realized,
        minimum_equity_delta=low,
        opened_positions=opens,
        flat_at_start=flat_start,
        flat_at_end=flat_end,
    )


def _write(path: Path, content: str) -> dict[str, object]:
    path.write_text(content, encoding="utf-8")
    raw = path.read_bytes()
    stat = path.stat()
    return {
        "path": str(path.resolve()),
        "sha256": evaluator.sha256_file(path),
        "bytes": len(raw),
        "lines": raw.count(b"\n") + (1 if raw and not raw.endswith(b"\n") else 0),
        "file_identity": {"device": stat.st_dev, "inode": stat.st_ino},
    }


def _write_json(path: Path, value: object) -> dict[str, object]:
    return _write(path, json.dumps(value, indent=2) + "\n")


def _rulepack() -> dict[str, object]:
    value = json.loads(evaluator.DEFAULT_RULEPACK_PATH.read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def _cost_snapshot(now: dt.datetime) -> dict[str, object]:
    rows = []
    values = {
        "USDJPY.DWX": ("USD/JPY", 100000, 100000, 3, 0.0, 5.0, 0.92, -19.78),
        "XAUUSD.DWX": ("XAU/USD", 100, 100, 2, 0.0014, 0.0, -66.21, -23.55),
        "XTIUSD.DWX": ("USOIL.cash", 1000, 100, 3, 0.0, 0.0, 4.22, -26.8),
    }
    for symbol, (
        provider,
        source_contract,
        target_contract,
        digits,
        percent,
        flat,
        swap_long,
        swap_short,
    ) in values.items():
        models = {
            "USDJPY.DWX": "flat_round_trip_per_target_lot_usd",
            "XAUUSD.DWX": "percent_of_notional_per_side",
            "XTIUSD.DWX": "commission_free",
        }
        rows.append(
            {
                "dwx_symbol": symbol,
                "provider_symbol": provider,
                "source_contract_size": source_contract,
                "target_contract_size": target_contract,
                "commission_model": models[symbol],
                "flat_round_trip_commission_per_lot": flat,
                "commission_percent_per_side": percent,
                "swap_long_points": swap_long,
                "swap_short_points": swap_short,
                "digits": digits,
                "profit_currency_to_account_rate": (
                    0.0066666667 if symbol == "USDJPY.DWX" else 1
                ),
                "derive_profit_currency_rate_from_pnl": symbol == "USDJPY.DWX",
                "triple_weekday": 2,
            }
        )
    asset_classes = {
        "USD/JPY": "Forex",
        "XAU/USD": "Metals CFD",
        "USOIL.cash": "Cash CFD",
    }
    profit_currencies = {"USD/JPY": "JPY", "XAU/USD": "USD", "USOIL.cash": "USD"}
    selected_provider_rows = [
        {
            "active": True,
            "assetClass": asset_classes[provider],
            "code": provider,
            "commission": flat if flat else percent,
            "commissionType": "flat_USD" if flat else "percent",
            "contractSize": target_contract,
            "digits": digits,
            "swapLong": swap_long,
            "swapShort": swap_short,
            "swapType": "points",
            "profitCurrency": profit_currencies[provider],
        }
        for (
            provider,
            _source_contract,
            target_contract,
            digits,
            percent,
            flat,
            swap_long,
            swap_short,
        ) in values.values()
    ]
    return {
        "schema": evaluator.COST_SNAPSHOT_SCHEMA,
        "retrieved_at_utc": now.isoformat().replace("+00:00", "Z"),
        "source": {
            "authority": "OFFICIAL_PROVIDER",
            "api_url": "https://ftmo.com/wp-json/ftmo/symbols",
            "http_status": 200,
            "response_sha256": evaluator.EXPECTED_COST_RESPONSE_SHA256,
            "platform_utc_offset_hours": 3,
        },
        "book3_normalization": rows,
        "selected_provider_rows": selected_provider_rows,
        "authorization": {
            "deployment_allowed": False,
            "money_gate_authorized": False,
            "factory_action_authorized": False,
            "purpose": "Research-only FTMO Book-3 cost input",
        },
    }


def _excluded_v2_r2() -> dict[str, object]:
    excluded_id = "excluded-v2-r2"
    payload_json = json.dumps(
        {
            "measurement_contract": evaluator.LADDER_MEASUREMENT_CONTRACT,
            "measurement_rung": "R2",
            "measurement_sequence": 4,
            "terminal": "T10",
        },
        separators=(",", ":"),
    )
    row = {
        "id": excluded_id,
        "kind": "backtest",
        "phase": "Q02",
        "ea_id": "QM5_13108",
        "symbol": "XTIUSD.DWX",
        "setfile_path": "C:/test/QM5_13108.set",
        "status": "pending",
        "verdict": None,
        "attempt_count": 0,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": payload_json,
        "created_at": "2026-07-29T00:00:00Z",
        "updated_at": "2026-07-29T00:00:00Z",
    }
    hold = {
        "work_item_id": excluded_id,
        "hold_code": evaluator.EXCLUDED_V2_R2_HOLD_CODE,
        "reason": evaluator.EXCLUDED_V2_R2_HOLD_REASON,
        "active": 1,
        "release_on_restart": 0,
        "created_at": "2026-07-29T00:00:00Z",
        "updated_at": "2026-07-29T00:00:00Z",
        "released_at": None,
        "release_note": None,
    }
    return {
        "id": excluded_id,
        "status": "pending",
        "verdict": None,
        "claimed_by": None,
        "evidence_path": None,
        "payload_sha256": evaluator.hashlib.sha256(payload_json.encode()).hexdigest(),
        "row": row,
        "row_sha256": evaluator.canonical_sha256(row),
        "hold": hold,
        "hold_sha256": evaluator.canonical_sha256(hold),
    }


def _receipt(
    *,
    rung: str,
    ea_id: int,
    symbol: str,
    work_item_id: str,
    summary: dict[str, object],
    stream: dict[str, object],
    source_commit: str,
    strategy_artifacts: dict[str, dict[str, str]],
) -> dict[str, object]:
    diagnostic = rung == "R2"
    excluded_v2_r2 = _excluded_v2_r2()
    diagnostic_hold = {
        "work_item_id": work_item_id,
        "hold_code": evaluator.DIAGNOSTIC_HOLD_CODE,
        "reason": evaluator.DIAGNOSTIC_HOLD_REASON,
        "active": 1,
        "release_on_restart": 0,
        "created_at": "2026-07-30T00:00:00Z",
        "updated_at": "2026-07-30T00:00:00Z",
        "released_at": None,
        "release_note": None,
    }
    measurement_contract = (
        evaluator.DIAGNOSTIC_MEASUREMENT_CONTRACT
        if diagnostic
        else evaluator.LADDER_MEASUREMENT_CONTRACT
    )
    work_core = (
        {
            "requested": True,
            "diagnostic": True,
            "valid": True,
            "errors": [],
            "diagnostic_code": evaluator.DIAGNOSTIC_CODE,
            "core": {
                "diagnostic_code": evaluator.DIAGNOSTIC_CODE,
                "ea_id": f"QM5_{ea_id}",
                "symbol": symbol,
                "period": "D1",
            },
        }
        if diagnostic
        else {
            "requested": True,
            "valid": True,
            "errors": [],
            "rung": rung,
            "core": {"ea_id": f"QM5_{ea_id}", "symbol": symbol},
        }
    )
    work_item = {
        "measurement_contract": measurement_contract if diagnostic else None,
        "diagnostic_code": evaluator.DIAGNOSTIC_CODE if diagnostic else None,
        "measurement_rung": None if diagnostic else rung,
        "measurement_sequence": None if diagnostic else {"R0": 0, "R1": 2}[rung],
        "evidence_run_id": None,
        "ea_id": f"QM5_{ea_id}",
        "symbol": symbol,
    }
    artifact_rows = [
        {
            "role": role,
            "path": value["path"],
            "expected_sha256": value["sha256"],
            "actual_sha256": value["sha256"],
            "valid": True,
        }
        for role, value in strategy_artifacts.items()
    ]
    return {
        "schema_version": 1,
        "mode": "apply",
        "worker_exit_code": 0,
        "success": True,
        "success_checks": {
            key: True
            for key in (
                EXPECTED_DIAGNOSTIC_SUCCESS_KEYS
                if diagnostic
                else EXPECTED_BASE_SUCCESS_KEYS
            )
        },
        "state": "completed",
        "terminal": "T10",
        "work_item_id": work_item_id,
        "completed_at_utc": "2026-07-30T01:00:00Z",
        "preflight": {
            "valid": True,
            "work_core": work_core,
            "work_item": work_item,
            "hold": diagnostic_hold if diagnostic else None,
            "source_binding": {
                "valid": True,
                "authoritative_source_commit": source_commit,
                "controller_head_commit": source_commit,
                "actual_head_commit": source_commit,
                "measurement_contract": measurement_contract if diagnostic else None,
                "framework_include_tree": {
                    "path": "C:/test/framework/include/QM",
                    "expected_sha256": INCLUDE_TREE_SHA256,
                    "actual_sha256": INCLUDE_TREE_SHA256,
                    "file_count": 12,
                },
            },
            "artifacts": artifact_rows,
            "payload_contract": {
                "requested": True,
                "valid": True,
                "errors": [],
                "pre_keys": ["measurement_contract"],
                "pre_key_value_sha256": {
                    "measurement_contract": evaluator.canonical_sha256(measurement_contract)
                },
            },
            "ladder_order": (
                {
                    "requested": True,
                    "diagnostic": True,
                    "valid": True,
                    "errors": [],
                    "rungs": [],
                    "no_ladder_progression": True,
                    "excluded_v2_r2": excluded_v2_r2,
                }
                if diagnostic
                else {"requested": True, "valid": True, "errors": []}
            ),
            "fidelity_receipt": (
                {
                    "requested": True,
                    "required": False,
                    "prohibited": True,
                    "valid": True,
                    "errors": [],
                }
                if diagnostic
                else {"requested": False, "required": False, "valid": True, "errors": []}
            ),
        },
        "payload_contract_revalidation": {"valid": True},
        "post_execution_inputs": {"valid": True},
        "post_runtime_sources": {"valid": True},
        "post_compile_binding": {"valid": True},
        "post_fidelity_receipt": {
            "requested": False,
            "required": False,
            "valid": True,
            "errors": [],
        },
        "process_tree_containment": {"valid": True},
        "post_run_quiescence": {"valid": True, "after": []},
        "post_work_item": {
            "id": work_item_id,
            "status": "done",
            "verdict": "PASS",
            "evidence_path": summary["path"],
        },
        "post_evidence": {
            "valid": True,
            "path": summary["path"],
            "sha256": summary["sha256"],
        },
        "post_run_stream": {
            "valid": True,
            "target": stream["path"],
            "harvested": {
                "sha256": stream["sha256"],
                "bytes": stream["bytes"],
                "lines": stream["lines"],
            },
        },
        "diagnostic_q08": (
            {
                "requested": True,
                "valid": True,
                "errors": [],
                "target": stream["path"],
                "target_sha256": stream["sha256"],
                "target_bytes": stream["bytes"],
                "target_lines": stream["lines"],
                "money_basis": evaluator.FULL_LIFECYCLE_MONEY_BASIS,
                "magic": 131080000,
                "symbol": symbol,
                "selected_trade_count": 1,
            }
            if diagnostic
            else {"requested": False, "valid": True, "errors": []}
        ),
        "diagnostic_isolation": (
            {
                "requested": True,
                "diagnostic": True,
                "valid": True,
                "errors": [],
                "rungs": [],
                "no_ladder_progression": True,
                "excluded_v2_r2": excluded_v2_r2,
                "pre_excluded_v2_r2": excluded_v2_r2,
            }
            if diagnostic
            else {"requested": False, "valid": True, "errors": []}
        ),
        "diagnostic_hold": (
            {
                "requested": True,
                "valid": True,
                "errors": [],
                "pre_hold": diagnostic_hold,
                "post_hold": diagnostic_hold,
            }
            if diagnostic
            else {"requested": False, "valid": True, "errors": []}
        ),
    }


def _manifest_fixture(tmp_path: Path, now: dt.datetime) -> tuple[dict[str, object], Path]:
    rulepack = _write_json(tmp_path / "rulepack.json", _rulepack())
    cost = _write_json(tmp_path / "cost.json", _cost_snapshot(now))
    qualification = _write_json(
        tmp_path / "qualification.json",
        {
            "schema": "qm.ftmo-book3-strict-qualification-assessment/v1",
            "as_of_utc": "2026-07-30T01:00:00Z",
            "book_id": evaluator.BOOK_ID,
            "status": "UNVERIFIED",
            "authority": "RESEARCH_INPUT_ONLY",
            "partial_book_approval": False,
            "candidates": [
                {
                    "ea_id": ea_id,
                    "symbol": symbol,
                    "challenge_ready": False,
                    "state": "TARGET_ELIGIBLE_WITH_EVIDENCE_DEBT",
                    "q08_verdict": "FAIL_SOFT",
                    "blockers": ["q08_not_strict_pass"],
                }
                for ea_id, symbol, _provider in evaluator.EXPECTED_BOOK.values()
            ],
            "global_blockers": ["authenticated_strict_qualification_missing"],
            "authorization": {
                "money_gate_authorized": False,
                "deployment_allowed": False,
                "factory_action_authorized": False,
                "paid_challenge_purchase_authorized": False,
            },
        },
    )
    sleeves = []
    for rung, (ea_id, symbol, provider) in evaluator.EXPECTED_BOOK.items():
        report = _write(tmp_path / f"{rung}_report.htm", f"<html>{rung}</html>\n")
        summary = _write_json(
            tmp_path / f"{rung}_summary.json",
            {
                "runs": [
                    {
                        "run": 1,
                        "status": "OK",
                        "total_trades": 1,
                        "report_canonical_path": report["path"],
                        "report_sha256": report["sha256"],
                        "report_size_bytes": report["bytes"],
                    }
                ]
            },
        )
        stream = _write(tmp_path / f"{rung}_stream.jsonl", "{}\n")
        m15 = _write(tmp_path / f"{rung}_M15.csv", "time,open,high,low,close\n")
        strategy_artifacts = {
            "setfile": _write(tmp_path / f"{rung}.set", f"risk=1000\nslot={rung}\n"),
            "staged_ex5": _write(tmp_path / f"{rung}.ex5", f"ex5-{rung}\n"),
            "mq5": _write(tmp_path / f"QM5_{ea_id}.mq5", f"// source {ea_id}\n"),
        }
        work_item_id = f"work-{rung.lower()}"
        source_commit = (
            EVALUATOR_SOURCE_COMMIT
            if rung == "R2"
            else evaluator.R0_R1_AUTHORITATIVE_SOURCE_COMMIT
        )
        receipt_doc = _receipt(
            rung=rung,
            ea_id=ea_id,
            symbol=symbol,
            work_item_id=work_item_id,
            summary=summary,
            stream=stream,
            source_commit=source_commit,
            strategy_artifacts=strategy_artifacts,
        )
        receipt = _write_json(tmp_path / f"{rung}_receipt.json", receipt_doc)
        sleeves.append(
            {
                "rung": rung,
                "ea_id": ea_id,
                "symbol": symbol,
                "provider_symbol": provider,
                "work_item_id": work_item_id,
                "source_commit": source_commit,
                "base_risk_fixed": 1000,
                "receipt": receipt,
                "summary": summary,
                "stream": stream,
                "m15": m15,
                "report": report,
            }
        )
    staging_root = tmp_path / "staging"
    staging_root.mkdir()
    manifest: dict[str, object] = {
        "schema": evaluator.MANIFEST_SCHEMA,
        "book_id": evaluator.BOOK_ID,
        "source_commit": EVALUATOR_SOURCE_COMMIT,
        "staging_root": str(staging_root.resolve()),
        "evaluator_source": _evaluator_source_binding(),
        "evidence_vintage": "FTMO_BOOK3_STANDALONE_TEST_V1",
        "r2_purpose": "FRESH_STANDALONE_DIAGNOSTIC_ONLY",
        "timestamp_basis": "unix_utc",
        "cost_snapshot_max_age_days": 7,
        "cost_snapshot": cost,
        "rulepack": rulepack,
        "qualification": qualification,
        "sleeves": sleeves,
        "evaluation": {
            "split_date": "2024-01-13",
            "bootstrap": {
                "runs_per_seed": 2,
                "block_days": 2,
                "minimum_path_days": 8,
                "seeds": [3, 7],
            },
        },
    }
    path = tmp_path / "manifest.json"
    _write_json(path, manifest)
    return manifest, path


def test_phase_uses_strict_boundaries_and_requires_flat_target() -> None:
    sequence = [
        _day(0, realized=2500.0, low=-5000.0),
        _day(1, realized=2500.0),
        _day(2, realized=2500.0),
        _day(3, realized=2500.0, flat_end=False),
        _day(4, realized=0.0),
        _day(5, realized=0.01),
    ]

    result = evaluator.evaluate_phase(
        sequence,
        start_index=0,
        target_balance=evaluator.PHASE1_TARGET,
    )

    assert result["outcome"] == "passed"
    assert result["end_index"] == 5
    assert result["balance"] == pytest.approx(110000.01)


def test_phase_breaches_only_when_strictly_below_daily_floor() -> None:
    equal = evaluator.evaluate_phase(
        [_day(0, low=-5000.0, opens=0)],
        start_index=0,
        target_balance=evaluator.PHASE1_TARGET,
    )
    below = evaluator.evaluate_phase(
        [_day(0, low=-5000.01, opens=0)],
        start_index=0,
        target_balance=evaluator.PHASE1_TARGET,
    )

    assert equal["outcome"] == "right_censored"
    assert below["outcome"] == "daily_loss_breach"


def test_two_phase_continues_same_path_after_fresh_balance_reset() -> None:
    sequence = [
        *[_day(index, realized=2500.01) for index in range(4)],
        *[_day(index, realized=1250.01) for index in range(4, 8)],
    ]

    result = evaluator.evaluate_two_phase_path(sequence, start_index=0)

    assert result["outcome"] == "passed"
    assert result["phase1"]["end_index"] == 3
    assert result["phase2"]["start_index"] == 4
    assert result["phase2"]["balance"] == pytest.approx(105000.04)


def test_internal_capture_buffer_and_phase2_risk_multiplier_are_enforced() -> None:
    barely_official = [_day(index, realized=2500.01) for index in range(4)]
    official = evaluator.evaluate_phase(
        barely_official,
        start_index=0,
        target_balance=evaluator.PHASE1_TARGET,
    )
    buffered = evaluator.evaluate_phase(
        barely_official,
        start_index=0,
        target_balance=evaluator.PHASE1_TARGET,
        capture_balance=evaluator.PHASE1_CAPTURE_BALANCE,
    )
    assert official["outcome"] == "passed"
    assert buffered["outcome"] == "right_censored"

    verification = [_day(index, realized=1300.0) for index in range(4)]
    raw = evaluator.evaluate_phase(
        verification,
        start_index=0,
        target_balance=evaluator.PHASE2_TARGET,
    )
    reduced = evaluator.evaluate_phase(
        verification,
        start_index=0,
        target_balance=evaluator.PHASE2_TARGET,
        risk_multiplier=evaluator.PHASE2_RISK_MULTIPLIER,
    )
    assert raw["outcome"] == "passed"
    assert reduced["outcome"] == "right_censored"
    assert reduced["balance"] == pytest.approx(103900.0)


def test_bootstrap_preserves_joint_vector_and_phase_sequence() -> None:
    source = [
        _day(index, realized=3000.0 if index % 2 == 0 else 1000.0)
        for index in range(12)
    ]

    result = evaluator.block_bootstrap(
        source,
        runs=3,
        block_days=2,
        minimum_path_days=10,
        seeds=[5],
    )

    assert result["phase_dependence_preserved"] is True
    assert result["sleeves_bootstrapped_independently"] is False
    assert result["no_deadline_claim"] is False
    assert result["phase1"]["starts"] == 3
    assert result["two_phase"]["starts"] == 3


def test_bootstrap_rebases_reused_source_dates_to_synthetic_calendar() -> None:
    source = [_day(9), _day(2), _day(9)]

    rebased = evaluator._synthetic_bootstrap_calendar(source)

    assert [row.day for row in rebased] == [
        dt.date(2000, 1, 1),
        dt.date(2000, 1, 2),
        dt.date(2000, 1, 3),
    ]
    assert [row.realized for row in rebased] == [row.realized for row in source]


def test_historical_start_set_excludes_duplicate_idle_calendar_starts() -> None:
    source = [
        *[_day(index, opens=0) for index in range(3)],
        *[_day(index, opens=1) for index in range(3, 7)],
    ]

    result = evaluator.historical_first_passage(source, label="TEST")

    assert result["eligible_flat_trade_open_starts"] == 4
    assert result["phase1"]["starts"] == 4


def test_evaluate_manifest_keeps_qualification_no_go_separate(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )
    daily = [_day(index, realized=3000.0) for index in range(24)]
    monkeypatch.setattr(
        evaluator,
        "_build_joint_daily_model",
        lambda cases, timestamp_basis: (
            daily,
            {"basis": "test_joint_m15", "calendar_days": len(daily)},
            {"basis": "test", "pairs": []},
        ),
    )

    receipt = evaluator.evaluate_manifest(
        manifest,
        manifest_path=manifest_path,
        now_utc=now,
    )

    assert receipt["status"] == "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED"
    assert receipt["readiness"]["native_stream_reconciliation"] == "PASS"
    assert receipt["readiness"]["strict_qualification"] == "UNVERIFIED"
    assert receipt["readiness"]["money_gate"] == "SETUP_DATA_MISSING"
    assert receipt["authorization"]["paid_challenge_purchase_authorized"] is False
    assert (
        receipt["historical_first_passage"]["official_rule_ceiling_1x"]["out_of_sample"][
            "time_limit"
        ]
        is None
    )
    assert (
        receipt["block_bootstrap"]["internal_policy_eod_surrogate"][
            "phase_dependence_preserved"
        ]
        is True
    )
    assert receipt["bindings"]["sleeves"][2]["rung"] == "R2"
    assert receipt["bindings"]["runner_receipts"][2]["measurement_role"] == (
        "STANDALONE_DIAGNOSTIC"
    )
    assert (
        receipt["bindings"]["runner_receipts"][0][
            "source_binding_measurement_contract_observed"
        ]
        is None
    )
    assert receipt["bindings"]["qualification"]["ready_state_permitted"] is False
    assert (
        receipt["historical_first_passage"]["holdout_contract"]["gate_eligible"]
        is False
    )
    bootstrap = receipt["block_bootstrap"]["official_rule_ceiling_1x"]
    assert bootstrap["gate_eligible"] is False
    assert "conditional_phase2_pass_given_phase1_pass" in bootstrap
    assert "mc_wilson_95_percent" in bootstrap["any_official_breach"]
    assert receipt["bindings"]["sleeves"][0]["report"]["staged"]["sha256"]
    assert receipt["staging_snapshot"]["semantic_inputs"] == (
        "CREATE_ONLY_CONTENT_ADDRESSED_STAGING_ONLY"
    )


def test_output_relevant_source_closure_is_complete() -> None:
    assert {
        "standalone_evaluator",
        "joint_m15_account_model",
        "native_stream_reconciliation",
        "report_cost_reconciliation",
        "intraday_candidate_screen",
        "phase1_mae",
        "prop_challenge_optimizer",
        "commission",
        "portfolio_common",
        "prop_challenge_sim",
        "portfolio_package",
    } == set(evaluator.EVALUATOR_SOURCE_PATHS)


def test_content_staging_rejects_change_read_restore(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    original = b'{"value":"ORIGINAL"}\n'
    source.write_bytes(original)
    destination = tmp_path / "staged.json"
    source.write_bytes(b'{"value":"TAMPERED"}\n')
    try:
        with pytest.raises(
            evaluator.StandaloneEvaluationError, match="staged_content_mismatch"
        ):
            evaluator._copy_verified_file(
                source,
                destination,
                expected_sha256=evaluator.hashlib.sha256(original).hexdigest(),
                expected_bytes=len(original),
                label="aba",
            )
    finally:
        source.write_bytes(original)
    assert source.read_bytes() == original


def _stager(tmp_path: Path, name: str) -> evaluator.ContentAddressedStager:
    root = tmp_path / name
    root.mkdir()
    manifest_bytes = f'{{"case":"{name}"}}\n'.encode()
    return evaluator.ContentAddressedStager(
        root,
        evaluator.hashlib.sha256(manifest_bytes).hexdigest(),
        manifest_bytes,
    )


def test_content_stager_rejects_same_path_and_hardlink_alias(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    source.write_text('{"value":1}\n', encoding="utf-8")
    pin = evaluator._pinned_spec(
        {"path": str(source.resolve()), "sha256": evaluator.sha256_file(source)},
        "source",
    )[1]
    stager = _stager(tmp_path, "same-path")
    stager.stage(source, pin, "first")
    with pytest.raises(evaluator.StandaloneEvaluationError, match="artifact_path_reused"):
        stager.stage(source, pin, "second")

    alias = tmp_path / "alias.json"
    os.link(source, alias)
    alias_pin = evaluator._pinned_spec(
        {"path": str(alias.resolve()), "sha256": evaluator.sha256_file(alias)},
        "alias",
    )[1]
    hardlink_stager = _stager(tmp_path, "hardlink")
    hardlink_stager.stage(source, pin, "source")
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="original_file_identity_reused"
    ):
        hardlink_stager.stage(alias, alias_pin, "alias")


def test_content_stager_allows_distinct_same_content_files(tmp_path: Path) -> None:
    first = tmp_path / "first.json"
    second = tmp_path / "second.json"
    first.write_text('{"value":1}\n', encoding="utf-8")
    second.write_bytes(first.read_bytes())
    stager = _stager(tmp_path, "distinct")
    for index, source in enumerate((first, second), 1):
        pin = evaluator._pinned_spec(
            {"path": str(source.resolve()), "sha256": evaluator.sha256_file(source)},
            f"source-{index}",
        )[1]
        stager.stage(source, pin, f"source-{index}")


def test_native_report_sha_drift_is_refused(tmp_path: Path) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    first = manifest["sleeves"][0]  # type: ignore[index]
    Path(first["report"]["path"]).write_text("tampered report\n", encoding="utf-8")  # type: ignore[index]

    with pytest.raises(evaluator.StandaloneEvaluationError, match="R0:report:sha256_mismatch"):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


def test_sha_drift_refuses_before_reconciliation(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    first = manifest["sleeves"][0]  # type: ignore[index]
    Path(first["m15"]["path"]).write_text("drift\n", encoding="utf-8")  # type: ignore[index]
    called = False

    def reconcile(*args: object, **kwargs: object) -> dict[str, object]:
        nonlocal called
        called = True
        return {"status": "PASS", "reasons": []}

    monkeypatch.setattr(evaluator, "reconcile_case", reconcile)

    with pytest.raises(evaluator.StandaloneEvaluationError, match="R0:m15:sha256_mismatch"):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)
    assert called is False


def test_sha_drift_during_model_is_refused_before_receipt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )
    first = manifest["sleeves"][0]  # type: ignore[index]

    def mutating_model(*args: object, **kwargs: object) -> tuple[object, object, object]:
        Path(first["m15"]["path"]).write_text("changed-during-model\n", encoding="utf-8")  # type: ignore[index]
        daily = [_day(index, realized=1.0) for index in range(24)]
        return daily, {"basis": "test"}, {"basis": "test", "pairs": []}

    monkeypatch.setattr(evaluator, "_build_joint_daily_model", mutating_model)

    with pytest.raises(
        evaluator.StandaloneEvaluationError,
        match="R0:m15:sha256_changed_during_evaluation",
    ):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


def test_r2_receipt_rejects_v2_rung_field_even_when_rehashed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    r2 = manifest["sleeves"][2]  # type: ignore[index]
    receipt_path = Path(r2["receipt"]["path"])  # type: ignore[index]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["preflight"]["work_core"]["rung"] = "R2"
    r2["receipt"] = _write_json(receipt_path, receipt)  # type: ignore[index]
    _write_json(manifest_path, manifest)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )

    with pytest.raises(
        evaluator.StandaloneEvaluationError,
        match="diagnostic_work_core_mismatch",
    ):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (lambda receipt: receipt.update(worker_exit_code=1), "envelope_contract_invalid"),
        (
            lambda receipt: receipt["post_fidelity_receipt"].update(requested=True),
            "diagnostic_post_fidelity_invalid",
        ),
        (
            lambda receipt: receipt["post_compile_binding"].update(valid=False),
            "post_compile_binding_invalid",
        ),
        (
            lambda receipt: receipt["diagnostic_q08"].update(target_lines=999),
            "diagnostic_q08_invalid",
        ),
        (
            lambda receipt: receipt["preflight"]["ladder_order"]["excluded_v2_r2"][
                "row"
            ].update(status="done"),
            "excluded_v2_r2_row_hash_invalid",
        ),
    ],
)
def test_r2_receipt_exact_contract_rejects_substitution(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutate: object,
    message: str,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    r2 = manifest["sleeves"][2]  # type: ignore[index]
    receipt_path = Path(r2["receipt"]["path"])  # type: ignore[index]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    mutate(receipt)  # type: ignore[operator]
    r2["receipt"] = _write_json(receipt_path, receipt)  # type: ignore[index]
    _write_json(manifest_path, manifest)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )

    with pytest.raises(evaluator.StandaloneEvaluationError, match=message):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


def test_receipt_success_key_contract_is_independent_literal() -> None:
    assert evaluator.BASE_SUCCESS_CHECK_KEYS == EXPECTED_BASE_SUCCESS_KEYS
    assert evaluator.DIAGNOSTIC_SUCCESS_CHECK_KEYS == EXPECTED_DIAGNOSTIC_SUCCESS_KEYS


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (
            lambda receipt: receipt["success_checks"].pop(
                "diagnostic_hold_unchanged"
            ),
            "success_checks_keyset_or_value_mismatch",
        ),
        (
            lambda receipt: receipt["success_checks"].update(extra_hold_check=True),
            "success_checks_keyset_or_value_mismatch",
        ),
        (
            lambda receipt: receipt["diagnostic_hold"]["post_hold"].update(active=0),
            "hold_state_invalid",
        ),
        (
            lambda receipt: receipt["diagnostic_hold"].update(unexpected=True),
            "diagnostic_hold_field_set_invalid",
        ),
    ],
)
def test_r2_receipt_rejects_diagnostic_hold_contract_drift(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutate: object,
    message: str,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    r2 = manifest["sleeves"][2]  # type: ignore[index]
    receipt_path = Path(r2["receipt"]["path"])  # type: ignore[index]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    mutate(receipt)  # type: ignore[operator]
    r2["receipt"] = _write_json(receipt_path, receipt)  # type: ignore[index]
    _write_json(manifest_path, manifest)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )
    with pytest.raises(evaluator.StandaloneEvaluationError, match=message):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


def test_runner_receipt_rejects_unknown_success_check_key(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    r0 = manifest["sleeves"][0]  # type: ignore[index]
    receipt_path = Path(r0["receipt"]["path"])  # type: ignore[index]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["success_checks"]["unexpected_check"] = True
    r0["receipt"] = _write_json(receipt_path, receipt)  # type: ignore[index]
    _write_json(manifest_path, manifest)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )

    with pytest.raises(
        evaluator.StandaloneEvaluationError,
        match="success_checks_keyset_or_value_mismatch",
    ):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


def test_historical_receipt_omission_requires_payload_contract_hash(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    manifest, manifest_path = _manifest_fixture(tmp_path, now)
    r0 = manifest["sleeves"][0]  # type: ignore[index]
    receipt_path = Path(r0["receipt"]["path"])  # type: ignore[index]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert receipt["preflight"]["work_item"]["measurement_contract"] is None
    assert receipt["preflight"]["source_binding"]["measurement_contract"] is None
    receipt["preflight"]["payload_contract"]["pre_key_value_sha256"][
        "measurement_contract"
    ] = "0" * 64
    r0["receipt"] = _write_json(receipt_path, receipt)  # type: ignore[index]
    _write_json(manifest_path, manifest)
    monkeypatch.setattr(
        evaluator,
        "reconcile_case",
        lambda *args, **kwargs: {"status": "PASS", "reasons": []},
    )

    with pytest.raises(
        evaluator.StandaloneEvaluationError,
        match="historical_payload_measurement_contract_unproven",
    ):
        evaluator.evaluate_manifest(manifest, manifest_path=manifest_path, now_utc=now)


def test_untrusted_qualification_cannot_claim_ready() -> None:
    document = {
        "schema": "qm.ftmo-book3-strict-qualification-assessment/v1",
        "as_of_utc": "2026-07-30T01:00:00Z",
        "book_id": evaluator.BOOK_ID,
        "status": "UNVERIFIED",
        "authority": "RESEARCH_INPUT_ONLY",
        "partial_book_approval": False,
        "candidates": [
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "challenge_ready": True,
                "state": "READY",
                "q08_verdict": "PASS",
                "blockers": ["none"],
            }
            for ea_id, symbol, _provider in evaluator.EXPECTED_BOOK.values()
        ],
        "global_blockers": ["still_unverified"],
        "authorization": {
            "money_gate_authorized": False,
            "deployment_allowed": False,
            "factory_action_authorized": False,
            "paid_challenge_purchase_authorized": False,
        },
    }

    with pytest.raises(evaluator.StandaloneEvaluationError, match="ready_claim_forbidden"):
        evaluator._qualification_status(document)


def test_qualification_rejects_contradictory_ready_string() -> None:
    document = {
        "schema": "qm.ftmo-book3-strict-qualification-assessment/v1",
        "as_of_utc": "2026-07-30T01:00:00Z",
        "book_id": evaluator.BOOK_ID,
        "status": "UNVERIFIED",
        "authority": "RESEARCH_INPUT_ONLY",
        "partial_book_approval": False,
        "candidates": [
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "challenge_ready": False,
                "state": "READY" if rung == "R0" else "BLOCKED",
                "q08_verdict": "FAIL_SOFT",
                "blockers": ["unverified"],
            }
            for rung, (ea_id, symbol, _provider) in evaluator.EXPECTED_BOOK.items()
        ],
        "global_blockers": ["still_unverified"],
        "authorization": {
            "money_gate_authorized": False,
            "deployment_allowed": False,
            "factory_action_authorized": False,
            "paid_challenge_purchase_authorized": False,
        },
    }

    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="contradictory_ready_string"
    ):
        evaluator._qualification_status(document)


def test_cost_and_qualification_authorization_keysets_are_exact() -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    for key, expected_value in evaluator.EXPECTED_COST_AUTHORIZATION.items():
        missing = _cost_snapshot(now)
        missing["authorization"].pop(key)  # type: ignore[union-attr]
        with pytest.raises(
            evaluator.StandaloneEvaluationError,
            match="authorization_not_research_only",
        ):
            evaluator._cost_rows(missing, now_utc=now, maximum_age_days=7)
        changed = _cost_snapshot(now)
        changed["authorization"][key] = (  # type: ignore[index]
            not expected_value
            if isinstance(expected_value, bool)
            else str(expected_value) + " MUTATED"
        )
        with pytest.raises(
            evaluator.StandaloneEvaluationError,
            match="authorization_not_research_only",
        ):
            evaluator._cost_rows(changed, now_utc=now, maximum_age_days=7)
    extra_cost = _cost_snapshot(now)
    extra_cost["authorization"]["unexpected_action_authorized"] = True  # type: ignore[index]
    with pytest.raises(
        evaluator.StandaloneEvaluationError,
        match="authorization_not_research_only",
    ):
        evaluator._cost_rows(extra_cost, now_utc=now, maximum_age_days=7)

    qualification = {
        "schema": "qm.ftmo-book3-strict-qualification-assessment/v1",
        "as_of_utc": "2026-07-30T01:00:00Z",
        "book_id": evaluator.BOOK_ID,
        "status": "UNVERIFIED",
        "authority": "RESEARCH_INPUT_ONLY",
        "partial_book_approval": False,
        "candidates": [
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "challenge_ready": False,
                "state": "TARGET_ELIGIBLE_WITH_EVIDENCE_DEBT",
                "q08_verdict": "FAIL_SOFT",
                "blockers": ["q08_not_strict_pass"],
            }
            for ea_id, symbol, _provider in evaluator.EXPECTED_BOOK.values()
        ],
        "global_blockers": ["authenticated_strict_qualification_missing"],
        "authorization": dict(evaluator.EXPECTED_QUALIFICATION_AUTHORIZATION),
    }
    assert evaluator._qualification_status(qualification)["status"] == "UNVERIFIED"
    for key, expected_value in evaluator.EXPECTED_QUALIFICATION_AUTHORIZATION.items():
        missing = json.loads(json.dumps(qualification))
        missing["authorization"].pop(key)
        with pytest.raises(
            evaluator.StandaloneEvaluationError,
            match="authorization_not_fail_closed",
        ):
            evaluator._qualification_status(missing)
        changed = json.loads(json.dumps(qualification))
        changed["authorization"][key] = not expected_value
        with pytest.raises(
            evaluator.StandaloneEvaluationError,
            match="authorization_not_fail_closed",
        ):
            evaluator._qualification_status(changed)
    extra_qualification = json.loads(json.dumps(qualification))
    extra_qualification["authorization"]["unexpected_action_authorized"] = True
    with pytest.raises(
        evaluator.StandaloneEvaluationError,
        match="authorization_not_fail_closed",
    ):
        evaluator._qualification_status(extra_qualification)


@pytest.mark.parametrize(
    ("payload", "message"),
    [
        ('{"key":1,"key":2}', "duplicate_key:key"),
        ('{"value":NaN}', "nonfinite_json_constant:NaN"),
        ('{"value":Infinity}', "nonfinite_json_constant:Infinity"),
        ('{"value":1e999}', "nonfinite_json_number"),
    ],
)
def test_json_loader_rejects_duplicate_keys_and_nonfinite_constants(
    tmp_path: Path,
    payload: str,
    message: str,
) -> None:
    path = tmp_path / "invalid.json"
    path.write_text(payload, encoding="utf-8")

    with pytest.raises(evaluator.StandaloneEvaluationError, match=message):
        evaluator._load_json(path, "strict")


def test_evaluator_source_binding_refuses_dirty_controller_scope(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    binding = _evaluator_source_binding()
    monkeypatch.setattr(
        evaluator,
        "_git_source_state",
        lambda repo_root, paths: {
            "head": EVALUATOR_SOURCE_COMMIT,
            "dirty": [" M tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py"],
        },
    )

    with pytest.raises(evaluator.StandaloneEvaluationError, match="source_scope_dirty"):
        evaluator._validate_evaluator_source(
            binding,
            source_commit=EVALUATOR_SOURCE_COMMIT,
        )


def test_prepare_manifest_cli_is_deterministic_and_create_only(tmp_path: Path) -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    source_manifest, _source_path = _manifest_fixture(tmp_path, now)
    output = tmp_path / "prepared_manifest.json"
    args = [
        "--prepare-manifest",
        str(output),
        "--source-commit",
        EVALUATOR_SOURCE_COMMIT,
        "--evidence-vintage",
        "FTMO_BOOK3_STANDALONE_TEST_V1",
        "--cost-snapshot",
        source_manifest["cost_snapshot"]["path"],  # type: ignore[index]
        "--rulepack",
        source_manifest["rulepack"]["path"],  # type: ignore[index]
        "--qualification",
        source_manifest["qualification"]["path"],  # type: ignore[index]
        "--staging-root",
        source_manifest["staging_root"],  # type: ignore[index]
        "--timestamp-basis",
        "unix_utc",
        "--cost-snapshot-max-age-days",
        "7",
        "--split-date",
        "2024-01-13",
        "--bootstrap-runs-per-seed",
        "2",
        "--bootstrap-block-days",
        "2",
        "--bootstrap-minimum-path-days",
        "8",
        "--bootstrap-seeds",
        "3",
        "7",
    ]
    for sleeve in source_manifest["sleeves"]:  # type: ignore[index]
        rung = sleeve["rung"].lower()
        args.extend(
            [
                f"--{rung}-work-item-id",
                sleeve["work_item_id"],
                f"--{rung}-source-commit",
                sleeve["source_commit"],
                f"--{rung}-receipt",
                sleeve["receipt"]["path"],
                f"--{rung}-summary",
                sleeve["summary"]["path"],
                f"--{rung}-stream",
                sleeve["stream"]["path"],
                f"--{rung}-m15",
                sleeve["m15"]["path"],
                f"--{rung}-report",
                sleeve["report"]["path"],
            ]
        )

    assert evaluator.main(args) == 0
    first = output.read_bytes()
    prepared = evaluator._load_json(output, "prepared")
    assert prepared["schema"] == evaluator.MANIFEST_SCHEMA
    assert prepared["r2_purpose"] == "FRESH_STANDALONE_DIAGNOSTIC_ONLY"
    assert prepared["evaluator_source"]["source_commit"] == EVALUATOR_SOURCE_COMMIT
    assert evaluator.main(args) == 2
    assert output.read_bytes() == first


def test_create_only_receipt_refuses_overwrite(tmp_path: Path) -> None:
    target = tmp_path / "receipt.json"
    evaluator.write_create_only_receipt(target, {"schema": "test", "status": "NO_GO"})
    original = target.read_bytes()

    with pytest.raises(evaluator.CreateOnlyReceiptError):
        evaluator.write_create_only_receipt(target, {"schema": "replacement"})

    assert target.read_bytes() == original


def test_rulepack_semantics_reject_legacy_inclusive_operator() -> None:
    rulepack = _rulepack()
    rules = rulepack["official_rules"]
    assert isinstance(rules, list)
    daily = next(row for row in rules if row["rule_id"] == "ftmo_2s_max_daily_loss")
    daily["parameters"]["breach_operator"] = "AT_OR_BELOW_LIMIT"

    with pytest.raises(evaluator.StandaloneEvaluationError, match="unsupported_rule_semantics"):
        evaluator._official_rules(rulepack)


def test_rulepack_rejects_duplicate_ids_and_semantic_substitution() -> None:
    duplicate = _rulepack()
    rows = duplicate["official_rules"]
    assert isinstance(rows, list)
    rows.append(dict(rows[0]))
    with pytest.raises(evaluator.StandaloneEvaluationError, match="duplicate_rule_id"):
        evaluator._official_rules(duplicate)

    substituted = _rulepack()
    rows = substituted["official_rules"]
    assert isinstance(rows, list)
    maximum = next(row for row in rows if row["rule_id"] == "ftmo_2s_maximum_loss")
    maximum["parameters"]["model"] = "TRAILING"
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="unsupported_rule_semantics"
    ):
        evaluator._official_rules(substituted)


def _mutated_semantic_value(value: object) -> object:
    if isinstance(value, bool):
        return not value
    if value is None:
        return 1
    if isinstance(value, int):
        return value + 1
    if isinstance(value, float):
        return value + 0.5
    if isinstance(value, str):
        return value + "_MUTATED"
    if isinstance(value, list):
        return [*value, "MUTATED"]
    if isinstance(value, dict):
        return {**value, "unexpected": 1}
    raise AssertionError(f"unsupported fixture value {value!r}")


def test_every_official_rule_semantic_field_is_fail_closed() -> None:
    for rule_id, expected in evaluator.EXPECTED_OFFICIAL_RULE_SEMANTICS.items():
        for field in ("category", "scope", "source_ids"):
            rulepack = _rulepack()
            row = next(
                value
                for value in rulepack["official_rules"]  # type: ignore[index]
                if value["rule_id"] == rule_id
            )
            row[field] = _mutated_semantic_value(expected[field])
            with pytest.raises(
                evaluator.StandaloneEvaluationError,
                match="unsupported_rule_semantics",
            ):
                evaluator._official_rules(rulepack)
        for parameter, value in expected["parameters"].items():
            rulepack = _rulepack()
            row = next(
                item
                for item in rulepack["official_rules"]  # type: ignore[index]
                if item["rule_id"] == rule_id
            )
            row["parameters"][parameter] = _mutated_semantic_value(value)
            with pytest.raises(
                evaluator.StandaloneEvaluationError,
                match="unsupported_rule_semantics",
            ):
                evaluator._official_rules(rulepack)


def test_internal_guardrail_set_fields_and_duplicates_are_fail_closed() -> None:
    for guardrail_id, expected in evaluator.EXPECTED_INTERNAL_GUARDRAIL_SEMANTICS.items():
        for field in ("scope",):
            rulepack = _rulepack()
            row = next(
                value
                for value in rulepack["internal_guardrails"]  # type: ignore[index]
                if value["guardrail_id"] == guardrail_id
            )
            row[field] = _mutated_semantic_value(expected[field])
            with pytest.raises(
                evaluator.StandaloneEvaluationError,
                match="unsupported_guardrail_semantics",
            ):
                evaluator._internal_policy(rulepack)
        for parameter, value in expected["parameters"].items():
            rulepack = _rulepack()
            row = next(
                item
                for item in rulepack["internal_guardrails"]  # type: ignore[index]
                if item["guardrail_id"] == guardrail_id
            )
            row["parameters"][parameter] = _mutated_semantic_value(value)
            with pytest.raises(
                evaluator.StandaloneEvaluationError,
                match="unsupported_guardrail_semantics",
            ):
                evaluator._internal_policy(rulepack)

    duplicate = _rulepack()
    duplicate["internal_guardrails"].append(  # type: ignore[union-attr]
        dict(duplicate["internal_guardrails"][0])  # type: ignore[index]
    )
    with pytest.raises(evaluator.StandaloneEvaluationError, match="duplicate_guardrail_id"):
        evaluator._internal_policy(duplicate)

    extra = _rulepack()
    extra["internal_guardrails"].append(  # type: ignore[union-attr]
        {
            "guardrail_id": "unexpected",
            "classification": "INTERNAL_QM_POLICY_NOT_PROVIDER_RULE",
            "status": "PROPOSED_FOR_CALIBRATION",
            "scope": [],
            "parameters": {},
        }
    )
    with pytest.raises(evaluator.StandaloneEvaluationError, match="guardrail_id_set_invalid"):
        evaluator._internal_policy(extra)


def test_official_source_snapshot_identity_and_claims_are_exact() -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    rulepack = _rulepack()
    snapshot = json.loads(
        (evaluator.REPO_ROOT / evaluator.OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH).read_text(
            encoding="utf-8"
        )
    )
    validated = evaluator._validate_official_rule_sources(
        rulepack, snapshot, now_utc=now
    )
    assert validated["source_ids"] == sorted(evaluator.EXPECTED_OFFICIAL_SOURCE_IDS)

    duplicate = _rulepack()
    duplicate["official_sources"].append(  # type: ignore[union-attr]
        dict(duplicate["official_sources"][0])  # type: ignore[index]
    )
    with pytest.raises(evaluator.StandaloneEvaluationError, match="duplicate_source_id"):
        evaluator._validate_official_rule_sources(duplicate, snapshot, now_utc=now)

    pointer_drift = _rulepack()
    pointer_drift["official_sources"][0]["snapshot_sha256"] = "0" * 64  # type: ignore[index]
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="official_source_binding_invalid"
    ):
        evaluator._validate_official_rule_sources(
            pointer_drift, snapshot, now_utc=now
        )

    claim_drift = json.loads(json.dumps(snapshot))
    claim_drift["normalized_claims"]["simultaneous_order_limit"] = 201
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="normalized_claims_invalid"
    ):
        evaluator._validate_official_rule_sources(rulepack, claim_drift, now_utc=now)


def test_rulepack_as_of_and_official_snapshot_freshness_are_fail_closed() -> None:
    as_of_drift = _rulepack()
    as_of_drift["as_of"] = "1900-01-01"
    with pytest.raises(evaluator.StandaloneEvaluationError, match="header_contract_invalid"):
        evaluator._official_rules(as_of_drift)

    rulepack = _rulepack()
    snapshot_path = evaluator.REPO_ROOT / evaluator.OFFICIAL_RULE_SNAPSHOT_RELATIVE_PATH
    snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
    stale = json.loads(json.dumps(snapshot))
    stale["retrieved_at_utc"] = "2026-07-22T00:00:00Z"
    with pytest.raises(evaluator.StandaloneEvaluationError, match="rule_snapshot:stale"):
        evaluator._validate_official_rule_sources(
            rulepack,
            stale,
            now_utc=dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC),
        )

    future = json.loads(json.dumps(snapshot))
    future["retrieved_at_utc"] = "2026-07-31T00:00:00Z"
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="rule_snapshot:future_timestamp"
    ):
        evaluator._validate_official_rule_sources(
            rulepack,
            future,
            now_utc=dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC),
        )


def test_evaluation_profile_and_deployment_six_audit_repros_fail_closed() -> None:
    duplicate_metric = _rulepack()
    duplicate_metric["evaluation_profile"]["metrics"].append(  # type: ignore[index]
        dict(duplicate_metric["evaluation_profile"]["metrics"][0])  # type: ignore[index]
    )
    with pytest.raises(evaluator.StandaloneEvaluationError, match="duplicate_metric_id"):
        evaluator._evaluation_and_deployment_contract(duplicate_metric)

    duplicate_criterion = _rulepack()
    duplicate_criterion["evaluation_profile"]["go_criteria"].append(  # type: ignore[index]
        dict(duplicate_criterion["evaluation_profile"]["go_criteria"][0])  # type: ignore[index]
    )
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="duplicate_criterion_id"
    ):
        evaluator._evaluation_and_deployment_contract(duplicate_criterion)

    deployment_open = _rulepack()
    deployment_open["deployment_boundary"]["factory_action_authorized"] = True  # type: ignore[index]
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="deployment_boundary_invalid"
    ):
        evaluator._evaluation_and_deployment_contract(deployment_open)

    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    joint_drifts = [
        ("USDJPY.DWX", "USD/JPY", "flat_round_trip_commission_per_lot", "commission", 6),
        ("XAUUSD.DWX", "XAU/USD", "commission_percent_per_side", "commission", 0.002),
        ("XTIUSD.DWX", "USOIL.cash", "target_contract_size", "contractSize", 200),
    ]
    for symbol, code, normalized_field, provider_field, value in joint_drifts:
        document = _cost_snapshot(now)
        normalized_row = next(
            row
            for row in document["book3_normalization"]  # type: ignore[index]
            if row["dwx_symbol"] == symbol
        )
        provider_row = next(
            row
            for row in document["selected_provider_rows"]  # type: ignore[index]
            if row["code"] == code
        )
        normalized_row[normalized_field] = value
        provider_row[provider_field] = value
        with pytest.raises(
            evaluator.StandaloneEvaluationError,
            match="absolute_cost_matrix_mismatch",
        ):
            evaluator._cost_rows(document, now_utc=now, maximum_age_days=7)


def test_every_evaluation_and_deployment_semantic_field_is_fail_closed() -> None:
    valid = evaluator._evaluation_and_deployment_contract(_rulepack())
    assert valid["metric_ids"] == sorted(evaluator.EXPECTED_METRIC_SEMANTICS)
    assert valid["go_criterion_ids"] == sorted(
        evaluator.EXPECTED_GO_CRITERION_SEMANTICS
    )

    objective = _rulepack()
    objective["evaluation_profile"]["objective"] += " MUTATED"  # type: ignore[index,operator]
    with pytest.raises(evaluator.StandaloneEvaluationError, match="objective_invalid"):
        evaluator._evaluation_and_deployment_contract(objective)

    for row_id, expected in evaluator.EXPECTED_METRIC_SEMANTICS.items():
        for field, value in expected.items():
            document = _rulepack()
            row = next(
                item
                for item in document["evaluation_profile"]["metrics"]  # type: ignore[index]
                if item["metric_id"] == row_id
            )
            row[field] = _mutated_semantic_value(value)
            with pytest.raises(
                evaluator.StandaloneEvaluationError, match="metric_semantics_invalid"
            ):
                evaluator._evaluation_and_deployment_contract(document)
        for parameter, value in expected["parameters"].items():
            document = _rulepack()
            row = next(
                item
                for item in document["evaluation_profile"]["metrics"]  # type: ignore[index]
                if item["metric_id"] == row_id
            )
            row["parameters"][parameter] = _mutated_semantic_value(value)
            with pytest.raises(
                evaluator.StandaloneEvaluationError, match="metric_semantics_invalid"
            ):
                evaluator._evaluation_and_deployment_contract(document)

    for row_id, expected in evaluator.EXPECTED_GO_CRITERION_SEMANTICS.items():
        for field, value in expected.items():
            document = _rulepack()
            row = next(
                item
                for item in document["evaluation_profile"]["go_criteria"]  # type: ignore[index]
                if item["criterion_id"] == row_id
            )
            row[field] = _mutated_semantic_value(value)
            with pytest.raises(
                evaluator.StandaloneEvaluationError,
                match="criterion_semantics_invalid",
            ):
                evaluator._evaluation_and_deployment_contract(document)
        for parameter, value in expected["parameters"].items():
            document = _rulepack()
            row = next(
                item
                for item in document["evaluation_profile"]["go_criteria"]  # type: ignore[index]
                if item["criterion_id"] == row_id
            )
            row["parameters"][parameter] = _mutated_semantic_value(value)
            with pytest.raises(
                evaluator.StandaloneEvaluationError,
                match="criterion_semantics_invalid",
            ):
                evaluator._evaluation_and_deployment_contract(document)

    for field, value in evaluator.EXPECTED_DEPLOYMENT_BOUNDARY.items():
        document = _rulepack()
        document["deployment_boundary"][field] = _mutated_semantic_value(value)  # type: ignore[index]
        with pytest.raises(
            evaluator.StandaloneEvaluationError, match="deployment_boundary_invalid"
        ):
            evaluator._evaluation_and_deployment_contract(document)

    for collection, id_field, message in (
        ("metrics", "metric_id", "metric_id_set_invalid"),
        ("go_criteria", "criterion_id", "criterion_id_set_invalid"),
    ):
        missing = _rulepack()
        missing["evaluation_profile"][collection].pop()  # type: ignore[index]
        with pytest.raises(evaluator.StandaloneEvaluationError, match=message):
            evaluator._evaluation_and_deployment_contract(missing)
        extra = _rulepack()
        row = dict(extra["evaluation_profile"][collection][0])  # type: ignore[index]
        row[id_field] = "unexpected_id"
        extra["evaluation_profile"][collection].append(row)  # type: ignore[index]
        with pytest.raises(evaluator.StandaloneEvaluationError, match=message):
            evaluator._evaluation_and_deployment_contract(extra)


def test_every_absolute_cost_matrix_field_is_fail_closed() -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    for symbol, expected in evaluator.EXPECTED_COST_MATRIX.items():
        for field, value in expected.items():
            document = _cost_snapshot(now)
            row = next(
                item
                for item in document["book3_normalization"]  # type: ignore[index]
                if item["dwx_symbol"] == symbol
            )
            source_field = (
                "target_contract_size" if field == "contract_size" else field
            )
            row[source_field] = _mutated_semantic_value(value)
            with pytest.raises(evaluator.StandaloneEvaluationError):
                evaluator._cost_rows(document, now_utc=now, maximum_age_days=7)

    for code, expected in evaluator.EXPECTED_PROVIDER_COST_MATRIX.items():
        for field, value in expected.items():
            document = _cost_snapshot(now)
            row = next(
                item
                for item in document["selected_provider_rows"]  # type: ignore[index]
                if item["code"] == code
            )
            row[field] = _mutated_semantic_value(value)
            with pytest.raises(evaluator.StandaloneEvaluationError):
                evaluator._cost_rows(document, now_utc=now, maximum_age_days=7)

    response = _cost_snapshot(now)
    response["source"]["response_sha256"] = "0" * 64  # type: ignore[index]
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="unexpected_response_sha256"
    ):
        evaluator._cost_rows(response, now_utc=now, maximum_age_days=7)


def test_cost_snapshot_crosswalk_rejects_bool_and_provider_drift() -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)
    boolean_substitution = _cost_snapshot(now)
    normalization = boolean_substitution["book3_normalization"]
    assert isinstance(normalization, list)
    normalization[0]["commission_percent_per_side"] = False
    with pytest.raises(evaluator.StandaloneEvaluationError, match="not_json_number"):
        evaluator._cost_rows(boolean_substitution, now_utc=now, maximum_age_days=7)

    provider_drift = _cost_snapshot(now)
    providers = provider_drift["selected_provider_rows"]
    assert isinstance(providers, list)
    providers[0]["commission"] = 6
    with pytest.raises(
        evaluator.StandaloneEvaluationError, match="absolute_provider_matrix_mismatch"
    ):
        evaluator._cost_rows(provider_drift, now_utc=now, maximum_age_days=7)


def test_cost_snapshot_exact_currency_contract_and_dwxsizes_fail_closed() -> None:
    now = dt.datetime(2026, 7, 30, 1, 30, tzinfo=dt.UTC)

    def normalized(document: dict[str, object], symbol: str) -> dict[str, object]:
        return next(
            row
            for row in document["book3_normalization"]  # type: ignore[index]
            if row["dwx_symbol"] == symbol
        )

    def provider(document: dict[str, object], code: str) -> dict[str, object]:
        return next(
            row
            for row in document["selected_provider_rows"]  # type: ignore[index]
            if row["code"] == code
        )

    mutations = [
        lambda doc: provider(doc, "USD/JPY").update(profitCurrency="USD"),
        lambda doc: provider(doc, "XAU/USD").update(profitCurrency="JPY"),
        lambda doc: provider(doc, "USOIL.cash").update(assetClass="Forex"),
        lambda doc: normalized(doc, "USDJPY.DWX").update(
            derive_profit_currency_rate_from_pnl=False
        ),
        lambda doc: normalized(doc, "USDJPY.DWX").update(
            profit_currency_to_account_rate=1
        ),
        lambda doc: normalized(doc, "XAUUSD.DWX").update(
            derive_profit_currency_rate_from_pnl=True
        ),
        lambda doc: normalized(doc, "XTIUSD.DWX").update(source_contract_size=100),
        lambda doc: normalized(doc, "XAUUSD.DWX").update(target_contract_size=101),
        lambda doc: normalized(doc, "USDJPY.DWX").update(triple_weekday=3),
        lambda doc: provider(doc, "XAU/USD").update(commissionType="flat_USD"),
    ]
    for mutate in mutations:
        document = _cost_snapshot(now)
        mutate(document)
        with pytest.raises(evaluator.StandaloneEvaluationError):
            evaluator._cost_rows(document, now_utc=now, maximum_age_days=7)
