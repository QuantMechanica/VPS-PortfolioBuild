from __future__ import annotations

import copy
import hashlib
import json
import sys
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Callable

import pytest


TOOLS = Path(__file__).resolve().parents[1] / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import adjudicate_dev as adjudicator  # noqa: E402
import research_evidence_io as evidence_io  # noqa: E402


CREATED_UTC = "2026-07-20T00:00:00Z"
FREEZE_SHA = "a" * 64
MANIFEST_SHA = "b" * 64


def _write_bytes(path: Path, payload: bytes) -> evidence_io.FileBinding:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return evidence_io.file_binding(path)


def _write_json(
    path: Path,
    payload: dict[str, Any],
    *,
    detached: bool = False,
    bare_detached: bool = False,
) -> evidence_io.FileBinding:
    binding = _write_bytes(path, evidence_io.canonical_json_bytes(payload))
    if detached:
        sidecar = Path(f"{path}.sha256")
        sidecar_payload = (
            f"{binding.sha256}\n".encode("ascii")
            if bare_detached
            else evidence_io.detached_bytes(binding.sha256, path.name)
        )
        _write_bytes(sidecar, sidecar_payload)
    return binding


def _file_binding(path: Path) -> dict[str, Any]:
    return evidence_io.file_binding(path).as_dict()


def _raw_position(
    *,
    symbol: str,
    sequence: int,
    broker_entry: datetime,
    adjusted_net: Decimal,
) -> dict[str, Any]:
    external = Decimal("10.00")
    raw_net = adjusted_net + external
    exit_time = broker_entry + timedelta(minutes=30)
    return {
        "sequence": sequence,
        "entry_deals": [f"{symbol}-{sequence}-entry"],
        "exit_deal": f"{symbol}-{sequence}-exit",
        "symbol": symbol,
        "side": "buy" if sequence % 2 else "sell",
        "volume": "1",
        "entry_times": [broker_entry.strftime("%Y-%m-%dT%H:%M:%S")],
        "exit_time": exit_time.strftime("%Y-%m-%dT%H:%M:%S"),
        "raw_net_usd": f"{raw_net:.2f}",
        "swap_usd": "0.00",
        "entry_external_cost_usd": "5.00",
        "exit_external_cost_usd": "5.00",
        "external_cost_usd": "10.00",
        "cost_adjusted_net_usd": f"{adjusted_net:.2f}",
    }


def _default_positions(key: adjudicator.CellKey) -> list[dict[str, Any]]:
    if key.market.symbol == "GDAXI.DWX":
        return []
    rows: list[dict[str, Any]] = []
    years = key.market.years
    sequence = 0
    for year in years:
        for ordinal in range(5):
            sequence += 1
            # Broker minus seven hours is the frozen New-York conversion.  09:00
            # broker is London 02:00 NY; 14:00 broker is New York 07:00 NY.
            hour = 9 if ordinal % 2 == 0 else 14
            month = 11 if year == 2017 else 6
            adjusted = Decimal("-100.00") if ordinal == 4 else Decimal("400.00")
            rows.append(
                _raw_position(
                    symbol=key.market.symbol,
                    sequence=sequence,
                    broker_entry=datetime(year, month, ordinal + 1, hour, 0, 0),
                    adjusted_net=adjusted,
                )
            )
    return rows


def _metrics(positions: list[dict[str, Any]]) -> dict[str, Any]:
    nets = [Decimal(row["cost_adjusted_net_usd"]) for row in positions]
    gross_profit = sum((max(value, Decimal(0)) for value in nets), Decimal(0))
    gross_loss = sum((min(value, Decimal(0)) for value in nets), Decimal(0))
    net = sum(nets, Decimal(0))
    external = sum((Decimal(row["external_cost_usd"]) for row in positions), Decimal(0))
    balance = Decimal("100000.00")
    peak = balance
    maximum_drawdown = Decimal(0)
    for value in nets:
        balance += value
        peak = max(peak, balance)
        maximum_drawdown = max(maximum_drawdown, peak - balance)
    if gross_loss < 0:
        profit_factor: str | None = format(
            (gross_profit / -gross_loss).quantize(
                Decimal("0.00000001"), rounding=ROUND_HALF_UP
            ),
            ".8f",
        )
        state = "FINITE"
    elif gross_profit > 0:
        profit_factor = None
        state = "INFINITE_NO_LOSSES"
    else:
        profit_factor = None
        state = "UNDEFINED_NO_PROFIT_OR_LOSS"
    return {
        "closed_positions": len(positions),
        "trading_deals": len(positions) * 2,
        "external_cost_total_usd": f"{external:.2f}",
        "cost_adjusted_net_profit_usd": f"{net:.2f}",
        "cost_adjusted_gross_profit_usd": f"{gross_profit:.2f}",
        "cost_adjusted_gross_loss_usd": f"{gross_loss:.2f}",
        "cost_adjusted_profit_factor": profit_factor,
        "cost_adjusted_profit_factor_state": state,
        "final_closed_balance_usd": f"{balance:.2f}",
        "max_cumulative_closed_balance_drawdown_usd": f"{maximum_drawdown:.2f}",
        "max_cumulative_closed_balance_drawdown_percent": "0.100000",
    }


