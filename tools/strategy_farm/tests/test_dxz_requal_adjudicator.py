from __future__ import annotations

import copy
import datetime as dt
import json
import os
import time
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_requal_adjudicator as subject
from tools.strategy_farm import dxz_as_live_requal as runner
from tools.strategy_farm.tests.test_dxz_cost_manifest_security import (
    _axis_payload,
    _write_bound_json,
)


HASH = "a" * 64


def _sign(payload: dict, field: str) -> dict:
    payload.pop(field, None)
    payload[field] = subject.canonical_json_sha(payload)
    return payload


def _contract(repo: Path, ea_id: int, slug: str, status: str = "ELIGIBLE") -> dict:
    source = repo / "framework" / "EAs" / f"QM5_{ea_id}_{slug}" / f"QM5_{ea_id}_{slug}.mq5"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(
        "input bool qm_friday_close_enabled = false;\n"
        "int OnInit(){\n"
        "  QM_FrameworkDeclareExecutionContract(PERIOD_H1, "
        'QM_FRIDAY_CLOSE_DISABLED, "CARD_DISABLED");\n'
        "  return 0;\n"
        "}\n"
        "void OnTick(){ if(QM_IsNewBar(_Symbol, PERIOD_H1)){} }\n",
        encoding="utf-8",
    )
    card = repo / "cards" / f"QM5_{ea_id}_{slug}.md"
    card.parent.mkdir(parents=True, exist_ok=True)
    card.write_text(f"# QM5_{ea_id}_{slug}\n", encoding="utf-8")
    reasons = [] if status == "ELIGIBLE" else [f"{status.lower()}_test_reason"]
    return {
        "ea_id": ea_id,
        "slug": slug,
        "card_ref": str(card.relative_to(repo)),
        "source": str(source.relative_to(repo)),
        "strategy_timeframe": "H1",
        "bar_gate_timeframe": "H1",
        "friday_close": {
            "enabled": False,
            "hour_broker": None,
            "mode": "DISABLED",
            "declaration": "CARD_DISABLED",
            "qualification_status": "PASS",
            "card_evidence": "test card",
        },
        "calendar": {"policy": "NONE"},
        "promotion": {"status": status, "block_reasons": reasons},
    }


def _sleeve(ea_id: int, slug: str, symbol: str, trades: int, risk: float) -> dict:
    return {
        "ea_id": ea_id,
        "symbol": symbol,
        "ea_label": f"QM5_{ea_id}_{slug}",
        "magic_number": ea_id * 10,
        "weight": risk,
        "risk_percent": risk,
        "trades": trades,
        "ex5_path": "stale/repo/path.ex5",
        "backtest_set": "stale/backtest/path.set",
    }


WINDOW = {
    "requested_from_date": "2017-01-01",
    "requested_to_date": "2025-12-31",
    "effective_from_date": "2017-01-01",
    "effective_to_date": "2025-12-31",
}


def _certified_cost_contract(
    tmp_path: Path, manifest_sha: str, sleeves: list[dict]
) -> tuple[dict, dict[str, dict]]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    identities = [
        {"ea_id": row["ea_id"], "symbol": row["symbol"], "timeframe": "H1"}
        for row in sleeves
    ]
    axes: dict[str, dict] = {}
    for axis in runner.EXECUTION_COST_AXES:
        artifact = tmp_path / f"cost_{axis}.json"
        payload = _axis_payload(axis, source_sha=manifest_sha, sleeves=identities)
        payload["evaluation_window"] = dict(WINDOW)
        payload["valid_from_utc"] = "2026-07-14T00:00:00+00:00"
        payload["valid_until_utc"] = "2026-07-18T00:00:00+00:00"
        _write_bound_json(artifact, payload, "artifact_payload_sha256")
        axes[axis] = {
            "status": "PASS",
            "evidence": {
                "path": artifact.name,
                "sha256": runner.sha256_file(artifact),
                "evidence_type": payload["evidence_type"],
            },
        }
    manifest_path = tmp_path / "execution_cost_manifest.json"
    manifest_payload = {
        "schema_version": 1,
        "artifact_type": runner.EXECUTION_COST_MANIFEST_TYPE,
        "status": "PASS",
        "source_manifest_sha256": manifest_sha,
        "valid_from_utc": "2026-07-01T00:00:00+00:00",
        "valid_until_utc": "2026-07-31T00:00:00+00:00",
        "scope": "GLOBAL",
        "covered_keys": [f"{row['ea_id']}:{row['symbol']}" for row in sleeves],
        "covered_sleeves": identities,
        "evaluation_window": dict(WINDOW),
        "axes": axes,
    }
    _write_bound_json(manifest_path, manifest_payload, "manifest_payload_sha256")
    metadata, contracts = runner.load_execution_cost_evidence_manifest(
        manifest_path,
        source_manifest_sha256=manifest_sha,
        as_of_utc=dt.datetime(2026, 7, 15, 12, tzinfo=dt.UTC),
        required_sleeves=identities,
        window_contract=WINDOW,
    )
    metadata["axis_hashes_start"] = runner.execution_cost_axis_hash_snapshot(metadata)
    return metadata, contracts


