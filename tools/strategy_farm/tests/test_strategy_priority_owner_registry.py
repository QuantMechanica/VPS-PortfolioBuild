from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import strategy_priority as priority


def _registry(path: Path, *, ea_id: str = "QM5_20007") -> Path:
    path.write_text(
        json.dumps(
            {
                "schema_version": "qm.owner-priority-tracks/v1",
                "policy": "EXPLICIT_OWNER_ORDERING_PRIOR_NOT_PIPELINE_EVIDENCE",
                "entries": [
                    {
                        "ea_id": ea_id,
                        "priority_track": True,
                        "asset_class": "index_metal",
                        "timeframe": "M5/M15",
                        "target_symbols": ["GDAXI.DWX", "NDX.DWX", "XAUUSD.DWX"],
                        "excluded_symbols": ["SP500.DWX"],
                        "owner_reference": "OWNER_DECISION_2026-07-31_TEST",
                        "decision_date": "2026-07-31",
                        "reason": "fixture",
                        "decision_source": {
                            "path": "decision.md",
                            "sha256": "a" * 64,
                            "commit_sha": "b" * 40,
                        },
                    }
                ],
            }
        )
        + "\n",
        encoding="utf-8",
    )
    return path


def test_compute_scores_resolves_20007_from_owner_registry(tmp_path: Path) -> None:
    cards = tmp_path / "cards"
    cards.mkdir()
    (cards / "QM5_20007_intraday.md").write_text(
        "---\nea_id: QM5_20007\nslug: intraday-config-engine\n"
        "concepts: [opening-range-breakout]\n---\n",
        encoding="utf-8",
    )
    db = tmp_path / "farm.sqlite"
    conn = sqlite3.connect(db)
    conn.execute("CREATE TABLE work_items(ea_id TEXT, verdict TEXT)")
    conn.execute("INSERT INTO work_items VALUES('QM5_20007','PASS')")
    conn.commit()
    conn.close()
    registry = _registry(tmp_path / "owner-priority.json")

    priority._SCORE_CACHE.clear()
    row = priority.compute_scores(
        cards_dir=cards,
        db=db,
        venue_cost_model_path=tmp_path / "missing-cost.json",
        live_book_manifest_path=tmp_path / "missing-book.json",
        owner_priority_registry_path=registry,
    )["QM5_20007"]

    assert row["built"] is True
    assert row["priority_track"] is True
    assert row["priority_track_source"] == "owner_priority_registry"
    assert row["asset"] == "index_metal"
    assert row["tf"] == "M5/M15"
    assert row["owner_priority_excluded_symbols"] == ["SP500.DWX"]
    assert row["pipeline_verdict_changed"] is False
    priority._SCORE_CACHE.clear()


def test_invalid_registry_fails_closed_without_override(tmp_path: Path) -> None:
    registry = _registry(tmp_path / "owner-priority.json")
    document = json.loads(registry.read_text(encoding="utf-8"))
    document["entries"][0]["target_symbols"].append("SP500.DWX")
    registry.write_text(json.dumps(document), encoding="utf-8")

    entries, provenance = priority.load_owner_priority_registry(registry)

    assert entries == {}
    assert provenance["load_status"] == "invalid"
    assert "symbol_contract_invalid" in provenance["error"]


def test_registry_cache_token_changes_when_registry_changes(tmp_path: Path) -> None:
    registry = _registry(tmp_path / "owner-priority.json")
    first = priority._file_cache_token(registry)
    document = json.loads(registry.read_text(encoding="utf-8"))
    document["entries"][0]["reason"] = "updated"
    registry.write_text(json.dumps(document, indent=2), encoding="utf-8")
    second = priority._file_cache_token(registry)
    assert first != second