PositionTransform = Callable[
    [adjudicator.CellKey, list[dict[str, Any]]], list[dict[str, Any]]
]
PayloadMutator = Callable[[adjudicator.CellKey, dict[str, Any]], None]


def _make_bundle(
    tmp_path: Path,
    *,
    position_transform: PositionTransform | None = None,
    duplicate_mutator: PayloadMutator | None = None,
    pointer_mutator: PayloadMutator | None = None,
    omit: set[str] | None = None,
    extra_pointer: bool = False,
) -> adjudicator.Policy:
    pointer_root = tmp_path / "pointers"
    receipt_root = tmp_path / "receipts"
    output_root = tmp_path / "published"
    tool_path = receipt_root / "common_toolchain" / "runner.exe"
    _write_bytes(tool_path, b"same immutable toolchain for all 52 cells\n")
    toolchain = {"runner": _file_binding(tool_path)}
    omitted = omit or set()

    for key in adjudicator.expected_cells():
        if key.cell_id in omitted:
            continue
        cell_root = (
            receipt_root
            / key.safe_symbol
            / key.market.timeframe
            / key.variant
        )
        cell_root.mkdir(parents=True, exist_ok=True)
        positions = _default_positions(key)
        if position_transform is not None:
            positions = position_transform(key, copy.deepcopy(positions))

        raw_reports: list[Path] = []
        for run_index in range(2):
            report_path = cell_root / f"raw_report_{run_index}.htm"
            _write_bytes(
                report_path,
                f"native report bytes may differ for semantic duplicate {run_index}\n".encode(),
            )
            raw_reports.append(report_path)

        deal_hash = hashlib.sha256(f"deal|{key.cell_id}".encode()).hexdigest()
        run_hash = hashlib.sha256(f"run|{key.cell_id}".encode()).hexdigest()
        audit_reports: list[dict[str, Any]] = []
        for run_index, report_path in enumerate(raw_reports):
            audit_reports.append(
                {
                    "schema_version": 1,
                    "artifact_type": "QM5_20009_DEV1_MT5_REPORT_COST_AUDIT",
                    "status": "PASS",
                    "report": {
                        "path": str(report_path.resolve()),
                        "sha256": evidence_io.sha256_file(report_path),
                        "encoding_contract": "UTF8_OR_UTF16_MT5_HTML",
                    },
                    "header": {
                        "symbol": key.market.symbol,
                        "timeframe": key.market.timeframe,
                        "from_date": key.market.from_date,
                        "to_date": key.market.to_date,
                        "initial_deposit": "100000.00",
                        "currency": "USD",
                    },
                    "identity": {
                        "canonical_deal_sequence_sha256": deal_hash,
                        "run_fingerprint_sha256": run_hash,
                    },
                    "closed_positions": copy.deepcopy(positions),
                    "metrics": _metrics(positions),
                    "same_day_swap_proof": {
                        "status": (
                            "PASS"
                            if positions
                            else "NOT_APPLICABLE_NO_CLOSED_POSITIONS"
                        )
                    },
                }
            )
        cost_audit = {
            "schema_version": 1,
            "artifact_type": adjudicator.COST_AUDIT_TYPE,
            "status": "PASS",
            "duplicate_count": 2,
            "duplicate_fingerprint_check": "PASS",
            "canonical_deal_sequence_sha256": deal_hash,
            "run_fingerprint_sha256": run_hash,
            "reports": audit_reports,
        }
        if duplicate_mutator is not None:
            duplicate_mutator(key, cost_audit)
        cost_audit_path = cell_root / "cost_audit.json"
        _write_json(cost_audit_path, cost_audit)

        runner_summary = {
            "result": "PASS",
            "symbol": key.market.symbol,
            "period": key.market.timeframe,
            "model": 4,
            "requested_runs": 2,
            "deterministic": True,
            "model4_log_marker_detected": True,
            "oninit_failure_detected": False,
            "log_bomb_detected": False,
            "runs": [
                {
                    "status": "OK",
                    "real_ticks_marker": True,
                    "report_canonical_path": str(report_path.resolve()),
                    "native_max_equity_drawdown_usd": "1000.00",
                }
                for report_path in raw_reports
            ],
        }
        runner_summary_path = cell_root / "runner_summary.json"
        _write_json(runner_summary_path, runner_summary)

        scalar_files: dict[str, Path] = {
            "validator_pre": cell_root / "validator_pre.json",
            "validator_post": cell_root / "validator_post.json",
            "runner_result": cell_root / "runner_result.json",
        }
        for name, path in scalar_files.items():
            _write_json(path, {"artifact": name, "status": "PASS"})
        tester_inis: list[Path] = []
        tester_logs: list[Path] = []
        for run_index in range(2):
            ini = cell_root / f"tester_{run_index}.ini"
            log = cell_root / f"tester_{run_index}.log"
            _write_bytes(ini, f"[Tester]\nrun={run_index}\n".encode())
            _write_bytes(log, f"real ticks run {run_index}\n".encode())
            tester_inis.append(ini)
            tester_logs.append(log)

        artifacts = {
            "validator_pre": _file_binding(scalar_files["validator_pre"]),
            "validator_post": _file_binding(scalar_files["validator_post"]),
            "runner_result": _file_binding(scalar_files["runner_result"]),
            "runner_summary": _file_binding(runner_summary_path),
            "cost_audit": _file_binding(cost_audit_path),
            "raw_reports": [_file_binding(path) for path in raw_reports],
            "tester_inis": [_file_binding(path) for path in tester_inis],
            "tester_logs": [_file_binding(path) for path in tester_logs],
        }
        receipt = {
            "schema_version": 1,
            "artifact_type": adjudicator.LAUNCHER_RECEIPT_TYPE,
            "status": "PASS",
            "created_utc": CREATED_UTC,
            "run_id": hashlib.sha256(key.cell_id.encode()).hexdigest()[:20],
            "protocol_id": adjudicator.DEFAULT_PROTOCOL_ID,
            "request": {
                "phase": "DEV",
                **adjudicator.expected_request(key),
                "infrastructure_only": False,
            },
            "fixed_tester_contract": {
                "model": 4,
                "initial_deposit": 100000,
                "currency": "USD",
                "commission_per_lot": 0,
                "commission_per_side_native": 0,
                "terminal_entrypoint": "run_dev1_backtest.ps1",
                "direct_terminal_start_forbidden": True,
            },
            "evidence_policy": {
                "separate_recorded_phase_verdict_is_required": True,
                "verdict": "NOT_ADJUDICATED",
            },
            "freeze_identity": {
                "freeze_inputs_sha256": FREEZE_SHA,
                "manifest_sha256": MANIFEST_SHA,
                "set_sha256": hashlib.sha256(f"set|{key.cell_id}".encode()).hexdigest(),
                "selected_data_sha256": "c" * 64,
                "phase_unlock_records": [],
                "postflight_exact_match": True,
            },
            "duplicate_identity": {
                "required_runs": 2,
                "canonical_deal_sequence_sha256": deal_hash,
                "run_fingerprint_sha256": run_hash,
                "duplicate_fingerprint_check": "PASS",
            },
            "toolchain": toolchain,
            "artifacts": artifacts,
        }
        receipt_path = cell_root / "research_receipt.json"
        receipt_binding = _write_json(receipt_path, receipt, detached=True)
        receipt_sidecar = evidence_io.file_binding(Path(f"{receipt_path}.sha256"))
        pointer = {
            "schema_version": 1,
            "artifact_type": adjudicator.POINTER_TYPE,
            "protocol_id": adjudicator.DEFAULT_PROTOCOL_ID,
            "phase_id": "DEV",
            "cell_id": key.cell_id,
            "selection_role": key.market.selection_role,
            "request": adjudicator.expected_request(key),
            "receipt": {
                "path": receipt_binding.path,
                "size_bytes": receipt_binding.size_bytes,
                "sha256": receipt_binding.sha256,
                "sidecar_path": receipt_sidecar.path,
                "sidecar_file_sha256": receipt_sidecar.sha256,
            },
            "published_utc": CREATED_UTC,
        }
        if pointer_mutator is not None:
            pointer_mutator(key, pointer)
        _write_json(key.pointer_path(pointer_root), pointer, detached=True)

    if extra_pointer:
        _write_json(
            pointer_root / "DEV" / "EXTRA" / "M1" / "center.pointer.json",
            {"not": "an allowed matrix cell"},
            detached=True,
        )
    return adjudicator.Policy(
        pointer_root=pointer_root,
        receipt_root=receipt_root,
        output_root=output_root,
        freeze_inputs_sha256=FREEZE_SHA,
        manifest_sha256=MANIFEST_SHA,
    )