def _receipt(
    sleeve: dict,
    ordinal: int,
    cost_registry: Path,
    cost_metadata: dict,
    cost_contract: dict,
) -> dict:
    cost_axes = {
        axis: {
            "status": "PASS",
            "source": "IMMUTABLE_EXTERNAL_EXECUTION_COST_EVIDENCE",
            "assertion": row["assertion"],
            "methodology": row["methodology"],
            "parameters": dict(row["parameters"]),
            "scenarios": list(row["scenarios"]),
            "results": dict(row["results"]),
            "evidence": dict(row["evidence"]),
            "reasons": [],
        }
        for axis, row in cost_contract["axes"].items()
    }
    cost_axes["historical_tester_spread"]["native_report_evidence"] = {
        "native_report_sha256": "4" * 64,
        "history_quality": "100% real ticks",
        "bars": 100,
        "ticks": 1000,
        "symbol_count": 1,
        "real_ticks_certified": True,
    }
    preset_stage = {
        "status": "PASS",
        "blockers": [],
        "expected": {
            "ENV": "live",
            "RISK_FIXED": 0,
            "RISK_PERCENT": sleeve["risk_percent"],
            "PORTFOLIO_WEIGHT": 1,
        },
        "actual": {
            "ENV": "live",
            "RISK_FIXED": "0",
            "RISK_PERCENT": str(sleeve["risk_percent"]),
            "PORTFOLIO_WEIGHT": "1",
        },
        "checks": [],
        "preset_path": f"T_Live/{sleeve['ea_id']}.set",
        "preset_sha256": "2" * 64,
        "risk_contract": {
            "mode": "ABSOLUTE_SLEEVE_RISK_PERCENT",
            "required_portfolio_weight": 1,
        },
    }
    receipt = {
        "schema_version": 2,
        "status": "PASS",
        "technical_status": "PASS",
        "qualification_mode": "AS_LIVE_REQUAL",
        "qualification_status": "QUALIFIED",
        "deployment_eligible": False,
        "window_contract": dict(WINDOW),
        **WINDOW,
        "runner_sha256": "b" * 64,
        "artifact_source": "CANONICAL_T_LIVE",
        "execution_cost_evidence_manifest": cost_metadata,
        "blockers": [],
        "job": {
            "ordinal": ordinal,
            "ea_id": sleeve["ea_id"],
            "symbol": sleeve["symbol"],
            "ea_label": sleeve["ea_label"],
            "timeframe": "H1",
            "manifest_trades": sleeve["trades"],
        },
        "execution": {
            "sandbox": r"C:\QM\mt5\DXZ_Truth_1",
            "started_utc": "2026-07-15T00:00:00+00:00",
            "finished_utc": "2026-07-15T00:01:00+00:00",
            "exit_code": 0,
            "timed_out": False,
            "from_date": "2017.01.01",
            "to_date": "2025.12.31",
            **WINDOW,
            "currency": "EUR",
            "deposit": 100_000,
        },
        "identity": {
            "live_ex5_path": f"T_Live/{sleeve['ea_label']}.ex5",
            "live_ex5_sha256": "1" * 64,
            "live_ex5_sha256_before": "1" * 64,
            "staged_ex5_sha256": "1" * 64,
            "live_preset_path": f"T_Live/{sleeve['ea_id']}_{sleeve['symbol']}.set",
            "live_preset_sha256": "2" * 64,
            "live_preset_sha256_before": "2" * 64,
            "staged_preset_sha256": "2" * 64,
            "tester_ini_sha256": "3" * 64,
            "native_report_sha256": "4" * 64,
            "report_trade_stream_sha256": "5" * 64,
            "q08_stream_sha256": "6" * 64,
            "reference_stream_path": f"sealed/{sleeve['ea_id']}_{sleeve['symbol']}.jsonl",
            "reference_stream_sha256": "7" * 64,
            "reference_expected_sha256": "7" * 64,
            "reference_frozen_relative_path": (
                f"streams/{sleeve['ea_id']}_{sleeve['symbol'].replace('.', '_')}.jsonl"
            ),
        },
        "common_stream_capture": {
            "captured": True,
            "restored": True,
            "stream_sha256": "6" * 64,
        },
        "native_metrics": {"total_trades": sleeve["trades"]},
        "native_report_execution_evidence": {
            "history_quality": "100% real ticks",
            "bars": 100,
            "ticks": 1000,
            "symbol_count": 1,
            "real_ticks_certified": True,
            "errors": [],
        },
        "live_preset_contract": {
            "before": dict(preset_stage),
            "staged": {**preset_stage, "preset_path": f"sandbox/{sleeve['ea_id']}.set"},
            "after": dict(preset_stage),
            "unchanged": True,
        },
        "cost_evidence": {
            "status": "CERTIFIED",
            "cost_certified": True,
            "reasons": [],
            "required_axes": list(runner.EXECUTION_COST_AXES),
            "axes": cost_axes,
            "execution_cost_evidence_manifest": cost_metadata,
            "registry_path": str(cost_registry),
            "registry_sha256": subject.sha256_file(cost_registry),
            "unknown_symbols": [],
            "degraded_symbols": [],
        },
        "cost_certified": True,
        "observed_trade_stats": {"trades": sleeve["trades"], "net": 123.0},
        "reference_trade_stats": {"trades": sleeve["trades"], "net": 120.0},
        "manifest_count_match": True,
        "reference_close_sequence_match": True,
        "q08_reference_signal_identity_match": True,
        "q08_reference_outcome_sign_match": True,
        "parse_error": None,
    }
    return _sign(receipt, "receipt_sha256")


def _case(tmp_path: Path, statuses: tuple[str, str] = ("ELIGIBLE", "ELIGIBLE")):
    repo = tmp_path / "repo"
    cost_registry = tmp_path / "cost_registry.json"
    cost_registry.write_text('{"certified":true}\n', encoding="utf-8")
    sleeves = [
        _sleeve(1, "alpha", "EURUSD.DWX", 10, 0.25),
        _sleeve(2, "beta", "XAUUSD.DWX", 20, 0.5),
    ]
    manifest = {
        "book": "DXZ",
        "status": "DRAFT",
        "n_sleeves": 2,
        "total_risk_pct": 0.75,
        "kpis": {"sharpe": 99.0},
        "sleeves": sleeves,
    }
    manifest_sha = subject.canonical_json_sha(manifest)
    cost_metadata, cost_contracts = _certified_cost_contract(
        tmp_path, manifest_sha, sleeves
    )
    receipts = [
        _receipt(
            sleeve,
            index,
            cost_registry,
            cost_metadata,
            cost_contracts[f"{sleeve['ea_id']}:{sleeve['symbol']}"],
        )
        for index, sleeve in enumerate(sleeves, start=1)
    ]
    summary = {
        "schema_version": 2,
        "run_id": "test",
        "status": "PASS",
        "technical_status": "PASS",
        "qualification_mode": "AS_LIVE_REQUAL",
        "qualification_status": "QUALIFIED",
        "deployment_eligible": False,
        "window_contract": dict(WINDOW),
        **WINDOW,
        "runner_sha256": "b" * 64,
        "runner_sha256_start": "b" * 64,
        "runner_sha256_end": "b" * 64,
        "runner_unchanged": True,
        "live_root": str(subject.CANONICAL_LIVE_ROOT),
        "canonical_live_root": str(subject.CANONICAL_LIVE_ROOT),
        "canonical_live_root_pinned": True,
        "scope": "FULL",
        "counts": {"PASS": 2},
        "n_jobs": 2,
        "manifest_jobs": 2,
        "manifest_sha256": manifest_sha,
        "manifest_sha256_end": manifest_sha,
        "manifest_unchanged": True,
        "reference_snapshot": {
            "status": "PASS",
            "seal_verified": True,
            "errors": [],
            "source_manifest_sha256": manifest_sha,
            "manifest_sha256": "c" * 64,
            "seal_sha256": "d" * 64,
            "snapshot_root": "sealed/reference",
        },
        "reference_snapshot_end": {
            "status": "PASS",
            "seal_verified": True,
            "errors": [],
            "source_manifest_sha256": manifest_sha,
            "manifest_sha256": "c" * 64,
            "seal_sha256": "d" * 64,
            "snapshot_root": "sealed/reference",
        },
        "reference_snapshot_unchanged": True,
        "cost_evidence": {
            "status": "CERTIFIED",
            "cost_certified": True,
            "reasons": [],
            "required_axes": list(runner.EXECUTION_COST_AXES),
            "axes": {
                axis: {"status": "PASS", "pass_receipts": 2, "required_receipts": 2}
                for axis in runner.EXECUTION_COST_AXES
            },
            "execution_cost_evidence_manifest": cost_metadata,
            "registry_paths": [str(cost_registry)],
            "registry_sha256s": [subject.sha256_file(cost_registry)],
            "unknown_symbols": [],
            "degraded_symbols": [],
        },
        "cost_certified": True,
        "cost_registry": {
            "path": str(cost_registry),
            "sha256_start": subject.sha256_file(cost_registry),
            "sha256_end": subject.sha256_file(cost_registry),
            "unchanged": True,
        },
        "execution_cost_evidence_manifest": {
            **cost_metadata,
            "sha256_end": cost_metadata["sha256"],
            "axis_hashes_end": cost_metadata["axis_hashes_start"],
            "unchanged": True,
            "end_errors": [],
        },
        "receipts": receipts,
    }
    _sign(summary, "summary_sha256")
    registry = {
        "schema_version": 2,
        "book_id": "test",
        "contracts": [
            _contract(repo, 1, "alpha", statuses[0]),
            _contract(repo, 2, "beta", statuses[1]),
        ],
    }
    return repo, manifest, manifest_sha, summary, registry


