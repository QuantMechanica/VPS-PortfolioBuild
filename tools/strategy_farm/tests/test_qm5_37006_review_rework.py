from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_37006_cusum-filter-structural-breakout"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"
MAGIC_RESOLVER = REPO / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"

EXPECTED_SLOTS = {"NDX.DWX": 0, "SP500.DWX": 1, "XTIUSD.DWX": 2}
EXPECTED_STRATEGY_DEFAULTS = {
    "strategy_vol_window": "50",
    "strategy_threshold_h": "1.50",
    "strategy_atr_period": "14",
    "strategy_sl_atr_mult": "1.50",
    "strategy_tp_rr": "2.00",
    "strategy_spread_atr_mult": "1.80",
    "strategy_max_slippage_ticks": "3",
    "strategy_daily_loss_limit_pct": "2.0",
    "strategy_daily_drawdown_hard_stop_pct": "2.5",
    "strategy_total_drawdown_stop_pct": "5.0",
    "strategy_per_trade_risk_cap_pct": "1.0",
    "strategy_state_rebuild_bars": "512",
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
    assert [
        name
        for name in names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ] == []


def test_cusum_uses_expected_return_and_resets_only_after_confirmed_entry() -> None:
    source = _executable_source()
    compact = _compact(source)
    apply_bar = _compact(
        _function_slice(source, "bool StrategyApplyClosedBar", "string StrategyStateKey")
    )
    entry = _compact(
        _function_slice(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")
    )
    on_tick = _compact(_function_slice(source, "void OnTick", "void OnTimer"))

    assert "mean_return=sum/(double)lookback;" in compact
    assert "centered_return=(rates[0].close-rates[1].close)-mean_return" in apply_bar
    assert "g_cusum_pos=MathMax(0.0,g_cusum_pos+centered_return)" in apply_bar
    assert "g_cusum_neg=MathMin(0.0,g_cusum_neg+centered_return)" in apply_bar
    assert "g_cusum_pos=0.0" not in entry
    assert "g_cusum_neg=0.0" not in entry
    accepted = "if(QM_TM_OpenPosition(req,out_ticket)){"
    assert accepted in on_tick
    accepted_body = on_tick[on_tick.index(accepted) :]
    assert "g_cusum_pos=0.0;" in accepted_body
    assert "g_cusum_neg=0.0;" in accepted_body


def test_restart_replay_is_durable_bounded_and_fail_closed() -> None:
    source = _source()
    compact = _compact(_executable_source())

    assert "StrategyPersistState" in source
    assert "StrategyRestoreState" in source
    assert "StrategyLastConfirmedEntryTime" in source
    assert "HistoryDealGetInteger(deal, DEAL_MAGIC)" in source
    assert "entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT" in source
    assert "oldest_shift>strategy_state_rebuild_bars" in compact
    assert "if(!StrategyApplyClosedBar(shift))returnfalse;" in compact
    assert "copied!=required||ArraySize(rates)<required" in compact
    assert "copied!=2||ArraySize(rates)<2" in compact
    assert source.count("perf-allowed:") >= 5
    assert "!StrategyRebuildState()" in compact
    on_init = _function_slice(compact, "intOnInit()", "voidOnDeinit")
    assert on_init.index("StrategyRebuildState()") < on_init.index(
        "QM_IsNewBar(_Symbol,PERIOD_M15);"
    )


def test_loss_slippage_magic_and_entry_filters_are_framework_wired() -> None:
    source = _executable_source()
    compact = _compact(source)
    on_init = _function_slice(compact, "intOnInit()", "voidOnDeinit")

    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_drawdown_hard_stop_pct,"
        "strategy_total_drawdown_stop_pct,"
        "strategy_per_trade_risk_cap_pct)"
    ) in on_init
    assert "QM_EntryConfigure(qm_ea_id,qm_news_mode_legacy,StrategyDeviationPoints()" in on_init
    assert "strategy_max_slippage_ticks*tick_size/point" in compact
    assert "QM_ChartUITodayPnL(0,closed_trades)" in compact
    assert "QM_EquityStreamRestoreBaseline(" in source
    assert "QM_EquityStreamPersistBaseline(" in source
    assert "returnStrategyTotalDrawdownHalt();" in compact
    assert "strategy_max_spread_points" not in source
    assert "strategy_spread_atr_mult*g_cached_atr1" in compact
    assert "req.symbol_slot=0;" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in compact


def test_setfiles_seal_card_defaults_and_fixed_backtest_risk() -> None:
    paths = sorted(SETS.glob("*_backtest.set"))
    assert len(paths) == 3

    observed: dict[str, int] = {}
    for path in paths:
        match = re.search(rf"{re.escape(LABEL)}_(.+)_M15_backtest\.set$", path.name)
        assert match, path
        values = _set_values(path)
        observed[match.group(1)] = int(values["qm_magic_slot_offset"])
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        for name, expected in EXPECTED_STRATEGY_DEFAULTS.items():
            assert values[name] == expected, (path, name)

    assert observed == EXPECTED_SLOTS


def test_registry_magic_and_hardening_remain_clean() -> None:
    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "37006"]

    assert len(rows) == 3
    assert {row["status"] for row in rows} == {"active"}
    assert {row["symbol"] for row in rows} == set(EXPECTED_SLOTS)
    assert {int(row["symbol_slot"]) for row in rows} == set(EXPECTED_SLOTS.values())
    assert {int(row["magic"]) for row in rows} == {370060000, 370060001, 370060002}
    resolver = MAGIC_RESOLVER.read_text(encoding="utf-8")
    assert all(str(magic) in resolver for magic in (370060000, 370060001, 370060002))

    result = hardening.analyze(REPO, LABEL)
    assert result["failures"] == []
    assert result["rows"][0]["failures"] == []
