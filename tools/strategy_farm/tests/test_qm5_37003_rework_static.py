from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_37003_hurst-exponent-dynamic-regime-switch"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
CARD_PATH = (
    ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / f"{EA_LABEL}.md"
)
LOCAL_CARD_PATH = EA_DIR / "docs" / "strategy_card.md"
SETS_DIR = EA_DIR / "sets"
EXPECTED_SLOTS = {
    "EURUSD.DWX": 0,
    "GBPJPY.DWX": 1,
    "SP500.DWX": 2,
}


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def _function(source: str, name: str) -> str:
    start = source.index(f"{name}(")
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"unterminated function: {name}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_card_registry_and_build_hardening_contracts_are_clean() -> None:
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    assert re.search(r"(?m)^ea_id:\s*QM5_37003\s*$", card)
    assert re.search(
        r"(?m)^slug:\s*hurst-exponent-dynamic-regime-switch\s*$", card
    )
    assert re.search(r"(?m)^g0_status:\s*APPROVED\s*$", card)
    local_card = LOCAL_CARD_PATH.read_text(encoding="utf-8-sig")
    approved_card = CARD_PATH.read_text(encoding="utf-8-sig")
    assert [line.rstrip() for line in local_card.splitlines()] == [
        line.rstrip() for line in approved_card.splitlines()
    ]

    with (ROOT / "framework" / "registry" / "ea_id_registry.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "37003"]
    assert len(rows) == 1
    assert rows[0]["slug"] == "hurst-exponent-dynamic-regime-switch"

    with (ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        magic_rows = {
            row["symbol"]: int(row["symbol_slot"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "37003" and row["status"] == "active"
        }
    assert magic_rows == EXPECTED_SLOTS

    resolver = (
        ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    ).read_text(encoding="utf-8-sig")
    for slot in EXPECTED_SLOTS.values():
        assert str(37003 * 10000 + slot) in resolver

    result = hardening.analyze_file(SOURCE_PATH, hardening.find_card(ROOT, EA_LABEL))
    assert result["failures"] == []
    assert result["warnings"] == []


def test_declared_card_parameter_ranges_fail_closed() -> None:
    source = hardening.strip_comments_preserve_lines(_source())
    config = _function(source, "Strategy_ConfigValid")

    assert "strategy_hurst_lookback < 50" in config
    assert "strategy_hurst_lookback > 200" in config
    assert "strategy_trend_hurst < 0.52" in config
    assert "strategy_trend_hurst > 0.65" in config
    assert "strategy_revert_hurst < 0.35" in config
    assert "strategy_revert_hurst > 0.48" in config
    assert "RISK_PERCENT > 0.0" in config
    assert "RISK_PERCENT < 0.20" in config
    assert "RISK_PERCENT > 1.00" in config


def test_review_loss_limits_are_distinct_and_wired() -> None:
    source = _source()
    no_trade = _function(source, "Strategy_NoTradeFilter")
    on_init = _function(source, "OnInit")

    assert "QM_ChartUITodayPnL(0, closed_trades)" in source
    assert "strategy_daily_loss_halt_pct / 100.0" in source
    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "QM_KillSwitchInit(qm_ea_id" in on_init
    kill_switch_tail = on_init.split("QM_KillSwitchInit(qm_ea_id", 1)[1]
    assert "strategy_daily_hard_stop_pct" in kill_switch_tail
    assert "strategy_total_dd_halt_pct" in kill_switch_tail
    assert "strategy_per_trade_risk_cap_pct" in kill_switch_tail


def test_mean_reversion_target_has_no_unauthorized_fixed_r_fallback() -> None:
    source = _source()
    entry = _function(source, "Strategy_EntrySignal")
    revert = entry.split("// 2. Mean-Reversion Mode", 1)[1]

    assert "if(g_cached_bb_middle <= ask)" in revert
    assert "if(g_cached_bb_middle <= 0.0 || g_cached_bb_middle >= bid)" in revert
    assert revert.count("req.tp = g_cached_bb_middle;") == 2
    assert "QM_TakeRR" not in revert


def test_position_management_precedes_every_entry_only_filter() -> None:
    source = _source()
    on_tick = _function(source, "OnTick")

    management = on_tick.index("Strategy_ManageOpenPosition();")
    assert management < on_tick.index("QM_NewsAllowsTrade2")
    assert management < on_tick.index("QM_IsNewBar(_Symbol, PERIOD_H1)")
    assert management < on_tick.index("Strategy_NoTradeFilter()")


def test_card_signal_mechanics_and_series_access_are_bounded() -> None:
    source = _source()
    hurst = _function(source, "CalculateHurst")
    refresh = _function(source, "AdvanceState_OnNewBar")

    assert "CopyRates(sym, tf, shift, lookback + 1, rates)" in hurst
    assert "ArraySize(rates) < lookback + 1" in hurst
    assert "ArraySize(rets) != lookback" in hurst
    assert "i + 1 >= ArraySize(rates)" in hurst
    assert "MathLog(rs) / MathLog((double)lookback)" in hurst
    assert "QM_Sig_Range_Breakout" in refresh
    assert "QM_BB_Upper" in refresh
    assert "QM_BB_Lower" in refresh
    assert "QM_BB_Middle" in refresh
    assert "QM_ATR" in refresh

    for line in source.splitlines():
        if "CopyRates(" in line or "iClose(" in line:
            assert "// perf-allowed" in line


def test_framework_risk_slippage_magic_mae_and_all_inputs_are_wired() -> None:
    raw = _source()
    source = hardening.strip_comments_preserve_lines(raw)
    on_init = _function(raw, "OnInit")

    assert "#include <QM/QM_Common.mqh>" in raw
    assert "input double RISK_PERCENT                 = 0.0;" in raw
    assert "input double RISK_FIXED                   = 1000.0;" in raw
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "strategy_max_slippage_ticks * tick_size / point" in on_init
    assert "QM_EntryConfigure(qm_ea_id" in on_init
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H1" in on_init
    assert re.search(r"\bqm_ea_id\s*\*", source) is None
    assert not re.search(r"(?i)tensorflow|torch|sklearn|keras|onnx", source)
    assert "CopyBuffer(" not in source

    inputs = re.findall(r"(?m)^\s*input\s+\S+\s+(\w+)\s*=", source)
    without_declarations = re.sub(
        r"(?m)^\s*input\s+\S+\s+\w+\s*=.*?;\s*$", "", source
    )
    assert inputs
    assert [
        name
        for name in inputs
        if re.search(rf"\b{re.escape(name)}\b", without_declarations) is None
    ] == []

    spec = (EA_DIR / "SPEC.md").read_text(encoding="utf-8-sig")
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec


def test_backtest_sets_cover_card_universe_and_all_strategy_inputs() -> None:
    source = _source()
    normalized_source = SOURCE_PATH.read_bytes().replace(b"\r\n", b"\n").replace(
        b"\r", b"\n"
    )
    source_hash = hashlib.sha256(normalized_source).hexdigest()
    strategy_inputs = re.findall(
        r"(?m)^\s*input\s+\S+\s+(strategy_\w+)\s*=", source
    )
    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == len(EXPECTED_SLOTS)

    for symbol, slot in EXPECTED_SLOTS.items():
        path = SETS_DIR / f"{EA_LABEL}_{symbol}_H1_backtest.set"
        assert path in setfiles
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert (
            "; card_defaults_source=strategy-seeds/cards/approved/"
            f"{EA_LABEL}.md"
        ) in text
        assert values["qm_ea_id"] == "37003"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["strategy_max_slippage_ticks"] == "3.0"
        assert all(name in values for name in strategy_inputs)
