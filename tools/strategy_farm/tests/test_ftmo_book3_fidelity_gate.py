from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import ftmo_book3_fidelity_gate as gate


SOURCE_COMMIT = "a" * 40


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _execution_rows(tmp_path: Path) -> tuple[list[dict], list[dict], str]:
    raw = []
    normalized = []
    for index in range(gate.EXPECTED_EXECUTION_INPUT_COUNT):
        role = f"role:{index:03d}"
        path = str((tmp_path / "execution_inputs" / f"input_{index:03d}.bin").resolve())
        digest = f"{index:064x}"
        byte_count = index
        raw.append({"role": role, "path": path, "sha256": digest, "bytes": byte_count})
        normalized.append(
            {
                "index": index,
                "valid": True,
                "role": role,
                "path": path,
                "expected_sha256": digest,
                "actual_sha256": digest,
                "expected_bytes": byte_count,
                "actual_bytes": byte_count,
                "actual_resolved_path": path,
            }
        )
    return raw, normalized, gate._canonical_sha(raw)


def _source_binding(tmp_path: Path, spec: gate.OperandSpec) -> dict:
    result = {
        "requested": True,
        "valid": True,
        "errors": [],
        "authoritative_source_commit": SOURCE_COMMIT,
        "controller_head_commit": SOURCE_COMMIT,
        "actual_head_commit": SOURCE_COMMIT,
        "measurement_rung": spec.rung,
        "measurement_sequence": spec.sequence,
        "evidence_run_id": spec.evidence_run_id,
    }
    for index, role in enumerate(
        (
            "framework_include_tree",
            "preregistration",
            "isolated_runner",
            "terminal_worker",
            "preparation_controller",
        )
    ):
        digest = f"{900 + index:064x}"
        result[role] = {
            "path": str((tmp_path / "source" / role).resolve()),
            "expected_sha256": digest,
            "actual_sha256": digest,
        }
        if role == "framework_include_tree":
            result[role]["file_count"] = 91
    direct_hashes = {
        "preregistration": result["preregistration"]["actual_sha256"],
        "isolated_runner": result["isolated_runner"]["actual_sha256"],
        "terminal_worker": result["terminal_worker"]["actual_sha256"],
        "preparation_controller": result["preparation_controller"]["actual_sha256"],
        "fidelity_gate": _sha(Path(gate.__file__).resolve()),
        "fidelity_comparator": _sha(gate.DEFAULT_COMPARATOR),
    }
    raw_sources = []
    for index, role in enumerate(sorted(gate.RUNTIME_SOURCE_ROLES)):
        path = (
            Path(gate.__file__).resolve()
            if role == "fidelity_gate"
            else gate.DEFAULT_COMPARATOR
            if role == "fidelity_comparator"
            else Path(result[role]["path"])
            if role in result
            else (tmp_path / "source" / f"runtime_{role}").resolve()
        )
        raw_sources.append(
            {
                "role": role,
                "path": str(path),
                "sha256": direct_hashes.get(role, f"{1000 + index:064x}"),
                "bytes": path.stat().st_size
                if role in {"fidelity_gate", "fidelity_comparator"}
                else 100 + index,
            }
        )
    normalized_sources = [
        {
            "index": index,
            "valid": True,
            "role": row["role"],
            "path": row["path"],
            "expected_sha256": row["sha256"],
            "actual_sha256": row["sha256"],
            "expected_bytes": row["bytes"],
            "actual_bytes": row["bytes"],
            "actual_resolved_path": row["path"],
        }
        for index, row in enumerate(raw_sources)
    ]
    result["runtime_sources"] = {
        "requested": True,
        "valid": True,
        "errors": [],
        "artifacts": normalized_sources,
        "canonical_sha256": gate._canonical_sha(raw_sources),
        "git_clean": {"valid": True, "error": None, "porcelain": ""},
    }
    return result


def _fingerprint(raw: bytes) -> dict:
    return {
        "exists": True,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "bytes": len(raw),
        "lines": len(raw.splitlines()),
        "mtime_ns": 123,
    }


