from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import test_lanes  # noqa: E402


def test_manifest_binds_exact_five_existing_residual_tests() -> None:
    manifest = test_lanes.load_manifest()

    assert len(manifest.residual_node_ids) == 5
    assert len(set(manifest.residual_node_ids)) == 5
    assert all(node_id.startswith("tools/strategy_farm/tests/") for node_id in manifest.residual_node_ids)
    assert "without skip, xfail" in manifest.exit_condition


def test_green_lane_deselects_only_declared_residuals() -> None:
    manifest = test_lanes.load_manifest()
    command = test_lanes.pytest_command("green", manifest)

    assert command[:4] == [sys.executable, "-m", "pytest", "-q"]
    assert all(root in command for root in manifest.suite_roots)
    deselected = [command[index + 1] for index, value in enumerate(command[:-1]) if value == "--deselect"]
    assert tuple(deselected) == manifest.residual_node_ids
    assert "--skip" not in command
    assert "--xfail" not in command


def test_residual_lane_runs_exact_nodes_without_weakening() -> None:
    manifest = test_lanes.load_manifest()
    command = test_lanes.pytest_command("external-residual", manifest)

    assert tuple(command[4:]) == manifest.residual_node_ids
    assert not any(value in command for value in ("--deselect", "--skip", "--xfail"))


def test_manifest_rejects_duplicate_keys_and_wrong_cardinality(tmp_path: Path) -> None:
    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text('{"schema_version":"a","schema_version":"b"}', encoding="utf-8")
    with pytest.raises(test_lanes.TestLaneError, match="duplicate JSON key"):
        test_lanes.load_manifest(duplicate)

    payload = json.loads(test_lanes.DEFAULT_MANIFEST.read_text(encoding="utf-8"))
    payload["external_residual_lane"]["tests"].pop()
    wrong_count = tmp_path / "wrong-count.json"
    wrong_count.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(test_lanes.TestLaneError, match="exactly five"):
        test_lanes.load_manifest(wrong_count)


def test_unknown_lane_is_rejected() -> None:
    with pytest.raises(test_lanes.TestLaneError, match="unknown test lane"):
        test_lanes.pytest_command("silent-green", test_lanes.load_manifest())
