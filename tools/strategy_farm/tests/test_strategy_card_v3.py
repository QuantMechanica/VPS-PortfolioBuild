from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import strategy_card_v3 as cards  # noqa: E402


def _draft() -> dict:
    return {
        "schema_version": cards.CARD_SCHEMA_VERSION,
        "card_id": "CARD-INTRADAY-0001",
        "card_version": 1,
        "source_authorization_id": "SRC-AUTH-0001",
        "source_sha256": "a" * 64,
        "mechanism": (
            "A bounded opening-range displacement followed by reduced spread is expected "
            "to retain same-session directional continuation."
        ),
        "falsifiable_prediction": (
            "Net costed return per independent trading day is positive in sealed OOS "
            "and remains positive under the preregistered spread stress."
        ),
        "falsifier": (
            "The mechanism is falsified when sealed OOS costed expectancy is non-positive "
            "or the latency-spread stress erases the edge."
        ),
        "kill_criteria": [
            "Retire after one measured hard Q08 contradiction.",
            "Retire when the independent-trial budget is exhausted without support.",
        ],
        "assumptions": [
            "The bound session clock maps broker time across DST without ambiguity.",
            "The cost model covers spread, commission, slippage and swap where applicable.",
        ],
        "primary_archetype": "intraday",
        "independent_cluster_unit": "trading_day",
        "degrees_of_freedom": {
            "declared_count": 2,
            "components": [
                {"name": "stop_distance", "count": 1},
                {"name": "entry_window", "count": 1},
            ],
        },
        "trial_budget": {
            "budget_id": "TRIAL-BUDGET-0001",
            "max_independent_trials": 2,
            "max_parameter_cells": 2,
        },
        "parameter_space": {
            "domains": [
                {
                    "name": "stop_atr",
                    "value_type": "DECIMAL",
                    "values": ["2", "1.5"],
                },
                {
                    "name": "entry_lookback",
                    "value_type": "INTEGER",
                    "values": [20, 10],
                },
            ],
            "cells": [
                {
                    "cell_id": "PARAM-CELL-0002",
                    "assignments": {"stop_atr": "2", "entry_lookback": 20},
                },
                {
                    "cell_id": "PARAM-CELL-0001",
                    "assignments": {"stop_atr": "1.5", "entry_lookback": 10},
                },
            ],
        },
        "symbol": "EURUSD",
        "timeframe": "M15",
        "data_cut": {
            "cut_id": "DATA-CUT-0001",
            "dataset_sha256": "b" * 64,
            "cut_at_utc": "2026-06-30T23:59:59Z",
        },
        "dev_seal": {
            "seal_id": "DEV-SEAL-0001",
            "partition_sha256": "c" * 64,
            "range_start_utc": "2020-01-01T00:00:00Z",
            "range_end_utc": "2024-12-31T23:59:59Z",
            "sealed_at_utc": "2026-07-01T00:00:00Z",
        },
        "oos_seal": {
            "seal_id": "OOS-SEAL-0001",
            "partition_sha256": "d" * 64,
            "range_start_utc": "2025-01-01T00:00:00Z",
            "range_end_utc": "2026-06-30T23:59:59Z",
            "sealed_at_utc": "2026-07-01T00:00:01Z",
        },
        "execution_assumptions": [
            "Orders are evaluated in account currency using the bound execution model.",
            "No unbound calendar or symbol specification may be substituted.",
        ],
        "execution_dependencies": [
            {
                "dependency_id": "SYMBOL-SPEC-0001",
                "kind": "SYMBOL_SPEC",
                "version": "darwinex-demo-2026-06",
                "sha256": "e" * 64,
            },
            {
                "dependency_id": "COST-MODEL-0001",
                "kind": "COST_MODEL",
                "version": "venue-cost-v1",
                "sha256": "f" * 64,
            },
        ],
        "author": {
            "authority": "AGENT",
            "identity": "research-agent-01",
            "authored_at_utc": "2026-07-29T12:00:00Z",
        },
    }


def _sealed() -> dict:
    return cards.build_card(_draft())


