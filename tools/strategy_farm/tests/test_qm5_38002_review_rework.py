from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_38002_codetrading-macd-ema-trend-pullback"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"


def source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def strategy_inputs(text: str) -> dict[str, str]:
    block = text.split('input group "Strategy"', 1)[1]
    declarations = re.findall(
        r"(?m)^input\s+\S+\s+(strategy_[A-Za-z0-9_]+)\s*=\s*([^;]+);",
        block,
    )
    return {name: value.strip() for name, value in declarations}


def test_card_stop_and_execution_controls_are_wired() -> None:
    text = source()

    assert "strategy_atr_sl_mult" not in text
    assert "CopyRates(_Symbol" in text
    assert "ArraySize(swing_rates) < strategy_swing_lookback" in text
    assert "g_swing_low - sl_buffer" in text
    assert "g_swing_high + sl_buffer" in text
    assert "QM_StopRulesPipsToPriceDistance" in text
    assert "StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent()))" in text
    assert "StrategyDeviationPoints()" in text
    assert "QM_EntryConfigure(qm_ea_id" in text
    assert "QM_FrameworkSetRiskCapPct(strategy_per_trade_risk_cap_pct)" in text
    assert re.search(
        r"QM_KillSwitchInit\(qm_ea_id,\s*QM_FrameworkMagic\(\),\s*"
        r"strategy_daily_hard_stop_pct,\s*strategy_total_drawdown_stop_pct,\s*"
        r"strategy_per_trade_risk_cap_pct\)",
        text,
    )


def test_management_precedes_entry_only_filters_and_state_is_seeded() -> None:
    text = source()
    on_init = text.split("int OnInit()", 1)[1].split("void OnDeinit", 1)[0]
    on_tick = text.split("void OnTick()", 1)[1].split("void OnTimer", 1)[0]

    assert on_init.index("AdvanceState_OnNewBar();") > on_init.index("QM_KillSwitchInit")
    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NewsFilterHook"
    )


def test_every_strategy_input_is_consumed_and_bound_in_each_setfile() -> None:
    text = source()
    inputs = strategy_inputs(text)
    assert inputs
    for name in inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", text)) >= 2, name

    setfiles = sorted(SETS_DIR.glob(f"{EA_LABEL}_*_M15_backtest.set"))
    assert len(setfiles) == 3
    for setfile in setfiles:
        settings = setfile.read_text(encoding="utf-8-sig")
        for name, default in inputs.items():
            expected = "15" if default == "PERIOD_M15" else default.lower()
            assert re.search(
                rf"(?m)^{re.escape(name)}={re.escape(expected)}$", settings
            ), f"{setfile.name}: {name}={expected}"
        assert "RISK_FIXED=1000" in settings
        assert "RISK_PERCENT=0" in settings