def _trade_row(
    spec: gate.OperandSpec,
    *,
    net: str = "10.00",
    volume: str = "0.10",
    overrides: dict | None = None,
) -> dict:
    net_value = float(net)
    row = {
        "event": "TRADE_CLOSED",
        "magic": spec.trade_magic,
        "symbol": spec.trade_symbol,
        "side": "BUY",
        "entry_price": "100.1250000000000000",
        "exit_price": "101.3750000000000000",
        "entry_time": 100,
        "time": 200,
        "profit": net_value + 2.0,
        "swap": 0.0,
        "fee": 0.0,
        "entry_commission": -1.0,
        "exit_commission": -1.0,
        "commission": -2.0,
        "net": net_value,
        "mae_acct": -5.0,
        "volume": float(volume),
        "notional": 10_000.0,
    }
    if spec.role == "standalone":
        row["money_basis"] = gate.FULL_LIFECYCLE_MONEY_BASIS
    else:
        row.update(
            {
                "schema_version": 2,
                "run_id": spec.evidence_run_id,
                "producer_version": gate.JOINT_PRODUCER_VERSION,
                "position_fully_closed": True,
                "position_id": 123_456,
                "entry_deal_ids": [7001],
                "exit_deal_ids": [7002],
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.0},
                    {"deal_id": 7002, "time": 200, "component": "PROFIT", "amount": net_value + 2.0},
                    {"deal_id": 7002, "time": 200, "component": "SWAP", "amount": 0.0},
                    {"deal_id": 7002, "time": 200, "component": "COMMISSION", "amount": -1.0},
                    {"deal_id": 7002, "time": 200, "component": "FEE", "amount": 0.0},
                ],
            }
        )
    if overrides:
        row.update(overrides)
    return row


def _trade_line(
    spec: gate.OperandSpec,
    *,
    net: str = "10.00",
    volume: str = "0.10",
    overrides: dict | None = None,
) -> bytes:
    return (
        json.dumps(
            _trade_row(spec, net=net, volume=volume, overrides=overrides),
            separators=(",", ":"),
        )
        + "\n"
    ).encode()


def _stream_contract(
    tmp_path: Path,
    work_id: str,
    spec: gate.OperandSpec,
    raw: bytes,
    *,
    preflight: bool,
) -> dict:
    source = str((tmp_path / "file_common" / "q08_trades" / f"{spec.source_stem}.jsonl").resolve())
    target = tmp_path / "reports" / work_id / f"q08_trades_{spec.source_stem}.timer_v2.jsonl"
    target.parent.mkdir(parents=True, exist_ok=True)
    if not preflight:
        target.write_bytes(raw)
    base = {
        "requested": True,
        "valid": True,
        "stream_type": "q08_trades",
        "source": source,
        "target": str(target.resolve()),
    }
    if preflight:
        base.update(
            {
                "errors": [],
                "pre_run_source": {"exists": False},
                "pre_v2_capture": {},
            }
        )
    else:
        fingerprint = _fingerprint(raw)
        base.update(
            {
                "post_run_source": fingerprint,
                "staged": fingerprint,
                "post_stage_source": fingerprint,
                "harvested": fingerprint,
                "publication": {
                    "published_targets": [str(target.resolve())],
                    "published_before_rollback": [],
                    "rollback_attempted": False,
                },
            }
        )
    return base


def _joint_stream_contract(
    tmp_path: Path,
    work_id: str,
    spec: gate.OperandSpec,
    raw: bytes,
    *,
    preflight: bool,
) -> dict:
    trade = _stream_contract(tmp_path, work_id, spec, raw, preflight=preflight)
    equity_source = str((tmp_path / "file_common" / "q08_equity" / "20181_USDJPY_DWX.jsonl").resolve())
    equity_target = str(
        (tmp_path / "reports" / work_id / "q08_equity_20181_USDJPY_DWX.timer_v2.jsonl").resolve()
    )
    equity = {
        "requested": True,
        "valid": True,
        "stream_type": "q08_equity",
        "source": equity_source,
        "target": equity_target,
    }
    if preflight:
        equity.update({"pre_run_source": {"exists": False}, "pre_v2_capture": {}})
    else:
        equity.update(
            {
                "post_run_source": _fingerprint(b"{}\n"),
                "staged": _fingerprint(b"{}\n"),
                "post_stage_source": _fingerprint(b"{}\n"),
                "harvested": _fingerprint(b"{}\n"),
            }
        )
    result = {
        "requested": True,
        "valid": True,
        "mode": "atomic_multi",
        "errors": [],
        "streams": [trade, equity],
    }
    if not preflight:
        result["publication"] = {
            "published_targets": [trade["target"], equity_target],
            "published_before_rollback": [],
            "rollback_attempted": False,
        }
        trade.pop("publication")
    return result