def _inventory_and_evaluation(
    policy: adjudicator.Policy,
) -> tuple[adjudicator.Inventory, adjudicator.Evaluation]:
    inventory = adjudicator.build_inventory(policy, created_utc=CREATED_UTC)
    return inventory, adjudicator.evaluate_inventory(inventory, created_utc=CREATED_UTC)


def test_strict_json_and_canonical_hash_contract(tmp_path: Path) -> None:
    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text('{"x":1,"x":2}', encoding="utf-8")
    with pytest.raises(evidence_io.EvidenceIOError, match="duplicate JSON key"):
        evidence_io.load_json_strict(duplicate)

    nonfinite = tmp_path / "nonfinite.json"
    nonfinite.write_text('{"x":NaN}', encoding="utf-8")
    with pytest.raises(evidence_io.EvidenceIOError, match="non-finite"):
        evidence_io.load_json_strict(nonfinite)

    left = {"z": [2, 1], "a": {"b": True}}
    right = {"a": {"b": True}, "z": [2, 1]}
    assert evidence_io.canonical_payload_sha256(left) == evidence_io.canonical_payload_sha256(right)
    assert evidence_io.canonical_json_bytes(left) == evidence_io.canonical_json_bytes(right)


def test_decimal_profit_factor_floor_is_pinned_and_inclusive() -> None:
    assert str(adjudicator.profit_factor_floor(30)) == (
        "2.0024168054612880603701325484402220513649467340400"
    )
    assert str(adjudicator.profit_factor_floor(60)) == (
        "1.6418303327350409139896728798923596474268488881887"
    )
    exact = adjudicator.Metrics(30, Decimal(1), Decimal(1), Decimal(-1), Decimal(0), adjudicator.profit_factor_floor(30), "FINITE")
    below = adjudicator.Metrics(30, Decimal(1), Decimal(1), Decimal(-1), Decimal(0), adjudicator.profit_factor_floor(30) - Decimal("1e-48"), "FINITE")
    assert adjudicator._pf_at_least(exact, adjudicator.profit_factor_floor(30))
    assert not adjudicator._pf_at_least(below, adjudicator.profit_factor_floor(30))


