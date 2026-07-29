#!/usr/bin/env python3
"""Strict read model for the Pipeline Books W0--W8 dashboard programme.

The dashboard status document is a source-only projection.  It cannot authorize
Factory, scheduler, MT5, deployment, money, or AutoTrading actions.  Its claims
are accepted only while the document is structurally valid and every bound
plan, evidence, policy, test-lane, and rulepack artifact still has the declared
hash.  Consumers receive an explicit ``MISSING``/``INVALID``/``STALE`` state;
an unreadable source is never rendered as an empty or successful programme.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Mapping, Sequence

try:  # package import (tests and dashboard package consumers)
    from tools.strategy_farm.target_rulepacks import load_rulepack_path
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/*.py`` execution
    from target_rulepacks import load_rulepack_path


SCHEMA_VERSION = "qm.pipeline-books-dashboard-status/v1"
DEFAULT_CONFIG = (
    Path(__file__).resolve().parent / "config" / "pipeline_books_program_status.v1.json"
)
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[2]

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
WORK_PACKAGE_IDS = tuple(f"W{i}" for i in range(9))
Q08_VERDICT_STATES = (
    "SUPPORTED",
    "CONDITIONAL",
    "INSUFFICIENT",
    "CONTRADICTED",
    "INVALID",
)
TARGET_LANE_IDS = ("DXZ_BETTER_BOOK", "FTMO_2S_100K_SWING")
TARGET_LANE_STATES = (
    "RESEARCH_RULEPACK_ONLY",
    "RESEARCH_EVALUATOR_SOURCE_IMPLEMENTED",
)
TOP_LEVEL_KEYS = {
    "schema_version",
    "program_id",
    "as_of_utc",
    "freshness_max_age_hours",
    "authority",
    "safety",
    "bindings",
    "work_packages",
    "q08_v3",
    "target_lanes",
    "verification_lanes",
    "owner_blockers",
}


class ProgramStatusError(ValueError):
    """The dashboard programme document cannot be trusted."""


def _fail(path: str, message: str) -> None:
    raise ProgramStatusError(f"{path}: {message}")


def _duplicate_key_guard(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise ProgramStatusError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def _reject_float(raw: str) -> Any:
    raise ProgramStatusError(f"floating-point JSON value rejected: {raw}")


def _reject_constant(raw: str) -> Any:
    raise ProgramStatusError(f"non-finite JSON value rejected: {raw}")


def _parse_json(path: Path) -> dict[str, Any]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError:
        raise
    except OSError as exc:
        raise ProgramStatusError(f"cannot read status document: {exc}") from exc
    try:
        value = json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_duplicate_key_guard,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ProgramStatusError(f"invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        _fail("$", "root must be an object")
    return value


def _exact_keys(value: Mapping[str, Any], expected: set[str], path: str) -> None:
    missing = sorted(expected - set(value))
    extra = sorted(set(value) - expected)
    if missing or extra:
        _fail(path, f"key set mismatch; missing={missing}, extra={extra}")


def _string(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        _fail(path, "must be a non-empty trimmed string")
    return value


def _bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        _fail(path, "must be boolean")
    return value


def _sha(value: Any, path: str) -> str:
    text = _string(value, path)
    if not SHA256_RE.fullmatch(text):
        _fail(path, "must be a lowercase SHA-256 hex digest")
    return text


def _utc(value: Any, path: str) -> dt.datetime:
    text = _string(value, path)
    if not text.endswith("Z"):
        _fail(path, "must use a Z-suffixed UTC timestamp")
    try:
        parsed = dt.datetime.fromisoformat(text[:-1] + "+00:00")
    except ValueError as exc:
        raise ProgramStatusError(f"{path}: invalid UTC timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        _fail(path, "must be UTC")
    return parsed


def _repo_path(repo_root: Path, relative: Any, path: str) -> Path:
    text = _string(relative, path)
    rel = Path(text)
    if rel.is_absolute() or ".." in rel.parts:
        _fail(path, "must be a repository-relative path without '..'")
    root = repo_root.resolve()
    resolved = (root / rel).resolve()
    try:
        resolved.relative_to(root)
    except ValueError:
        _fail(path, "resolves outside the repository")
    return resolved


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except FileNotFoundError:
        raise ProgramStatusError(f"bound artifact missing: {path}")
    except OSError as exc:
        raise ProgramStatusError(f"cannot read bound artifact {path}: {exc}") from exc
    return digest.hexdigest()


def _verify_file_binding(binding: Any, repo_root: Path, path: str) -> Path:
    if not isinstance(binding, dict):
        _fail(path, "must be an object")
    _exact_keys(binding, {"path", "file_sha256"}, path)
    source = _repo_path(repo_root, binding["path"], f"{path}.path")
    expected = _sha(binding["file_sha256"], f"{path}.file_sha256")
    actual = _file_sha256(source)
    if actual != expected:
        _fail(path, f"file hash mismatch for {binding['path']}: expected {expected}, got {actual}")
    return source


def _validate_safety(value: Any) -> None:
    if not isinstance(value, dict):
        _fail("$.safety", "must be an object")
    _exact_keys(
        value,
        {
            "factory_state",
            "factory_action_authorized",
            "scheduler_action_authorized",
            "mt5_action_authorized",
            "autotrading_action_authorized",
            "deployment_authorized",
            "statement",
        },
        "$.safety",
    )
    if value["factory_state"] != "INTENTIONALLY_OFF":
        _fail("$.safety.factory_state", "must be INTENTIONALLY_OFF")
    for key in (
        "factory_action_authorized",
        "scheduler_action_authorized",
        "mt5_action_authorized",
        "autotrading_action_authorized",
        "deployment_authorized",
    ):
        if _bool(value[key], f"$.safety.{key}"):
            _fail(f"$.safety.{key}", "source-only dashboard must not grant authority")
    _string(value["statement"], "$.safety.statement")


def _validate_bindings(value: Any, repo_root: Path) -> None:
    if not isinstance(value, dict):
        _fail("$.bindings", "must be an object")
    _exact_keys(
        value,
        {"plan", "evidence", "q08_policy", "test_lanes", "rulepacks"},
        "$.bindings",
    )
    _verify_file_binding(value["plan"], repo_root, "$.bindings.plan")
    _verify_file_binding(value["evidence"], repo_root, "$.bindings.evidence")
    _verify_file_binding(value["test_lanes"], repo_root, "$.bindings.test_lanes")

    policy = value["q08_policy"]
    if not isinstance(policy, dict):
        _fail("$.bindings.q08_policy", "must be an object")
    _exact_keys(
        policy, {"path", "file_sha256", "canonical_sha256"}, "$.bindings.q08_policy"
    )
    policy_path = _repo_path(repo_root, policy["path"], "$.bindings.q08_policy.path")
    policy_file_hash = _sha(policy["file_sha256"], "$.bindings.q08_policy.file_sha256")
    actual_file_hash = _file_sha256(policy_path)
    if actual_file_hash != policy_file_hash:
        _fail("$.bindings.q08_policy", "file hash mismatch")
    policy_payload = _parse_json(policy_path)
    canonical_policy = hashlib.sha256(
        json.dumps(
            policy_payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        ).encode("utf-8")
    ).hexdigest()
    if canonical_policy != _sha(
        policy["canonical_sha256"], "$.bindings.q08_policy.canonical_sha256"
    ):
        _fail("$.bindings.q08_policy", "canonical hash mismatch")

    rulepacks = value["rulepacks"]
    if not isinstance(rulepacks, list) or len(rulepacks) != 2:
        _fail("$.bindings.rulepacks", "must contain exactly the DXZ and FTMO rulepacks")
    seen: set[str] = set()
    for index, binding in enumerate(rulepacks):
        path = f"$.bindings.rulepacks[{index}]"
        if not isinstance(binding, dict):
            _fail(path, "must be an object")
        _exact_keys(
            binding,
            {"rulepack_id", "path", "file_sha256", "canonical_sha256"},
            path,
        )
        rulepack_id = _string(binding["rulepack_id"], f"{path}.rulepack_id")
        if rulepack_id in seen:
            _fail(path, "duplicate rulepack_id")
        source = _repo_path(repo_root, binding["path"], f"{path}.path")
        expected_file = _sha(binding["file_sha256"], f"{path}.file_sha256")
        if _file_sha256(source) != expected_file:
            _fail(path, "file hash mismatch")
        try:
            loaded = load_rulepack_path(source)
        except Exception as exc:
            raise ProgramStatusError(f"{path}: invalid target rulepack: {exc}") from exc
        if loaded.rulepack_id != rulepack_id:
            _fail(path, "rulepack_id does not match bound artifact")
        expected_canonical = _sha(
            binding["canonical_sha256"], f"{path}.canonical_sha256"
        )
        if loaded.canonical_sha256 != expected_canonical:
            _fail(path, "canonical rulepack hash mismatch")
        seen.add(rulepack_id)
    if seen != {"DXZ_BETTER_BOOK_V1", "FTMO_2S_100K_SWING_V1"}:
        _fail("$.bindings.rulepacks", "required rulepack IDs missing")


def _validate_work_packages(value: Any) -> None:
    if not isinstance(value, list) or len(value) != 9:
        _fail("$.work_packages", "must contain exactly W0 through W8")
    for index, row in enumerate(value):
        path = f"$.work_packages[{index}]"
        if not isinstance(row, dict):
            _fail(path, "must be an object")
        _exact_keys(
            row,
            {
                "id",
                "title",
                "status",
                "source_status",
                "runtime_status",
                "authority_status",
                "next_action",
            },
            path,
        )
        if row["id"] != WORK_PACKAGE_IDS[index]:
            _fail(f"{path}.id", f"expected {WORK_PACKAGE_IDS[index]}")
        for key in (
            "title",
            "status",
            "source_status",
            "runtime_status",
            "authority_status",
            "next_action",
        ):
            _string(row[key], f"{path}.{key}")
        if row["authority_status"] != "NO_RUNTIME_AUTHORITY":
            _fail(f"{path}.authority_status", "must remain NO_RUNTIME_AUTHORITY")


def _validate_q08(value: Any, bindings: Mapping[str, Any]) -> None:
    if not isinstance(value, dict):
        _fail("$.q08_v3", "must be an object")
    _exact_keys(
        value,
        {
            "lifecycle",
            "promotion_state",
            "canonical_q08_unchanged",
            "policy_canonical_sha256",
            "verdict_states",
            "evidence_semantics",
        },
        "$.q08_v3",
    )
    if value["lifecycle"] != "SHADOW_ONLY":
        _fail("$.q08_v3.lifecycle", "must be SHADOW_ONLY")
    if value["promotion_state"] != "NOT_OWNER_APPROVED":
        _fail("$.q08_v3.promotion_state", "must be NOT_OWNER_APPROVED")
    if not _bool(value["canonical_q08_unchanged"], "$.q08_v3.canonical_q08_unchanged"):
        _fail("$.q08_v3.canonical_q08_unchanged", "must be true")
    policy_hash = _sha(value["policy_canonical_sha256"], "$.q08_v3.policy_canonical_sha256")
    if policy_hash != bindings["q08_policy"]["canonical_sha256"]:
        _fail("$.q08_v3.policy_canonical_sha256", "does not match policy binding")
    if tuple(value["verdict_states"]) != Q08_VERDICT_STATES:
        _fail("$.q08_v3.verdict_states", "must use the ordered five-state contract")
    _string(value["evidence_semantics"], "$.q08_v3.evidence_semantics")


def _validate_target_lanes(value: Any, bindings: Mapping[str, Any]) -> None:
    if not isinstance(value, list) or len(value) != 2:
        _fail("$.target_lanes", "must contain exactly the DXZ and FTMO lanes")
    bound = {row["rulepack_id"]: row for row in bindings["rulepacks"]}
    for index, row in enumerate(value):
        path = f"$.target_lanes[{index}]"
        if not isinstance(row, dict):
            _fail(path, "must be an object")
        _exact_keys(
            row,
            {
                "lane_id",
                "label",
                "state",
                "rulepack_id",
                "rulepack_canonical_sha256",
                "eligibility",
                "deployment_authority",
                "next_action",
            },
            path,
        )
        if row["lane_id"] != TARGET_LANE_IDS[index]:
            _fail(f"{path}.lane_id", f"expected {TARGET_LANE_IDS[index]}")
        for key in ("label", "state", "rulepack_id", "eligibility", "next_action"):
            _string(row[key], f"{path}.{key}")
        if row["state"] not in TARGET_LANE_STATES:
            _fail(
                f"{path}.state",
                f"must be one of {', '.join(TARGET_LANE_STATES)}",
            )
        if row["eligibility"] != "NOT_EVALUATED":
            _fail(f"{path}.eligibility", "must be NOT_EVALUATED")
        if row["deployment_authority"] != "NONE":
            _fail(f"{path}.deployment_authority", "must be NONE")
        rulepack_id = row["rulepack_id"]
        if rulepack_id not in bound:
            _fail(f"{path}.rulepack_id", "has no binding")
        expected = _sha(
            row["rulepack_canonical_sha256"], f"{path}.rulepack_canonical_sha256"
        )
        if expected != bound[rulepack_id]["canonical_sha256"]:
            _fail(path, "lane hash does not match rulepack binding")


def _test_lane_node_ids(test_lanes_path: Path) -> tuple[str, ...]:
    payload = _parse_json(test_lanes_path)
    try:
        rows = payload["external_residual_lane"]["tests"]
        values = tuple(row["node_id"] for row in rows)
    except (KeyError, TypeError) as exc:
        raise ProgramStatusError("bound test-lane artifact lacks residual node IDs") from exc
    if not all(isinstance(value, str) for value in values):
        _fail("test_lanes", "residual node IDs must be strings")
    return values


def _validate_verification_lanes(value: Any, repo_root: Path, bindings: Mapping[str, Any]) -> None:
    if not isinstance(value, dict):
        _fail("$.verification_lanes", "must be an object")
    _exact_keys(value, {"green", "external_residual"}, "$.verification_lanes")
    green = value["green"]
    if not isinstance(green, dict):
        _fail("$.verification_lanes.green", "must be an object")
    _exact_keys(
        green,
        {"state", "passed", "skipped", "deselected", "subtests_passed", "statement"},
        "$.verification_lanes.green",
    )
    if green["state"] != "PASS":
        _fail("$.verification_lanes.green.state", "must be PASS")
    for key in ("passed", "skipped", "deselected", "subtests_passed"):
        if type(green[key]) is not int or green[key] < 0:
            _fail(f"$.verification_lanes.green.{key}", "must be a non-negative integer")
    _string(green["statement"], "$.verification_lanes.green.statement")

    residual = value["external_residual"]
    if not isinstance(residual, dict):
        _fail("$.verification_lanes.external_residual", "must be an object")
    _exact_keys(
        residual,
        {"state", "expected_count", "items", "exit_condition"},
        "$.verification_lanes.external_residual",
    )
    if residual["state"] != "EXPECTED_FAIL_CLOSED":
        _fail("$.verification_lanes.external_residual.state", "must be EXPECTED_FAIL_CLOSED")
    if residual["expected_count"] != 5:
        _fail("$.verification_lanes.external_residual.expected_count", "must be exactly 5")
    items = residual["items"]
    if not isinstance(items, list) or len(items) != 5:
        _fail("$.verification_lanes.external_residual.items", "must contain exactly five items")
    node_ids: list[str] = []
    for index, item in enumerate(items):
        path = f"$.verification_lanes.external_residual.items[{index}]"
        if not isinstance(item, dict):
            _fail(path, "must be an object")
        _exact_keys(item, {"node_id", "label", "owner_items"}, path)
        node_ids.append(_string(item["node_id"], f"{path}.node_id"))
        _string(item["label"], f"{path}.label")
        owner_items = item["owner_items"]
        if not isinstance(owner_items, list) or not owner_items:
            _fail(f"{path}.owner_items", "must be a non-empty array")
        for owner_index, owner_item in enumerate(owner_items):
            _string(owner_item, f"{path}.owner_items[{owner_index}]")
    if len(set(node_ids)) != 5:
        _fail("$.verification_lanes.external_residual.items", "node IDs must be unique")
    test_lanes_path = _repo_path(repo_root, bindings["test_lanes"]["path"], "$.bindings.test_lanes.path")
    if tuple(node_ids) != _test_lane_node_ids(test_lanes_path):
        _fail("$.verification_lanes.external_residual.items", "does not match bound test-lane order")
    _string(residual["exit_condition"], "$.verification_lanes.external_residual.exit_condition")


def _validate_owner_blockers(value: Any) -> None:
    if not isinstance(value, list) or not value:
        _fail("$.owner_blockers", "must be a non-empty array")
    seen: set[str] = set()
    for index, row in enumerate(value):
        path = f"$.owner_blockers[{index}]"
        if not isinstance(row, dict):
            _fail(path, "must be an object")
        _exact_keys(row, {"id", "title", "state", "safe_default", "blocks"}, path)
        blocker_id = _string(row["id"], f"{path}.id")
        if blocker_id in seen:
            _fail(path, "duplicate blocker ID")
        seen.add(blocker_id)
        _string(row["title"], f"{path}.title")
        if row["state"] != "OPEN_OWNER_DECISION":
            _fail(f"{path}.state", "must be OPEN_OWNER_DECISION")
        _string(row["safe_default"], f"{path}.safe_default")
        blocks = row["blocks"]
        if not isinstance(blocks, list) or not blocks:
            _fail(f"{path}.blocks", "must be a non-empty array")
        for block_index, block in enumerate(blocks):
            _string(block, f"{path}.blocks[{block_index}]")


def load_program_status(
    path: Path | str = DEFAULT_CONFIG,
    *,
    repo_root: Path | str = DEFAULT_REPO_ROOT,
) -> dict[str, Any]:
    """Load and verify the strict source programme document.

    The returned dictionary is detached from the parser.  A caller that needs a
    non-throwing dashboard model should use :func:`program_status_snapshot`.
    """

    source = Path(path)
    root = Path(repo_root)
    value = _parse_json(source)
    _exact_keys(value, TOP_LEVEL_KEYS, "$")
    if value["schema_version"] != SCHEMA_VERSION:
        _fail("$.schema_version", f"unsupported value {value['schema_version']!r}")
    if value["program_id"] != "PIPELINE_BOOKS_DXZ_FTMO_2026_07":
        _fail("$.program_id", "unexpected programme identity")
    _utc(value["as_of_utc"], "$.as_of_utc")
    if type(value["freshness_max_age_hours"]) is not int or not 1 <= value["freshness_max_age_hours"] <= 720:
        _fail("$.freshness_max_age_hours", "must be an integer from 1 through 720")
    if value["authority"] != "SOURCE_STATUS_ONLY_NO_RUNTIME_AUTHORITY":
        _fail("$.authority", "must deny runtime authority")
    _validate_safety(value["safety"])
    _validate_bindings(value["bindings"], root)
    _validate_work_packages(value["work_packages"])
    _validate_q08(value["q08_v3"], value["bindings"])
    _validate_target_lanes(value["target_lanes"], value["bindings"])
    _validate_verification_lanes(value["verification_lanes"], root, value["bindings"])
    _validate_owner_blockers(value["owner_blockers"])
    return json.loads(json.dumps(value))


def _now_utc(now_utc: dt.datetime | None) -> dt.datetime:
    now = now_utc or dt.datetime.now(dt.UTC)
    if now.tzinfo is None or now.utcoffset() != dt.timedelta(0):
        raise ValueError("now_utc must be timezone-aware UTC")
    return now.astimezone(dt.UTC)


def program_status_snapshot(
    path: Path | str = DEFAULT_CONFIG,
    *,
    repo_root: Path | str = DEFAULT_REPO_ROOT,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    """Return a renderer-safe, explicit FRESH/STALE/MISSING/INVALID model."""

    now = _now_utc(now_utc)
    base: dict[str, Any] = {
        "state": "INVALID",
        "valid": False,
        "error": "",
        "generated_at_utc": now.isoformat().replace("+00:00", "Z"),
        "config_as_of_utc": None,
        "age_hours": None,
        "schema_version": SCHEMA_VERSION,
        "program_id": None,
        "authority": None,
        "safety": {},
        "bindings": {},
        "work_packages": [],
        "q08_v3": {},
        "target_lanes": [],
        "verification_lanes": {},
        "owner_blockers": [],
    }
    try:
        value = load_program_status(path, repo_root=repo_root)
    except FileNotFoundError:
        base["state"] = "MISSING"
        base["error"] = f"programme status source missing: {Path(path)}"
        return base
    except ProgramStatusError as exc:
        base["state"] = "INVALID"
        base["error"] = str(exc)
        return base

    as_of = _utc(value["as_of_utc"], "$.as_of_utc")
    age = (now - as_of).total_seconds() / 3600
    if age < -1:
        base["state"] = "INVALID"
        base["error"] = "programme status as_of_utc is more than one hour in the future"
        return base
    state = "STALE" if age > value["freshness_max_age_hours"] else "FRESH"
    base.update(value)
    base.update(
        {
            "state": state,
            "valid": state == "FRESH",
            "error": "" if state == "FRESH" else (
                f"programme status is {age:.1f}h old; maximum is "
                f"{value['freshness_max_age_hours']}h"
            ),
            "generated_at_utc": now.isoformat().replace("+00:00", "Z"),
            "config_as_of_utc": value["as_of_utc"],
            "age_hours": round(age, 1),
        }
    )
    return base


__all__ = [
    "DEFAULT_CONFIG",
    "DEFAULT_REPO_ROOT",
    "ProgramStatusError",
    "load_program_status",
    "program_status_snapshot",
]
