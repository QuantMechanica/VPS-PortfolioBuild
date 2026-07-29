from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import governance_records as records  # noqa: E402


def _source_payload() -> dict:
    return {
        "schema_version": records.SOURCE_AUTHORIZATION_V1,
        "authorization_id": "SRC-AUTH-0001",
        "source_ref": "https://example.test/strategy/1",
        "source_sha256": "a" * 64,
        "decision": "AUTHORIZED",
        "authority": "OWNER",
        "owner_identity": "owner@example.test",
        "decided_at_utc": "2026-07-29T10:00:00Z",
        "rationale": "Source reviewed and authorized for card extraction.",
    }


def _g0_payload(*, authority: str = "AGENT", decision: str = "RECOMMEND_APPROVE") -> dict:
    return {
        "schema_version": records.G0_DECISION_V1,
        "decision_id": "G0-DECISION-0001",
        "card_id": "QM-CARD-0001",
        "card_sha256": "b" * 64,
        "source_authorization_id": "SRC-AUTH-0001",
        "source_sha256": "a" * 64,
        "decision": decision,
        "authority": authority,
        "agent_identity": "research-agent-01" if authority == "AGENT" else None,
        "owner_identity": "owner@example.test" if authority == "OWNER" else None,
        "decided_at_utc": "2026-07-29T10:15:00Z",
        "rationale": "The evidence and card contract support this decision.",
    }


def _experiment_payload() -> dict:
    return {
        "schema_version": records.EXPERIMENT_RECORD_V1,
        "experiment_id": "EXP-20260729-0001",
        "independent_trial_id": "TRIAL-20260729-0001",
        "attempt_id": "ATTEMPT-20260729-0001",
        "attempt_kind": "ORIGINAL",
        "retry_of": None,
        "family_fingerprint": "c" * 64,
        "card_sha256": "b" * 64,
        "parameter_cell": {
            "cell_id": "PARAM-CELL-0001",
            "cell_sha256": "d" * 64,
        },
        "symbol": "EURUSD",
        "timeframe": "M15",
        "data_cut": {
            "cut_id": "DATA-CUT-0001",
            "dataset_sha256": "e" * 64,
            "cut_at_utc": "2026-06-30T23:59:59Z",
        },
        "dev_seal": {
            "seal_id": "DEV-SEAL-0001",
            "evidence_sha256": "f" * 64,
            "sealed_at_utc": "2026-07-01T00:00:00Z",
        },
        "oos_seal": {
            "seal_id": "OOS-SEAL-0001",
            "evidence_sha256": "0" * 64,
            "sealed_at_utc": "2026-07-01T00:00:01Z",
        },
        "trial_budget": {
            "budget_id": "TRIAL-BUDGET-0001",
            "independent_trial_ordinal": 1,
            "independent_trial_limit": 12,
        },
        "created_at_utc": "2026-07-29T10:30:00Z",
        "producer": {"authority": "AGENT", "identity": "experiment-agent-01"},
    }


def _retry_payload(original: dict) -> dict:
    payload = copy.deepcopy(original)
    payload.pop("record_sha256", None)
    payload.update(
        {
            "attempt_id": "ATTEMPT-20260729-0002",
            "attempt_kind": "INFRA_RETRY",
            "retry_of": original["attempt_id"],
            "created_at_utc": "2026-07-29T10:45:00Z",
        }
    )
    return payload


def _reseal(value: dict, *, prior_records=()) -> dict:
    payload = copy.deepcopy(value)
    payload.pop("record_sha256", None)
    return records.seal_record(payload, prior_records=prior_records)


def test_source_authorization_is_owner_only_and_hash_bound() -> None:
    sealed = records.seal_record(_source_payload())

    records.validate_source_authorization(sealed)
    assert sealed["record_sha256"] == records.canonical_record_hash(sealed)

    wrong_authority = _source_payload()
    wrong_authority["authority"] = "AGENT"
    with pytest.raises(records.GovernanceRecordError, match="authority=OWNER"):
        records.seal_record(wrong_authority)

    missing_owner = _source_payload()
    missing_owner["owner_identity"] = ""
    with pytest.raises(records.GovernanceRecordError, match="owner_identity"):
        records.seal_record(missing_owner)


@pytest.mark.parametrize(
    "decision",
    ["RECOMMEND_APPROVE", "RECOMMEND_REJECT", "RECOMMEND_CHANGES_REQUIRED"],
)
def test_agent_g0_decisions_are_recommendations_only(decision: str) -> None:
    sealed = records.seal_record(_g0_payload(decision=decision))
    records.validate_g0_decision(sealed)