def _refresh_cost_and_receipts(
    tmp_path: Path,
    manifest: dict,
    summary: dict,
    cost_registry: Path,
) -> str:
    manifest_sha = subject.canonical_json_sha(manifest)
    metadata, contracts = _certified_cost_contract(
        tmp_path / "refreshed_cost", manifest_sha, manifest["sleeves"]
    )
    summary["receipts"] = [
        _receipt(
            sleeve,
            ordinal,
            cost_registry,
            metadata,
            contracts[f"{sleeve['ea_id']}:{sleeve['symbol']}"],
        )
        for ordinal, sleeve in enumerate(manifest["sleeves"], start=1)
    ]
    summary["manifest_sha256"] = manifest_sha
    summary["manifest_sha256_end"] = manifest_sha
    summary["reference_snapshot"]["source_manifest_sha256"] = manifest_sha
    summary["reference_snapshot_end"]["source_manifest_sha256"] = manifest_sha
    summary["cost_evidence"].update(
        {
            "execution_cost_evidence_manifest": metadata,
            "axes": {
                axis: {
                    "status": "PASS",
                    "pass_receipts": len(summary["receipts"]),
                    "required_receipts": len(summary["receipts"]),
                }
                for axis in runner.EXECUTION_COST_AXES
            },
        }
    )
    summary["execution_cost_evidence_manifest"] = {
        **metadata,
        "sha256_end": metadata["sha256"],
        "axis_hashes_end": metadata["axis_hashes_start"],
        "unchanged": True,
        "end_errors": [],
    }
    _sign(summary, "summary_sha256")
    return manifest_sha


def _adjudicate(case):
    repo, manifest, manifest_sha, summary, registry = case
    return subject.adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256="8" * 64,
        registry_sha256="9" * 64,
        manifest_path="manifest.json",
        summary_path="summary.json",
        registry_path="contracts.json",
        repo_root=repo,
        as_of=dt.date(2026, 7, 15),
        generated_utc="2026-07-15T12:00:00+00:00",
    )


def _make_machine_requal_case(
    tmp_path: Path,
    *,
    extra_reasons: tuple[str, ...] = (),
    stale_binary: bool = False,
):
    case = list(_case(tmp_path, statuses=("REQUAL_REQUIRED", "ELIGIBLE")))
    repo, _manifest, _manifest_sha, summary, registry = case
    contract = registry["contracts"][0]
    contract["promotion"]["block_reasons"] = [
        "remediated_binary_not_requalified",
        *extra_reasons,
    ]
    source = repo / contract["source"]
    ex5 = source.with_suffix(".ex5")
    ex5.write_bytes(b"fresh-controlled-build")
    base = time.time() - 120
    if stale_binary:
        os.utime(ex5, (base, base))
        os.utime(source, (base + 60, base + 60))
    else:
        os.utime(source, (base, base))
        os.utime(ex5, (base + 60, base + 60))
    ex5_sha = subject.sha256_file(ex5)
    receipt = summary["receipts"][0]
    receipt["identity"]["live_ex5_sha256"] = ex5_sha
    receipt["identity"]["live_ex5_sha256_before"] = ex5_sha
    receipt["identity"]["staged_ex5_sha256"] = ex5_sha
    _sign(receipt, "receipt_sha256")
    _sign(summary, "summary_sha256")
    return tuple(case)


def test_complete_bound_case_keeps_every_sleeve_without_reusing_draft_kpis(tmp_path: Path) -> None:
    adjudication, candidate = _adjudicate(_case(tmp_path))

    assert adjudication["verdict"] == "PASS"
    assert adjudication["counts"] == {
        "KEEP": 2,
        "KEEP_CANDIDATE": 0,
        "REPAIR": 0,
        "BLOCK": 0,
    }
    assert candidate["status"] == "BOUND_CANDIDATE_COMPLETE"
    assert candidate["n_sleeves"] == 2
    assert candidate["total_risk_pct"] == 0.75
    assert candidate["kpis"] is None
    assert candidate["portfolio_recompute_required"] is True
    assert candidate["deployment_eligible"] is False
    assert "ex5_path" not in candidate["sleeves"][0]
    assert "set_file_expectation" not in candidate["sleeves"][0]
    bindings = candidate["sleeves"][0]["artifact_bindings"]
    assert bindings["qualified_ex5_sha256"] == "1" * 64
    assert bindings["mq5_sha256"]
    assert bindings["qualified_set_path"] == bindings["live_preset_path"]
    assert candidate["source_requalification"]["scope"] == "FULL"
    assert candidate["source_requalification"]["status"] == "PASS"
    assert candidate["source_adjudication"]["verdict"] == "PASS"


