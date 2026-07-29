from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from pathlib import Path

import pytest

from tools.strategy_farm.target_outcome_dossier import (
    EVIDENCE_SEAL_SCHEMA_VERSION,
    DEFAULT_SCHEMA_PATH,
    TargetOutcomeDossierError,
    build_target_outcome_dossier,
    canonical_dossier_sha256,
    load_target_outcome_dossier,
    validate_target_outcome_dossier,
    write_new_target_outcome_dossier,
)
from tools.strategy_farm.target_rulepacks import load_rulepack


RULEPACK_HASHES = {
    "DXZ_BETTER_BOOK_V1": "9cd49385808f2d7b7041135c4f5aaf0d7b62a3020e31e51bee9f8b1904b6f284",
    "FTMO_2S_100K_SWING_V1": "c675a1fa48d425d9d581c4ea235586d6312fa09bf2e1b92f49f205b73dc99825",
}


_EVIDENCE_ROOT: Path | None = None


@pytest.fixture(autouse=True)
def _real_evidence_root(tmp_path: Path):
    global _EVIDENCE_ROOT
    _EVIDENCE_ROOT = tmp_path / "evidence-root"
    _EVIDENCE_ROOT.mkdir()
    yield
    _EVIDENCE_ROOT = None


def _write_json(path: Path, value: dict) -> bytes:
    raw = (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def _evidence_ref(evidence_id: str, lane: str, slot: str) -> dict:
    assert _EVIDENCE_ROOT is not None
    artifact_rel = f"artifacts/{evidence_id}.json"
    seal_rel = f"seals/{evidence_id}.seal.json"
    artifact_raw = _write_json(
        _EVIDENCE_ROOT / artifact_rel,
        {"evidence_id": evidence_id, "lane": lane, "slot": slot},
    )
    artifact_sha = hashlib.sha256(artifact_raw).hexdigest()
    seal_raw = _write_json(
        _EVIDENCE_ROOT / seal_rel,
        {
            "schema_version": EVIDENCE_SEAL_SCHEMA_VERSION,
            "evidence_id": evidence_id,
            "lane": lane,
            "slot": slot,
            "artifact_path": artifact_rel,
            "artifact_sha256": artifact_sha,
            "fidelity": "EXACT",
        },
    )
    return {
        "evidence_id": evidence_id,
        "path": artifact_rel,
        "artifact_sha256": artifact_sha,
        "fidelity": "EXACT",
        "seal_state": "SEALED",
        "seal_path": seal_rel,
        "seal_sha256": hashlib.sha256(seal_raw).hexdigest(),
    }


def _evidence() -> dict:
    return {
        "dxz": {
            "incumbent_book_manifest": _evidence_ref("dxz.incumbent.manifest", "dxz", "incumbent_book_manifest"),
            "challenger_book_manifest": _evidence_ref("dxz.challenger.manifest", "dxz", "challenger_book_manifest"),
            "execution_bundle": _evidence_ref("dxz.execution.bundle", "dxz", "execution_bundle"),
            "simulation": _evidence_ref("dxz.simulation.sealed", "dxz", "simulation"),
            "prospective_shadow": _evidence_ref("dxz.prospective.shadow", "dxz", "prospective_shadow"),
            "probation": _evidence_ref("dxz.probation.sealed", "dxz", "probation"),
        },
        "ftmo": {
            "book_manifest": _evidence_ref("ftmo.book.manifest", "ftmo", "book_manifest"),
            "execution_bundle": _evidence_ref("ftmo.execution.bundle", "ftmo", "execution_bundle"),
            "simulation": _evidence_ref("ftmo.simulation.sealed", "ftmo", "simulation"),
            "prospective_shadow": _evidence_ref("ftmo.prospective.shadow", "ftmo", "prospective_shadow"),
        },
    }


def _rewrite_seal(row: dict, lane: str, slot: str) -> None:
    assert _EVIDENCE_ROOT is not None
    raw = _write_json(
        _EVIDENCE_ROOT / row["seal_path"],
        {
            "schema_version": EVIDENCE_SEAL_SCHEMA_VERSION,
            "evidence_id": row["evidence_id"],
            "lane": lane,
            "slot": slot,
            "artifact_path": row["path"],
            "artifact_sha256": row["artifact_sha256"],
            "fidelity": row["fidelity"],
        },
    )
    row["seal_sha256"] = hashlib.sha256(raw).hexdigest()


def _criterion_rows(rulepack_id: str, kind: str, evidence_id: str) -> list[dict]:
    payload = load_rulepack(rulepack_id).as_dict()
    if kind == "official":
        ids = [row["rule_id"] for row in payload["official_rules"]]
        owner_gate = None
    else:
        ids = [row["criterion_id"] for row in payload["evaluation_profile"]["go_criteria"]]
        owner_gate = (
            "dxz_owner_money_gate"
            if rulepack_id == "DXZ_BETTER_BOOK_V1"
            else "ftmo_owner_purchase_gate"
        )
    return [
        {
            "criterion_id": criterion_id,
            "status": "PENDING_OWNER" if criterion_id == owner_gate else "PASS",
            "evidence_ids": [evidence_id],
        }
        for criterion_id in ids
    ]


def _observations() -> dict:
    return {
        "dxz": {
            "official_criteria": _criterion_rows(
                "DXZ_BETTER_BOOK_V1", "official", "dxz.simulation.sealed"
            ),
            "internal_criteria": _criterion_rows(
                "DXZ_BETTER_BOOK_V1", "internal", "dxz.probation.sealed"
            ),
            "q08_verdict": "SUPPORTED",
            "evidence_debt_visible": False,
            "incumbent_metrics": {
                "six_month_return_percent": "12",
                "six_month_max_drawdown_percent": "7",
                "return_drawdown_ratio": "1.714",
            },
            "challenger_metrics": {
                "six_month_return_percent": "16",
                "six_month_max_drawdown_percent": "6.5",
                "return_drawdown_ratio": "2.462",
            },
            "darwin_replica_metrics_present": True,
            "synchronized_outer_validation_pass": True,
            "probation": {
                "completed_days": 42,
                "operational_defects": 0,
                "actual_darwin_metrics_observed": True,
            },
        },
        "ftmo": {
            "official_criteria": _criterion_rows(
                "FTMO_2S_100K_SWING_V1", "official", "ftmo.simulation.sealed"
            ),
            "internal_criteria": _criterion_rows(
                "FTMO_2S_100K_SWING_V1", "internal", "ftmo.prospective.shadow"
            ),
            "q08_verdict": "SUPPORTED",
            "evidence_debt_visible": False,
            "rule_snapshot_age_days": 7,
            "execution_fidelity_unadjudicated_mismatches": 0,
            "complete_mtm_evidence": True,
            "phase1_pass_probability_percent": "80",
            "phase1_lower_95_percent_bound_percent": "70",
            "breach_probability_upper_95_percent_bound_percent": "10",
            "phase2_conditional_pass_probability_percent": "85",
            "joint_two_phase_pass_probability_percent": "65",
            "completed_free_trial_runs": 1,
            "free_trial_operational_defects": 0,
            "prediction_bands_respected": True,
        },
    }


def _build(*, evidence: dict | None = None, observations: dict | None = None) -> dict:
    assert _EVIDENCE_ROOT is not None
    return build_target_outcome_dossier(
        dossier_id="outcome.dossier.fixture.v1",
        created_at_utc="2026-07-29T19:00:00Z",
        evidence=_evidence() if evidence is None else evidence,
        observations=_observations() if observations is None else observations,
        evidence_root=_EVIDENCE_ROOT,
    )


def _check(dossier: dict, lane: str, check_id: str) -> dict:
    return next(
        row for row in dossier["evaluation"][lane]["metric_checks"]
        if row["check_id"] == check_id
    )


def test_ready_dossier_binds_both_immutable_rulepacks_and_stops_at_owner() -> None:
    dossier = _build()

    assert dossier["evaluation"]["overall_status"] == "READY_FOR_OWNER_DECISION"
    assert dossier["evaluation"]["dxz"]["status"] == "READY_FOR_OWNER_DECISION"
    assert dossier["evaluation"]["ftmo"]["status"] == "READY_FOR_OWNER_DECISION"
    assert dossier["evaluation"]["authority_ceiling"] == "READY_FOR_OWNER_DECISION"
    assert {
        row["rulepack_id"]: row["canonical_sha256"]
        for row in dossier["rulepack_bindings"]
    } == RULEPACK_HASHES
    assert dossier["evaluation"]["dxz"]["official_criteria"]["status"] == "PASS"
    assert dossier["evaluation"]["dxz"]["internal_criteria"]["status"] == "PENDING_OWNER"
    assert dossier["evaluation"]["ftmo"]["official_criteria"]["status"] == "PASS"
    assert dossier["evaluation"]["ftmo"]["internal_criteria"]["status"] == "PENDING_OWNER"
    assert _check(dossier, "ftmo", "phase1_pass_probability")["threshold"] == "80"
    assert _check(dossier, "ftmo", "phase1_lower_95_percent_bound")["threshold"] == "70"
    assert _check(dossier, "ftmo", "official_rule_breach_upper_95_percent_bound")["threshold"] == "10"
    assert _check(dossier, "ftmo", "phase2_conditional_pass_probability")["threshold"] == "85"
    assert _check(dossier, "ftmo", "joint_two_phase_pass_probability")["threshold"] == "65"
    assert _check(dossier, "dxz", "probation_minimum_days")["threshold"] == "42"
    assert dossier["owner_decision_required"] is True
    for action in (
        "runtime_action",
        "factory_action",
        "mt5_action",
        "purchase_action",
        "deployment_action",
    ):
        assert dossier[action] == "NONE"
    assert "GO" not in {dossier["evaluation"]["overall_status"]}
    assert dossier["dossier_sha256"] == canonical_dossier_sha256(dossier)
    assert _EVIDENCE_ROOT is not None
    validate_target_outcome_dossier(dossier, evidence_root=_EVIDENCE_ROOT)


def test_build_is_deterministic_and_canonicalizes_criterion_order() -> None:
    observations = _observations()
    observations["dxz"]["official_criteria"].reverse()
    observations["dxz"]["internal_criteria"].reverse()
    observations["ftmo"]["official_criteria"].reverse()
    observations["ftmo"]["internal_criteria"].reverse()

    first = _build(observations=observations)
    second = _build()

    assert first == second
    assert first["dossier_sha256"] == second["dossier_sha256"]


@pytest.mark.parametrize(
    ("field", "value", "check_id"),
    [
        ("rule_snapshot_age_days", 8, "rule_snapshot_age_days"),
        (
            "execution_fidelity_unadjudicated_mismatches",
            1,
            "execution_fidelity_unadjudicated_mismatches",
        ),
        ("complete_mtm_evidence", False, "complete_mtm_evidence"),
        ("phase1_pass_probability_percent", "79.999", "phase1_pass_probability"),
        (
            "phase1_lower_95_percent_bound_percent",
            "69.999",
            "phase1_lower_95_percent_bound",
        ),
        (
            "breach_probability_upper_95_percent_bound_percent",
            "10.001",
            "official_rule_breach_upper_95_percent_bound",
        ),
        (
            "phase2_conditional_pass_probability_percent",
            "84.999",
            "phase2_conditional_pass_probability",
        ),
        (
            "joint_two_phase_pass_probability_percent",
            "64.999",
            "joint_two_phase_pass_probability",
        ),
        ("completed_free_trial_runs", 0, "completed_free_trial_runs"),
        ("free_trial_operational_defects", 1, "free_trial_operational_defects"),
        ("prediction_bands_respected", False, "prediction_bands_respected"),
    ],
)
def test_ftmo_thresholds_are_read_from_rulepack_and_fail_closed(
    field: str, value: object, check_id: str
) -> None:
    observations = _observations()
    observations["ftmo"][field] = value

    dossier = _build(observations=observations)

    assert dossier["evaluation"]["ftmo"]["status"] == "NO_GO"
    assert dossier["evaluation"]["overall_status"] == "NO_GO"
    assert _check(dossier, "ftmo", check_id)["status"] == "FAIL"


@pytest.mark.parametrize(
    ("lane", "field"),
    [
        ("dxz", "incumbent_book_manifest"),
        ("dxz", "challenger_book_manifest"),
        ("dxz", "execution_bundle"),
        ("dxz", "simulation"),
        ("dxz", "prospective_shadow"),
        ("dxz", "probation"),
        ("ftmo", "book_manifest"),
        ("ftmo", "execution_bundle"),
        ("ftmo", "simulation"),
        ("ftmo", "prospective_shadow"),
    ],
)
def test_every_required_exact_evidence_hash_is_fail_closed_when_missing(
    lane: str, field: str
) -> None:
    evidence = _evidence()
    del evidence[lane][field]

    dossier = _build(evidence=evidence)

    assert dossier["evidence"][lane][field] is None
    assert dossier["evaluation"][lane]["status"] == "NO_GO"
    assert f"missing:{field}" in dossier["evaluation"][lane]["evidence_failures"]


@pytest.mark.parametrize(
    ("mutation", "failure"),
    [
        ({"fidelity": "APPROXIMATE"}, "approximate:simulation"),
        ({"seal_state": "UNSEALED", "seal_path": None, "seal_sha256": None}, "unsealed:simulation"),
    ],
)
def test_approximate_or_unsealed_evidence_is_no_go(
    mutation: dict, failure: str
) -> None:
    evidence = _evidence()
    evidence["ftmo"]["simulation"].update(mutation)
    if "fidelity" in mutation:
        _rewrite_seal(evidence["ftmo"]["simulation"], "ftmo", "simulation")

    dossier = _build(evidence=evidence)

    assert dossier["evaluation"]["ftmo"]["status"] == "NO_GO"
    assert failure in dossier["evaluation"]["ftmo"]["evidence_failures"]


def test_false_sealed_claim_without_seal_identity_is_rejected() -> None:
    evidence = _evidence()
    evidence["ftmo"]["simulation"]["seal_path"] = None
    evidence["ftmo"]["simulation"]["seal_sha256"] = None

    with pytest.raises(TargetOutcomeDossierError, match="SEALED evidence requires"):
        _build(evidence=evidence)


def test_artifact_and_seal_bytes_are_revalidated_from_allowed_root() -> None:
    evidence = _evidence()
    assert _EVIDENCE_ROOT is not None
    artifact = evidence["dxz"]["simulation"]
    (_EVIDENCE_ROOT / artifact["path"]).write_bytes(b"tampered\n")
    with pytest.raises(TargetOutcomeDossierError, match="artifact_sha256.*file bytes"):
        _build(evidence=evidence)

    evidence = _evidence()
    seal = evidence["dxz"]["simulation"]
    (_EVIDENCE_ROOT / seal["seal_path"]).write_bytes(b"tampered seal\n")
    with pytest.raises(TargetOutcomeDossierError, match="seal_sha256.*seal file bytes"):
        _build(evidence=evidence)


def test_declared_evidence_file_must_exist_under_allowed_root() -> None:
    evidence = _evidence()
    assert _EVIDENCE_ROOT is not None
    row = evidence["dxz"]["simulation"]
    (_EVIDENCE_ROOT / row["path"]).unlink()

    with pytest.raises(TargetOutcomeDossierError, match="evidence file is unavailable"):
        _build(evidence=evidence)


def test_seal_must_bind_exact_lane_slot_and_artifact_relationship() -> None:
    evidence = _evidence()
    assert _EVIDENCE_ROOT is not None
    row = evidence["ftmo"]["simulation"]
    seal_path = _EVIDENCE_ROOT / row["seal_path"]
    seal = json.loads(seal_path.read_text(encoding="utf-8"))
    seal["slot"] = "book_manifest"
    raw = _write_json(seal_path, seal)
    row["seal_sha256"] = hashlib.sha256(raw).hexdigest()

    with pytest.raises(TargetOutcomeDossierError, match="exactly bind this lane"):
        _build(evidence=evidence)


def test_cross_lane_reuse_is_rejected_independent_of_evidence_id() -> None:
    evidence = _evidence()
    dxz = evidence["dxz"]["simulation"]
    ftmo = evidence["ftmo"]["simulation"]
    ftmo["path"] = dxz["path"]
    ftmo["artifact_sha256"] = dxz["artifact_sha256"]
    _rewrite_seal(ftmo, "ftmo", "simulation")

    with pytest.raises(TargetOutcomeDossierError, match="cross-lane evidence reuse"):
        _build(evidence=evidence)


def test_same_artifact_bytes_at_different_paths_cannot_cross_target_lanes() -> None:
    evidence = _evidence()
    assert _EVIDENCE_ROOT is not None
    dxz = evidence["dxz"]["simulation"]
    ftmo = evidence["ftmo"]["simulation"]
    copied = (_EVIDENCE_ROOT / dxz["path"]).read_bytes()
    (_EVIDENCE_ROOT / ftmo["path"]).write_bytes(copied)
    ftmo["artifact_sha256"] = hashlib.sha256(copied).hexdigest()
    _rewrite_seal(ftmo, "ftmo", "simulation")

    with pytest.raises(TargetOutcomeDossierError, match="artifact_sha256"):
        _build(evidence=evidence)


@pytest.mark.parametrize(
    ("path", "value", "check_id"),
    [
        (("challenger_metrics", "six_month_return_percent"), "12", "challenger_six_month_return_improves"),
        (("challenger_metrics", "six_month_max_drawdown_percent"), "7.001", "challenger_six_month_drawdown_not_worse"),
        (("challenger_metrics", "return_drawdown_ratio"), "1.714", "challenger_return_drawdown_ratio_improves"),
        (("probation", "completed_days"), 41, "probation_minimum_days"),
        (("probation", "operational_defects"), 1, "probation_operational_defects"),
        (("probation", "actual_darwin_metrics_observed"), False, "probation_actual_darwin_metrics"),
    ],
)
def test_dxz_challenger_comparison_and_probation_are_mandatory(
    path: tuple[str, str], value: object, check_id: str
) -> None:
    observations = _observations()
    observations["dxz"][path[0]][path[1]] = value

    dossier = _build(observations=observations)

    assert dossier["evaluation"]["dxz"]["status"] == "NO_GO"
    assert _check(dossier, "dxz", check_id)["status"] == "FAIL"


def test_conditional_q08_requires_visible_evidence_debt() -> None:
    observations = _observations()
    observations["dxz"]["q08_verdict"] = "CONDITIONAL"
    observations["dxz"]["evidence_debt_visible"] = False
    failed = _build(observations=observations)
    assert _check(failed, "dxz", "q08_target_evidence")["status"] == "FAIL"

    observations["dxz"]["evidence_debt_visible"] = True
    ready = _build(observations=observations)
    assert _check(ready, "dxz", "q08_target_evidence")["status"] == "PASS"
    assert ready["evaluation"]["dxz"]["status"] == "READY_FOR_OWNER_DECISION"


def test_missing_or_failed_criteria_are_separate_no_go_dimensions() -> None:
    observations = _observations()
    missing_official = observations["ftmo"]["official_criteria"].pop()
    observations["ftmo"]["internal_criteria"][0]["status"] = "FAIL"

    dossier = _build(observations=observations)

    lane = dossier["evaluation"]["ftmo"]
    assert lane["official_criteria"]["status"] == "NO_GO"
    assert missing_official["criterion_id"] in lane["official_criteria"]["missing_ids"]
    assert lane["internal_criteria"]["status"] == "NO_GO"
    assert lane["internal_criteria"]["failures"]


def test_official_and_internal_criterion_namespaces_cannot_be_swapped() -> None:
    observations = _observations()
    observations["ftmo"]["official_criteria"][0]["criterion_id"] = (
        "ftmo_phase1_probability_gate"
    )

    with pytest.raises(TargetOutcomeDossierError, match="not declared by the bound rulepack"):
        _build(observations=observations)


def test_criterion_evidence_cannot_be_laundered_across_target_lanes() -> None:
    observations = _observations()
    observations["ftmo"]["official_criteria"][0]["evidence_ids"] = [
        "dxz.simulation.sealed"
    ]

    dossier = _build(observations=observations)

    failures = dossier["evaluation"]["ftmo"]["official_criteria"]["failures"]
    assert any("unresolved_evidence:dxz.simulation.sealed" in item for item in failures)
    assert dossier["evaluation"]["ftmo"]["status"] == "NO_GO"


def test_rulepack_binding_evaluation_and_authority_tampering_are_rejected() -> None:
    dossier = _build()
    assert _EVIDENCE_ROOT is not None

    bad_binding = deepcopy(dossier)
    bad_binding["rulepack_bindings"][0]["canonical_sha256"] = "0" * 64
    bad_binding["dossier_sha256"] = canonical_dossier_sha256(bad_binding)
    with pytest.raises(TargetOutcomeDossierError, match="exactly bind both"):
        validate_target_outcome_dossier(bad_binding, evidence_root=_EVIDENCE_ROOT)

    bad_evaluation = deepcopy(dossier)
    bad_evaluation["evaluation"]["ftmo"]["status"] = "NO_GO"
    bad_evaluation["dossier_sha256"] = canonical_dossier_sha256(bad_evaluation)
    with pytest.raises(TargetOutcomeDossierError, match="deterministic rulepack evaluation"):
        validate_target_outcome_dossier(bad_evaluation, evidence_root=_EVIDENCE_ROOT)

    bad_authority = deepcopy(dossier)
    bad_authority["purchase_action"] = "BUY"
    bad_authority["dossier_sha256"] = canonical_dossier_sha256(bad_authority)
    with pytest.raises(TargetOutcomeDossierError, match="must remain NONE"):
        validate_target_outcome_dossier(bad_authority, evidence_root=_EVIDENCE_ROOT)


def test_hash_tampering_is_rejected() -> None:
    dossier = _build()
    dossier["dossier_sha256"] = "0" * 64
    assert _EVIDENCE_ROOT is not None

    with pytest.raises(TargetOutcomeDossierError, match="hash mismatch"):
        validate_target_outcome_dossier(dossier, evidence_root=_EVIDENCE_ROOT)


def test_create_new_writer_roundtrip_and_refuses_overwrite(tmp_path: Path) -> None:
    dossier = _build()
    path = tmp_path / "outcome.json"
    assert _EVIDENCE_ROOT is not None

    receipt = write_new_target_outcome_dossier(
        dossier, path, evidence_root=_EVIDENCE_ROOT
    )

    assert receipt.dossier_sha256 == dossier["dossier_sha256"]
    assert receipt.bytes_written == path.stat().st_size
    assert load_target_outcome_dossier(path, evidence_root=_EVIDENCE_ROOT) == dossier
    with pytest.raises(TargetOutcomeDossierError, match="refusing to overwrite"):
        write_new_target_outcome_dossier(
            dossier, path, evidence_root=_EVIDENCE_ROOT
        )


def test_loader_rejects_duplicate_keys_and_floats(tmp_path: Path) -> None:
    duplicate = tmp_path / "duplicate.json"
    duplicate.write_text('{"schema_version":"x","schema_version":"y"}', encoding="utf-8")
    with pytest.raises(TargetOutcomeDossierError, match="duplicate JSON key"):
        load_target_outcome_dossier(duplicate)

    floating = tmp_path / "float.json"
    floating.write_text('{"value":1.25}', encoding="utf-8")
    with pytest.raises(TargetOutcomeDossierError, match="floating-point JSON"):
        load_target_outcome_dossier(floating)


def test_decimal_values_must_be_canonical_strings() -> None:
    observations = _observations()
    observations["ftmo"]["phase1_pass_probability_percent"] = 80.0
    with pytest.raises(TargetOutcomeDossierError, match="floating-point"):
        _build(observations=observations)

    observations = _observations()
    observations["ftmo"]["phase1_pass_probability_percent"] = "80.0"
    with pytest.raises(TargetOutcomeDossierError, match="trailing fractional zeroes"):
        _build(observations=observations)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("phase1_pass_probability_percent", "-1"),
        ("phase1_pass_probability_percent", "100.001"),
        ("phase1_lower_95_percent_bound_percent", "-0.1"),
        ("breach_probability_upper_95_percent_bound_percent", "-1"),
        ("phase2_conditional_pass_probability_percent", "101"),
        ("joint_two_phase_pass_probability_percent", "101"),
    ],
)
def test_probability_percentages_are_bounded_zero_to_one_hundred(
    field: str, value: str
) -> None:
    observations = _observations()
    observations["ftmo"][field] = value
    with pytest.raises(TargetOutcomeDossierError, match=r"must be (>= 0|<= 100)"):
        _build(observations=observations)


