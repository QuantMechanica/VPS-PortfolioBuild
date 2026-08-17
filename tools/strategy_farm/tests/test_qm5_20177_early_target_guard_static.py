from __future__ import annotations

import glob
from pathlib import Path
import pytest


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_20177_carney-ab-cd-pattern-h4-r1-recovery"
SOURCE = EA_DIR / "QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5"


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


def test_qm5_20177_entry_signal_rejects_early_target_at_fill() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    entry_body = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")

    # Ensure long branch computes T1 target and requires ask < t1 before accepting entry
    assert "const double t1 = d_proj + t1_fib * (C - d_proj);" in entry_body
    assert "const bool t1_ok = (ask < t1);" in entry_body
    assert "long_ok = touch_ok && confirm_ok && t1_ok" in entry_body

    # Ensure short branch computes T1 target and requires bid > t1 before accepting entry
    assert "const double t1 = d_proj + t1_fib * (C2p - d_proj);" in entry_body
    assert "const bool t1_ok = (bid > t1);" in entry_body
    assert "short_ok = touch_ok && confirm_ok && t1_ok" in entry_body


def test_qm5_20177_target_room_simulation_bullish_and_bearish() -> None:
    t1_fib = 0.382

    # --- Bullish Case ---
    # A=100.0, B=110.0, C=105.0 (C > A, B > A)
    # ab_range = 10.0, d_proj = C + (B - A) = 105.0 + 10.0 = 115.0
    # t1 = d_proj + t1_fib * (C - d_proj) = 115.0 + 0.382 * (105.0 - 115.0) = 115.0 - 3.82 = 111.18
    A, B, C = 100.0, 110.0, 105.0
    d_proj_bull = C + (B - A)
    t1_bull = d_proj_bull + t1_fib * (C - d_proj_bull)

    # 1. Defective state: Confirmation bar closed at 112.50 (> c2.high), ask is 112.52.
    # Price is already past T1 (112.52 > 111.18), target is behind fill.
    ask_behind = 112.52
    assert not (ask_behind < t1_bull), "Signal MUST be refused when ask is past T1"

    # 2. Valid room state: ask is 110.00 (< 111.18), price has room to reach T1.
    ask_with_room = 110.00
    assert (ask_with_room < t1_bull), "Signal MUST be accepted when ask has room to T1"

    # --- Bearish Case ---
    # A=120.0, B=110.0, C=115.0 (C < A, A > B)
    # ab_range = 10.0, d_proj = C - (A - B) = 115.0 - 10.0 = 105.0
    # t1 = d_proj + t1_fib * (C - d_proj) = 105.0 + 0.382 * (115.0 - 105.0) = 105.0 + 3.82 = 108.82
    A2, B2, C2p = 120.0, 110.0, 115.0
    d_proj_bear = C2p - (A2 - B2)
    t1_bear = d_proj_bear + t1_fib * (C2p - d_proj_bear)

    # 1. Defective state: Confirmation bar closed at 107.50 (< c2.low), bid is 107.48.
    # Price is already past T1 (107.48 < 108.82), target is behind fill.
    bid_behind = 107.48
    assert not (bid_behind > t1_bear), "Signal MUST be refused when bid is past T1"

    # 2. Valid room state: bid is 110.00 (> 108.82), price has room to reach T1.
    bid_with_room = 110.00
    assert (bid_with_room > t1_bear), "Signal MUST be accepted when bid has room to T1"


def test_qm5_20177_build_guardrails_compliance() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "qm_news_stale_max_hours" in source
    assert "qm_news_stale_max_hours      = 336;" in source

    setfiles = list(EA_DIR.glob("sets/*.set"))
    assert len(setfiles) >= 1, "At least one setfile must exist"

    for setfile in setfiles:
        values: dict[str, str] = {}
        for raw_line in setfile.read_text(encoding="utf-8-sig").splitlines():
            line = raw_line.strip()
            if not line or line.startswith(";") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()

        assert float(values.get("RISK_FIXED", "0")) > 0.0, f"RISK_FIXED must be > 0 in {setfile.name}"
        assert float(values.get("RISK_PERCENT", "1")) == 0.0, f"RISK_PERCENT must be 0 in {setfile.name}"
        if "qm_news_stale_max_hours" in values:
            assert int(values["qm_news_stale_max_hours"]) <= 336, f"News stale max hours > 336 in {setfile.name}"
