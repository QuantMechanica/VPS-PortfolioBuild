from pathlib import Path
import re


EA = Path(__file__).parents[1] / "QM5_9940_ff-ha-ma-fractal-h1.mq5"


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\b(?:bool|int|void)\s+{name}\s*\([^)]*\)\s*\{{", source)
    assert match, f"missing function: {name}"
    start = match.end()
    depth = 1
    cursor = start
    while cursor < len(source) and depth:
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
        cursor += 1
    assert depth == 0, f"unterminated function: {name}"
    return source[start : cursor - 1]


def test_ha_reconstruction_is_closed_bar_cached() -> None:
    source = EA.read_text(encoding="utf-8-sig")
    refresh = function_body(source, "Strategy_RefreshHACache")
    color = function_body(source, "Strategy_HAColor")

    assert "iTime(_Symbol, PERIOD_H1, 1)" in refresh
    assert "closed_bar == g_ha_cache_closed_bar" in refresh
    assert refresh.count("Strategy_ComputeHASmoothed(") == 1
    assert "Strategy_RefreshHACache()" in color
    assert "Strategy_ComputeHASmoothed(" not in color


def test_tick_management_checks_exposure_before_reading_ha() -> None:
    source = EA.read_text(encoding="utf-8-sig")
    manage = function_body(source, "Strategy_ManageOpenPosition")
    exit_signal = function_body(source, "Strategy_ExitSignal")

    assert manage.index("Strategy_HasOurPendingOrder()") < manage.index("Strategy_HAColor(1)")
    assert exit_signal.index("Strategy_SelectOurPosition") < exit_signal.index("Strategy_HAColor(1)")
