import datetime as dt
import hashlib
import json
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_event_complete_replay as replay  # noqa: E402


UTC = dt.UTC
PRAGUE = ZoneInfo("Europe/Prague")
NEW_YORK = ZoneInfo("America/New_York")
SYMBOL = "XAUUSD.DWX"
RUN_ID = "FTMO_BOOK3_EC_10145_TEST_V1"
TICK_RUN_ID = "FTMO_BOOK3_TICKS_TEST_V1"
MAGIC = 101450001


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode() + b"\n"


def _write_json(path: Path, value: object) -> None:
    path.write_bytes(_json_bytes(value))


def _write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_bytes(b"".join(_json_bytes(row) for row in rows))


def _utc_msc(value: dt.datetime) -> int:
    return int(value.timestamp() * 1000)


def _wall_msc(value: dt.datetime) -> int:
    value = value.astimezone(UTC)
    offset = 3 if value.astimezone(NEW_YORK).dst() not in {
        None,
        dt.timedelta(0),
    } else 2
    return _utc_msc(value) + offset * 3_600_000


def _local_midnight(day: dt.date) -> dt.datetime:
    return dt.datetime.combine(day, dt.time(), tzinfo=PRAGUE).astimezone(UTC)


def _artifact_path(case: dict, role: str, symbol: str | None = None) -> Path:
    return case["paths"][(role, symbol)]


