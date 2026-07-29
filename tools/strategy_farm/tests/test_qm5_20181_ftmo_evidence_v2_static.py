from __future__ import annotations

from pathlib import Path

from tools.strategy_farm.portfolio import ftmo_joint_output_adapter as adapter


REPO = Path(__file__).resolve().parents[3]
EA_DIR = (
    REPO
    / "framework"
    / "EAs"
    / "QM5_20181_ftmo-joint-multisym-timer"
)
EA = EA_DIR / "QM5_20181_ftmo-joint-multisym-timer.mq5"
EQUITY = (
    REPO
    / "framework"
    / "include"
    / "QM"
    / "modules"
    / "QM_Mod_FtmoJointEquitySampler_20180.mqh"
)
TRADES = (
    REPO
    / "framework"
    / "include"
    / "QM"
    / "modules"
    / "QM_Mod_FtmoJointTradeV2_20181.mqh"
)
SETS = {
    "J0": EA_DIR
    / "sets"
    / "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_replay_runner.set",
    "J1": EA_DIR
    / "sets"
    / "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book2_9936_10145.set",
    "J2": EA_DIR
    / "sets"
    / "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book3_9936_10145_13108.set",
}


def _source(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in _source(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_evidence_run_identity_is_mandatory_and_exactly_rung_bound() -> None:
    source = _compact(_source(EA))

    assert 'inputstringqm_evidence_run_id="";' in source
    assert "if(!QM20181EvidenceRunIdValid())" in source
    assert 'return"FTMO_BOOK3_20260729_V1_J0";' in source
    assert 'return"FTMO_BOOK3_20260729_V1_J1";' in source
    assert 'return"FTMO_BOOK3_20260729_V1_J2";' in source
    assert "qm_evidence_run_id==expected" in source

    for rung, path in SETS.items():
        values = _set_values(path)
        assert values["qm_evidence_run_id"] == f"FTMO_BOOK3_20260729_V1_{rung}"


def test_equity_v2_is_an_explicit_setup_block_not_a_false_attestation() -> None:
    source = _source(EQUITY)
    compact = _compact(source)

    assert '\\"FTMO_JOINT_TRACE_META\\"' in source
    assert '\\"FTMO_JOINT_TRACE_POINT\\"' in source
    assert "HOST_TICK_PLUS_MODEL_SECOND_TIMER_NOT_EVENT_COMPLETE" in source
    assert "NON_HOST_SUBSECOND_TICKS_NOT_OBSERVED" in source
    assert "EVENT_COMPLETE_MTM_REPLAY_PRODUCER_MISSING" in source
    assert "QM5_20181_FTMO_TRACE_V2" in source
    assert '\\"coverage_complete\\\":false' in source
    assert '\\"coverage_complete\\\":true' not in source
    assert "QM_FJ_Eq_ConfigureV2Blocked(eqmagics,eqsymbols,qm_evidence_run_id)" in _compact(
        _source(EA)
    )

    # Metadata names the exact adapter contract, while the per-point boolean is
    # the only completeness attestation and remains false.
    for required in (
        "NET_CLOSED_TRADING_PNL_INCLUDING_COSTS_NO_EXTERNAL_CASHFLOWS",
        "MARK_TO_MARKET_INCLUDING_OPEN_PNL_SWAP_COMMISSION",
        "RECONCILED_POSITION_FIRST_OPEN_EVENTS_IN_INTERVAL_(PREVIOUS_TS,TS]",
        "TICK_EVENT_COMPLETE_INTERVAL_MIN_EQUITY_INCLUDING_ENDPOINTS",
        "TICK_EVENT_COMPLETE_ALL_BOOK_SYMBOLS_AND_ACCOUNT_EVENTS",
    ):
        assert required in compact


def test_trade_v2_is_history_based_complete_lifecycle_evidence() -> None:
    source = _source(TRADES)
    compact = _compact(source)

    assert "HistorySelect(0,TimeCurrent())" in compact
    assert "HistoryDealsTotal()" in compact
    assert "DEAL_POSITION_ID" in source
    assert "DEAL_ENTRY_IN" in source
    assert "DEAL_ENTRY_OUT" in source
    assert "DEAL_ENTRY_OUT_BY" in source
    assert "INOUT_REVERSAL_UNSUPPORTED" in source
    assert "DEAL_FEE" in source
    assert '"FEE"' in source
    assert "POSITION_LIFECYCLE_NOT_FULLY_CLOSED_OR_NOT_LEGACY_COMPATIBLE" in source
    assert "QM_FJ_TradeV2PositionStillOpen" in source

    for required_field in (
        '\\"schema_version\\\":2',
        '\\"run_id\\\"',
        '\\"producer_version\\\"',
        '\\"position_fully_closed\\\":true',
        '\\"position_id\\\"',
        '\\"entry_deal_ids\\\"',
        '\\"exit_deal_ids\\\"',
        '\\"balance_events\\\"',
        '\\"entry_commission\\\"',
        '\\"exit_commission\\\"',
        '\\"fee\\\":0.00',
    ):
        assert required_field in source

    # Existing replay/Q08 consumers still receive their required legacy fields.
    for legacy_field in (
        '\\"event\\\":\\"TRADE_CLOSED\\"',
        '\\"entry_time\\\"',
        '\\"time\\\"',
        '\\"net\\\"',
        '\\"volume\\\"',
        '\\"mae_acct\\\"',
        '\\"notional\\\"',
        '\\"magic\\\"',
        '\\"symbol\\\"',
    ):
        assert legacy_field in source

    assert '"COMMISSION"' in source
    assert '"PROFIT"' in source
    assert '"SWAP"' in source
    assert '\\"deal_id\\\"' in source


def test_v2_prepares_before_framework_state_is_cleared_and_commits_after_close() -> None:
    source = _compact(_source(EA))
    deinit = source[source.index("voidOnDeinit(") : source.index("voidOnTick(")]

    prepare = deinit.index("QM_FJ_TradeV2Prepare()")
    shutdown = deinit.index("QM_FrameworkShutdown()")
    commit = deinit.index("QM_FJ_TradeV2Commit()")
    assert prepare < shutdown < commit
    assert "FTMO_TRADE_V2_SETUP_BLOCKED" in deinit


def test_evidence_modules_are_observers_only() -> None:
    combined = _source(EQUITY) + _source(TRADES)
    for mutation_api in (
        "OrderSend(",
        "CTrade",
        "QM_BasketOpenPosition(",
        "QM_TM_OpenPosition(",
        "QM_TM_ClosePosition(",
    ):
        assert mutation_api not in combined


def test_declared_equity_coverage_gap_reaches_the_intended_adapter_block() -> None:
    member = adapter.ExpectedMember(201810000, "USDJPY.DWX")
    meta = {
        "event": adapter.EQUITY_META_EVENT,
        "schema_version": adapter.ADAPTER_SCHEMA_VERSION,
        "q08_trade_schema_version": adapter.Q08_TRADE_SCHEMA_VERSION,
        "trace_id": "FTMO_BOOK3_20260729_V1_J0",
        "run_id": "FTMO_BOOK3_20260729_V1_J0",
        "producer_version": "QM5_20181_FTMO_TRACE_V2",
        "currency": "USD",
        "grid_seconds": 3600,
        "money_decimals": 2,
        "host_symbol": "USDJPY.DWX",
        "expected_members": [{"magic": member.magic, "symbol": member.symbol}],
        "balance_basis": adapter.rules_engine.BALANCE_BASIS_NET_TRADING,
        "equity_basis": adapter.rules_engine.EQUITY_BASIS_MTM,
        "opened_positions_basis": adapter.rules_engine.OPENED_POSITIONS_BASIS,
        "interval_min_equity_basis": adapter.rules_engine.INTERVAL_MIN_EQUITY_BASIS,
        "pending_orders_basis": adapter.PENDING_ORDERS_BASIS,
        "coverage_basis": adapter.COVERAGE_BASIS,
        "trade_net_basis": adapter.TRADE_NET_BASIS,
        "floating_basis": adapter.FLOATING_BASIS,
        "producer_status": "SETUP_DATA_MISSING",
        "coverage_observation_basis": (
            "HOST_TICK_PLUS_MODEL_SECOND_TIMER_NOT_EVENT_COMPLETE"
        ),
    }
    blocked_point = {
        "event": adapter.EQUITY_POINT_EVENT,
        "schema_version": adapter.ADAPTER_SCHEMA_VERSION,
        "trace_id": "FTMO_BOOK3_20260729_V1_J0",
        "run_id": "FTMO_BOOK3_20260729_V1_J0",
        "producer_version": "QM5_20181_FTMO_TRACE_V2",
        "coverage_complete": False,
    }
    provenance = adapter.ProvenanceBinding(
        work_item_id="ftmo-book3-static-fixture",
        evidence_run_id="FTMO_BOOK3_20260729_V1_J0",
        producer_version="QM5_20181_FTMO_TRACE_V2",
        runner_receipt_path="receipt.json",
        runner_receipt_sha256="c" * 64,
        ex5_path="20181.ex5",
        ex5_sha256="d" * 64,
        setfile_path="j0.set",
        setfile_sha256="e" * 64,
        report_path="report.htm",
        report_sha256="f" * 64,
    )
    rules_snapshot = adapter.RuleSnapshotBinding(
        path="rules.json",
        sha256="1" * 64,
        source_url=adapter.rules_engine.RULES_SOURCE_URL,
        source_observations_sha256="2" * 64,
        retrieved_at_utc="2026-07-29T00:00:00Z",
        engine_profile_sha256="3" * 64,
        age_seconds_at_evaluation=0,
    )

    artifact, trace = adapter.adapt_and_evaluate(
        [],
        [meta, blocked_point],
        expected_members=[member],
        trade_sha256="a" * 64,
        equity_sha256="b" * 64,
        phase="PHASE1",
        provenance=provenance,
        rules_snapshot=rules_snapshot,
    )

    assert artifact["status"] == "SETUP_DATA_MISSING"
    assert artifact["reason"] == "equity_point_coverage_incomplete:0"
    assert artifact["money_gate_eligible"] is False
    assert trace is None
