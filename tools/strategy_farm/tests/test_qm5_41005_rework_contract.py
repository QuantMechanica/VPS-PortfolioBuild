from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_41005_richard-donchian-50day-cta-benchmark"
EA = EA_DIR / "QM5_41005_richard-donchian-50day-cta-benchmark.mq5"
CARD = REPO / "strategy-seeds" / "cards" / "approved" / "QM5_41005_richard-donchian-50day-cta-benchmark.md"
SETS = sorted((EA_DIR / "sets").glob("*_backtest.set"))


def _source(path: Path = EA) -> str:
    return path.read_text(encoding="utf-8")


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
        "double g_spread_atr", 1
    )[0]
    return re.findall(
        r"\binput\s+(?:bool|double|int|string|uint)\s+([A-Za-z_]\w*)\s*=",
        strategy_group,
    )


def test_card_mechanism_uses_one_bounded_new_bar_channel_buffer() -> None:
    source = _source()
    compact = _compact(source)

    assert "iClose(" not in source
    assert "iHigh(" not in source
    assert "iLow(" not in source
    assert source.count("CopyRates(") == 1
    assert "perf-allowed:oneboundednew-bar-onlychannelbuffer" in compact
    assert "copied!=required||ArraySize(rates)<required" in compact
    assert "for(inti=1;i<=lookback;++i)" in compact
    assert "rates[0].close" in compact
    assert "CalculateDonchianBreakout(rates,InpEntryLookback,g_entry_breakout)" in compact
    assert "CalculateDonchianBreakout(rates,InpExitLookback,g_exit_breakout)" in compact
    assert "QM_ATR(_Symbol,PERIOD_D1,InpAtrPeriod,1)" in compact
    assert "ask-InpAtrSlMult*g_stop_atr" in compact
    assert "bid+InpAtrSlMult*g_stop_atr" in compact


def test_execution_and_loss_limit_contracts_are_wired() -> None:
    source = _source()
    compact = _compact(source)

    assert (
        "QM_FrameworkDeclareExecutionContract(PERIOD_D1,"
        "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,"
        '"DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED")'
    ) in compact
    assert "InpDailyLossEntryHaltPct/100.0" in compact
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "InpDailyHardStopPct,InpTotalDrawdownStopPct,1.0)"
    ) in compact
    assert "QM_BrokerToUTC(TimeCurrent())" in compact


def test_management_exit_and_mae_are_reachable_before_entry_filters() -> None:
    source = _source()
    on_tick = source.split("void OnTick()", 1)[1].split("void OnTimer()", 1)[0]

    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_ExitSignal()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("QM_EquityStreamOnNewBar();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )


def test_every_declared_strategy_input_is_consumed_and_sealed_in_all_sets() -> None:
    source = _source()
    inputs = _strategy_inputs(source)

    assert len(SETS) == 4
    assert set(inputs) == {
        "InpEntryLookback",
        "InpExitLookback",
        "InpAtrPeriod",
        "InpAtrSlMult",
        "InpSpreadAtrMult",
        "InpDailyLossEntryHaltPct",
        "InpDailyHardStopPct",
        "InpTotalDrawdownStopPct",
    }
    for name in inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) > 1, name
        assert all(name in _set_values(path) for path in SETS), name


def test_framework_risk_magic_and_forbidden_mechanisms_are_conformant() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "RISK_PERCENT=0.0" in compact
    assert "RISK_FIXED=1000.0" in compact
    assert "QM_FrameworkMagic()" in source
    assert "QM_TM_OpenPosition(req,out_ticket)" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert not re.search(r"\b(?:iMA|iATR|iRSI|iMACD|iADX|iBands)\s*\(", source)
    assert not re.search(r"\b(?:OrderSend|Sleep|CopyBuffer)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_card_and_backtest_sets_preserve_v5_risk_and_registered_slots() -> None:
    card = _source(CARD)
    assert "g0_status: APPROVED" in card
    assert "`InpRiskPercent`" in card
    assert "`0.20 - 1.00`" in card

    expected_slots = {
        "XTIUSD.DWX": "0",
        "XAUUSD.DWX": "1",
        "SP500.DWX": "2",
        "EURUSD.DWX": "3",
    }
    observed: dict[str, str] = {}
    for path in SETS:
        values = _set_values(path)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        symbol = next(symbol for symbol in expected_slots if symbol in path.name)
        observed[symbol] = values["qm_magic_slot_offset"]

    assert observed == expected_slots
