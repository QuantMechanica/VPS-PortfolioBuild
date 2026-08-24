from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_39001_forexfactory-trading-made-simple-tms"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SETS = EA_DIR / "sets"
CARD = (
    ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_39001_forexfactory-trading-made-simple-tms.md"
)
EA_IDS = ROOT / "framework" / "registry" / "ea_id_registry.csv"
MAGICS = ROOT / "framework" / "registry" / "magic_numbers.csv"
RESOLVER = ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"

EXPECTED_SLOTS = {
    0: ("EURUSD.DWX", 390010000),
    1: ("GBPUSD.DWX", 390010001),
    2: ("AUDUSD.DWX", 390010002),
}


def _csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8-sig")


def test_approved_card_and_deterministic_registries_match() -> None:
    card = CARD.read_text(encoding="utf-8-sig")
    assert re.search(r"(?m)^ea_id:\s*QM5_39001\s*$", card)
    assert re.search(r"(?m)^slug:\s*forexfactory-trading-made-simple-tms\s*$", card)
    assert re.search(r"(?m)^g0_status:\s*APPROVED\s*$", card)
    assert "target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX]" in card
    assert "timeframe: H1" in card

    ea_rows = [row for row in _csv_rows(EA_IDS) if row["ea_id"] == "39001"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "forexfactory-trading-made-simple-tms"

    magic_rows = [
        row
        for row in _csv_rows(MAGICS)
        if row["ea_id"] == "39001" and row["status"].lower() == "active"
    ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in magic_rows
    }
    assert actual == EXPECTED_SLOTS
    resolver = RESOLVER.read_text(encoding="utf-8-sig")
    for _slot, (_symbol, magic) in EXPECTED_SLOTS.items():
        assert str(magic) in resolver


def test_framework_risk_magic_and_mae_chain_is_preserved() -> None:
    source = _source()
    assert "#include <QM/QM_Common.mqh>" in source
    assert "input double RISK_PERCENT               = 0.0;" in source
    assert "input double RISK_FIXED                 = 1000.0;" in source
    assert "QM_FrameworkInit(" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkOnTradeTransaction(" in source
    assert "qm_ea_id * 10000" not in source
    assert not re.search(r"(?i)tensorflow|torch|sklearn|keras|onnx", source)


def test_restart_state_h1_cadence_utc_and_three_tick_deviation_are_wired() -> None:
    source = _source()
    assert "const ENUM_TIMEFRAMES STRATEGY_SIGNAL_TF = PERIOD_H1;" in source
    assert "QM_IsNewBar(_Symbol, STRATEGY_SIGNAL_TF)" in source
    assert "QM_IsNewBar()" not in source
    assert "QM_BrokerToUTC(TimeCurrent())" in source
    assert "STRATEGY_MAX_SLIPPAGE_TICKS = 3" in source
    assert "SYMBOL_TRADE_TICK_SIZE" in source
    assert "QM_EntryConfigure(qm_ea_id," in source

    on_init = source[source.index("int OnInit()") : source.index("void OnDeinit")]
    assert "Strategy_RefreshH1State();" in on_init

    on_tick = source[source.index("void OnTick()") : source.index("void OnTimer()")]
    assert on_tick.index("Strategy_RefreshH1State();") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )


def test_exact_three_bar_swing_stop_and_true_tdi_crossback() -> None:
    source = _source()
    assert "STRATEGY_SWING_BARS         = 3" in source
    assert "CopyRates(_Symbol, STRATEGY_SIGNAL_TF, 1, STRATEGY_SWING_BARS, rates)" in source
    assert "ArraySize(rates) < STRATEGY_SWING_BARS" in source
    assert "i < STRATEGY_SWING_BARS && i < ArraySize(rates)" in source
    assert "QM_StopRulesPipsToPriceDistance(_Symbol, STRATEGY_SL_BUFFER_PIPS)" in source
    assert "g_swing_low - buffer" in source
    assert "g_swing_high + buffer" in source
    assert "0.5 * g_last_atr" not in source
    assert "SYMBOL_POINT) * 10" not in source
    assert "g_tdi_fast_prev >= g_tdi_slow_prev && g_tdi_fast < g_tdi_slow" in source
    assert "g_tdi_fast_prev <= g_tdi_slow_prev && g_tdi_fast > g_tdi_slow" in source
    assert "BE_LOCK" not in source
    assert "strategy_be_" not in source


def test_every_strategy_input_has_a_use_site_and_sets_are_fixed_risk() -> None:
    source = _source()
    source_bytes = SOURCE.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    source_hash = hashlib.sha256(source_bytes).hexdigest()
    strategy_block = source[
        source.index('input group "Strategy"') : source.index(
            "const ENUM_TIMEFRAMES STRATEGY_SIGNAL_TF"
        )
    ]
    strategy_inputs = re.findall(
        r"(?m)^input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", strategy_block
    )
    assert strategy_inputs
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    setfiles = sorted(SETS.glob("*.set"))
    assert len(setfiles) == len(EXPECTED_SLOTS)
    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        path = SETS / f"{EA_LABEL}_{symbol}_H1_backtest.set"
        assert path in setfiles
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "39001"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        for name in strategy_inputs:
            assert name in values
        for removed in (
            "strategy_signal_tf",
            "strategy_swing_lookback",
            "strategy_be_enabled",
            "strategy_be_trigger_r",
        ):
            assert removed not in values