def _runner_receipt(
    tmp_path: Path,
    spec: gate.OperandSpec,
    execution_rows: list[dict],
    execution_identity: str,
    raw: bytes,
    *,
    ordinal: int,
) -> dict:
    work_id = f"00000000-0000-4000-8000-{ordinal:012d}"
    payload_sha = f"{100 + ordinal:064x}"
    post_payload_sha = payload_sha
    terminal_worker_sha = f"{903:064x}"
    source_binding = _source_binding(tmp_path, spec)
    execution_observations = [
        {
            "role": row["role"],
            "path": row["path"],
            "resolved_path": row["actual_resolved_path"],
            "sha256": row["actual_sha256"],
            "bytes": row["actual_bytes"],
        }
        for row in execution_rows
    ]
    observed_execution_identity = gate._canonical_sha(execution_observations)
    stage = int(spec.rung[1])
    prior_fidelity = {
        "requested": stage > 0,
        "required": stage > 0,
        "required_stage": stage - 1 if stage > 0 else None,
        "valid": True,
        "errors": [],
    }
    if stage > 0:
        prior_fidelity.update(
            {
                "path": str((tmp_path / f"stage_{stage - 1}_fidelity.json").resolve()),
                "actual_sha256": f"{500 + stage:064x}",
                "bytes": 500 + stage,
            }
        )
    post_fidelity = copy.deepcopy(prior_fidelity)
    if stage > 0:
        post_fidelity.update(
            {
                "post_sha256": prior_fidelity["actual_sha256"],
                "post_bytes": prior_fidelity["bytes"],
            }
        )
    pre_stream = (
        _joint_stream_contract(tmp_path, work_id, spec, raw, preflight=True)
        if spec.role == "joint"
        else _stream_contract(tmp_path, work_id, spec, raw, preflight=True)
    )
    post_stream = (
        _joint_stream_contract(tmp_path, work_id, spec, raw, preflight=False)
        if spec.role == "joint"
        else _stream_contract(tmp_path, work_id, spec, raw, preflight=False)
    )
    artifacts = []
    for index, role in enumerate(("setfile", "staged_ex5", "mq5")):
        digest = f"{200 + ordinal * 10 + index:064x}"
        artifacts.append(
            {
                "role": role,
                "path": str((tmp_path / "artifacts" / f"{spec.rung}_{role}").resolve()),
                "expected_sha256": digest,
                "actual_sha256": digest,
                "valid": True,
            }
        )
    worker_path = str((tmp_path / "source" / "terminal_worker").resolve())
    evidence_path = (tmp_path / "reports" / work_id / "q02_worker_evidence.json").resolve()
    evidence_path.write_bytes(b'{"verdict":"PASS"}\n')
    evidence_sha = _sha(evidence_path)
    success_checks = {key: True for key in gate.SUCCESS_CHECK_KEYS}
    return {
        "schema_version": 1,
        "mode": "apply",
        "state": "completed",
        "success": True,
        "success_checks": success_checks,
        "started_at_utc": f"2026-07-29T00:{ordinal * 2:02d}:00+00:00",
        "completed_at_utc": f"2026-07-29T00:{ordinal * 2 + 1:02d}:00+00:00",
        "terminal": "T10",
        "work_item_id": work_id,
        "worker_exit_code": 0,
        "factory_off_sha256": "f" * 64,
        "live_scope_touched": False,
        "autotrading_touched": False,
        "preflight": {
            "valid": True,
            "errors": [],
            "terminal": "T10",
            "factory_off_sha256": "f" * 64,
            "work_item_id": work_id,
            "work_item": {
                "ea_id": spec.ea_id,
                "symbol": spec.work_symbol,
                "phase": "Q02",
                "status": "pending",
                "claimed_by": None,
                "measurement_rung": spec.rung,
                "measurement_sequence": spec.sequence,
                "evidence_run_id": spec.evidence_run_id,
                "payload_sha256": payload_sha,
            },
            "source_binding": source_binding,
            "artifacts": artifacts,
            "execution_inputs": {
                "requested": True,
                "valid": True,
                "errors": [],
                "expected_count": gate.EXPECTED_EXECUTION_INPUT_COUNT,
                "artifacts": copy.deepcopy(execution_rows),
                "canonical_sha256": execution_identity,
                "observed_bundle_sha256": observed_execution_identity,
            },
            "fidelity_receipt": prior_fidelity,
            "post_run_stream": pre_stream,
            "worker_script": worker_path,
            "worker_sha256": terminal_worker_sha,
        },
        "process_tree_containment": {"attempted": True, "valid": True, "actions": []},
        "post_run_quiescence": {"valid": True, "before": [], "after": []},
        "post_execution_inputs": {
            "requested": True,
            "valid": True,
            "errors": [],
            "expected_count": gate.EXPECTED_EXECUTION_INPUT_COUNT,
            "artifacts": copy.deepcopy(execution_rows),
            "canonical_sha256": execution_identity,
            "observed_bundle_sha256": observed_execution_identity,
            "pre_observed_bundle_sha256": observed_execution_identity,
        },
        "post_runtime_sources": copy.deepcopy(source_binding["runtime_sources"]),
        "payload_contract_revalidation": {
            "requested": True,
            "valid": True,
            "errors": [],
            "pre_payload_sha256": payload_sha,
            "post_payload_sha256": post_payload_sha,
            "changed_immutable_keys": [],
            "removed_immutable_keys": [],
            "unexpected_added_runtime_keys": [],
        },
        "post_fidelity_receipt": post_fidelity,
        "post_run_stream": post_stream,
        "post_evidence": {
            "path": str(evidence_path),
            "resolved_path": str(evidence_path),
            "sha256": evidence_sha,
            "bytes": evidence_path.stat().st_size,
            "valid": True,
            "errors": [],
        },
        "post_work_item": {
            "id": work_id,
            "status": "done",
            "verdict": "PASS",
            "claimed_by": None,
            "evidence_path": str(evidence_path),
        },
        "pre_payload_sha256": payload_sha,
        "post_payload_sha256": post_payload_sha,
    }