def test_build_card_binds_schema_policy_cells_and_full_payload() -> None:
    card = _sealed()
    cards.validate_card(card)
    bindings = cards.load_contract_bindings()

    assert card["contract_bindings"] == bindings.as_dict()
    assert card["card_sha256"] == cards.canonical_card_hash(card)
    assert [row["name"] for row in card["parameter_space"]["domains"]] == [
        "entry_lookback",
        "stop_atr",
    ]
    assert [row["cell_id"] for row in card["parameter_space"]["cells"]] == [
        "PARAM-CELL-0001",
        "PARAM-CELL-0002",
    ]
    for cell in card["parameter_space"]["cells"]:
        assert cell["cell_sha256"] == cards.semantic_json_sha256(
            {"cell_id": cell["cell_id"], "assignments": cell["assignments"]}
        )


def test_builder_is_deterministic_across_nonsemantic_ordering() -> None:
    first = _draft()
    second = copy.deepcopy(first)
    second = dict(reversed(list(second.items())))
    for field in ("kill_criteria", "assumptions", "execution_assumptions"):
        second[field].reverse()
    second["degrees_of_freedom"]["components"].reverse()
    second["parameter_space"]["domains"].reverse()
    for domain in second["parameter_space"]["domains"]:
        domain["values"].reverse()
    second["parameter_space"]["cells"].reverse()
    for cell in second["parameter_space"]["cells"]:
        cell["assignments"] = dict(reversed(list(cell["assignments"].items())))
    second["execution_dependencies"].reverse()

    built_first = cards.build_card(first)
    built_second = cards.build_card(second)
    assert built_first == built_second
    assert cards.canonical_json_bytes(built_first) == cards.canonical_json_bytes(
        built_second
    )


def test_create_new_write_load_round_trip_and_no_overwrite(tmp_path: Path) -> None:
    destination = tmp_path / "card.json"
    receipt = cards.write_new_card(destination, _draft())
    first_bytes = destination.read_bytes()
    loaded = cards.load_card(destination)

    assert receipt.card_id == loaded["card_id"]
    assert receipt.card_version == loaded["card_version"]
    assert receipt.card_sha256 == loaded["card_sha256"]
    assert receipt.size_bytes == len(first_bytes)
    assert first_bytes == cards.canonical_json_bytes(loaded, file_form=True)

    replacement = _draft()
    replacement["mechanism"] = "A different post-result mechanism must be a new card."
    with pytest.raises(cards.StrategyCardError, match="refusing to overwrite"):
        cards.write_new_card(destination, replacement)
    assert destination.read_bytes() == first_bytes


def test_writer_requires_an_existing_parent_directory(tmp_path: Path) -> None:
    destination = tmp_path / "not-created" / "card.json"
    with pytest.raises(cards.StrategyCardError, match="parent directory does not exist"):
        cards.write_new_card(destination, _draft())
    assert not destination.parent.exists()


def test_writer_retains_post_create_failure_fail_closed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    destination = tmp_path / "ambiguous-card.json"

    def fail_fsync(_descriptor: int) -> None:
        raise OSError("simulated durability failure")

    monkeypatch.setattr(cards.os, "fsync", fail_fsync)
    with pytest.raises(OSError, match="simulated durability failure"):
        cards.write_new_card(destination, _draft())

    retained = destination.read_bytes()
    assert retained
    with pytest.raises(cards.StrategyCardError, match="refusing to overwrite"):
        cards.write_new_card(destination, _draft())
    assert destination.read_bytes() == retained


def test_duplicate_keys_and_noncanonical_file_bytes_fail_closed(tmp_path: Path) -> None:
    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text('{"card_id":"first-card","card_id":"second-card"}\n', encoding="utf-8")
    with pytest.raises(cards.StrategyCardError, match="duplicate JSON key"):
        cards.load_card(duplicate)

    pretty = tmp_path / "pretty.json"
    pretty.write_text(json.dumps(_sealed(), indent=2) + "\n", encoding="utf-8")
    with pytest.raises(cards.StrategyCardError, match="not canonical"):
        cards.load_card(pretty)


