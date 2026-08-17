from __future__ import annotations

from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SOURCES = (
    ROOT
    / "framework"
    / "EAs"
    / "QM5_21502_xau-weekly-tsmom"
    / "QM5_21502_xau-weekly-tsmom.mq5",
    ROOT
    / "framework"
    / "EAs"
    / "QM5_21505_xag-weekly-lowvol-momentum"
    / "QM5_21505_xag-weekly-lowvol-momentum.mq5",
    ROOT
    / "framework"
    / "EAs"
    / "QM5_21506_xau-weekly-trend-confirm"
    / "QM5_21506_xau-weekly-trend-confirm.mq5",
    ROOT
    / "framework"
    / "EAs"
    / "QM5_21507_qs-kama-trend-xau"
    / "QM5_21507_qs-kama-trend-xau.mq5",
    ROOT
    / "framework"
    / "EAs"
    / "QM5_21513_qs-double-seven-trend-ndx"
    / "QM5_21513_qs-double-seven-trend-ndx.mq5",
)

PREPARE_CALL = {
    "QM5_21502_xau-weekly-tsmom": "Strategy_PrepareWeeklySignal();",
    "QM5_21505_xag-weekly-lowvol-momentum": "Strategy_PrepareWeeklySignal();",
    "QM5_21506_xau-weekly-trend-confirm": "AdvanceState_OnNewBar();",
    "QM5_21507_qs-kama-trend-xau": "AdvanceState_OnNewBar();",
    "QM5_21513_qs-double-seven-trend-ndx": "AdvanceState_OnNewBar();",
}


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


def _compact(value: str) -> str:
    return "".join(value.split())


@pytest.mark.parametrize("source_path", SOURCES, ids=lambda path: path.parent.name)
def test_fresh_weekly_state_drives_close_before_same_bar_entry(
    source_path: Path,
) -> None:
    source = source_path.read_text(encoding="utf-8")
    on_tick = _compact(_function_body(source, "void OnTick()"))

    new_bar = on_tick.index("if(!QM_IsNewBar())")
    prepare = on_tick.index(PREPARE_CALL[source_path.parent.name])
    fresh_manage = on_tick.index("Strategy_ManageOpenPosition();", prepare)
    news = on_tick.index("Strategy_NewsFilterHook(broker_now)", fresh_manage)
    entry = on_tick.index("Strategy_EntrySignal(req)", news)

    assert new_bar < prepare < fresh_manage < news < entry
    assert on_tick.count("Strategy_ManageOpenPosition();") == 2


@pytest.mark.parametrize("source_path", SOURCES, ids=lambda path: path.parent.name)
def test_entry_is_fail_closed_while_any_owned_position_remains(
    source_path: Path,
) -> None:
    source = source_path.read_text(encoding="utf-8")
    entry = _compact(
        _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")
    )

    assert "if(Strategy_HasOwnedPosition())returnfalse;" in entry
    assert "POSITION_TYPE_BUY&&g_cached_direction" not in entry
    assert "POSITION_TYPE_SELL&&g_cached_direction" not in entry


def _atomic_reverse_trace(
    *, held_direction: int, target_direction: int, close_succeeds: bool
) -> tuple[str, ...]:
    events = ["prepare_fresh_signal"]
    position_remains = held_direction != 0
    if position_remains and held_direction != target_direction:
        events.append("close_opposite")
        position_remains = not close_succeeds
    elif position_remains:
        events.append("hold_same_direction")

    if position_remains:
        events.append("block_entry")
    else:
        events.append("allow_entry")
    return tuple(events)


def test_atomic_reverse_contract_blocks_on_close_failure() -> None:
    assert _atomic_reverse_trace(
        held_direction=1, target_direction=-1, close_succeeds=False
    ) == ("prepare_fresh_signal", "close_opposite", "block_entry")
    assert _atomic_reverse_trace(
        held_direction=1, target_direction=-1, close_succeeds=True
    ) == ("prepare_fresh_signal", "close_opposite", "allow_entry")
    assert _atomic_reverse_trace(
        held_direction=1, target_direction=1, close_succeeds=True
    ) == ("prepare_fresh_signal", "hold_same_direction", "block_entry")
