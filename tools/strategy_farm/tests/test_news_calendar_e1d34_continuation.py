import json

from tools.strategy_farm import news_calendar_e1d34_continuation as continuation


def test_new_anchor_civil_instants_are_unique_and_offset_aware():
    keys = set()
    for currency, code, instant, kind, source, zone in continuation.NEW_ANCHORS:
        assert continuation.repair.stamp(instant).utcoffset().total_seconds() == 0
        assert source.startswith("https://")
        assert zone
        assert kind in {"rate", "nonrate"}
        keys.add((currency, code, instant))
    assert len(keys) == len(continuation.NEW_ANCHORS) == 9


def test_build_anchor_catalog_preserves_base_and_adds_sources(tmp_path):
    base = tmp_path / "base.json"
    base.write_text(json.dumps({"decision_id": continuation.DECISION, "anchors": [{
        "currency": "USD", "event_code": "fixture", "utc": "2026-01-01T00:00:00+00:00",
        "kind": "usd", "source": "fixture",
    }]}))
    output = tmp_path / "catalog.json"
    result = continuation.build_anchor_catalog(base, output)
    assert len(result["anchors"]) == 10
    assert result["publication_authorized"] is False
    assert output.is_file()


def test_taxonomy_schedule_classes_have_named_authority():
    assert continuation.OFFICIAL_SCHEDULE_CLASSES == set(continuation.OFFICIAL_FAMILY)
    assert "FOMC Member Waller Speaks" not in continuation.OFFICIAL_SCHEDULE_CLASSES
    assert "CPI m/m" in continuation.OFFICIAL_SCHEDULE_CLASSES
