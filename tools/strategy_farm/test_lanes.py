#!/usr/bin/env python3
"""Run the green merge lane or the explicit external-residual lane.

The five former residual checks remain ordinary tests and are never marked
skip or xfail. The resolved V2 default runs them as part of green and retains
the targeted residual command as a separately measurable sentinel lane. The
historical V1 manifest remains available for audit reproduction only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence


SCHEMA_VERSION = "qm.test-lanes/v1"
SCHEMA_VERSION_V2 = "qm.test-lanes/v2"
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = Path(__file__).resolve().parent / "config" / "test_lanes.v2.json"
V1_GREEN_POLICY = "RUN_ALL_EXCEPT_DECLARED_EXTERNAL_RESIDUALS"
V2_GREEN_POLICY = "RUN_ALL_INCLUDING_RESOLVED_EXTERNAL_REGRESSIONS"
RESOLVED_PASS = "RESOLVED_PASS"
RESOLVED_EXIT_CONDITION = (
    "All five node IDs PASS without skip, xfail, assertion weakening or silent rebinding."
)
V2_SUITE_ROOTS = (
    "tools/strategy_farm/tests",
    "framework/scripts/tests",
)
SENTINEL_NODE_IDS = (
    "tools/strategy_farm/tests/test_dxz_10939_repair_packet.py::test_real_spec_hash_bindings_pass",
    "tools/strategy_farm/tests/test_dxz_12567_xau_repair_packet.py::test_spec_is_hash_bound_blocked_and_xau_not_xng",
    "tools/strategy_farm/tests/test_execution_contract_lint.py::test_dxz23_registry_is_source_bound_and_structurally_clean",
    "tools/strategy_farm/tests/test_execution_contract_lint.py::test_density_execution_contracts_are_source_and_runtime_binding_clean",
    "tools/strategy_farm/tests/test_execution_contract_lint.py::test_20009_ftmo_news_calendar_is_exact_and_evidence_bound",
)
NODE_ID_RE = re.compile(
    r"^(?P<path>(?:tools/strategy_farm|framework/scripts)/tests/"
    r"test_[a-zA-Z0-9_]+\.py)::(?P<test>test_[a-zA-Z0-9_]+)$"
)


class TestLaneError(ValueError):
    pass


@dataclass(frozen=True)
class TestLaneManifest:
    suite_roots: tuple[str, ...]
    residual_node_ids: tuple[str, ...]
    exit_condition: str
    schema_version: str = SCHEMA_VERSION
    green_policy: str = V1_GREEN_POLICY
    external_state: str | None = None
    external_policy: str = "FAIL_CLOSED_UNTIL_BOUND_EXTERNAL_STATE_IS_RECONCILED"


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise TestLaneError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_manifest(path: Path | str = DEFAULT_MANIFEST) -> TestLaneManifest:
    manifest_path = Path(path)
    try:
        payload = json.loads(
            manifest_path.read_text(encoding="utf-8"),
            object_pairs_hook=_unique_object,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise TestLaneError(f"cannot load test-lane manifest: {exc}") from exc
    if not isinstance(payload, dict) or set(payload) != {
        "schema_version",
        "suite_roots",
        "green_lane",
        "external_residual_lane",
    }:
        raise TestLaneError("manifest root key set mismatch")
    schema_version = payload["schema_version"]
    if not isinstance(schema_version, str) or schema_version not in (
        SCHEMA_VERSION,
        SCHEMA_VERSION_V2,
    ):
        raise TestLaneError("unsupported test-lane schema")
    if schema_version == SCHEMA_VERSION:
        if payload["green_lane"] != {
            "policy": V1_GREEN_POLICY,
            "residual_handling": "DESELECT_ONLY_NEVER_SKIP_OR_XFAIL",
        }:
            raise TestLaneError("green-lane policy must remain fail-closed")
        green_policy = V1_GREEN_POLICY
    else:
        if payload["green_lane"] != {"policy": V2_GREEN_POLICY}:
            raise TestLaneError("resolved green-lane policy/key set mismatch")
        green_policy = V2_GREEN_POLICY
    roots = payload["suite_roots"]
    if not isinstance(roots, list) or not roots or any(not isinstance(v, str) for v in roots):
        raise TestLaneError("suite_roots must be a non-empty string array")
    if len(roots) != len(set(roots)):
        raise TestLaneError("suite_roots contain duplicates")
    if schema_version == SCHEMA_VERSION_V2 and tuple(roots) != V2_SUITE_ROOTS:
        raise TestLaneError("resolved manifest must preserve the exact suite roots/order")

    residual = payload["external_residual_lane"]
    expected_residual_keys = {"policy", "tests", "exit_condition"}
    if schema_version == SCHEMA_VERSION_V2:
        expected_residual_keys.add("state")
    if not isinstance(residual, dict) or set(residual) != expected_residual_keys:
        raise TestLaneError("external_residual_lane key set mismatch")
    if schema_version == SCHEMA_VERSION:
        external_state: str | None = None
        external_policy = "FAIL_CLOSED_UNTIL_BOUND_EXTERNAL_STATE_IS_RECONCILED"
        if residual["policy"] != external_policy:
            raise TestLaneError("external residual policy was weakened")
    else:
        external_state = residual["state"]
        external_policy = residual["policy"]
        if external_state != RESOLVED_PASS or external_policy != RESOLVED_PASS:
            raise TestLaneError("resolved external residual state/policy must be RESOLVED_PASS")
    rows = residual["tests"]
    if not isinstance(rows, list) or len(rows) != 5:
        raise TestLaneError("exactly five external residual node IDs are required")
    node_ids: list[str] = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != {"node_id", "owner_items"}:
            raise TestLaneError(f"residual test[{index}] key set mismatch")
        node_id = row["node_id"]
        match = NODE_ID_RE.fullmatch(node_id) if isinstance(node_id, str) else None
        if match is None:
            raise TestLaneError(f"invalid residual node ID: {node_id!r}")
        owners = row["owner_items"]
        if (
            not isinstance(owners, list)
            or not owners
            or any(re.fullmatch(r"MNT-[0-9]{3}", value or "") is None for value in owners)
        ):
            raise TestLaneError(f"residual test[{index}] has invalid owner_items")
        source_path = REPO_ROOT / match.group("path")
        if not source_path.is_file():
            raise TestLaneError(f"residual source is missing: {source_path}")
        source = source_path.read_text(encoding="utf-8")
        if re.search(rf"^def {re.escape(match.group('test'))}\s*\(", source, re.MULTILINE) is None:
            raise TestLaneError(f"residual function is missing: {node_id}")
        node_ids.append(node_id)
    if len(node_ids) != len(set(node_ids)):
        raise TestLaneError("external residual node IDs contain duplicates")
    if schema_version == SCHEMA_VERSION_V2 and tuple(node_ids) != SENTINEL_NODE_IDS:
        raise TestLaneError("resolved manifest must preserve the exact five sentinel node IDs/order")
    exit_condition = residual["exit_condition"]
    if not isinstance(exit_condition, str) or not exit_condition.strip():
        raise TestLaneError("external residual exit_condition is required")
    if schema_version == SCHEMA_VERSION_V2 and exit_condition != RESOLVED_EXIT_CONDITION:
        raise TestLaneError("resolved external residual exit_condition mismatch")
    return TestLaneManifest(
        tuple(roots),
        tuple(node_ids),
        exit_condition,
        schema_version=schema_version,
        green_policy=green_policy,
        external_state=external_state,
        external_policy=external_policy,
    )


def _validate_command_manifest(manifest: TestLaneManifest) -> None:
    if manifest.schema_version == SCHEMA_VERSION:
        if (
            manifest.green_policy != V1_GREEN_POLICY
            or manifest.external_state is not None
            or manifest.external_policy
            != "FAIL_CLOSED_UNTIL_BOUND_EXTERNAL_STATE_IS_RECONCILED"
        ):
            raise TestLaneError("V1 command manifest contract mismatch")
        return
    if manifest.schema_version == SCHEMA_VERSION_V2:
        if (
            manifest.green_policy != V2_GREEN_POLICY
            or manifest.external_state != RESOLVED_PASS
            or manifest.external_policy != RESOLVED_PASS
            or manifest.suite_roots != V2_SUITE_ROOTS
            or manifest.residual_node_ids != SENTINEL_NODE_IDS
            or manifest.exit_condition != RESOLVED_EXIT_CONDITION
        ):
            raise TestLaneError("V2 resolved command manifest contract mismatch")
        return
    raise TestLaneError("unsupported test-lane schema")


def pytest_command(
    lane: str,
    manifest: TestLaneManifest,
    *,
    collect_only: bool = False,
    extra_args: Sequence[str] = (),
) -> list[str]:
    _validate_command_manifest(manifest)
    if manifest.schema_version == SCHEMA_VERSION_V2 and extra_args:
        raise TestLaneError(
            "V2 green/residual commands must not accept free pytest arguments"
        )
    command = [sys.executable, "-m", "pytest", "-q"]
    if lane == "green":
        command.extend(manifest.suite_roots)
        if manifest.schema_version == SCHEMA_VERSION:
            if manifest.green_policy != V1_GREEN_POLICY:
                raise TestLaneError("V1 green-lane policy mismatch")
            command.extend(
                argument
                for node_id in manifest.residual_node_ids
                for argument in ("--deselect", node_id)
            )
        elif manifest.schema_version == SCHEMA_VERSION_V2:
            if (
                manifest.green_policy != V2_GREEN_POLICY
                or manifest.external_state != RESOLVED_PASS
                or manifest.external_policy != RESOLVED_PASS
            ):
                raise TestLaneError("V2 resolved green-lane contract mismatch")
    elif lane == "external-residual":
        command.extend(manifest.residual_node_ids)
    else:
        raise TestLaneError(f"unknown test lane: {lane!r}")
    if collect_only:
        command.append("--collect-only")
    command.extend(extra_args)
    return command


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane", choices=("green", "external-residual"))
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--collect-only", action="store_true")
    parser.add_argument("--print-command", action="store_true")
    args, extra = parser.parse_known_args(argv)
    try:
        manifest = load_manifest(args.manifest)
        if (
            manifest.schema_version == SCHEMA_VERSION_V2
            and os.environ.get("PYTEST_ADDOPTS", "").strip()
        ):
            raise TestLaneError("V2 commands require PYTEST_ADDOPTS to be empty")
        command = pytest_command(
            args.lane,
            manifest,
            collect_only=args.collect_only,
            extra_args=extra,
        )
    except TestLaneError as exc:
        print(json.dumps({"status": "INVALID", "error": str(exc)}), file=sys.stderr)
        return 2
    if args.print_command:
        print(json.dumps(command, ensure_ascii=False))
        return 0
    return subprocess.run(command, cwd=REPO_ROOT, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
