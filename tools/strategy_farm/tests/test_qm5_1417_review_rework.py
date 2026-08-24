from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_1417_classical-pennant-continuation-h1"
    / "QM5_1417_classical-pennant-continuation-h1.mq5"
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


def test_pivot_geometry_has_no_fabricated_fallback() -> None:
    code = source()

    assert "s_up = -0.05 * atr" not in code
    assert "s_lo = +0.05 * atr" not in code
    assert re.search(
        r"if\(ArraySize\(highs\) < 2 \|\| ArraySize\(lows\) < 2\)\s*continue;",
        code,
    )


def test_pending_stop_contract_and_acceptance_commit_are_explicit() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    on_tick = function_body(code, "OnTick")

    assert "req.type = QM_BUY_STOP;" in entry
    assert "req.type = QM_SELL_STOP;" in entry
    assert "const int STRATEGY_PENDING_VALID_BARS = 6;" in code
    assert "req.expiration_seconds = STRATEGY_PENDING_VALID_BARS * tf_seconds;" in entry
    assert "g_active_" not in entry
    assert "g_pattern_block_until =" not in entry
    assert re.search(
        r"if\(QM_TM_OpenPosition\(req, out_ticket\)\)\s*"
        r"Strategy_CommitAcceptedSetup\(out_ticket\);",
        on_tick,
    )


def test_sma_order_news_window_and_advancing_projection_match_card() -> None:
    code = source()

    assert "sma_vals[1] > sma_vals[0]" in code
    assert "sma_vals[1] < sma_vals[0]" in code
    assert "QM_NewsInWindow(utc_time, _Symbol, 180, 180, qm_news_min_impact)" in code
    assert "g_active_line_x_at_setup + (double)bars_since_setup" in code
    assert "rates[0].close < up_line && rates[0].close > dn_line" in code
    assert "rates[0].close > dn_line && rates[0].close < up_line" in code


def test_framework_contract_and_all_declared_inputs_are_wired() -> None:
    code = source()
    on_init = function_body(code, "OnInit")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkTrackOpenPositionMae();" in code
    assert "QM_FrameworkMagic()" in code
    assert "input double RISK_PERCENT               = 0.0;" in code
    assert "input double RISK_FIXED                 = 1000.0;" in code
    assert re.search(
        r"QM_FrameworkInit\([\s\S]*?\)\)\s*return INIT_FAILED;\s*"
        r"if\(!QM_FrameworkDeclareExecutionContract\(PERIOD_H1,",
        on_init,
    )

    inputs = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    assert inputs
    unused = [name for name in inputs if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2]
    assert unused == []