def test_complete_52_cell_inventory_passes_and_duplicates_count_once(tmp_path: Path) -> None:
    policy = _make_bundle(tmp_path)
    inventory, evaluation = _inventory_and_evaluation(policy)
    assert len(inventory.cells) == 52
    assert inventory.payload["matrix_contract"] == {
        "markets": [market.symbol for market in adjudicator.MARKETS],
        "variants": list(adjudicator.VARIANTS),
        "expected_cells": 52,
        "observed_cells": 52,
        "required_semantic_duplicate_runs_per_cell": 2,
        "duplicate_runs_counted_for_merit": 1,
    }
    assert evaluation.status == "PASS"
    gates = evaluation.payload["binding_gates"]
    assert gates["sleeve_a_center"]["metrics"]["trades"] == 10
    assert gates["sleeve_b_center"]["metrics"]["trades"] == 60
    assert all(
        row["metrics"]["trades"] == 0
        for row in evaluation.payload["transport_diagnostic"]["variants"]
    )


@pytest.mark.parametrize("mode", ["missing", "extra"])
def test_inventory_rejects_missing_or_extra_pointer(tmp_path: Path, mode: str) -> None:
    first = adjudicator.expected_cells()[0]
    policy = _make_bundle(
        tmp_path,
        omit={first.cell_id} if mode == "missing" else None,
        extra_pointer=mode == "extra",
    )
    with pytest.raises(adjudicator.AdjudicationError, match="pointer matrix mismatch"):
        adjudicator.build_inventory(policy, created_utc=CREATED_UTC)