def _rebind_manifest(case: dict) -> None:
    manifest_path = case["manifest_path"]
    manifest = (
        json.loads(manifest_path.read_text())
        if manifest_path.exists()
        else case["manifest"]
    )
    for item in manifest["artifacts"]:
        item["sha256"] = _sha(
            case["paths"][(item["role"], item.get("symbol"))]
        )
    manifest.pop("manifest_id", None)
    manifest["manifest_id"] = hashlib.sha256(
        json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    _write_json(manifest_path, manifest)
    case["manifest"] = manifest


def _refresh(case: dict) -> None:
    paths = case["paths"]
    tick_rows = [
        json.loads(line)
        for line in paths[("ticks", SYMBOL)].read_text().splitlines()
        if line.strip()
    ]
    chunks = [
        json.loads(line)
        for line in paths[("tick_chunks", SYMBOL)].read_text().splitlines()
        if line.strip()
    ]
    for chunk in chunks:
        chunk["tick_count"] = sum(
            chunk["from_msc"] <= row["time_msc"] < chunk["to_msc_exclusive"]
            for row in tick_rows
        )
        chunk["market_coverage_status"] = (
            "REQUIRES_CLOSED_MARKET_PROOF"
            if chunk["tick_count"] == 0
            else "OBSERVED_TICKS_PRESENT"
        )
    _write_jsonl(paths[("tick_chunks", SYMBOL)], chunks)
    complete = json.loads(paths[("tick_complete", SYMBOL)].read_text())
    complete["tick_count"] = len(tick_rows)
    complete["chunk_count"] = len(chunks)
    _write_json(paths[("tick_complete", SYMBOL)], complete)

    receipt_path = paths[("history_complete", SYMBOL)]
    receipt = json.loads(receipt_path.read_text())
    for role in ("orders", "deals", "account_events", "checkpoints"):
        receipt[f"{role}_sha256"] = _sha(paths[(role, SYMBOL)])
    for role, field in (
        ("orders", "order_rows"),
        ("deals", "deal_rows"),
        ("account_events", "account_event_rows"),
        ("checkpoints", "checkpoint_rows"),
    ):
        receipt[field] = len(
            [line for line in paths[(role, SYMBOL)].read_text().splitlines() if line.strip()]
        )
    receipt["modifications_sha256"] = _sha(paths[("modifications", SYMBOL)])
    receipt["modifications_rows"] = len(
        [line for line in paths[("modifications", SYMBOL)].read_text().splitlines() if line.strip()]
    )
    receipt["execution_manifest_sha256"] = _sha(paths[("execution_manifest", SYMBOL)])
    receipt["prague_midnight_proof_sha256"] = _sha(
        paths[("prague_midnight_proof", SYMBOL)]
    )
    _write_json(receipt_path, receipt)

    _rebind_manifest(case)


def _case(
    tmp_path: Path,
    *,
    start_day: dt.date = dt.date(2026, 1, 5),
    days: int = 1,
    pending_entry: bool = False,
    partial_swap: bool = False,
    modification_complete: bool = True,
    broker_midnight_window: bool = False,
) -> dict:
    tmp_path.mkdir(parents=True, exist_ok=True)
    start_utc = (
        dt.datetime.combine(start_day, dt.time(), tzinfo=UTC) - dt.timedelta(hours=2)
        if broker_midnight_window
        else _local_midnight(start_day)
    )
    end_utc = (
        start_utc + dt.timedelta(days=days)
        if broker_midnight_window
        else _local_midnight(start_day + dt.timedelta(days=days))
    )
    start_raw = _wall_msc(start_utc)
    end_raw = _wall_msc(end_utc)
    entry_utc = start_utc + dt.timedelta(hours=2)
    partial_utc = start_utc + dt.timedelta(hours=3)
    exit_utc = start_utc + dt.timedelta(hours=4 if partial_swap else 3)

    paths: dict[tuple[str, str | None], Path] = {}

    def add(role: str, symbol: str | None, suffix: str, payload: bytes) -> None:
        path = tmp_path / f"{role}_{symbol or 'global'}{suffix}"
        path.write_bytes(payload)
        paths[(role, symbol)] = path

    tick_rows: list[dict] = []
    cursor = start_utc
    sequence = 0
    while cursor < end_utc:
        hours = (cursor - start_utc).total_seconds() / 3600
        price = 100 if hours < 3 else (105 if partial_swap and hours < 4 else 110)
        tick_rows.append(
            {
                "schema": replay.TICK_SCHEMA,
                "symbol": SYMBOL,
                "time_msc": _wall_msc(cursor),
                "source_sequence": sequence,
                "bid": str(price),
                "ask": str(price),
                "last": "0",
                "flags": 6,
                "volume": 1,
                "volume_real": "1",
            }
        )
        sequence += 1
        cursor += dt.timedelta(hours=1)
    add("ticks", SYMBOL, ".jsonl", b"".join(_json_bytes(row) for row in tick_rows))
    chunk = {
        "event": "TICK_CHUNK",
        "schema_version": 1,
        "run_id": TICK_RUN_ID,
        "symbol": SYMBOL,
        "chunk_index": 0,
        "from_msc": start_raw,
        "to_msc_exclusive": end_raw,
        "copy_status": "COPY_RANGE_COMPLETE",
        "market_coverage_status": "OBSERVED_TICKS_PRESENT",
        "tick_count": len(tick_rows),
        "time_basis": replay.TIMESTAMP_BASIS,
    }
    add("tick_chunks", SYMBOL, ".jsonl", _json_bytes(chunk))
    add(
        "tick_complete",
        SYMBOL,
        ".json",
        _json_bytes(
            {
                "event": "TICK_RAW_COPY_COMPLETE",
                "schema_version": 1,
                "run_id": TICK_RUN_ID,
                "symbol": SYMBOL,
                "from_msc": start_raw,
                "to_msc_exclusive": end_raw,
                "chunk_count": 1,
                "tick_count": len(tick_rows),
                "raw_copy_complete": True,
                "market_coverage_complete": False,
                "time_basis": replay.TIMESTAMP_BASIS,
            }
        ),
    )

    entry_type = "BUY_STOP" if pending_entry else "BUY"
    execution_mode = "PENDING" if pending_entry else "MARKET"
    order_specs = [(entry_utc, 10, entry_type, "IN")]
    if partial_swap:
        order_specs.extend(
            [(partial_utc, 11, "SELL", "OUT"), (exit_utc, 12, "SELL", "OUT")]
        )
    else:
        order_specs.append((exit_utc, 11, "SELL", "OUT"))
    order_rows: list[dict] = []
    for order_index, (when, order_id, order_type, _entry) in enumerate(order_specs):
        volume = "2" if partial_swap and order_id == 10 else "1"
        price = "100" if order_id == 10 else ("105" if order_id == 11 and partial_swap else "110")
        for event_index, event in enumerate(("PLACED", "FILLED")):
            order_rows.append(
                {
                    "schema": replay.ORDER_SCHEMA,
                    "run_id": RUN_ID,
                    "symbol": SYMBOL,
                    "magic": MAGIC,
                    "time_msc": _wall_msc(when),
                    "source_sequence": order_index * 2 + event_index,
                    "order_id": order_id,
                    "position_id": 1000,
                    "event": event,
                    "type": order_type,
                    "volume_initial": volume,
                    "volume_remaining": volume if event == "PLACED" else "0",
                    "price": price,
                    "stop_limit": "0",
                    "sl": "0",
                    "tp": "0",
                }
            )
    for row in order_rows:
        row["time_basis"] = replay.TIMESTAMP_BASIS
    add("orders", SYMBOL, ".jsonl", b"".join(_json_bytes(row) for row in order_rows))

    if partial_swap:
        deal_rows = [
            {
                "schema": replay.DEAL_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(entry_utc),
                "source_sequence": 1,
                "deal_id": 20,
                "order_id": 10,
                "position_id": 1000,
                "entry": "IN",
                "side": "BUY",
                "execution_mode": execution_mode,
                "reason": "EXPERT",
                "volume": "2",
                "price": "100",
                "profit": "0.00",
                "commission": "-2.00",
                "swap": "0.00",
                "fee": "0.00",
            },
            {
                "schema": replay.DEAL_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(partial_utc),
                "source_sequence": 2,
                "deal_id": 21,
                "order_id": 11,
                "position_id": 1000,
                "entry": "OUT",
                "side": "SELL",
                "execution_mode": "MARKET",
                "reason": "EXPERT",
                "volume": "1",
                "price": "105",
                "profit": "5.00",
                "commission": "-1.00",
                "swap": "-2.00",
                "fee": "0.00",
            },
            {
                "schema": replay.DEAL_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(exit_utc),
                "source_sequence": 3,
                "deal_id": 22,
                "order_id": 12,
                "position_id": 1000,
                "entry": "OUT",
                "side": "SELL",
                "execution_mode": "MARKET",
                "reason": "TP",
                "volume": "1",
                "price": "110",
                "profit": "10.00",
                "commission": "-1.00",
                "swap": "-2.00",
                "fee": "0.00",
            },
        ]
        account_rows = [
            {
                "schema": replay.ACCOUNT_EVENT_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(entry_utc),
                "source_sequence": 1,
                "event_id": "swap-zero",
                "kind": "POSITION_SWAP_MARK",
                "position_id": 1000,
                "amount": "0.00",
            },
            {
                "schema": replay.ACCOUNT_EVENT_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(entry_utc + dt.timedelta(minutes=30)),
                "source_sequence": 2,
                "event_id": "swap-minus-four",
                "kind": "POSITION_SWAP_MARK",
                "position_id": 1000,
                "amount": "-4.00",
            },
        ]
        checkpoint_specs = [
            (start_utc, "START", [], "100000.00", "100000.00", 0, [], "0", "100000"),
            (entry_utc, "DEAL_BOUNDARY", [20], "99998.00", "99998.00", 1, [(1000, "0.00")], "100", "99898"),
            (partial_utc, "DEAL_BOUNDARY", [21], "100000.00", "100003.00", 1, [(1000, "-2.00")], "50", "99953"),
            (exit_utc, "DEAL_BOUNDARY", [22], "100007.00", "100007.00", 0, [], "0", "100007"),
            (end_utc, "END", [], "100007.00", "100007.00", 0, [], "0", "100007"),
        ]
    else:
        deal_rows = [
            {
                "schema": replay.DEAL_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(entry_utc),
                "source_sequence": 1,
                "deal_id": 20,
                "order_id": 10,
                "position_id": 1000,
                "entry": "IN",
                "side": "BUY",
                "execution_mode": execution_mode,
                "reason": "EXPERT",
                "volume": "1",
                "price": "100",
                "profit": "0.00",
                "commission": "0.00",
                "swap": "0.00",
                "fee": "0.00",
            },
            {
                "schema": replay.DEAL_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(exit_utc),
                "source_sequence": 2,
                "deal_id": 21,
                "order_id": 11,
                "position_id": 1000,
                "entry": "OUT",
                "side": "SELL",
                "execution_mode": "MARKET",
                "reason": "SL",
                "volume": "1",
                "price": "110",
                "profit": "10.00",
                "commission": "0.00",
                "swap": "0.00",
                "fee": "0.00",
            },
        ]
        account_rows = [
            {
                "schema": replay.ACCOUNT_EVENT_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(entry_utc),
                "source_sequence": 1,
                "event_id": "swap-zero",
                "kind": "POSITION_SWAP_MARK",
                "position_id": 1000,
                "amount": "0.00",
            }
        ]
        checkpoint_specs = [
            (start_utc, "START", [], "100000.00", "100000.00", 0, [], "0", "100000"),
            (entry_utc, "DEAL_BOUNDARY", [20], "100000.00", "100000.00", 1, [(1000, "0.00")], "100", "99900"),
            (exit_utc, "DEAL_BOUNDARY", [21], "100010.00", "100010.00", 0, [], "0", "100010"),
            (end_utc, "END", [], "100010.00", "100010.00", 0, [], "0", "100010"),
        ]
    for row in deal_rows + account_rows:
        row["time_basis"] = replay.TIMESTAMP_BASIS
    for row in account_rows:
        row["effective_time_msc"] = None
        row["effective_time_basis"] = (
            "UNRESOLVED_EXTERNAL_PRAGUE_RECONCILIATION_REQUIRED"
        )
    add("deals", SYMBOL, ".jsonl", b"".join(_json_bytes(row) for row in deal_rows))
    add("account_events", SYMBOL, ".jsonl", b"".join(_json_bytes(row) for row in account_rows))

    checkpoint_rows = []
    for index, (when, kind, deal_ids, balance, equity, opens, swaps, margin, free) in enumerate(checkpoint_specs):
        checkpoint_rows.append(
            {
                "schema": replay.CHECKPOINT_SCHEMA,
                "run_id": RUN_ID,
                "symbol": SYMBOL,
                "magic": MAGIC,
                "time_msc": _wall_msc(when),
                "source_sequence": index,
                "kind": kind,
                "deal_ids": deal_ids,
                "balance": balance,
                "equity": equity,
                "open_positions": opens,
                "pending_orders": 0,
                "position_swaps": [
                    {"position_id": position_id, "amount": amount}
                    for position_id, amount in swaps
                ],
                "margin": margin,
                "margin_free": free,
                "margin_level": "0" if margin == "0" else "999",
                "account_leverage": 100,
                "account_currency": "USD",
                "account_margin_mode": 2,
                "time_basis": replay.TIMESTAMP_BASIS,
            }
        )
    add("checkpoints", SYMBOL, ".jsonl", b"".join(_json_bytes(row) for row in checkpoint_rows))

    add("execution_manifest", SYMBOL, ".json", b'{"contract":"execution"}\n')
    add("prague_midnight_proof", SYMBOL, ".json", b'{"contract":"prague"}\n')
    add("modifications", SYMBOL, ".jsonl", b"")
    receipt = {
        "schema": replay.HISTORY_COMPLETE_SCHEMA,
        "complete": True,
        "run_id": RUN_ID,
        "symbol": SYMBOL,
        "magic": MAGIC,
        "start_time_msc": start_raw,
        "end_time_msc": end_raw,
        "modification_observation_complete": modification_complete,
        "history_select_complete": True,
        "end_flat": True,
        "account_leverage": 100,
        "time_basis": replay.TIMESTAMP_BASIS,
        "modifications_rows": 0,
        "normal_deinit_complete": True,
        "raw_evidence_window_semantics": "EXACT_BROKER_WALL_TESTER_DATE_RANGE",
        "prague_boundary_day_policy": "PARTIAL_BOUNDARY_DAYS_PRESERVED_IN_RAW_EVIDENCE",
        "producer_window_transform": "NONE",
        "strategy_truth_window_preserved": True,
        "expected_broker_wall_start_msc": start_raw,
        "expected_broker_wall_end_msc": end_raw,
        "actual_first_tick_broker_wall_msc": tick_rows[0]["time_msc"],
        "actual_last_tick_broker_wall_msc": tick_rows[-1]["time_msc"],
        "execution_manifest_hash_verified": True,
        "prague_midnight_proof_hash_verified": True,
        "prague_midnight_proof_semantically_consumed_by_producer": False,
        "swap_effective_timing_basis": "OBSERVATION_ONLY_EFFECTIVE_TIME_NULL",
        "swap_effective_timing_complete": False,
        "external_prague_swap_timing_reconciliation_required": True,
        "external_completed_tester_report_required": True,
        "external_completed_tester_report_verified_by_producer": False,
        "admission_authority": "NONE",
        "producer_status": "PRODUCER_COMPLETE",
        "failure_count": 0,
        "failure_reasons": "",
        "expected_account_currency": "USD",
        "account_currency": "USD",
        "expected_account_margin_mode": 2,
        "account_margin_mode": 2,
        "expected_account_leverage": 100,
        "order_rows": len(order_rows),
        "deal_rows": len(deal_rows),
        "account_event_rows": len(account_rows),
        "checkpoint_rows": len(checkpoint_rows),
    }
    add("history_complete", SYMBOL, ".json", _json_bytes(receipt))

    symbol_properties = {
        "schema": replay.SYMBOL_PROPERTIES_SCHEMA,
        "account_currency": "USD",
        "expected_account_leverage": 100,
        "expected_account_margin_mode": 2,
        "symbols": [
            {
                "symbol": SYMBOL,
                "calc_mode": "CFD_LINEAR",
                "contract_size": "1",
                "tick_size": "0.01",
                "tick_value": "0.01",
                "profit_currency": "USD",
                "account_currency": "USD",
                "conversion_mode": "IDENTITY",
                "swap_mode": 0,
                "margin_initial": "100",
                "margin_maintenance": "100",
                "quote_sessions": [],
                "trade_sessions": [],
            }
        ],
    }
    add("symbol_properties", None, ".json", _json_bytes(symbol_properties))
    sleeve = {
        "sleeve_id": "xau-10145",
        "symbol": SYMBOL,
        "run_id": RUN_ID,
        "magic": MAGIC,
        "native_initial_balance": "100000.00",
        "scale": "1",
    }
    sizing = {
        "schema": replay.SIZING_SCHEMA,
        "normalization_basis": "PNL_DELTA_FROM_RECONCILED_STANDALONE_INITIAL_BALANCE",
        "synthetic_initial_balance": "100000.00",
        "sleeves": [sleeve],
    }
    add("sizing_policy", None, ".json", _json_bytes(sizing))
    add(
        "tick_set_complete",
        None,
        ".json",
        _json_bytes(
            {
                "event": "TICK_RAW_COPY_SET_COMPLETE",
                "schema_version": 1,
                "run_id": TICK_RUN_ID,
                "symbol_count": 1,
                "from_msc": start_raw,
                "to_msc_exclusive": end_raw,
                "raw_copy_complete": True,
                "market_coverage_complete": False,
                "time_basis": replay.TIMESTAMP_BASIS,
            }
        ),
    )
    for role in replay._GLOBAL_ROLES - {"symbol_properties", "sizing_policy", "tick_set_complete"}:
        add(role, None, ".bin", f"{role}-evidence\n".encode())
    for role in replay._SLEEVE_ROLES - {
        "ticks",
        "tick_chunks",
        "tick_complete",
        "orders",
        "deals",
        "account_events",
        "checkpoints",
        "history_complete",
        "execution_manifest",
        "prague_midnight_proof",
        "modifications",
    }:
        add(role, SYMBOL, ".bin", f"{role}-{SYMBOL}\n".encode())

    artifacts = [
        {
            "role": role,
            **({} if symbol is None else {"symbol": symbol}),
            "path": path.name,
            "sha256": "0" * 64,
        }
        for (role, symbol), path in sorted(paths.items(), key=lambda item: (item[0][0], item[0][1] or ""))
    ]
    manifest = {
        "schema": replay.MANIFEST_SCHEMA,
        "replay_id": "ftmo-book3-test",
        "account_currency": "USD",
        "initial_balance": "100000.00",
        "money_decimals": 2,
        "grid_seconds": 3600,
        "observation_timezone": "Europe/Prague",
        "timestamp_basis": replay.TIMESTAMP_BASIS,
        "gap_policy": "CLOSED_MARKET_ONLY_WITH_PROOF",
        "require_end_flat": True,
        "start_time_msc": start_raw,
        "end_time_msc": end_raw,
        "allowed_symbols": [SYMBOL],
        "sleeves": [sleeve],
        "artifacts": artifacts,
    }
    manifest_path = tmp_path / "manifest.json"
    case = {"manifest": manifest, "manifest_path": manifest_path, "paths": paths}
    _refresh(case)
    return case


def test_valid_replay_is_deterministic_single_read_and_explicitly_blocked(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    case = _case(tmp_path)
    original = replay._read_once
    calls: dict[Path, int] = {}

    def counted(path: Path, label: str) -> bytes:
        resolved = path.resolve()
        calls[resolved] = calls.get(resolved, 0) + 1
        return original(path, label)

    monkeypatch.setattr(replay, "_read_once", counted)
    product = replay.produce_replay(case["manifest_path"])

    assert all(count == 1 for count in calls.values())
    assert len(calls) == 1 + len(case["paths"])
    assert product.trace.points[-1].balance == replay.Decimal("100010.00")
    assert product.book_ready is False
    assert "EVENT_COMPLETE_MARGIN_AND_JOINT_FREE_MARGIN_REPLAY_NOT_IMPLEMENTED_V1" in product.qualification_blockers
    assert replay.canonical_result_bytes(product) == replay.canonical_result_bytes(product)


def test_producer_shaped_receipt_contract_is_end_to_end_and_legacy_aliases_fail(
    tmp_path: Path,
) -> None:
    case = _case(tmp_path / "canonical")
    receipt_path = _artifact_path(case, "history_complete", SYMBOL)
    receipt = json.loads(receipt_path.read_text())
    assert receipt["modifications_rows"] == 0
    assert receipt["actual_first_tick_broker_wall_msc"] > 0
    assert receipt["actual_last_tick_broker_wall_msc"] >= receipt[
        "actual_first_tick_broker_wall_msc"
    ]
    assert "modification_rows" not in receipt
    assert "actual_init_broker_wall_msc" not in receipt
    assert "actual_last_observed_broker_wall_msc" not in receipt
    assert replay.produce_replay(case["manifest_path"]).trace is not None

    receipt["modification_rows"] = receipt.pop("modifications_rows")
    _write_json(receipt_path, receipt)
    _rebind_manifest(case)
    with pytest.raises(
        replay.ReplayDataInvalid, match="history_stream_count_mismatch"
    ):
        replay.produce_replay(case["manifest_path"])

    case = _case(tmp_path / "legacy-times")
    receipt_path = _artifact_path(case, "history_complete", SYMBOL)
    receipt = json.loads(receipt_path.read_text())
    receipt["actual_init_broker_wall_msc"] = receipt.pop(
        "actual_first_tick_broker_wall_msc"
    )
    receipt["actual_last_observed_broker_wall_msc"] = receipt.pop(
        "actual_last_tick_broker_wall_msc"
    )
    _write_json(receipt_path, receipt)
    _rebind_manifest(case)
    with pytest.raises(
        replay.ReplayDataInvalid, match="actual_first_tick_broker_wall_msc_invalid"
    ):
        replay.produce_replay(case["manifest_path"])


def test_broker_wall_conversion_handles_standard_and_daylight_and_rejects_fold_gap() -> None:
    for instant in (
        dt.datetime(2026, 1, 15, 12, tzinfo=UTC),
        dt.datetime(2026, 7, 15, 12, tzinfo=UTC),
    ):
        assert replay.broker_wall_msc_to_utc_msc(_wall_msc(instant)) == _utc_msc(instant)

    # At US fall-back the repeated broker-wall hour has two valid UTC meanings.
    ambiguous_wall = _utc_msc(dt.datetime(2026, 11, 1, 8, 30, tzinfo=UTC))
    with pytest.raises(replay.ReplayDataInvalid, match="broker_wall_time_ambiguous"):
        replay.broker_wall_msc_to_utc_msc(ambiguous_wall)
    # At US spring-forward the skipped broker-wall hour has none.
    nonexistent_wall = _utc_msc(dt.datetime(2026, 3, 8, 9, 30, tzinfo=UTC))
    with pytest.raises(replay.ReplayDataInvalid, match="broker_wall_time_nonexistent"):
        replay.broker_wall_msc_to_utc_msc(nonexistent_wall)


def test_spring_dst_grid_keeps_prague_midnight_anchors(tmp_path: Path) -> None:
    case = _case(tmp_path, start_day=dt.date(2026, 3, 28), days=2)
    product = replay.produce_replay(case["manifest_path"])
    anchors = [point for point in product.trace.points if point.day_anchor]
    assert len(product.trace.points) == 48  # inclusive grid over a 47-hour Prague span
    assert len(anchors) == 3


def test_real_broker_midnight_window_produces_partial_day_joint_trace(tmp_path: Path) -> None:
    case = _case(tmp_path, broker_midnight_window=True, days=2)
    product = replay.produce_replay(case["manifest_path"])
    assert product.trace is not None
    assert product.trace.points[0].day_anchor is False
    assert product.trace.points[-1].day_anchor is False
    assert product.trace.points[-1].balance == replay.Decimal("100010.00")


def test_commission_swap_partial_close_and_tp_are_replayed(tmp_path: Path) -> None:
    case = _case(tmp_path, partial_swap=True)
    product = replay.produce_replay(case["manifest_path"])
    assert product.trace.points[-1].balance == replay.Decimal("100007.00")
    assert product.trace.points[-1].open_positions == 0


def test_subsecond_spike_is_preserved_as_true_interval_minimum(tmp_path: Path) -> None:
    case = _case(tmp_path)
    tick_path = _artifact_path(case, "ticks", SYMBOL)
    rows = [json.loads(line) for line in tick_path.read_text().splitlines()]
    entry = _local_midnight(dt.date(2026, 1, 5)) + dt.timedelta(hours=2)
    for offset_msc, price in ((500, "80"), (900, "100")):
        rows.append(
            {
                "schema": replay.TICK_SCHEMA,
                "symbol": SYMBOL,
                "time_msc": _wall_msc(entry) + offset_msc,
                "source_sequence": 0,
                "bid": price,
                "ask": price,
                "last": "0",
                "flags": 6,
                "volume": 1,
                "volume_real": "1",
            }
        )
    rows.sort(key=lambda row: row["time_msc"])
    for sequence, row in enumerate(rows):
        row["source_sequence"] = sequence
    _write_jsonl(tick_path, rows)
    _refresh(case)

    product = replay.produce_replay(case["manifest_path"])
    assert product.trace.points[3].interval_min_equity == replay.Decimal("99980.00")


def test_tick_chunk_validation_scales_across_many_contiguous_chunks(tmp_path: Path) -> None:
    case = _case(tmp_path)
    manifest = case["manifest"]
    start = manifest["start_time_msc"]
    end = manifest["end_time_msc"]
    width = (end - start) // 1000
    chunks = [
        {
            "event": "TICK_CHUNK",
            "schema_version": 1,
            "run_id": TICK_RUN_ID,
            "symbol": SYMBOL,
            "chunk_index": index,
            "from_msc": start + index * width,
            "to_msc_exclusive": (
                end if index == 999 else start + (index + 1) * width
            ),
            "copy_status": "COPY_RANGE_COMPLETE",
            "market_coverage_status": "OBSERVED_TICKS_PRESENT",
            "tick_count": 0,
            "time_basis": replay.TIMESTAMP_BASIS,
        }
        for index in range(1000)
    ]
    _write_jsonl(_artifact_path(case, "tick_chunks", SYMBOL), chunks)
    _refresh(case)

    product = replay.produce_replay(case["manifest_path"])
    assert product.trace.points[-1].balance == replay.Decimal("100010.00")


def test_position_modification_is_hash_bound_and_causally_correlated(tmp_path: Path) -> None:
    case = _case(tmp_path)
    modification_path = _artifact_path(case, "modifications", SYMBOL)
    modification_time = _local_midnight(dt.date(2026, 1, 5)) + dt.timedelta(
        hours=2, minutes=30
    )
    row = {
        "schema": replay.MODIFICATION_SCHEMA,
        "run_id": RUN_ID,
        "symbol": SYMBOL,
        "magic": MAGIC,
        "time_msc": _wall_msc(modification_time),
        "time_basis": replay.TIMESTAMP_BASIS,
        "source_sequence": 10,
        "modification_id": "SLTP_10",
        "ticket": 5000,
        "position_id": 1000,
        "old_sl": "0",
        "new_sl": "95",
        "old_tp": "0",
        "new_tp": "110",
        "reason": "BREAKEVEN",
        "send_ok": True,
        "retcode": 10009,
        "request_id": 77,
        "request_callback_seen": True,
        "position_callback_seen": True,
        "callback_retcode": 10009,
        "callback_request_id": 77,
        "correlated_sl_exit_deal": 21,
        "correlated_sl_exit_price": "110",
    }
    _write_jsonl(modification_path, [row])
    _refresh(case)
    product = replay.produce_replay(case["manifest_path"])
    assert "POSITION_MODIFICATION_CAUSAL_REPLAY_NOT_IMPLEMENTED_V1" in product.qualification_blockers

    row["correlated_sl_exit_price"] = "109"
    _write_jsonl(modification_path, [row])
    _refresh(case)
    with pytest.raises(replay.ReplayDataInvalid, match="modification_correlated_deal_mismatch"):
        replay.produce_replay(case["manifest_path"])


def test_pending_order_lifecycle_is_required_for_pending_fill(tmp_path: Path) -> None:
    case = _case(tmp_path, pending_entry=True)
    assert replay.produce_replay(case["manifest_path"]).trace.points[-1].balance == replay.Decimal("100010.00")
    orders_path = _artifact_path(case, "orders", SYMBOL)
    rows = [json.loads(line) for line in orders_path.read_text().splitlines()]
    rows = [row for row in rows if not (row["order_id"] == 10 and row["event"] == "PLACED")]
    _write_jsonl(orders_path, rows)
    _refresh(case)
    with pytest.raises(replay.ReplayDataInvalid, match="pending_deal_without_order|order_terminal_without_placed"):
        replay.produce_replay(case["manifest_path"])


@pytest.mark.parametrize(
    ("mutation", "reason"),
    [
        ("nonmonotone_ticks", "tick_stream_nonmonotone"),
        ("foreign_tick", "tick_foreign_symbol"),
        ("missing_marks", "mark_missing|grid_mark_missing"),
        ("unsupported_order", "unsupported_order_type"),
        ("checkpoint_drift", "checkpoint_balance_mismatch"),
    ],
)
def test_adversarial_streams_fail_closed(tmp_path: Path, mutation: str, reason: str) -> None:
    case = _case(tmp_path)
    if mutation in {"nonmonotone_ticks", "foreign_tick", "missing_marks"}:
        path = _artifact_path(case, "ticks", SYMBOL)
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        if mutation == "nonmonotone_ticks":
            rows[0], rows[1] = rows[1], rows[0]
        elif mutation == "foreign_tick":
            rows[0]["symbol"] = "FOREIGN.DWX"
        else:
            rows = [row for row in rows if row["time_msc"] > _wall_msc(_local_midnight(dt.date(2026, 1, 5)) + dt.timedelta(hours=2))]
        _write_jsonl(path, rows)
    elif mutation == "unsupported_order":
        path = _artifact_path(case, "orders", SYMBOL)
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        rows[0]["type"] = "CLOSE_BY"
        _write_jsonl(path, rows)
    else:
        path = _artifact_path(case, "checkpoints", SYMBOL)
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        rows[-1]["balance"] = "100009.99"
        _write_jsonl(path, rows)
    _refresh(case)
    with pytest.raises(replay.ReplayContractError, match=reason):
        replay.produce_replay(case["manifest_path"])


def test_unsupported_conversion_and_external_account_event_fail_closed(tmp_path: Path) -> None:
    case = _case(tmp_path)
    properties_path = _artifact_path(case, "symbol_properties")
    properties = json.loads(properties_path.read_text())
    properties["symbols"][0]["conversion_mode"] = "UNVERIFIED_TRIANGULATION"
    _write_json(properties_path, properties)
    _refresh(case)
    with pytest.raises(replay.ReplayDataInvalid, match="unsupported_conversion"):
        replay.produce_replay(case["manifest_path"])

    case = _case(tmp_path / "cashflow")
    account_path = _artifact_path(case, "account_events", SYMBOL)
    rows = [json.loads(line) for line in account_path.read_text().splitlines()]
    rows[0]["kind"] = "BALANCE_CREDIT"
    _write_jsonl(account_path, rows)
    _refresh(case)
    with pytest.raises(replay.ReplayDataInvalid, match="unsupported_account_event"):
        replay.produce_replay(case["manifest_path"])


def test_weekend_and_unproven_modifications_never_become_book_ready(tmp_path: Path) -> None:
    case = _case(
        tmp_path, start_day=dt.date(2026, 1, 9), days=3, modification_complete=False
    )
    product = replay.produce_replay(case["manifest_path"])
    assert product.book_ready is False
    assert "HISTORICAL_MARKET_SESSION_AND_HOLIDAY_REPLAY_NOT_IMPLEMENTED_V1" in product.qualification_blockers
    assert "ORDER_MODIFICATION_LIFECYCLE_NOT_PROVEN" in product.qualification_blockers


def test_manifest_and_artifact_hashes_fail_closed(tmp_path: Path) -> None:
    case = _case(tmp_path)
    manifest = json.loads(case["manifest_path"].read_text())
    manifest["grid_seconds"] = 1800
    _write_json(case["manifest_path"], manifest)
    with pytest.raises(replay.ReplayDataInvalid, match="manifest_id_mismatch"):
        replay.produce_replay(case["manifest_path"])

    _refresh(case)
    _artifact_path(case, "ea_binary", SYMBOL).write_bytes(b"tampered")
    with pytest.raises(replay.ReplayDataInvalid, match="artifact_hash_mismatch"):
        replay.produce_replay(case["manifest_path"])
