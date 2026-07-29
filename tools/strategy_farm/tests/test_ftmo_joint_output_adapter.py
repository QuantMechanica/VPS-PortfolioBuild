import datetime as dt
import hashlib
import json
import sys
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_joint_output_adapter as adapter  # noqa: E402


PRAGUE = ZoneInfo("Europe/Prague")
MEMBERS = (
    adapter.ExpectedMember(201810000, "USDJPY.DWX"),
    adapter.ExpectedMember(201810001, "XAUUSD.DWX"),
    adapter.ExpectedMember(201810002, "XTIUSD.DWX"),
)
TRADE_HASH = "a" * 64
EQUITY_HASH = "b" * 64
PRODUCER_VERSION = "QM5_20181_FTMO_TRACE_V2_TEST"
PROVENANCE = adapter.ProvenanceBinding(
    work_item_id="work-item-001",
    evidence_run_id="run-book3-001",
    producer_version=PRODUCER_VERSION,
    runner_receipt_path="runner-receipt.json",
    runner_receipt_sha256="c" * 64,
    ex5_path="book3.ex5",
    ex5_sha256="d" * 64,
    setfile_path="book3.set",
    setfile_sha256="e" * 64,
    report_path="book3-report.json",
    report_sha256="f" * 64,
)
RULE_SNAPSHOT = adapter.RuleSnapshotBinding(
    path="ftmo-rules-snapshot.json",
    sha256="1" * 64,
    source_url=adapter.rules_engine.RULES_SOURCE_URL,
    source_observations_sha256="2" * 64,
    retrieved_at_utc="2026-07-29T00:00:00Z",
    engine_profile_sha256=adapter.rules_engine.frozen_rule_profile_sha256(),
    age_seconds_at_evaluation=0,
)


def _epoch(value: dt.datetime) -> int:
    return int(value.timestamp())


