"""Execute the changed MQL stress predicate with governed Q06 input values."""
import math
from pathlib import Path
import re

import pytest

ROOT = Path(__file__).resolve().parents[4]
FAMILY = [41171, 41319, 41358, 41359, 41360, 41361, 41362]
SEEDS = [7, 17, 42, 99, 2026]
PROBABILITIES = [0.0, 0.1, 0.5, 1.0]
FRAMEWORK_PIN = re.compile(
    r"\b(?:qm_rng_seed|qm_news_(?:temporal|compliance|stale_max_hours|min_impact|mode(?:_legacy)?)|qm_friday_close_\w+)\b\s*(?:==|!=)"
    r"|(?:==|!=)\s*\b(?:qm_rng_seed|qm_news_(?:temporal|compliance|stale_max_hours|min_impact|mode(?:_legacy)?)|qm_friday_close_\w+)\b"
    r"|!\s*qm_friday_close_enabled\b",
    re.I,
)


def source_path(ea):
    directory = next((ROOT / "framework/EAs").glob(f"QM5_{ea}_*"))
    return directory / (directory.name + ".mq5")


def input_guard(source):
    match = re.search(
        r"bool\s+Strategy_(?:InputsValid|NoTradeFilter)\s*\([^)]*\)\s*\{.*?^\s*\}",
        source,
        re.M | re.S,
    )
    assert match
    return match.group(0)


def predicate(source, seed, probability):
    # Translate only the actual finite/range expression, not a parallel model.
    guard = input_guard(source)
    assert not FRAMEWORK_PIN.search(guard)
    assert not re.search(r"\bqm_stress_reject_probability\b\s*(?:==|!=)|(?:==|!=)\s*\bqm_stress_reject_probability\b", guard)
    reject = re.search(r"!MathIsValidNumber\(qm_stress_reject_probability\)\s*\|\|\s*qm_stress_reject_probability < 0\.0\s*\|\|\s*qm_stress_reject_probability > 1\.0", source)
    accept = re.search(r"MathIsValidNumber\(qm_stress_reject_probability\)\s*&&\s*qm_stress_reject_probability >= 0\.0\s*&&\s*qm_stress_reject_probability <= 1\.0", source)
    assert bool(reject) != bool(accept)
    expression = (reject or accept)[0].replace("||", " or ").replace("&&", " and ").replace("!", "not ")
    expression = " ".join(expression.split())
    value = eval(expression, {"__builtins__": {}, "MathIsValidNumber": math.isfinite,
                              "qm_stress_reject_probability": probability})
    return not value if reject else value


@pytest.mark.parametrize("ea", FAMILY)
@pytest.mark.parametrize("seed", SEEDS)
@pytest.mark.parametrize("probability", PROBABILITIES)
def test_actual_family_guard_accepts_q07_inputs(ea, seed, probability):
    assert predicate(source_path(ea).read_text(), seed, probability)


@pytest.mark.parametrize("ea", FAMILY)
@pytest.mark.parametrize("probability,allowed", [(-.01, False), (1.01, False),
    (math.nan, False), (math.inf, False), (-math.inf, False)])
def test_actual_family_guard_rejects_invalid_probability(ea, probability, allowed):
    assert predicate(source_path(ea).read_text(), 42, probability) is allowed


@pytest.mark.parametrize("ea", FAMILY)
def test_framework_owned_pins_removed_and_strategy_pins_retained(ea):
    path = source_path(ea)
    new = path.read_text()
    assert not FRAMEWORK_PIN.search(input_guard(new))
    assert "qm_rng_seed" not in input_guard(new)
    # EA identity, magic allocation, strategy parameters and risk remain pinned.
    assert f"qm_ea_id {'!=' if ea in (41171, 41319) else '=='} {ea}" in input_guard(new)
    assert "qm_magic_slot_offset" in input_guard(new)
    assert "strategy_" in input_guard(new)
    assert "RISK_FIXED" in input_guard(new)
    assert "MathIsValidNumber(qm_stress_reject_probability)" in input_guard(new)


def test_framework_already_accepts_harsh_probability():
    entry = (ROOT / "framework/Include/QM/QM_Entry.mqh").read_text()
    assert "(stress_reject_probability < 0.0) ? 0.0" in entry
    assert "(stress_reject_probability > 1.0) ? 1.0 : stress_reject_probability" in entry