def _write_json(path: Path, value: dict) -> str:
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    return _sha(path)


def _case(tmp_path: Path, stage: int, *, standalone_raw: bytes | None = None, joint_raw: bytes | None = None):
    spec = gate.STAGES[stage]
    _raw_rows, execution_rows, execution_identity = _execution_rows(tmp_path)
    standalone = _runner_receipt(
        tmp_path,
        spec.standalone,
        execution_rows,
        execution_identity,
        standalone_raw or _trade_line(spec.standalone),
        ordinal=stage * 2,
    )
    joint = _runner_receipt(
        tmp_path,
        spec.joint,
        execution_rows,
        execution_identity,
        joint_raw or _trade_line(spec.joint),
        ordinal=stage * 2 + 1,
    )
    standalone_path = tmp_path / f"R{stage}.receipt.json"
    joint_path = tmp_path / f"J{stage}.receipt.json"
    standalone_sha = _write_json(standalone_path, standalone)
    joint_sha = _write_json(joint_path, joint)
    comparator_sha = _sha(gate.DEFAULT_COMPARATOR)
    kwargs = {
        "stage": stage,
        "standalone_receipt_path": standalone_path.resolve(),
        "expected_standalone_receipt_sha256": standalone_sha,
        "joint_receipt_path": joint_path.resolve(),
        "expected_joint_receipt_sha256": joint_sha,
        "expected_source_commit": SOURCE_COMMIT,
        "expected_execution_input_artifacts_sha256": execution_identity,
        "expected_controller_sha256": _sha(Path(gate.__file__).resolve()),
        "comparator_path": gate.DEFAULT_COMPARATOR,
        "expected_comparator_sha256": comparator_sha,
    }
    return kwargs, standalone, joint


@pytest.mark.parametrize("stage", [0, 1, 2])
def test_passes_each_exact_stage_contract(tmp_path, stage):
    kwargs, _standalone, _joint = _case(tmp_path, stage)

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "PASS"
    assert result["schema"] == "qm.ftmo-book3-fidelity-adjudication-receipt/v2"
    assert result["stage"] == stage
    assert result["work_item_ids"] == {
        "standalone": result["operands"]["standalone"]["work_item_id"],
        "joint": result["operands"]["joint"]["work_item_id"],
    }
    assert result["source_commit"] == SOURCE_COMMIT
    assert (
        result["execution_input_artifacts_sha256"]
        == kwargs["expected_execution_input_artifacts_sha256"]
    )
    assert result["controller_path"] == str(Path(gate.__file__).resolve())
    assert result["controller_sha256"] == kwargs["expected_controller_sha256"]
    assert result["isolated_runner_sha256"] == f"{902:064x}"
    assert result["preparation_controller_sha256"] == f"{904:064x}"
    assert result["comparator_sha256"] == kwargs["expected_comparator_sha256"]
    assert result["adjudication_id"] == gate._adjudication_id(result)
    assert result["contract"]["measurement_contract"] == (
        "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET"
    )
    assert result["contract"]["money_basis"] == gate.FULL_LIFECYCLE_MONEY_BASIS
    assert result["contract"]["price_tolerance"] == 0.0
    assert result["comparison"] == {
        "algorithm": "maximum_bipartite_exact_time_side_price_full_lifecycle_money_volume/v3",
        "money_basis": gate.FULL_LIFECYCLE_MONEY_BASIS,
        "money_tolerance": 0.005,
        "volume_tolerance": 0.005,
        "price_tolerance": 0.0,
        "standalone_trades": 1,
        "joint_trades": 1,
        "matched": 1,
        "unmatched_standalone": 0,
        "unmatched_joint": 0,
        "match_rate": 1.0,
        "unmatched_standalone_sample": [],
        "unmatched_joint_sample": [],
    }