@pytest.mark.parametrize("decision", ["APPROVED", "REJECTED"])
def test_agent_cannot_emit_final_g0_decision(decision: str) -> None:
    with pytest.raises(records.GovernanceRecordError, match="recommendation decisions only"):
        records.seal_record(_g0_payload(decision=decision))


@pytest.mark.parametrize("decision", ["APPROVED", "REJECTED"])
def test_owner_can_emit_hash_bound_final_g0_decision(decision: str) -> None:
    sealed = records.seal_record(_g0_payload(authority="OWNER", decision=decision))
    records.validate_g0_decision(sealed)
    assert sealed["owner_identity"] == "owner@example.test"
    assert sealed["card_sha256"] == "b" * 64
    assert sealed["source_sha256"] == "a" * 64


def test_owner_final_requires_explicit_identity_and_decision_time() -> None:
    missing_owner = _g0_payload(authority="OWNER", decision="APPROVED")
    missing_owner["owner_identity"] = None
    with pytest.raises(records.GovernanceRecordError, match="owner_identity"):
        records.seal_record(missing_owner)

    bad_time = _g0_payload(authority="OWNER", decision="APPROVED")
    bad_time["decided_at_utc"] = "2026-07-29T12:15:00+02:00"
    with pytest.raises(records.GovernanceRecordError, match="ending in Z"):
        records.seal_record(bad_time)


def test_canonical_create_new_round_trip_and_no_overwrite(tmp_path: Path) -> None:
    destination = tmp_path / "source-authorization.json"
    receipt = records.write_new_record(destination, _source_payload())
    first_bytes = destination.read_bytes()

    loaded = records.load_record(destination)
    assert receipt.record_sha256 == loaded["record_sha256"]
    assert receipt.size_bytes == len(first_bytes)
    assert first_bytes.endswith(b"\n") and not first_bytes.endswith(b"\n\n")

    replacement = _source_payload()
    replacement["decision"] = "REJECTED"
    with pytest.raises(records.GovernanceRecordError, match="refusing to overwrite"):
        records.write_new_record(destination, replacement)
    assert destination.read_bytes() == first_bytes


def test_writer_retains_post_create_failure_fail_closed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    destination = tmp_path / "ambiguous-authorization.json"

    def fail_fsync(_descriptor: int) -> None:
        raise OSError("simulated durability failure")

    monkeypatch.setattr(records.os, "fsync", fail_fsync)
    with pytest.raises(OSError, match="simulated durability failure"):
        records.write_new_record(destination, _source_payload())

    retained = destination.read_bytes()
    assert retained
    with pytest.raises(records.GovernanceRecordError, match="refusing to overwrite"):
        records.write_new_record(destination, _source_payload())
    assert destination.read_bytes() == retained


def test_canonical_hash_is_independent_of_input_key_order() -> None:
    payload = _source_payload()
    reversed_payload = dict(reversed(list(payload.items())))
    assert records.seal_record(payload)["record_sha256"] == records.seal_record(
        reversed_payload
    )["record_sha256"]


def test_duplicate_keys_noncanonical_bytes_and_hash_mismatch_fail_closed(tmp_path: Path) -> None:
    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text(
        '{"schema_version":"qm.g0-decision/v1","schema_version":"qm.g0-decision/v1"}\n',
        encoding="utf-8",
    )
    with pytest.raises(records.GovernanceRecordError, match="duplicate JSON key"):
        records.load_record(duplicate)

    sealed = records.seal_record(_source_payload())
    noncanonical = tmp_path / "pretty.json"
    noncanonical.write_text(json.dumps(sealed, indent=2) + "\n", encoding="utf-8")
    with pytest.raises(records.GovernanceRecordError, match="not in canonical"):
        records.load_record(noncanonical)

    tampered = copy.deepcopy(sealed)
    tampered["rationale"] = "Tampered after sealing."
    with pytest.raises(records.GovernanceRecordError, match="record_sha256 mismatch"):
        records.validate_record(tampered)


def test_extra_keys_and_floating_point_values_fail_closed() -> None:
    extra = _source_payload()
    extra["unexpected"] = "not allowed"
    with pytest.raises(records.GovernanceRecordError, match="key set mismatch"):
        records.seal_record(extra)

    nested_extra = _experiment_payload()
    nested_extra["parameter_cell"]["parameters"] = []
    with pytest.raises(records.GovernanceRecordError, match="parameter_cell key set mismatch"):
        records.seal_record(nested_extra)

    floating = _experiment_payload()
    floating["trial_budget"]["independent_trial_ordinal"] = 1.0
    with pytest.raises(records.GovernanceRecordError, match="floating-point"):
        records.seal_record(floating)