def complete_sources(
    *,
    start_date: dt.date = dt.date(2026, 3, 27),
    days: int = 4,
    final_balance: Decimal = Decimal("110000.04"),
):
    start = dt.datetime.combine(start_date, dt.time(), tzinfo=PRAGUE).astimezone(dt.UTC)
    end = dt.datetime.combine(
        start_date + dt.timedelta(days=days), dt.time(), tzinfo=PRAGUE
    ).astimezone(dt.UTC)
    net = (final_balance - Decimal("100000.00")) / Decimal(days)
    trades = []
    for day in range(days):
        member = MEMBERS[day % len(MEMBERS)]
        entry = dt.datetime.combine(
            start_date + dt.timedelta(days=day),
            dt.time(9, 30),
            tzinfo=PRAGUE,
        ).astimezone(dt.UTC)
        close = dt.datetime.combine(
            start_date + dt.timedelta(days=day),
            dt.time(10, 30),
            tzinfo=PRAGUE,
        ).astimezone(dt.UTC)
        profit = net + Decimal("2.00")
        trades.append(
            {
                "event": "TRADE_CLOSED",
                "schema_version": 2,
                "run_id": "run-book3-001",
                "producer_version": PRODUCER_VERSION,
                "position_fully_closed": True,
                "position_id": 1000 + day,
                "entry_deal_ids": [2000 + day * 2],
                "exit_deal_ids": [2001 + day * 2],
                "magic": member.magic,
                "symbol": member.symbol,
                "entry_time": _epoch(entry),
                "time": _epoch(close),
                "profit": format(profit, ".2f"),
                "swap": "0.00",
                "commission": "-2.00",
                "fee": "0.00",
                "net": format(net, ".2f"),
                "balance_events": [
                    {
                        "deal_id": 2000 + day * 2,
                        "time": _epoch(entry),
                        "component": "COMMISSION",
                        "amount": "-1.00",
                    },
                    {
                        "deal_id": 2001 + day * 2,
                        "time": _epoch(close),
                        "component": "PROFIT",
                        "amount": format(profit, ".2f"),
                    },
                    {
                        "deal_id": 2001 + day * 2,
                        "time": _epoch(close),
                        "component": "SWAP",
                        "amount": "0.00",
                    },
                    {
                        "deal_id": 2001 + day * 2,
                        "time": _epoch(close),
                        "component": "COMMISSION",
                        "amount": "-1.00",
                    },
                    {
                        "deal_id": 2001 + day * 2,
                        "time": _epoch(close),
                        "component": "FEE",
                        "amount": "0.00",
                    },
                ],
            }
        )
    meta = {
        "event": adapter.EQUITY_META_EVENT,
        "schema_version": adapter.ADAPTER_SCHEMA_VERSION,
        "q08_trade_schema_version": adapter.Q08_TRADE_SCHEMA_VERSION,
        "trace_id": "book3-spring-dst",
        "run_id": "run-book3-001",
        "producer_version": PRODUCER_VERSION,
        "currency": "USD",
        "grid_seconds": 3600,
        "money_decimals": 2,
        "host_symbol": "USDJPY.DWX",
        "expected_members": [
            {"magic": member.magic, "symbol": member.symbol} for member in MEMBERS
        ],
        "balance_basis": adapter.rules_engine.BALANCE_BASIS_NET_TRADING,
        "equity_basis": adapter.rules_engine.EQUITY_BASIS_MTM,
        "opened_positions_basis": adapter.rules_engine.OPENED_POSITIONS_BASIS,
        "interval_min_equity_basis": adapter.rules_engine.INTERVAL_MIN_EQUITY_BASIS,
        "pending_orders_basis": adapter.PENDING_ORDERS_BASIS,
        "coverage_basis": adapter.COVERAGE_BASIS,
        "trade_net_basis": adapter.TRADE_NET_BASIS,
        "floating_basis": adapter.FLOATING_BASIS,
    }
    points = []
    timestamp = start
    previous_equity = Decimal("100000.00")
    sequence = 0
    while timestamp <= end:
        balance = Decimal("100000.00")
        for trade in trades:
            for event in trade["balance_events"]:
                if dt.datetime.fromtimestamp(event["time"], tz=dt.UTC) <= timestamp:
                    balance += Decimal(event["amount"])
        open_positions = sum(
            1
            for trade in trades
            if dt.datetime.fromtimestamp(trade["entry_time"], tz=dt.UTC)
            <= timestamp
            < dt.datetime.fromtimestamp(trade["time"], tz=dt.UTC)
        )
        previous = timestamp if sequence == 0 else timestamp - dt.timedelta(hours=1)
        opened_positions = 0 if sequence == 0 else sum(
            1
            for trade in trades
            if previous
            < dt.datetime.fromtimestamp(trade["entry_time"], tz=dt.UTC)
            <= timestamp
        )
        local = timestamp.astimezone(PRAGUE)
        equity = balance
        points.append(
            {
                "event": adapter.EQUITY_POINT_EVENT,
                "schema_version": adapter.ADAPTER_SCHEMA_VERSION,
                "trace_id": "book3-spring-dst",
                "run_id": "run-book3-001",
                "producer_version": PRODUCER_VERSION,
                "interval_sequence": sequence,
                "interval_start_utc": _epoch(previous),
                "interval_end_utc": _epoch(timestamp),
                "t_utc": _epoch(timestamp),
                "balance": format(balance, ".2f"),
                "equity": format(equity, ".2f"),
                "interval_min_equity": format(min(previous_equity, equity), ".2f"),
                "open_positions": open_positions,
                "opened_positions": opened_positions,
                "pending_orders": 0,
                "open_positions_by_member": [
                    {
                        "magic": member.magic,
                        "symbol": member.symbol,
                        "count": sum(
                            1
                            for trade in trades
                            if trade["magic"] == member.magic
                            and dt.datetime.fromtimestamp(trade["entry_time"], tz=dt.UTC)
                            <= timestamp
                            < dt.datetime.fromtimestamp(trade["time"], tz=dt.UTC)
                        ),
                    }
                    for member in MEMBERS
                ],
                "opened_positions_by_member": [
                    {
                        "magic": member.magic,
                        "symbol": member.symbol,
                        "count": (
                            0
                            if sequence == 0
                            else sum(
                                1
                                for trade in trades
                                if trade["magic"] == member.magic
                                and previous
                                < dt.datetime.fromtimestamp(
                                    trade["entry_time"], tz=dt.UTC
                                )
                                <= timestamp
                            )
                        ),
                    }
                    for member in MEMBERS
                ],
                "pending_orders_by_member": [
                    {"magic": member.magic, "symbol": member.symbol, "count": 0}
                    for member in MEMBERS
                ],
                "day_anchor": local.time() == dt.time(),
                "coverage_complete": True,
                "covered_magics": [member.magic for member in MEMBERS],
                "covered_symbols": [member.symbol for member in MEMBERS],
                "fl_total": "0.00",
                "fl": [
                    {"magic": member.magic, "symbol": member.symbol, "f": "0.00"}
                    for member in MEMBERS
                ],
            }
        )
        previous_equity = equity
        timestamp += dt.timedelta(hours=1)
        sequence += 1
    return trades, [meta, *points]


