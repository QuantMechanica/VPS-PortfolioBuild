import copy
import hashlib
import json
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm import target_rulepacks as rulepacks  # noqa: E402


DXZ_ID = "DXZ_BETTER_BOOK_V1"
FTMO_ID = "FTMO_2S_100K_SWING_V1"


def _by_id(rows: list[dict], key: str) -> dict[str, dict]:
    return {row[key]: row for row in rows}


def test_loads_both_versioned_rulepacks_with_canonical_hashes() -> None:
    ids = rulepacks.list_rulepack_ids()
    assert DXZ_ID in ids
    assert FTMO_ID in ids

    loaded = {pack.rulepack_id: pack for pack in rulepacks.validate_all()}
    assert {DXZ_ID, FTMO_ID} <= set(loaded)
    for pack in loaded.values():
        assert pack.profile_version == 1
        assert pack.as_of == "2026-07-29"
        assert len(pack.canonical_sha256) == 64
        assert pack.canonical_sha256 == hashlib.sha256(pack.canonical_payload).hexdigest()
        assert pack.canonical_sha256 == rulepacks.canonical_sha256(pack.as_dict())


def test_canonical_payload_is_order_independent_and_change_sensitive() -> None:
    payload = rulepacks.load_rulepack(DXZ_ID).as_dict()
    reversed_payload = dict(reversed(list(payload.items())))

    assert rulepacks.canonical_json_bytes(payload) == rulepacks.canonical_json_bytes(
        reversed_payload
    )

    changed = copy.deepcopy(payload)
    changed["as_of"] = "2026-07-28"
    assert rulepacks.canonical_sha256(changed) != rulepacks.canonical_sha256(payload)


def test_loaded_payload_is_detached_from_stored_canonical_identity() -> None:
    pack = rulepacks.load_rulepack(FTMO_ID)
    detached = pack.as_dict()
    detached["account_or_program"] = "mutated"

    assert json.loads(pack.canonical_payload)["account_or_program"] != "mutated"
    assert pack.canonical_sha256 == hashlib.sha256(pack.canonical_payload).hexdigest()


def test_json_schema_is_valid_and_names_the_same_contract() -> None:
    schema = json.loads(rulepacks.DEFAULT_SCHEMA_PATH.read_text(encoding="utf-8"))

    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["properties"]["schema_version"]["const"] == rulepacks.SCHEMA_VERSION
    assert schema["properties"]["deployment_boundary"]["$ref"].endswith(
        "deploymentBoundary"
    )


def test_dxz_provider_rules_and_internal_loss_guardrails_are_separate() -> None:
    payload = rulepacks.load_rulepack(DXZ_ID).as_dict()
    official = _by_id(payload["official_rules"], "rule_id")
    internal = _by_id(payload["internal_guardrails"], "guardrail_id")

    assert "dxz_daily_loss_limit" not in official
    assert "dxz_total_loss_limit" not in official
    assert internal["qm_dxz_daily_loss_guardrail"]["parameters"] == {
        "percent_of_reference_equity": "5",
        "provider_rule_publicly_verified": False,
    }
    assert internal["qm_dxz_total_loss_guardrail"]["parameters"] == {
        "percent_of_reference_equity": "20",
        "provider_rule_publicly_verified": False,
    }
    assert all(
        row["classification"] == rulepacks.INTERNAL_CLASSIFICATION
        for row in internal.values()
    )
    assert official["dxz_darwin_target_var"]["parameters"] == {
        "confidence_percent": "95",
        "minimum_monthly_percent": "3.25",
        "maximum_monthly_percent": "6.5",
    }


def test_ftmo_swing_rulepack_pins_current_two_step_rules() -> None:
    payload = rulepacks.load_rulepack(FTMO_ID).as_dict()
    official = _by_id(payload["official_rules"], "rule_id")

    assert official["ftmo_2s_phase1_profit_target"]["parameters"][
        "percent_of_initial_simulated_capital"
    ] == "10"
    assert official["ftmo_2s_verification_profit_target"]["parameters"][
        "percent_of_initial_simulated_capital"
    ] == "5"
    assert official["ftmo_2s_max_daily_loss"]["parameters"]["timezone"] == "Europe/Prague"
    assert official["ftmo_2s_maximum_loss"]["parameters"]["model"] == "STATIC_INITIAL"
    assert official["ftmo_2s_minimum_trading_days"]["parameters"] == {
        "days": 4,
        "timezone": "Europe/Prague",
        "qualifying_action": "POSITION_OPENED",
    }
    assert official["ftmo_swing_news"]["parameters"][
        "ftmo_account_swing_restricted"
    ] is False
    assert official["ftmo_swing_weekend"]["parameters"][
        "ftmo_account_swing_restricted"
    ] is False


def test_q08_soft_is_evidence_debt_not_clean_pass() -> None:
    for rulepack_id in (DXZ_ID, FTMO_ID):
        policy = rulepacks.load_rulepack(rulepack_id).as_dict()["q08_evidence_policy"]
        assert policy["soft_admission_status"] == "TARGET_ELIGIBLE_WITH_EVIDENCE_DEBT"
        assert policy["not_applicable_requires_declared_archetype"] is True
        assert set(policy["hard_block_dimensions"]).isdisjoint(
            policy["soft_evidence_debt_dimensions"]
        )
        assert "no universal hard-block dimension is present" in policy[
            "compensation_requirements"
        ] or "soft reason is not a universal hard-block dimension" in policy[
            "compensation_requirements"
        ]


