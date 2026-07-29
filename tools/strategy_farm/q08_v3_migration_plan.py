#!/usr/bin/env python3
"""Create a deterministic Q08 v2/v3 discordance plan with no apply path.

The input inventory is immutable and content-addressed.  Q08 v3 shadow
decisions are resolved only through explicit work-item, alias, or lineage
selectors.  Ambiguous and duplicate bindings remain unresolved and therefore
fail closed.  Output proposals are advisory; OWNER authorization and runtime
action are always ``NONE``.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from q08_v3_migration_inventory import (
        InventoryError,
        canonical_q08_policy_binding,
        canonical_sha256,
        load_json_file,
        render_json_bytes,
        validate_inventory,
        write_create_new,
    )
except ModuleNotFoundError:  # pragma: no cover - package-style invocation
    from tools.strategy_farm.q08_v3_migration_inventory import (
        InventoryError,
        canonical_q08_policy_binding,
        canonical_sha256,
        load_json_file,
        render_json_bytes,
        validate_inventory,
        write_create_new,
    )

try:
    from framework.scripts.q08_v3_shadow import (
        DEFAULT_POLICY_PATH as DEFAULT_Q08_POLICY_PATH,
        PolicyValidationError,
        SubtestResult,
        aggregate_shadow,
        load_policy as load_q08_policy,
    )
except ModuleNotFoundError:  # direct script execution
    repo_root = Path(__file__).resolve().parents[2]
    if str(repo_root) not in sys.path:
        sys.path.insert(0, str(repo_root))
    from framework.scripts.q08_v3_shadow import (
        DEFAULT_POLICY_PATH as DEFAULT_Q08_POLICY_PATH,
        PolicyValidationError,
        SubtestResult,
        aggregate_shadow,
        load_policy as load_q08_policy,
    )


SCHEMA_VERSION = "qm.q08-v3-migration-plan/v1"
SHADOW_BINDINGS_SCHEMA_VERSION = "qm.q08-v3-shadow-bindings/v1"
SHADOW_DECISION_SCHEMA_VERSION = "q08_shadow_decision/v1"
TOOL_VERSION = "q08_v3_migration_plan/1.0.0"

SELECTOR_TYPES = {"WORK_ITEM_ID", "ALIAS", "LINEAGE_KEY"}
V3_VERDICTS = {
    "SUPPORTED",
    "CONDITIONAL",
    "INSUFFICIENT",
    "CONTRADICTED",
    "INVALID",
}
VERDICT_ROUTES = {
    "SUPPORTED": "PORTFOLIO_EVALUATION",
    "CONDITIONAL": "PORTFOLIO_EVALUATION_CONDITIONAL",
    "INSUFFICIENT": "SHADOW_EVIDENCE",
    "CONTRADICTED": "REJECT",
    "INVALID": "RETRY",
}
DISCORDANCE_STATES = (
    "AGREEMENT",
    "UPGRADE_CANDIDATE",
    "DOWNGRADE_REVIEW",
    "REVERSAL_REVIEW",
    "EVIDENCE_GAP",
    "INFRA_RESOLVED_REVIEW",
    "NO_V3_RESULT",
    "NOT_ELIGIBLE",
    "INVALID_BINDING",
)
OVERLAY_STATES = (
    "SUPPORTED_CANDIDATE",
    "CONDITIONAL_CANDIDATE",
    "INSUFFICIENT_HOLD",
    "CONTRADICTED_HOLD",
    "INVALID_HOLD",
    "NO_RESULT",
    "NOT_ELIGIBLE",
    "COLLISION_HOLD",
)
RESOLUTION_STATES = {"NO_MATCH", "AMBIGUOUS_MATCH", "MULTIPLE_BINDINGS"}
INVENTORY_DISPOSITIONS = {
    "CURRENT",
    "LEGACY_UNVERIFIED",
    "ELIGIBLE_REEVALUATION",
    "INVALID",
    "SUPERSEDED",
}
INVENTORY_PRIORITIES = {
    "P0_CURRENT_TARGET",
    "P1_V2_PASS",
    "P2_V2_FAIL_SOFT",
    "P3_LEGACY",
    "HOLD_INVALID",
    "HOLD_SUPERSEDED",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

DECISION_KEYS = {
    "schema_version",
    "policy_version",
    "policy_sha256",
    "verdict",
    "route",
    "archetype_requested",
    "archetype_resolved",
    "required_test_ids",
    "supported_test_ids",
    "conditional_test_ids",
    "insufficient_test_ids",
    "contradicted_test_ids",
    "invalid_test_ids",
    "missing_test_ids",
    "diagnostic_test_ids",
    "ignored_test_ids",
    "reasons",
}
DECISION_ARRAY_KEYS = (
    "required_test_ids",
    "supported_test_ids",
    "conditional_test_ids",
    "insufficient_test_ids",
    "contradicted_test_ids",
    "invalid_test_ids",
    "missing_test_ids",
    "diagnostic_test_ids",
    "ignored_test_ids",
    "reasons",
)
SUBTEST_RESULT_KEYS = {"test_id", "status", "detail"}


class PlanError(RuntimeError):
    """The inventory, shadow bindings, or resulting plan is invalid."""


def _exact_object(value: Any, keys: set[str], context: str) -> dict[str, Any]:
    if type(value) is not dict:
        raise PlanError(f"{context} must be an object")
    actual = set(value)
    if actual != keys:
        raise PlanError(
            f"{context} key set mismatch "
            f"(missing={sorted(keys - actual)}, extra={sorted(actual - keys)})"
        )
    return value


def _nonempty_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        raise PlanError(f"{context} must be a non-empty, trimmed string")
    return value


def _sha(value: Any, context: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise PlanError(f"{context} must be a lowercase SHA-256 digest")
    return value


def _sorted_string_set(value: Any, context: str, *, allow_empty: bool = True) -> list[str]:
    if type(value) is not list:
        raise PlanError(f"{context} must be an array")
    if not value and not allow_empty:
        raise PlanError(f"{context} must not be empty")
    for index, item in enumerate(value):
        if not isinstance(item, str) or not item:
            raise PlanError(f"{context}[{index}] must be a non-empty string")
    if value != sorted(value) or len(value) != len(set(value)):
        raise PlanError(f"{context} must be uniquely sorted")
    return value


def _normalize_subtest_results(value: Any, context: str) -> list[dict[str, str]]:
    if type(value) is not list:
        raise PlanError(f"{context} must be an array")
    normalized: list[dict[str, str]] = []
    for index, raw in enumerate(value):
        item_context = f"{context}[{index}]"
        if type(raw) is not dict:
            raise PlanError(f"{item_context} must be an object")
        if not {"test_id", "status"}.issubset(raw) or not set(raw).issubset(
            SUBTEST_RESULT_KEYS
        ):
            raise PlanError(
                f"{item_context} must contain test_id/status and optional detail only"
            )
        try:
            parsed = SubtestResult.from_mapping(raw)
        except (TypeError, ValueError) as exc:
            raise PlanError(f"{item_context} violates the Q08-v3 result contract: {exc}") from exc
        normalized.append(
            {
                "test_id": parsed.test_id,
                "status": parsed.status.value,
                "detail": parsed.detail,
            }
        )
    normalized.sort(key=lambda row: (row["test_id"], row["status"], row["detail"]))
    return normalized


def _validate_decision(
    value: Any,
    context: str,
    *,
    policy: Any,
    subtest_results: Sequence[Mapping[str, str]],
) -> dict[str, Any]:
    decision = _exact_object(value, DECISION_KEYS, context)
    if decision["schema_version"] != SHADOW_DECISION_SCHEMA_VERSION:
        raise PlanError(f"{context} has unsupported schema_version")
    _nonempty_string(decision["policy_version"], f"{context}.policy_version")
    _sha(decision["policy_sha256"], f"{context}.policy_sha256")
    verdict = decision["verdict"]
    if verdict not in V3_VERDICTS:
        raise PlanError(f"{context} has unsupported verdict")
    if decision["route"] != VERDICT_ROUTES[verdict]:
        raise PlanError(f"{context} verdict/route mismatch")
    if not isinstance(decision["archetype_requested"], str):
        raise PlanError(f"{context}.archetype_requested must be a string")
    if decision["archetype_resolved"] is not None and not isinstance(
        decision["archetype_resolved"], str
    ):
        raise PlanError(f"{context}.archetype_resolved must be string or null")
    for key in DECISION_ARRAY_KEYS:
        _sorted_string_set(decision[key], f"{context}.{key}")
    if decision["policy_version"] != policy.policy_version:
        raise PlanError(f"{context}.policy_version does not bind the canonical policy")
    if decision["policy_sha256"] != policy.policy_sha256:
        raise PlanError(f"{context}.policy_sha256 does not bind the canonical policy")
    expected = aggregate_shadow(
        archetype=decision["archetype_requested"],
        results=subtest_results,
        policy=policy,
    ).to_dict()
    if decision != expected:
        raise PlanError(
            f"{context} does not match canonical Q08-v3 aggregation semantics"
        )
    return decision


def normalize_shadow_bindings(value: Any) -> dict[str, Any]:
    """Validate and deterministically normalize explicit v3 result bindings."""

    if type(value) is not dict:
        raise PlanError("shadow bindings must be an object")
    allowed_root_keys = {"schema_version", "bindings", "policy_binding"}
    if set(value) not in ({"schema_version", "bindings"}, allowed_root_keys):
        raise PlanError("shadow bindings key set mismatch")
    root = value
    if root["schema_version"] != SHADOW_BINDINGS_SCHEMA_VERSION:
        raise PlanError("unsupported shadow-bindings schema_version")
    if type(root["bindings"]) is not list:
        raise PlanError("shadow bindings must be an array")
    try:
        policy = load_q08_policy(DEFAULT_Q08_POLICY_PATH)
        expected_policy_binding = canonical_q08_policy_binding()
    except (InventoryError, PolicyValidationError, OSError) as exc:
        raise PlanError(f"canonical Q08-v3 policy cannot be loaded: {exc}") from exc
    if "policy_binding" in root:
        declared_policy_binding = _exact_object(
            root["policy_binding"],
            {"path", "file_sha256", "canonical_sha256", "policy_version"},
            "shadow bindings policy_binding",
        )
        if declared_policy_binding != expected_policy_binding:
            raise PlanError("shadow bindings policy_binding is stale or non-canonical")
    normalized: list[dict[str, Any]] = []
    selectors: set[tuple[str, str]] = set()
    for index, raw in enumerate(root["bindings"]):
        binding = _exact_object(
            raw,
            {"selector_type", "selector", "subtest_results", "decision"},
            f"shadow bindings[{index}]",
        )
        selector_type = _nonempty_string(
            binding["selector_type"], f"bindings[{index}].selector_type"
        ).upper()
        selector = _nonempty_string(binding["selector"], f"bindings[{index}].selector")
        if selector_type not in SELECTOR_TYPES:
            raise PlanError(f"unsupported shadow selector_type: {selector_type}")
        selector_key = (selector_type, selector)
        if selector_key in selectors:
            raise PlanError(f"duplicate shadow selector: {selector_key}")
        selectors.add(selector_key)
        subtest_results = _normalize_subtest_results(
            binding["subtest_results"], f"bindings[{index}].subtest_results"
        )
        decision = _validate_decision(
            binding["decision"],
            f"bindings[{index}].decision",
            policy=policy,
            subtest_results=subtest_results,
        )
        normalized.append(
            {
                "selector_type": selector_type,
                "selector": selector,
                "subtest_results": subtest_results,
                "decision": decision,
            }
        )
    normalized.sort(
        key=lambda row: (
            row["selector_type"],
            row["selector"],
            canonical_sha256(row["decision"]),
        )
    )
    return {
        "schema_version": SHADOW_BINDINGS_SCHEMA_VERSION,
        "policy_binding": expected_policy_binding,
        "bindings": normalized,
    }


def load_shadow_bindings(path: Path | None) -> dict[str, Any]:
    if path is None:
        return normalize_shadow_bindings(
            {"schema_version": SHADOW_BINDINGS_SCHEMA_VERSION, "bindings": []}
        )
    return normalize_shadow_bindings(
        load_json_file(Path(path), context="Q08 v3 shadow bindings")
    )


def _record_indexes(
    records: Sequence[Mapping[str, Any]],
) -> tuple[
    dict[str, Mapping[str, Any]],
    dict[str, list[str]],
    dict[str, list[str]],
]:
    by_id: dict[str, Mapping[str, Any]] = {}
    by_alias_sets: dict[str, set[str]] = defaultdict(set)
    by_lineage_sets: dict[str, set[str]] = defaultdict(set)
    for record in records:
        item_id = str(record["work_item_id"])
        by_id[item_id] = record
        by_lineage_sets[str(record["lineage"]["key"])].add(item_id)
        for alias in record["aliases"]:
            by_alias_sets[str(alias["alias"])].add(item_id)
    by_alias = {key: sorted(values) for key, values in by_alias_sets.items()}
    by_lineage = {key: sorted(values) for key, values in by_lineage_sets.items()}
    return by_id, by_alias, by_lineage


def _binding_candidates(
    binding: Mapping[str, Any],
    by_id: Mapping[str, Mapping[str, Any]],
    by_alias: Mapping[str, Sequence[str]],
    by_lineage: Mapping[str, Sequence[str]],
) -> list[str]:
    selector_type = binding["selector_type"]
    selector = binding["selector"]
    if selector_type == "WORK_ITEM_ID":
        return [selector] if selector in by_id else []
    if selector_type == "ALIAS":
        return list(by_alias.get(selector, ()))
    return list(by_lineage.get(selector, ()))


def _resolve_bindings(
    records: Sequence[Mapping[str, Any]],
    manifest: Mapping[str, Any],
) -> tuple[dict[str, Mapping[str, Any]], list[dict[str, Any]], set[str]]:
    by_id, by_alias, by_lineage = _record_indexes(records)
    staged: list[tuple[Mapping[str, Any], list[str], str]] = []
    singleton_counts: Counter[str] = Counter()
    for binding in manifest["bindings"]:
        candidates = _binding_candidates(binding, by_id, by_alias, by_lineage)
        if not candidates:
            resolution = "NO_MATCH"
        elif len(candidates) > 1:
            resolution = "AMBIGUOUS_MATCH"
        else:
            resolution = "RESOLVED"
            singleton_counts[candidates[0]] += 1
        staged.append((binding, candidates, resolution))

    resolved: dict[str, Mapping[str, Any]] = {}
    unresolved: list[dict[str, Any]] = []
    affected: set[str] = set()
    for binding, candidates, initial_resolution in staged:
        resolution = initial_resolution
        if resolution == "RESOLVED" and singleton_counts[candidates[0]] > 1:
            resolution = "MULTIPLE_BINDINGS"
        binding_sha = canonical_sha256(binding)
        if resolution == "RESOLVED":
            resolved[candidates[0]] = binding
            continue
        affected.update(candidates)
        unresolved.append(
            {
                "binding_sha256": binding_sha,
                "selector_type": binding["selector_type"],
                "selector": binding["selector"],
                "resolution": resolution,
                "candidate_work_item_ids": candidates,
            }
        )
    unresolved.sort(
        key=lambda row: (
            row["resolution"],
            row["selector_type"],
            row["selector"],
            row["binding_sha256"],
        )
    )
    return resolved, unresolved, affected


def _discordance(legacy_verdict: Any, v3_verdict: str) -> str:
    if legacy_verdict == "PASS":
        return {
            "SUPPORTED": "AGREEMENT",
            "CONDITIONAL": "DOWNGRADE_REVIEW",
            "INSUFFICIENT": "EVIDENCE_GAP",
            "CONTRADICTED": "REVERSAL_REVIEW",
            "INVALID": "EVIDENCE_GAP",
        }[v3_verdict]
    if legacy_verdict == "FAIL_SOFT":
        return {
            "SUPPORTED": "UPGRADE_CANDIDATE",
            "CONDITIONAL": "AGREEMENT",
            "INSUFFICIENT": "EVIDENCE_GAP",
            "CONTRADICTED": "DOWNGRADE_REVIEW",
            "INVALID": "EVIDENCE_GAP",
        }[v3_verdict]
    if legacy_verdict == "FAIL_HARD":
        return {
            "SUPPORTED": "REVERSAL_REVIEW",
            "CONDITIONAL": "REVERSAL_REVIEW",
            "INSUFFICIENT": "EVIDENCE_GAP",
            "CONTRADICTED": "AGREEMENT",
            "INVALID": "EVIDENCE_GAP",
        }[v3_verdict]
    if legacy_verdict == "FAIL":
        return {
            "SUPPORTED": "REVERSAL_REVIEW",
            "CONDITIONAL": "REVERSAL_REVIEW",
            "INSUFFICIENT": "EVIDENCE_GAP",
            "CONTRADICTED": "AGREEMENT",
            "INVALID": "EVIDENCE_GAP",
        }[v3_verdict]
    if legacy_verdict == "INFRA_FAIL":
        if v3_verdict in {"SUPPORTED", "CONDITIONAL", "CONTRADICTED"}:
            return "INFRA_RESOLVED_REVIEW"
        return "EVIDENCE_GAP"
    return "INVALID_BINDING"


def _overlay_state(v3_verdict: str) -> str:
    return {
        "SUPPORTED": "SUPPORTED_CANDIDATE",
        "CONDITIONAL": "CONDITIONAL_CANDIDATE",
        "INSUFFICIENT": "INSUFFICIENT_HOLD",
        "CONTRADICTED": "CONTRADICTED_HOLD",
        "INVALID": "INVALID_HOLD",
    }[v3_verdict]


def _proposal(
    record: Mapping[str, Any],
    *,
    binding: Mapping[str, Any] | None,
    binding_unresolved: bool,
    collision_blocked: bool,
) -> dict[str, Any]:
    reasons: set[str] = set()
    decision: Mapping[str, Any] | None = None
    decision_sha: str | None = None
    binding_sha: str | None = None
    if binding is not None:
        decision = binding["decision"]
        decision_sha = canonical_sha256(decision)
        binding_sha = canonical_sha256(binding)
        binding_state = "MATCHED"
    elif binding_unresolved:
        binding_state = "UNRESOLVED"
        reasons.add("SHADOW_BINDING_UNRESOLVED")
    else:
        binding_state = "NOT_PROVIDED"

    disposition = record["disposition"]
    if disposition == "INVALID":
        discordance = "INVALID_BINDING"
        overlay = "INVALID_HOLD"
        reasons.add("INVENTORY_INVALID")
    elif disposition == "SUPERSEDED":
        discordance = "NOT_ELIGIBLE"
        overlay = "NOT_ELIGIBLE"
        reasons.add("INVENTORY_SUPERSEDED")
    elif collision_blocked:
        discordance = "INVALID_BINDING"
        overlay = "COLLISION_HOLD"
        reasons.add("BLOCKING_IDENTITY_COLLISION")
    elif binding_state == "UNRESOLVED":
        discordance = "INVALID_BINDING"
        overlay = "INVALID_HOLD"
    elif decision is None:
        discordance = "NO_V3_RESULT"
        overlay = "NO_RESULT"
        reasons.add("SHADOW_RESULT_NOT_PROVIDED")
    else:
        discordance = _discordance(record["legacy"]["verdict"], decision["verdict"])
        overlay = _overlay_state(decision["verdict"])
        if discordance != "AGREEMENT":
            reasons.add("OLD_VS_V3_REVIEW_REQUIRED")

    shadow = {
        "binding_state": binding_state,
        "binding_sha256": binding_sha,
        "decision_sha256": decision_sha,
        "verdict": None if decision is None else decision["verdict"],
        "route": None if decision is None else decision["route"],
    }
    proposal: dict[str, Any] = {
        "work_item_id": record["work_item_id"],
        "lineage_key": record["lineage"]["key"],
        "legacy_verdict": record["legacy"]["verdict"],
        "inventory_disposition": disposition,
        "inventory_priority": record["priority"],
        "targets": list(record["targets"]),
        "shadow": shadow,
        "discordance": discordance,
        "proposed_overlay_state": overlay,
        "owner_authorization": "NONE",
        "runtime_action": "NONE",
        "reason_codes": sorted(reasons),
    }
    proposal["proposal_id"] = canonical_sha256(proposal)
    return proposal


def _full_counts(values: Sequence[str], domain: Sequence[str]) -> dict[str, int]:
    counts = Counter(values)
    return {name: int(counts.get(name, 0)) for name in domain}


def build_migration_plan(
    inventory: Mapping[str, Any],
    *,
    shadow_bindings: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Build one advisory proposal per inventory record; never write SQLite."""

    try:
        validated_inventory = validate_inventory(inventory)
    except InventoryError as exc:
        raise PlanError(f"invalid inventory: {exc}") from exc
    manifest = normalize_shadow_bindings(
        shadow_bindings
        if shadow_bindings is not None
        else {"schema_version": SHADOW_BINDINGS_SCHEMA_VERSION, "bindings": []}
    )
    if validated_inventory["source"]["q08_policy_binding"] != manifest["policy_binding"]:
        raise PlanError(
            "inventory and shadow bindings do not share the canonical Q08-v3 policy"
        )
    records = validated_inventory["records"]
    resolved, unresolved, unresolved_affected = _resolve_bindings(records, manifest)
    collision_blocked = set(validated_inventory["summary"]["blocking_work_item_ids"])
    proposals = [
        _proposal(
            record,
            binding=resolved.get(record["work_item_id"]),
            binding_unresolved=record["work_item_id"] in unresolved_affected,
            collision_blocked=record["work_item_id"] in collision_blocked,
        )
        for record in records
    ]
    proposals.sort(key=lambda row: row["work_item_id"])
    summary = {
        "proposal_count": len(proposals),
        "discordance_counts": _full_counts(
            [row["discordance"] for row in proposals], DISCORDANCE_STATES
        ),
        "overlay_state_counts": _full_counts(
            [row["proposed_overlay_state"] for row in proposals], OVERLAY_STATES
        ),
        "matched_work_item_ids": sorted(resolved),
        "no_result_work_item_ids": sorted(
            row["work_item_id"]
            for row in proposals
            if row["shadow"]["binding_state"] == "NOT_PROVIDED"
        ),
        "collision_blocked_work_item_ids": sorted(collision_blocked),
    }
    plan: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "plan_mode": "DRY_RUN_ONLY",
        "owner_authorization": "NONE",
        "runtime_action": "NONE",
        "apply_supported": False,
        "source": {
            "inventory_sha256": validated_inventory["inventory_sha256"],
            "inventory_row_count": len(records),
            "shadow_bindings_sha256": canonical_sha256(manifest),
            "shadow_binding_count": len(manifest["bindings"]),
            "resolved_binding_count": len(resolved),
            "unresolved_binding_count": len(unresolved),
            "q08_policy_binding": dict(manifest["policy_binding"]),
        },
        "shadow_bindings": manifest,
        "unresolved_bindings": unresolved,
        "proposals": proposals,
        "summary": summary,
    }
    plan["plan_sha256"] = canonical_sha256(plan)
    validate_plan(plan)
    return plan


