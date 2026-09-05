from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_current_pool_cost_snapshot as snapshot
from tools.strategy_farm.portfolio import ftmo_daily_net_export as daily


ARTIFACT = Path("docs/ops/evidence/2026-09-05_ftmo_current_pool_cost_snapshot.json")


def test_dated_snapshot_validates_and_projection_is_reproducible() -> None:
    value = snapshot.load(ARTIFACT)
    assert snapshot.project(value) == value["projection"]


def test_validator_rejects_unit_drift() -> None:
    value = snapshot.load(ARTIFACT)
    broken = copy.deepcopy(value)
    broken["symbols"][0]["normalized"]["commission_round_trip"]["unit"] = "USD_PER_SIDE"
    with pytest.raises(snapshot.SnapshotError, match="commission unit/type mismatch"):
        snapshot.validate(broken)


def test_loader_rejects_non_finite_json(tmp_path: Path) -> None:
    target = tmp_path / "nan.json"
    target.write_text('{"x": NaN}', encoding="utf-8")
    with pytest.raises(snapshot.SnapshotError, match="non-finite JSON constant"):
        snapshot.load(target)


def test_daily_consumer_unwraps_root_and_accepts_flat_round_trip_commission() -> None:
    digest = hashlib.sha256(ARTIFACT.read_bytes()).hexdigest()
    term, actual = daily._cost_term(ARTIFACT, ftmo_code="EUR/USD", expected_sha256=digest)
    assert actual == digest
    assert term["commissionType"] == "flat_USD"
    assert term["commission"] == 5
    assert term["tripleWeekday"] == 2


def test_duplicate_json_keys_are_rejected(tmp_path: Path) -> None:
    target = tmp_path / "duplicate.json"
    target.write_text('{"schema": "a", "schema": "b"}', encoding="utf-8")
    with pytest.raises(snapshot.SnapshotError, match="duplicate JSON key"):
        snapshot.load(target)