def test_rulepacks_are_explicitly_non_runtime_and_non_mutating() -> None:
    for rulepack_id in (DXZ_ID, FTMO_ID):
        boundary = rulepacks.load_rulepack(rulepack_id).as_dict()["deployment_boundary"]
        assert boundary["runtime_integration"] == "NOT_IMPLEMENTED"
        assert boundary["deploy_authorization"] == "OWNER_ONLY"
        assert boundary["factory_action_authorized"] is False
        assert boundary["mt5_action_authorized"] is False


def test_parser_rejects_duplicate_keys_and_float_literals(tmp_path: Path) -> None:
    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text('{"rulepack_id":"A","rulepack_id":"B"}', encoding="utf-8")
    with pytest.raises(rulepacks.RulepackValidationError, match="duplicate JSON key"):
        rulepacks.load_rulepack_path(duplicate)

    payload = rulepacks.load_rulepack(DXZ_ID).as_dict()
    payload["internal_guardrails"][0]["parameters"]["bad_float"] = 1.25
    with pytest.raises(rulepacks.RulepackValidationError, match="float values are forbidden"):
        rulepacks.validate_rulepack(payload)


def test_validator_rejects_authority_leaks_and_runtime_activation() -> None:
    dxz = rulepacks.load_rulepack(DXZ_ID).as_dict()
    dxz["internal_guardrails"][0]["classification"] = "OFFICIAL_PROVIDER"
    with pytest.raises(rulepacks.RulepackValidationError, match="must equal INTERNAL_QM_POLICY"):
        rulepacks.validate_rulepack(dxz)

    ftmo = rulepacks.load_rulepack(FTMO_ID).as_dict()
    ftmo["deployment_boundary"]["runtime_integration"] = "ENABLED"
    with pytest.raises(rulepacks.RulepackValidationError, match="must remain NOT_IMPLEMENTED"):
        rulepacks.validate_rulepack(ftmo)


def test_validator_rejects_target_rule_tampering_and_unofficial_domains() -> None:
    ftmo = rulepacks.load_rulepack(FTMO_ID).as_dict()
    rules = _by_id(ftmo["official_rules"], "rule_id")
    rules["ftmo_2s_max_daily_loss"]["parameters"][
        "percent_of_initial_simulated_capital"
    ] = "6"
    with pytest.raises(rulepacks.RulepackValidationError, match="must equal '5'"):
        rulepacks.validate_rulepack(ftmo)

    dxz = rulepacks.load_rulepack(DXZ_ID).as_dict()
    dxz["official_sources"][0]["url"] = "https://example.com/not-official"
    with pytest.raises(rulepacks.RulepackValidationError, match="DXZ official sources"):
        rulepacks.validate_rulepack(dxz)


def test_ftmo_snapshot_contract_is_required_hash_bound_and_fresh() -> None:
    missing = rulepacks.load_rulepack(FTMO_ID).as_dict()
    for key in rulepacks.SOURCE_SNAPSHOT_KEYS:
        missing["official_sources"][0].pop(key)
    with pytest.raises(rulepacks.RulepackValidationError, match="require hash-bound snapshots"):
        rulepacks.validate_rulepack(missing)

    tampered = rulepacks.load_rulepack(FTMO_ID).as_dict()
    for source in tampered["official_sources"]:
        source["snapshot_sha256"] = "0" * 64
    with pytest.raises(rulepacks.RulepackValidationError, match="snapshot hash mismatch"):
        rulepacks.validate_rulepack(tampered)

    stale = rulepacks.load_rulepack(FTMO_ID).as_dict()
    for source in stale["official_sources"]:
        source["retrieved_on"] = "2026-07-20"
        source["retrieved_at_utc"] = "2026-07-20T19:25:39Z"
    with pytest.raises(rulepacks.RulepackValidationError, match="snapshot age must be 0..7"):
        rulepacks.validate_rulepack(stale)


def test_rulepack_filename_must_match_payload_identity(tmp_path: Path) -> None:
    payload = rulepacks.load_rulepack(DXZ_ID).as_dict()
    target = tmp_path / f"{FTMO_ID}.json"
    target.write_text(json.dumps(payload), encoding="utf-8")

    with pytest.raises(rulepacks.RulepackValidationError, match="filename requested"):
        rulepacks.load_rulepack(FTMO_ID, rulepack_dir=tmp_path)


def test_additive_writer_round_trips_and_never_overwrites(tmp_path: Path) -> None:
    payload = rulepacks.load_rulepack(FTMO_ID).as_dict()
    payload["rulepack_id"] = "FTMO_2S_100K_SWING_V2"
    payload["profile_version"] = 2

    written = rulepacks.write_rulepack(payload, rulepack_dir=tmp_path)
    target = tmp_path / "FTMO_2S_100K_SWING_V2.json"
    original_bytes = target.read_bytes()

    assert written.rulepack_id == "FTMO_2S_100K_SWING_V2"
    assert written.as_dict() == payload
    assert written.canonical_sha256 == rulepacks.canonical_sha256(payload)
    with pytest.raises(FileExistsError):
        rulepacks.write_rulepack(payload, rulepack_dir=tmp_path)
    assert target.read_bytes() == original_bytes
