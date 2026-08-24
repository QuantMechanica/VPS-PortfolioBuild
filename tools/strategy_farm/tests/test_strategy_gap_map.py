from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import strategy_gap_map as gap


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _booklab(path: Path) -> Path:
    payload = {
        "schema": "qm.q15-shadow-booklab/v1",
        "classification": {
            "rows": [{
                "sleeve": "QM5_910001_EURUSD_1",
                "ea_id": "QM5_910001",
                "ea_id_int": 910001,
                "symbol": "EURUSD.DWX",
                "asset_class": "fx",
                "timeframe": "H1",
                "family": "breakout",
            }]
        },
        "research_counterfactuals": {
            "train_inverse_volatility": {
                "concentration": {
                    "weights": [{"sleeve": "QM5_910001_EURUSD_1", "weight": 1.0}]
                },
                "group_exposure": {},
            }
        },
        "correlation": {"worst_15_stress_pairs": []},
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def _card(path: Path, ea_id: int, slug: str, symbol: str, period: str, concept: str) -> None:
    path.write_text(
        "---\n"
        f"ea_id: QM5_{ea_id}\n"
        f"slug: {slug}\n"
        "g0_status: APPROVED\n"
        f"target_symbols: [{symbol}]\n"
        f"period: {period}\n"
        f"concepts: ['[[concepts/{concept}]]']\n"
        "---\n# Fixture\n",
        encoding="utf-8",
    )


def _db(path: Path) -> Path:
    connection = sqlite3.connect(path)
    connection.execute(
        "CREATE TABLE work_items(id TEXT,phase TEXT,ea_id TEXT,symbol TEXT,status TEXT,verdict TEXT,gate_contract_version TEXT)"
    )
    for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07"):
        connection.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
            (f"row-{phase}", phase, "QM5_920001", "XTIUSD.DWX", "done", "PASS", "v4"),
        )
    connection.commit()
    connection.close()
    return path


def _registry(path: Path) -> Path:
    path.write_text(
        "ea_id,slug,strategy_id,status,owner,created_at,retired_at,retired_reason,retired_evidence\n"
        "910001,reference-breakout,s1,active,Development,2026-01-01,,,\n"
        "920001,energy-trend,s2,active,Development,2026-01-01,,,\n",
        encoding="utf-8",
    )
    return path


def test_gap_map_is_read_only_and_surfaces_absent_assets(tmp_path: Path) -> None:
    cards = tmp_path / "cards"
    cards.mkdir()
    _card(cards / "energy.md", 920001, "energy-tsmom", "XTIUSD.DWX", "D1", "trend-following")
    _card(cards / "relative.md", 920002, "fx-cointeg-pair", "EURGBP.DWX", "H4", "cointegration")
    db = _db(tmp_path / "farm.sqlite")
    before = _sha(db)

    report = gap.build_gap_map(
        booklab_path=_booklab(tmp_path / "booklab.json"),
        db_path=db,
        cards_dir=cards,
        registry_path=_registry(tmp_path / "registry.csv"),
    )

    assert _sha(db) == before
    assert report["sources"]["pipeline"]["query_only"] == 1
    assert report["queue_rows_changed"] == 0
    assert report["strategy_cards_created_by_run"] == 0
    assert report["strategy_cards_approved_by_run"] == 0
    assert report["diagnosis"]["recommendation_is_queue_or_card_action"] is False
    energy = next(row for row in report["dimension_gaps"]["asset_class"] if row["key"] == "energy")
    assert energy["coverage_state"] == "ABSENT"
    assert energy["approved_supply_at_or_beyond_q07"] == 1
    assert report["top_whitespace"][0]["reference_roster_sleeves"] == 0


def test_archetype_classifier_prefers_relative_value_before_reversal() -> None:
    assert gap.classify_archetype("oil-gold-spread-reversal") == "relative_value"
    assert gap.classify_archetype("fomc-breakout") == "event_driven"


def test_invalid_unrelated_yaml_quote_uses_relevant_field_fallback(tmp_path: Path) -> None:
    card_path = tmp_path / "card.md"
    card_path.write_text(
        "---\n"
        "ea_id: QM5_930001\n"
        "slug: energy-breakout\n"
        "g0_status: APPROVED\n"
        "target_symbols: [XTIUSD.DWX]\n"
        "period: H1\n"
        "concepts:\n  - '[[concepts/momentum-breakout]]'\n"
        'source_citation: "local C:\\Users\\broken"\n'
        "---\n# Card\n",
        encoding="utf-8",
    )

    parsed = gap._frontmatter(card_path)

    assert parsed["__gap_parser_mode__"] == "RELEVANT_FLAT_FIELDS_FALLBACK"
    assert parsed["ea_id"] == "QM5_930001"
    assert parsed["target_symbols"] == ["XTIUSD.DWX"]


def test_invalid_yaml_in_relevant_field_is_not_silently_recovered(
    tmp_path: Path,
) -> None:
    card_path = tmp_path / "card.md"
    card_path.write_text(
        "---\n"
        "ea_id: QM5_930002\n"
        "slug: broken-symbols\n"
        "g0_status: APPROVED\n"
        'target_symbols: "C:\\Users\\broken"\n'
        "period: H1\n"
        "---\n# Card\n",
        encoding="utf-8",
    )

    with pytest.raises(gap.GapMapError, match="outside the recoverable"):
        gap._frontmatter(card_path)
