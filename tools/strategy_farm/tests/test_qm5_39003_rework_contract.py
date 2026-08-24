from __future__ import annotations

import csv
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_39003_forexfactory-james16-price-action-ppz"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
CARD = (
    REPO
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_39003_forexfactory-james16-price-action-ppz.md"
)
SETS = sorted((EA_DIR / "sets").glob("*_backtest.set"))
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"


def _source(path: Path = EA) -> str:
    return path.read_text(encoding="utf-8-sig")


def _compact(value: str) -> str:
    return "".join(value.split())


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in _source(path).splitlines():
        line = raw_line.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def _strategy_inputs(source: str) -> list[str]:
    strategy_group = source.split('input group "Strategy"', 1)[1].split(
        "double g_initial_equity", 1
    )[0]
    return re.findall(
        r"\binput\s+(?:bool|double|int|string|uint)\s+([A-Za-z_]\w*)\s*=",
        strategy_group,
    )


def test_ppz_entry_target_and_trailing_are_card_faithful_and_bounded() -> None:
    source = _source()
    compact = _compact(source)

    assert source.count("CopyRates(") == 1
    assert "perf-allowed:oneboundedD1structurebuffer" in compact
    assert "copied==required&&ArraySize(rates)>=required" in compact
    assert "StrategyIsSwingLow(rates,index)" in compact
    assert "StrategyIsSwingHigh(rates,index)" in compact
    assert "index=2;index<=InpPPZLookback-1;++index" in compact

    assert "next_resistance" in source
    assert "next_support" in source
    assert "tp=QM_StopRulesNormalizePrice(_Symbol,next_resistance)" in compact
    assert "tp=QM_StopRulesNormalizePrice(_Symbol,next_support)" in compact
    assert "tp<minimum_target" in compact
    assert "tp>minimum_target" in compact
    assert "QM_TakeRR(" not in source

    assert "StrategyFindLatestSwing(rates,is_buy,swing_level)" in compact
    assert "QM_TM_MoveSL(ticket,target_sl,\"JAMES16_DYNAMIC_SWING_TRAIL\")" in compact
    assert "QM_StopRulesPipsToPriceDistance(_Symbol,strategy_sl_buffer_pips)" in compact
    assert not re.search(
        r"QM_StopRulesPipsToPriceDistance\([^)]*(?:\*\s*10|10\s*\*)", source
    )


def test_filters_and_card_loss_limits_are_executable() -> None:
    source = _source()
    compact = _compact(source)

    assert "QM_BrokerToUTC(broker_now)" in compact
    assert "utc_parts.hour==23&&utc_parts.min>=55" in compact
    assert "utc_parts.hour==0&&utc_parts.min<=5" in compact
    assert "(ask-bid)>strategy_spread_atr_multiplier*cached_atr" in compact
    assert "QM_TM_OpenPositionCount(magic)>=strategy_max_open_positions" in compact
    assert "QM_ChartUITodayPnL(0,closed_trades_today)" in compact
    assert "strategy_daily_entry_loss_limit_pct/100.0" in compact
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_drawdown_stop_pct,strategy_total_drawdown_stop_pct,1.0)"
    ) in compact
    assert "returnStrategyTotalDrawdownBreached();" in compact


def test_management_and_exits_run_before_entry_only_filters() -> None:
    source = _source()
    on_tick = source.split("void OnTick()", 1)[1].split("void OnTimer()", 1)[0]

    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_NoTradeFilter()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert on_tick.index("QM_NewsAllowsTrade2") < on_tick.index("QM_IsNewBar()")


def test_every_strategy_input_is_used_and_sealed_in_every_setfile() -> None:
    source = _source()
    inputs = _strategy_inputs(source)

    assert len(SETS) == 3
    assert set(inputs) == {
        "InpPPZLookback",
        "InpTrendEMA",
        "strategy_atr_period",
        "strategy_ppz_zone_atr_fraction",
        "strategy_pinbar_wick_fraction",
        "strategy_pinbar_body_fraction",
        "strategy_spread_atr_multiplier",
        "strategy_sl_buffer_pips",
        "strategy_reward_risk",
        "strategy_slippage_tolerance_ticks",
        "strategy_max_open_positions",
        "strategy_daily_entry_loss_limit_pct",
        "strategy_daily_drawdown_stop_pct",
        "strategy_total_drawdown_stop_pct",
    }
    for name in inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) > 1, name
        assert all(name in _set_values(path) for path in SETS), name


def test_framework_risk_magic_mae_and_forbidden_calls_are_conformant() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "RISK_PERCENT=0.0" in compact
    assert "RISK_FIXED=1000.0" in compact
    assert "QM_FrameworkMagic()" in source
    assert "QM_TM_OpenPosition(req,out_ticket)" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in compact
    assert not re.search(r"\b(?:iOpen|iHigh|iLow|iClose|iMA|iATR|iRSI|iMACD|iADX|iBands)\s*\(", source)
    assert not re.search(r"\b(?:OrderSend|Sleep|CopyBuffer)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_approved_card_risk_mapping_and_registered_slots_are_exact() -> None:
    card = _source(CARD)
    assert "g0_status: APPROVED" in card
    assert "`InpRiskPercent`" in card
    assert "`0.50`" in card
    assert "input double InpRiskPercent" not in _source()

    expected_slots = {
        "EURUSD.DWX": "0",
        "GBPUSD.DWX": "1",
        "XAUUSD.DWX": "2",
    }
    observed: dict[str, str] = {}
    for path in SETS:
        values = _set_values(path)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        symbol = next(symbol for symbol in expected_slots if symbol in path.name)
        observed[symbol] = values["qm_magic_slot_offset"]
    assert observed == expected_slots

    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "39003"]
    assert {
        (row["symbol_slot"], row["symbol"], row["status"]) for row in rows
    } == {
        ("0", "EURUSD.DWX", "active"),
        ("1", "GBPUSD.DWX", "active"),
        ("2", "XAUUSD.DWX", "active"),
    }
