"""Console 02 source/geometry contracts, complementary to real MT5 screenshots.

Arithmetic fixtures below exercise complete-row pagination and chart bounds.
They do not claim to execute MQL5, validate glyph pixels, or replace native QA.
"""

from collections import Counter
import math
from pathlib import Path
import re

import pytest


SOURCE = Path(__file__).resolve().parents[3] / "framework/include/QM/QM_StrategyConsoleV2.mqh"


def text():
    return SOURCE.read_text(encoding="utf-8")


def paginate(rows, budget):
    page = used = 0
    previous = ""
    result = []
    for index, (height, section) in enumerate(rows):
        heading = 18 if section and section != previous else 0
        if used and used + heading + height > budget:
            page, used, previous = page + 1, 0, ""
            heading = 18 if section else 0
        if heading + height > budget:
            heading = 0
        result.append((index, page if height <= budget else -1, used + heading, height))
        used += heading + height
        previous = section
    return result, page + 1


def overview_rows(budget, live_rows, kpi_fits):
    line = 28 if budget < 39 else 39
    rows = [(74, ""), (28, "")] if kpi_fits and budget >= 74 else [(line, "")] * 3
    rows += [(line, "LIVE")] * live_rows
    rows += [(46, "")] if budget >= 46 else [(28, ""), (28, "")]
    return rows


def test_v2_is_a_separate_public_renderer_with_no_overlay_ownership():
    source = text()
    assert "class CQMStrategyConsoleV2" in source
    for method in ("Initialize", "Ready", "Render", "OnChartEvent", "Shutdown", "Mode", "PanelRightPixels"):
        assert re.search(rf"\b{method}\s*\(", source)
    assert all(token in source for token in ("show_range=false", "show_strategy=false", "show_levels=false", "show_markers=false"))
    assert not any(token in source for token in ("OBJ_TREND", "OBJ_HLINE", "OBJ_ARROW", "ChartTimePriceToXY", "ChartXYToTimePrice", "void Overlay"))
    assert 'Rect("bg",0,0,m_width,m_height' in source
    assert 'Button("design_version"' in source
    assert '"Switch to Design 1"' in source


def test_renderer_remains_presentation_only_and_clicks_use_the_cache():
    source = text()
    forbidden = r"\b(?:OrderSend\w*|OrderCalcProfit|AccountInfo\w*|History\w*|PositionGet\w*|OrderGet\w*|SymbolInfo\w*|Strategy_\w*)\s*\("
    assert not re.search(forbidden, source)
    events = source.split("void OnChartEvent", 1)[1].split("void Render", 1)[0]
    assert "Render(m_last_snapshot)" in events
    assert "CHARTEVENT_CHART_CHANGE" in events
    assert "m_rendering" in events
    assert "MQL_TESTER" in source and "MQL_OPTIMIZATION" in source
    render = source.split("void Render", 1)[1].split("void Shutdown", 1)[0]
    assert render.count("ChartRedraw(") == 1
    assert "stable_snapshot=snapshot" in render
    cleanup = source.split("void RemoveUnused", 1)[1].split("public:", 1)[0]
    assert "StringFind(name,m_prefix)!=0" in cleanup


def test_unicode_copyright_and_measured_ellipsis_survive_sanitizing():
    source = text()
    assert "ShortToString(0x00A9)" in source
    assert "ShortToString(0x00B7)" in source
    assert "ShortToString(0x2026)" in source
    sanitizer = source.split("string DisplayText", 1)[1].split("color TextColor", 1)[0]
    assert "c>=32" in sanitizer and "c<=126" not in sanitizer
    assert "c>=127&&c<=159" in sanitizer
    original = "© QuantMechanica · EURUSD – Österreich\n\t\x7f\x85"
    cleaned = "".join(c if ord(c) >= 32 and not 127 <= ord(c) <= 159 else " " for c in original)
    assert cleaned == "© QuantMechanica · EURUSD – Österreich    "
    assert "TextGetSize" in source and "TextLogicalHeight" in source


def test_three_tabs_preserve_every_snapshot_collection():
    source = text()
    for key in ("tab_overview", "tab_checks", "tab_performance"):
        assert f'"{key}"' in source
    for collection in ("risk", "live", "gates", "performance"):
        assert f"ArraySize(snapshot.{collection})" in source
    assert "m_tab_page[3]" in source
    assert "No observations reported" in source
    assert "Enlarge chart or reduce display scale" in source
    assert "Snapshot" in source


def test_kpi_cards_only_reformat_real_producer_strings_and_fallback_when_too_wide():
    source = text()
    parts = source.split("void Parts", 1)[1].split("int KpiHeight", 1)[0]
    assert 'StringFind(value," | ")' in parts
    assert "StringToDouble" not in parts and "StringToInteger" not in parts
    fits = source.split("bool KpiFits", 1)[1].split("void Kpi", 1)[0]
    assert "TextWidth(line.label" in fits and "TextWidth(primary" in fits and "TextWidth(secondary" in fits
    build = source.split("void BuildRows", 1)[1].split("int HeadingHeight", 1)[0]
    assert "KpiHeight()<=budget" in build
    assert "KpiFits(snapshot.risk[0]" in build and "KpiFits(snapshot.risk[1]" in build
    assert "for(int i=first;i<ArraySize(snapshot.risk)" in build