def test_discovery_mode_cannot_be_adjudicated_even_if_status_is_tampered_pass(
    tmp_path: Path,
) -> None:
    case = list(_case(tmp_path))
    summary = case[3]
    summary["qualification_mode"] = "DISCOVERY_RECONCILED"
    summary["qualification_status"] = "QUALIFIED"
    for receipt in summary["receipts"]:
        receipt["qualification_mode"] = "DISCOVERY_RECONCILED"
        receipt["qualification_status"] = "QUALIFIED"
        _sign(receipt, "receipt_sha256")
    _sign(summary, "summary_sha256")

    adjudication, candidate = _adjudicate(tuple(case))

    assert "SUMMARY_QUALIFICATION_MODE_NOT_AS_LIVE" in adjudication["global_blockers"]
    assert adjudication["verdict"] == "BLOCK"
    assert candidate["status"] == "NO_BOOK_CANDIDATE"
    assert candidate["deployment_eligible"] is False


def test_degraded_cost_evidence_blocks_candidate_even_with_pass_receipts(
    tmp_path: Path,
) -> None:
    case = list(_case(tmp_path))
    summary = case[3]
    summary["qualification_status"] = "COST_UNCERTIFIED"
    summary["cost_certified"] = False
    summary["cost_evidence"].update(
        {
            "status": "DEGRADED",
            "cost_certified": False,
            "degraded_symbols": ["EURUSD.DWX"],
        }
    )
    for receipt in summary["receipts"]:
        receipt["qualification_status"] = "COST_UNCERTIFIED"
        receipt["cost_certified"] = False
        receipt["cost_evidence"].update(
            {
                "status": "DEGRADED",
                "cost_certified": False,
                "degraded_symbols": [receipt["job"]["symbol"]],
            }
        )
        _sign(receipt, "receipt_sha256")
    _sign(summary, "summary_sha256")

    adjudication, candidate = _adjudicate(tuple(case))

    assert "SUMMARY_COST_EVIDENCE_NOT_CERTIFIED" in adjudication["global_blockers"]
    assert candidate["n_sleeves"] == 0
    assert candidate["deployment_eligible"] is False


def test_eligible_pass_is_kept_but_requal_contract_is_repair_and_excluded(tmp_path: Path) -> None:
    adjudication, candidate = _adjudicate(
        _case(tmp_path, statuses=("ELIGIBLE", "REQUAL_REQUIRED"))
    )

    assert adjudication["verdict"] == "REPAIR"
    assert adjudication["counts"] == {
        "KEEP": 1,
        "KEEP_CANDIDATE": 0,
        "REPAIR": 1,
        "BLOCK": 0,
    }
    assert candidate["status"] == "BOUND_CANDIDATE_PARTIAL"
    assert [item["ea_id"] for item in candidate["sleeves"]] == [1]
    assert candidate["excluded_sleeves"][0]["classification"] == "REPAIR"
    assert "CONTRACT_REQUAL:requal_required_test_reason" in candidate["excluded_sleeves"][0]["reasons"]


def test_blocked_contract_cannot_enter_candidate_even_with_pass_receipt(tmp_path: Path) -> None:
    adjudication, candidate = _adjudicate(
        _case(tmp_path, statuses=("ELIGIBLE", "BLOCKED"))
    )

    assert adjudication["verdict"] == "BLOCK"
    assert adjudication["counts"] == {
        "KEEP": 1,
        "KEEP_CANDIDATE": 0,
        "REPAIR": 0,
        "BLOCK": 1,
    }
    assert candidate["n_sleeves"] == 1
    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 2)
    assert "CONTRACT_BLOCK:blocked_test_reason" in decision["reasons"]


def test_non_order_routable_symbol_cannot_be_keep_even_with_eligible_contract_and_pass_receipt(
    tmp_path: Path,
) -> None:
    case = list(_case(tmp_path))
    repo, manifest, _manifest_sha, summary, registry = case
    sleeve = manifest["sleeves"][0]
    sleeve["symbol"] = "SP500.DWX"
    manifest_sha = _refresh_cost_and_receipts(
        tmp_path, manifest, summary, tmp_path / "cost_registry.json"
    )
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text(
        "symbol,evidence_line\n"
        'SP500.DWX,"owner_custom_symbol; backtest-only; broker routet keine Orders"\n'
        'EURUSD.DWX,"broker symbol"\n'
        'XAUUSD.DWX,"broker symbol"\n',
        encoding="utf-8",
    )

    adjudication, candidate = subject.adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256="8" * 64,
        registry_sha256="9" * 64,
        manifest_path="manifest.json",
        summary_path="summary.json",
        registry_path="contracts.json",
        repo_root=repo,
        symbol_matrix_path=matrix,
        as_of=dt.date(2026, 7, 15),
        generated_utc="2026-07-15T12:00:00+00:00",
    )

    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert decision["classification"] == "BLOCK"
    assert decision["reasons"] == ["SYMBOL_NON_ORDER_ROUTABLE:SP500.DWX"]
    assert [item["ea_id"] for item in candidate["sleeves"]] == [2]


def test_explicit_order_routable_alias_can_keep_only_when_exact_mapping_is_qualified(
    tmp_path: Path,
) -> None:
    case = list(_case(tmp_path))
    repo, manifest, _manifest_sha, summary, registry = case
    sleeve = manifest["sleeves"][0]
    sleeve["symbol"] = "SP500.DWX"
    manifest_sha = _refresh_cost_and_receipts(
        tmp_path, manifest, summary, tmp_path / "cost_registry.json"
    )

    evidence = tmp_path / "route_evidence.md"
    evidence.write_text("# bound test evidence\n", encoding="utf-8")
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text(
        "symbol,evidence_line,live_order_symbol,live_order_status,routing_evidence_ref\n"
        f'SP500.DWX,"custom test alias is backtest-only",SP500,'
        f"ORDER_ROUTABLE_CONFIRMED,{evidence}\n"
        "EURUSD.DWX,broker symbol,,,\n"
        "XAUUSD.DWX,broker symbol,,,\n",
        encoding="utf-8",
    )
    registry["contracts"][0]["darwinex_zero_routing"] = {
        "test_symbol": "SP500.DWX",
        "live_order_symbol": "SP500",
        "status": "BACKTEST_ALIAS_TO_ORDER_ROUTABLE_BROKER_SYMBOL",
        "source_registry": str(matrix),
        "evidence_ref": str(evidence),
        "automatic_symbol_inference": False,
        "qualification_status": "PASS",
        "full_requalification_required": True,
    }

    adjudication, candidate = subject.adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256="8" * 64,
        registry_sha256="9" * 64,
        manifest_path="manifest.json",
        summary_path="summary.json",
        registry_path="contracts.json",
        repo_root=repo,
        symbol_matrix_path=matrix,
        as_of=dt.date(2026, 7, 15),
        generated_utc="2026-07-15T12:00:00+00:00",
    )

    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert decision["classification"] == "KEEP"
    candidate_sleeve = next(item for item in candidate["sleeves"] if item["ea_id"] == 1)
    assert candidate_sleeve["execution_contract"]["darwinex_zero_routing"] == {
        "test_symbol": "SP500.DWX",
        "live_order_symbol": "SP500",
        "status": "BACKTEST_ALIAS_TO_ORDER_ROUTABLE_BROKER_SYMBOL",
        "source_registry": str(matrix),
        "evidence_ref": str(evidence),
        "automatic_symbol_inference": False,
        "qualification_status": "PASS",
        "full_requalification_required": True,
    }


