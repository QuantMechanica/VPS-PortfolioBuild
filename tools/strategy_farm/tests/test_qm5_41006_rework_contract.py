from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_41006_man-ahl-multispeed-ewma-trend"
EA = EA_DIR / "QM5_41006_man-ahl-multispeed-ewma-trend.mq5"
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
        "double g_forecast1", 1
    )[0]
    return re.findall(
        r"\binput\s+(?:bool|double|int|string|uint)\s+([A-Za-z_]\w*)\s*=",
        strategy_group,
    )


def test_forecast_uses_bounded_return_volatility_and_all_six_ema_pairs() -> None:
    source = _source()
    compact = _compact(source)

    assert "iClose(" not in source
    assert source.count("CopyClose(") == 1
    assert "perf-allowed:oneboundednew-bar-onlyvolatilitybuffer" in compact
    assert "copied==required&&ArraySize(closes)>=required" in compact
    assert "ArraySize(closes)<required" in compact
    assert "daily_return=c0/c1-1.0" in compact
    assert "sigma=closes[offset]*MathSqrt(variance)" in compact
    assert "QM_ATR(_Symbol,PERIOD_D1,InpVolWindow" not in compact
    assert "pairs_fast[6]={2,4,8,16,32,64}" in compact
    assert "pairs_slow[6]={8,16,32,64,128,256}" in compact
    assert "!MathIsValidNumber(ema_f)||!MathIsValidNumber(ema_s)" in compact


def test_continuous_rebalance_scales_framework_risk_and_preserves_retry_intent() -> None:
    source = _source()
    compact = _compact(source)

    assert "exposure=MathMin(1.0,MathAbs(g_forecast1))" in compact
    assert "risk_value=RISK_FIXED*exposure" in compact
    assert "risk_value=RISK_PERCENT*exposure" in compact
    assert "QM_TM_ClosePosition(ticket,QM_EXIT_STRATEGY)" in compact
    assert "g_rebalance_pending_direction=same_direction" in compact
    assert "is_new_bar||g_rebalance_pending_direction!=0" in compact
    assert "if(opened)g_rebalance_pending_direction=0" in compact
    assert "boolStrategy_ExitSignal(){" in compact
    assert "returnfalse;" in compact.split("boolStrategy_ExitSignal(){", 1)[1].split("}", 1)[0]


def test_management_and_mae_remain_reachable_when_entry_gates_block() -> None:
    source = _source()
    on_tick = source.split("void OnTick()", 1)[1].split("void OnTimer()", 1)[0]

    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(!g_rebalance_entries_allowed)"
    )
    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert "if(Strategy_NoTradeFilter()) return;" not in on_tick
    assert "if(!news_allows)" not in on_tick


def test_loss_limits_gmt_contract_and_execution_contract_are_wired() -> None:
    source = _source()
    compact = _compact(source)

    assert "QM_BrokerToUTC(TimeCurrent())" in compact
    assert "InpDailyLossEntryHaltPct/100.0" in compact
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "InpDailyHardStopPct,InpTotalDrawdownStopPct,1.0)"
    ) in compact
    assert (
        "QM_FrameworkDeclareExecutionContract(PERIOD_D1,"
        "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,"
        '"DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED")'
    ) in compact


def test_every_declared_strategy_input_is_consumed_and_sealed_in_all_sets() -> None:
    source = _source()
    inputs = _strategy_inputs(source)

    assert len(SETS) == 4
    assert set(inputs) == {
        "InpForecastThreshold",
        "InpVolWindow",
        "InpAtrSlPeriod",
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
    compact = _compact(source).lower()

    assert "#include<QM/QM_Common.mqh>".lower() in compact
    assert "RISK_PERCENT=0.0" in _compact(source)
    assert "RISK_FIXED=1000.0" in _compact(source)
    assert "QM_FrameworkMagic()" in source
    assert "QM_TM_OpenPosition(req,out_ticket,0,risk_mode,risk_value)" in _compact(source)
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert not re.search(r"\b(?:iMA|iATR|iRSI|iMACD|iADX|iBands)\s*\(", source)
    assert not re.search(r"\b(?:OrderSend|Sleep|CopyBuffer)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)


def test_all_backtest_sets_use_fixed_risk_and_registered_slots() -> None:
    expected_slots = {
        "NDX.DWX": "0",
        "SP500.DWX": "1",
        "XTIUSD.DWX": "2",
        "XAUUSD.DWX": "3",
    }
    observed: dict[str, str] = {}
    for path in SETS:
        values = _set_values(path)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        symbol = next(symbol for symbol in expected_slots if symbol in path.name)
        observed[symbol] = values["qm_magic_slot_offset"]

    assert observed == expected_slots
