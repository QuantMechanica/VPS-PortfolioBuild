from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_1408_classical-bull-flag-continuation-h1"
EA_SOURCE = REPO_ROOT / "framework" / "EAs" / EA_LABEL / f"{EA_LABEL}.mq5"
CARD = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_1408_classical-bull-flag-continuation-h1.md"
)


def source_text() -> str:
    return EA_SOURCE.read_text(encoding="utf-8")


def test_qm5_1408_passes_current_build_hardening() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, CARD)
    assert result["failures"] == []


def test_qm5_1408_implements_card_pending_lifecycle_and_pivot_gate() -> None:
    source = source_text()
    assert "req.type = QM_BUY_STOP;" in source
    assert "STRATEGY_PENDING_VALID_BARS = 8" in source
    assert 'Strategy_RemoveOurPendingOrders("per_bar_reprice")' in source
    assert 'Strategy_InvalidateSetup("eight_bar_expiry")' in source
    assert "if(ArraySize(high_pivots) < 2 || ArraySize(low_pivots) < 2)" in source
    assert "no regression/window-boundary fallback" in source
    assert "upper_intercept = flag_high" not in source
    assert "req.type = QM_BUY;" not in source


def test_qm5_1408_management_is_governed_restart_safe_and_precedes_news() -> None:
    source = source_text()
    on_tick = source[source.index("void OnTick()") : source.index("void OnTimer()")]
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_EntryNewsAllows(broker_now)"
    )
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert "QM_TM_PartialClose(" in source
    assert "QM_TM_MoveSL(" in source
    assert "QM_TM_RemovePendingOrder(" in source
    assert "CTrade " not in source
    assert "GlobalVariableSet(" in source
    assert "GlobalVariableGet(" in source
    assert "GlobalVariablesFlush();" in source
    assert "Strategy_UpperLineAtShift(1)" in source
    assert "g_active_upper_anchor_time" in source
    assert "g_restart_state_missing" in source
    assert "fail-closed exit for missing restart state" in source


def test_every_declared_strategy_input_has_an_executable_use_site() -> None:
    source = source_text()
    strategy_group = source.split('input group "Strategy"', 1)[1].split(
        "const int STRATEGY_PENDING_VALID_BARS", 1
    )[0]
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        strategy_group,
        flags=re.MULTILINE,
    )
    assert names
    missing = [
        name
        for name in names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ]
    assert missing == []