def test_tolerance_is_inclusive_but_above_tolerance_fails(tmp_path):
    stage = 0
    spec = gate.STAGES[stage]
    kwargs, _, _ = _case(
        tmp_path / "inclusive",
        stage,
        standalone_raw=_trade_line(spec.standalone, net="10.000", volume="0.100"),
        joint_raw=_trade_line(spec.joint, net="10.005", volume="0.105"),
    )
    assert gate.adjudicate(**kwargs)["verdict"] == "PASS"

    kwargs, _, _ = _case(
        tmp_path / "above",
        stage,
        standalone_raw=_trade_line(spec.standalone, net="10.000", volume="0.100"),
        joint_raw=_trade_line(spec.joint, net="10.006", volume="0.100"),
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "FAIL"
    assert result["comparison"]["match_rate"] == 0.0
    assert result["comparison"]["unmatched_standalone"] == 1
    assert result["comparison"]["unmatched_joint"] == 1


def test_missing_standalone_money_basis_is_setup_blocked(tmp_path):
    spec = gate.STAGES[0]
    row = _trade_row(spec.standalone)
    row.pop("money_basis")
    kwargs, _, _ = _case(
        tmp_path,
        0,
        standalone_raw=(json.dumps(row, separators=(",", ":")) + "\n").encode(),
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "SETUP_BLOCKED"
    assert "standalone money_basis mismatch" in result["errors"][0]


@pytest.mark.parametrize("role", ["standalone", "joint"])
def test_missing_fee_is_setup_blocked(tmp_path, role):
    spec = gate.STAGES[0]
    operand = spec.standalone if role == "standalone" else spec.joint
    row = _trade_row(operand)
    row.pop("fee")
    raw = (json.dumps(row, separators=(",", ":")) + "\n").encode()
    kwargs, _, _ = _case(
        tmp_path,
        0,
        standalone_raw=raw if role == "standalone" else None,
        joint_raw=raw if role == "joint" else None,
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "SETUP_BLOCKED"
    assert f"{role} trade line 1 fee is missing" in result["errors"][0]


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"commission": -3.0}, "commission components do not reconcile"),
        ({"net": 9.0}, "full-lifecycle net does not reconcile"),
    ],
)
def test_inconsistent_full_lifecycle_components_are_setup_blocked(
    tmp_path, overrides, message
):
    spec = gate.STAGES[0]
    kwargs, _, _ = _case(
        tmp_path,
        0,
        standalone_raw=_trade_line(spec.standalone, overrides=overrides),
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "SETUP_BLOCKED"
    assert message in result["errors"][0]


def test_consistent_but_different_money_components_fail_fidelity(tmp_path):
    spec = gate.STAGES[0]
    kwargs, _, _ = _case(
        tmp_path,
        0,
        joint_raw=_trade_line(
            spec.joint,
            overrides={
                "entry_commission": -1.006,
                "exit_commission": -0.994,
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.006},
                    {"deal_id": 7002, "time": 200, "component": "PROFIT", "amount": 12.0},
                    {"deal_id": 7002, "time": 200, "component": "SWAP", "amount": 0.0},
                    {"deal_id": 7002, "time": 200, "component": "COMMISSION", "amount": -0.994},
                    {"deal_id": 7002, "time": 200, "component": "FEE", "amount": 0.0},
                ],
            },
        ),
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "FAIL"
    assert result["comparison"]["algorithm"].endswith("/v3")
    assert result["comparison"]["money_basis"] == gate.FULL_LIFECYCLE_MONEY_BASIS
    assert result["comparison"]["match_rate"] == 0.0


