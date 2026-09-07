import json
import re

from tools.strategy_farm.chart_panel_acceptance import (
    DEPENDENCIES, INCLUDE_ROOT, TOKEN_JSON, static_acceptance, token_color_mapping,
)


def test_chart_panel_static_contract():
    result = static_acceptance()
    assert result["status"] == "PASS", result
    assert all(result["checks"].values())


def test_cross_platform_tokens_cover_every_value():
    document = json.loads(TOKEN_JSON.read_text(encoding="utf-8"))
    source = (INCLUDE_ROOT / "QM_DesignTokens.mqh").read_text(encoding="utf-8")
    constants = dict(re.findall(r"^#define\s+(\w+)\s+(.+)$", source, re.M))
    assert len(token_color_mapping()) == len(document["color"]) == 24
    assert all(row["matches"] for row in token_color_mapping())
    for value in document["spacingPx"]:
        assert constants[f"QM_SPACE_{value}"] == str(value)
    for key, value in document["radiusPx"].items():
        assert constants[f"QM_RADIUS_{key.upper()}"] == str(value)
    for key, value in document["layout"]["breakpointsPx"].items():
        assert constants[f"QM_BREAKPOINT_{key.upper()}"] == str(value)
    assert constants["QM_LAYOUT_CONTENT_MAX"] == str(document["layout"]["contentMaxPx"])
    assert constants["QM_LAYOUT_TEXT_MAX_CH"] == str(document["layout"]["textMaxCh"])
    assert constants["QM_LAYOUT_NAV_HEIGHT"] == str(document["layout"]["navHeightPx"])
    assert constants["QM_FONT_WEB"] == json.dumps(document["typography"]["fontSans"])
    for key in ("display", "heading", "body"):
        assert constants[f"QM_WEIGHT_{key.upper()}"] == str(document["typography"][key + "Weight"])
    for key, constant in (("master", "QM_BRAND_MASTER"), ("module", "QM_BRAND_MODULE"),
                          ("brandLine", "QM_BRAND_LINE"), ("campaignLine", "QM_CAMPAIGN_LINE")):
        assert constants[constant] == json.dumps(document["brand"][key])
    colors = {row["constant"]: row["value"] for row in token_color_mapping()}
    for key, state in document["status"].items():
        for kind, value in state.items():
            assert colors[constants[f"QM_STATUS_{key.upper()}_{kind.upper()}"]] == value


def test_native_probe_copies_every_transitive_console_include():
    names = set(DEPENDENCIES)
    for name in DEPENDENCIES:
        text = (INCLUDE_ROOT / name).read_text(encoding="utf-8")
        for dependency in re.findall(r"#include <QM/(.+?)>", text):
            assert dependency in names, (name, dependency)


def test_performance_keeps_history_provenance_and_monotonic_cache():
    text = (INCLUDE_ROOT / "QM_ConsoleData.mqh").read_text(encoding="utf-8")
    for term in ("DEAL_MAGIC", "DEAL_POSITION_ID", "DEAL_PROFIT", "DEAL_SWAP",
                 "DEAL_COMMISSION", "DEAL_FEE", "QM_PanelPositionIdentifierOpen",
                 "closed_week", "today_net", "week_net", "GetTickCount64()"):
        assert term in text
    condition = text.split("if(!m_scanned", 1)[1].split("{", 1)[0]
    assert "QM_PANEL_REFRESH_SECONDS*1000" in condition
    assert "m_dirty" not in condition
