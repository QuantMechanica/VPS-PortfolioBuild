"""Tests: OBSERVE projector manifest + INFRA/strategy separation; research_env guard."""

from __future__ import annotations

import json
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import observe_projector, research_env  # noqa: E402
from _research_fixtures import build_fixture_db, build_registry_csv  # noqa: E402


def _dataset(tmp_path):
    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    out_root = tmp_path / "datasets"
    manifest = observe_projector.project(db, out_root, registry_path=registry)
    return manifest, Path(manifest["dataset_dir"])


def test_manifest_shape_and_content_addressing(tmp_path):
    manifest, dataset_dir = _dataset(tmp_path)

    assert manifest["schema"] == "qm.research-dataset/v1"
    assert manifest["dataset_id"]  # sha256 of the manifest file
    # Every emitted CSV has a sha256 and a row count.
    for name in ("gate_outcomes.csv", "ea_metrics.csv", "holds.csv", "idea_families.csv", "sources.csv"):
        assert name in manifest["sha256"], name
        assert name in manifest["row_counts"], name
        assert (dataset_dir / name).exists()
    # manifest.json on disk parses and its own sha matches dataset_id.
    on_disk = json.loads((dataset_dir / "manifest.json").read_text(encoding="utf-8"))
    assert on_disk["source_db_size_bytes"] == manifest["source_db_size_bytes"]
    assert manifest["source_db_mtime_utc"]  # snapshot note carries the mtime


def test_infra_vs_strategy_kept_apart(tmp_path):
    manifest, dataset_dir = _dataset(tmp_path)
    rows = list(__import__("csv").DictReader((dataset_dir / "gate_outcomes.csv").open(encoding="utf-8")))
    by_wid = {r["work_item_id"]: r for r in rows}

    # w3 is INFRA_FAIL -> infra taxonomy, reason_class an INFRA token, never strategy.
    assert by_wid["w3"]["verdict_taxonomy"] == "infra"
    assert by_wid["w3"]["reason_class"] == "ACTIVE_TIMEOUT"
    # w1 is a gate PASS -> strategy taxonomy.
    assert by_wid["w1"]["verdict_taxonomy"] == "strategy"
    assert by_wid["w1"]["reason_class"] == "PASS"
    # w5 MEASURED -> measurement, DISJOINT from strategy.
    assert by_wid["w5"]["verdict_taxonomy"] == "measurement"

    # The manifest's split enumerates every taxonomy -> a single disposition.
    split = manifest["verdict_taxonomy_split"]
    assert split["infra"]["disposition"] == "infra"
    assert split["strategy"]["disposition"] == "economic"
    assert split["measurement"]["disposition"] == "measurement"
    # No taxonomy is dropped silently: rows sum to the gate_outcomes row count.
    assert sum(v["rows"] for v in split.values()) == manifest["row_counts"]["gate_outcomes.csv"]


def test_idea_families_derived_from_slug(tmp_path):
    _, dataset_dir = _dataset(tmp_path)
    rows = list(__import__("csv").DictReader((dataset_dir / "idea_families.csv").open(encoding="utf-8")))
    fam = {r["ea_id"]: r["family"] for r in rows}
    assert fam["QM5_1001"] == "trend"
    assert fam["QM5_1002"] == "mean_reversion"
    assert fam["QM5_1003"] == "breakout"


def test_limit_bounds_rows(tmp_path):
    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    manifest = observe_projector.project(db, tmp_path / "ds", registry_path=registry, limit=2)
    assert manifest["row_counts"]["gate_outcomes.csv"] == 2
    assert manifest["limit"] == 2


def test_projector_is_read_only(tmp_path):
    """The DB file bytes are unchanged after projection (mode=ro + query_only)."""
    import hashlib

    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    before = hashlib.sha256(db.read_bytes()).hexdigest()
    observe_projector.project(db, tmp_path / "ds", registry_path=registry)
    after = hashlib.sha256(db.read_bytes()).hexdigest()
    assert before == after


# --- research_env guard ------------------------------------------------------


def test_guard_allows_when_clear(tmp_path):
    result = research_env.research_guard(
        cpu_percent=10.0, disk_free_gb=200.0, free_ram_gb=40.0, lock_status="absent"
    )
    assert result.allowed
    assert result.reasons == []
    assert result.max_worker_processes == 2


def test_guard_refuses_high_cpu():
    result = research_env.research_guard(
        cpu_percent=99.0, disk_free_gb=200.0, free_ram_gb=40.0, lock_status="absent"
    )
    assert not result.allowed
    assert any(r.startswith("CPU_HIGH") for r in result.reasons)
    # The CPU line is READ from the worker constant, never redefined.
    assert result.measurements["cpu_high_pause_percent"] == research_env.CPU_HIGH_PAUSE_PERCENT


def test_guard_refuses_low_disk():
    result = research_env.research_guard(
        cpu_percent=10.0, disk_free_gb=10.0, free_ram_gb=40.0, lock_status="absent"
    )
    assert not result.allowed
    assert any(r.startswith("DISK_LOW") for r in result.reasons)


def test_guard_refuses_live_mutation_lock():
    result = research_env.research_guard(
        cpu_percent=10.0, disk_free_gb=200.0, free_ram_gb=40.0, lock_status="live"
    )
    assert not result.allowed
    assert any(r.startswith("MUTATION_LOCK_LIVE") for r in result.reasons)


def test_guard_disk_floor_is_80gb():
    assert research_env.RESEARCH_DISK_MIN_FREE_GB == 80.0
