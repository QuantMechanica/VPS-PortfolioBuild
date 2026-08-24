from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_1416_classical-bear-flag-continuation-h1"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
SOURCE_PATH = EA_DIR / f"{EA_LABEL}.mq5"
SETS_DIR = EA_DIR / "sets"


def source_text() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def function_body(source: str, function_name: str) -> str:
    match = re.search(
        rf"\b{re.escape(function_name)}\s*\([^)]*\)\s*\{{(?P<body>.*?)\n\}}",
        source,
        flags=re.DOTALL,
    )
    assert match is not None, function_name
    return match.group("body")


def test_qm5_1416_hardening_gate_is_clean() -> None:
    result = hardening.analyze(REPO_ROOT, EA_LABEL)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_qm5_1416_uses_card_pending_order_geometry_and_lifecycle() -> None:
    source = source_text()

    assert "req.type = QM_SELL_STOP;" in source
    assert "req.type = QM_SELL;" not in source
    assert "req.expiration_seconds = strategy_pending_valid_bars * PeriodSeconds(strategy_tf);" in source
    assert "entry_price >= bid" in source
    assert "Strategy_SelectOurPendingSellStop" in source
    assert "trade.OrderDelete(ticket)" in source
    assert "required_flag_origin" in source
    assert "g_active_flag_bars_at_setup + bars_since_setup > strategy_flag_max_bars" in source
    assert "gate_revalidation_failed" in source

    # Gate 6 must reject missing pivots; flag-wide extrema/regression are not
    # authorized substitutes for two highs plus two lows.
    assert "if(ArraySize(highs) < 2 || ArraySize(lows) < 2)" in source
    assert "Use flag boundary regressions" not in source
    assert "upper_intercept = flag_high" not in source
    assert "lower_intercept = flag_low" not in source


def test_qm5_1416_news_is_exact_and_does_not_block_management() -> None:
    source = source_text()
    entry = function_body(source, "Strategy_EntrySignal")
    on_tick = function_body(source, "OnTick")

    assert 'QM_NewsInWindow(TimeGMT(), _Symbol, 180, 180, "HIGH")' in entry
    assert "QM_NEWS_TEMPORAL_OFF" in source
    assert "QM_NEWS_COMPLIANCE_NONE" in source
    assert "QM_NewsAllowsTrade" not in on_tick
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "QM_IsNewBar(_Symbol, strategy_tf)"
    )


def test_qm5_1416_restart_state_is_durable_and_fail_closed() -> None:
    source = source_text()

    for token in (
        "GlobalVariableSet",
        "GlobalVariableGet",
        'Strategy_WriteStateValue("commit", generation)',
        "Strategy_RestoreState()",
        "Strategy_ReconstructPositionFailClosed",
        "g_active_lower_at_setup",
        "g_active_lower_slope",
        "g_active_tp1_price",
        "g_tp1_done",
        "g_state_recovery_failed",
        "fail-closed exit",
    ):
        assert token in source

    assert source.index("Strategy_RestoreState();") < source.index(
        "return INIT_SUCCEEDED;"
    )
    assert "Strategy_PersistState();" in function_body(source, "OnDeinit")


def test_qm5_1416_every_declared_input_has_an_executable_use_site() -> None:
    raw = source_text()
    code = hardening.strip_comments_preserve_lines(raw)
    input_names = re.findall(r"(?m)^\s*input\s+\S+\s+(\w+)\s*=", code)
    assert input_names

    code_without_declarations = re.sub(
        r"(?m)^\s*input\s+\S+\s+\w+\s*=.*?;\s*$", "", code
    )
    unused = [
        name
        for name in input_names
        if re.search(rf"\b{re.escape(name)}\b", code_without_declarations) is None
    ]
    assert unused == []


def test_qm5_1416_framework_corset_and_risk_setfiles() -> None:
    source = source_text()
    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkMagic()" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in function_body(source, "OnTick")
    assert "CopyBuffer(" not in source
    assert re.search(r"\biATR\s*\(", source) is None
    assert re.search(r"\biMA\s*\(", source) is None
    for line in source.splitlines():
        if "CopyRates(" in line:
            assert "// perf-allowed" in line

    setfiles = sorted(SETS_DIR.glob("*.set"))
    assert len(setfiles) == 14
    for setfile in setfiles:
        payload = setfile.read_text(encoding="utf-8")
        assert "RISK_FIXED=1000" in payload
        assert "RISK_PERCENT=0" in payload
        assert "strategy_pending_valid_bars=8" in payload

    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "1416" and row["status"] == "active"
        ]
    assert len(rows) == 14
    assert {int(row["magic"]) for row in rows} == {
        14160000 + slot for slot in range(14)
    }
