from __future__ import annotations

import copy
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

import pytest


TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import q08_v3_migration_inventory as inventory_subject  # noqa: E402
import q08_v3_migration_plan as subject  # noqa: E402


WORK_ITEMS_SCHEMA = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    setfile_path TEXT NOT NULL,
    status TEXT NOT NULL,
    verdict TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
"""


def _insert(connection: sqlite3.Connection, item_id: str, **overrides: Any) -> None:
    row: dict[str, Any] = {
        "id": item_id,
        "kind": "backtest",
        "phase": "Q08",
        "ea_id": "QM5_200",
        "symbol": "EURUSD.DWX",
        "setfile_path": f"sets/{item_id}.set",
        "status": "done",
        "verdict": "PASS",
        "attempt_count": 1,
        "parent_task_id": None,
        "evidence_path": None,
        "claimed_by": None,
        "payload_json": "{}",
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-01T01:00:00Z",
    }
    row.update(overrides)
    connection.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
        ) VALUES(
          :id,:kind,:phase,:ea_id,:symbol,:setfile_path,:status,:verdict,:attempt_count,
          :parent_task_id,:evidence_path,:claimed_by,:payload_json,:created_at,:updated_at
        )
        """,
        row,
    )


def _subtest_results(verdict: str) -> list[dict[str, str]]:
    policy = subject.load_q08_policy(subject.DEFAULT_Q08_POLICY_PATH)
    archetype = policy.resolve_archetype("trend")
    assert archetype is not None
    required = [
        row.test_id
        for row in (*policy.universal_tests, *archetype.tests)
        if row.requirement.value == "REQUIRED"
    ]
    statuses = {test_id: "PASS" for test_id in required}
    if verdict == "CONDITIONAL":
        statuses["temporal_stability"] = "FAIL"
    elif verdict == "INSUFFICIENT":
        statuses.pop("identity_lineage")
    elif verdict == "CONTRADICTED":
        statuses["cost_adjusted_edge"] = "FAIL"
    elif verdict == "INVALID":
        statuses["identity_lineage"] = "FAIL"
    elif verdict != "SUPPORTED":
        raise AssertionError(verdict)
    return [
        {"test_id": test_id, "status": status, "detail": "fixture"}
        for test_id, status in sorted(statuses.items())
    ]


def _decision(verdict: str) -> dict[str, Any]:
    policy = subject.load_q08_policy(subject.DEFAULT_Q08_POLICY_PATH)
    decision = subject.aggregate_shadow(
        archetype="trend",
        results=_subtest_results(verdict),
        policy=policy,
    ).to_dict()
    assert decision["verdict"] == verdict
    return decision


def _bindings(*rows: tuple[str, str, str]) -> dict[str, Any]:
    return {
        "schema_version": subject.SHADOW_BINDINGS_SCHEMA_VERSION,
        "bindings": [
            {
                "selector_type": selector_type,
                "selector": selector,
                "subtest_results": _subtest_results(verdict),
                "decision": _decision(verdict),
            }
            for selector_type, selector, verdict in rows
        ],
    }


def _inventory(tmp_path: Path) -> dict[str, Any]:
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as connection:
        connection.executescript(WORK_ITEMS_SCHEMA)
        _insert(connection, "q-pass", verdict="PASS")
        _insert(connection, "q-soft", ea_id="QM5_201", verdict="FAIL_SOFT")
        _insert(connection, "q-hard", ea_id="QM5_202", verdict="FAIL_HARD")
        _insert(
            connection,
            "q-infra",
            ea_id="QM5_203",
            status="failed",
            verdict="INFRA_FAIL",
        )
        _insert(connection, "q-no-result", ea_id="QM5_204", verdict="PASS")
        _insert(
            connection,
            "q-superseded",
            ea_id="QM5_205",
            verdict="SUPERSEDED_DUPLICATE",
        )
        _insert(
            connection,
            "q-invalid",
            ea_id="QM5_206",
            verdict="UNKNOWN",
        )
        connection.commit()
    return inventory_subject.build_inventory(db, source_label="fixture/farm.sqlite")


def _assert_every_object_schema_is_closed_or_typed(node: Any) -> None:
    if isinstance(node, dict):
        if node.get("type") == "object":
            assert "additionalProperties" in node
        for child in node.values():
            _assert_every_object_schema_is_closed_or_typed(child)
    elif isinstance(node, list):
        for child in node:
            _assert_every_object_schema_is_closed_or_typed(child)


