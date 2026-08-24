from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_1407_classical-symmetric-triangle-breakout-h4"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
CARD = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_1407_classical-symmetric-triangle-breakout-h4.md"
)
APPROVED_SYMBOLS = {
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "XAUUSD.DWX",
    "NDX.DWX",
    "WS30.DWX",
    "GDAXI.DWX",
    "UK100.DWX",
    "XTIUSD.DWX",
}


def source_text() -> str:
    return EA_SOURCE.read_text(encoding="utf-8")


def test_qm5_1407_passes_source_build_hardening() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_pending_oco_apex_and_spread_match_card() -> None:
    source = source_text()
    assert "buy_request.type = QM_BUY_STOP;" in source
    assert "sell_request.type = QM_SELL_STOP;" in source
    assert "oco_opposite_after_first_fill" in source
    assert "strategy_pending_lifetime_bars          = 12" in source
    assert "twelve_h4_bar_expiry" in source
    assert "if(apex_shift >= 0.0" in source
    assert "apex_at_or_behind_current_bar" in source
    assert "ask - bid <= strategy_spread_max_atr * atr" in source
    assert "strategy_spread_max_atr                 = 0.25" in source
    assert "QM_NewsInWindow(utc, _Symbol, 480, 480" in source
    assert "req.type = QM_BUY;" not in source
    assert "req.type = QM_SELL;" not in source


def test_reuse_and_management_state_are_durable_and_checked() -> None:
    source = source_text()
    assert "Strategy_Overlap(pat, g_reuse_pivots, g_reuse_count)" in source
    assert "> strategy_reuse_overlap_ratio" in source
    assert "Strategy_RecordReuse(TimeCurrent())" in source
    assert "GlobalVariableSet(" in source
    assert "GlobalVariableGet(" in source
    assert "GlobalVariablesFlush();" in source
    assert "g_restart_state_missing" in source
    assert "fail_closed_exit" in source
    assert "if(lots > 0.0 && lots < volume && QM_TM_PartialClose(" in source
    assert "if(!g_tp1_break_even_done && PositionSelectByTicket(ticket) &&" in source
    assert "QM_TM_MoveSL(ticket, Strategy_NormalizePrice(open)" in source
    assert "g_tp1_partial_done = true" in source
    assert "g_tp1_break_even_done = true" in source
    assert "Strategy_ProjectedLine(true, closed[0].time)" in source
    assert "Strategy_ProjectedLine(false, closed[0].time)" in source


def test_series_reads_are_bounded_or_explicitly_perf_allowed() -> None:
    source = source_text()
    assert "CopyRates(_Symbol, strategy_tf, 0, requested, rates); // perf-allowed:" in source
    assert "const int size = ArraySize(rates);" in source
    assert "copied < 1 || ArraySize(closed) < 1" in source
    raw_calls = re.findall(r"^.*\b(?:iOpen|iHigh|iLow|iClose|iTime|iBarShift)\s*\(.*$", source, re.MULTILINE)
    assert raw_calls
    assert all("perf-allowed:" in line for line in raw_calls)


def test_every_declared_strategy_input_has_an_executable_use_site() -> None:
    source = source_text()
    strategy_group = source.split('input group "Strategy"', 1)[1].split(
        "const int ST_MAX_SIDE_PIVOTS", 1
    )[0]
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        strategy_group,
        flags=re.MULTILINE,
    )
    assert names
    assert [name for name in names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2] == []


def test_setfiles_are_exact_approved_universe_and_fixed_risk() -> None:
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    symbols = {path.name.removeprefix(f"{EA_LABEL}_").removesuffix("_H4_backtest.set") for path in setfiles}
    assert symbols == APPROVED_SYMBOLS
    for path in setfiles:
        text = path.read_text(encoding="utf-8-sig")
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert "strategy_pending_lifetime_bars=12" in text
        assert "strategy_reuse_overlap_ratio=0.50" in text
        assert "strategy_spread_max_atr=0.25" in text
        assert "strategy_spread_lookback_bars" not in text
        assert "strategy_spread_average_multiplier" not in text


def test_missing_xtiusd_magic_was_added_without_reallocating_existing_rows() -> None:
    registry = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    with registry.open(encoding="utf-8-sig", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "1407"]
    by_slot = {int(row["symbol_slot"]): row for row in rows}
    assert sorted(by_slot) == list(range(14))
    assert by_slot[13]["symbol"] == "XTIUSD.DWX"
    assert by_slot[13]["magic"] == "14070013"
    assert all(by_slot[slot]["magic"] == str(14070000 + slot) for slot in range(13))