def test_tampered_receipt_is_blocked_even_when_summary_is_resigned(tmp_path: Path) -> None:
    case = list(_case(tmp_path))
    summary = copy.deepcopy(case[3])
    summary["receipts"][0]["identity"]["native_report_sha256"] = "f" * 64
    _sign(summary, "summary_sha256")
    case[3] = summary

    adjudication, candidate = _adjudicate(tuple(case))

    assert adjudication["verdict"] == "BLOCK"
    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert "RECEIPT_SHA256_INVALID" in decision["reasons"]
    assert [item["ea_id"] for item in candidate["sleeves"]] == [2]


def test_missing_reference_binding_fails_closed(tmp_path: Path) -> None:
    case = list(_case(tmp_path))
    summary = copy.deepcopy(case[3])
    summary["receipts"][0]["identity"]["reference_stream_sha256"] = None
    _sign(summary["receipts"][0], "receipt_sha256")
    _sign(summary, "summary_sha256")
    case[3] = summary

    adjudication, _candidate = _adjudicate(tuple(case))

    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert decision["classification"] == "BLOCK"
    assert "RECEIPT_REFERENCE_STREAM_SHA256_UNBOUND" in decision["reasons"]


def test_invalid_summary_hash_blocks_all_sleeves_and_emits_empty_candidate(tmp_path: Path) -> None:
    case = list(_case(tmp_path))
    case[3]["unexpected_mutation"] = True

    adjudication, candidate = _adjudicate(tuple(case))

    assert adjudication["global_blockers"] == ["SUMMARY_SHA256_INVALID"]
    assert adjudication["counts"] == {
        "KEEP": 0,
        "KEEP_CANDIDATE": 0,
        "REPAIR": 0,
        "BLOCK": 2,
    }
    assert candidate["status"] == "NO_BOOK_CANDIDATE"
    assert candidate["sleeves"] == []


def test_summary_for_different_manifest_blocks_everything(tmp_path: Path) -> None:
    case = list(_case(tmp_path))
    case[3]["manifest_sha256"] = "0" * 64
    _sign(case[3], "summary_sha256")

    adjudication, candidate = _adjudicate(tuple(case))

    assert "SUMMARY_MANIFEST_SHA256_MISMATCH" in adjudication["global_blockers"]
    assert candidate["n_sleeves"] == 0


def test_missing_receipt_blocks_only_missing_sleeve_when_summary_is_consistent(tmp_path: Path) -> None:
    case = list(_case(tmp_path))
    summary = case[3]
    summary["receipts"] = summary["receipts"][:1]
    summary["n_jobs"] = 1
    summary["counts"] = {"PASS": 1}
    summary["scope"] = "PARTIAL"
    summary["status"] = "PASS_PARTIAL"
    _sign(summary, "summary_sha256")

    adjudication, candidate = _adjudicate(tuple(case))

    assert adjudication["counts"] == {
        "KEEP": 1,
        "KEEP_CANDIDATE": 0,
        "REPAIR": 0,
        "BLOCK": 1,
    }
    assert candidate["sleeves"] == []
    assert candidate["status"] == "NO_BOOK_CANDIDATE"
    assert candidate["n_validated_sleeves"] == 1
    assert candidate["validated_sleeves_not_admitted"][0]["key"] == "1:EURUSD.DWX"
    missing = next(item for item in adjudication["decisions"] if item["ea_id"] == 2)
    assert missing["reasons"] == ["RECEIPT_MISSING"]


def test_full_incomplete_summary_preserves_good_receipt_decision_but_emits_no_book_candidate(
    tmp_path: Path,
) -> None:
    case = list(_case(tmp_path))
    summary = case[3]
    original_job = summary["receipts"][1]["job"]
    blocked = {
        "schema_version": 1,
        "status": "BLOCKED",
        "blockers": ["REFERENCE_STREAM_MISSING_OR_INVALID"],
        "job": original_job,
        "execution": {"skipped": True, "reason": "REFERENCE_PREFLIGHT_BLOCKED"},
        "identity": {},
    }
    _sign(blocked, "receipt_sha256")
    summary["receipts"][1] = blocked
    summary["counts"] = {"PASS": 1, "BLOCKED": 1}
    summary["status"] = "INCOMPLETE"
    _sign(summary, "summary_sha256")

    adjudication, candidate = _adjudicate(tuple(case))

    assert adjudication["global_blockers"] == []
    first = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    second = next(item for item in adjudication["decisions"] if item["ea_id"] == 2)
    assert first["classification"] == "KEEP"
    assert second["classification"] == "BLOCK"
    assert candidate["status"] == "NO_BOOK_CANDIDATE"
    assert candidate["book_qualification_gate"] == {
        "eligible": False,
        "required_scope": "FULL",
        "required_summary_status": "PASS",
        "observed_scope": "FULL",
        "observed_summary_status": "INCOMPLETE",
        "required_qualification_mode": "AS_LIVE_REQUAL",
        "observed_qualification_mode": "AS_LIVE_REQUAL",
        "required_qualification_status": "QUALIFIED",
        "observed_qualification_status": "QUALIFIED",
        "cost_certified": True,
        "reasons": ["SUMMARY_STATUS_NOT_PASS:INCOMPLETE"],
    }
    assert candidate["n_validated_sleeves"] == 1
    assert candidate["sleeves"] == []
    assert candidate["validated_sleeves_not_admitted"][0]["key"] == "1:EURUSD.DWX"