def evaluate(trades, equity):
    return adapter.adapt_and_evaluate(
        trades,
        equity,
        expected_members=MEMBERS,
        trade_sha256=TRADE_HASH,
        equity_sha256=EQUITY_HASH,
        phase="PHASE1",
        provenance=PROVENANCE,
        rules_snapshot=RULE_SNAPSHOT,
    )


def write_bound_sources(
    tmp_path: Path,
    *,
    retrieved_at_utc: str = "2026-07-29T00:00:00Z",
):
    trades, equity = complete_sources()
    trades_path = tmp_path / "q08_trades.jsonl"
    equity_path = tmp_path / "q08_equity.jsonl"
    ex5_path = tmp_path / "book3.ex5"
    setfile_path = tmp_path / "book3.set"
    report_path = tmp_path / "report.json"
    receipt_path = tmp_path / "runner-receipt.json"
    rules_path = tmp_path / "rules-snapshot.json"
    trades_path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in trades),
        encoding="utf-8",
        newline="\n",
    )
    equity_path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in equity),
        encoding="utf-8",
        newline="\n",
    )
    ex5_path.write_bytes(b"book3-ex5")
    setfile_path.write_text(
        "RISK_FIXED=1000\nqm_evidence_run_id=run-book3-001\n",
        encoding="utf-8",
        newline="\n",
    )
    report_path.write_text('{"status":"PASS"}\n', encoding="utf-8", newline="\n")
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    receipt = {
        "schema_version": 1,
        "mode": "apply",
        "worker_exit_code": 0,
        "work_item_id": "work-item-001",
        "preflight": {
            "work_item": {"evidence_run_id": "run-book3-001"},
            "artifacts": [
                {
                    "role": "setfile",
                    "path": str(setfile_path.resolve()),
                    "expected_sha256": sha(setfile_path),
                    "actual_sha256": sha(setfile_path),
                    "valid": True,
                },
                {
                    "role": "staged_ex5",
                    "path": str(ex5_path.resolve()),
                    "expected_sha256": sha(ex5_path),
                    "actual_sha256": sha(ex5_path),
                    "valid": True,
                },
            ]
        },
        "post_run_stream": {
            "valid": True,
            "streams": [
                {
                    "stream_type": "q08_trades",
                    "target": str(trades_path.resolve()),
                    "valid": True,
                    "harvested": {"sha256": sha(trades_path)},
                },
                {
                    "stream_type": "q08_equity",
                    "target": str(equity_path.resolve()),
                    "valid": True,
                    "harvested": {"sha256": sha(equity_path)},
                },
            ],
        },
        "post_work_item": {
            "id": "work-item-001",
            "status": "done",
            "verdict": "PASS",
            "evidence_path": str(report_path.resolve()),
        },
    }
    receipt_path.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    rules_path.write_text(
        json.dumps(
            {
                "schema": "qm.ftmo-official-rules-snapshot/v1",
                "retrieved_at_utc": retrieved_at_utc,
                "freshness_max_age_days": 7,
                "sources": [
                    {
                        "source_id": "ftmo_trading_objectives_official",
                        "url": adapter.rules_engine.RULES_SOURCE_URL,
                        "http_status": 200,
                        "response_bytes": 123,
                        "response_sha256_observation": "9" * 64,
                        "last_modified_utc_observation": (
                            "2026-07-29T00:00:00Z"
                        ),
                    }
                ],
                "normalized_claims": {
                    "phase1_profit_target_percent": "10",
                    "verification_profit_target_percent": "5",
                    "profit_target_operator": (
                        "STRICTLY_GREATER_THAN_TARGET_WHILE_FLAT"
                    ),
                    "maximum_daily_loss_percent_of_initial": "5",
                    "maximum_daily_loss_reset_timezone": "Europe/Prague",
                    "maximum_daily_loss_reset_local_time": "00:00:00",
                    "maximum_daily_loss_basis": (
                        "MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT"
                    ),
                    "maximum_daily_loss_breach_operator": (
                        "EQUITY_STRICTLY_BELOW_LIMIT"
                    ),
                    "maximum_loss_percent_of_initial": "10",
                    "maximum_loss_model": "STATIC_INITIAL_CAPITAL",
                    "maximum_loss_breach_operator": (
                        "EQUITY_STRICTLY_BELOW_LIMIT"
                    ),
                    "minimum_trading_days_per_phase": 4,
                    "trading_day_qualifier": (
                        "AT_LEAST_ONE_POSITION_OPENED_DURING_PRAGUE_LOCAL_DAY"
                    ),
                    "maximum_trading_period_days": None,
                },
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    kwargs = {
        "runner_receipt_path": receipt_path,
        "expected_runner_receipt_sha256": sha(receipt_path),
        "ex5_path": ex5_path,
        "expected_ex5_sha256": sha(ex5_path),
        "setfile_path": setfile_path,
        "expected_setfile_sha256": sha(setfile_path),
        "report_path": report_path,
        "expected_report_sha256": sha(report_path),
        "expected_work_item_id": "work-item-001",
        "expected_evidence_run_id": "run-book3-001",
        "expected_producer_version": PRODUCER_VERSION,
        "rules_snapshot_path": rules_path,
        "expected_rules_snapshot_sha256": sha(rules_path),
        "evaluated_at_utc": dt.datetime(2026, 7, 29, 12, tzinfo=dt.UTC),
    }
    return trades_path, equity_path, kwargs


def test_legacy_20181_schema_fails_with_precise_setup_data_missing() -> None:
    trades = [
        {
            "event": "TRADE_CLOSED",
            "magic": 201810000,
            "time": 1530891002,
            "entry_time": 1530861135,
            "net": -1056.51,
            "profit": -1044.48,
            "swap": 0.0,
            "commission": -12.03,
            "symbol": "USDJPY.DWX",
        }
    ]
    equity = [
        {
            "event": "EQUITY_LOW",
            "t_utc": 1530478800,
            "equity": 100000.0,
            "balance": 100000.0,
            "fl_total": 0.0,
            "fl": [{"magic": 201810000, "f": 0.0}],
        }
    ]

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_MISSING"
    assert artifact["reason"] == "legacy_qm5_20181_output_lacks_money_gate_contract"
    assert artifact["missing_requirements"] == list(adapter.LEGACY_MISSING_REQUIREMENTS)
    assert artifact["money_gate_eligible"] is False
    assert artifact["challenge_proof"] is False
    assert trace is None


def test_complete_book3_sources_reconcile_and_pass_across_spring_dst() -> None:
    trades, equity = complete_sources()

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SCREEN_PASS"
    assert artifact["money_gate_eligible"] is True
    assert artifact["coverage"]["position_lifecycles"] == 4
    assert artifact["coverage"]["maximum_pending_orders_observed"] == 0
    assert artifact["coverage"]["prague_day_anchors"] == 5
    assert artifact["evaluation"]["balance"] == "110000.04"
    assert trace is not None
    # Four Prague days spanning the 23-hour spring transition: inclusive grid.
    assert len(trace["rows"]) == 96


def test_complete_book3_sources_reconcile_across_autumn_dst() -> None:
    trades, equity = complete_sources(start_date=dt.date(2026, 10, 23))

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SCREEN_PASS"
    assert trace is not None
    # Four Prague days spanning the 25-hour autumn transition: inclusive grid.
    assert len(trace["rows"]) == 98
    assert artifact["coverage"]["prague_day_anchors"] == 5


def test_exact_target_is_not_enough_under_current_rulepack_strictly_greater() -> None:
    trades, equity = complete_sources(final_balance=Decimal("110000.00"))

    artifact, trace = evaluate(trades, equity)

    assert trace is not None
    assert artifact["status"] == "NOT_PASSED"
    assert artifact["money_gate_eligible"] is False
    assert artifact["evaluation"]["missing_objectives"] == ["PROFIT_TARGET"]
    assert (
        artifact["evaluation"]["assumptions"]["profit_target_operator"]
        == "balance > target with flat book"
    )


def test_non_host_coverage_must_name_every_exact_book_member() -> None:
    trades, equity = complete_sources()
    equity[10]["covered_symbols"].remove("XTIUSD.DWX")

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"] == "covered_symbols_mismatch"
    assert trace is None


def test_missing_pending_order_state_is_setup_data_missing() -> None:
    trades, equity = complete_sources()
    del equity[10]["pending_orders"]

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_MISSING"
    assert artifact["reason"] == "pending_orders_missing:9"
    assert trace is None


def test_missing_regular_interval_fails_closed_instead_of_forward_fill() -> None:
    trades, equity = complete_sources()
    del equity[12]
    for index, row in enumerate(equity[1:]):
        row["interval_sequence"] = index
        if index:
            row["interval_start_utc"] = equity[index]["t_utc"]

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_MISSING"
    assert artifact["reason"].startswith("equity_grid_interval_missing:")
    assert trace is None


def test_open_counts_are_reconciled_to_position_lifecycles() -> None:
    trades, equity = complete_sources()
    entry_epoch = trades[0]["entry_time"]
    point = next(row for row in equity[1:] if row["t_utc"] > entry_epoch)
    assert point["open_positions"] == 1
    point["open_positions"] = 0

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"].startswith("open_positions_member_total_mismatch:")
    assert trace is None


def test_entry_and_exit_cost_events_must_reconcile_balance_and_trade_net() -> None:
    trades, equity = complete_sources()
    trades[0]["balance_events"][0]["amount"] = "0.00"

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"] == "trade_balance_components_mismatch:0"
    assert trace is None


def test_trade_and_equity_streams_from_different_runs_cannot_be_mixed() -> None:
    trades, equity = complete_sources()
    trades[0]["run_id"] = "different-isolated-run"

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"] == "trade_run_id_mismatch:0"
    assert trace is None


def test_equity_must_equal_balance_plus_all_member_floating_pnl() -> None:
    trades, equity = complete_sources()
    equity[8]["equity"] = "99999.99"

    artifact, trace = evaluate(trades, equity)

    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"] == "account_equity_identity_mismatch:7"
    assert trace is None


def test_jsonl_loader_rejects_duplicate_keys(tmp_path: Path) -> None:
    path = tmp_path / "duplicate.jsonl"
    path.write_text('{"event":"A","event":"B"}\n', encoding="utf-8")

    try:
        adapter.load_jsonl(path, "test")
    except adapter.SetupDataInvalid as exc:
        assert exc.reason == "json_duplicate_key:event"
    else:  # pragma: no cover - assertion clarity
        raise AssertionError("duplicate JSON key was accepted")


def test_bound_file_evaluation_authenticates_runner_artifacts_and_rules(
    tmp_path: Path,
) -> None:
    trades_path, equity_path, kwargs = write_bound_sources(tmp_path)

    artifact, trace = adapter.evaluate_files(
        trades_path,
        equity_path,
        expected_members=MEMBERS,
        phase="PHASE1",
        **kwargs,
    )

    assert artifact["status"] == "SCREEN_PASS"
    assert artifact["provenance"]["runner_receipt_sha256"] == kwargs[
        "expected_runner_receipt_sha256"
    ]
    assert artifact["provenance"]["ex5_sha256"] == kwargs["expected_ex5_sha256"]
    assert artifact["provenance"]["setfile_sha256"] == kwargs[
        "expected_setfile_sha256"
    ]
    assert artifact["provenance"]["report_sha256"] == kwargs[
        "expected_report_sha256"
    ]
    assert artifact["rules_snapshot"]["sha256"] == kwargs[
        "expected_rules_snapshot_sha256"
    ]
    assert trace is not None


def test_work_item_and_evidence_run_id_are_independent_fail_closed_bindings(
    tmp_path: Path,
) -> None:
    trades_path, equity_path, kwargs = write_bound_sources(tmp_path)

    wrong_work_item = dict(kwargs)
    wrong_work_item["expected_work_item_id"] = "run-book3-001"
    try:
        adapter.evaluate_files(
            trades_path,
            equity_path,
            expected_members=MEMBERS,
            phase="PHASE1",
            **wrong_work_item,
        )
    except adapter.SetupDataInvalid as exc:
        assert exc.reason == "runner_receipt_work_item_id_mismatch"
    else:  # pragma: no cover - assertion clarity
        raise AssertionError("evidence run ID was accepted as a work-item ID")

    wrong_evidence_run = dict(kwargs)
    wrong_evidence_run["expected_evidence_run_id"] = "work-item-001"
    try:
        adapter.evaluate_files(
            trades_path,
            equity_path,
            expected_members=MEMBERS,
            phase="PHASE1",
            **wrong_evidence_run,
        )
    except adapter.SetupDataInvalid as exc:
        assert exc.reason == "runner_receipt_evidence_run_id_mismatch"
    else:  # pragma: no cover - assertion clarity
        raise AssertionError("work-item ID was accepted as an evidence run ID")


def test_setfile_evidence_run_id_cannot_be_replayed_with_a_bound_receipt(
    tmp_path: Path,
) -> None:
    trades_path, equity_path, kwargs = write_bound_sources(tmp_path)
    setfile_path = kwargs["setfile_path"]
    receipt_path = kwargs["runner_receipt_path"]
    setfile_path.write_text(
        "RISK_FIXED=1000\nqm_evidence_run_id=replayed-run\n",
        encoding="utf-8",
        newline="\n",
    )
    set_sha = hashlib.sha256(setfile_path.read_bytes()).hexdigest()
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    set_artifact = next(
        item
        for item in receipt["preflight"]["artifacts"]
        if item["role"] == "setfile"
    )
    set_artifact["expected_sha256"] = set_sha
    set_artifact["actual_sha256"] = set_sha
    receipt_path.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    kwargs["expected_setfile_sha256"] = set_sha
    kwargs["expected_runner_receipt_sha256"] = hashlib.sha256(
        receipt_path.read_bytes()
    ).hexdigest()

    try:
        adapter.evaluate_files(
            trades_path,
            equity_path,
            expected_members=MEMBERS,
            phase="PHASE1",
            **kwargs,
        )
    except adapter.SetupDataInvalid as exc:
        assert exc.reason == "setfile_evidence_run_id_mismatch"
    else:  # pragma: no cover - assertion clarity
        raise AssertionError("replayed set-file evidence run ID was admitted")


def test_source_hash_and_parser_use_one_identical_byte_snapshot(
    tmp_path: Path, monkeypatch
) -> None:
    trades_path, equity_path, kwargs = write_bound_sources(tmp_path)
    original = adapter._read_snapshot
    counts = {trades_path.resolve(): 0, equity_path.resolve(): 0}

    def counted(path: Path, label: str):
        resolved = path.resolve()
        if resolved in counts:
            counts[resolved] += 1
        return original(path, label)

    monkeypatch.setattr(adapter, "_read_snapshot", counted)
    artifact, _trace = adapter.evaluate_files(
        trades_path,
        equity_path,
        expected_members=MEMBERS,
        phase="PHASE1",
        **kwargs,
    )

    assert artifact["status"] == "SCREEN_PASS"
    assert counts == {trades_path.resolve(): 1, equity_path.resolve(): 1}


def test_stale_or_unbound_official_rules_snapshot_blocks_money_gate(
    tmp_path: Path,
) -> None:
    trades_path, equity_path, kwargs = write_bound_sources(
        tmp_path, retrieved_at_utc="2026-07-21T11:59:59Z"
    )

    try:
        adapter.evaluate_files(
            trades_path,
            equity_path,
            expected_members=MEMBERS,
            phase="PHASE1",
            **kwargs,
        )
    except adapter.SetupDataMissing as exc:
        assert exc.reason.startswith("rules_snapshot_stale:")
    else:  # pragma: no cover - assertion clarity
        raise AssertionError("stale official-rules snapshot was admitted")

    kwargs["expected_rules_snapshot_sha256"] = "0" * 64
    try:
        adapter.evaluate_files(
            trades_path,
            equity_path,
            expected_members=MEMBERS,
            phase="PHASE1",
            **kwargs,
        )
    except adapter.SetupDataInvalid as exc:
        assert exc.reason.startswith("rules_snapshot_sha256_mismatch:")
    else:  # pragma: no cover - assertion clarity
        raise AssertionError("unbound official-rules snapshot was admitted")


def test_equity_points_are_bound_to_run_producer_and_per_member_state() -> None:
    trades, equity = complete_sources()
    equity[5]["run_id"] = "spliced-run"
    artifact, trace = evaluate(trades, equity)
    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"] == "equity_point_run_id_mismatch:4"
    assert trace is None

    trades, equity = complete_sources()
    active = next(row for row in equity[1:] if row["open_positions"] == 1)
    counts = active["open_positions_by_member"]
    owner = next(item for item in counts if item["count"] == 1)
    other = next(item for item in counts if item["count"] == 0)
    owner["count"] = 0
    other["count"] = 1
    artifact, trace = evaluate(trades, equity)
    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"].startswith(
        "open_positions_member_reconciliation_mismatch:"
    )
    assert trace is None


def test_every_cost_event_is_fee_complete_and_bound_to_a_lifecycle_deal() -> None:
    trades, equity = complete_sources()
    del trades[0]["fee"]
    artifact, trace = evaluate(trades, equity)
    assert artifact["status"] == "SETUP_DATA_MISSING"
    assert artifact["reason"] == "trade_fee_missing:0"
    assert trace is None

    trades, equity = complete_sources()
    trades[0]["balance_events"][0]["deal_id"] = 999999
    artifact, trace = evaluate(trades, equity)
    assert artifact["status"] == "SETUP_DATA_INVALID"
    assert artifact["reason"] == "balance_event_deal_id_not_in_lifecycle:0:0"
    assert trace is None


def test_cli_refuses_output_input_collision_and_existing_trace(
    tmp_path: Path,
) -> None:
    trades = tmp_path / "trades.jsonl"
    equity = tmp_path / "equity.jsonl"
    out = tmp_path / "artifact.json"
    trace_out = tmp_path / "trace.json"
    original_trade = json.dumps({"event": "TRADE_CLOSED", "magic": 201810000}) + "\n"
    trades.write_text(original_trade, encoding="utf-8")
    equity.write_text('{"event":"EQUITY_LOW"}\n', encoding="utf-8")

    collision_exit = adapter.main(
        [
            "--trades",
            str(trades),
            "--equity",
            str(equity),
            "--member",
            "201810000:USDJPY.DWX",
            "--out",
            str(trades),
            "--trace-out",
            str(trace_out),
        ]
    )
    assert collision_exit == 2
    assert trades.read_text(encoding="utf-8") == original_trade

    trace_out.write_text('{"stale":"prior-pass"}\n', encoding="utf-8")
    stale_exit = adapter.main(
        [
            "--trades",
            str(trades),
            "--equity",
            str(equity),
            "--member",
            "201810000:USDJPY.DWX",
            "--out",
            str(out),
            "--trace-out",
            str(trace_out),
        ]
    )
    assert stale_exit == 2
    assert not out.exists()
    assert json.loads(trace_out.read_text(encoding="utf-8")) == {
        "stale": "prior-pass"
    }


def test_cli_writes_legacy_refusal_without_loading_entire_equity_file(
    tmp_path: Path,
) -> None:
    trades = tmp_path / "trades.jsonl"
    equity = tmp_path / "equity.jsonl"
    out = tmp_path / "artifact.json"
    trace_out = tmp_path / "trace.json"
    trades.write_text(
        json.dumps({"event": "TRADE_CLOSED", "magic": 201810000}) + "\n",
        encoding="utf-8",
    )
    equity.write_text(
        json.dumps({"event": "EQUITY_LOW", "equity": 100000}) + "\n"
        + "this later legacy line is deliberately never parsed\n",
        encoding="utf-8",
    )

    exit_code = adapter.main(
        [
            "--trades",
            str(trades),
            "--equity",
            str(equity),
            "--member",
            "201810000:USDJPY.DWX",
            "--out",
            str(out),
            "--trace-out",
            str(trace_out),
        ]
    )

    artifact = json.loads(out.read_text(encoding="utf-8"))
    assert exit_code == 2
    assert artifact["status"] == "SETUP_DATA_MISSING"
    assert artifact["source"]["q08_trades_sha256"] == hashlib.sha256(
        trades.read_bytes()
    ).hexdigest()
    assert not trace_out.exists()
