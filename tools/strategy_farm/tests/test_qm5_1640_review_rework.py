from __future__ import annotations

import json
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_1640_aa-indmom-12-0"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
SETS = EA_DIR / "sets"
MANIFEST = EA_DIR / "basket_manifest.json"

EXPECTED_SLOTS = {
    "GDAXI.DWX": 0,
    "NDX.DWX": 1,
    "SP500.DWX": 2,
    "UK100.DWX": 3,
    "WS30.DWX": 4,
}
EXPECTED_STRATEGY_DEFAULTS = {
    "strategy_min_monthly_bars": "14",
    "strategy_top_slots": "5",
    "strategy_atr_period_d1": "20",
    "strategy_sl_atr_mult": "3.0",
    "strategy_spread_median_days": "20",
    "strategy_spread_median_mult": "2.5",
}


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _executable_source() -> str:
    source = re.sub(r"/\*.*?\*/", "", _source(), flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", source)


def _compact(value: str) -> str:
    return "".join(value.split())


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if line and not line.startswith(";") and "=" in line:
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


def test_cross_sectional_completed_month_snapshot_is_card_faithful() -> None:
    source = _source()
    compact = _compact(_executable_source())

    assert "CopyClose(symbol, PERIOD_MN1, 1, required, closes)" in source
    assert "constintlatest_index=copied-1;" in compact
    assert "constintpast_index=copied-13;" in compact
    assert "out_score=close_1/close_13-1.0;" in compact
    assert "copied!=required||ArraySize(closes)<required" in compact
    assert "g_snapshot_scores[right]>g_snapshot_scores[left]" in compact
    assert "g_snapshot_scores[symbol_index]>0.0" in compact
    assert "rank<selected_limit" in compact
    assert "PERIOD_D1, 252" not in source
    assert "iClose(" not in source
    assert "Bars(" not in source


def test_monthly_admission_is_restart_safe_and_portfolio_capped() -> None:
    compact = _compact(_executable_source())

    assert "Strategy_FirstD1BarOfMonth()" in compact
    assert "month_key==g_last_entry_rebalance_key" in compact
    assert "Strategy_HadEntryThisMonth()" in compact
    assert "HistoryDealGetInteger(deal,DEAL_MAGIC)" in compact
    assert "entry==DEAL_ENTRY_IN||entry==DEAL_ENTRY_INOUT" in compact
    assert "Strategy_OpenPortfolioPositions()>=strategy_top_slots" in compact
    assert "position_magic==QM_Magic(qm_ea_id,g_universe_slots[slot_index])" in compact
    assert "QM_MagicChecked(qm_ea_id,symbol_slot,_Symbol)" in compact


def test_spread_rule_is_exact_bounded_and_fail_closed() -> None:
    source = _source()
    compact = _compact(_executable_source())

    assert "CopyRates(_Symbol, PERIOD_D1, 1, required, rates)" in source
    assert "copied!=required||ArraySize(rates)<required" in compact
    assert "rates[i].spread<=0" in compact
    assert "median<=0.0" in compact
    assert "current_spread_points<=strategy_spread_median_mult*median" in compact
    assert source.count("perf-allowed:") >= 3


def test_news_blocks_entries_only_and_framework_chain_is_preserved() -> None:
    source = _executable_source()
    compact = _compact(source)
    on_tick = compact[compact.index("voidOnTick()") : compact.index("voidOnTimer()")]

    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_ExitSignal())"
    )
    assert on_tick.index("if(Strategy_ExitSignal())") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert on_tick.index("QM_NewsAllowsTrade2") < on_tick.index("if(!QM_IsNewBar())")
    assert "QM_FrameworkInit(qm_ea_id" in compact
    assert "RISK_PERCENT" in source and "RISK_FIXED" in source
    assert "inputboolqm_friday_close_enabled=false;" in compact


def test_manifest_and_setfiles_bind_only_available_card_proxies() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert manifest["basket_symbols"] == list(EXPECTED_SLOTS)
    assert manifest["symbol_slots"] == EXPECTED_SLOTS
    assert manifest["card_candidates_unavailable_in_active_matrix"] == [
        "FCHI.DWX",
        "SPA35.DWX",
        "NETH25.DWX",
        "STOXX50E.DWX",
    ]

    observed: dict[str, int] = {}
    paths = sorted(SETS.glob("*_backtest.set"))
    assert len(paths) == 5
    for path in paths:
        match = re.search(rf"{re.escape(LABEL)}_(.+)_D1_backtest\.set$", path.name)
        assert match, path
        values = _set_values(path)
        observed[match.group(1)] = int(values["qm_magic_slot_offset"])
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        for name, expected in EXPECTED_STRATEGY_DEFAULTS.items():
            assert values[name] == expected, (path, name)
    assert observed == EXPECTED_SLOTS


def test_scoped_build_gate_hardening_is_clean() -> None:
    result = hardening.analyze(REPO, LABEL)
    assert result["failures"] == []
    assert result["rows"][0]["failures"] == []