@pytest.mark.parametrize("missing_key", ["run_id", "position_id", "entry_deal_ids", "exit_deal_ids", "balance_events"])
def test_joint_v2_run_id_and_lineage_are_mandatory(tmp_path, missing_key):
    spec = gate.STAGES[0]
    row = _trade_row(spec.joint)
    row.pop(missing_key)
    kwargs, _, _ = _case(
        tmp_path,
        0,
        joint_raw=(json.dumps(row, separators=(",", ":")) + "\n").encode(),
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "SETUP_BLOCKED"
    assert missing_key in result["errors"][0]


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("side", "SELL"),
        ("entry_price", "100.1250000000000001"),
        ("exit_price", "101.3750000000000001"),
    ],
)
def test_side_or_any_price_drift_fails_exact_fidelity(tmp_path, field, value):
    spec = gate.STAGES[0]
    kwargs, _, _ = _case(
        tmp_path,
        0,
        joint_raw=_trade_line(spec.joint, overrides={field: value}),
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "FAIL"
    assert result["comparison"]["price_tolerance"] == 0.0
    assert result["comparison"]["match_rate"] == 0.0


@pytest.mark.parametrize("role", ["standalone", "joint"])
def test_noncanonical_side_is_setup_blocked(tmp_path, role):
    spec = gate.STAGES[0]
    operand = spec.standalone if role == "standalone" else spec.joint
    raw = _trade_line(operand, overrides={"side": "buy"})
    kwargs, _, _ = _case(
        tmp_path,
        0,
        standalone_raw=raw if role == "standalone" else None,
        joint_raw=raw if role == "joint" else None,
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "SETUP_BLOCKED"
    assert "side must be canonical BUY or SELL" in result["errors"][0]


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"position_id": 0}, "position_id must be positive"),
        ({"position_id": True}, "position_id must be an integer"),
        ({"entry_deal_ids": [7001, 7001]}, "contains duplicate deal IDs"),
        ({"exit_deal_ids": [7001]}, "entry/exit deal IDs overlap"),
        ({"entry_deal_ids": [0]}, "must contain only positive integers"),
        ({"balance_events": []}, "must be a non-empty array"),
        (
            {
                "balance_events": [
                    {
                        "deal_id": 7001,
                        "time": 100,
                        "component": "COMMISSION",
                        "amount": -1.0,
                        "extra": True,
                    }
                ]
            },
            "fields mismatch",
        ),
        (
            {
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "PROFIT", "amount": -1.0}
                ]
            },
            "entry component invalid",
        ),
        (
            {
                "balance_events": [
                    {
                        "deal_id": 7001,
                        "time": 100,
                        "component": "COMMISSION",
                        "amount": "-1.0",
                    }
                ]
            },
            "amount must be a JSON number",
        ),
        (
            {
                "balance_events": [
                    {"deal_id": 9999, "time": 100, "component": "COMMISSION", "amount": -1.0}
                ]
            },
            "outside declared lineage",
        ),
        (
            {
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.0},
                    {"deal_id": 7002, "time": 199, "component": "PROFIT", "amount": 12.0},
                    {"deal_id": 7002, "time": 199, "component": "SWAP", "amount": 0.0},
                    {"deal_id": 7002, "time": 199, "component": "COMMISSION", "amount": -1.0},
                    {"deal_id": 7002, "time": 199, "component": "FEE", "amount": 0.0},
                ]
            },
            "final exit deal does not establish close time",
        ),
        (
            {
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -0.99},
                    {"deal_id": 7002, "time": 200, "component": "PROFIT", "amount": 12.0},
                    {"deal_id": 7002, "time": 200, "component": "SWAP", "amount": 0.0},
                    {"deal_id": 7002, "time": 200, "component": "COMMISSION", "amount": -1.0},
                    {"deal_id": 7002, "time": 200, "component": "FEE", "amount": 0.0},
                ]
            },
            "does not reconcile",
        ),
    ],
)
def test_joint_lineage_is_strict_and_money_reconciled(tmp_path, overrides, message):
    spec = gate.STAGES[0]
    kwargs, _, _ = _case(
        tmp_path,
        0,
        joint_raw=_trade_line(spec.joint, overrides=overrides),
    )

    result = gate.adjudicate(**kwargs)

    assert result["verdict"] == "SETUP_BLOCKED"
    assert message in result["errors"][0]


def test_joint_lineage_accepts_ordered_partial_exit_events():
    spec = gate.STAGES[0]
    partial_events = [
        {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.0},
        {"deal_id": 7002, "time": 150, "component": "PROFIT", "amount": 5.0},
        {"deal_id": 7002, "time": 150, "component": "SWAP", "amount": 0.0},
        {"deal_id": 7002, "time": 150, "component": "COMMISSION", "amount": -0.4},
        {"deal_id": 7002, "time": 150, "component": "FEE", "amount": 0.0},
        {"deal_id": 7003, "time": 200, "component": "PROFIT", "amount": 7.0},
        {"deal_id": 7003, "time": 200, "component": "SWAP", "amount": 0.0},
        {"deal_id": 7003, "time": 200, "component": "COMMISSION", "amount": -0.6},
        {"deal_id": 7003, "time": 200, "component": "FEE", "amount": 0.0},
    ]
    row = _trade_row(
        spec.joint,
        overrides={
            "exit_deal_ids": [7002, 7003],
            "balance_events": partial_events,
        },
    )
    money = gate._full_lifecycle_money(row, spec=spec.joint, label="joint fixture")

    gate._validate_joint_lineage(
        row,
        money,
        label="joint fixture",
        entry_time=100,
        close_time=200,
    )


