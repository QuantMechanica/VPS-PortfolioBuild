from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = (
    ROOT
    / "framework"
    / "scripts"
    / "mt5_diagnostics"
    / "Export_FTMO_EventComplete_Ticks.mq5"
)


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def test_export_is_read_only_and_uses_full_raw_tick_store() -> None:
    source = _source()
    assert "CopyTicksRange" in source
    assert "COPY_TICKS_ALL" in source
    assert '\\"schema\\":\\"FTMO_TICK_V1\\"' in source
    assert "time_msc" in source
    assert "source_sequence" in source
    assert "OrderSend" not in source
    assert "PositionClose" not in source
    assert "trade.Buy" not in source
    assert "trade.Sell" not in source


def test_export_has_fail_closed_chunk_and_completion_contract() -> None:
    source = _source()
    assert "if(copied < 0 || error != 0)" in source
    assert "if(copied >= 0 && error == 0)" in source
    assert "FTMO_EVENT_TICK_COPY_FAILED" in source
    assert "FTMO_EVENT_TICK_ORDER_INVALID" in source
    assert '\\"copy_status\\":\\"COPY_RANGE_COMPLETE\\"' in source
    assert '\\"raw_copy_complete\\":true' in source
    assert '\\"market_coverage_complete\\":false' in source
    assert "RemoveStaleComplete(TickStem(symbols[i])" in source
    assert "RemoveStaleComplete(RunCompletePath())" in source
    assert "SameTick(prior_tick, tick)" in source
    assert '\\"volume\\":%I64u' in source
    assert '\\"volume_real\\":%s' in source
    assert "!MathIsValidNumber(tick.bid)" in source
    assert "!MathIsValidNumber(tick.ask)" in source
    assert "!MathIsValidNumber(tick.last)" in source
    assert "!MathIsValidNumber(tick.volume_real)" in source
    assert "tick.bid <= 0.0" in source
    assert "tick.ask <= 0.0" in source
    assert "tick.last < 0.0" in source
    assert "tick.volume_real < 0.0" in source


def test_export_captures_replay_calculation_properties() -> None:
    source = _source()
    required = {
        "SYMBOL_TRADE_CALC_MODE",
        "SYMBOL_TRADE_TICK_SIZE",
        "SYMBOL_TRADE_TICK_VALUE_PROFIT",
        "SYMBOL_TRADE_TICK_VALUE_LOSS",
        "SYMBOL_TRADE_CONTRACT_SIZE",
        "SYMBOL_CURRENCY_BASE",
        "SYMBOL_CURRENCY_PROFIT",
        "SYMBOL_CURRENCY_MARGIN",
        "SYMBOL_VOLUME_STEP",
        "SYMBOL_MARGIN_INITIAL",
        "SYMBOL_MARGIN_MAINTENANCE",
        "SYMBOL_SWAP_LONG",
        "SYMBOL_SWAP_SHORT",
        "SYMBOL_SWAP_MODE",
        "SYMBOL_SWAP_ROLLOVER3DAYS",
        "SYMBOL_SWAP_SUNDAY",
        "SYMBOL_SWAP_MONDAY",
        "SYMBOL_SWAP_TUESDAY",
        "SYMBOL_SWAP_WEDNESDAY",
        "SYMBOL_SWAP_THURSDAY",
        "SYMBOL_SWAP_FRIDAY",
        "SYMBOL_SWAP_SATURDAY",
    }
    for token in required:
        assert token in source
    assert '\\"schema\\":\\"FTMO_SYMBOL_PROPERTIES_V1\\"' in source
    assert '\\"conversion_mode\\"' in source
    assert "SymbolInfoSessionQuote" in source
    assert "SymbolInfoSessionTrade" in source
    assert '\\"quote_sessions\\"' in source
    assert '\\"trade_sessions\\"' in source
    assert '\\"session_snapshot_complete\\":true' in source
    assert "session_index <= 64" in source
    assert "session_index == 64" in source
    assert "ERR_MARKET_SESSION_INDEX" in source


def test_export_requires_exact_three_symbol_run_and_safe_identity() -> None:
    source = _source()
    assert "symbol_count != 3" in source
    assert "SafeToken(InpEvidenceRunId)" in source
    assert "FTMO_EVENT_TICK_SYMBOL_DUPLICATE" in source
    assert "SafeSymbol(symbols[i]) == SafeSymbol(symbols[j])" in source
    assert "!SafeToken(SafeSymbol(symbols[i]))" in source
    assert "InpToBrokerWallExclusive <= InpFromBrokerWall" in source
    assert 'InpRawTimeBasis = "DARWINEX_US_DST_BROKER_WALL_EPOCH"' in source
    assert 'InpRawTimeBasis != "DARWINEX_US_DST_BROKER_WALL_EPOCH"' in source
    assert '\\"time_basis\\":\\"DARWINEX_US_DST_BROKER_WALL_EPOCH\\"' in source
    assert 'conversion_mode == "UNSUPPORTED"' in source
    assert 'StringFind(calc_mode, "UNSUPPORTED_") == 0' in source
    assert "custom == 0" in source
    assert "!MathIsValidNumber(point)" in source
    assert "error == 0" in source
    assert "if(!complete_written)" in source
    assert "account_currency_source" in source
    assert "account_contract_requires_history_reconciliation" in source