def test_plan_is_complete_content_addressed_and_byte_deterministic(tmp_path: Path) -> None:
    inventory = _inventory(tmp_path)
    bindings = _bindings(
        ("WORK_ITEM_ID", "q-pass", "SUPPORTED"),
        ("WORK_ITEM_ID", "q-soft", "SUPPORTED"),
        ("WORK_ITEM_ID", "q-hard", "SUPPORTED"),
        ("WORK_ITEM_ID", "q-infra", "SUPPORTED"),
    )
    first = subject.build_migration_plan(inventory, shadow_bindings=bindings)
    second = subject.build_migration_plan(inventory, shadow_bindings=bindings)

    assert first == second
    assert inventory_subject.render_json_bytes(first) == inventory_subject.render_json_bytes(second)
    assert first["plan_sha256"] == inventory_subject.canonical_sha256(
        {key: value for key, value in first.items() if key != "plan_sha256"}
    )
    assert first["plan_mode"] == "DRY_RUN_ONLY"
    assert first["owner_authorization"] == "NONE"
    assert first["runtime_action"] == "NONE"
    assert first["apply_supported"] is False
    assert first["shadow_bindings"] == subject.normalize_shadow_bindings(bindings)
    assert first["summary"]["proposal_count"] == inventory["summary"]["row_count"] == 7
    assert sum(first["summary"]["discordance_counts"].values()) == 7
    by_id = {row["work_item_id"]: row for row in first["proposals"]}
    assert by_id["q-pass"]["discordance"] == "AGREEMENT"
    assert by_id["q-soft"]["discordance"] == "UPGRADE_CANDIDATE"
    assert by_id["q-hard"]["discordance"] == "REVERSAL_REVIEW"
    assert by_id["q-infra"]["discordance"] == "INFRA_RESOLVED_REVIEW"
    assert by_id["q-no-result"]["discordance"] == "NO_V3_RESULT"
    assert by_id["q-superseded"]["discordance"] == "NOT_ELIGIBLE"
    assert by_id["q-invalid"]["discordance"] == "INVALID_BINDING"
    assert all(row["owner_authorization"] == "NONE" for row in first["proposals"])
    assert all(row["runtime_action"] == "NONE" for row in first["proposals"])


@pytest.mark.parametrize(
    ("legacy", "v3", "expected"),
    [
        ("PASS", "CONDITIONAL", "DOWNGRADE_REVIEW"),
        ("PASS", "CONTRADICTED", "REVERSAL_REVIEW"),
        ("PASS", "INVALID", "EVIDENCE_GAP"),
        ("FAIL_SOFT", "CONDITIONAL", "AGREEMENT"),
        ("FAIL_SOFT", "CONTRADICTED", "DOWNGRADE_REVIEW"),
        ("FAIL_HARD", "CONTRADICTED", "AGREEMENT"),
        ("FAIL", "SUPPORTED", "REVERSAL_REVIEW"),
        ("INFRA_FAIL", "INSUFFICIENT", "EVIDENCE_GAP"),
    ],
)
def test_discordance_matrix_is_directional(legacy: str, v3: str, expected: str) -> None:
    assert subject._discordance(legacy, v3) == expected


def test_alias_ambiguity_duplicate_resolution_and_no_match_fail_closed(
    tmp_path: Path,
) -> None:
    db = tmp_path / "collisions.sqlite"
    with sqlite3.connect(db) as connection:
        connection.executescript(WORK_ITEMS_SCHEMA)
        _insert(
            connection,
            "q-a",
            payload_json=json.dumps(
                {"candidate_lineage_key": "lineage-a", "aliases": ["shared"]},
                sort_keys=True,
            ),
        )
        _insert(
            connection,
            "q-b",
            ea_id="QM5_201",
            payload_json=json.dumps(
                {"candidate_lineage_key": "lineage-b", "aliases": ["shared"]},
                sort_keys=True,
            ),
        )
        _insert(
            connection,
            "q-c",
            ea_id="QM5_202",
            payload_json=json.dumps(
                {"candidate_lineage_key": "lineage-c", "aliases": ["alias-c"]},
                sort_keys=True,
            ),
        )
        connection.commit()
    inventory = inventory_subject.build_inventory(db)
    bindings = _bindings(
        ("ALIAS", "shared", "SUPPORTED"),
        ("WORK_ITEM_ID", "q-c", "SUPPORTED"),
        ("ALIAS", "alias-c", "CONDITIONAL"),
        ("WORK_ITEM_ID", "missing", "SUPPORTED"),
    )
    plan = subject.build_migration_plan(inventory, shadow_bindings=bindings)

    assert plan["source"]["resolved_binding_count"] == 0
    assert plan["source"]["unresolved_binding_count"] == 4
    assert {row["resolution"] for row in plan["unresolved_bindings"]} == {
        "NO_MATCH",
        "AMBIGUOUS_MATCH",
        "MULTIPLE_BINDINGS",
    }
    by_id = {row["work_item_id"]: row for row in plan["proposals"]}
    assert by_id["q-a"]["proposed_overlay_state"] == "COLLISION_HOLD"
    assert by_id["q-b"]["proposed_overlay_state"] == "COLLISION_HOLD"
    assert by_id["q-c"]["shadow"]["binding_state"] == "UNRESOLVED"
    assert by_id["q-c"]["discordance"] == "INVALID_BINDING"