def test_empty_filtered_operand_is_setup_blocked(tmp_path):
    kwargs, _, _ = _case(tmp_path, 0, joint_raw=b'{"event":"META"}\n')
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "empty filtered operand" in result["errors"][0]


def test_receipt_hash_tamper_is_setup_blocked(tmp_path):
    kwargs, _, _ = _case(tmp_path, 0)
    kwargs["joint_receipt_path"].write_bytes(kwargs["joint_receipt_path"].read_bytes() + b" ")
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "receipt SHA-256 mismatch" in result["errors"][0]


def test_harvest_hash_tamper_is_setup_blocked(tmp_path):
    kwargs, _, joint = _case(tmp_path, 0)
    trade = next(row for row in joint["post_run_stream"]["streams"] if row["stream_type"] == "q08_trades")
    Path(trade["target"]).write_bytes(Path(trade["target"]).read_bytes() + b" ")
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "harvested q08_trades SHA-256 mismatch" in result["errors"][0]


def test_spliced_source_vintage_is_setup_blocked(tmp_path):
    kwargs, _standalone, joint = _case(tmp_path, 0)
    row = joint["preflight"]["source_binding"]["preregistration"]
    row["expected_sha256"] = row["actual_sha256"] = "c" * 64
    kwargs["expected_joint_receipt_sha256"] = _write_json(kwargs["joint_receipt_path"], joint)
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "direct/runtime-source binding mismatch" in result["errors"][0]


def test_cross_rung_or_sequence_receipt_is_setup_blocked(tmp_path):
    kwargs, _standalone, joint = _case(tmp_path, 1)
    joint["preflight"]["work_item"]["measurement_sequence"] = 5
    kwargs["expected_joint_receipt_sha256"] = _write_json(kwargs["joint_receipt_path"], joint)
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "sequence mismatch" in result["errors"][0]


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [("status", "failed", "not done"), ("verdict", "FAIL", "not PASS")],
)
def test_post_work_item_must_be_done_pass(tmp_path, field, value, message):
    kwargs, standalone, _joint = _case(tmp_path, 0)
    standalone["post_work_item"][field] = value
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert message in result["errors"][0]


def test_completed_success_contract_is_mandatory(tmp_path):
    kwargs, standalone, _joint = _case(tmp_path, 0)
    standalone["success_checks"].pop("runtime_sources_unchanged")
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "success_checks keyset/value contract mismatch" in result["errors"][0]


def test_post_execution_and_runtime_revalidation_are_mandatory(tmp_path):
    kwargs, standalone, _joint = _case(tmp_path / "execution", 0)
    standalone["post_execution_inputs"]["observed_bundle_sha256"] = "0" * 64
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "observed execution-input bundle hash is inconsistent" in result["errors"][0]

    kwargs, standalone, _joint = _case(tmp_path / "runtime", 0)
    standalone["post_runtime_sources"]["canonical_sha256"] = "0" * 64
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "runtime sources manifest hash is inconsistent" in result["errors"][0]


def test_payload_evidence_and_quiescence_are_revalidated(tmp_path):
    kwargs, standalone, _joint = _case(tmp_path / "payload", 0)
    standalone["payload_contract_revalidation"]["changed_immutable_keys"] = ["model"]
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "changed_immutable_keys is not empty" in result["errors"][0]

    kwargs, standalone, _joint = _case(tmp_path / "evidence", 0)
    Path(standalone["post_evidence"]["path"]).write_bytes(b"tampered\n")
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "post evidence SHA-256 mismatch" in result["errors"][0]

    kwargs, standalone, _joint = _case(tmp_path / "quiescence", 0)
    standalone["post_run_quiescence"]["after"] = [{"ProcessId": 123}]
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "process census is not empty" in result["errors"][0]


def test_prior_stage_fidelity_receipt_must_remain_unchanged(tmp_path):
    kwargs, standalone, _joint = _case(tmp_path, 1)
    standalone["post_fidelity_receipt"]["post_sha256"] = "0" * 64
    kwargs["expected_standalone_receipt_sha256"] = _write_json(
        kwargs["standalone_receipt_path"], standalone
    )
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "prior fidelity receipt changed during run" in result["errors"][0]