def test_consistent_hash_does_not_hide_summary_scope_status_contradiction(tmp_path: Path) -> None:
    case = list(_case(tmp_path))
    case[3]["status"] = "INCOMPLETE"
    _sign(case[3], "summary_sha256")

    adjudication, candidate = _adjudicate(tuple(case))

    assert adjudication["global_blockers"] == ["SUMMARY_STATUS_MISMATCH"]
    assert all(item["classification"] == "BLOCK" for item in adjudication["decisions"])
    assert candidate["status"] == "NO_BOOK_CANDIDATE"


def test_machine_only_requal_reason_becomes_evidence_bound_keep_candidate(tmp_path: Path) -> None:
    adjudication, candidate = _adjudicate(_make_machine_requal_case(tmp_path))

    assert adjudication["verdict"] == "PASS"
    assert adjudication["counts"] == {
        "KEEP": 1,
        "KEEP_CANDIDATE": 1,
        "REPAIR": 0,
        "BLOCK": 0,
    }
    promoted = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert promoted["classification"] == "KEEP_CANDIDATE"
    assert promoted["reasons"] == []
    resolution = promoted["promotion_resolution"]
    assert resolution["resolved_reasons"] == ["remediated_binary_not_requalified"]
    assert resolution["unresolved_reasons"] == []
    assert resolution["resolution_scope"] == "AS_LIVE_AND_CURRENT_REPO_BINARY"
    assert resolution["repo_rebuild_status"] == "BOUND_TO_RECEIPT"
    assert resolution["repo_ex5"]["matches_receipt_live_ex5"] is True
    candidate_row = next(item for item in candidate["sleeves"] if item["ea_id"] == 1)
    assert candidate_row["qualification"]["status"] == "BOUND_PASS_EVIDENCE_PROMOTED"
    assert candidate_row["qualification"]["promotion_resolution"]["controlled_source_tree"]["aggregate_sha256"]


def test_semantic_reason_is_never_auto_resolved_alongside_machine_reason(tmp_path: Path) -> None:
    adjudication, candidate = _adjudicate(
        _make_machine_requal_case(
            tmp_path,
            extra_reasons=("friday_close_override_not_card_qualified",),
        )
    )

    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert decision["classification"] == "REPAIR"
    assert decision["promotion_resolution"]["resolved_reasons"] == [
        "remediated_binary_not_requalified"
    ]
    assert decision["promotion_resolution"]["unresolved_reasons"] == [
        "friday_close_override_not_card_qualified"
    ]
    assert "CONTRACT_REQUAL:friday_close_override_not_card_qualified" in decision["reasons"]
    assert [item["ea_id"] for item in candidate["sleeves"]] == [2]


def test_stale_repo_binary_allows_only_as_live_retention_candidate(tmp_path: Path) -> None:
    adjudication, candidate = _adjudicate(
        _make_machine_requal_case(tmp_path, stale_binary=True)
    )

    decision = next(item for item in adjudication["decisions"] if item["ea_id"] == 1)
    assert decision["classification"] == "KEEP_CANDIDATE"
    assert decision["reasons"] == []
    resolution = decision["promotion_resolution"]
    assert resolution["resolution_scope"] == "AS_LIVE_BINARY_RETENTION_ONLY"
    assert resolution["repo_rebuild_status"] == "REQUAL_REQUIRED"
    assert "PROMOTION_REPO_EX5_PREDATES_SOURCE_TREE" in resolution["repo_rebuild_blockers"]
    assert [item["ea_id"] for item in candidate["sleeves"]] == [1, 2]


def test_contract_counts_distinguish_sleeves_from_distinct_eas(tmp_path: Path) -> None:
    case = list(_case(tmp_path, statuses=("REQUAL_REQUIRED", "BLOCKED")))
    repo, manifest, manifest_sha, _summary, registry = case
    manifest["sleeves"].insert(
        1,
        _sleeve(1, "alpha", "GBPUSD.DWX", 11, 0.1),
    )
    manifest["n_sleeves"] = 3
    manifest_sha = subject.canonical_json_sha(manifest)
    empty_summary = {
        "schema_version": 1,
        "run_id": "empty",
        "status": "FAIL",
        "scope": "PARTIAL",
        "counts": {},
        "n_jobs": 0,
        "manifest_jobs": 3,
        "manifest_sha256": manifest_sha,
        "receipts": [],
    }
    _sign(empty_summary, "summary_sha256")

    adjudication, _candidate = subject.adjudicate(
        manifest,
        empty_summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256="8" * 64,
        registry_sha256="9" * 64,
        manifest_path="manifest.json",
        summary_path="summary.json",
        registry_path="contracts.json",
        repo_root=repo,
        as_of=dt.date(2026, 7, 15),
        generated_utc="2026-07-15T12:00:00+00:00",
    )

    # A legacy EA-wide contract may not leak across two manifest sleeves.  Both
    # rows fail closed as MISSING until sleeve-specific contracts exist.
    assert adjudication["source_contract_status_counts"]["sleeves"]["REQUAL_REQUIRED"] == 0
    assert adjudication["source_contract_status_counts"]["distinct_eas"]["REQUAL_REQUIRED"] == 0
    assert adjudication["source_contract_status_counts"]["sleeves"]["MISSING"] == 2
    assert adjudication["source_contract_status_counts"]["distinct_eas"]["MISSING"] == 1
    assert adjudication["source_contract_status_counts"]["sleeves"]["BLOCKED"] == 1
    assert adjudication["source_contract_status_counts"]["distinct_eas"]["BLOCKED"] == 1
    ambiguous = [
        item
        for item in adjudication["decisions"]
        if item["ea_id"] == 1
    ]
    assert len(ambiguous) == 2
    assert all(
        "CONTRACT_LEGACY_EA_SCOPE_AMBIGUOUS" in item["reasons"]
        for item in ambiguous
    )


def test_contract_resolution_is_timeframe_and_variant_specific(tmp_path: Path) -> None:
    h1 = _contract(tmp_path, 7, "alpha")
    h1.update({"symbol": "EURUSD.DWX", "timeframe": "H1", "variant_id": "BASE"})
    h4 = copy.deepcopy(h1)
    h4.update(
        {
            "timeframe": "H4",
            "strategy_timeframe": "H4",
            "bar_gate_timeframe": "H4",
            "variant_id": "CHALLENGER",
        }
    )
    contracts = {
        subject.execution_contract_lint.execution_contract_identity(h1): h1,
        subject.execution_contract_lint.execution_contract_identity(h4): h4,
    }
    sleeve = {
        "ea_id": 7,
        "symbol": "EURUSD.DWX",
        "timeframe": "H4",
        "variant_id": "CHALLENGER",
    }
    receipt = {"job": dict(sleeve)}

    contract, resolved, registry_identity, issues = subject._resolve_contract(
        sleeve,
        receipt,
        contracts,
        manifest_ea_counts={7: 2},
    )

    assert issues == []
    assert contract == h4
    assert resolved == (7, "EURUSD.DWX", "H4", "CHALLENGER")
    assert registry_identity == resolved

    unresolved_contract, unresolved_identity, unresolved_registry, ambiguous = subject._resolve_contract(
        {"ea_id": 7, "symbol": "EURUSD.DWX"},
        None,
        contracts,
        manifest_ea_counts={7: 2},
    )
    assert unresolved_contract is None
    assert unresolved_identity is None
    assert unresolved_registry is None
    assert ambiguous == ["CONTRACT_TIMEFRAME_AMBIGUOUS"]


