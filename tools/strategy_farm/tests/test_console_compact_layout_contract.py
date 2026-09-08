"""Compact console geometry contract; native object bounds are checked separately.

These arithmetic fixtures intentionally do not claim to execute MQL5 or replace
the MT5 screenshot/census harness. They exercise page-boundary edge cases and
keep the narrow-footprint / complete-row policy explicit during later edits.
"""

import math
from pathlib import Path
import re

import pytest


RENDERER = Path(__file__).resolve().parents[3] / "framework/include/QM/QM_StrategyConsole.mqh"


def geometry(chart_width, chart_height, dpi, scale, mode):
    factor = dpi * scale / 9600
    width = max(0, min((416, 360, 320)[mode], math.floor((chart_width - 16) / factor)))
    height = max(0, min((428, 232, 132)[mode], math.floor((chart_height - 16) / factor)))
    short_header = mode == 2 or (mode == 0 and height < 300)
    # Native measured default heights at 96 DPI / 100% scale. Other DPI cases
    # below exercise outer bounds, not a claim about the native font metrics.
    state_y = 36 if short_header else 68
    state_end = state_y + min(72, height - state_y - 8)
    body_top = state_end + 27
    body_bottom = height - 35
    return width, height, body_top, body_bottom, factor


def paginate(rows, top, bottom):
    budget = max(0, bottom - top)
    page, used, previous = 0, 0, ""
    output = []
    for index, (section, height) in enumerate(rows):
        heading = 14 if section and section != previous else 0
        if used and used + heading + height > budget:
            page, used, previous = page + 1, 0, ""
            heading = 14 if section else 0
        if heading + height > budget:
            heading = 0
        assigned = page if height <= budget else -1
        output.append((index, assigned, top + used + heading, height))
        used += heading + height
        previous = section
    return output, page + 1


def test_narrow_footprint_is_the_renderer_contract():
    source = RENDERER.read_text(encoding="utf-8")
    assert "QM_CONSOLE_FULL?416:(m_mode==QM_CONSOLE_COMPACT?360:320)" in source
    assert "QM_CONSOLE_FULL?428:(m_mode==QM_CONSOLE_COMPACT?232:132)" in source
    assert "m_side_layout" not in source
    assert "TextSetFont(" in source and "TextGetSize(" in source
    assert 'S(key,OBJPROP_TOOLTIP,DisplayText(value))' in source
    assert "return budget<40?26:LineHeight(line);" in source
    assert "budget<GateHeight()?26:GateHeight()" in source


@pytest.mark.parametrize("chart", [(1362, 419), (960, 600), (1366, 768), (1920, 1080), (340, 240)])
@pytest.mark.parametrize("dpi", [96, 120, 144])
@pytest.mark.parametrize("scale", [80, 100, 125, 150])
def test_all_three_mode_backgrounds_stay_inside_chart(chart, dpi, scale):
    previous_width = float("inf")
    for mode in range(3):
        width, height, _, _, factor = geometry(*chart, dpi, scale, mode)
        assert width <= previous_width
        assert 8 + round(width * factor) <= chart[0] - 8
        assert 8 + round(height * factor) <= chart[1] - 8
        previous_width = width


@pytest.mark.parametrize("budget", [26, 27, 30, 35, 39, 40, 49, 50, 74, 118, 196, 300])
@pytest.mark.parametrize("live_rows", [0, 3, 9, 10])
def test_every_complete_row_is_reachable_without_footer_overlap(budget, live_rows):
    line_height = 26 if budget < 40 else 40
    gate_height = 26 if budget < 30 else 30
    rows = [("RISK", line_height)] * 3
    rows += [("FILTER GATE", gate_height)] * 4
    rows += [("LIVE", line_height)] * live_rows
    rows += [("", 50)] if budget >= 50 else [("TODAY / WEEK", 26)] * 2
    top, bottom = 172, 172 + budget
    rendered, pages = paginate(rows, top, bottom)
    assert pages >= 1
    assert [row[0] for row in rendered] == list(range(len(rows)))
    for _, page, y, height in rendered:
        assert 0 <= page < pages
        assert top <= y and y + height <= bottom
    for page in range(pages):
        page_rows = [row for row in rendered if row[1] == page]
        assert page_rows
        for earlier, later in zip(page_rows, page_rows[1:]):
            assert earlier[2] + earlier[3] <= later[2]


def test_status_reason_survives_modes_and_alerts_override_only_presentation():
    source = RENDERER.read_text(encoding="utf-8")
    card = source.split("int StateCard(", 1)[1].split("void AddRow", 1)[0]
    assert all('"' + key + '"' in card for key in ("state_headline", "state_reason", "state_next", "state_meta"))
    assert "snapshot.alert_reason" in card and "snapshot.alert_state" in card
    assert "m_mode" not in card
    forbidden = r"\b(?:OrderSend|OrderCalcProfit|AccountInfo\w*|History\w*|PositionGet\w*|Strategy_\w*)\s*\("
    assert not re.search(forbidden, source)
    events = source.split("void OnChartEvent", 1)[1].split("void Render", 1)[0]
    assert "Render(m_last_snapshot)" in events
    assert "CHARTEVENT_CHART_CHANGE" in events
    assert "m_rendering" in events


def test_risk_is_first_in_the_compact_overview_and_performance_is_not_discarded():
    source = RENDERER.read_text(encoding="utf-8")
    build = source.split("void BuildRows", 1)[1].split("void Paginate", 1)[0]
    assert build.index("ArraySize(snapshot.risk)") < build.index("ArraySize(snapshot.gates)")
    assert "ArraySize(snapshot.performance)" in build and "ArraySize(snapshot.live)" in build
    assert '"tab_overview"' in source and '"tab_performance"' in source
    assert all(text in source for text in ('"Buy Trigger "', '"Sell Trigger "', '"Range High "', '"Range Low "'))
