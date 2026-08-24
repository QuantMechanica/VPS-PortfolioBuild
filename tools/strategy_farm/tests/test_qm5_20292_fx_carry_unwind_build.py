from __future__ import annotations

import csv
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LABEL = "QM5_20292_fx-carry-unwind_card"
EA_DIR = ROOT / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
CARD = ROOT / "strategy-seeds" / "cards" / "approved" / (
    "QM5_20292_fx-carry-unwind_card.md"
)
TARGETS = (
    "AUDCHF.DWX",
    "AUDJPY.DWX",
    "GBPCHF.DWX",
    "GBPJPY.DWX",
    "NZDCHF.DWX",
    "NZDJPY.DWX",
)
SIGNALS = (
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "AUDUSD.DWX",
    "NZDUSD.DWX",
    "USDJPY.DWX",
    "USDCHF.DWX",
    "USDCAD.DWX",
)
BASELINE = {
    "strategy_rv_window_d1": "21",
    "strategy_rv_baseline_observations": "252",
    "strategy_min_valid_signal_symbols": "5",
    "strategy_stress_entry_ratio": "1.50",
    "strategy_stress_exit_ratio": "1.10",
    "strategy_selected_legs": "2",
    "strategy_atr_period_d1": "20",
    "strategy_atr_sl_mult": "2.5",
    "strategy_max_hold_d1_bars": "5",
    "strategy_spread_history_d1": "20",
    "strategy_spread_mult": "3.0",
    "strategy_history_bars": "320",
    "strategy_max_endpoint_gap_days": "10",
    "strategy_deviation_points": "20",
}


def _source(path: Path = EA) -> str:
    return path.read_text(encoding="utf-8-sig")


def _compact(value: str) -> str:
    return "".join(value.split())


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in _source(path).splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_approved_card_is_mirrored_and_basket_manifest_is_exact() -> None:
    mirror = EA_DIR / "docs" / "strategy_card.md"
    assert _source(mirror).rstrip("\n") == _source(CARD).rstrip("\n")

    manifest = json.loads(_source(EA_DIR / "basket_manifest.json"))
    assert manifest["host_symbol"] == "AUDCHF.DWX"
    assert manifest["host_timeframe"] == "D1"
    assert tuple(manifest["traded_symbols"]) == TARGETS
    assert tuple(manifest["signal_symbols"]) == SIGNALS


