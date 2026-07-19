from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

import dxz_target_binary_repro_gate as gate  # noqa: E402


def _h(label: str) -> str:
    return hashlib.sha256(label.encode("utf-8")).hexdigest()


def _cost_evidence() -> dict:
    return {
        "status": "CERTIFIED",
        "cost_certified": True,
        "axes": {axis: {"status": "PASS"} for axis in gate.REQUIRED_COST_AXES},
    }


def _artifact_contract(manifest_sha256: str) -> dict:
    return {
        "path": "D:/QM/evidence/target-artifacts.json",
        "sha256": _h("artifact-manifest-file"),
        "artifact_payload_sha256": _h("artifact-manifest-payload"),
        "source_manifest_sha256": manifest_sha256,
        "bound_artifacts": [
            {
                "ea_id": 12567,
                "symbol": "XNGUSD.DWX",
                "timeframe": "D1",
                "variant_id": "VARIANT_UNSPECIFIED",
                "ex5_sha256": _h("target-ex5"),
                "set_sha256": _h("target-set"),
            }
        ],
    }


def _axis_contract(sequences: dict[str, list]) -> dict:
    result = {"schema_version": 1}
    for axis in gate.REQUIRED_IDENTITY_AXES:
        sequence = sequences[axis]
        result[axis] = {
            "complete": True,
            "count": len(sequence),
            "sha256": gate.canonical_json_sha(sequence),
            "basis": f"ordered_{axis}_v1",
        }
    return result


def _telemetry_descriptor(
    sequence: list,
    *,
    complete: bool = True,
    basis: str = "test_physical_sequence",
    reasons: list[str] | None = None,
) -> dict:
    return {
        "complete": complete,
        "count": len(sequence),
        "sha256": gate.canonical_json_sha(sequence),
        "basis": basis,
        "reasons": [] if reasons is None else reasons,
        "sequence": sequence,
    }