def test_manifest_index_allows_same_ea_symbol_on_distinct_timeframes() -> None:
    manifest = {
        "n_sleeves": 2,
        "sleeves": [
            {"ea_id": 7, "symbol": "EURUSD.DWX", "timeframe": "H1"},
            {"ea_id": 7, "symbol": "EURUSD.DWX", "timeframe": "H4"},
        ],
    }

    sleeves, indexed, issues = subject._manifest_index(manifest)

    assert issues == []
    assert len(sleeves) == len(indexed) == 2


def _target_pair_for_summary(
    summary: dict,
    *,
    manifest_sha: str,
    summary_path: str = "summary.json",
    summary_file_sha: str = "8" * 64,
) -> tuple[dict, dict]:
    matched = ["1:EURUSD.DWX:H1:VARIANT_UNSPECIFIED", "2:XAUUSD.DWX:H1:VARIANT_UNSPECIFIED"]
    pair = {
        "artifact_type": subject.TARGET_PAIR_ARTIFACT_TYPE,
        "schema_version": subject.TARGET_PAIR_SCHEMA_VERSION,
        "status": "PASS",
        "qualification_mode": runner.TARGET_BINARY_REQUAL,
        "source_manifest_sha256": manifest_sha,
        "summary_a": {
            "path": summary_path,
            "file_sha256": summary_file_sha,
            "payload_sha256": summary["summary_sha256"],
            "declared_payload_sha256": summary["summary_sha256"],
            "run_id": summary["run_id"],
            "sidecar_path": f"{summary_path}.sha256",
            "sidecar_file_sha256": "1" * 64,
            "sidecar_declared_sha256": summary_file_sha,
        },
        "summary_b": {
            "path": "summary_b.json",
            "file_sha256": "7" * 64,
            "payload_sha256": "6" * 64,
            "declared_payload_sha256": "6" * 64,
            "run_id": "target-run-b",
            "sidecar_path": "summary_b.json.sha256",
            "sidecar_file_sha256": "5" * 64,
            "sidecar_declared_sha256": "7" * 64,
        },
        "contracts": {
            name: {"status": "PASS", "hash_bound": True}
            for name in ("card", "artifact_override", "reference", "cost", "window")
        },
        "identity_axes": {
            axis: {
                "status": "PASS",
                "required": True,
                "matched_sleeves": list(matched),
                "missing_sleeves": [],
                "mismatched_sleeves": [],
                "invalid_sleeves": [],
                "source_fields": [f"reproducibility_identity.{axis}"],
                "partial_observations": {},
            }
            for axis in subject.TARGET_REPRODUCIBILITY_AXES
        },
        "compared_sleeves": [
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "timeframe": "H1",
                "variant_id": "VARIANT_UNSPECIFIED",
                "status": "PASS",
                "identity_axes": {
                    axis: "PASS" for axis in subject.TARGET_REPRODUCIBILITY_AXES
                },
            }
            for ea_id, symbol in ((1, "EURUSD.DWX"), (2, "XAUUSD.DWX"))
        ],
        "runner_contract_gap": {
            "status": "CLOSED",
            "missing_required_axes": [],
            "required_receipt_field": "reproducibility_identity",
        },
        "run_intervals": {
            "summary_a": {
                "started_utc": "2026-07-16T12:00:00+00:00",
                "finished_utc": "2026-07-16T12:10:00+00:00",
                "receipt_count": 2,
            },
            "summary_b": {
                "started_utc": "2026-07-16T13:00:00+00:00",
                "finished_utc": "2026-07-16T13:10:00+00:00",
                "receipt_count": 2,
            },
            "serial_non_overlapping": True,
        },
        "issues": [],
        "deployment_eligible": False,
    }
    _sign(pair, "pair_payload_sha256")
    artifact_sha = subject.target_pair_artifact_sha(pair)
    metadata = {
        "path": "target_pair.json",
        "artifact_sha256": artifact_sha,
        "sidecar_path": "target_pair.json.sha256",
        "sidecar_sha256": "4" * 64,
        "sidecar_declared_sha256": artifact_sha,
    }
    return pair, metadata


def test_target_pair_validator_binds_current_summary_and_fails_on_axis_tamper() -> None:
    summary = {
        "run_id": "target-run-a",
        "summary_sha256": "3" * 64,
    }
    pair, metadata = _target_pair_for_summary(summary, manifest_sha="a" * 64)

    issues, binding = subject._target_pair_validation(
        pair,
        metadata,
        summary=summary,
        summary_path="summary.json",
        summary_sha256="8" * 64,
        manifest_sha256="a" * 64,
        manifest_count=2,
        manifest_keys={
            "1:EURUSD.DWX:H1:VARIANT_UNSPECIFIED",
            "2:XAUUSD.DWX:H1:VARIANT_UNSPECIFIED",
        },
    )

    assert issues == []
    assert binding is not None
    assert binding["current_summary_role"] == "summary_a"

    pair["identity_axes"]["mtm"]["status"] = "FAIL"
    _sign(pair, "pair_payload_sha256")
    metadata["artifact_sha256"] = subject.target_pair_artifact_sha(pair)
    metadata["sidecar_declared_sha256"] = metadata["artifact_sha256"]
    issues, _binding = subject._target_pair_validation(
        pair,
        metadata,
        summary=summary,
        summary_path="summary.json",
        summary_sha256="8" * 64,
        manifest_sha256="a" * 64,
        manifest_count=2,
        manifest_keys={
            "1:EURUSD.DWX:H1:VARIANT_UNSPECIFIED",
            "2:XAUUSD.DWX:H1:VARIANT_UNSPECIFIED",
        },
    )
    assert "TARGET_PAIR_IDENTITY_AXIS_NOT_PASS:mtm" in issues


