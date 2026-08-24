from __future__ import annotations

import csv
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_38003_codetrading-bollinger-engulfing-reversal"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"

SYMBOL_SLOTS = {
    "EURUSD.DWX": (0, 380030000),
    "GBPJPY.DWX": (1, 380030001),
    "AUDUSD.DWX": (2, 380030002),
}


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def test_framework_corset_and_closed_bar_inputs_are_used() -> None:
    source = _source()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkInit(" in source
    assert "QM_NewsAllowsTrade2(" in source
    assert "QM_ReadBar(_Symbol, PERIOD_H1, 1" in source
    assert "QM_ReadBar(_Symbol, PERIOD_H1, 2" in source
    assert "CopyBuffer(" not in source
    assert "CopyRates(" not in source
    assert not re.search(r"\bi(?:ATR|Bands|RSI)\s*\(", source)

    strategy_inputs = (
        "InpBBPeriod",
        "InpBBDev",
        "InpRSIPeriod",
        "InpDailyLossHaltPct",
        "InpDailyDrawdownStopPct",
        "InpTotalDrawdownStopPct",
    )
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name


def test_card_entry_exit_and_risk_rules_are_wired() -> None:
    source = _source()

    required_fragments = (
        "g_cached_bar_1.close > g_cached_bar_2.open",
        "g_cached_bar_1.open < g_cached_bar_2.close",
        "g_cached_bar_2.close < g_cached_bar_2.open",
        "g_cached_bar_1.close < g_cached_bar_2.open",
        "g_cached_bar_1.open > g_cached_bar_2.close",
        "g_cached_bar_2.close > g_cached_bar_2.open",
        "g_cached_bar_1.low <= g_cached_lower_band",
        "g_cached_bar_1.high >= g_cached_upper_band",
        "g_cached_rsi <= CARD_LONG_RSI_MAX",
        "g_cached_rsi >= CARD_SHORT_RSI_MIN",
        "QM_StopRulesPipsToPriceDistance(_Symbol, CARD_SL_BUFFER_PIPS)",
        "QM_TakeRR(_Symbol, req.type, req.price, req.sl",
        "QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL)",
        "QM_BrokerToUTC(TimeCurrent())",
        "CARD_MAX_SLIPPAGE_TICKS * tick_size",
        "QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= CARD_MAX_OPEN_POSITIONS",
    )
    for fragment in required_fragments:
        assert fragment in source, fragment

    no_trade = source.split("bool Strategy_NoTradeFilter()", 1)[1].split(
        "bool Strategy_EntrySignal", 1
    )[0]
    assert "return false;" in no_trade
    assert "QM_TM_OpenPositionCount" not in no_trade


def test_registry_setfiles_and_resolver_use_deterministic_slots() -> None:
    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8", newline=""
    ) as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "38003" and row["status"] == "active"
        ]

    assert len(rows) == len(SYMBOL_SLOTS)
    observed = {
        row["symbol"]: (int(row["symbol_slot"]), int(row["magic"])) for row in rows
    }
    assert observed == SYMBOL_SLOTS

    expected_strategy_values = {
        "InpBBPeriod": "20",
        "InpBBDev": "2.0",
        "InpRSIPeriod": "14",
        "InpDailyLossHaltPct": "2.0",
        "InpDailyDrawdownStopPct": "2.5",
        "InpTotalDrawdownStopPct": "5.0",
    }
    for symbol, (slot, _magic) in SYMBOL_SLOTS.items():
        setfile = SETS_DIR / f"{EA_LABEL}_{symbol}_H1_backtest.set"
        assert setfile.is_file()
        text = setfile.read_text(encoding="utf-8")
        values = _set_values(setfile)
        assert f"; symbol:       {symbol}" in text
        assert "; timeframe:    H1" in text
        assert "; environment:  backtest" in text
        assert values["qm_ea_id"] == "38003"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["PORTFOLIO_WEIGHT"] == "1"
        for key, value in expected_strategy_values.items():
            assert values[key] == value

    resolver = (
        REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    ).read_text(encoding="utf-8")
    for _slot, magic in SYMBOL_SLOTS.values():
        assert str(magic) in resolver


def test_strategy_card_mirror_matches_card_of_record() -> None:
    card = (
        REPO_ROOT
        / "strategy-seeds"
        / "cards"
        / "QM5_38003_codetrading-bollinger-engulfing-reversal.md"
    ).read_text(encoding="utf-8")
    mirror = (EA_DIR / "docs" / "strategy_card.md").read_text(encoding="utf-8")

    assert mirror.rstrip() == card.rstrip()
    assert "g0_status: APPROVED" in mirror
