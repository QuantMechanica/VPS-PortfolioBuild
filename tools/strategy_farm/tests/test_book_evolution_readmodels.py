"""Tests for the Continuous Book Evolution read-model loader + headline builder.

OWNER-DEC-CBE-20260915: the Morning Briefing and Heartbeat surfaces read a set
of read-model JSON files and degrade gracefully to ``EVIDENCE_MISSING`` when a
file is absent/unreadable, never inventing values.
"""
from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import book_evolution_readmodels as be


def _write(state_dir: Path, name: str, payload: dict) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / be.READ_MODELS[name]).write_text(
        json.dumps(payload), encoding="utf-8"
    )


def test_absent_read_models_degrade_to_evidence_missing(tmp_path: Path) -> None:
    head = be.book_evolution_headline(tmp_path)
    for facet in ("dxz", "ftmo", "research", "factory"):
        assert head[facet]["available"] is False
        assert be.MISSING in head[facet]["text"]
        assert head[facet]["detail"] == be.MISSING
    assert be.headline_lines(tmp_path) == [
        "DXZ: EVIDENCE_MISSING",
        "FTMO: EVIDENCE_MISSING",
        "Research: EVIDENCE_MISSING",
        "Factory: EVIDENCE_MISSING",
    ]


def test_unreadable_read_model_is_not_an_error(tmp_path: Path) -> None:
    # Invalid JSON and a non-object top level both resolve to None (no traceback).
    (tmp_path / be.READ_MODELS["dxz"]).write_text("{not json", encoding="utf-8")
    (tmp_path / be.READ_MODELS["research"]).write_text("[]", encoding="utf-8")
    assert be.load_read_model("dxz", tmp_path) is None
    assert be.load_read_model("research", tmp_path) is None
    head = be.book_evolution_headline(tmp_path)
    assert head["dxz"]["available"] is False
    assert head["research"]["available"] is False


def test_headline_reads_all_four_facets_from_fixtures(tmp_path: Path) -> None:
    _write(tmp_path, "dxz", {
        "incumbent": {"sleeve_count": 24},
        "proposal": {"outcome": "REPLACE_SLEEVE"},
        "next_recomposition_utc": "2026-09-20T10:00:00+00:00",
    })
    _write(tmp_path, "ftmo_readiness", {
        "recommendation": "CONTINUE_DEMO",
        "demo_cycle": {"validation_days": 7},
    })
    _write(tmp_path, "research", {
        "kimi_campaigns": [
            {"status": "active"}, {"status": "sealed"}, {"status": "running"},
        ],
        "programmes": [{"status": "active"}, {"status": "paused"}],
    })
    _write(tmp_path, "factory", {
        "bottlenecks": [{"name": "Q08 claim starvation"}, {"name": "disk"}],
    })

    head = be.book_evolution_headline(tmp_path)

    assert head["dxz"]["sleeve_count"] == 24
    assert head["dxz"]["proposal_outcome"] == "REPLACE_SLEEVE"
    assert "REPLACE_SLEEVE" in head["dxz"]["text"]
    assert head["ftmo"]["recommendation"] == "CONTINUE_DEMO"
    assert head["ftmo"]["validation_days"] == 7
    assert head["research"]["active_campaigns"] == 2  # active + running, not sealed
    assert head["research"]["active_programmes"] == 1
    assert head["factory"]["top_bottleneck"] == "Q08 claim starvation"
    # detail omits the "<Facet>: " prefix that text carries.
    assert head["dxz"]["text"] == "DXZ: " + head["dxz"]["detail"]


def test_ftmo_falls_back_to_book_model_when_readiness_absent(tmp_path: Path) -> None:
    _write(tmp_path, "ftmo_book", {
        "venue": "ftmo",
        "proposal": {"outcome": "PLACE_ON_PROBATION"},
        "demo_cycle": {"validation_days": 3},
    })
    head = be.book_evolution_headline(tmp_path)
    assert head["ftmo"]["recommendation"] == "PLACE_ON_PROBATION"
    assert head["ftmo"]["validation_days"] == 3
