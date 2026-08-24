from __future__ import annotations

import math
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_1624_ehlers-adaptive-cg-h4"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SET_PATHS = sorted((EA_DIR / "sets").glob("*_backtest.set"))


def source() -> str:
    return EA_PATH.read_text(encoding="utf-8-sig")


def function_body(code: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", code)
    assert match is not None, f"missing function {name}"
    start = match.end() - 1
    depth = 0
    for offset in range(start, len(code)):
        if code[offset] == "{":
            depth += 1
        elif code[offset] == "}":
            depth -= 1
            if depth == 0:
                return code[start + 1 : offset]
    raise AssertionError(f"unterminated function {name}")


def assignments(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def ehlers_2013_acp(closes: list[float], low: int = 6, high: int = 48) -> int:
    """Independent numeric fixture for the algorithm ported into the EA."""
    count = len(closes)
    hp = [0.0] * count
    filt = [0.0] * count
    angle = 0.707 * 2.0 * math.pi / 48.0
    alpha1 = (math.cos(angle) + math.sin(angle) - 1.0) / math.cos(angle)
    hp_a = (1.0 - alpha1 / 2.0) ** 2
    hp_b = 2.0 * (1.0 - alpha1)
    hp_c = -(1.0 - alpha1) ** 2
    a1 = math.exp(-1.414 * math.pi / 10.0)
    b1 = 2.0 * a1 * math.cos(1.414 * math.pi / 10.0)
    c2, c3 = b1, -(a1**2)
    c1 = 1.0 - c2 - c3
    for i in range(2, count):
        hp[i] = (
            hp_a * (closes[i] - 2.0 * closes[i - 1] + closes[i - 2])
            + hp_b * hp[i - 1]
            + hp_c * hp[i - 2]
        )
        filt[i] = (
            c1 * (hp[i] + hp[i - 1]) / 2.0
            + c2 * filt[i - 1]
            + c3 * filt[i - 2]
        )

    smoothed_power = [0.0] * 65
    max_power = 0.0
    last_period = 0
    for end in range(50, count):
        corr = [0.0] * 65
        for lag in range(49):
            xs = [filt[end - j] for j in range(3)]
            ys = [filt[end - lag - j] for j in range(3)]
            sx, sy = sum(xs), sum(ys)
            sxx = sum(x * x for x in xs)
            syy = sum(y * y for y in ys)
            sxy = sum(x * y for x, y in zip(xs, ys, strict=True))
            var_x = 3.0 * sxx - sx * sx
            var_y = 3.0 * syy - sy * sy
            if var_x * var_y > 1e-15:
                corr[lag] = (3.0 * sxy - sx * sy) / math.sqrt(var_x * var_y)

        for period in range(low, high + 1):
            cosine = sum(
                corr[lag] * math.cos(2.0 * math.pi * lag / period)
                for lag in range(3, 49)
            )
            sine = sum(
                corr[lag] * math.sin(2.0 * math.pi * lag / period)
                for lag in range(3, 49)
            )
            sq_sum = cosine * cosine + sine * sine
            smoothed_power[period] = (
                0.2 * sq_sum * sq_sum + 0.8 * smoothed_power[period]
            )

        max_power *= 0.995
        max_power = max(max_power, *smoothed_power[low : high + 1])
        weights = [
            (period, smoothed_power[period] / max_power)
            for period in range(low, high + 1)
            if max_power > 0.0 and smoothed_power[period] / max_power >= 0.5
        ]
        if weights:
            last_period = round(
                sum(period * power for period, power in weights)
                / sum(power for _, power in weights)
            )
    return last_period


def test_ehlers_acp_numeric_cycle_fixtures() -> None:
    for expected_period in (8, 12, 24, 40):
        closes = [
            100.0 + 2.0 * math.sin(2.0 * math.pi * i / expected_period)
            for i in range(224)
        ]
        assert ehlers_2013_acp(closes) == expected_period


def test_source_contains_centered_normalized_spectrum_cg_not_raw_argmax() -> None:
    code = source()
    detector = function_body(code, "ComputeDominantPeriod")

    assert "close0 - 2.0 * close1 + close2" in detector
    assert "ss_c1 * (hp[i] + hp[i - 1]) / 2.0" in detector
    assert "m * sxy - sx * sy" in detector
    assert "var_x * var_y" in detector
    assert "0.2 * sq_sum * sq_sum" in detector
    assert "max_power *= 0.995" in detector
    assert "normalized_power >= 0.5" in detector
    assert "weighted_period / weight_sum" in detector
    assert "sum_xy / denom" not in detector
    assert "best_period" not in detector


def test_actual_h4_bar_stop_and_restart_durable_entry_state() -> None:
    code = source()
    exit_signal = function_body(code, "Strategy_ExitSignal")
    restore = function_body(code, "RestoreAcceptedEntryState")
    on_tick = function_body(code, "OnTick")

    assert "iBarShift(_Symbol, PERIOD_H4, h4_bar, false)" in code
    assert "TimeCurrent() -" not in exit_signal
    assert "strategy_time_stop_mult * (double)entry_period" in exit_signal
    assert "PositionGetString(POSITION_COMMENT)" in exit_signal
    assert "HistoryDealGetString(deal, DEAL_COMMENT)" in restore
    assert "DEAL_ENTRY_IN" in restore
    assert "g_last_entry_period" in function_body(code, "Strategy_EntrySignal")
    assert "EntryProvenanceComment" in function_body(code, "Strategy_EntrySignal")
    assert re.search(
        r"if\(QM_TM_OpenPosition\(req, out_ticket\)\)\s*CommitAcceptedEntryState\(\);",
        on_tick,
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )


def test_h4_framework_contract_magic_mae_and_bounded_series_access() -> None:
    code = source()
    on_init = function_body(code, "OnInit")
    on_tick = function_body(code, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H4" in on_init
    assert "QM_IsNewBar(_Symbol, PERIOD_H4)" in on_tick
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert "QM_FrameworkMagic()" in code
    assert "STRATEGY_MAX_RATE_BARS" in code
    assert "ArraySize(rates) < rate_count" in code
    assert "ArraySize(h4) < bars_needed" in code
    assert "CopyBuffer(" not in code
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", code, re.IGNORECASE)

    raw_series = re.compile(r"\b(?:iOpen|iClose|iHigh|iLow|iTime|iBarShift|CopyRates)\s*\(")
    for line in code.splitlines():
        if raw_series.search(line):
            assert "perf-allowed:" in line


def test_every_input_is_wired_and_backtest_risk_contract_is_fixed() -> None:
    code = source()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []

    assert len(SET_PATHS) == 14
    for set_path in SET_PATHS:
        values = assignments(set_path)
        assert values["qm_ea_id"] == "1624"
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        framework_defaults = {
            "qm_rng_seed",
            "qm_news_temporal",
            "qm_news_compliance",
            "qm_news_stale_max_hours",
            "qm_news_min_impact",
            "qm_news_mode_legacy",
            "qm_friday_close_enabled",
            "qm_friday_close_hour_broker",
            "qm_stress_reject_probability",
        }
        assert set(input_names) - framework_defaults <= set(values)
