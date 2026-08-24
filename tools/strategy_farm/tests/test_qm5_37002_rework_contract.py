from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_37002_dual-thrust-asymmetric-range-breakout"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"
MAGIC_RESOLVER = REPO / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"

EXPECTED_SLOTS = {"SP500.DWX": 0, "NDX.DWX": 1, "XTIUSD.DWX": 2}
EXPECTED_STRATEGY_DEFAULTS = {
    "strategy_lookback_days": "4",
    "strategy_k1": "0.50",
    "strategy_k2": "0.50",
    "strategy_daily_loss_limit_pct": "2.0",
    "strategy_daily_drawdown_hard_stop_pct": "2.5",
    "strategy_total_drawdown_stop_pct": "5.0",
    "strategy_max_slippage_ticks": "3",
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


def test_range_uses_current_open_and_strictly_prior_closed_days() -> None:
    source = _executable_source()
    compact = _compact(source)
    calculation = _compact(
        _function_slice(source, "DualThrust_Levels CalculateDualThrust", "datetime Strategy_UTCNow")
    )

    assert "CopyRates(sym,PERIOD_D1,0,required,rates)" in calculation
    assert "copied!=required||ArraySize(rates)<required" in calculation
    assert "for(inti=1;i<=lookback;++i)" in calculation
    assert "constdoubleref_open=rates[0].open" in calculation
    assert "rates[0].high" not in calculation
    assert "rates[0].low" not in calculation
    assert "rates[0].close" not in calculation
    assert "iOpen(" not in compact
    assert "iHigh(" not in compact
    assert "iLow(" not in compact
    assert "iClose(" not in compact
    assert "perf-allowed:" in _source()


def test_entry_is_paired_pending_bracket_with_card_risk_geometry() -> None:
    source = _executable_source()
    compact = _compact(source)
    entry = _compact(
        _function_slice(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")
    )

    assert "buy_req.type=QM_BUY_STOP" in entry
    assert "req.type=QM_SELL_STOP" in entry
    assert "buy_req.price=buy_price" in entry
    assert "req.price=sell_price" in entry
    assert "buy_sl=QM_TM_NormalizePrice(_Symbol,sell_price)" in entry
    assert "sell_sl=QM_TM_NormalizePrice(_Symbol,buy_price)" in entry
    assert "STRATEGY_TARGET_R_MULT*buy_risk" in entry
    assert "STRATEGY_TARGET_R_MULT*sell_risk" in entry
    assert "QM_TM_OpenPosition(buy_req,g_strategy_first_pending_ticket)" in entry
    assert 'QM_TM_RemovePendingOrder(g_strategy_first_pending_ticket,"paired_submit_rollback")' in compact
    assert "QM_StopATR" not in source
    assert "strategy_max_hold_bars" not in source


def test_management_and_settlement_exit_cannot_be_gated_by_entry_filters() -> None:
    source = _executable_source()
    compact = _compact(source)
    manage = _compact(
        _function_slice(source, "void Strategy_ManageOpenPosition", "bool Strategy_ExitSignal")
    )
    exit_signal = _compact(
        _function_slice(source, "bool Strategy_ExitSignal", "bool Strategy_NewsFilterHook")
    )
    on_tick = _compact(_function_slice(source, "void OnTick", "void OnTimer"))

    assert 'Strategy_CancelPendingStops("daily_settlement")' in manage
    assert 'Strategy_CancelPendingStops("oco_peer_cancel")' in manage
    assert "Strategy_HasOpenPosition()&&Strategy_IsSettlementWindow()" in exit_signal
    assert "QM_BrokerToUTC(TimeCurrent())" in compact
    assert "QM_UTCToBroker(StructToTime(utc_day))" in compact
    assert "TimeGMT()" not in compact
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )


def test_card_loss_limits_and_framework_contract_are_wired() -> None:
    source = _executable_source()
    compact = _compact(source)
    on_init = _function_slice(compact, "intOnInit()", "voidOnDeinit")

    assert "Strategy_DailyRealizedNet()" in source
    assert "DEAL_PROFIT" in source
    assert "DEAL_SWAP" in source
    assert "DEAL_COMMISSION" in source
    assert "DEAL_FEE" in source
    assert "strategy_daily_loss_limit_pct" in compact
    assert "strategy_daily_loss_limit_pct>2.0" in on_init
    assert "strategy_daily_drawdown_hard_stop_pct>2.5" in on_init
    assert "strategy_total_drawdown_stop_pct>5.0" in on_init
    assert "strategy_max_slippage_ticks*tick_size/point" in compact
    assert "QM_EntryConfigure(qm_ea_id" in on_init
    assert (
        "QM_KillSwitchInit(qm_ea_id,QM_FrameworkMagic(),"
        "strategy_daily_drawdown_hard_stop_pct,"
        "strategy_total_drawdown_stop_pct,1.0)"
    ) in on_init
    assert "QM_FrameworkInit(" in on_init
    assert "QM_FrameworkTrackOpenPositionMae();" in compact
    assert "QM_Magic(" not in source
    assert "370020000" not in source


def test_setfiles_seal_card_defaults_slots_and_fixed_backtest_risk() -> None:
    paths = sorted(SETS.glob("*_backtest.set"))
    assert len(paths) == 3

    observed: dict[str, int] = {}
    for path in paths:
        match = re.search(rf"{re.escape(LABEL)}_(.+)_D1_backtest\.set$", path.name)
        assert match, path
        values = _set_values(path)
        observed[match.group(1)] = int(values["qm_magic_slot_offset"])
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert "; build_hash:   pending" in path.read_text(encoding="utf-8-sig")
        for name, expected in EXPECTED_STRATEGY_DEFAULTS.items():
            assert values[name] == expected, (path, name)
        assert set(values).isdisjoint(
            {
                "strategy_atr_period",
                "strategy_sl_atr_mult",
                "strategy_max_hold_bars",
                "strategy_spread_atr_mult",
                "strategy_max_spread_points",
            }
        )

    assert observed == EXPECTED_SLOTS


def test_registry_magic_and_hardening_remain_clean() -> None:
    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "37002"]

    assert len(rows) == 3
    assert {row["status"] for row in rows} == {"active"}
    assert {row["symbol"] for row in rows} == set(EXPECTED_SLOTS)
    assert {int(row["symbol_slot"]) for row in rows} == set(EXPECTED_SLOTS.values())
    assert {int(row["magic"]) for row in rows} == {370020000, 370020001, 370020002}
    resolver = MAGIC_RESOLVER.read_text(encoding="utf-8")
    assert all(str(magic) in resolver for magic in (370020000, 370020001, 370020002))

    result = hardening.analyze(REPO, LABEL)
    assert result["failures"] == []
    assert result["rows"][0]["failures"] == []
