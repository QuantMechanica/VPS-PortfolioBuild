#!/usr/bin/env python3
"""Run the green merge lane or the explicit external-residual lane.

The five residual checks remain ordinary failing tests. They are never marked
skip or xfail; the green command deselects only the exact versioned node IDs,
while the residual command executes those IDs directly.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence


SCHEMA_VERSION = "qm.test-lanes/v1"
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = Path(__file__).resolve().parent / "config" / "test_lanes.v1.json"
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
    if payload["schema_version"] != SCHEMA_VERSION:
        raise TestLaneError("unsupported test-lane schema")
    if payload["green_lane"] != {
        "policy": "RUN_ALL_EXCEPT_DECLARED_EXTERNAL_RESIDUALS",
        "residual_handling": "DESELECT_ONLY_NEVER_SKIP_OR_XFAIL",
    }:
        raise TestLaneError("green-lane policy must remain fail-closed")
    roots = payload["suite_roots"]
    if not isinstance(roots, list) or not roots or any(not isinstance(v, str) for v in roots):
        raise TestLaneError("suite_roots must be a non-empty string array")
    if len(roots) != len(set(roots)):
        raise TestLaneError("suite_roots contain duplicates")

    residual = payload["external_residual_lane"]
    if not isinstance(residual, dict) or set(residual) != {
        "policy",
        "tests",
        "exit_condition",
    }:
        raise TestLaneError("external_residual_lane key set mismatch")
    if residual["policy"] != "FAIL_CLOSED_UNTIL_BOUND_EXTERNAL_STATE_IS_RECONCILED":
        raise TestLaneError("external residual policy was weakened")
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
    exit_condition = residual["exit_condition"]
    if not isinstance(exit_condition, str) or not exit_condition.strip():
        raise TestLaneError("external residual exit_condition is required")
    return TestLaneManifest(tuple(roots), tuple(node_ids), exit_condition)


def pytest_command(
    lane: str,
    manifest: TestLaneManifest,
    *,
    collect_only: bool = False,
    extra_args: Sequence[str] = (),
) -> list[str]:
    command = [sys.executable, "-m", "pytest", "-q"]
    if lane == "green":
        command.extend(manifest.suite_roots)
        command.extend(
            argument
            for node_id in manifest.residual_node_ids
            for argument in ("--deselect", node_id)
        )
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
