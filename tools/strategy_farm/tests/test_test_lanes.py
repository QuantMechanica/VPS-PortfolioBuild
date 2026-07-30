from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import test_lanes  # noqa: E402


def _v2_payload() -> dict:
    payload = json.loads(test_lanes.DEFAULT_MANIFEST.read_text(encoding="utf-8"))
    payload["schema_version"] = test_lanes.SCHEMA_VERSION_V2
    payload["green_lane"] = {"policy": test_lanes.V2_GREEN_POLICY}
    payload["external_residual_lane"]["state"] = test_lanes.RESOLVED_PASS
    payload["external_residual_lane"]["policy"] = test_lanes.RESOLVED_PASS
    payload["external_residual_lane"][
        "exit_condition"
    ] = test_lanes.RESOLVED_EXIT_CONDITION
    return payload


def _write_payload(path: Path, payload: dict) -> Path:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path


def test_manifest_binds_exact_five_existing_residual_tests() -> None:
    manifest = test_lanes.load_manifest()

    assert test_lanes.DEFAULT_MANIFEST.name == "test_lanes.v1.json"
    assert manifest.schema_version == test_lanes.SCHEMA_VERSION
    assert manifest.green_policy == test_lanes.V1_GREEN_POLICY
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


def test_v2_green_runs_all_including_resolved_external_regressions(
    tmp_path: Path,
) -> None:
    manifest = test_lanes.load_manifest(
        _write_payload(tmp_path / "resolved-v2.json", _v2_payload())
    )
    command = test_lanes.pytest_command("green", manifest)

    assert manifest.schema_version == test_lanes.SCHEMA_VERSION_V2
    assert manifest.green_policy == test_lanes.V2_GREEN_POLICY
    assert manifest.external_state == test_lanes.RESOLVED_PASS
    assert manifest.external_policy == test_lanes.RESOLVED_PASS
    assert manifest.residual_node_ids == test_lanes.SENTINEL_NODE_IDS
    assert command[:4] == [sys.executable, "-m", "pytest", "-q"]
    assert tuple(command[4:]) == manifest.suite_roots
    assert "--deselect" not in command
    assert not any(node_id in command for node_id in manifest.residual_node_ids)
    with pytest.raises(test_lanes.TestLaneError, match="must not accept --deselect"):
        test_lanes.pytest_command(
            "green",
            manifest,
            extra_args=("--deselect", manifest.residual_node_ids[0]),
        )


def test_v2_targeted_external_residual_lane_stays_exact(tmp_path: Path) -> None:
    manifest = test_lanes.load_manifest(
        _write_payload(tmp_path / "resolved-v2.json", _v2_payload())
    )
    command = test_lanes.pytest_command("external-residual", manifest)

    assert tuple(command[4:]) == test_lanes.SENTINEL_NODE_IDS
    assert not any(value in command for value in ("--deselect", "--skip", "--xfail"))


def test_v2_rejects_false_or_malformed_resolved_contracts(tmp_path: Path) -> None:
    malformed: list[tuple[str, dict, str]] = []

    false_state = _v2_payload()
    false_state["external_residual_lane"]["state"] = False
    malformed.append(("false-state", false_state, "state/policy"))

    false_policy = _v2_payload()
    false_policy["external_residual_lane"]["policy"] = (
        "FAIL_CLOSED_UNTIL_BOUND_EXTERNAL_STATE_IS_RECONCILED"
    )
    malformed.append(("false-policy", false_policy, "state/policy"))

    missing_state = _v2_payload()
    missing_state["external_residual_lane"].pop("state")
    malformed.append(("missing-state", missing_state, "key set"))

    false_exit = _v2_payload()
    false_exit["external_residual_lane"]["exit_condition"] = "claimed resolved"
    malformed.append(("false-exit", false_exit, "exit_condition"))

    reordered = _v2_payload()
    reordered["external_residual_lane"]["tests"][0:2] = reversed(
        reordered["external_residual_lane"]["tests"][0:2]
    )
    malformed.append(("reordered", reordered, "exact five sentinel"))

    extra_green_key = _v2_payload()
    extra_green_key["green_lane"]["residual_handling"] = "NO_DESELECT"
    malformed.append(("extra-green-key", extra_green_key, "policy/key set"))

    incomplete_roots = _v2_payload()
    incomplete_roots["suite_roots"] = ["tools/strategy_farm/tests"]
    malformed.append(("incomplete-roots", incomplete_roots, "exact suite roots"))

    non_string_schema = _v2_payload()
    non_string_schema["schema_version"] = [test_lanes.SCHEMA_VERSION_V2]
    malformed.append(("non-string-schema", non_string_schema, "unsupported"))

    for name, payload, error in malformed:
        path = _write_payload(tmp_path / f"{name}.json", payload)
        with pytest.raises(test_lanes.TestLaneError, match=error):
            test_lanes.load_manifest(path)
