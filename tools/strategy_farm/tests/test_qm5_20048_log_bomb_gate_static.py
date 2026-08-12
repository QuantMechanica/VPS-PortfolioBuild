from __future__ import annotations

from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA = (
    REPO
    / "framework"
    / "EAs"
    / "QM5_20048_wti-preholiday"
    / "QM5_20048_wti-preholiday.mq5"
)


def _on_tick() -> str:
    source = EA.read_text(encoding="utf-8")
    signature = source.index("void OnTick()")
    opening = source.index("{", signature)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError("unterminated OnTick")


def test_20048_keeps_safety_tick_responsive_and_gates_news_once_per_bar() -> None:
    on_tick = _on_tick()

    kill_switch = on_tick.index("QM_KillSwitchCheck()")
    friday_close = on_tick.index("QM_FrameworkHandleFridayClose()")
    new_bar = on_tick.index("QM_IsNewBar()")
    news = on_tick.index("QM_NewsAllowsTrade2(")
    manage = on_tick.index("Strategy_ManageOpenPosition()")
    entry = on_tick.index("Strategy_EntrySignal(req)")

    assert kill_switch < friday_close < new_bar < news < manage < entry
    assert on_tick.count("QM_IsNewBar()") == 1
    assert on_tick.count("QM_NewsAllowsTrade2(") == 1


def test_20048_build_contract_remains_fail_closed_and_fixed_risk() -> None:
    source = EA.read_text(encoding="utf-8")
    compact = "".join(source.split())

    assert "inputintqm_news_stale_max_hours=336;" in compact
    assert "inputdoubleRISK_FIXED=1000.0;" in compact
    assert "inputdoubleRISK_PERCENT=0.0;" in compact