def _write_runtime_artifacts(
    run_dir: Path,
    run: str,
    sandbox: Path,
    expected_magic_source: dict,
) -> dict:
    run_dir.mkdir(parents=True, exist_ok=True)
    sandbox.mkdir(parents=True, exist_ok=True)
    job_identity = "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED"
    expected_magic = 125670002
    runtime_log = (run_dir / "runtime_log.jsonl").resolve()
    runtime_rows = [
        {
            "event": "INIT",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "payload": {"magic": expected_magic, "symbol": "XNGUSD.DWX"},
        },
        {
            "event": "INIT_OK",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "payload": {},
        },
        {
            "event": "ENTRY_ACCEPTED",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "ts_broker": "2024-01-01T00:00:00+00:00",
            "payload": {
                "symbol": "XNGUSD.DWX",
                "magic": expected_magic,
                "ticket": 1,
                "type": "BUY",
                "lots": 0.1,
                "price": 2.5,
                "reason": "SIGNAL",
            },
        },
        {
            "event": "TM_CLOSE",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "ts_broker": "2024-01-02T00:00:00+00:00",
            "payload": {
                "symbol": "XNGUSD.DWX",
                "ticket": 1,
                "lots": 0.1,
                "reason": "TP",
                "ok": True,
                "partial": False,
            },
        },
        {
            "event": "EQUITY_SNAPSHOT",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "ts_broker": "2024-01-02T00:00:00+00:00",
            "payload": {
                "symbol": "XNGUSD.DWX",
                "day_key": 20240102,
                "month_key": 202401,
                "equity": 10010.5,
                "day_pnl": 10.5,
                "month_pnl": 10.5,
                "atr_regime": "NORMAL",
            },
        },
        {
            "event": "ENTRY_ACCEPTED",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "ts_broker": "2024-01-03T00:00:00+00:00",
            "payload": {
                "symbol": "XNGUSD.DWX",
                "magic": expected_magic,
                "ticket": 2,
                "type": "SELL",
                "lots": 0.2,
                "price": 2.7,
                "reason": "SIGNAL",
            },
        },
        {
            "event": "TM_CLOSE",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "ts_broker": "2024-01-04T00:00:00+00:00",
            "payload": {
                "symbol": "XNGUSD.DWX",
                "ticket": 2,
                "lots": 0.2,
                "reason": "SL",
                "ok": True,
                "partial": False,
            },
        },
        {
            "event": "EQUITY_SNAPSHOT",
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "tf": "D1",
            "magic": expected_magic,
            "ts_broker": "2024-01-04T00:00:00+00:00",
            "payload": {
                "symbol": "XNGUSD.DWX",
                "day_key": 20240104,
                "month_key": 202401,
                "equity": 10008,
                "day_pnl": -2.5,
                "month_pnl": 8,
                "atr_regime": "NORMAL",
            },
        },
    ]
    runtime_log.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in runtime_rows),
        encoding="utf-8",
    )
    runtime_log_sha = gate.sha256_file(runtime_log)
    q08_rows = [
        {
            "event": "TRADE_CLOSED",
            "entry_time": 1704067200,
            "time": 1704153600,
            "symbol": "XNGUSD.DWX",
            "volume": 0.1,
            "net": 10.5,
            "profit": 11.0,
            "mae_acct": -1.0,
            "swap": 0.0,
            "commission": -0.5,
            "notional": 2500.0,
            "magic": expected_magic,
        },
        {
            "event": "TRADE_CLOSED",
            "entry_time": 1704240000,
            "time": 1704326400,
            "symbol": "XNGUSD.DWX",
            "volume": 0.2,
            "net": -2.5,
            "profit": -2.0,
            "mae_acct": -3.0,
            "swap": 0.0,
            "commission": -0.5,
            "notional": 5400.0,
            "magic": expected_magic,
        },
    ]
    q08_stream = (run_dir / "q08_stream.jsonl").resolve()
    q08_stream.write_text(
        "".join(
            json.dumps(row, sort_keys=True)
            + "\n"
            for row in q08_rows
        ),
        encoding="utf-8",
    )
    enriched_rows = [
        {**q08_rows[0], "side": "BUY", "requested_entry_price": "2.5", "exit_reason": "TP"},
        {**q08_rows[1], "side": "SELL", "requested_entry_price": "2.7", "exit_reason": "SL"},
    ]
    entry_sequence = [
        [1704067200, "XNGUSD.DWX", "0.1", "BUY", "2.5", 1, "SIGNAL", expected_magic],
        [1704240000, "XNGUSD.DWX", "0.2", "SELL", "2.7", 2, "SIGNAL", expected_magic],
    ]
    exit_sequence = [
        [1704153600, "XNGUSD.DWX", "0.1", "TP", 1, "TM_CLOSE", expected_magic],
        [1704326400, "XNGUSD.DWX", "0.2", "SL", 2, "TM_CLOSE", expected_magic],
    ]
    daily_sequence = [
        [1704153600, 20240102, "XNGUSD.DWX", "10010.5", "10.5", "10.5", "NORMAL", expected_magic],
        [1704326400, 20240104, "XNGUSD.DWX", "10008", "-2.5", "8", "NORMAL", expected_magic],
    ]
    mtm_sequence = [[1704067200, "10000"], [1704326400, "10008"]]
    margin_sequence = [[1704067200, "100", "9900", "120"], [1704326400, "0", "10008", "0"]]

    telemetry = (run_dir / "runtime_telemetry.json").resolve()
    telemetry_payload = {
        "schema_version": 1,
        "capture_sha256": runtime_log_sha,
        "job_identity": job_identity,
        "expected_magic": expected_magic,
        "expected_magic_source": dict(expected_magic_source),
        "telemetry": {
            "schema_version": 1,
            "status": "PASS",
            "errors": [],
            "line_count": 8,
            "relevant_event_count": 6,
            "identity": {
                "ea_id": 12567,
                "symbol": "XNGUSD.DWX",
                "timeframe": "D1",
                "magic": expected_magic,
                "magic_unique": True,
                "expected_magic": expected_magic,
                "expected_magic_valid": True,
                "expected_magic_source": dict(expected_magic_source),
                "observed_magic_matches_expected": True,
            },
            "entries": _telemetry_descriptor(
                entry_sequence,
                basis=(
                    "framework_ENTRY_ACCEPTED_broker_time_symbol_volume_side_"
                    "requested_price_not_fill_price"
                ),
            ),
            "exits": _telemetry_descriptor(
                exit_sequence,
                basis="framework_TM_CLOSE_broker_time_symbol_volume_reason",
            ),
            "equity": _telemetry_descriptor(
                daily_sequence,
                complete=False,
                basis="framework_EQUITY_SNAPSHOT_partial_observation_sequence",
                reasons=[
                    "INITIAL_AND_FINAL_EQUITY_BOUNDARY_SNAPSHOTS_NOT_EMITTED"
                ],
            ),
        },
        "q08_binding": {
            "status": "INCOMPLETE",
            "integrity_status": "PASS",
            "blockers": ["ENTRY_FILL_PRICE_NOT_EMITTED"],
            "entries_complete": False,
            "entry_join_complete": True,
            "entry_axis_reasons": ["ENTRY_FILL_PRICE_NOT_EMITTED"],
            "exits_complete": True,
            "exit_join_complete": True,
            "exit_axis_reasons": [],
            "enriched_rows": enriched_rows,
            "magic_bound": True,
            "authoritative_expected_magic_bound": True,
            "expected_magic": expected_magic,
            "expected_magic_valid": True,
            "runtime_magic_matches_expected": True,
            "q08_magic_matches_expected": True,
            "magic_cross_stream_consistent": True,
            "observed_magic": expected_magic,
            "entry_join_basis": (
                "exact_broker_time_symbol_canonical_volume_bijection; "
                "price_is_request_not_fill"
            ),
            "exit_join_basis": "exact_broker_time_symbol_canonical_volume_bijection",
        },
    }
    telemetry.write_text(
        json.dumps(telemetry_payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    transaction = (run_dir / "runtime_log_transaction.json").resolve()
    transaction.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "CAPTURED_AND_RESTORED",
                "sandbox": str(sandbox.resolve()),
                "ea_id": 12567,
                "job_identity": job_identity,
                "pattern": r"^QM5_12567_.+\.log$",
                "prepared_epoch_ns": 1,
                "pre_run_logs": [],
                "completed_utc": "2026-07-16T12:10:00+00:00",
                "capture": {
                    "status": "PASS",
                    "captured": True,
                    "fresh": True,
                    "restored": True,
                    "ambiguous": False,
                    "blockers": [],
                    "evidence_path": str(runtime_log),
                    "sha256": runtime_log_sha,
                    "size": runtime_log.stat().st_size,
                    "source_path": str((sandbox / "tester" / "files" / "QM5_12567_test.log").resolve()),
                    "late_rescans": 3,
                    "candidates": [
                        {
                            "source_path": str((sandbox / "tester" / "files" / "QM5_12567_test.log").resolve()),
                            "evidence_path": str((run_dir / "runtime_log_candidates" / "001_QM5_12567_test.log").resolve()),
                            "sha256": runtime_log_sha,
                            "size": runtime_log.stat().st_size,
                            "mtime_ns": 1,
                            "fresh": True,
                            "stable": True,
                            "stability_observations": 3,
                            "required_stability_observations": 3,
                        }
                    ],
                    "preserved_post_run_logs": [
                        {
                            "source_path": str((sandbox / "tester" / "files" / "QM5_12567_test.log").resolve()),
                            "evidence_path": str((run_dir / "runtime_log_candidates" / "001_QM5_12567_test.log").resolve()),
                            "sha256": runtime_log_sha,
                            "size": runtime_log.stat().st_size,
                            "mtime_ns": 1,
                            "fresh": True,
                            "stable": True,
                            "stability_observations": 3,
                            "required_stability_observations": 3,
                        }
                    ],
                    "restore_errors": [],
                    "restored_pre_run_logs": [],
                    "post_restore_quiescence": {
                        "confirmed": True,
                        "stable_observations": 3,
                        "required_stable_observations": 3,
                        "scans": 3,
                        "incidents": [],
                    },
                    "residual_concurrency_risk": (
                        "FINITE_QUIESCENCE_WINDOW_CANNOT_PREVENT_A_NON_RUN_UNIQUE_"
                        "LOG_WRITER_FROM_REOPENING_AFTER_TRANSACTION_COMPLETION"
                    ),
                },
            },
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    axis_sequences = {
        "trades": q08_rows,
        "signals": [[1704067200, 1704153600, "XNGUSD.DWX"], [1704240000, 1704326400, "XNGUSD.DWX"]],
        "entries": [[0, 1704067200, "XNGUSD.DWX", "BUY", "2.5"], [1, 1704240000, "XNGUSD.DWX", "SELL", "2.7"]],
        "exits": [[0, 1704153600, "TP"], [1, 1704326400, "SL"]],
        "lots": [[0, "0.1"], [1, "0.2"]],
        "outcome_signs": [[0, 1], [1, -1]],
        "pnl": [[0, "10.5"], [1, "-2.5"]],
        "daily_mtm": daily_sequence,
        "mtm": mtm_sequence,
        "margin": margin_sequence,
    }
    return {
        "identity": {
            "q08_stream_sha256": gate.sha256_file(q08_stream),
            "runtime_log_path": str(runtime_log),
            "runtime_log_sha256": runtime_log_sha,
            "runtime_log_transaction_path": str(transaction),
            "runtime_log_transaction_sha256": gate.sha256_file(transaction),
            "runtime_telemetry_path": str(telemetry),
            "runtime_telemetry_sha256": gate.sha256_file(telemetry),
        },
        "axis_contract": _axis_contract(axis_sequences),
    }


def _receipt(
    run: str,
    sandbox: Path,
    runtime_artifacts: dict,
    manifest_path: Path,
    manifest_sha256: str,
    *,
    explicit_axes: bool = True,
) -> dict:
    card_contract = {
        "path": "D:/QM/cards/QM5_12567.md",
        "sha256": _h("card-v2"),
    }
    artifact_contract = _artifact_contract(manifest_sha256)
    expected_magic = 125670002
    expected_magic_source = {
        "authority": "HASH_BOUND_SOURCE_MANIFEST_SLEEVE",
        "field": "magic_number",
        "manifest_path": str(manifest_path.resolve()),
        "manifest_sha256": manifest_sha256,
        "sleeve_ordinal": 1,
        "promotion_identity": "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED",
        "expected_magic": expected_magic,
    }
    receipt = {
        "schema_version": 2,
        "status": "PASS",
        "technical_status": "PASS",
        "qualification_mode": gate.QUALIFICATION_MODE,
        "qualification_status": gate.SINGLE_RUN_QUALIFICATION_STATUS,
        "deployment_eligible": False,
        "artifact_source": gate.TARGET_ARTIFACT_SOURCE,
        "runner_sha256": _h("runner-v1"),
        "artifact_override_manifest": artifact_contract,
        "blockers": [],
        "job": {
            "ordinal": 1,
            "ea_id": 12567,
            "symbol": "XNGUSD.DWX",
            "timeframe": "D1",
            "variant_id": gate.VARIANT_UNSPECIFIED,
            "ea_label": "QM5_12567_cum-rsi2-commodity",
            "manifest_trades": 2,
            "expected_magic": expected_magic,
            "expected_magic_source": dict(expected_magic_source),
        },
        "card_contract": card_contract,
        "execution": {
            "sandbox": str(sandbox),
            "run": run,
            "started_utc": (
                "2026-07-16T12:00:00+00:00"
                if "120000" in run
                else "2026-07-16T13:00:00+00:00"
            ),
            "finished_utc": (
                "2026-07-16T12:10:00+00:00"
                if "120000" in run
                else "2026-07-16T13:10:00+00:00"
            ),
        },
        "cost_certified": True,
        "cost_evidence": _cost_evidence(),
        "identity": {
            **runtime_artifacts["identity"],
            "expected_magic": expected_magic,
            "expected_magic_source": dict(expected_magic_source),
            "artifact_source": gate.TARGET_ARTIFACT_SOURCE,
            "artifact_override_manifest": artifact_contract,
            "card_contract": card_contract,
            "card_contract_end": card_contract,
            "card_contract_unchanged": True,
        },
        "q08_trade_stats": {
            "trades": 2,
            "net": 12.5,
            "close_time_count": 2,
            "close_times_sha256": _h("close-times"),
        },
        "q08_signal_identity": {
            "identity_complete": True,
            "row_count": 2,
            "identity_count": 2,
            "identity_sha256": _h("signals"),
            "outcome_sign_count": 2,
            "outcome_sign_sha256": _h("outcome-signs"),
            "outcome_sign_complete": True,
        },
    }
    if explicit_axes:
        receipt["reproducibility_identity"] = runtime_artifacts["axis_contract"]
    receipt["receipt_sha256"] = gate.embedded_hash(receipt, "receipt_sha256")
    return receipt


def _summary(
    run_id: str,
    sandbox: Path,
    common_root: Path,
    summary_dir: Path,
    manifest_path: Path,
    *,
    explicit_axes: bool = True,
) -> dict:
    manifest_sha = gate.sha256_file(manifest_path)
    expected_magic_source = {
        "authority": "HASH_BOUND_SOURCE_MANIFEST_SLEEVE",
        "field": "magic_number",
        "manifest_path": str(manifest_path.resolve()),
        "manifest_sha256": manifest_sha,
        "sleeve_ordinal": 1,
        "promotion_identity": "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED",
        "expected_magic": 125670002,
    }
    runtime_artifacts = _write_runtime_artifacts(
        summary_dir
        / "runs"
        / "01_12567_XNGUSD_DWX_D1_VARIANT_UNSPECIFIED",
        run_id,
        sandbox,
        expected_magic_source,
    )
    receipt = _receipt(
        run_id,
        sandbox,
        runtime_artifacts,
        manifest_path,
        manifest_sha,
        explicit_axes=explicit_axes,
    )
    summary = {
        "schema_version": 2,
        "run_id": run_id,
        "status": "PASS",
        "technical_status": "PASS",
        "qualification_mode": gate.QUALIFICATION_MODE,
        "qualification_status": gate.SINGLE_RUN_QUALIFICATION_STATUS,
        "deployment_eligible": False,
        "canonical_live_artifacts_used": False,
        "canonical_live_root_pinned": True,
        "scope": "FULL",
        "counts": {"PASS": 1},
        "technical_counts": {"PASS": 1},
        "global_blockers": [],
        "n_jobs": 1,
        "manifest_jobs": 1,
        "manifest_sha256": manifest_sha,
        "manifest_sha256_end": manifest_sha,
        "manifest_unchanged": True,
        "runner_unchanged": True,
        "runner_sha256": _h("runner-v1"),
        "runner_sha256_start": _h("runner-v1"),
        "runner_sha256_end": _h("runner-v1"),
        "reference_snapshot_unchanged": True,
        "artifact_override_manifest_unchanged": True,
        "sandbox_derivations_unchanged": True,
        "live_source_unchanged": True,
        "common_root": str(common_root),
        "common_root_isolated_from_live": True,
        "window_contract": {
            "requested_from_date": "2017-01-01",
            "requested_to_date": "2025-12-31",
            "effective_from_date": "2017-01-01",
            "effective_to_date": "2025-12-31",
        },
        "card_contract": {
            "path": "D:/QM/cards/QM5_12567.md",
            "sha256": _h("card-v2"),
            "status": "APPROVED",
        },
        "artifact_override_manifest": _artifact_contract(manifest_sha),
        "reference_snapshot": {
            "manifest_sha256": _h("reference-manifest"),
            "source_manifest_sha256": manifest_sha,
            "entries": 1,
        },
        "execution_cost_evidence_manifest": {
            "path": "D:/QM/evidence/cost.json",
            "sha256": _h("cost-manifest-file"),
            "artifact_payload_sha256": _h("cost-manifest-payload"),
            "source_manifest_sha256": manifest_sha,
            "unchanged": True,
        },
        "cost_certified": True,
        "cost_evidence": _cost_evidence(),
        "receipts": [receipt],
    }
    summary["summary_sha256"] = gate.embedded_hash(summary, "summary_sha256")
    return summary


def _write_bound(path: Path, payload: dict) -> str:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    file_sha = gate.sha256_file(path)
    path.with_name(path.name + ".sha256").write_text(
        f"{file_sha}  {path.name}\n", encoding="utf-8"
    )
    return file_sha


def _bound_pair(tmp_path: Path, *, explicit_axes: bool = True):
    path_a = tmp_path / "summary_a" / "summary.json"
    path_b = tmp_path / "summary_b" / "summary.json"
    manifest_path = tmp_path / "source_manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "sleeves": [
                    {
                        "ea_id": 12567,
                        "ea_label": "QM5_12567_cum-rsi2-commodity",
                        "symbol": "XNGUSD.DWX",
                        "timeframe": "D1",
                        "variant_id": gate.VARIANT_UNSPECIFIED,
                        "magic_number": 125670002,
                    }
                ]
            },
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    summary_a = _summary(
        "20260716T120000Z",
        tmp_path / "run_a" / "DXZ_Truth_A",
        tmp_path / "common_a",
        path_a.parent,
        manifest_path,
        explicit_axes=explicit_axes,
    )
    summary_b = _summary(
        "20260716T130000Z",
        tmp_path / "run_b" / "DXZ_Truth_B",
        tmp_path / "common_b",
        path_b.parent,
        manifest_path,
        explicit_axes=explicit_axes,
    )
    sha_a = _write_bound(path_a, summary_a)
    sha_b = _write_bound(path_b, summary_b)
    binding_a, loaded_a, issues_a = gate.load_summary_binding("A", path_a, sha_a)
    binding_b, loaded_b, issues_b = gate.load_summary_binding("B", path_b, sha_b)
    return path_a, sha_a, binding_a, loaded_a, issues_a, path_b, sha_b, binding_b, loaded_b, issues_b