def test_probability_bounds_are_internally_coherent() -> None:
    observations = _observations()
    observations["ftmo"]["phase1_lower_95_percent_bound_percent"] = "81"
    with pytest.raises(TargetOutcomeDossierError, match="point estimate"):
        _build(observations=observations)

    observations = _observations()
    observations["ftmo"]["joint_two_phase_pass_probability_percent"] = "86"
    with pytest.raises(TargetOutcomeDossierError, match="phase-1 pass probability"):
        _build(observations=observations)


@pytest.mark.parametrize(
    ("metric", "value"),
    [
        ("six_month_return_percent", "-101"),
        ("six_month_max_drawdown_percent", "-1"),
        ("six_month_max_drawdown_percent", "100.001"),
        ("return_drawdown_ratio", "0"),
    ],
)
def test_dxz_metric_domains_are_bounded(metric: str, value: str) -> None:
    observations = _observations()
    observations["dxz"]["challenger_metrics"][metric] = value
    with pytest.raises(TargetOutcomeDossierError, match="must be"):
        _build(observations=observations)


@pytest.mark.parametrize("path", ["C:/secret.json", "../escape.json", "/absolute.json", "bad\\path.json"])
def test_evidence_paths_must_be_normalized_relative_posix(path: str) -> None:
    evidence = _evidence()
    evidence["dxz"]["simulation"]["path"] = path

    with pytest.raises(TargetOutcomeDossierError, match="relative POSIX"):
        _build(evidence=evidence)


def test_schema_is_strict_and_matches_implementation_version() -> None:
    schema = json.loads(DEFAULT_SCHEMA_PATH.read_text(encoding="utf-8"))

    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["additionalProperties"] is False
    assert schema["properties"]["schema_version"]["const"] == (
        "qm.target-outcome-dossier/v1"
    )
    for action in (
        "runtime_action",
        "factory_action",
        "mt5_action",
        "purchase_action",
        "deployment_action",
    ):
        assert schema["properties"][action]["const"] == "NONE"
    assert schema["properties"]["owner_decision_required"]["const"] is True
