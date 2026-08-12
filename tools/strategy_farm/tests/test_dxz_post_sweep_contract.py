from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_requal_adjudicator as adjudicator
from tools.strategy_farm import dxz_truth_chain as truth_chain
from tools.strategy_farm import dxz_as_live_requal as runner
from tools.strategy_farm.tests.test_dxz_requal_adjudicator import (
    _certified_cost_contract,
)
from tools.strategy_farm.portfolio.portfolio_freeze_gate import (
    FreezeGateError,
    sha256_file,
    validate_admission_resize_freeze_gate,
)


def _write(path: Path, content: str | bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(content, bytes):
        path.write_bytes(content)
    else:
        path.write_text(content, encoding="utf-8")
    return path


def _write_json(path: Path, payload: dict) -> Path:
    return _write(path, json.dumps(payload, indent=2, sort_keys=True))


def _sign(payload: dict, field: str) -> None:
    payload.pop(field, None)
    payload[field] = adjudicator.canonical_json_sha(payload)


def _trade_stream(path: Path, symbol: str, trades: int) -> Path:
    rows = []
    for index in range(trades):
        rows.append(
            {
                "event": "TRADE_CLOSED",
                "ticket": 1000 + index,
                "entry_time": 1_700_000_000 + index * 10_000,
                "time": 1_700_003_600 + index * 10_000,
                "net": 10.0 if index % 2 == 0 else -4.0,
                "symbol": symbol,
            }
        )
    return _write(path, "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows))


def _build_full_contract(tmp_path: Path) -> dict[str, Path | dict]:
    repo = tmp_path / "repo"
    live_root = tmp_path / "T_Live"
    terminal = live_root / "MT5_Base"
    history_root = tmp_path / "DXZ_Truth_1"
    run_root = tmp_path / "requal" / "20260716T000000Z"
    label = "QM5_7001_contract-e2e"
    symbol = "EURUSD.DWX"
    trades = 2

    include = _write(repo / "framework" / "Include" / "QM" / "QM_Common.mqh", "// test\n")
    source = _write(
        repo / "framework" / "EAs" / label / f"{label}.mq5",
        '#include <QM/QM_Common.mqh>\n'
        "input bool qm_friday_close_enabled = false;\n"
        "int OnInit(){\n"
        "  QM_FrameworkDeclareExecutionContract(PERIOD_H1, "
        'QM_FRIDAY_CLOSE_DISABLED, "CARD_DISABLED");\n'
        "  return 0;\n"
        "}\n"
        "void OnTick(){ if(QM_IsNewBar(_Symbol, PERIOD_H1)){} }\n",
    )
    card = _write(repo / "cards" / f"{label}.md", f"# {label}\n")
    live_ex5 = _write(
        terminal / "MQL5" / "Experts" / "Live EAs" / f"{label}.ex5",
        b"qualified-as-live-binary",
    )
    live_preset = _write(
        terminal
        / "MQL5"
        / "Presets"
        / f"slot0_EURUSD_H1_{label}_magic70010000_dxz23_live.set",
        "; environment: live\nRISK_PERCENT=0.25\nRISK_FIXED=0\nPORTFOLIO_WEIGHT=1\n",
    )
    _write(
        history_root / "Tester" / "bases" / "Darwinex-Live" / "history" / symbol / "2025.hcs",
        b"bars",
    )
    _write(
        history_root / "Tester" / "bases" / "Darwinex-Live" / "ticks" / symbol / "202501.tkc",
        b"ticks",
    )
    cost = _write(tmp_path / "cost.json", '{"cost":"bound"}\n')

    sleeve = {
        "ea_id": 7001,
        "symbol": symbol,
        "ea_label": label,
        "magic_number": 70010000,
        "weight": 0.25,
        "risk_percent": 0.25,
        "trades": trades,
        "set_file_expectation": {
            "ENV": "live",
            "RISK_FIXED": 0,
            "RISK_PERCENT": 0.25,
            "PORTFOLIO_WEIGHT": 1,
        },
    }
    manifest = {
        "book": "DXZ_E2E",
        "status": "DRAFT",
        "n_sleeves": 1,
        "sleeves": [sleeve],
    }
    manifest_path = _write_json(tmp_path / "source_manifest.json", manifest)
    manifest_sha = sha256_file(manifest_path)
    cost_metadata, cost_contracts = _certified_cost_contract(
        tmp_path / "execution_cost", manifest_sha, [sleeve]
    )
    cost_contract = cost_contracts[f"{sleeve['ea_id']}:{sleeve['symbol']}"]
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

    run_dir = run_root / "runs" / "01_7001_EURUSD_DWX"
    q08 = _trade_stream(run_dir / "q08_stream.jsonl", symbol, trades)
    report_stream = _trade_stream(run_dir / "report_trade_stream.jsonl", symbol, trades)
    report = _write(run_dir / "report.htm", b"native-report")
    tester_ini = _write(run_dir / "tester.ini", "[Tester]\n")
    reference = _trade_stream(tmp_path / "sealed" / "7001_EURUSD_DWX.jsonl", symbol, trades)
    cost_axes["historical_tester_spread"]["native_report_evidence"] = {
        "native_report_sha256": sha256_file(report),
        "history_quality": "100% real ticks",
        "bars": 100,
        "ticks": 1000,
        "symbol_count": 1,
        "real_ticks_certified": True,
    }
    preset_contract_stage = {
        "status": "PASS",
        "preset_path": str(live_preset),
        "preset_sha256": sha256_file(live_preset),
        "expected": dict(sleeve["set_file_expectation"]),
        "actual": {
            "ENV": "live",
            "RISK_FIXED": "0",
            "RISK_PERCENT": "0.25",
            "PORTFOLIO_WEIGHT": "1",
        },
        "checks": [],
        "blockers": [],
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
        "runner_sha256": "a" * 64,
        "artifact_source": "CANONICAL_T_LIVE",
        "execution_cost_evidence_manifest": cost_metadata,
        "window_contract": {
            "requested_from_date": "2017-01-01",
            "requested_to_date": "2025-12-31",
            "effective_from_date": "2017-01-01",
            "effective_to_date": "2025-12-31",
        },
        "requested_from_date": "2017-01-01",
        "requested_to_date": "2025-12-31",
        "effective_from_date": "2017-01-01",
        "effective_to_date": "2025-12-31",
        "blockers": [],
        "job": {
            "ordinal": 1,
            "ea_id": 7001,
            "symbol": symbol,
            "ea_label": label,
            "timeframe": "H1",
            "manifest_trades": trades,
        },
        "execution": {
            "sandbox": str(history_root),
            "started_utc": "2026-07-16T00:00:00+00:00",
            "finished_utc": "2026-07-16T00:01:00+00:00",
            "exit_code": 0,
            "timed_out": False,
            "from_date": "2017.01.01",
            "to_date": "2025.12.31",
            "requested_from_date": "2017-01-01",
            "requested_to_date": "2025-12-31",
            "effective_from_date": "2017-01-01",
            "effective_to_date": "2025-12-31",
            "currency": "EUR",
            "deposit": 100_000,
        },
        "identity": {
            "live_ex5_path": str(live_ex5),
            "live_ex5_sha256": sha256_file(live_ex5),
            "live_ex5_sha256_before": sha256_file(live_ex5),
            "staged_ex5_sha256": sha256_file(live_ex5),
            "live_preset_path": str(live_preset),
            "live_preset_sha256": sha256_file(live_preset),
            "live_preset_sha256_before": sha256_file(live_preset),
            "staged_preset_sha256": sha256_file(live_preset),
            "tester_ini_sha256": sha256_file(tester_ini),
            "native_report_sha256": sha256_file(report),
            "report_trade_stream_sha256": sha256_file(report_stream),
            "q08_stream_sha256": sha256_file(q08),
            "reference_stream_path": str(reference),
            "reference_stream_sha256": sha256_file(reference),
            "reference_expected_sha256": sha256_file(reference),
            "reference_frozen_relative_path": f"streams/{reference.name}",
        },
        "common_stream_capture": {
            "captured": True,
            "restored": True,
            "stream_sha256": sha256_file(q08),
        },
        "native_metrics": {"total_trades": trades},
        "native_report_execution_evidence": {
            "history_quality": "100% real ticks",
            "bars": 100,
            "ticks": 1000,
            "symbol_count": 1,
            "real_ticks_certified": True,
            "errors": [],
        },
        "live_preset_contract": {
            "before": dict(preset_contract_stage),
            "staged": {**preset_contract_stage, "preset_path": "sandbox/source.set"},
            "after": dict(preset_contract_stage),
            "unchanged": True,
        },
        "cost_evidence": {
            "status": "CERTIFIED",
            "cost_certified": True,
            "reasons": [],
            "required_axes": list(runner.EXECUTION_COST_AXES),
            "axes": cost_axes,
            "execution_cost_evidence_manifest": cost_metadata,
            "registry_path": str(cost),
            "registry_sha256": sha256_file(cost),
            "unknown_symbols": [],
            "degraded_symbols": [],
        },
        "cost_certified": True,
        "observed_trade_stats": {"trades": trades, "net": 6.0},
        "reference_trade_stats": {"trades": trades, "net": 6.0},
        "manifest_count_match": True,
        "reference_close_sequence_match": True,
        "q08_reference_signal_identity_match": True,
        "q08_reference_outcome_sign_match": True,
        "parse_error": None,
    }
    _sign(receipt, "receipt_sha256")
    _write_json(run_dir / "receipt.json", receipt)
    summary = {
        "schema_version": 2,
        "run_id": "20260716T000000Z",
        "status": "PASS",
        "technical_status": "PASS",
        "qualification_mode": "AS_LIVE_REQUAL",
        "qualification_status": "QUALIFIED",
        "deployment_eligible": False,
        "runner_sha256": "a" * 64,
        "runner_sha256_start": "a" * 64,
        "runner_sha256_end": "a" * 64,
        "runner_unchanged": True,
        "live_root": str(adjudicator.CANONICAL_LIVE_ROOT),
        "canonical_live_root": str(adjudicator.CANONICAL_LIVE_ROOT),
        "canonical_live_root_pinned": True,
        "window_contract": receipt["window_contract"],
        "requested_from_date": "2017-01-01",
        "requested_to_date": "2025-12-31",
        "effective_from_date": "2017-01-01",
        "effective_to_date": "2025-12-31",
        "scope": "FULL",
        "counts": {"PASS": 1},
        "n_jobs": 1,
        "manifest_jobs": 1,
        "manifest_sha256": manifest_sha,
        "manifest_sha256_end": manifest_sha,
        "manifest_unchanged": True,
        "reference_snapshot": {
            "status": "PASS",
            "seal_verified": True,
            "errors": [],
            "source_manifest_sha256": manifest_sha,
            "manifest_sha256": "b" * 64,
            "seal_sha256": "c" * 64,
            "snapshot_root": str(reference.parent),
        },
        "reference_snapshot_end": {
            "status": "PASS",
            "seal_verified": True,
            "errors": [],
            "source_manifest_sha256": manifest_sha,
            "manifest_sha256": "b" * 64,
            "seal_sha256": "c" * 64,
            "snapshot_root": str(reference.parent),
        },
        "reference_snapshot_unchanged": True,
        "cost_evidence": {
            "status": "CERTIFIED",
            "cost_certified": True,
            "reasons": [],
            "required_axes": list(runner.EXECUTION_COST_AXES),
            "axes": {
                axis: {"status": "PASS", "pass_receipts": 1, "required_receipts": 1}
                for axis in runner.EXECUTION_COST_AXES
            },
            "execution_cost_evidence_manifest": cost_metadata,
            "registry_paths": [str(cost)],
            "registry_sha256s": [sha256_file(cost)],
            "unknown_symbols": [],
            "degraded_symbols": [],
        },
        "cost_certified": True,
        "cost_registry": {
            "path": str(cost),
            "sha256_start": sha256_file(cost),
            "sha256_end": sha256_file(cost),
            "unchanged": True,
        },
        "execution_cost_evidence_manifest": {
            **cost_metadata,
            "sha256_end": cost_metadata["sha256"],
            "axis_hashes_end": cost_metadata["axis_hashes_start"],
            "unchanged": True,
            "end_errors": [],
        },
        "receipts": [receipt],
    }
    _sign(summary, "summary_sha256")
    summary_path = _write_json(run_root / "summary.json", summary)

    contract = {
        "ea_id": 7001,
        "slug": "contract-e2e",
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
            "card_evidence": "test contract",
        },
        "calendar": {"policy": "NONE"},
        "promotion": {"status": "ELIGIBLE", "block_reasons": []},
    }
    registry = {"schema_version": 2, "book_id": "e2e", "contracts": [contract]}
    registry_path = _write_json(tmp_path / "contracts.json", registry)

    adjudication, candidate = adjudicator.adjudicate(
        manifest,
        summary,
        registry,
        manifest_sha256=manifest_sha,
        summary_sha256=sha256_file(summary_path),
        registry_sha256=sha256_file(registry_path),
        manifest_path=str(manifest_path),
        summary_path=str(summary_path),
        registry_path=str(registry_path),
        repo_root=repo,
        as_of=dt.date(2026, 7, 16),
        generated_utc="2026-07-16T00:02:00+00:00",
    )
    bundle = tmp_path / "adjudication_bundle"
    adjudicator.write_bundle(
        bundle,
        adjudication=adjudication,
        candidate=candidate,
        manifest_path=manifest_path,
        summary_path=summary_path,
        registry_path=registry_path,
    )
    return {
        "repo": repo,
        "live_root": live_root,
        "history_root": history_root,
        "include": include,
        "cost": cost,
        "q08": q08,
        "summary": summary_path,
        "adjudication": bundle / "adjudication.json",
        "candidate": bundle / "candidate_bound_manifest.json",
        "candidate_payload": candidate,
        "adjudication_payload": adjudication,
    }


def test_full_runner_summary_to_adjudicator_truth_chain_and_freeze_gate(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Fixture cost-evidence axes are stamped with a fixed validity window
    # (valid_from_utc=2026-07-14 .. valid_until_utc=2026-07-18). Pin the
    # truth-chain's wall clock inside that window so the test stays
    # deterministic instead of expiring once real time passes 2026-07-18.
    monkeypatch.setattr(
        truth_chain, "utc_now", lambda: dt.datetime(2026, 7, 16, tzinfo=dt.UTC)
    )
    fixture = _build_full_contract(tmp_path)
    candidate = fixture["candidate_payload"]
    assert isinstance(candidate, dict)
    assert candidate["status"] == "BOUND_CANDIDATE_COMPLETE"
    bindings = candidate["sleeves"][0]["artifact_bindings"]
    assert bindings["qualified_ex5_path"] == bindings["live_ex5_path"]
    assert bindings["qualified_set_path"] == bindings["live_preset_path"]
    assert bindings["qualified_live_preset_path"] == bindings["live_preset_path"]
    assert bindings["qualified_stream_sha256"] == sha256_file(fixture["q08"])
    assert candidate["sleeves"][0]["trades"] == 2

    evidence = truth_chain.build_evidence(
        fixture["candidate"],
        repo_root=fixture["repo"],
        live_root=fixture["live_root"],
        cards_roots=[fixture["repo"] / "cards"],
        history_roots=[fixture["history_root"]],
        include_roots=[fixture["repo"] / "framework" / "Include"],
        cost_models=[fixture["cost"]],
        generated_at=dt.datetime(2026, 7, 16, tzinfo=dt.UTC),
    )
    assert evidence["verdict"] == "PASS"
    assert evidence["qualification_chain"]["status"] == "PASS"
    assert evidence["summary"]["closed_count"] == 1

    truth_path = _write_json(tmp_path / "truth_chain.json", evidence)
    lineage = evidence["qualification_chain"]
    gate = {
        "schema_version": 1,
        "gate_type": "ADMISSION_RESIZE_FREEZE",
        "allowed_purposes": ["admission", "resize"],
        "truth_chain": {
            "status": "PASS",
            "artifact_path": str(truth_path),
            "artifact_sha256": sha256_file(truth_path),
            "candidate_manifest_sha256": lineage["candidate"]["sha256"],
            "adjudication_sha256": lineage["adjudication"]["sha256"],
            "requal_summary_sha256": lineage["requalification"]["sha256"],
        },
        "inputs": {
            "resize_config_sha256": "a" * 64,
            "stream_manifest_sha256": "b" * 64,
            "commission_registry_sha256": "c" * 64,
            "streams": {"7001:EURUSD.DWX": sha256_file(fixture["q08"])},
        },
    }
    gate_path = _write_json(tmp_path / "freeze_gate.json", gate)
    frozen = validate_admission_resize_freeze_gate(
        gate_path,
        purpose="admission",
        actual_inputs={
            "resize_config_sha256": "a" * 64,
            "stream_manifest_sha256": "b" * 64,
            "commission_registry_sha256": "c" * 64,
        },
        actual_stream_sha256={"7001:EURUSD.DWX": sha256_file(fixture["q08"])},
    )
    assert frozen.candidate_manifest_sha256 == sha256_file(fixture["candidate"])
    assert frozen.adjudication_sha256 == sha256_file(fixture["adjudication"])
    assert frozen.requal_summary_sha256 == sha256_file(fixture["summary"])

    gate["truth_chain"]["requal_summary_sha256"] = "f" * 64
    _write_json(gate_path, gate)
    with pytest.raises(FreezeGateError, match="lineage SHA mismatch"):
        validate_admission_resize_freeze_gate(
            gate_path,
            purpose="resize",
            actual_inputs={"resize_config_sha256": "a" * 64},
            actual_stream_sha256={"7001:EURUSD.DWX": sha256_file(fixture["q08"])},
        )


def test_partial_candidate_cannot_reach_truth_or_freeze_eligibility(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # See test_full_runner_summary_to_adjudicator_truth_chain_and_freeze_gate:
    # pin the wall clock inside the fixture's fixed cost-evidence validity window.
    monkeypatch.setattr(
        truth_chain, "utc_now", lambda: dt.datetime(2026, 7, 16, tzinfo=dt.UTC)
    )
    fixture = _build_full_contract(tmp_path)
    candidate_path = fixture["candidate"]
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    candidate["status"] = "BOUND_CANDIDATE_PARTIAL"
    candidate["candidate_manifest_sha256"] = adjudicator.canonical_json_sha(
        {key: value for key, value in candidate.items() if key != "candidate_manifest_sha256"}
    )
    _write_json(candidate_path, candidate)

    evidence = truth_chain.build_evidence(
        candidate_path,
        repo_root=fixture["repo"],
        live_root=fixture["live_root"],
        cards_roots=[fixture["repo"] / "cards"],
        history_roots=[fixture["history_root"]],
        include_roots=[fixture["repo"] / "framework" / "Include"],
        cost_models=[fixture["cost"]],
    )
    assert evidence["verdict"] == "FAIL"
    assert "candidate_status_not_complete" in evidence["qualification_chain"]["issues"]

    truth_path = _write_json(tmp_path / "partial_truth.json", evidence)
    lineage = evidence["qualification_chain"]
    gate_path = _write_json(
        tmp_path / "partial_gate.json",
        {
            "schema_version": 1,
            "gate_type": "ADMISSION_RESIZE_FREEZE",
            "allowed_purposes": ["admission"],
            "truth_chain": {
                "status": "PASS",
                "artifact_path": str(truth_path),
                "artifact_sha256": sha256_file(truth_path),
                "candidate_manifest_sha256": lineage["candidate"]["sha256"],
                "adjudication_sha256": lineage["adjudication"]["sha256"],
                "requal_summary_sha256": lineage["requalification"]["sha256"],
            },
            "inputs": {"streams": {"7001:EURUSD.DWX": sha256_file(fixture["q08"])}},
        },
    )
    with pytest.raises(FreezeGateError, match="artifact status"):
        validate_admission_resize_freeze_gate(
            gate_path,
            purpose="admission",
            actual_inputs={"candidate_manifest_sha256": sha256_file(candidate_path)},
            actual_stream_sha256={"7001:EURUSD.DWX": sha256_file(fixture["q08"])},
        )


def test_truth_chain_rejects_rebound_discovery_summary_even_when_marked_pass(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # See test_full_runner_summary_to_adjudicator_truth_chain_and_freeze_gate:
    # pin the wall clock inside the fixture's fixed cost-evidence validity window.
    monkeypatch.setattr(
        truth_chain, "utc_now", lambda: dt.datetime(2026, 7, 16, tzinfo=dt.UTC)
    )
    fixture = _build_full_contract(tmp_path)
    summary_path = fixture["summary"]
    assert isinstance(summary_path, Path)
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["qualification_mode"] = "DISCOVERY_RECONCILED"
    summary["qualification_status"] = "QUALIFIED"
    _sign(summary, "summary_sha256")
    _write_json(summary_path, summary)

    candidate_path = fixture["candidate"]
    assert isinstance(candidate_path, Path)
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    binding = candidate["source_requalification"]
    binding.update(
        {
            "artifact_sha256": sha256_file(summary_path),
            "sha256": sha256_file(summary_path),
            "payload_sha256": summary["summary_sha256"],
            "qualification_mode": "DISCOVERY_RECONCILED",
            "qualification_status": "QUALIFIED",
        }
    )
    candidate["evidence"]["as_live_summary"] = dict(binding)
    candidate["book_qualification_gate"]["observed_qualification_mode"] = (
        "DISCOVERY_RECONCILED"
    )
    for sleeve in candidate["sleeves"]:
        sleeve["qualification"]["qualification_mode"] = "DISCOVERY_RECONCILED"
    candidate["candidate_manifest_sha256"] = adjudicator.canonical_json_sha(
        {
            key: value
            for key, value in candidate.items()
            if key != "candidate_manifest_sha256"
        }
    )
    _write_json(candidate_path, candidate)

    evidence = truth_chain.build_evidence(
        candidate_path,
        repo_root=fixture["repo"],
        live_root=fixture["live_root"],
        cards_roots=[fixture["repo"] / "cards"],
        history_roots=[fixture["history_root"]],
        include_roots=[fixture["repo"] / "framework" / "Include"],
        cost_models=[fixture["cost"]],
    )

    assert evidence["verdict"] == "FAIL"
    issues = evidence["qualification_chain"]["issues"]
    assert "candidate_book_gate_mode_not_qualifying" in issues
    assert "adjudication_requal_binding_mismatch" in issues
    assert "candidate_book_gate_mode_contract_mismatch" in issues