def test_card_and_cell_hash_tampering_fail_closed() -> None:
    card = _sealed()
    card["mechanism"] = "Tampered mechanism."
    with pytest.raises(cards.StrategyCardError, match="card_sha256 mismatch"):
        cards.validate_card(card)

    cell_tamper = _sealed()
    cell_tamper["parameter_space"]["cells"][0]["assignments"]["entry_lookback"] = 20
    with pytest.raises(cards.StrategyCardError, match="cell_sha256 mismatch"):
        cards.validate_card(cell_tamper)


def test_identity_and_version_are_inside_immutable_card_hash() -> None:
    for field, value in (("card_id", "CARD-INTRADAY-9999"), ("card_version", 2)):
        card = _sealed()
        card[field] = value
        with pytest.raises(cards.StrategyCardError, match="card_sha256 mismatch"):
            cards.validate_card(card)


def test_g0_or_approval_fields_are_not_part_of_the_card_contract() -> None:
    for forbidden_key in ("g0_status", "approval", "decision"):
        draft = _draft()
        draft[forbidden_key] = "APPROVED"
        with pytest.raises(cards.StrategyCardError, match="key set mismatch"):
            cards.build_card(draft)

    nested = _draft()
    nested["author"]["decision"] = "APPROVED"
    with pytest.raises(cards.StrategyCardError, match="author key set mismatch"):
        cards.build_card(nested)


def test_extra_keys_and_floating_point_values_fail_closed() -> None:
    extra = _draft()
    extra["parameter_space"]["domains"][0]["after_result_default"] = "2"
    with pytest.raises(cards.StrategyCardError, match="key set mismatch"):
        cards.build_card(extra)

    floating = _draft()
    floating["parameter_space"]["domains"][0]["values"] = [1.5]
    with pytest.raises(cards.StrategyCardError, match="floating-point"):
        cards.build_card(floating)


def test_q08_archetype_must_be_canonical_and_cluster_unit_must_match_policy() -> None:
    alias = _draft()
    alias["primary_archetype"] = "session"
    with pytest.raises(cards.StrategyCardError, match="canonical archetype"):
        cards.build_card(alias)

    mismatch = _draft()
    mismatch["independent_cluster_unit"] = "holding_period"
    with pytest.raises(cards.StrategyCardError, match="does not match Q08 policy"):
        cards.build_card(mismatch)


def test_bound_policy_and_schema_hashes_cannot_be_replaced() -> None:
    policy_tamper = _sealed()
    policy_tamper["contract_bindings"]["q08_policy_sha256"] = "0" * 64
    with pytest.raises(cards.StrategyCardError, match="Q08 policy hash binding mismatch"):
        cards.validate_card(policy_tamper)

    schema_tamper = _sealed()
    schema_tamper["contract_bindings"]["strategy_card_schema_sha256"] = "0" * 64
    with pytest.raises(cards.StrategyCardError, match="schema hash binding mismatch"):
        cards.validate_card(schema_tamper)


@pytest.mark.parametrize(
    ("mutator", "message"),
    [
        (
            lambda draft: draft["dev_seal"].update(
                {"range_end_utc": "2025-02-01T00:00:00Z"}
            ),
            "overlap",
        ),
        (
            lambda draft: draft["oos_seal"].update(
                {"range_end_utc": "2026-07-01T00:00:00Z"}
            ),
            "exceeds the bound data cut",
        ),
        (
            lambda draft: draft["oos_seal"].update(
                {"sealed_at_utc": "2026-07-30T00:00:00Z"}
            ),
            "cannot postdate card authorship",
        ),
        (
            lambda draft: draft["oos_seal"].update(
                {"sealed_at_utc": "2026-01-01T00:00:00Z"}
            ),
            "cannot be sealed before",
        ),
    ],
)
def test_data_cut_and_dev_oos_seals_are_chronological(mutator, message: str) -> None:
    draft = _draft()
    mutator(draft)
    with pytest.raises(cards.StrategyCardError, match=message):
        cards.build_card(draft)


