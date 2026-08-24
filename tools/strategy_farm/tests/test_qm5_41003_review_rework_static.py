from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_41003_kaufman-ready-set-go-momentum"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _function(source: str, name: str, next_name: str) -> str:
    start = source.index(name)
    end = source.index(next_name, start)
    return source[start:end]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_review_findings_are_fixed_card_faithfully() -> None:
    source = _source()
    compact = _compact(source)
    advance = _function(source, "void AdvanceState_OnNewBar", "bool Strategy_NoTradeFilter")

    assert "g_atr_sma=atr_sum/(double)strategy_slow_atr_period;" in compact
    assert "strategy_fast_atr_period,1+i" in _compact(advance)
    assert "constdoublec5=QM_SMA(_Symbol,strategy_signal_tf,1,strategy_momentum_bars,PRICE_CLOSE);" in compact
    assert "1+strategy_momentum_bars" not in compact

    first_read = advance.index("QM_SMA(")
    for reset in (
        "g_last_signal = 0;",
        "g_fast_atr = 0.0;",
        "g_atr_sma = 0.0;",
        "g_spread_atr = 0.0;",
        "g_close5 = 0.0;",
    ):
        assert advance.index(reset) < first_read

    assert "constdoublespread_atr=QM_ATR(_Symbol,strategy_signal_tf,14,1);" in compact
    assert "spread>g_spread_atr*strategy_spread_filter_mult" in compact
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H1,QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in compact
    assert "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),strategy_daily_dd_hard_stop_pct,strategy_total_drawdown_stop_pct,1.0)" in compact
    assert "strategy_daily_loss_limit_pct=2.0" in compact
    assert "strategy_daily_dd_hard_stop_pct=2.5" in compact
    assert "strategy_total_drawdown_stop_pct=5.0" in compact
    assert "g_daily_entry_halt=true;//historyfailuremustfailclosed" in compact
    assert "HistorySelect(day_start,now)" in compact


def test_strategy_inputs_are_wired_and_bounded() -> None:
    source = _source()
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(r"^input\s+\S+\s+(strategy_[a-z0-9_]+)\s*=", strategy_block, re.MULTILINE)

    assert names == [
        "strategy_signal_tf",
        "strategy_fast_atr_period",
        "strategy_slow_atr_period",
        "strategy_trend_ema_period",
        "strategy_momentum_bars",
        "strategy_go_atr_mult",
        "strategy_sl_atr_mult",
        "strategy_tp_rr_mult",
        "strategy_rollover_start_hhmm",
        "strategy_rollover_end_hhmm",
        "strategy_spread_filter_mult",
        "strategy_daily_loss_limit_pct",
        "strategy_daily_dd_hard_stop_pct",
        "strategy_total_drawdown_stop_pct",
    ]
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    compact = _compact(source)
    assert "strategy_fast_atr_period>=5&&strategy_fast_atr_period<=15" in compact
    assert "strategy_slow_atr_period>=20&&strategy_slow_atr_period<=50" in compact
    assert "strategy_trend_ema_period>=30&&strategy_trend_ema_period<=80" in compact
    assert "strategy_momentum_bars>=3&&strategy_momentum_bars<=10" in compact
    assert "MathAbs(strategy_daily_loss_limit_pct-2.0)<=1e-9" in compact
    assert "MathAbs(strategy_daily_dd_hard_stop_pct-2.5)<=1e-9" in compact
    assert "MathAbs(strategy_total_drawdown_stop_pct-5.0)<=1e-9" in compact
    assert "if(!StrategyInputsValid())returnINIT_PARAMETERS_INCORRECT;" in compact
    assert "for(inti=0;i<strategy_slow_atr_period;++i)" in compact


def test_framework_chain_risk_magic_mae_and_forbidden_calls() -> None:
    source = _source()
    compact = _compact(source)
    on_tick = _function(source, "void OnTick", "void OnTimer")

    assert "#include <QM/QM_Common.mqh>" in source
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert "QM_FrameworkMagic()" in source
    assert "41003*10000" not in compact
    assert "QM_StopATRFromValue" in source
    assert "QM_TakeRR" in source

    forbidden = (
        "iATR(",
        "iMA(",
        "iClose(",
        "CopyBuffer(",
        "CopyRates(",
        "OrderSend(",
        "tensorflow",
        "torch",
        "sklearn",
        "keras",
        "onnx",
    )
    lowered = source.lower()
    for token in forbidden:
        assert token.lower() not in lowered, token

    setfiles = sorted(SETS.glob(f"{LABEL}_*_H1_backtest.set"))
    assert len(setfiles) == 3
    assert {path.name.split(f"{LABEL}_", 1)[1].split("_H1_", 1)[0] for path in setfiles} == {
        "SP500.DWX",
        "NDX.DWX",
        "GDAXI.DWX",
    }
    for path in setfiles:
        values = _set_values(path)
        assert values["qm_ea_id"] == "41003"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["PORTFOLIO_WEIGHT"] == "1"
        assert values["strategy_daily_loss_limit_pct"] == "2.0"
        assert values["strategy_daily_dd_hard_stop_pct"] == "2.5"
        assert values["strategy_total_drawdown_stop_pct"] == "5.0"
