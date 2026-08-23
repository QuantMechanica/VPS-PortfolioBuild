"""Contract tests for the standalone public EA showcase renderer."""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import public_ea_showcase as showcase  # noqa: E402


def _projection(*, include_live: bool = True) -> dict:
    evidence = [
        {
            "evidence_id": "rpt_0000000000000001",
            "kind": "GATE_EVIDENCE",
            "label": "Validation gates",
            "summary": "The published record shows Q04, Q08, and Q11 as passed.",
        },
        {
            "evidence_id": "rpt_0000000000000002",
            "kind": "OUT_OF_SAMPLE",
            "label": "Independent window",
            "summary": "The sealed comparison covers 2024-01-01 through 2025-12-31.",
        },
        {
            "evidence_id": "rpt_0000000000000003",
            "kind": "COST_MODEL",
            "label": "Venue cost model",
            "summary": "The backtest includes 7.5 basis points of documented round-trip costs.",
        },
        {
            "evidence_id": "rpt_0000000000000004",
            "kind": "DRAWDOWN",
            "label": "Drawdown evidence",
            "summary": "Maximum observed drawdown in the cited test was 4.8 percent.",
        },
        {
            "evidence_id": "rpt_0000000000000005",
            "kind": "BACKTEST_RECORD",
            "label": "Frozen backtest dossier",
            "summary": "The cited backtest contains 318 trades and a 1.27 profit factor.",
        },
    ]
    tracks = [
        {
            "evidence_id": "rpt_0000000000000005",
            "kind": "BACKTEST",
            "label": "Frozen independent backtest",
            "period_label": "January 2024 to December 2025",
            "summary": "Backtest only: 318 trades with a 1.27 profit factor.",
        }
    ]
    if include_live:
        evidence.append(
            {
                "evidence_id": "rpt_0000000000000006",
                "kind": "LIVE_RECORD",
                "label": "Published live record",
                "summary": "The cited real-account record contains 41 closed trades.",
            }
        )
        tracks.append(
            {
                "evidence_id": "rpt_0000000000000006",
                "kind": "LIVE",
                "label": "Real-account observation",
                "period_label": "April 2026 to August 2026",
                "summary": "Live record: 41 closed trades, reported separately from backtest.",
            }
        )
    return {
        "schema": showcase.PROJECTION_SCHEMA,
        "generated_at": "2026-08-23T20:00:00Z",
        "items": [
            {
                "public_id": "card_0123456789abcdef",
                "slug": "trend-and-carry",
                "title": "Trend & Carry",
                "eligibility": {
                    "in_live_book": True,
                    "traded_live": True,
                    "marketplace_candidate": True,
                    "product_ea_ready": True,
                    "rights_status": "CLEARED",
                },
                "thesis": "Persistent repricing can continue when participation and direction reinforce each other.",
                "risk_profile": "The strategy accepts false starts and is vulnerable to abrupt reversals after crowded trends.",
                "behavior": "It tends to wait through quiet markets and participate when directional movement becomes broad.",
                "failure_modes": [
                    "It can lose repeatedly in directionless markets.",
                    "Sudden reversals can erase open trend profit.",
                ],
                "evidence_chain": evidence,
                "track_records": tracks,
                "mql5_listing_url": "https://www.mql5.com/en/market/product/123456",
            }
        ],
    }


def test_valid_projection_renders_separate_backtest_and_live_sections(tmp_path):
    result = showcase.render_projection(_projection(), tmp_path)
    target = Path(result["render_dir"])
    page = (target / "trend-and-carry.html").read_text(encoding="utf-8")
    assert "BACKTEST — NOT LIVE" in page
    assert "LIVE — REAL ACCOUNT RECORD" in page
    assert page.index("<h2>Backtest record</h2>") < page.index("<h2>Live track record</h2>")
    assert "Trend &amp; Carry" in page
    assert "QM5_" not in page
    assert result["pages"] == 1


def test_live_record_is_optional_but_never_faked_from_backtest(tmp_path):
    result = showcase.render_projection(_projection(include_live=False), tmp_path)
    page = (Path(result["render_dir"]) / "trend-and-carry.html").read_text(
        encoding="utf-8"
    )
    assert "BACKTEST — NOT LIVE" in page
    assert "No public live track record is attached" in page
    assert "LIVE — REAL ACCOUNT RECORD" not in page