def validate_plan(value: Any) -> dict[str, Any]:
    root = _exact_object(
        value,
        {
            "schema_version",
            "tool_version",
            "plan_mode",
            "owner_authorization",
            "runtime_action",
            "apply_supported",
            "source",
            "shadow_bindings",
            "unresolved_bindings",
            "proposals",
            "summary",
            "plan_sha256",
        },
        "migration plan",
    )
    if root["schema_version"] != SCHEMA_VERSION or root["tool_version"] != TOOL_VERSION:
        raise PlanError("unsupported migration-plan version")
    if (
        root["plan_mode"] != "DRY_RUN_ONLY"
        or root["owner_authorization"] != "NONE"
        or root["runtime_action"] != "NONE"
        or root["apply_supported"] is not False
    ):
        raise PlanError("migration plan must remain advisory and non-mutating")
    source = _exact_object(
        root["source"],
        {
            "inventory_sha256",
            "inventory_row_count",
            "shadow_bindings_sha256",
            "shadow_binding_count",
            "resolved_binding_count",
            "unresolved_binding_count",
            "q08_policy_binding",
        },
        "migration plan source",
    )
    _sha(source["inventory_sha256"], "source.inventory_sha256")
    _sha(source["shadow_bindings_sha256"], "source.shadow_bindings_sha256")
    for key in (
        "inventory_row_count",
        "shadow_binding_count",
        "resolved_binding_count",
        "unresolved_binding_count",
    ):
        if type(source[key]) is not int or source[key] < 0:
            raise PlanError(f"source.{key} must be a non-negative integer")
    policy_binding = _exact_object(
        source["q08_policy_binding"],
        {"path", "file_sha256", "canonical_sha256", "policy_version"},
        "migration plan source.q08_policy_binding",
    )
    if policy_binding != canonical_q08_policy_binding():
        raise PlanError("source.q08_policy_binding is stale or non-canonical")
    normalized_manifest = normalize_shadow_bindings(root["shadow_bindings"])
    if normalized_manifest != root["shadow_bindings"]:
        raise PlanError("shadow_bindings must use the canonical normalized form")
    if normalized_manifest["policy_binding"] != policy_binding:
        raise PlanError("shadow_bindings and source policy bindings differ")
    if source["shadow_bindings_sha256"] != canonical_sha256(normalized_manifest):
        raise PlanError("source.shadow_bindings_sha256 mismatch")
    if source["shadow_binding_count"] != len(normalized_manifest["bindings"]):
        raise PlanError("source.shadow_binding_count mismatch")
    bindings_by_sha = {
        canonical_sha256(binding): binding
        for binding in normalized_manifest["bindings"]
    }
    if len(bindings_by_sha) != len(normalized_manifest["bindings"]):
        raise PlanError("shadow_bindings contain duplicate semantic identities")
    if type(root["unresolved_bindings"]) is not list or type(root["proposals"]) is not list:
        raise PlanError("unresolved_bindings and proposals must be arrays")
    unresolved_keys = {
        "binding_sha256",
        "selector_type",
        "selector",
        "resolution",
        "candidate_work_item_ids",
    }
    unresolved_order: list[tuple[str, str, str, str]] = []
    unresolved_binding_hashes: set[str] = set()
    for index, raw in enumerate(root["unresolved_bindings"]):
        row = _exact_object(raw, unresolved_keys, f"unresolved_bindings[{index}]")
        if row["selector_type"] not in SELECTOR_TYPES:
            raise PlanError(f"unresolved_bindings[{index}] selector_type unsupported")
        _nonempty_string(row["selector"], f"unresolved_bindings[{index}].selector")
        if row["resolution"] not in RESOLUTION_STATES:
            raise PlanError(f"unresolved_bindings[{index}] resolution unsupported")
        _sorted_string_set(
            row["candidate_work_item_ids"],
            f"unresolved_bindings[{index}].candidate_work_item_ids",
        )
        binding_sha = _sha(
            row["binding_sha256"], f"unresolved_bindings[{index}].binding_sha256"
        )
        binding = bindings_by_sha.get(binding_sha)
        if binding is None:
            raise PlanError(
                f"unresolved_bindings[{index}] is absent from shadow_bindings"
            )
        if (
            row["selector_type"] != binding["selector_type"]
            or row["selector"] != binding["selector"]
        ):
            raise PlanError(
                f"unresolved_bindings[{index}] selector does not match its binding"
            )
        if binding_sha in unresolved_binding_hashes:
            raise PlanError("unresolved binding identity is duplicated")
        unresolved_binding_hashes.add(binding_sha)
        unresolved_order.append(
            (row["resolution"], row["selector_type"], row["selector"], row["binding_sha256"])
        )
    if unresolved_order != sorted(unresolved_order):
        raise PlanError("unresolved bindings are not deterministically sorted")
    proposal_keys = {
        "work_item_id",
        "lineage_key",
        "legacy_verdict",
        "inventory_disposition",
        "inventory_priority",
        "targets",
        "shadow",
        "discordance",
        "proposed_overlay_state",
        "owner_authorization",
        "runtime_action",
        "reason_codes",
        "proposal_id",
    }
    proposal_ids: list[str] = []
    matched_binding_hashes: set[str] = set()
    for index, raw in enumerate(root["proposals"]):
        proposal = _exact_object(raw, proposal_keys, f"proposals[{index}]")
        item_id = _nonempty_string(proposal["work_item_id"], f"proposals[{index}].work_item_id")
        proposal_ids.append(item_id)
        _nonempty_string(proposal["lineage_key"], f"proposals[{index}].lineage_key")
        if proposal["legacy_verdict"] is not None and not isinstance(
            proposal["legacy_verdict"], str
        ):
            raise PlanError(f"proposals[{index}].legacy_verdict must be string or null")
        if proposal["inventory_disposition"] not in INVENTORY_DISPOSITIONS:
            raise PlanError(f"proposals[{index}].inventory_disposition unsupported")
        if proposal["inventory_priority"] not in INVENTORY_PRIORITIES:
            raise PlanError(f"proposals[{index}].inventory_priority unsupported")
        targets = proposal["targets"]
        if (
            type(targets) is not list
            or targets != sorted(targets)
            or len(targets) != len(set(targets))
            or any(target not in {"DXZ", "FTMO"} for target in targets)
        ):
            raise PlanError(f"proposals[{index}].targets must be a sorted target set")
        if proposal["discordance"] not in DISCORDANCE_STATES:
            raise PlanError(f"proposals[{index}] discordance unsupported")
        if proposal["proposed_overlay_state"] not in OVERLAY_STATES:
            raise PlanError(f"proposals[{index}] overlay state unsupported")
        if proposal["owner_authorization"] != "NONE" or proposal["runtime_action"] != "NONE":
            raise PlanError(f"proposals[{index}] attempts to authorize action")
        shadow = _exact_object(
            proposal["shadow"],
            {
                "binding_state",
                "binding_sha256",
                "decision_sha256",
                "verdict",
                "route",
            },
            f"proposals[{index}].shadow",
        )
        if shadow["binding_state"] not in {"MATCHED", "NOT_PROVIDED", "UNRESOLVED"}:
            raise PlanError(f"proposals[{index}].shadow.binding_state unsupported")
        if shadow["binding_state"] == "MATCHED":
            binding_sha = _sha(
                shadow["binding_sha256"],
                f"proposals[{index}].shadow.binding_sha256",
            )
            binding = bindings_by_sha.get(binding_sha)
            if binding is None:
                raise PlanError(
                    f"proposals[{index}].shadow is absent from shadow_bindings"
                )
            if binding_sha in matched_binding_hashes:
                raise PlanError("matched shadow binding identity is duplicated")
            matched_binding_hashes.add(binding_sha)
            decision = binding["decision"]
            decision_sha = _sha(
                shadow["decision_sha256"],
                f"proposals[{index}].shadow.decision_sha256",
            )
            if decision_sha != canonical_sha256(decision):
                raise PlanError(
                    f"proposals[{index}].shadow decision hash does not match its binding"
                )
            if shadow["verdict"] not in V3_VERDICTS:
                raise PlanError(f"proposals[{index}].shadow.verdict unsupported")
            if shadow["route"] != VERDICT_ROUTES[shadow["verdict"]]:
                raise PlanError(f"proposals[{index}].shadow verdict/route mismatch")
            if (
                shadow["verdict"] != decision["verdict"]
                or shadow["route"] != decision["route"]
            ):
                raise PlanError(
                    f"proposals[{index}].shadow does not match its semantic decision"
                )
        elif any(
            shadow[key] is not None
            for key in ("binding_sha256", "decision_sha256", "verdict", "route")
        ):
            raise PlanError(f"proposals[{index}].unmatched shadow must not claim a decision")
        _sorted_string_set(proposal["reason_codes"], f"proposals[{index}].reason_codes")
        declared = _sha(proposal["proposal_id"], f"proposals[{index}].proposal_id")
        unsigned = {key: child for key, child in proposal.items() if key != "proposal_id"}
        if declared != canonical_sha256(unsigned):
            raise PlanError(f"proposals[{index}].proposal_id mismatch")
    if proposal_ids != sorted(proposal_ids) or len(proposal_ids) != len(set(proposal_ids)):
        raise PlanError("proposals must be uniquely sorted by work_item_id")
    if matched_binding_hashes & unresolved_binding_hashes:
        raise PlanError("a shadow binding cannot be both matched and unresolved")
    if matched_binding_hashes | unresolved_binding_hashes != set(bindings_by_sha):
        raise PlanError("shadow binding identities are not completely accounted for")
    if source["inventory_row_count"] != len(root["proposals"]):
        raise PlanError("source.inventory_row_count mismatch")
    if source["unresolved_binding_count"] != len(root["unresolved_bindings"]):
        raise PlanError("source.unresolved_binding_count mismatch")
    if source["resolved_binding_count"] != sum(
        row["shadow"]["binding_state"] == "MATCHED" for row in root["proposals"]
    ):
        raise PlanError("source.resolved_binding_count mismatch")
    if source["shadow_binding_count"] != (
        source["resolved_binding_count"] + source["unresolved_binding_count"]
    ):
        raise PlanError("source.shadow_binding_count mismatch")
    summary = _exact_object(
        root["summary"],
        {
            "proposal_count",
            "discordance_counts",
            "overlay_state_counts",
            "matched_work_item_ids",
            "no_result_work_item_ids",
            "collision_blocked_work_item_ids",
        },
        "migration plan summary",
    )
    if summary["proposal_count"] != len(root["proposals"]):
        raise PlanError("migration plan proposal_count mismatch")
    if summary["discordance_counts"] != _full_counts(
        [row["discordance"] for row in root["proposals"]], DISCORDANCE_STATES
    ):
        raise PlanError("migration plan discordance_counts mismatch")
    if summary["overlay_state_counts"] != _full_counts(
        [row["proposed_overlay_state"] for row in root["proposals"]], OVERLAY_STATES
    ):
        raise PlanError("migration plan overlay_state_counts mismatch")
    for key in (
        "matched_work_item_ids",
        "no_result_work_item_ids",
        "collision_blocked_work_item_ids",
    ):
        _sorted_string_set(summary[key], f"summary.{key}")
        if any(item_id not in set(proposal_ids) for item_id in summary[key]):
            raise PlanError(f"summary.{key} references unknown work item")
    actual_matched = sorted(
        row["work_item_id"]
        for row in root["proposals"]
        if row["shadow"]["binding_state"] == "MATCHED"
    )
    actual_no_result = sorted(
        row["work_item_id"]
        for row in root["proposals"]
        if row["shadow"]["binding_state"] == "NOT_PROVIDED"
    )
    if summary["matched_work_item_ids"] != actual_matched:
        raise PlanError("summary.matched_work_item_ids mismatch")
    if summary["no_result_work_item_ids"] != actual_no_result:
        raise PlanError("summary.no_result_work_item_ids mismatch")
    declared_plan = _sha(root["plan_sha256"], "plan.plan_sha256")
    unsigned_plan = {key: child for key, child in root.items() if key != "plan_sha256"}
    if declared_plan != canonical_sha256(unsigned_plan):
        raise PlanError("plan_sha256 mismatch")
    return root


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--shadow-bindings", type=Path)
    parser.add_argument("--output", type=Path, help="Create-new JSON path (default: stdout)")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        inventory = load_json_file(args.inventory, context="Q08 migration inventory")
        plan = build_migration_plan(
            inventory,
            shadow_bindings=load_shadow_bindings(args.shadow_bindings),
        )
        if args.output is not None:
            write_create_new(plan, args.output)
        else:
            sys.stdout.buffer.write(render_json_bytes(plan))
        return 0
    except (InventoryError, PlanError, OSError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