def _rehash_summary(summary: dict) -> None:
    receipt = summary["receipts"][0]
    receipt["receipt_sha256"] = gate.embedded_hash(receipt, "receipt_sha256")
    summary["summary_sha256"] = gate.embedded_hash(summary, "summary_sha256")


def _rewrite_runtime_json(summary: dict, artifact_name: str, mutate) -> dict:
    identity = summary["receipts"][0]["identity"]
    path_field, sha_field, _basename = gate.RUNTIME_ARTIFACT_FIELDS[artifact_name]
    path = Path(identity[path_field])
    payload = json.loads(path.read_text(encoding="utf-8"))
    mutate(payload)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8"
    )
    identity[sha_field] = gate.sha256_file(path)
    _rehash_summary(summary)
    return payload


def _rewrite_runtime_log_and_bind(summary: dict, mutate) -> None:
    identity = summary["receipts"][0]["identity"]
    runtime_log = Path(identity["runtime_log_path"])
    rows = [
        json.loads(line)
        for line in runtime_log.read_text(encoding="utf-8").splitlines()
    ]
    mutate(rows)
    runtime_log.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )
    log_sha = gate.sha256_file(runtime_log)
    log_size = runtime_log.stat().st_size
    identity["runtime_log_sha256"] = log_sha

    transaction = Path(identity["runtime_log_transaction_path"])
    marker = json.loads(transaction.read_text(encoding="utf-8"))
    marker["capture"]["sha256"] = log_sha
    marker["capture"]["size"] = log_size
    for field in ("candidates", "preserved_post_run_logs"):
        marker["capture"][field][0]["sha256"] = log_sha
        marker["capture"][field][0]["size"] = log_size
    transaction.write_text(
        json.dumps(marker, indent=2, sort_keys=True), encoding="utf-8"
    )
    identity["runtime_log_transaction_sha256"] = gate.sha256_file(transaction)

    telemetry = Path(identity["runtime_telemetry_path"])
    telemetry_payload = json.loads(telemetry.read_text(encoding="utf-8"))
    telemetry_payload["capture_sha256"] = log_sha
    telemetry.write_text(
        json.dumps(telemetry_payload, indent=2, sort_keys=True), encoding="utf-8"
    )
    identity["runtime_telemetry_sha256"] = gate.sha256_file(telemetry)
    _rehash_summary(summary)