def test_pointer_schema_is_exact_and_receipt_graph_is_hash_bound(tmp_path: Path) -> None:
    first_id = adjudicator.expected_cells()[0].cell_id

    def add_unknown(key: adjudicator.CellKey, pointer: dict[str, Any]) -> None:
        if key.cell_id == first_id:
            pointer["unknown"] = "forbidden"

    policy = _make_bundle(tmp_path / "schema", pointer_mutator=add_unknown)
    with pytest.raises(adjudicator.AdjudicationError, match="key mismatch"):
        adjudicator.build_inventory(policy, created_utc=CREATED_UTC)

    policy = _make_bundle(tmp_path / "hash")
    key = adjudicator.expected_cells()[0]
    pointer = evidence_io.load_json_strict(key.pointer_path(policy.pointer_root))
    receipt = Path(pointer["receipt"]["path"])
    receipt.write_bytes(receipt.read_bytes() + b" ")
    with pytest.raises(evidence_io.EvidenceIOError, match="binding drift"):
        adjudicator.build_inventory(policy, created_utc=CREATED_UTC)


def test_semantic_duplicate_drift_rejects_even_with_valid_file_bindings(tmp_path: Path) -> None:
    target = adjudicator.expected_cells()[0].cell_id

    def drift(key: adjudicator.CellKey, audit: dict[str, Any]) -> None:
        if key.cell_id == target:
            audit["reports"][1]["same_day_swap_proof"]["duplicate_only_marker"] = True

    policy = _make_bundle(tmp_path, duplicate_mutator=drift)
    with pytest.raises(adjudicator.AdjudicationError, match="semantic duplicate payload drift"):
        adjudicator.build_inventory(policy, created_utc=CREATED_UTC)