def test_target_pair_promotes_only_effective_book_status(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo, manifest, manifest_sha, summary, registry = _case(tmp_path)
    for sleeve in manifest["sleeves"]:
        sleeve["timeframe"] = "H1"
        sleeve["variant_id"] = "VARIANT_UNSPECIFIED"
    for contract, sleeve in zip(registry["contracts"], manifest["sleeves"]):
        contract["symbol"] = sleeve["symbol"]
        contract["timeframe"] = "H1"
        contract["variant_id"] = "VARIANT_UNSPECIFIED"
    manifest_sha = subject.canonical_json_sha(manifest)
    summary["run_id"] = "target-run-a"
    summary["qualification_mode"] = runner.TARGET_BINARY_REQUAL
    summary["qualification_status"] = runner.TARGET_SINGLE_RUN_STATUS
    for receipt in summary["receipts"]:
        receipt["job"]["variant_id"] = "VARIANT_UNSPECIFIED"
        receipt["qualification_mode"] = runner.TARGET_BINARY_REQUAL
        receipt["qualification_status"] = runner.TARGET_SINGLE_RUN_STATUS
        _sign(receipt, "receipt_sha256")
    _sign(summary, "summary_sha256")
    pair, metadata = _target_pair_for_summary(summary, manifest_sha=manifest_sha)
    monkeypatch.setattr(subject, "_summary_integrity_issues", lambda *args, **kwargs: [])
    monkeypatch.setattr(subject, "_receipt_issues", lambda *args, **kwargs: [])

    adjudication, candidate = subject.adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256="8" * 64,
        registry_sha256="9" * 64,
        manifest_path="manifest.json",
        summary_path="summary.json",
        registry_path="contracts.json",
        target_repro_pair=pair,
        target_repro_pair_metadata=metadata,
        repo_root=repo,
        as_of=dt.date(2026, 7, 15),
        generated_utc="2026-07-15T12:00:00+00:00",
    )

    assert adjudication["book_qualification_gate"]["eligible"] is True
    assert candidate["status"] == "BOUND_CANDIDATE_COMPLETE"
    assert candidate["book_qualification_gate"]["observed_qualification_status"] == "QUALIFIED"
    assert candidate["source_requalification"]["qualification_status"] == "REPRODUCIBILITY_PENDING"
    assert candidate["source_requalification"]["effective_qualification_status"] == "QUALIFIED"
    assert candidate["sleeves"][0]["qualification"]["single_run_qualification_status"] == "REPRODUCIBILITY_PENDING"
    assert candidate["sleeves"][0]["qualification"]["qualification_status"] == "QUALIFIED"
    assert candidate["source_target_reproducibility_pair"]["status"] == "PASS"

    blocked_adjudication, blocked = subject.adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256="8" * 64,
        registry_sha256="9" * 64,
        manifest_path="manifest.json",
        summary_path="summary.json",
        registry_path="contracts.json",
        repo_root=repo,
        as_of=dt.date(2026, 7, 15),
        generated_utc="2026-07-15T12:00:00+00:00",
    )
    assert blocked["status"] == "NO_BOOK_CANDIDATE"
    assert blocked_adjudication["verdict"] == "BLOCK"
    assert all(
        decision["classification"] == "BLOCK"
        for decision in blocked_adjudication["decisions"]
    )
    assert blocked["book_qualification_gate"]["reasons"] == [
        "SUMMARY_OR_INPUT_INTEGRITY_INVALID",
        "TARGET_PAIR:TARGET_REPRODUCIBILITY_PAIR_MISSING"
    ]


def test_target_card_must_be_approved_and_exact_registry_card(
    tmp_path: Path,
) -> None:
    repo = tmp_path / "repo"
    cards = repo / "cards"
    cards.mkdir(parents=True)
    content = (
        "---\n"
        "card_schema_version: 2\n"
        "status: APPROVED\n"
        "g0_status: APPROVED\n"
        "execution_contract_status: APPROVED\n"
        "ea_id: QM5_7001\n"
        "symbol: EURUSD.DWX\n"
        "timeframe: H1\n"
        "variant_id: POLICY_REPAIR\n"
        "---\n"
        "# Approved exact target Card\n"
    )
    registry_card = cards / "registry.md"
    registry_card.write_text(content, encoding="utf-8")
    foreign_card = cards / "foreign.md"
    foreign_card.write_text(content, encoding="utf-8")
    contract = {"card_ref": str(registry_card.relative_to(repo))}
    identity = (7001, "EURUSD.DWX", "H1", "POLICY_REPAIR")

    assert subject._target_card_contract_issues(
        {
            "path": str(registry_card),
            "sha256": subject.sha256_file(registry_card),
        },
        contract,
        identity,
        repo_root=repo,
    ) == []
    assert subject._target_card_contract_issues(
        {
            "path": str(foreign_card),
            "sha256": subject.sha256_file(foreign_card),
        },
        contract,
        identity,
        repo_root=repo,
    ) == ["RECEIPT_TARGET_CARD_NOT_EXACT_REGISTRY_CARD"]


def test_output_guard_refuses_live_or_existing_directories(tmp_path: Path) -> None:
    with pytest.raises(subject.AdjudicationError, match="tier/live"):
        subject.validate_output_dir(tmp_path / "T_Live" / "reports", [])
    existing = tmp_path / "artifact"
    existing.mkdir()
    with pytest.raises(subject.AdjudicationError, match="already exists"):
        subject.validate_output_dir(existing, [])


def test_bundle_is_immutable_snapshot_with_checksums(tmp_path: Path) -> None:
    case = _case(tmp_path)
    adjudication, candidate = _adjudicate(case)
    _repo, manifest, _manifest_sha, summary, registry = case
    inputs = []
    for name, payload in (("manifest.json", manifest), ("summary.json", summary), ("registry.json", registry)):
        path = tmp_path / name
        path.write_text(json.dumps(payload), encoding="utf-8")
        inputs.append(path)
    output = tmp_path / "bundle"

    subject.write_bundle(
        output,
        adjudication=adjudication,
        candidate=candidate,
        manifest_path=inputs[0],
        summary_path=inputs[1],
        registry_path=inputs[2],
    )

    assert (output / "adjudication.json").is_file()
    assert (output / "candidate_bound_manifest.json").is_file()
    assert len((output / "SHA256SUMS").read_text(encoding="ascii").splitlines()) == 5
    with pytest.raises(FileExistsError):
        subject.write_bundle(
            output,
            adjudication=adjudication,
            candidate=candidate,
            manifest_path=inputs[0],
            summary_path=inputs[1],
            registry_path=inputs[2],
        )
