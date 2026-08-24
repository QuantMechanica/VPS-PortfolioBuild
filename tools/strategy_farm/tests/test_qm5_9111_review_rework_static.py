from __future__ import annotations

import hashlib
import math
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_9111_aa-dlwma-trend10"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"


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


def _lwma(closes_by_shift: list[float], shift: int, period: int) -> float:
    weights = range(period, 0, -1)
    return sum(
        weight * closes_by_shift[shift + offset]
        for offset, weight in enumerate(weights)
    ) / sum(range(1, period + 1))


def _dlwma_components(
    closes_by_shift: list[float], shift: int, period: int
) -> tuple[float, float, float]:
    lwma1 = _lwma(closes_by_shift, shift, period)
    weights = range(period, 0, -1)
    lwma2 = sum(
        weight * _lwma(closes_by_shift, shift + offset, period)
        for offset, weight in enumerate(weights)
    ) / sum(range(1, period + 1))
    trend = 3.0 / (period - 1) * (lwma1 - lwma2)
    return lwma1, lwma2, trend


def test_qm5_9111_hardening_gate_is_clean() -> None:
    result = hardening.analyze_file(
        SOURCE_PATH, hardening.find_card(ROOT, EA_LABEL)
    )
    assert result["failures"] == []
    assert result["warnings"] == []


def test_qm5_9111_spread_gate_is_exact_bounded_and_fail_closed() -> None:
    source = _source()
    spread = _function(source, "SpreadAllowsEntry")

    assert "input double strategy_spread_median_mult = 2.5;" in source
    assert "strategy_spread_atr_mult" not in source
    assert "const int lookback = 20;" in spread
    assert "CopySpread(_Symbol, PERIOD_D1, 1, lookback, spreads); // perf-allowed" in spread
    assert "copied != lookback || ArraySize(spreads) < lookback" in spread
    assert "i >= ArraySize(spreads) || spreads[i] <= 0" in spread
    assert "ArraySort(spreads);" in spread
    assert "strategy_spread_median_mult * median_spread" in spread
    assert "return true;" not in spread


def test_qm5_9111_dlwma_reference_vectors_and_exact_slope() -> None:
    source = _source()
    trend = _function(source, "ComputeDLWMATrend")
    closes_by_shift = [
        101.0,
        102.5,
        101.75,
        104.0,
        106.5,
        105.25,
        108.0,
        110.5,
        109.75,
        112.0,
        114.5,
        113.0,
        116.25,
        118.0,
        117.5,
        120.0,
        122.75,
        121.5,
        124.0,
        126.5,
        125.0,
    ]

    assert "sum_lwma2 += (double)(n - k) * l1_val;" in trend
    assert "trend = (3.0 / (double)(n - 1)) * (lwma1 - lwma2);" in trend
    assert "MathIsValidNumber(trend)" in trend
    expected = {
        1: (105.44545454545455, 109.3201652892562, -1.2915702479338843),
        2: (106.5409090909091, 110.62223140495868, -1.3604407713498623),
    }
    for shift, reference in expected.items():
        actual = _dlwma_components(closes_by_shift, shift, 10)
        for observed, wanted in zip(actual, reference, strict=True):
            assert math.isclose(observed, wanted, rel_tol=0.0, abs_tol=1e-12)


def test_qm5_9111_d1_clock_and_entry_filters_do_not_suppress_exits() -> None:
    source = _source()
    on_init = _function(source, "OnInit")
    on_tick = _function(source, "OnTick")

    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in on_init
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in on_tick
    assert "QM_IsNewBar()" not in on_tick
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("QM_FrameworkHandleFridayClose()") < on_tick.index(
        "QM_IsNewBar(_Symbol, PERIOD_D1)"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )


def test_qm5_9111_framework_corset_inputs_and_backtest_risk() -> None:
    raw = _source()
    source = hardening.strip_comments_preserve_lines(raw)

    assert "#include <QM/QM_Common.mqh>" in raw
    assert "QM_FrameworkMagic()" in source
    assert "CopyBuffer(" not in source
    assert re.search(r"\bqm_ea_id\s*\*", source) is None
    assert not re.search(r"(?i)tensorflow|torch|sklearn|keras|onnx", source)
    for line in raw.splitlines():
        if "CopySpread(" in line:
            assert "// perf-allowed" in line

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

    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == 13
    normalized = SOURCE_PATH.read_bytes().replace(b"\r\n", b"\n").replace(
        b"\r", b"\n"
    )
    checkout_hash = hashlib.sha256(normalized.replace(b"\n", b"\r\n")).hexdigest()
    for setfile in setfiles:
        payload = setfile.read_text(encoding="utf-8-sig")
        assert f"; build_hash:   {checkout_hash}" in payload
        assert "RISK_FIXED=1000" in payload
        assert "RISK_PERCENT=0" in payload
        assert "strategy_spread_median_mult=2.5" in payload
        assert "strategy_spread_atr_mult" not in payload
