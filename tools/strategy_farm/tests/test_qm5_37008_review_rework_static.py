from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_37008_garch-volatility-forecast-breakout"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
CARD = (
    REPO
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_37008_garch-volatility-forecast-breakout.md"
)
SETS = EA_DIR / "sets"
CARD_MIRROR = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("SP500.DWX", 370080000),
    1: ("NDX.DWX", 370080001),
    2: ("XAUUSD.DWX", 370080002),
}


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


def test_approved_card_identity_and_reviewed_mechanism() -> None:
    card = CARD.read_text(encoding="utf-8")

    assert "ea_id: QM5_37008" in card
    assert "slug: garch-volatility-forecast-breakout" in card
    assert "g0_status: APPROVED" in card
    assert "Spread Filter" in card
    assert re.search(r"1\.8\s+\\times\s+\\text\{ATR\}\(14", card)
    assert "Trailing Stop" in card
    assert "Ratchet with 1-sigma GARCH cone" in card
    mirror = CARD_MIRROR.read_text(encoding="utf-8")
    assert [line.rstrip() for line in mirror.splitlines()] == [
        line.rstrip() for line in card.splitlines()
    ]


def test_review_findings_are_fixed_without_card_drift() -> None:
    source = _source()
    compact = _compact(source)
    manager = _function(source, "void Strategy_ManageOpenPosition", "bool Strategy_ExitSignal")
    on_tick = _function(source, "void OnTick", "void OnTimer")
    entry = _function(source, "bool Strategy_EntrySignal", "void Strategy_ManageOpenPosition")

    assert "strategy_max_spread_points" not in source
    assert compact.count("Strategy_SpreadAllowsEntry(ask,bid)") == 2
    assert "strategy_spread_atr_mult*g_cached_atr1" in compact
    assert entry.index("Strategy_SpreadAllowsEntry(ask, bid)") < entry.index(
        "const double cone_distance"
    )
    assert on_tick.index("AdvanceState_OnNewBar();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert on_tick.index("Strategy_NoTradeFilter()") < on_tick.index(
        "Strategy_EntrySignal(req)"
    )

    manager_compact = _compact(manager)
    assert "PositionGetString(POSITION_SYMBOL)!=_Symbol" in manager_compact
    assert "PositionGetInteger(POSITION_MAGIC)!=magic" in manager_compact
    assert "g_cached_open1-g_cached_sigma_price" in manager_compact
    assert "g_cached_open1+g_cached_sigma_price" in manager_compact
    assert "constboolimproves=" in manager_compact
    assert "constboolcorrect_side=" in manager_compact
    assert 'QM_TM_MoveSL(ticket,target_sl,"garch_one_sigma_cone_ratchet")' in manager_compact


def test_raw_series_reads_are_bounded_guarded_and_perf_allowed() -> None:
    source = _source()
    compact = _compact(source)
    raw_series = re.compile(
        r"\b(?:CopyRates|CopyClose|CopyOpen|CopyHigh|CopyLow|CopyTime|"
        r"iBars|iBarShift|iOpen|iHigh|iLow|iClose|iTime)\s*\("
    )

    matching_lines = [line for line in source.splitlines() if raw_series.search(line)]
    assert len(matching_lines) == 2
    for line in matching_lines:
        assert "perf-allowed" in line, line

    assert "constintclose_count=ArraySize(closes);" in compact
    assert "close_count<total_bars" in compact
    assert "total_bars>100" in compact
    assert "ArraySize(rates)<copied_rates" in compact
    assert "copied>lookback||ArraySize(closes)<copied" in compact
    assert "ArrayResize(rets,ret_count)!=ret_count" in compact


def test_every_declared_input_has_a_non_declaration_use_site() -> None:
    source = _source()
    inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+([A-Za-z][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert inputs
    for input_name in inputs:
        assert len(re.findall(rf"\b{re.escape(input_name)}\b", source)) >= 2, input_name


def test_framework_magic_risk_mae_registry_and_sets_are_bound() -> None:
    source = _source()
    on_tick = _function(source, "void OnTick", "void OnTimer")
    on_init = _function(source, "int OnInit", "void OnDeinit")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkMagic()" in source
    assert "37008 * 10000" not in source
    assert "return qm_magic_slot_offset;" in source
    assert "return -1;" in source
    assert "if(Strategy_SymbolSlot() < 0)" in source
    assert "QM_FrameworkDeclareExecutionContract(" in on_init
    assert "PERIOD_D1" in on_init
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in on_init
    assert '"CARD_HAS_NO_FRIDAY_RULE_FRAMEWORK_SAFETY_OVERRIDE"' in on_init
    assert on_init.index("QM_FrameworkInit(") < on_init.index(
        "QM_FrameworkDeclareExecutionContract("
    )
    assert on_init.index("QM_FrameworkDeclareExecutionContract(") < on_init.index(
        "QM_EntryConfigure("
    )
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)

    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "37008" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in rows
    }
    assert actual == EXPECTED_SLOTS

    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    set_paths = sorted(SETS.glob(f"{LABEL}_*_D1_backtest.set"))
    assert len(set_paths) == len(EXPECTED_SLOTS)
    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        path = SETS / f"{LABEL}_{symbol}_D1_backtest.set"
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "37008"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        for input_name in re.findall(
            r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
            source,
            flags=re.MULTILINE,
        ):
            assert input_name in values, (path.name, input_name)