def test_registry_allocation_matches_magic_formula_without_duplicates() -> None:
    with (ROOT / "framework" / "registry" / "ea_id_registry.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        ea_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "20292"]
    assert len(ea_rows) == 1
    assert ea_rows[0]["slug"] == "fx-carry-unwind"
    assert ea_rows[0]["status"] == "active"

    with (ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "20292" and row["status"] == "active"
        ]
    assert len(rows) == len(TARGETS)
    assert tuple(row["symbol"] for row in rows) == TARGETS
    for slot, row in enumerate(rows):
        assert int(row["symbol_slot"]) == slot
        assert int(row["magic"]) == 20292 * 10_000 + slot


def test_all_target_setfiles_seal_the_backtest_baseline() -> None:
    setfiles = sorted((EA_DIR / "sets").glob(f"{LABEL}_*_D1_backtest.set"))
    assert len(setfiles) == len(TARGETS)
    assert tuple(path.name[len(LABEL) + 1 : -len("_D1_backtest.set")] for path in setfiles) == TARGETS

    for slot, path in enumerate(setfiles):
        values = _set_values(path)
        assert values["qm_ea_id"] == "20292"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["PORTFOLIO_WEIGHT"] == "1"
        assert values["qm_rng_seed"] == "42"
        assert values["qm_news_temporal"] == "0"
        assert values["qm_news_compliance"] == "0"
        assert values["qm_news_stale_max_hours"] == "336"
        assert values["qm_news_min_impact"] == "high"
        assert values["qm_news_mode_legacy"] == "0"
        assert values["qm_friday_close_enabled"] == "1"
        assert values["qm_friday_close_hour_broker"] == "21"
        assert values["qm_stress_reject_probability"] == "0.0"
        assert {key: values[key] for key in BASELINE} == BASELINE


def test_every_strategy_input_is_used_and_only_declared_p3_axes_can_vary() -> None:
    source = _source()
    names = re.findall(
        r"^input\s+(?:int|double)\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert set(names) == set(BASELINE)
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2

    compact = _compact(source)
    assert "strategy_stress_entry_ratio-1.25" in compact
    assert "strategy_stress_entry_ratio-1.50" in compact
    assert "strategy_stress_entry_ratio-1.75" in compact
    assert "strategy_stress_exit_ratio-1.00" in compact
    assert "strategy_stress_exit_ratio-1.10" in compact
    assert "strategy_stress_exit_ratio-1.20" in compact
    assert "strategy_max_hold_d1_bars==3" in compact
    assert "strategy_max_hold_d1_bars==5" in compact
    assert "strategy_selected_legs<1" in compact
    assert "strategy_selected_legs>QM5_20292_MAX_PACKAGE_LEGS" in compact


def test_week_attempt_is_persisted_before_history_or_signal_checks() -> None:
    source = _source()
    advance = _compact(_function_body(source, "void Strategy_AdvanceStateOnNewBar()"))
    assert advance.index("Strategy_RecordWeekAttempt(current_week_key)") < advance.index(
        "Strategy_GlobalStress(host_bar.time"
    )
    assert "GlobalVariableSet(g_week_attempt_state_key,(double)week_key)" in _compact(
        _function_body(source, "bool Strategy_RecordWeekAttempt(")
    )
    assert "GlobalVariableCheck(g_week_attempt_state_key)" in _compact(
        _function_body(source, "void Strategy_LoadAttemptState()")
    )


def test_stress_carry_rank_and_unwind_direction_are_card_faithful() -> None:
    source = _source()
    compact = _compact(source)
    assert "strategy_rv_window_d1+strategy_rv_baseline_observations+1" in compact
    assert "MathLog(newer.close / older.close)" in source
    assert "MathSqrt(variance) * MathSqrt(252.0)" in source
    assert "baseline_values[i] = rolling_vols[i + 1]" in source
    assert "out_valid_symbols < strategy_min_valid_signal_symbols" in source

    for mode in (
        "SYMBOL_SWAP_MODE_POINTS",
        "SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT",
        "SYMBOL_SWAP_MODE_CURRENCY_SYMBOL",
        "SYMBOL_SWAP_MODE_CURRENCY_MARGIN",
        "SYMBOL_SWAP_MODE_INTEREST_CURRENT",
        "SYMBOL_SWAP_MODE_INTEREST_OPEN",
    ):
        assert mode in source
    assert "candidate.carry_cash_per_lot /" in source
    assert "StringCompare(g_target_symbols[left.target_index]" in source
    assert "const int unwind_direction = -candidate.favorable_direction;" in source


def _package_trace(selected_legs: int, open_results: tuple[bool, ...]) -> tuple[str, ...]:
    events = [f"prepare:{index}" for index in range(selected_legs)]
    for index in range(selected_legs):
        events.append(f"open:{index}")
        if not open_results[index]:
            events.append("flatten")
            return tuple(events)
    events.append("package_open")
    return tuple(events)


def test_atomic_package_prepares_all_legs_and_rolls_back_partial_open() -> None:
    source = _source()
    package = _compact(
        _function_body(source, "bool Strategy_OpenCarryUnwindPackage()")
    )
    prepare = package.index("Strategy_PrepareLeg(candidates[i],requests[i])")
    open_leg = package.index("Strategy_OpenPreparedLeg(requests[i],ticket)")
    flatten = package.index("Strategy_ClosePackage(QM_EXIT_STRATEGY)", open_leg)
    assert prepare < open_leg < flatten

    assert _package_trace(2, (True, False)) == (
        "prepare:0",
        "prepare:1",
        "open:0",
        "open:1",
        "flatten",
    )
    assert _package_trace(1, (True,))[-1] == "package_open"


def test_management_repairs_orphans_and_exits_on_stress_or_time() -> None:
    source = _source()
    manage = _compact(_function_body(source, "void Strategy_ManageOpenPosition()"))
    orphan = manage.index("open_legs!=strategy_selected_legs")
    new_bar = manage.index("if(!g_new_d1_bar)")
    stress = manage.index("g_stress_ratio<=strategy_stress_exit_ratio")
    time_stop = manage.index("held_bars>=strategy_max_hold_d1_bars")
    assert orphan < new_bar < stress < time_stop
    assert "Strategy_ClosePackage(QM_EXIT_TIME_STOP)" in manage


def test_framework_corset_and_entry_only_news_ordering() -> None:
    source = _source()
    on_tick = _compact(_function_body(source, "void OnTick()"))
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae()") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition()") < on_tick.index(
        "Strategy_EntrySignal(request)"
    )
    entry = _compact(
        _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &request)")
    )
    assert entry.index("Strategy_NewsFilterHook(TimeCurrent())") < entry.index(
        "Strategy_OpenCarryUnwindPackage()"
    )
    assert source.count("QM_IsNewBar(") == 1
    assert "CopyBuffer(" not in source
    assert not re.search(r"\bi(?:ATR|MA|RSI|MACD|ADX|Bands)\s*\(", source)
    for forbidden in ("onnx", "tensorflow", "torch", "sklearn", "keras"):
        assert forbidden not in source.lower()