def test_empty_projection_is_valid_current_blocked_state(tmp_path):
    projection = {
        "schema": showcase.PROJECTION_SCHEMA,
        "generated_at": "2026-08-23T20:00:00Z",
        "items": [],
    }
    result = showcase.render_projection(projection, tmp_path)
    index = (Path(result["render_dir"]) / "index.html").read_text(encoding="utf-8")
    assert result["pages"] == 0
    assert "No EA currently satisfies all publication gates" in index


@pytest.mark.parametrize(
    "field,value",
    [
        ("in_live_book", False),
        ("traded_live", False),
        ("marketplace_candidate", False),
        ("product_ea_ready", False),
        ("rights_status", "PENDING"),
    ],
)
def test_any_missing_publication_gate_refuses_page(field, value):
    projection = _projection()
    projection["items"][0]["eligibility"][field] = value
    with pytest.raises(showcase.ShowcaseContractError, match=field):
        showcase.validate_projection(projection)


def test_unknown_internal_rule_field_is_refused_not_filtered():
    projection = _projection()
    projection["items"][0]["entry_rules"] = ["private mechanics"]
    with pytest.raises(showcase.ShowcaseContractError, match="non-public fields"):
        showcase.validate_projection(projection)


@pytest.mark.parametrize(
    "field,value,match",
    [
        ("thesis", r"Details live at C:\QM\repo\private.md", "private locator"),
        ("thesis", "Internal QM5_12000 candidate has an edge.", "internal identifier"),
        ("behavior", "See 123e4567-e89b-12d3-a456-426614174000.", "internal identifier"),
        ("risk_profile", "The P5 result is robust.", "legacy operator phase"),
        ("thesis", "The result makes 12 percent each year.", "unevidenced numeric"),
        ("behavior", "Entry when price exceeds SMA(20).", "build-manual syntax"),
    ],
)
def test_private_or_build_manual_copy_is_refused(field, value, match):
    projection = _projection()
    projection["items"][0][field] = value
    with pytest.raises(showcase.ShowcaseContractError, match=match):
        showcase.validate_projection(projection)


def test_missing_evidence_class_refuses_page():
    projection = _projection()
    projection["items"][0]["evidence_chain"] = [
        row
        for row in projection["items"][0]["evidence_chain"]
        if row["kind"] != "DRAWDOWN"
    ]
    with pytest.raises(showcase.ShowcaseContractError, match="DRAWDOWN"):
        showcase.validate_projection(projection)


def test_track_record_must_bind_to_matching_published_evidence():
    projection = _projection()
    projection["items"][0]["track_records"][0]["evidence_id"] = (
        "rpt_0000000000000004"
    )
    with pytest.raises(showcase.ShowcaseContractError, match="bound to DRAWDOWN"):
        showcase.validate_projection(projection)


def test_mixed_track_record_is_refused():
    projection = _projection()
    projection["items"][0]["track_records"][0]["kind"] = "MIXED"
    with pytest.raises(showcase.ShowcaseContractError, match="BACKTEST or LIVE"):
        showcase.validate_projection(projection)


@pytest.mark.parametrize(
    "url",
    [
        "http://www.mql5.com/en/market/product/123",
        "https://example.com/en/market/product/123",
        "https://www.mql5.com/en/market/product/123?internal=1",
        "https://www.mql5.com/en/articles/123",
    ],
)
def test_only_clean_official_mql5_product_links_are_allowed(url):
    projection = _projection()
    projection["items"][0]["mql5_listing_url"] = url
    with pytest.raises(showcase.ShowcaseContractError, match="official MQL5"):
        showcase.validate_projection(projection)


def test_mql5_link_is_optional_until_listing_exists(tmp_path):
    projection = _projection()
    del projection["items"][0]["mql5_listing_url"]
    result = showcase.render_projection(projection, tmp_path)
    page = (Path(result["render_dir"]) / "trend-and-carry.html").read_text(
        encoding="utf-8"
    )
    assert "MQL5 listing pending" in page
    manifest = json.loads(
        (Path(result["render_dir"]) / "manifest.json").read_text(encoding="utf-8")
    )
    assert manifest["pages"][0]["has_mql5_listing"] is False


def test_renderer_refuses_live_public_data_target():
    with pytest.raises(showcase.ShowcaseContractError, match="staging-only"):
        showcase.render_projection(_projection(), REPO / "public-data" / "showcase")


def test_render_id_is_deterministic(tmp_path):
    first = showcase.render_projection(_projection(), tmp_path / "a")
    second = showcase.render_projection(copy.deepcopy(_projection()), tmp_path / "b")
    assert first["render_id"] == second["render_id"]