def test_degrees_of_freedom_must_reconcile_and_cover_variable_domains() -> None:
    wrong_sum = _draft()
    wrong_sum["degrees_of_freedom"]["declared_count"] = 3
    with pytest.raises(cards.StrategyCardError, match="does not equal component sum"):
        cards.build_card(wrong_sum)

    underdeclared = _draft()
    underdeclared["degrees_of_freedom"]["components"] = [
        {"name": "entry_window", "count": 1}
    ]
    underdeclared["degrees_of_freedom"]["declared_count"] = 1
    with pytest.raises(cards.StrategyCardError, match="variable parameter-domain count"):
        cards.build_card(underdeclared)


def test_trial_budget_bounds_declared_parameter_cells() -> None:
    for field in ("max_independent_trials", "max_parameter_cells"):
        draft = _draft()
        draft["trial_budget"][field] = 1
        with pytest.raises(cards.StrategyCardError, match=field):
            cards.build_card(draft)


def test_parameter_domains_are_typed_canonical_and_cells_are_complete() -> None:
    bool_as_integer = _draft()
    integer_domain = next(
        row
        for row in bool_as_integer["parameter_space"]["domains"]
        if row["name"] == "entry_lookback"
    )
    integer_domain["values"] = [True, 10]
    with pytest.raises(cards.StrategyCardError, match="not boolean"):
        cards.build_card(bool_as_integer)

    noncanonical_decimal = _draft()
    decimal_domain = next(
        row
        for row in noncanonical_decimal["parameter_space"]["domains"]
        if row["name"] == "stop_atr"
    )
    decimal_domain["values"] = ["1.50", "2"]
    with pytest.raises(cards.StrategyCardError, match="not canonical"):
        cards.build_card(noncanonical_decimal)

    missing_assignment = _draft()
    del missing_assignment["parameter_space"]["cells"][0]["assignments"]["stop_atr"]
    with pytest.raises(cards.StrategyCardError, match="assignments key set mismatch"):
        cards.build_card(missing_assignment)

    outside_domain = _draft()
    outside_domain["parameter_space"]["cells"][0]["assignments"]["entry_lookback"] = 30
    with pytest.raises(cards.StrategyCardError, match="outside its declared domain"):
        cards.build_card(outside_domain)


def test_duplicate_parameter_assignments_are_not_independent_cells() -> None:
    draft = _draft()
    draft["parameter_space"]["cells"][1]["assignments"] = copy.deepcopy(
        draft["parameter_space"]["cells"][0]["assignments"]
    )
    with pytest.raises(cards.StrategyCardError, match="must not duplicate assignments"):
        cards.build_card(draft)


def test_schema_is_versioned_closed_and_has_no_embedded_approval_surface() -> None:
    schema = json.loads(cards.DEFAULT_SCHEMA_PATH.read_text(encoding="utf-8"))
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["additionalProperties"] is False
    assert schema["properties"]["schema_version"]["const"] == cards.CARD_SCHEMA_VERSION
    assert set(schema["required"]) == cards._TOP_LEVEL_KEYS
    assert {"g0_status", "approval", "decision"}.isdisjoint(schema["properties"])
    assert schema["properties"]["card_sha256"]["$ref"] == "#/$defs/sha256"

    for definition_name, definition in schema["$defs"].items():
        if definition.get("type") == "object" and definition_name != "parameter_cell":
            assert definition.get("additionalProperties") is False


def test_schema_and_policy_hashes_are_semantic_not_formatting_hashes(tmp_path: Path) -> None:
    schema = json.loads(cards.DEFAULT_SCHEMA_PATH.read_text(encoding="utf-8"))
    policy = json.loads(cards.DEFAULT_Q08_POLICY_PATH.read_text(encoding="utf-8"))
    pretty_schema = tmp_path / "schema.json"
    pretty_policy = tmp_path / "policy.json"
    pretty_schema.write_text(json.dumps(schema, indent=4), encoding="utf-8")
    pretty_policy.write_text(json.dumps(policy, indent=4), encoding="utf-8")

    expected = cards.load_contract_bindings()
    reformatted = cards.load_contract_bindings(
        schema_path=pretty_schema,
        q08_policy_path=pretty_policy,
    )
    assert expected.as_dict() == reformatted.as_dict()