def test_center_cannot_be_rescued_by_profitable_neighbours(tmp_path: Path) -> None:
    def thin_center(
        key: adjudicator.CellKey, positions: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        if key.market.symbol == "NDX.DWX" and key.variant == "center":
            return positions[:8]
        return positions

    policy = _make_bundle(tmp_path, position_transform=thin_center)
    _, evaluation = _inventory_and_evaluation(policy)
    assert evaluation.status == "FAIL"
    gates = evaluation.payload["binding_gates"]
    assert gates["sleeve_a_center"]["status"] == "FAIL"
    assert gates["sleeve_a_plateau"]["status"] == "FAIL"
    assert gates["sleeve_a_plateau"]["selected_variant"] == "center"
    assert evaluation.payload["selected_configuration"]["neighbour_rescue_permitted"] is False


def test_plateau_enforces_nine_profitable_and_exact_seventy_percent(tmp_path: Path) -> None:
    losing_variants = set(adjudicator.NEIGHBOURS[:5])

    def lose_five(
        key: adjudicator.CellKey, positions: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        if key.market.symbol == "NDX.DWX" and key.variant in losing_variants:
            for row in positions:
                row["raw_net_usd"] = "-90.00"
                row["cost_adjusted_net_usd"] = "-100.00"
        return positions

    policy = _make_bundle(tmp_path / "profitability", position_transform=lose_five)
    _, evaluation = _inventory_and_evaluation(policy)
    plateau = evaluation.payload["binding_gates"]["sleeve_a_plateau"]
    assert plateau["profitable_variants"] == 8
    assert plateau["status"] == "FAIL"

    def retention(
        key: adjudicator.CellKey, positions: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        if key.market.symbol == "NDX.DWX" and key.variant == "pivot_low":
            return positions[:6]  # center=10, required neighbour count is >=7
        return positions

    policy = _make_bundle(tmp_path / "retention", position_transform=retention)
    _, evaluation = _inventory_and_evaluation(policy)
    plateau = evaluation.payload["binding_gates"]["sleeve_a_plateau"]
    pivot_low = next(row for row in plateau["neighbours"] if row["variant"] == "pivot_low")
    assert pivot_low["trade_retention_exact_check"] == "6*10 >= 10*7"
    assert pivot_low["trade_retention_status"] == "FAIL"
    assert plateau["status"] == "FAIL"


def test_gdax_zero_or_losing_transport_never_changes_selection(tmp_path: Path) -> None:
    def losing_gdax(
        key: adjudicator.CellKey, positions: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        if key.market.symbol != "GDAXI.DWX" or key.variant == "center":
            return positions
        return [
            _raw_position(
                symbol="GDAXI.DWX",
                sequence=1,
                broker_entry=datetime(2021, 6, 1, 9),
                adjusted_net=Decimal("-100.00"),
            )
        ]

    policy = _make_bundle(tmp_path, position_transform=losing_gdax)
    _, evaluation = _inventory_and_evaluation(policy)
    assert evaluation.status == "PASS"
    transport = evaluation.payload["transport_diagnostic"]
    assert transport["never_affects_selection_or_plateau"] is True
    assert transport["variants"][0]["metrics"]["trades"] == 0
    assert transport["variants"][1]["metrics"]["net_profit_usd"] == "-100.00"


def test_fx_session_boundaries_and_mixed_partial_entries_fail_closed() -> None:
    def row_at(*times: str) -> dict[str, Any]:
        row = _raw_position(
            symbol="GBPUSD.DWX",
            sequence=1,
            broker_entry=datetime.strptime(times[0], "%Y-%m-%dT%H:%M:%S"),
            adjusted_net=Decimal("100.00"),
        )
        row["entry_times"] = list(times)
        row["exit_time"] = "2021-06-01T18:00:00"
        return row

    london = adjudicator.parse_position(
        row_at("2021-06-01T09:00:00"),
        expected_symbol="GBPUSD.DWX",
        context="london",
    )
    new_york = adjudicator.parse_position(
        row_at("2021-06-01T14:00:00"),
        expected_symbol="GBPUSD.DWX",
        context="new_york",
    )
    assert london.session == "LONDON"
    assert new_york.session == "NEW_YORK"
    for invalid in (
        row_at("2021-06-01T12:00:00"),  # London end, NY 05:00
        row_at("2021-06-01T17:00:00"),  # New York end, NY 10:00
        row_at("2021-06-01T09:00:00", "2021-06-01T14:00:00"),
    ):
        with pytest.raises(adjudicator.AdjudicationError, match="outside-session|mixed-session"):
            adjudicator.parse_position(
                invalid,
                expected_symbol="GBPUSD.DWX",
                context="invalid",
            )


def test_publication_is_exclusive_and_verdict_is_last_commit_marker(tmp_path: Path) -> None:
    policy = _make_bundle(tmp_path / "success")
    inventory, evaluation = _inventory_and_evaluation(policy)
    bindings = adjudicator.publish_dev(
        policy, inventory, evaluation, created_utc=CREATED_UTC
    )
    assert len(bindings) == 6
    verdict = policy.output_root / "verdicts" / "DEV.verdict.json"
    assert verdict.exists()
    verdict_payload = evidence_io.load_json_strict(verdict)
    assert verdict_payload["verdict"] == "PASS"
    assert verdict_payload["publication_contract"]["verdict_json_is_final_commit_marker"] is True
    evidence_io.verify_detached(verdict, Path(f"{verdict}.sha256"))
    with pytest.raises(evidence_io.EvidenceIOError, match="already exists"):
        adjudicator.publish_dev(
            policy, inventory, evaluation, created_utc=CREATED_UTC
        )

    policy = _make_bundle(tmp_path / "crash")
    inventory, evaluation = _inventory_and_evaluation(policy)
    with pytest.raises(evidence_io.EvidenceIOError, match="injected publication failure"):
        adjudicator.publish_dev(
            policy,
            inventory,
            evaluation,
            created_utc=CREATED_UTC,
            fail_after=5,
        )
    verdict = policy.output_root / "verdicts" / "DEV.verdict.json"
    assert not verdict.exists()
    assert Path(f"{verdict}.sha256").exists()

