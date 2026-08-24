from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = (
    REPO
    / "framework"
    / "EAs"
    / "QM5_39007_forexfactory-100-pips-early-bird-breakout"
)
EA = EA_DIR / "QM5_39007_forexfactory-100-pips-early-bird-breakout.mq5"
SETS = sorted((EA_DIR / "sets").glob("*_M15_backtest.set"))


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_m15_contract_framework_magic_and_risk_modes_are_explicit() -> None:
    source = _compact(_source())

    assert "#include<QM/QM_Common.mqh>" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_M15" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" not in source
    assert "inputdoubleRISK_PERCENT=0.0;" in source
    assert "inputdoubleRISK_FIXED=1000.0;" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source


def test_exact_closed_box_and_pending_straddle_oco_are_wired() -> None:
    source = _compact(_source())

    assert "(InpBoxEndHourUTC-InpBoxStartHourUTC)*4" in source
    assert "CopyRates(_Symbol,PERIOD_M15,1,box_bars,rates)" in source
    assert "copied!=box_bars||ArraySize(rates)<box_bars" in source
    assert "bar_minute<start_minute||bar_minute>=end_minute" in source
    assert "Strategy_BuildStopRequest(QM_BUY_STOP" in source
    assert "Strategy_BuildStopRequest(QM_SELL_STOP" in source
    assert "req.expiration_seconds=expiration_seconds;" in source
    assert "EARLY_BIRD_OCO_SIBLING" in source
    assert "EARLY_BIRD_OCO_FILL_TRANSACTION" in source
    assert "EARLY_BIRD_STRADDLE_ROLLBACK" in source
    assert source.count("QM_TM_OpenPosition(") == 2


def test_pip_units_tp1_tp2_and_noon_cancel_match_card() -> None:
    source = _compact(_source())

    assert "QM_StopRulesPipsToPriceDistance(_Symbol,1)" in source
    assert "InpBufferPips*10.0" not in source
    assert "InpStopLossPips*10.0" not in source
    assert "InpTakeProfitPips*10.0" not in source
    assert "Strategy_PipsToPriceDistance(InpTakeProfit2Pips)" in source
    assert "Strategy_PipsToPriceDistance(InpTakeProfitPips)" in source
    assert "QM_TM_PartialClose(ticket,close_volume,QM_EXIT_PARTIAL)" in source
    assert "QM_TM_MoveToBreakEven(ticket,strategy_be_trigger_pips,1)" in source
    assert "EARLY_BIRD_NOON_CANCEL" in source

    exit_hook = source[
        source.index("boolStrategy_ExitSignal()") :
        source.index("boolStrategy_NewsFilterHook")
    ]
    assert "returnfalse;" in exit_hook
    assert "QM_TM_ClosePosition(" not in exit_hook


def test_loss_controls_are_both_entry_halt_and_hard_flatten() -> None:
    source = _compact(_source())

    assert "g_daily_realized_loss_pct>=strategy_daily_loss_halt_pct" in source
    assert "daily_drawdown_pct>=strategy_daily_hard_stop_pct" in source
    assert "total_drawdown_pct>=strategy_total_dd_halt_pct" in source
    assert "QM_KillSwitchTrip(KS_DAILY_LOSS" in source
    assert 'QM_KillSwitchTrip("KS_TOTAL_DRAWDOWN"' in source
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_hard_stop_pct,strategy_total_dd_halt_pct,"
        "strategy_per_trade_risk_cap_pct)"
    ) in source


def test_every_declared_input_has_a_non_declaration_use_site() -> None:
    source = _source()
    inputs = re.findall(r"^input\s+\w+\s+(\w+)\s*=", source, flags=re.MULTILINE)

    assert inputs
    missing = [name for name in inputs if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2]
    assert missing == []


def test_backtest_sets_bind_all_strategy_defaults_and_fixed_risk() -> None:
    assert len(SETS) == 2
    expected = {
        "RISK_FIXED": "1000",
        "RISK_PERCENT": "0",
        "InpBoxStartHourUTC": "5",
        "InpBoxEndHourUTC": "7",
        "InpSessionEndHourUTC": "12",
        "InpBufferPips": "3.0",
        "InpStopLossPips": "25.0",
        "InpTakeProfitPips": "50.0",
        "InpTakeProfit2Pips": "100.0",
        "strategy_atr_period": "14",
        "strategy_be_trigger_pips": "20",
        "strategy_tp1_close_fraction": "0.50",
        "strategy_daily_loss_halt_pct": "2.0",
        "strategy_daily_hard_stop_pct": "2.5",
        "strategy_total_dd_halt_pct": "5.0",
        "strategy_per_trade_risk_cap_pct": "1.0",
        "strategy_slippage_ticks": "3.0",
    }

    for setfile in SETS:
        values = _set_values(setfile)
        assert {key: values.get(key) for key in expected} == expected


def test_forbidden_execution_and_indicator_surfaces_are_absent() -> None:
    source = _source()

    for forbidden in (
        "OrderSend(",
        "PositionClose(",
        "PositionClosePartial(",
        "iATR(",
        "CopyBuffer(",
        "tensorflow",
        "torch",
        "sklearn",
        "keras",
        "onnx",
    ):
        assert forbidden not in source

    for raw_series_call in re.findall(r"\b(iTime|iHigh|iLow|iClose)\s*\([^;]+;", source):
        assert raw_series_call == "iTime"
    assert "iTime(_Symbol, PERIOD_M15, 0); // perf-allowed:" in source
