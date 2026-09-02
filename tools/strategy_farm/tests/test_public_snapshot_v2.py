import importlib.util
import json
import sqlite3
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]


def _load_pipeline_builder():
    path = REPO / "scripts" / "build_pipeline_state.py"
    spec = importlib.util.spec_from_file_location("pipeline_state_v2_test", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_public_work_item_count_is_read_only(tmp_path: Path, monkeypatch) -> None:
    module = _load_pipeline_builder()
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE work_items(id TEXT PRIMARY KEY)")
        conn.executemany("INSERT INTO work_items VALUES(?)", [("a",), ("b",), ("c",)])
    before = db.read_bytes()
    monkeypatch.setattr(module, "FARM_DB", db)
    assert module.count_work_items_read_only() == 3
    assert db.read_bytes() == before


def test_public_snapshot_v2_schema_retires_legacy_surface() -> None:
    schema = json.loads(
        (REPO / "public-data" / "public-snapshot.schema.v2.json").read_text()
    )
    assert schema["properties"]["schema_version"]["enum"] == [2]
    assert "t6" not in schema["required"]
    assert "t6" not in schema["properties"]
    pipeline = schema["properties"]["pipeline"]
    assert "by_phase" not in pipeline["properties"]
    assert "work_items_total" in pipeline["required"]
    assert schema["properties"]["phase"]["pattern"].startswith("^Q")


def test_exporter_emits_q_only_v2_and_redacted_stats() -> None:
    source = (REPO / "scripts" / "export_public_snapshot.ps1").read_text(
        encoding="utf-8-sig"
    )
    public_object = source[source.index("$publicSnapshot ="):source.index("$publicStats =")]
    assert "schema_version = $SchemaVersionV2" in public_object
    assert "t6 =" not in public_object
    assert "by_phase =" not in public_object
    assert 'phaseLabel = "Q00"' in source
    assert "Endausbaustufe" not in source
    stats_object = source[source.index("$publicStats ="):source.index("$publicSchemaPath")]
    assert "terminals" not in stats_object.lower()
    assert "backtests_total" in stats_object
    assert "strategy_cards" in stats_object


def test_stats_schema_refuses_infrastructure_fields() -> None:
    jsonschema = pytest.importorskip("jsonschema")
    schema = json.loads((REPO / "public-data" / "public-stats.schema.json").read_text())
    valid = {
        "schema_version": 1,
        "generated_at": "2026-09-02T14:50:00Z",
        "eas_compiled": 10,
        "strategy_cards": 9,
        "backtests_total": 8,
        "phases": 18,
        "q02_baseline_pass": 7,
        "q04_walkforward_pass": 6,
        "q08_davey_stats_pass": 5,
        "portfolio_candidates": 4,
        "archive_total": 300,
        "archive_passed_q10": 3,
        "archive_failed": 120,
        "symbols": 23,
    }
    jsonschema.validate(valid, schema)
    # research_sources is an optional key (omitted when the sources table is absent).
    jsonschema.validate(dict(valid, research_sources=100), schema)
    invalid = dict(valid, terminals=10)
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(invalid, schema)


def test_local_preview_site_has_no_hardcoded_hero_counts() -> None:
    site = Path(r"C:\QM\deploy\quantmechanica-ops\Website")
    if not site.is_dir():
        pytest.skip("local deploy preview repository is unavailable")
    index = (site / "index.html").read_text(encoding="utf-8-sig")
    hero = index[index.index('<section class="hero">'):index.index('</section>', index.index('<section class="hero">'))]
    assert 'data-stat="terminals"' not in hero
    assert 'data-stat="strategy_cards"' in hero
    assert 'data-target="4240"' not in hero
    assert 'data-target="109929"' not in hero
    loader = (site / "scripts" / "stats-loader.js").read_text(encoding="utf-8-sig")
    assert "'/public-data/stats.json'" in loader