def test_original_experiment_binds_all_immutable_inputs() -> None:
    sealed = records.seal_record(_experiment_payload())
    records.validate_experiment_record(sealed)

    assert sealed["family_fingerprint"] == "c" * 64
    assert sealed["parameter_cell"]["cell_sha256"] == "d" * 64
    assert sealed["data_cut"]["dataset_sha256"] == "e" * 64
    assert sealed["dev_seal"]["evidence_sha256"] == "f" * 64
    assert sealed["oos_seal"]["evidence_sha256"] == "0" * 64
    assert sealed["trial_budget"]["independent_trial_ordinal"] == 1


def test_infra_retry_reuses_independent_trial_and_all_trial_bindings() -> None:
    original = records.seal_record(_experiment_payload())
    retry = records.seal_record(_retry_payload(original), prior_records=(original,))

    records.validate_experiment_record(retry, prior_records=(original,))
    assert retry["independent_trial_id"] == original["independent_trial_id"]
    assert retry["experiment_id"] == original["experiment_id"]
    assert retry["retry_of"] == original["attempt_id"]


def test_infra_retry_requires_known_target_and_cannot_mint_trial_identity() -> None:
    original = records.seal_record(_experiment_payload())
    retry = _retry_payload(original)

    with pytest.raises(records.GovernanceRecordError, match="target not supplied"):
        records.seal_record(retry)

    retry["independent_trial_id"] = "TRIAL-20260729-NEW1"
    with pytest.raises(
        records.GovernanceRecordError,
        match="budget slot|immutable trial bindings",
    ):
        records.seal_record(retry, prior_records=(original,))


@pytest.mark.parametrize(
    ("field", "replacement"),
    [
        ("card_sha256", "1" * 64),
        ("family_fingerprint", "2" * 64),
        ("symbol", "GBPUSD"),
        ("timeframe", "H1"),
    ],
)
def test_infra_retry_cannot_change_immutable_binding(field: str, replacement: str) -> None:
    original = records.seal_record(_experiment_payload())
    retry = _retry_payload(original)
    retry[field] = replacement
    with pytest.raises(records.GovernanceRecordError, match="immutable trial bindings"):
        records.seal_record(retry, prior_records=(original,))


def test_existing_trial_identity_cannot_be_reintroduced_as_original() -> None:
    original = records.seal_record(_experiment_payload())
    replay = _experiment_payload()
    replay["attempt_id"] = "ATTEMPT-20260729-0009"
    replay["created_at_utc"] = "2026-07-29T11:30:00Z"
    with pytest.raises(records.GovernanceRecordError, match="must continue as INFRA_RETRY"):
        records.seal_record(replay, prior_records=(original,))


def test_retry_chain_requires_complete_ancestry() -> None:
    original = records.seal_record(_experiment_payload())
    retry_one = records.seal_record(_retry_payload(original), prior_records=(original,))
    retry_two_payload = _retry_payload(retry_one)
    retry_two_payload["attempt_id"] = "ATTEMPT-20260729-0003"
    retry_two_payload["created_at_utc"] = "2026-07-29T11:00:00Z"

    with pytest.raises(records.GovernanceRecordError, match="incomplete.*ancestry"):
        records.seal_record(retry_two_payload, prior_records=(retry_one,))

    retry_two = records.seal_record(
        retry_two_payload,
        prior_records=(original, retry_one),
    )
    records.validate_experiment_record(retry_two, prior_records=(original, retry_one))


def test_schema_documents_are_versioned_and_closed() -> None:
    schema_dir = STRATEGY_FARM / "schemas"
    names = (
        "source_authorization_v1.schema.json",
        "g0_decision_v1.schema.json",
        "experiment_record_v1.schema.json",
    )
    for name in names:
        schema = json.loads((schema_dir / name).read_text(encoding="utf-8"))
        assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
        assert schema["additionalProperties"] is False
        assert "record_sha256" in schema["required"]

    experiment = json.loads(
        (schema_dir / "experiment_record_v1.schema.json").read_text(encoding="utf-8")
    )
    for definition in ("parameter_cell", "data_cut", "seal", "trial_budget", "producer"):
        assert experiment["$defs"][definition]["additionalProperties"] is False