def test_status_reason_next_and_alert_remain_visible_on_every_tab():
    source = text()
    state = source.split("int StateCard", 1)[1].split("void Parts", 1)[0]
    assert all(f'"{key}"' in state for key in ("state_headline", "state_reason", "state_next"))
    assert "snapshot.alert_reason" in state and "snapshot.alert_state" in state
    assert "m_tab" not in state
    assert "snapshot.environment" in source.split("int Header", 1)[1].split("int StateCard", 1)[0]


@pytest.mark.parametrize("chart", [(1178, 379), (1235, 451), (1362, 419), (1920, 1080), (300, 180)])
@pytest.mark.parametrize("dpi", [96, 120, 144, 192])
@pytest.mark.parametrize("scale", [80, 100, 125, 150])
def test_narrow_width_caps_never_expand_or_leave_the_chart(chart, dpi, scale):
    source = text()
    assert "QM_CONSOLE_FULL?384:(m_mode==QM_CONSOLE_COMPACT?336:304)" in source
    factor = dpi * scale / 9600
    available = max(0, math.floor((chart[0] - 16) / factor))
    previous = float("inf")
    for desired in (384, 336, 304):
        width = min(desired, available)
        assert 8 + round(width * factor) <= chart[0] - 8
        assert width <= previous
        previous = width


@pytest.mark.parametrize("budget", [28, 29, 38, 39, 45, 46, 73, 74, 100, 149, 166, 176, 300])
@pytest.mark.parametrize("live_rows", [0, 3, 9, 10])
@pytest.mark.parametrize("kpi_fits", [False, True])
def test_all_overview_rows_are_reachable_as_complete_pages(budget, live_rows, kpi_fits):
    rows = overview_rows(budget, live_rows, kpi_fits)
    rendered, pages = paginate(rows, budget)
    assert [row[0] for row in rendered] == list(range(len(rows)))
    for _, page, y, height in rendered:
        assert 0 <= page < pages
        assert 0 <= y and y + height <= budget
    for page in range(pages):
        same = [row for row in rendered if row[1] == page]
        assert same
        for earlier, later in zip(same, same[1:]):
            assert earlier[2] + earlier[3] <= later[2]


def test_default_checks_fit_and_off_is_not_pass_in_gate_summary():
    rendered, pages = paginate([(21, "")] * 7, 150)
    assert pages == 1 and len(rendered) == 7
    counts = Counter([0, 0, 0, 0, 0, 0, 5])
    assert counts[0] == 6 and counts[5] == 1 and counts[3] == 0
    source = text()
    summary = source.split("string GateCounts", 1)[1].split("int GateHeight", 1)[0]
    assert "int counts[8]" in summary
    assert "QM_ConsoleGateText((QM_ConsoleGateState)order[i])" in summary
    assert "counts[order[i]]>0" in summary


def test_short_native_flat_overview_is_one_page_without_a_gate_counts_row():
    # Actual 1187 x 380, 96-DPI / 100% native screenshot: body budget 150.
    rows = overview_rows(150, live_rows=0, kpi_fits=True)
    rendered, pages = paginate(rows, 150)
    assert pages == 1 and len(rendered) == 3
    assert sum(height for height, _ in rows) == 148
    source = text()
    build = source.split("void BuildRows", 1)[1].split("int HeadingHeight", 1)[0]
    assert "AddRow(4," not in build and "GateCounts(" not in build
    footer = source.split("void Footer", 1)[1].split("void RemoveUnused", 1)[0]
    assert 'Label("gate_counts"' in footer and "GateCounts(snapshot)" in footer
    assert "copyright_width+12" in footer and "Logical(TextWidth(Copyright(),9))+3" in footer
    assert '"EA v"+snapshot.version' in footer
    tabs = source.split("void Tabs", 1)[1].split("void Footer", 1)[0]
    assert 'i==1?"; "+GateCounts(snapshot)' in tabs


@pytest.mark.parametrize("text_height,bold_height", [(15, 15), (16, 17), (18, 18), (20, 19)])
def test_compact_gate_chip_and_glyphs_stay_inside_each_measured_row(text_height, bold_height):
    height = max(21, max(text_height, bold_height) + 6)
    chip_height = max(19, bold_height + 4)
    assert 3 + text_height <= height
    assert 1 + chip_height <= height
    assert 3 + bold_height <= 1 + chip_height
    source = text()
    gate = source.split("int GateSingleHeight", 1)[1].split("int SummaryHeight", 1)[0]
    assert "MathMax(21,MathMax(TextLogicalHeight(9),TextLogicalHeight(9,true))+6)" in gate
    assert 'x+width-chip,y+1,chip,chip_height' in gate
    assert 'x+width-chip+3,y+3,chip-6' in gate


@pytest.mark.parametrize("budget", [28, 39, 100, 149, 176])
def test_all_eleven_performance_metrics_remain_accessible(budget):
    heights = [28 if budget < 39 or i % 3 == 0 else 39 for i in range(11)]
    rendered, pages = paginate([(height, "") for height in heights], budget)
    assert len(rendered) == 11
    assert all(0 <= page < pages and y + height <= budget for _, page, y, height in rendered)
