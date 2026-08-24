from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_38004_codetrading-triple-ema-momentum-scalper"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"
MAGIC_RESOLVER = REPO / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"

EXPECTED_SLOTS = {"NDX.DWX": 0, "WS30.DWX": 1, "GDAXI.DWX": 2}
EXPECTED_STRATEGY_DEFAULTS = {
    "strategy_signal_tf": "5",
    "strategy_fast_ema_period": "8",
    "strategy_med_ema_period": "21",
    "strategy_slow_ema_period": "55",
    "strategy_atr_period": "14",
    "strategy_sl_buffer_pips": "2",
    "strategy_tp_rr": "2.0",
    "strategy_trail_enabled": "true",
    "strategy_trail_trigger_r": "1.0",
    "strategy_rollover_start_hhmm": "2355",
    "strategy_rollover_end_hhmm": "5",
    "strategy_spread_filter_mult": "1.8",
    "strategy_max_slippage_ticks": "3",
    "strategy_daily_loss_limit_pct": "2.0",
    "strategy_daily_drawdown_hard_stop_pct": "2.5",
    "strategy_total_drawdown_stop_pct": "5.0",
    "strategy_per_trade_risk_cap_pct": "0.5",
}


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _executable_source() -> str:
    source = re.sub(r"/\*.*?\*/", "", _source(), flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", source)


def _compact(value: str) -> str:
    return "".join(value.split())


def _function_slice(source: str, start: str, end: str) -> str:
    return source[source.index(start) : source.index(end)]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_every_declared_input_has_an_executable_use_site() -> None:
    source = _executable_source()
    names = re.findall(r"(?m)^input\s+\S+\s+(\w+)\s*=", source)

    assert names
    assert len(names) == len(set(names))
    assert [name for name in names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2] == []


def test_state_refresh_precedes_entry_admission_and_management_is_reachable() -> None:
    compact = _compact(_executable_source())
    on_init = _function_slice(compact, "intOnInit()", "voidOnDeinit")
    on_tick = _function_slice(compact, "voidOnTick()", "voidOnTimer")

    assert "AdvanceState_OnNewBar();" in on_init
    assert "constboolstrategy_new_bar=QM_IsNewBar(_Symbol,strategy_signal_tf);" in on_tick
    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_NoTradeFilter())return;"
    )
    assert on_tick.index("if(Strategy_ExitSignal())") < on_tick.index(
        "if(Strategy_NoTradeFilter())return;"
    )
    assert "if(!g_strategy_state_ready)returntrue;" in compact
    assert "ask<=bid||g_strategy_cached_atr<=0.0" in compact


def test_card_loss_risk_and_execution_caps_are_framework_wired() -> None:
    source = _executable_source()
    compact = _compact(source)
    on_init = _function_slice(compact, "intOnInit()", "voidOnDeinit")

    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_drawdown_hard_stop_pct,"
        "strategy_total_drawdown_stop_pct,"
        "strategy_per_trade_risk_cap_pct)"
    ) in on_init
    assert "RISK_PERCENT>0.0&&!QM_FrameworkSetRiskCapPct(strategy_per_trade_risk_cap_pct)" in on_init
    assert "QM_EntryConfigure(qm_ea_id,qm_news_mode_legacy,StrategyDeviationPoints()" in on_init
    assert "strategy_max_slippage_ticks*tick_size/point" in compact
    assert "QM_ChartUITodayPnL(0,closed_trades)" in compact
    assert "QM_EquityStreamRestoreBaseline(" in source
    assert "QM_EquityStreamPersistBaseline(" in source
    assert "drawdown_pct>=strategy_total_drawdown_stop_pct" in compact
    assert "returnStrategyTotalDrawdownHalt();" in compact


def test_exact_ema55_stop_and_original_r_survive_sl_moves() -> None:
    source = _executable_source()
    entry = _compact(_function_slice(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition"))
    manage = _compact(_function_slice(source, "void Strategy_ManageOpenPosition", "bool Strategy_ExitSignal"))

    assert "g_strategy_cached_slow_ema-buffer" in entry
    assert "g_strategy_cached_slow_ema+buffer" in entry
    assert "if(sl<=0.0||(side==QM_BUY&&sl>=entry)||(side==QM_SELL&&sl<=entry))returnfalse;" in entry
    assert "ATR" not in entry.upper()
    assert "(current_tp-open_price)/strategy_tp_rr" in manage
    assert "(open_price-current_tp)/strategy_tp_rr" in manage
    assert "MathAbs(open_price-current_sl)" not in manage
    assert "req.symbol_slot=0;" in entry


def test_setfiles_seal_card_defaults_and_fixed_backtest_risk() -> None:
    paths = sorted(SETS.glob("*_backtest.set"))
    assert len(paths) == 3

    observed: dict[str, int] = {}
    for path in paths:
        match = re.search(rf"{re.escape(LABEL)}_(.+)_M5_backtest\.set$", path.name)
        assert match, path
        symbol = match.group(1)
        values = _set_values(path)
        observed[symbol] = int(values["qm_magic_slot_offset"])
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        for name, expected in EXPECTED_STRATEGY_DEFAULTS.items():
            assert values[name] == expected, (path, name)

    assert observed == EXPECTED_SLOTS


def test_registry_magic_and_hardening_remain_clean() -> None:
    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "38004"]

    assert len(rows) == 3
    assert {row["status"] for row in rows} == {"active"}
    assert {row["symbol"] for row in rows} == set(EXPECTED_SLOTS)
    assert {int(row["symbol_slot"]) for row in rows} == set(EXPECTED_SLOTS.values())
    assert {int(row["magic"]) for row in rows} == {380040000, 380040001, 380040002}
    assert all(str(magic) in MAGIC_RESOLVER.read_text(encoding="utf-8") for magic in (380040000, 380040001, 380040002))

    result = hardening.analyze(REPO, LABEL)
    assert result["failures"] == []
    assert result["rows"][0]["failures"] == []
