from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_1410_bressert-dual-cycle-oscillator-h4"
    / "QM5_1410_bressert-dual-cycle-oscillator-h4.mq5"
)


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


def test_card_news_window_is_entry_only_and_exactly_two_h4_bars() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    on_tick = function_body(code, "OnTick")

    assert "qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;" in code
    assert "QM_NewsInWindow(utc_time, _Symbol, 480, 480, qm_news_min_impact)" in entry
    assert re.search(
        r"QM_FrameworkInit\([\s\S]*?qm_friday_close_hour_broker,\s*"
        r"480, 480, qm_news_stale_max_hours",
        code,
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert on_tick.index("Strategy_ExitSignal(is_new_bar)") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )


def test_tp1_partial_close_is_restart_idempotent() -> None:
    code = source()
    rebuild = function_body(code, "Strategy_ReconstructPositionState")
    manage = function_body(code, "Strategy_ManageOpenPosition")

    assert "POSITION_IDENTIFIER" in rebuild
    assert "HistorySelect(position_time - 60, now)" in rebuild
    assert "DEAL_POSITION_ID" in rebuild
    assert "DEAL_ENTRY_OUT" in rebuild
    assert "g_tp1_done = partial_exit_seen;" in rebuild
    assert manage.index("Strategy_ReconstructPositionState(ticket)") < manage.index(
        "if(!g_tp1_done)"
    )
    assert "if(trade.PositionClosePartial(ticket, close_vol))" in manage


def test_gain_cap_is_mae_adjusted_instead_of_a_static_price_tp() -> None:
    code = source()
    manage = function_body(code, "Strategy_ManageOpenPosition")
    exit_signal = function_body(code, "Strategy_ExitSignal")
    entry = function_body(code, "Strategy_EntrySignal")

    assert "g_mae_adverse_price" in function_body(
        code, "Strategy_ReconstructPositionState"
    )
    assert "mae_adjusted_gain = favorable_gain - g_mae_adverse_price" in manage
    assert "mae_adjusted_gain >= strategy_tp_cap_atr_mult * atr" in manage
    assert "if(g_mae_cap_reached)" in exit_signal
    assert entry.count("req.tp = 0.0;") == 2
    assert "strategy_tp_cap_atr_mult * atr" not in entry


def test_framework_corset_and_all_declared_inputs_are_wired() -> None:
    code = source()
    on_tick = function_body(code, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkMagic()" in code
    assert "QM_ATR(" in code
    assert "QM_SMA(" in code
    assert "iATR(" not in code
    assert "iMA(" not in code
    assert "CopyBuffer(" not in code
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert "QM_EntryRequest req = {};" in on_tick
    assert code.count("req.expiration_seconds = 0;") == 2

    for line in code.splitlines():
        if "CopyRates(" in line:
            assert "// perf-allowed" in line

    inputs = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    assert inputs
    unused = [name for name in inputs if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2]
    assert unused == []


def test_dynamic_dss_buffers_have_explicit_bounds_proofs() -> None:
    body = function_body(source(), "Strategy_CalculateDSS")

    assert "ArraySize(rates) < total_bars" in body
    assert "i >= ArraySize(k1)" in body
    assert "k1_start >= ArraySize(k1_smooth)" in body
    assert "i >= ArraySize(k2)" in body
    assert "dss_start >= ArraySize(dss_out)" in body
