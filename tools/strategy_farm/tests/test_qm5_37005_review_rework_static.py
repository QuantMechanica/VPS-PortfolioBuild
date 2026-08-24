from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_37005_chan-bollinger-adx-mean-reversion"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8-sig")


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

    assert "if(g_cached_bb_middle<=ask)returnfalse;" in compact
    assert "if(g_cached_bb_middle>=bid)returnfalse;" in compact
    assert compact.count("req.tp=g_cached_bb_middle;") == 2
    assert "ask+sl_dist" not in compact
    assert "bid-sl_dist" not in compact

    assert "strategy_daily_loss_limit_pct=2.00" in compact
    assert "strategy_daily_drawdown_hard_stop_pct=2.50" in compact
    assert "strategy_total_drawdown_stop_pct=5.00" in compact
    assert "g_daily_entry_halt=true;" in compact
    assert "HistorySelect(day_start,now)" in compact
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_drawdown_hard_stop_pct,"
        "strategy_total_drawdown_stop_pct,1.0)"
    ) in compact


def test_strategy_inputs_are_all_wired_and_bounded() -> None:
    source = _source()
    compact = _compact(source)
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(
        r"^input\s+\S+\s+(strategy_[a-z0-9_]+)\s*=", strategy_block, re.MULTILINE
    )

    assert names == [
        "strategy_bb_period",
        "strategy_bb_dev",
        "strategy_adx_period",
        "strategy_max_adx",
        "strategy_atr_period",
        "strategy_sl_atr_mult",
        "strategy_spread_atr_mult",
        "strategy_max_spread_points",
        "strategy_daily_loss_limit_pct",
        "strategy_daily_drawdown_hard_stop_pct",
        "strategy_total_drawdown_stop_pct",
        "strategy_max_slippage_ticks",
    ]
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    assert "strategy_bb_period>=14&&strategy_bb_period<=30" in compact
    assert "strategy_max_spread_points>=50&&strategy_max_spread_points<=300" in compact
    assert "MathAbs(strategy_daily_loss_limit_pct-2.0)<=1e-9" in compact
    assert "MathAbs(strategy_daily_drawdown_hard_stop_pct-2.5)<=1e-9" in compact
    assert "MathAbs(strategy_total_drawdown_stop_pct-5.0)<=1e-9" in compact
    assert "MathAbs(strategy_max_slippage_ticks-3.0)<=1e-9" in compact
    assert "if(!StrategyInputsValid())returnINIT_PARAMETERS_INCORRECT;" in compact


def test_framework_chain_magic_mae_and_bounded_data_access() -> None:
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
    assert "37005*10000" not in compact
    assert "QM_StopATRFromValue" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H1" in compact

    for applied_price in ("PRICE_OPEN", "PRICE_HIGH", "PRICE_LOW", "PRICE_CLOSE"):
        assert f"1,1,{applied_price})" in compact

    forbidden = (
        "iATR(",
        "iMA(",
        "iClose(",
        "iOpen(",
        "iHigh(",
        "iLow(",
        "CopyBuffer(",
        "CopyRates(",
        "CopyClose(",
        "CopyOpen(",
        "CopyHigh(",
        "CopyLow(",
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


def test_backtest_setfiles_bind_card_defaults_and_risk_mode() -> None:
    setfiles = sorted(SETS.glob(f"{LABEL}_*_H1_backtest.set"))
    assert len(setfiles) == 3
    assert {
        path.name.split(f"{LABEL}_", 1)[1].split("_H1_", 1)[0] for path in setfiles
    } == {"EURUSD.DWX", "USDCAD.DWX", "AUDCAD.DWX"}

    for path in setfiles:
        values = _set_values(path)
        assert values["qm_ea_id"] == "37005"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["PORTFOLIO_WEIGHT"] == "1"
        assert values["strategy_daily_loss_limit_pct"] == "2.00"
        assert values["strategy_daily_drawdown_hard_stop_pct"] == "2.50"
        assert values["strategy_total_drawdown_stop_pct"] == "5.00"
        assert values["strategy_max_slippage_ticks"] == "3.00"