def test_current_distinct_target_pair_is_physically_valid_but_axes_fail_closed(
    tmp_path: Path,
) -> None:
    (
        _path_a,
        _sha_a,
        binding_a,
        summary_a,
        issues_a,
        _path_b,
        _sha_b,
        binding_b,
        summary_b,
        issues_b,
    ) = _bound_pair(tmp_path)

    result = gate.evaluate_pair(
        binding_a, summary_a, binding_b, summary_b, [*issues_a, *issues_b]
    )

    assert result["artifact_type"] == gate.ARTIFACT_TYPE
    assert result["schema_version"] == 1
    assert result["status"] == "FAIL"
    assert result["qualification_mode"] == "TARGET_BINARY_REQUAL"
    assert result["source_manifest_sha256"] == summary_a["manifest_sha256"]
    assert result["deployment_eligible"] is False
    assert result["runner_contract_gap"] == {
        "status": "OPEN",
        "missing_required_axes": ["entries", "daily_mtm", "mtm", "margin"],
        "required_receipt_field": "reproducibility_identity",
        "note": result["runner_contract_gap"]["note"],
    }
    assert result["run_intervals"]["serial_non_overlapping"] is True
    assert {
        axis for axis, row in result["identity_axes"].items() if row["status"] == "FAIL"
    } == {"entries", "daily_mtm", "mtm", "margin"}
    runtime_bindings = result["runtime_artifact_bindings"]
    assert set(runtime_bindings) == {"summary_a", "summary_b"}
    for summary_binding in runtime_bindings.values():
        assert Path(summary_binding["runs_root"]).is_dir()
        assert len(summary_binding["receipts"]) == 1
        receipt_binding = summary_binding["receipts"][0]
        assert receipt_binding["status"] == "PASS"
        assert receipt_binding["transaction_contract_status"] == "PASS"
        assert receipt_binding["telemetry_contract_status"] == "PASS"
        assert all(
            artifact["status"] == "PASS"
            and artifact["file_sha256"] == artifact["declared_sha256"]
            for artifact in receipt_binding["artifacts"].values()
        )
    assert result["pair_payload_sha256"] == gate.embedded_hash(
        result, "pair_payload_sha256"
    )


@pytest.mark.parametrize(
    ("mode", "value"),
    [("missing", None), ("string", "125670002"), ("bool", True)],
)
def test_target_receipt_expected_magic_requires_exact_positive_integer(
    tmp_path: Path, mode: str, value
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    job = summary_a["receipts"][0]["job"]
    if mode == "missing":
        job.pop("expected_magic")
    else:
        job["expected_magic"] = value
    _rehash_summary(summary_a)
    assert summary_a["receipts"][0]["receipt_sha256"] == gate.embedded_hash(
        summary_a["receipts"][0], "receipt_sha256"
    )
    assert summary_a["summary_sha256"] == gate.embedded_hash(
        summary_a, "summary_sha256"
    )

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert result["status"] == "FAIL"
    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "EXPECTED_MAGIC_MISSING_OR_INVALID"
        in result["issues"]
    )


def test_target_receipt_identity_expected_magic_must_equal_job_magic(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    summary_a["receipts"][0]["identity"]["expected_magic"] = 15560004
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "IDENTITY_EXPECTED_MAGIC_BINDING_MISMATCH"
        in result["issues"]
    )


@pytest.mark.parametrize(
    ("field", "value", "issue_suffix"),
    [
        (
            "authority",
            "UNBOUND_MANIFEST",
            "EXPECTED_MAGIC_SOURCE_AUTHORITY_INVALID",
        ),
        ("field", "magic", "EXPECTED_MAGIC_SOURCE_FIELD_INVALID"),
        (
            "manifest_sha256",
            _h("other-source-manifest"),
            "EXPECTED_MAGIC_SOURCE_MANIFEST_SHA256_MISMATCH",
        ),
        (
            "promotion_identity",
            "1556:XAUUSD.DWX:D1:C_POLICY_REPAIR",
            "EXPECTED_MAGIC_SOURCE_PROMOTION_IDENTITY_MISMATCH",
        ),
        (
            "sleeve_ordinal",
            2,
            "EXPECTED_MAGIC_SOURCE_SLEEVE_ORDINAL_MISMATCH",
        ),
    ],
)
def test_expected_magic_source_fields_are_bound_to_summary_and_sleeve(
    tmp_path: Path, field: str, value, issue_suffix: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    receipt = summary_a["receipts"][0]
    job_source = dict(receipt["job"]["expected_magic_source"])
    job_source[field] = value
    receipt["job"]["expected_magic_source"] = job_source
    receipt["identity"]["expected_magic_source"] = dict(job_source)
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert result["status"] == "FAIL"
    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        f"{issue_suffix}"
        in result["issues"]
    )


def test_identity_expected_magic_source_must_exactly_equal_job_source(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity_source = summary_a["receipts"][0]["identity"][
        "expected_magic_source"
    ]
    identity_source["manifest_sha256"] = _h("identity-only-rebind")
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "IDENTITY_EXPECTED_MAGIC_SOURCE_BINDING_MISMATCH"
        in result["issues"]
    )


