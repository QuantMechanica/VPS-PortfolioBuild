from __future__ import annotations

import csv
import hashlib
import json
import math
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_1623_hopwood-bermaui-dss-h4"
SOURCE = EA_DIR / "QM5_1623_hopwood-bermaui-dss-h4.mq5"
SPEC = EA_DIR / "SPEC.md"
BUILD_IDENTITY = EA_DIR / "build_identity.json"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("GDAXI.DWX", 16230000),
    1: ("NDX.DWX", 16230001),
    2: ("SP500.DWX", 16230002),
    3: ("UK100.DWX", 16230003),
    4: ("WS30.DWX", 16230004),
    5: ("XAUUSD.DWX", 16230005),
    6: ("EURUSD.DWX", 16230006),
    7: ("GBPUSD.DWX", 16230007),
    8: ("USDJPY.DWX", 16230008),
    9: ("USDCHF.DWX", 16230009),
    10: ("AUDUSD.DWX", 16230010),
    11: ("USDCAD.DWX", 16230011),
    12: ("NZDUSD.DWX", 16230012),
}


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


def _nearest_rank(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    rank = math.ceil(percentile * len(ordered) / 100.0) - 1
    return ordered[max(0, min(rank, len(ordered) - 1))]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_card_baseline_defaults_replace_the_rejected_identity() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    expected_defaults = {
        "strategy_dss_stoch_period": "10",
        "strategy_dss_inner_ema": "5",
        "strategy_dss_outer_ema": "5",
        "strategy_bermaui_lookback": "100",
        "strategy_overbought_percentile": "80.0",
        "strategy_oversold_percentile": "20.0",
        "strategy_d1_ema_period": "200",
        "strategy_atr_period": "14",
        "strategy_atr_sl_mult": "2.0",
        "strategy_max_hold_bars": "20",
        "strategy_cooldown_bars": "6",
        "strategy_spread_max_atr_mult": "0.3",
    }
    for name, value in expected_defaults.items():
        assert re.search(rf"\b{name}\s*=\s*{re.escape(value)}\s*;", source), name

    for rejected in (
        "strategy_bermaui_k",
        "strategy_min_overshoot_mult",
        "strategy_atr_tp_mult",
        "strategy_be_atr_mult",
        "QM_TakeATRFromValue",
        "QM_TM_MoveSL",
    ):
        assert rejected not in source

    entry = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")
    assert entry.count("req.tp = 0.0;") == 2
    assert "QM_StopATRFromValue" in entry
    assert "strategy_atr_sl_mult" in entry


def test_percentile_bands_are_nearest_rank_over_two_100_bar_windows() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    percentile = _function_body(source, "bool DSS_Percentile(")
    advance = _function_body(source, "bool AdvanceState_OnNewBar()")

    assert "ArraySize(source) < offset + count" in percentile
    assert "ArraySize(sample) < count" in percentile
    assert "ArraySort(sample);" in percentile
    assert "MathCeil(percentile * count / 100.0) - 1" in percentile
    assert "strategy_bermaui_lookback + 1" in advance
    assert advance.count("strategy_overbought_percentile") == 2
    assert advance.count("strategy_oversold_percentile") == 2
    assert "DSS_Percentile(dss_values, 0, strategy_bermaui_lookback" in advance
    assert "DSS_Percentile(dss_values, 1, strategy_bermaui_lookback" in advance

    values = [float(value) for value in range(1, 101)]
    assert _nearest_rank(values, 20.0) == 20.0
    assert _nearest_rank(values, 80.0) == 80.0


def test_dss_series_is_bounded_guarded_and_h4_fixed() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    raw = _function_body(source, "bool DSS_RawStochAtShift(")
    series = _function_body(source, "bool DSS_BuildSeries(")

    assert "const int warmup_count = 200;" in series
    assert "Bars(_Symbol, PERIOD_H4)" in series
    assert series.count("ArraySize(") >= 3
    assert "strategy_dss_inner_ema" in series
    assert "strategy_dss_outer_ema" in series
    assert "iHigh(_Symbol, PERIOD_H4" in raw
    assert "iLow(_Symbol, PERIOD_H4" in raw
    assert "iClose(_Symbol, PERIOD_H4" in raw
    assert raw.count("perf-allowed:") == 3


def test_entry_and_all_card_exit_families_share_one_snapshot() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    advance = _function_body(source, "bool AdvanceState_OnNewBar()")
    exit_signal = _function_body(source, "bool Strategy_ExitSignal(")
    manage = _function_body(source, "void Strategy_ManageOpenPosition()")

    assert "g_dss_outer_2 <= g_lower_thr_2" in advance
    assert "g_dss_outer_1 > g_lower_thr_1" in advance
    assert "g_dss_outer_2 >= g_upper_thr_2" in advance
    assert "g_dss_outer_1 < g_upper_thr_1" in advance
    assert "g_long_band_exit" in advance
    assert "g_short_band_exit" in advance
    assert "g_d1_bias > 0" in advance
    assert "g_d1_bias < 0" in advance

    assert "g_short_signal" in exit_signal
    assert "g_long_signal" in exit_signal
    assert "QM_EXIT_OPPOSITE_SIGNAL" in exit_signal
    assert "g_long_band_exit || g_d1_bias <= 0" in exit_signal
    assert "g_short_band_exit || g_d1_bias >= 0" in exit_signal
    assert "PERIOD_H4" in manage
    assert "strategy_max_hold_bars" in manage
    assert "QM_EXIT_TIME_STOP" in manage


def test_closed_bar_state_precedes_exits_and_entry_only_guards() -> None:
    on_tick = _function_body(SOURCE.read_text(encoding="utf-8"), "void OnTick()")

    mae = on_tick.index("QM_FrameworkTrackOpenPositionMae();")
    friday = on_tick.index("QM_FrameworkHandleFridayClose()")
    manage = on_tick.index("Strategy_ManageOpenPosition();")
    new_bar = on_tick.index("QM_IsNewBar(_Symbol, PERIOD_H4)")
    snapshot = on_tick.index("AdvanceState_OnNewBar()")
    exit_signal = on_tick.index("Strategy_ExitSignal(ticket, exit_reason)")
    spread = on_tick.index("Strategy_NoTradeFilter()")
    news = on_tick.index("QM_NewsAllowsTrade2(")
    entry = on_tick.index("Strategy_EntrySignal(req)")

    assert mae < friday < manage < new_bar < snapshot < exit_signal < spread < news < entry
    assert on_tick.count("QM_IsNewBar(_Symbol, PERIOD_H4)") == 1
    assert "ZeroMemory(req);" in on_tick


def test_spread_guard_is_current_snapshot_and_fail_closed() -> None:
    spread = _function_body(
        SOURCE.read_text(encoding="utf-8"), "bool Strategy_NoTradeFilter()"
    )

    assert "!g_state_ready || g_atr_1 <= 0.0" in spread
    assert "ask <= 0.0 || bid <= 0.0 || ask <= bid" in spread
    assert "spread > strategy_spread_max_atr_mult * g_atr_1" in spread


def test_h4_scope_is_rejected_during_initialization() -> None:
    init = _function_body(SOURCE.read_text(encoding="utf-8"), "int OnInit()")

    assert "_Period != PERIOD_H4" in init
    assert "return INIT_PARAMETERS_INCORRECT;" in init
    assert init.index("_Period != PERIOD_H4") < init.index("QM_FrameworkInit(")


def test_cooldown_resets_only_after_confirmed_order_acceptance() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    entry = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")
    on_tick = _function_body(source, "void OnTick()")

    assert "g_bars_since_last_long = 0" not in entry
    assert "g_bars_since_last_short = 0" not in entry
    open_start = on_tick.index("if(QM_TM_OpenPosition(req, out_ticket))")
    assert on_tick.index("g_bars_since_last_long = 0", open_start) > open_start
    assert on_tick.index("g_bars_since_last_short = 0", open_start) > open_start


def test_every_declared_strategy_input_has_an_executable_use_site() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    strategy_block = source.split('input group "Strategy"', 1)[1].split(
        "// -----------------------------------------------------------------------------", 1
    )[0]
    names = re.findall(r"(?m)^input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", strategy_block)

    assert len(names) == 12
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name


def test_existing_magic_allocations_and_13_fixed_risk_sets_are_unchanged() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "1623" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"])) for row in rows
    }
    assert actual == EXPECTED_SLOTS

    expected_names = {
        f"QM5_1623_hopwood-bermaui-dss-h4_{symbol}_H4_backtest.set"
        for symbol, _ in EXPECTED_SLOTS.values()
    }
    assert {path.name for path in SETS.glob("*.set")} == expected_names
    for slot, (symbol, _) in EXPECTED_SLOTS.items():
        values = _set_values(
            SETS / f"QM5_1623_hopwood-bermaui-dss-h4_{symbol}_H4_backtest.set"
        )
        assert values["qm_magic_slot_offset"] == str(slot)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"


def test_spec_documents_the_approved_contract_and_clean_risk_value() -> None:
    spec = SPEC.read_text(encoding="utf-8")

    assert "DSS(10,5,5)" in spec
    assert "80th and 20th percentiles" in spec
    assert "latest 100 completed H4 bars" in spec
    assert "20-H4-bar time stop" in spec
    assert "2.0 * ATR(14, H4)" in spec
    assert "no take-profit" in spec
    assert "$1,000 per trade" in spec
    assert "mean and standard deviation" not in spec


def test_build_identity_truthfully_marks_the_stale_binary() -> None:
    identity = json.loads(BUILD_IDENTITY.read_text(encoding="utf-8"))
    ex5 = EA_DIR / "QM5_1623_hopwood-bermaui-dss-h4.ex5"

    assert identity["rework_task_id"] == "9c4f7a27-e62e-41e4-8d21-1e74c7a05c33"
    assert identity["mq5_sha256"] == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert identity["ex5_sha256"] == hashlib.sha256(ex5.read_bytes()).hexdigest()
    assert identity["build_check_passed"] is False
    assert identity["compile_succeeded"] is False
    assert identity["compile_blocked_reason"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["ex5_status"] == "stale_pre_rework_binary_not_rebuilt"