def test_spliced_execution_input_identity_is_setup_blocked(tmp_path):
    kwargs, _standalone, joint = _case(tmp_path, 0)
    rows = joint["preflight"]["execution_inputs"]["artifacts"]
    rows[0]["expected_sha256"] = rows[0]["actual_sha256"] = "d" * 64
    reconstructed = [
        {
            "role": row["role"],
            "path": row["path"],
            "sha256": row["actual_sha256"],
            "bytes": row["actual_bytes"],
        }
        for row in rows
    ]
    joint["preflight"]["execution_inputs"]["canonical_sha256"] = gate._canonical_sha(reconstructed)
    kwargs["expected_joint_receipt_sha256"] = _write_json(kwargs["joint_receipt_path"], joint)
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "execution-input identity mismatch" in result["errors"][0]


def test_duplicate_receipt_key_is_setup_blocked(tmp_path):
    kwargs, _, _ = _case(tmp_path, 0)
    duplicate = b'{"schema_version":1,"schema_version":1}\n'
    kwargs["standalone_receipt_path"].write_bytes(duplicate)
    kwargs["expected_standalone_receipt_sha256"] = hashlib.sha256(duplicate).hexdigest()
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "duplicate JSON key" in result["errors"][0]


def test_duplicate_jsonl_key_is_setup_blocked(tmp_path):
    spec = gate.STAGES[0]
    raw = (
        b'{"event":"TRADE_CLOSED","magic":99360000,"magic":99360000,'
        b'"symbol":"USDJPY.DWX","entry_time":100,"time":200,"net":10,"volume":0.1}\n'
    )
    kwargs, _, _ = _case(tmp_path, 0, standalone_raw=raw, joint_raw=_trade_line(spec.joint))
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "duplicate JSON key" in result["errors"][0]


def test_comparator_requires_both_canonical_path_and_exact_hash(tmp_path):
    kwargs, _, _ = _case(tmp_path / "hash", 0)
    kwargs["expected_comparator_sha256"] = "0" * 64
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "fidelity comparator SHA-256 mismatch" in result["errors"][0]

    kwargs, _, _ = _case(tmp_path / "path", 0)
    copied = (tmp_path / "path" / "copied_compare_joint_replay.py").resolve()
    copied.write_bytes(gate.DEFAULT_COMPARATOR.read_bytes())
    kwargs["comparator_path"] = copied
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "fidelity comparator path mismatch" in result["errors"][0]


def test_gate_controller_self_hash_is_mandatory(tmp_path):
    kwargs, _, _ = _case(tmp_path, 0)
    kwargs["expected_controller_sha256"] = "0" * 64
    result = gate.adjudicate(**kwargs)
    assert result["verdict"] == "SETUP_BLOCKED"
    assert "fidelity gate controller SHA-256 mismatch" in result["errors"][0]


def test_each_harvested_jsonl_is_read_exactly_once(tmp_path, monkeypatch):
    kwargs, standalone, joint = _case(tmp_path, 0)
    standalone_target = Path(standalone["post_run_stream"]["target"]).resolve()
    joint_target = Path(
        next(row for row in joint["post_run_stream"]["streams"] if row["stream_type"] == "q08_trades")["target"]
    ).resolve()
    counts = {standalone_target: 0, joint_target: 0}
    original = Path.read_bytes

    def counted(self):
        resolved = self.resolve()
        if resolved in counts:
            counts[resolved] += 1
        return original(self)

    monkeypatch.setattr(Path, "read_bytes", counted)
    assert gate.adjudicate(**kwargs)["verdict"] == "PASS"
    assert counts == {standalone_target: 1, joint_target: 1}


def test_cli_writes_canonical_create_only_receipt_and_never_overwrites(tmp_path):
    kwargs, _, _ = _case(tmp_path, 0)
    output = (tmp_path / "adjudication.json").resolve()
    argv = [
        "--stage", "0",
        "--standalone-receipt", str(kwargs["standalone_receipt_path"]),
        "--expected-standalone-receipt-sha256", kwargs["expected_standalone_receipt_sha256"],
        "--joint-receipt", str(kwargs["joint_receipt_path"]),
        "--expected-joint-receipt-sha256", kwargs["expected_joint_receipt_sha256"],
        "--expected-source-commit", SOURCE_COMMIT,
        "--expected-execution-input-artifacts-sha256", kwargs["expected_execution_input_artifacts_sha256"],
        "--expected-controller-sha256", kwargs["expected_controller_sha256"],
        "--comparator-path", str(gate.DEFAULT_COMPARATOR),
        "--expected-comparator-sha256", kwargs["expected_comparator_sha256"],
        "--receipt-out", str(output),
    ]
    assert gate.main(argv) == 0
    first = output.read_bytes()
    decoded = json.loads(first)
    assert decoded["verdict"] == "PASS"
    assert first == gate._canonical_bytes(decoded)

    assert gate.main(argv) == 4
    assert output.read_bytes() == first