def test_expected_magic_authority_opens_and_checks_designated_manifest_sleeve(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "wrong_magic_manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "sleeves": [
                    {
                        "ea_id": 12567,
                        "symbol": "XNGUSD.DWX",
                        "timeframe": "D1",
                        "variant_id": gate.VARIANT_UNSPECIFIED,
                        "magic_number": 15560004,
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    manifest_sha = gate.sha256_file(manifest)
    job = {"ordinal": 1, "expected_magic": 125670002}
    source = {
        "manifest_path": str(manifest.resolve()),
        "manifest_sha256": manifest_sha,
        "sleeve_ordinal": 1,
    }

    issues = gate._expected_magic_manifest_issues(
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED",
        (12567, "XNGUSD.DWX", "D1", gate.VARIANT_UNSPECIFIED),
        job,
        source,
        manifest_sha,
    )

    assert any(issue.endswith("MANIFEST_SLEEVE_MAGIC_MISMATCH") for issue in issues)


def test_summary_runner_hash_chain_mismatch_fails_closed(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    summary_a["runner_sha256_end"] = _h("runner-mutated-at-end")
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert "SUMMARY_A_RUNNER_SHA256_CHAIN_MISMATCH" in result["issues"]


def test_receipt_runner_hash_must_bind_summary_runner(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    summary_a["receipts"][0]["runner_sha256"] = _h("other-runner")
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNNER_SHA256_SUMMARY_BINDING_MISMATCH"
        in result["issues"]
    )


def test_two_internally_bound_but_different_runners_fail_pair_contract(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_b = copy.deepcopy(pair[8])
    other_runner = _h("other-valid-runner")
    for field in ("runner_sha256", "runner_sha256_start", "runner_sha256_end"):
        summary_b[field] = other_runner
    summary_b["receipts"][0]["runner_sha256"] = other_runner
    _rehash_summary(summary_b)

    result = gate.evaluate_pair(pair[2], pair[3], pair[7], summary_b)

    assert "RUNNER_CONTRACT_MISMATCH" in result["issues"]
    assert result["contracts"]["runner"]["status"] == "FAIL"


@pytest.mark.parametrize(
    ("mutate", "issue_suffix"),
    [
        (
            lambda payload: payload["telemetry"].update({"status": "FAIL"}),
            "NESTED_STATUS_NOT_PASS",
        ),
        (
            lambda payload: payload["q08_binding"].update(
                {"integrity_status": "FAIL"}
            ),
            "Q08_INTEGRITY_STATUS_NOT_PASS",
        ),
    ],
)
def test_nested_runtime_telemetry_integrity_cannot_be_self_rehashed_away(
    tmp_path: Path, mutate, issue_suffix: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    _rewrite_runtime_json(summary_a, "runtime_telemetry", mutate)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        f"RUNTIME_TELEMETRY:{issue_suffix}"
        in result["issues"]
    )


def test_forged_complete_descriptor_without_complete_physical_sequence_fails(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])

    def forge_unsupported_mtm(payload: dict) -> None:
        payload["telemetry"]["mtm"] = _telemetry_descriptor([["garbage"]])

    _rewrite_runtime_json(summary_a, "runtime_telemetry", forge_unsupported_mtm)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_TELEMETRY:NESTED_SCHEMA_FIELDS_INVALID"
        in result["issues"]
    )
    assert (
        "SUMMARY_A_IDENTITY_AXIS_PHYSICAL_SEQUENCE_UNAVAILABLE:mtm:"
        "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED"
        in result["issues"]
    )


@pytest.mark.parametrize(
    "artifact_name",
    ["runtime_log", "runtime_telemetry", "runtime_log_transaction"],
)
@pytest.mark.parametrize("failure_mode", ["missing", "tampered", "hash_missing"])
def test_runtime_artifacts_fail_closed_when_missing_tampered_or_hash_unbound(
    tmp_path: Path, artifact_name: str, failure_mode: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity = summary_a["receipts"][0]["identity"]
    path_field, sha_field, _basename = gate.RUNTIME_ARTIFACT_FIELDS[artifact_name]
    path = Path(identity[path_field])
    if failure_mode == "missing":
        path.unlink()
        issue_suffix = "FILE_MISSING_OR_UNREADABLE"
    elif failure_mode == "tampered":
        path.write_bytes(path.read_bytes() + b"\nTAMPERED\n")
        issue_suffix = "FILE_SHA256_MISMATCH"
    else:
        identity.pop(sha_field)
        _rehash_summary(summary_a)
        issue_suffix = "SHA256_MISSING_OR_INVALID"

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    artifact_label = artifact_name.upper()
    expected = (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        f"{artifact_label}:{issue_suffix}"
    )
    assert result["status"] == "FAIL"
    assert expected in result["issues"]
    assert (
        result["runtime_artifact_bindings"]["summary_a"]["receipts"][0][
            "artifacts"
        ][artifact_name]["status"]
        == "FAIL"
    )


def test_relative_runtime_artifact_path_is_rejected(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    summary_a["receipts"][0]["identity"]["runtime_log_path"] = "runtime_log.jsonl"
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_LOG:PATH_NOT_ABSOLUTE"
        in result["issues"]
    )


def test_runtime_artifact_outside_summary_runs_root_is_rejected(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity = summary_a["receipts"][0]["identity"]
    outside = tmp_path / "outside" / "runtime_log.jsonl"
    outside.parent.mkdir()
    outside.write_bytes(Path(identity["runtime_log_path"]).read_bytes())
    identity["runtime_log_path"] = str(outside.resolve())
    identity["runtime_log_sha256"] = gate.sha256_file(outside)
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_LOG:PATH_OUTSIDE_OR_ESCAPES_RUNS_ROOT"
        in result["issues"]
    )


def test_runtime_artifact_overlapping_execution_sandbox_is_rejected(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    receipt = summary_a["receipts"][0]
    identity = receipt["identity"]
    sandbox_log = Path(receipt["execution"]["sandbox"]) / "runtime_log.jsonl"
    sandbox_log.write_bytes(Path(identity["runtime_log_path"]).read_bytes())
    identity["runtime_log_path"] = str(sandbox_log.resolve())
    identity["runtime_log_sha256"] = gate.sha256_file(sandbox_log)
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_LOG:PATH_OVERLAPS_EXECUTION_SANDBOX"
        in result["issues"]
    )


def test_runtime_artifact_symlink_escape_is_rejected(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity = summary_a["receipts"][0]["identity"]
    declared = Path(identity["runtime_log_path"])
    outside = tmp_path / "symlink_escape" / "runtime_log.jsonl"
    outside.parent.mkdir()
    outside.write_bytes(declared.read_bytes())
    declared.unlink()
    try:
        declared.symlink_to(outside)
    except OSError as exc:  # pragma: no cover - host policy can disable symlinks
        pytest.skip(f"symlink creation unavailable: {exc}")

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_LOG:PATH_OUTSIDE_OR_ESCAPES_RUNS_ROOT"
        in result["issues"]
    )


def test_runtime_artifacts_from_another_valid_run_dir_are_rejected(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity = summary_a["receipts"][0]["identity"]
    expected_dir = Path(identity["runtime_log_path"]).parent
    other_dir = expected_dir.parent / "02_12567_XNGUSD_DWX_D1_VARIANT_UNSPECIFIED"
    other_dir.mkdir()

    other_log = other_dir / "runtime_log.jsonl"
    other_log.write_bytes(Path(identity["runtime_log_path"]).read_bytes())
    other_telemetry = other_dir / "runtime_telemetry.json"
    other_telemetry.write_bytes(Path(identity["runtime_telemetry_path"]).read_bytes())
    transaction_payload = json.loads(
        Path(identity["runtime_log_transaction_path"]).read_text(encoding="utf-8")
    )
    transaction_payload["capture"]["evidence_path"] = str(other_log.resolve())
    other_transaction = other_dir / "runtime_log_transaction.json"
    other_transaction.write_text(
        json.dumps(transaction_payload, indent=2, sort_keys=True), encoding="utf-8"
    )
    for artifact_name, path in (
        ("runtime_log", other_log),
        ("runtime_telemetry", other_telemetry),
        ("runtime_log_transaction", other_transaction),
    ):
        path_field, sha_field, _basename = gate.RUNTIME_ARTIFACT_FIELDS[artifact_name]
        identity[path_field] = str(path.resolve())
        identity[sha_field] = gate.sha256_file(path)
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    prefix = "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
    for artifact_name in gate.RUNTIME_ARTIFACT_FIELDS:
        assert (
            f"{prefix}{artifact_name.upper()}:PARENT_NOT_EXACT_EXPECTED_RUN_DIR"
            in result["issues"]
        )


@pytest.mark.parametrize("invalid_ordinal", ["1", True, 0])
def test_runtime_artifact_binding_requires_exact_positive_integer_ordinal(
    tmp_path: Path, invalid_ordinal
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    summary_a["receipts"][0]["job"]["ordinal"] = invalid_ordinal
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "JOB_ORDINAL_MISSING_OR_INVALID"
        in result["issues"]
    )


@pytest.mark.parametrize(
    ("mutate", "issue_suffix"),
    [
        (
            lambda payload: payload.update({"status": "CAPTURE_FAILED_RESTORED"}),
            "STATUS_NOT_CAPTURED_AND_RESTORED",
        ),
        (
            lambda payload: payload["capture"].update({"status": "FAIL"}),
            "CAPTURE_STATUS_NOT_PASS",
        ),
        (
            lambda payload: payload["capture"].update({"captured": False}),
            "CAPTURE_CAPTURED_NOT_TRUE",
        ),
        (
            lambda payload: payload["capture"].update({"fresh": False}),
            "CAPTURE_FRESH_NOT_TRUE",
        ),
        (
            lambda payload: payload["capture"].update({"restored": False}),
            "CAPTURE_RESTORED_NOT_TRUE",
        ),
        (
            lambda payload: payload["capture"].update({"ambiguous": True}),
            "CAPTURE_AMBIGUOUS_NOT_FALSE",
        ),
        (
            lambda payload: payload["capture"].update({"blockers": ["FORGED"]}),
            "CAPTURE_BLOCKERS_PRESENT_OR_INVALID",
        ),
    ],
)
def test_runtime_transaction_marker_requires_exact_success_state(
    tmp_path: Path, mutate, issue_suffix: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    _rewrite_runtime_json(summary_a, "runtime_log_transaction", mutate)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        f"RUNTIME_LOG_TRANSACTION:{issue_suffix}"
        in result["issues"]
    )


@pytest.mark.parametrize(
    ("mutate", "issue_suffix"),
    [
        (
            lambda payload: payload.update({"ea_id": 1556}),
            "EA_ID_BINDING_MISMATCH",
        ),
        (
            lambda payload: payload.update(
                {"job_identity": "1556:XAUUSD.DWX:D1:C_POLICY_REPAIR"}
            ),
            "JOB_IDENTITY_BINDING_MISMATCH",
        ),
        (
            lambda payload: payload.update({"sandbox": str(Path.cwd())}),
            "SANDBOX_BINDING_MISMATCH",
        ),
        (
            lambda payload: payload["capture"].update(
                {
                    "evidence_path": payload["sandbox"]
                    + str(Path("runtime_log.jsonl"))
                }
            ),
            "CAPTURE_EVIDENCE_PATH_BINDING_MISMATCH",
        ),
        (
            lambda payload: payload["capture"].update({"sha256": _h("other-log")}),
            "CAPTURE_SHA256_BINDING_MISMATCH",
        ),
    ],
)
def test_runtime_transaction_cross_binding_is_rejected(
    tmp_path: Path, mutate, issue_suffix: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    _rewrite_runtime_json(summary_a, "runtime_log_transaction", mutate)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        f"RUNTIME_LOG_TRANSACTION:{issue_suffix}"
        in result["issues"]
    )


@pytest.mark.parametrize(
    ("mutate", "issue_suffix"),
    [
        (
            lambda payload: payload.update({"capture_sha256": _h("other-log")}),
            "CAPTURE_SHA256_BINDING_MISMATCH",
        ),
        (
            lambda payload: payload.update(
                {"job_identity": "1556:XAUUSD.DWX:D1:C_POLICY_REPAIR"}
            ),
            "JOB_IDENTITY_BINDING_MISMATCH",
        ),
    ],
)
def test_runtime_telemetry_cross_binding_is_rejected(
    tmp_path: Path, mutate, issue_suffix: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    _rewrite_runtime_json(summary_a, "runtime_telemetry", mutate)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        f"RUNTIME_TELEMETRY:{issue_suffix}"
        in result["issues"]
    )


def test_transaction_self_hash_cannot_replace_physical_file_hash(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity = summary_a["receipts"][0]["identity"]
    transaction = Path(identity["runtime_log_transaction_path"])
    payload = json.loads(transaction.read_text(encoding="utf-8"))
    payload["runtime_log_transaction_sha256"] = "0" * 64
    payload["runtime_log_transaction_sha256"] = gate.embedded_hash(
        payload, "runtime_log_transaction_sha256"
    )
    transaction.write_text(
        json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8"
    )
    identity["runtime_log_transaction_sha256"] = payload[
        "runtime_log_transaction_sha256"
    ]
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_LOG_TRANSACTION:FILE_SHA256_MISMATCH"
        in result["issues"]
    )


def test_current_receipt_fields_fail_closed_and_name_missing_identity_axes(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path, explicit_axes=False)
    result = gate.evaluate_pair(
        pair[2], pair[3], pair[7], pair[8], [*pair[4], *pair[9]]
    )

    assert result["status"] == "FAIL"
    assert result["identity_axes"]["trades"]["status"] == "FAIL"
    assert result["identity_axes"]["signals"]["status"] == "FAIL"
    assert result["identity_axes"]["outcome_signs"]["status"] == "FAIL"
    assert result["identity_axes"]["exits"]["status"] == "FAIL"
    assert result["runner_contract_gap"]["missing_required_axes"] == [
        "trades",
        "signals",
        "entries",
        "exits",
        "lots",
        "outcome_signs",
        "pnl",
        "daily_mtm",
        "mtm",
        "margin",
    ]
    assert "IDENTITY_AXIS_MISSING:mtm" in result["issues"]
    exit_partial = result["identity_axes"]["exits"]["partial_observations"]
    key = "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED"
    assert exit_partial[key]["partial_match"] is True
    assert result["compared_sleeves"][0]["variant_id"] == gate.VARIANT_UNSPECIFIED


def test_identity_mismatch_fails_even_when_both_runs_are_technical_pass(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_b = copy.deepcopy(pair[8])
    summary_b["receipts"][0]["reproducibility_identity"]["lots"]["sha256"] = _h("different-lots")
    summary_b["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        summary_b["receipts"][0], "receipt_sha256"
    )
    summary_b["summary_sha256"] = gate.embedded_hash(summary_b, "summary_sha256")

    result = gate.evaluate_pair(pair[2], pair[3], pair[7], summary_b)

    assert result["status"] == "FAIL"
    assert result["identity_axes"]["lots"]["invalid_sleeves"] == [
        "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED"
    ]
    assert (
        "SUMMARY_B_IDENTITY_AXIS_PHYSICAL_SEQUENCE_MISMATCH:lots:"
        "12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED"
        in result["issues"]
    )


def test_legacy_qualified_status_fails_closed_at_summary_and_receipt_level(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)

    forged_summary = copy.deepcopy(pair[3])
    forged_summary["qualification_status"] = "QUALIFIED"
    forged_summary["summary_sha256"] = gate.embedded_hash(
        forged_summary, "summary_sha256"
    )
    summary_result = gate.evaluate_pair(
        pair[2], forged_summary, pair[7], pair[8]
    )
    assert summary_result["status"] == "FAIL"
    assert (
        "SUMMARY_A_QUALIFICATION_STATUS_NOT_REPRODUCIBILITY_PENDING"
        in summary_result["issues"]
    )

    forged_receipt = copy.deepcopy(pair[3])
    forged_receipt["receipts"][0]["qualification_status"] = "QUALIFIED"
    forged_receipt["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        forged_receipt["receipts"][0], "receipt_sha256"
    )
    forged_receipt["summary_sha256"] = gate.embedded_hash(
        forged_receipt, "summary_sha256"
    )
    receipt_result = gate.evaluate_pair(
        pair[2], forged_receipt, pair[7], pair[8]
    )
    assert receipt_result["status"] == "FAIL"
    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "QUALIFICATION_STATUS_NOT_REPRODUCIBILITY_PENDING"
        in receipt_result["issues"]
    )


def test_same_run_or_sandbox_and_common_root_are_rejected(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_b = copy.deepcopy(pair[8])
    summary_b["run_id"] = pair[3]["run_id"]
    summary_b["common_root"] = pair[3]["common_root"]
    summary_b["receipts"][0]["execution"]["sandbox"] = pair[3]["receipts"][0]["execution"]["sandbox"]
    summary_b["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        summary_b["receipts"][0], "receipt_sha256"
    )
    summary_b["summary_sha256"] = gate.embedded_hash(summary_b, "summary_sha256")

    result = gate.evaluate_pair(pair[2], pair[3], pair[7], summary_b)

    assert result["status"] == "FAIL"
    assert "RUN_ID_NOT_DISTINCT" in result["issues"]
    assert "RUN_SANDBOXES_NOT_ISOLATED" in result["issues"]
    assert "RUN_COMMON_ROOTS_NOT_ISOLATED" in result["issues"]


@pytest.mark.parametrize(
    ("common_owner", "use_nested_path", "expected_issue"),
    [
        (
            "A",
            False,
            "SUMMARY_A_COMMON_ROOT_OVERLAPS_SUMMARY_B_SANDBOX",
        ),
        (
            "A",
            True,
            "SUMMARY_A_COMMON_ROOT_OVERLAPS_SUMMARY_B_SANDBOX",
        ),
        (
            "B",
            False,
            "SUMMARY_B_COMMON_ROOT_OVERLAPS_SUMMARY_A_SANDBOX",
        ),
        (
            "B",
            True,
            "SUMMARY_B_COMMON_ROOT_OVERLAPS_SUMMARY_A_SANDBOX",
        ),
    ],
)
def test_cross_run_common_root_and_sandbox_overlap_is_rejected(
    tmp_path: Path,
    common_owner: str,
    use_nested_path: bool,
    expected_issue: str,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    summary_b = copy.deepcopy(pair[8])

    if common_owner == "A":
        common = Path(summary_a["common_root"])
        summary_b["receipts"][0]["execution"]["sandbox"] = str(
            common / "nested" if use_nested_path else common
        )
        changed_summary = summary_b
    else:
        common = Path(summary_b["common_root"])
        summary_a["receipts"][0]["execution"]["sandbox"] = str(
            common / "nested" if use_nested_path else common
        )
        changed_summary = summary_a

    changed_summary["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        changed_summary["receipts"][0], "receipt_sha256"
    )
    changed_summary["summary_sha256"] = gate.embedded_hash(
        changed_summary, "summary_sha256"
    )

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], summary_b)

    assert result["status"] == "FAIL"
    assert expected_issue in result["issues"]


def test_designated_target_runs_must_be_serial_not_overlapping(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_b = copy.deepcopy(pair[8])
    summary_b["receipts"][0]["execution"].update(
        {
            "started_utc": "2026-07-16T12:05:00+00:00",
            "finished_utc": "2026-07-16T12:20:00+00:00",
        }
    )
    summary_b["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        summary_b["receipts"][0], "receipt_sha256"
    )
    summary_b["summary_sha256"] = gate.embedded_hash(
        summary_b, "summary_sha256"
    )

    result = gate.evaluate_pair(pair[2], pair[3], pair[7], summary_b)

    assert result["status"] == "FAIL"
    assert result["run_intervals"]["serial_non_overlapping"] is False
    assert "DESIGNATED_RUN_INTERVALS_OVERLAP" in result["issues"]


def test_missing_variant_is_rejected_instead_of_defaulted(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_b = copy.deepcopy(pair[8])
    summary_b["receipts"][0]["job"].pop("variant_id")
    summary_b["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        summary_b["receipts"][0], "receipt_sha256"
    )
    summary_b["summary_sha256"] = gate.embedded_hash(summary_b, "summary_sha256")

    result = gate.evaluate_pair(pair[2], pair[3], pair[7], summary_b)

    assert result["status"] == "FAIL"
    assert "SUMMARY_B_RECEIPT_SLEEVE_KEY_INVALID" in result["issues"]
    assert "COMPARED_SLEEVE_SET_MISMATCH" in result["issues"]


def test_different_variant_ids_are_strictly_separate_sleeves(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary_b = copy.deepcopy(pair[8])
    summary_b["receipts"][0]["job"]["variant_id"] = "C_POLICY_REPAIR"
    summary_b["receipts"][0]["receipt_sha256"] = gate.embedded_hash(
        summary_b["receipts"][0], "receipt_sha256"
    )
    summary_b["summary_sha256"] = gate.embedded_hash(summary_b, "summary_sha256")

    result = gate.evaluate_pair(pair[2], pair[3], pair[7], summary_b)

    assert result["status"] == "FAIL"
    assert "COMPARED_SLEEVE_SET_MISMATCH" in result["issues"]
    assert [row["variant_id"] for row in result["compared_sleeves"]] == [
        "C_POLICY_REPAIR",
        gate.VARIANT_UNSPECIFIED,
    ]


def test_file_hash_and_sidecar_bindings_fail_closed(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    binding, payload, issues = gate.load_summary_binding(
        "A", pair[0], "0" * 64
    )
    assert payload is not None
    assert binding["file_sha256"] == pair[1]
    assert "SUMMARY_A_FILE_SHA256_MISMATCH" in issues
    assert "SUMMARY_A_SIDECAR_EXPECTED_SHA256_MISMATCH" in issues


def test_summary_binding_below_tier_root_is_rejected(tmp_path: Path) -> None:
    tier = tmp_path / "T1" / "reports"
    tier.mkdir(parents=True)
    path = tier / "summary.json"
    manifest_path = tmp_path / "tier_source_manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "sleeves": [
                    {
                        "ea_id": 12567,
                        "symbol": "XNGUSD.DWX",
                        "timeframe": "D1",
                        "variant_id": gate.VARIANT_UNSPECIFIED,
                        "magic_number": 125670002,
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    payload = _summary(
        "20260716T120000Z",
        tmp_path / "run_a" / "DXZ_Truth_A",
        tmp_path / "common_a",
        path.parent,
        manifest_path,
    )
    file_sha = _write_bound(path, payload)

    _binding, _payload, issues = gate.load_summary_binding(
        "A", path, file_sha
    )

    assert "SUMMARY_A_PATH_BELOW_TIER_OR_LIVE_ROOT" in issues


def test_full_manifest_requires_exact_receipt_sleeve_set(tmp_path: Path) -> None:
    manifest = tmp_path / "two_sleeves.json"
    manifest.write_text(
        json.dumps(
            {
                "sleeves": [
                    {
                        "ea_id": 12567,
                        "ea_label": "QM5_12567_cum-rsi2-commodity",
                        "symbol": "XNGUSD.DWX",
                        "timeframe": "D1",
                        "variant_id": gate.VARIANT_UNSPECIFIED,
                        "magic_number": 125670002,
                    },
                    {
                        "ea_id": 1556,
                        "ea_label": "QM5_1556_xau",
                        "symbol": "XAUUSD.DWX",
                        "timeframe": "D1",
                        "variant_id": "C_POLICY_REPAIR",
                        "magic_number": 15560004,
                    },
                ]
            },
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    summary = _summary(
        "20260716T120000Z",
        tmp_path / "sandbox",
        tmp_path / "common",
        tmp_path / "summary",
        manifest,
    )

    receipts, issues = gate.validate_summary("A", summary)

    assert len(receipts) == 1
    assert "SUMMARY_A_FULL_MANIFEST_RECEIPT_SET_MISMATCH" in issues
    assert "SUMMARY_A_N_JOBS_NOT_EXACT_MANIFEST_COUNT" in issues
    assert "SUMMARY_A_MANIFEST_JOBS_NOT_EXACT_MANIFEST_COUNT" in issues

    fake_key = (1556, "XAUUSD.DWX", "D1", "C_POLICY_REPAIR")
    receipt_set = dict(receipts)
    receipt_set[fake_key] = {
        "job": {
            "ordinal": 2,
            "expected_magic_source": {
                "manifest_path": str(manifest.resolve())
            },
        }
    }
    direct_issues = gate._full_manifest_receipt_issues(
        "SUMMARY_A", summary, receipt_set
    )
    assert "SUMMARY_A_FULL_MANIFEST_RECEIPT_SET_MISMATCH" not in direct_issues
    receipt_set[(9999, "EURUSD.DWX", "H1", "C_EXTRA")] = {
        "job": {
            "ordinal": 3,
            "expected_magic_source": {
                "manifest_path": str(manifest.resolve())
            },
        }
    }
    extra_receipt_issues = gate._full_manifest_receipt_issues(
        "SUMMARY_A", summary, receipt_set
    )
    assert "SUMMARY_A_FULL_MANIFEST_RECEIPT_SET_MISMATCH" in extra_receipt_issues


@pytest.mark.parametrize(
    "mutation",
    [
        lambda payload: payload["q08_binding"].update({"status": "FAIL"}),
        lambda payload: payload["q08_binding"].update(
            {"blockers": ["CRITICAL"]}
        ),
        lambda payload: payload["q08_binding"].update(
            {"expected_magic_valid": False}
        ),
        lambda payload: payload["q08_binding"].update(
            {"entries_complete": True, "entry_axis_reasons": ["JOIN_FAILED"]}
        ),
        lambda payload: payload["q08_binding"].update(
            {"exit_axis_reasons": ["JOIN_FAILED"]}
        ),
    ],
)
def test_q08_binding_self_report_cannot_be_rehashed_into_acceptance(
    tmp_path: Path, mutation
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    _rewrite_runtime_json(summary_a, "runtime_telemetry", mutation)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert (
        "SUMMARY_A_RECEIPT:12567:XNGUSD.DWX:D1:VARIANT_UNSPECIFIED:"
        "RUNTIME_TELEMETRY:Q08_BINDING_CONTRACT_MISMATCH"
        in result["issues"]
    )


@pytest.mark.parametrize("field", ["equity", "mtm", "margin"])
def test_garbage_runtime_sequence_never_becomes_a_complete_physical_axis(
    tmp_path: Path, field: str
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])

    def forge(payload: dict) -> None:
        payload["telemetry"][field] = _telemetry_descriptor([["garbage"]])

    _rewrite_runtime_json(summary_a, "runtime_telemetry", forge)
    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    expected_issue = (
        "EQUITY_PHYSICAL_REDERIVATION_MISMATCH"
        if field == "equity"
        else "NESTED_SCHEMA_FIELDS_INVALID"
    )
    assert any(expected_issue in issue for issue in result["issues"])
    axis = "daily_mtm" if field == "equity" else field
    binding = result["runtime_artifact_bindings"]["summary_a"]["receipts"][0]
    assert binding["physical_axis_descriptors"][axis]["complete"] is False


def test_telemetry_exit_and_magic_claims_are_rederived_from_physical_log(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])

    def forge(payload: dict) -> None:
        exits = payload["telemetry"]["exits"]["sequence"]
        for row in exits:
            row[3] = "FORGED"
        payload["telemetry"]["exits"]["sha256"] = gate.canonical_json_sha(exits)
        for row in payload["q08_binding"]["enriched_rows"]:
            row["exit_reason"] = "FORGED"
        payload["telemetry"]["identity"]["magic"] = 999
        payload["telemetry"]["identity"]["magic_unique"] = False
        payload["q08_binding"]["observed_magic"] = 999

    _rewrite_runtime_json(summary_a, "runtime_telemetry", forge)
    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert any(
        "EXITS_PHYSICAL_REDERIVATION_MISMATCH" in issue
        for issue in result["issues"]
    )
    assert any("IDENTITY_BINDING_MISMATCH" in issue for issue in result["issues"])
    assert any(
        "Q08_BINDING_CONTRACT_MISMATCH" in issue for issue in result["issues"]
    )


@pytest.mark.parametrize(
    "forged_value",
    [pytest.param("0.1", id="numeric_string"), pytest.param(True, id="bool"), pytest.param(float("inf"), id="nonfinite")],
)
def test_runtime_log_numeric_fields_use_runner_exact_types(
    tmp_path: Path, forged_value
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])

    def forge(rows: list[dict]) -> None:
        entry = next(row for row in rows if row.get("event") == "ENTRY_ACCEPTED")
        entry["payload"]["lots"] = forged_value

    _rewrite_runtime_log_and_bind(summary_a, forge)
    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert any(
        "RUNTIME_LOG_ENTRY_SCHEMA_INVALID" in issue
        or "RUNTIME_LOG_JSON_INVALID" in issue
        for issue in result["issues"]
    )


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("ea_id", "12567"),
        ("symbol", " xngusd.dwx "),
        ("symbol", "XNGUSD"),
        ("timeframe", "d1"),
        ("timeframe", "D2"),
    ],
)
def test_receipt_job_identity_requires_raw_canonical_types(
    tmp_path: Path, field: str, value
) -> None:
    pair = _bound_pair(tmp_path)
    summary = copy.deepcopy(pair[3])
    summary["receipts"][0]["job"][field] = value
    _rehash_summary(summary)

    _receipts, issues = gate.validate_summary("A", summary)

    assert "SUMMARY_A_RECEIPT_SLEEVE_KEY_INVALID" in issues


@pytest.mark.parametrize(
    ("field", "value"),
    [("symbol", "XNGUSD"), ("timeframe", "D2"), ("host_timeframe", "D2")],
)
def test_manifest_identity_uses_runner_symbol_and_timeframe_grammar(
    field: str, value: str
) -> None:
    sleeve = {
        "ea_id": 12567,
        "symbol": "XNGUSD.DWX",
        "timeframe": "D1",
        "variant_id": gate.VARIANT_UNSPECIFIED,
    }
    sleeve[field] = value

    assert gate._manifest_sleeve_identity(sleeve) is None


def test_full_summary_counts_reject_bool_as_integer(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    summary = copy.deepcopy(pair[3])
    summary["n_jobs"] = True
    summary["manifest_jobs"] = True
    summary["counts"] = {"PASS": True}
    summary["technical_counts"] = {"PASS": True}
    _rehash_summary(summary)

    _receipts, issues = gate.validate_summary("A", summary)

    assert "SUMMARY_A_FULL_JOB_COUNT_MISMATCH" in issues
    assert "SUMMARY_A_COUNTS_NOT_ALL_PASS" in issues
    assert "SUMMARY_A_TECHNICAL_COUNTS_NOT_ALL_PASS" in issues


def test_outer_summary_duplicate_json_key_is_rejected(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    path = pair[0]
    text = path.read_text(encoding="utf-8")
    assert text.count('"scope": "FULL"') == 1
    path.write_text(
        text.replace('"scope": "FULL"', '"scope": "BAD",\n  "scope": "FULL"'),
        encoding="utf-8",
    )
    file_sha = gate.sha256_file(path)
    path.with_name(path.name + ".sha256").write_text(
        f"{file_sha}  {path.name}\n", encoding="utf-8"
    )

    _binding, payload, issues = gate.load_summary_binding("A", path, file_sha)

    assert payload is None
    assert "SUMMARY_A_JSON_INVALID" in issues


@pytest.mark.parametrize(
    "mutation",
    [
        lambda marker: marker["capture"].update({"late_rescans": 0}),
        lambda marker: marker["capture"]["post_restore_quiescence"].update(
            {"confirmed": False}
        ),
        lambda marker: marker["capture"].update(
            {"restore_errors": ["FORGED"]}
        ),
    ],
)
def test_runtime_transaction_hardening_fields_fail_closed(
    tmp_path: Path, mutation
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    _rewrite_runtime_json(summary_a, "runtime_log_transaction", mutation)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    transaction = result["runtime_artifact_bindings"]["summary_a"]["receipts"][0]
    assert transaction["transaction_contract_status"] == "FAIL"


def test_multiple_or_internally_ambiguous_axis_declarations_fail_closed(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    receipt = summary_a["receipts"][0]
    receipt["identity_axes"] = {
        "trades": {"complete": True, "count": 2, "sha256": _h("forged")}
    }
    receipt["reproducibility_identity"]["signals"]["row_count"] = 2
    receipt["reproducibility_identity"]["signals"]["sequence_sha256"] = (
        receipt["reproducibility_identity"]["signals"]["sha256"]
    )
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert "IDENTITY_AXIS_INVALID:trades" in result["issues"]
    assert "IDENTITY_AXIS_INVALID:signals" in result["issues"]


def test_q08_wrapper_cannot_duplicate_or_override_payload_identity(
    tmp_path: Path,
) -> None:
    pair = _bound_pair(tmp_path)
    summary_a = copy.deepcopy(pair[3])
    identity = summary_a["receipts"][0]["identity"]
    q08_path = Path(identity["q08_stream_path"] if "q08_stream_path" in identity else Path(identity["runtime_log_path"]).parent / "q08_stream.jsonl")
    rows = [json.loads(line) for line in q08_path.read_text(encoding="utf-8").splitlines()]
    rows[0]["payload"] = {"symbol": "FORGED"}
    q08_path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )
    identity["q08_stream_sha256"] = gate.sha256_file(q08_path)
    _rehash_summary(summary_a)

    result = gate.evaluate_pair(pair[2], summary_a, pair[7], pair[8])

    assert any("Q08_STREAM_EVENT_INVALID_AT_LINE:1" in issue for issue in result["issues"])


def test_cli_writes_immutable_hashed_output_and_refuses_overwrite(tmp_path: Path) -> None:
    pair = _bound_pair(tmp_path)
    output = tmp_path / "pair_gate.json"
    args = [
        "--summary-a",
        str(pair[0]),
        "--summary-a-sha256",
        pair[1],
        "--summary-b",
        str(pair[5]),
        "--summary-b-sha256",
        pair[6],
        "--output",
        str(output),
    ]

    assert gate.main(args) == 2
    payload = json.loads(output.read_text(encoding="utf-8"))
    assert payload["status"] == "FAIL"
    sidecar = output.with_name(output.name + ".sha256")
    assert sidecar.read_text(encoding="utf-8").split()[0] == gate.sha256_file(output)
    assert gate.main(args) == 3


@pytest.mark.parametrize("tier", ["T_Live", "T1", "T10"])
def test_output_guard_refuses_tier_and_live_paths(
    tmp_path: Path, tier: str
) -> None:
    parent = tmp_path / tier / "reports"
    parent.mkdir(parents=True)

    with pytest.raises(PermissionError, match="T_Live or T1-T10"):
        gate.write_immutable_result(
            parent / "pair.json",
            {"status": "FAIL", "pair_payload_sha256": "0" * 64},
        )
