from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import shadow_search_world_census as census


def _payload() -> dict:
    return census.build_payload(
        [
            {"ea_id": "QM5_2", "symbol": "XAUUSD.DWX"},
            {"ea_id": "QM5_1", "symbol": "EURUSD.DWX"},
            {"ea_id": "QM5_1", "symbol": "GBPUSD.DWX"},
        ],
        generated_at_utc="2026-08-24T10:00:00+00:00",
        database_path="fixture.sqlite",
        database_observation={
            "work_item_count": 10,
            "query_only": True,
            "snapshot_transaction": True,
        },
    )


def test_census_is_sorted_unique_hashed_and_loadable(tmp_path: Path) -> None:
    payload = _payload()
    assert payload["pair_count"] == 3
    assert payload["pairs"] == [
        {"ea_id": "QM5_1", "symbol": "EURUSD.DWX"},
        {"ea_id": "QM5_1", "symbol": "GBPUSD.DWX"},
        {"ea_id": "QM5_2", "symbol": "XAUUSD.DWX"},
    ]
    assert len(payload["pairs_sha256"]) == 64
    census.validate_payload(payload)

    path = tmp_path / "search-world.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    loaded = census.load_census(path)
    assert loaded["pair_count"] == 3
    assert loaded["census_path"] == str(path.resolve())
    assert len(loaded["census_sha256"]) == 64


def test_census_refuses_tampering_duplicates_and_reordering() -> None:
    payload = _payload()
    payload["pairs"][0]["symbol"] = "TAMPERED.DWX"
    with pytest.raises(census.SearchWorldCensusError, match="canonically sorted|hash mismatch"):
        census.validate_payload(payload)

    payload = _payload()
    payload["pairs"].reverse()
    with pytest.raises(census.SearchWorldCensusError, match="canonically sorted"):
        census.validate_payload(payload)

    payload = _payload()
    payload["pairs"][1] = dict(payload["pairs"][0])
    with pytest.raises(census.SearchWorldCensusError, match="duplicate"):
        census.validate_payload(payload)


def test_schema_document_parses() -> None:
    schema = Path(census.__file__).resolve().parent / "config" / (
        "shadow_null_search_world_census.v1.schema.json"
    )
    payload = json.loads(schema.read_text(encoding="utf-8"))
    assert payload["properties"]["schema"]["const"] == census.SCHEMA