def test_shadow_decision_and_plan_tampering_are_rejected(tmp_path: Path) -> None:
    inventory = _inventory(tmp_path)
    wrong_route = _decision("SUPPORTED")
    wrong_route["route"] = "RETRY"
    with pytest.raises(subject.PlanError, match="verdict/route mismatch"):
        subject.normalize_shadow_bindings(
            {
                "schema_version": subject.SHADOW_BINDINGS_SCHEMA_VERSION,
                "bindings": [
                    {
                        "selector_type": "WORK_ITEM_ID",
                        "selector": "q-pass",
                        "subtest_results": _subtest_results("SUPPORTED"),
                        "decision": wrong_route,
                    }
                ],
            }
        )

    duplicate = _bindings(
        ("WORK_ITEM_ID", "q-pass", "SUPPORTED"),
        ("WORK_ITEM_ID", "q-pass", "CONDITIONAL"),
    )
    with pytest.raises(subject.PlanError, match="duplicate shadow selector"):
        subject.normalize_shadow_bindings(duplicate)

    fabricated_policy = _bindings(("WORK_ITEM_ID", "q-pass", "SUPPORTED"))
    fabricated_policy["bindings"][0]["decision"]["policy_sha256"] = "0" * 64
    with pytest.raises(subject.PlanError, match="canonical policy"):
        subject.normalize_shadow_bindings(fabricated_policy)

    fabricated_semantics = _bindings(("WORK_ITEM_ID", "q-pass", "SUPPORTED"))
    fabricated_semantics["bindings"][0]["decision"]["supported_test_ids"].pop()
    with pytest.raises(subject.PlanError, match="aggregation semantics"):
        subject.normalize_shadow_bindings(fabricated_semantics)

    stale_results = _bindings(("WORK_ITEM_ID", "q-pass", "SUPPORTED"))
    stale_results["bindings"][0]["subtest_results"][0]["status"] = "FAIL"
    with pytest.raises(subject.PlanError, match="aggregation semantics"):
        subject.normalize_shadow_bindings(stale_results)

    plan = subject.build_migration_plan(inventory)
    drift = copy.deepcopy(plan)
    drift["proposals"][0]["discordance"] = "AGREEMENT"
    with pytest.raises(subject.PlanError, match="proposal_id mismatch"):
        subject.validate_plan(drift)


def test_self_hashed_plan_revalidates_embedded_shadow_semantics(tmp_path: Path) -> None:
    inventory = _inventory(tmp_path)
    plan = subject.build_migration_plan(
        inventory,
        shadow_bindings=_bindings(("WORK_ITEM_ID", "q-pass", "SUPPORTED")),
    )
    binding = plan["shadow_bindings"]["bindings"][0]
    binding["decision"]["supported_test_ids"].pop()
    new_binding_sha = inventory_subject.canonical_sha256(binding)
    new_decision_sha = inventory_subject.canonical_sha256(binding["decision"])
    proposal = next(
        row for row in plan["proposals"] if row["work_item_id"] == "q-pass"
    )
    proposal["shadow"]["binding_sha256"] = new_binding_sha
    proposal["shadow"]["decision_sha256"] = new_decision_sha
    proposal["proposal_id"] = inventory_subject.canonical_sha256(
        {key: value for key, value in proposal.items() if key != "proposal_id"}
    )
    plan["source"]["shadow_bindings_sha256"] = inventory_subject.canonical_sha256(
        plan["shadow_bindings"]
    )
    plan["plan_sha256"] = inventory_subject.canonical_sha256(
        {key: value for key, value in plan.items() if key != "plan_sha256"}
    )

    with pytest.raises(subject.PlanError, match="aggregation semantics"):
        subject.validate_plan(plan)


def test_inventory_bindings_and_plan_share_one_canonical_q08_policy(tmp_path: Path) -> None:
    inventory = _inventory(tmp_path)
    expected = inventory_subject.canonical_q08_policy_binding()
    assert inventory["source"]["q08_policy_binding"] == expected

    normalized = subject.normalize_shadow_bindings(
        _bindings(("WORK_ITEM_ID", "q-pass", "SUPPORTED"))
    )
    assert normalized["policy_binding"] == expected

    plan = subject.build_migration_plan(inventory, shadow_bindings=normalized)
    assert plan["source"]["q08_policy_binding"] == expected

    stale = copy.deepcopy(normalized)
    stale["policy_binding"]["canonical_sha256"] = "0" * 64
    with pytest.raises(subject.PlanError, match="stale or non-canonical"):
        subject.normalize_shadow_bindings(stale)


def test_invalid_inventory_hash_is_rejected_before_planning(tmp_path: Path) -> None:
    inventory = _inventory(tmp_path)
    inventory["inventory_sha256"] = "0" * 64
    with pytest.raises(subject.PlanError, match="invalid inventory"):
        subject.build_migration_plan(inventory)


def test_plan_json_schema_is_strict_and_loadable() -> None:
    schema_path = TOOLS / "schemas" / "q08_v3_migration_plan_v1.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["additionalProperties"] is False
    _assert_every_object_schema_is_closed_or_typed(schema)
