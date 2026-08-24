from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from framework.scripts import validate_spec_doc


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_DIR = REPO_ROOT / "framework" / "EAs" / "QM5_9113_aa-ab-velocity"
SOURCE_PATH = EA_DIR / "QM5_9113_aa-ab-velocity.mq5"
SPEC_PATH = EA_DIR / "SPEC.md"


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


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


def test_recursive_state_is_seeded_once_and_advanced_incrementally() -> None:
    source = _source()

    reconstruct = _function_body(source, "bool Strategy_ReconstructABState()")
    advance = _function_body(source, "bool Strategy_AdvanceABState()")
    entry = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")
    exit_signal = _function_body(source, "bool Strategy_ExitSignal()")

    assert "const double seed_close = rates[oldest].close;" in reconstruct
    assert "for(int i = oldest - 1; i >= 0; --i)" in reconstruct
    assert "CopyRates(_Symbol, PERIOD_D1, 1, closed_bars, rates)" in reconstruct
    assert "copied != closed_bars || ArraySize(rates) != closed_bars" in reconstruct
    assert "iBarShift(_Symbol, PERIOD_D1, g_ab_last_closed_bar_time, true)" in advance
    assert "g_ab_velocity_previous = g_ab_velocity;" in advance
    assert "CopyRates" not in entry
    assert "CopyRates" not in exit_signal
    assert "Strategy_CalculateABVelocity" not in source
    assert "warmup + 10" not in source


def test_alpha_beta_reference_vector_matches_sealed_constants() -> None:
    alpha = 0.29896
    beta = 0.05295
    closes = [100.0, 101.0, 102.0, 101.0, 103.0]
    position = closes[0]
    velocity = 0.0

    for close in closes[1:]:
        prediction = position + velocity
        residual = close - prediction
        position = prediction + alpha * residual
        velocity = velocity + beta * residual

    assert position == 101.68932923728812
    assert velocity == 0.24001492360508736
    source = _source()
    assert "101.68932923728812" in source
    assert "0.24001492360508736" in source
    assert "Strategy_ABReferenceVectorPasses()" in source


def test_exit_and_management_precede_all_entry_only_filters() -> None:
    on_tick = _function_body(_source(), "void OnTick()")

    friday = on_tick.index("QM_FrameworkHandleFridayClose()")
    management = on_tick.index("Strategy_ManageOpenPosition();")
    refresh = on_tick.index("Strategy_RefreshABSnapshot()")
    exit_signal = on_tick.index("Strategy_ExitSignal()")
    news = on_tick.index("QM_NewsAllowsTrade2")
    spread_and_history = on_tick.index("Strategy_NoTradeFilter()")
    entry = on_tick.index("Strategy_EntrySignal(req)")

    assert friday < management < refresh < exit_signal < news < spread_and_history < entry
    assert "const bool is_new_d1_bar = QM_IsNewBar(_Symbol, PERIOD_D1);" in on_tick
    assert "if(!is_new_d1_bar) return;" in on_tick


def test_spread_filter_requires_exact_positive_twenty_day_sample() -> None:
    source = _source()
    median = _function_body(source, "double Strategy_MedianSpreadD1")
    admission = _function_body(source, "bool Strategy_SpreadAllowsEntry()")

    assert "copied != lookback || ArraySize(rates) != lookback" in median
    assert "if(rates[i].spread <= 0)" in median
    assert "STRATEGY_SPREAD_LOOKBACK_DAYS" in admission
    assert "ask <= 0.0 || bid <= 0.0 || !(ask > bid)" in admission
    assert "if(current_spread <= 0.0)" in admission
    assert "if(median_spread <= 0.0)" in admission
    assert "return true;" not in admission


def test_declared_strategy_inputs_are_wired_and_framework_contract_is_present() -> None:
    source = _source()
    strategy_inputs = re.findall(r"^input\s+\w+\s+(strategy_\w+)\s*=", source, re.MULTILINE)

    assert strategy_inputs == [
        "strategy_alpha",
        "strategy_beta",
        "strategy_atr_period",
        "strategy_atr_sl_mult",
        "strategy_min_warmup_bars",
        "strategy_enable_shorts",
    ]
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    assert "input double RISK_PERCENT               = 0.0;" in source
    assert "input double RISK_FIXED                 = 1000.0;" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "CopyBuffer(" not in source
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", source, re.IGNORECASE)

    for line in source.splitlines():
        if re.search(r"\b(?:Bars|CopyRates|iBarShift)\(", line):
            assert "perf-allowed" in line, line


def test_spec_is_clean_and_validator_rejects_control_characters(tmp_path: Path) -> None:
    raw_spec = SPEC_PATH.read_bytes()
    assert not any(byte < 32 and byte not in {9, 10, 13} for byte in raw_spec)
    assert validate_spec_doc.check_one(EA_DIR) == (True, [])

    fixture = tmp_path / "QM5_9113_control-byte-fixture"
    fixture.mkdir()
    sections = "\n".join(f"## {name}\ntext" for name in validate_spec_doc.REQUIRED_SECTIONS)
    (fixture / "SPEC.md").write_text(
        f"**EA ID:** QM5_9113\n{sections}\ncorrupt:\x07value\n",
        encoding="utf-8",
    )

    ok, failures = validate_spec_doc.check_one(fixture)
    assert not ok
    assert any("non-whitespace control characters (1)" in failure for failure in failures)
    assert any("0x07" in failure for failure in failures)


def test_build_identity_fail_closes_stale_predecessor_binary() -> None:
    identity = json.loads((EA_DIR / "build_identity.json").read_text(encoding="utf-8"))
    source_sha256 = hashlib.sha256(SOURCE_PATH.read_bytes()).hexdigest()

    assert identity["mq5_sha256"] == source_sha256
    assert identity["build_check_passed"] is False
    assert identity["build_check_status"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["ex5_current_for_mq5"] is False
    assert "ex5_sha256" not in identity
    assert len(identity["predecessor_ex5_sha256"]) == 64
