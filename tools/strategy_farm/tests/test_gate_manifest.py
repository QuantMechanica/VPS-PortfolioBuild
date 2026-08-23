from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import gate_manifest  # noqa: E402
import phase_ids  # noqa: E402


def test_default_manifest_matches_phase_ids_and_is_active_v3() -> None:
    # Gate Manifest v3 is the active default after the 2026-08-23 activation.
    contract = gate_manifest.load_gate_manifest()

    assert list(contract.phase_ids) == phase_ids.PHASE_ORDER
    assert contract.display_names == phase_ids.PHASE_NAME
    assert dict(contract.legacy_aliases) == phase_ids.LEGACY_P_TO_Q
    assert contract.verdict_dimensions == gate_manifest.REQUIRED_VERDICT_DIMENSIONS
    assert contract.schema_version == "qm.gate-manifest/v3"
    assert gate_manifest.SCHEMA_VERSION == "qm.gate-manifest/v3"
    assert gate_manifest.DEFAULT_MANIFEST.name == "gate_manifest.v3.json"
    assert contract.activation_state == "ACTIVE"
    assert contract.phase_ids == tuple(f"Q{i:02d}" for i in range(17))
    assert contract.next_by_phase["Q13"] is None
    assert contract.next_by_phase["Q16"] == "Q11"
    assert phase_ids.ORDINARY_PHASE_ORDER == [f"Q{i:02d}" for i in range(14)]
    assert phase_ids.OPTIMIZATION_PHASE_ORDER == ["Q14", "Q15", "Q16"]
    assert phase_ids.next_phase_id("Q10") == "Q11"
    assert phase_ids.next_phase_id("Q13") is None
    assert phase_ids.next_phase_id("Q16") == "Q11"
    assert len(contract.sha256) == 64


def test_v1_manifest_remains_a_valid_closed_fixture() -> None:
    contract = gate_manifest.load_gate_manifest(gate_manifest.V1_MANIFEST)
    # v2 is the reference for the frozen Q00-Q13 topology + enumerated rename
    # exemption.  v3 additionally relabels Q09/Q10 (validated by the v3 tests);
    # its authority/runner/next freeze is covered separately below.
    current = gate_manifest.load_gate_manifest(gate_manifest.V2_MANIFEST)

    assert contract.schema_version == "qm.gate-manifest/v1"
    assert contract.phase_ids == tuple(f"Q{i:02d}" for i in range(14))
    assert contract.extension_topology is None
    assert contract.next_by_phase["Q13"] is None
    # v2 must not redefine the Q00-Q13 topology.  Display names are exempt from
    # that freeze -- OWNER-DEC-GATEMANIFEST-Q05 (2026-08-21) renamed Q05 from
    # "Stress MEDIUM" to "Gross Full-History Robustness".  The exemption is
    # enumerated, not open: any *other* renamed gate still fails here.
    def topology(gate: gate_manifest.Gate) -> tuple[object, ...]:
        return (gate.id, gate.ordinal, gate.authority, gate.runner, gate.evidence_role, gate.next)

    assert [topology(g) for g in current.gates[:14]] == [topology(g) for g in contract.gates]
    renamed = {
        g.id: (old.name, g.name)
        for g, old in zip(current.gates[:14], contract.gates)
        if g.name != old.name
    }
    assert renamed == {"Q05": ("Stress MEDIUM", "Gross Full-History Robustness")}
    assert dict(current.legacy_aliases) == dict(contract.legacy_aliases)
    assert current.verdict_dimensions == contract.verdict_dimensions
    assert gate_manifest.write_phase_id("Q13", contract) == "Q13"
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("Q14", contract)


def test_v3_is_now_the_active_default_and_v2_remains_loadable() -> None:
    active = gate_manifest.load_gate_manifest()
    candidate = gate_manifest.load_gate_manifest(gate_manifest.V3_MANIFEST)
    legacy = gate_manifest.load_gate_manifest(gate_manifest.V2_MANIFEST)

    assert active.schema_version == "qm.gate-manifest/v3"
    assert gate_manifest.DEFAULT_MANIFEST.name == "gate_manifest.v3.json"
    assert candidate.schema_version == "qm.gate-manifest/v3"
    # v2 stays a valid, loadable fixture after the switch.
    assert legacy.schema_version == "qm.gate-manifest/v2"
    assert legacy.names["Q09"] == "News Impact Mode"
    assert candidate.phase_ids == tuple(f"Q{i:02d}" for i in range(17))
    assert "Q10A" not in candidate.phase_ids
    assert candidate.display_names["Q10A"] == "Baseline Full Run"
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("Q10A", candidate)

    topology = candidate.extension_topology
    assert topology is not None
    assert tuple(topology["target_sequence"]) == (
        "Q10A", "Q09", "Q10", "Q14", "Q15", "Q16", "Q11"
    )
    assert topology["baseline_stage"]["source_phase"] == "Q08"
    assert topology["baseline_stage"]["reuse_policy"] == (
        "REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE"
    )
    assert topology["baseline_stage"]["missing_binding_action"] == (
        "REQUIRE_Q10A_BASELINE_RUN"
    )
    assert topology["optimization_fork"]["pattern_filter_cap_per_direction"] == 3
    assert topology["q16_dependencies"][0]["source_phase"] == "Q08"
    assert topology["q16_dependencies"][1]["source_phase"] == "Q10"
    assert topology["portfolio_routes"][0]["from"] == "Q10"
    assert topology["portfolio_routes"][1]["from"] == "Q16"
    assert topology["activation_guard"] == {
        "state": "ACTIVE",
        "requires_completed_review": "OPS-Q10-REALIGN-E1-E2",
        "requires_approver": "CLAUDE",
        "default_manifest_switch": True,
        "activated_by": "CLAUDE",
        "activated_at": "2026-08-23",
        "review_refs": ("9b40ff25", "d5c13a08"),
    }


def test_v3_loader_exposes_q11_routing_and_q16_dependencies() -> None:
    contract = gate_manifest.load_gate_manifest()

    # Q11 routing rule: Q10 is the non-optimized predecessor, Q16 the optimized.
    assert contract.portfolio_route(optimized=False) == "Q10"
    assert contract.portfolio_route(optimized=True) == "Q16"

    roles = [(dep["role"], dep["phase"]) for dep in contract.q16_dependencies]
    assert roles == [("BASELINE_FULL_RUN", "Q10A"), ("INCUMBENT_Q10", "Q10")]

    # Q10A conditional-reuse contract is queryable through the loader.
    assert contract.baseline_reuse_policy == (
        "REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE"
    )
    assert contract.baseline_missing_binding_action == "REQUIRE_Q10A_BASELINE_RUN"

    # v2 has no v3 optimization contract; accessors degrade to empty/None.
    v2 = gate_manifest.load_gate_manifest(gate_manifest.V2_MANIFEST)
    assert v2.q16_dependencies == ()
    assert v2.portfolio_route(optimized=True) is None
    assert v2.baseline_reuse_policy is None


def test_v4_draft_loads_read_inert_without_changing_v3_default() -> None:
    active = gate_manifest.load_gate_manifest()
    draft = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)

    assert active.schema_version == gate_manifest.SCHEMA_VERSION_V3
    assert gate_manifest.SCHEMA_VERSION == gate_manifest.SCHEMA_VERSION_V3
    assert gate_manifest.DEFAULT_MANIFEST == gate_manifest.V3_MANIFEST
    assert draft.schema_version == gate_manifest.SCHEMA_VERSION_V4
    assert draft.activation_state == "READ_INERT"
    assert draft.phase_ids == tuple(f"Q{i:02d}" for i in range(18))
    assert draft.macro_phase("Q00") == "1_STRATEGIEBEWEIS"
    assert draft.macro_phase("Q14") == "2_OPTIMIERUNG"
    assert draft.macro_phase("Q15") == "3_BUCHBEWERTUNG"


def test_v4_equivalence_round_trips_every_phase2_and_phase3_gate() -> None:
    draft = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    forward = dict(draft.contract_equivalence["v3_to_v4"])
    source_by_gate = {
        target: source for source, target in forward.items() if target in draft.phase_ids
    }

    assert set(source_by_gate) == set(draft.phase_ids)
    for v4_gate in draft.phase_ids[9:]:
        v3_gate = source_by_gate[v4_gate]
        assert draft.equivalent_gate(v3_gate, "v3", "v4") == v4_gate
        assert draft.equivalent_gate(v4_gate, "v4", "v3") == v3_gate
        assert gate_manifest.equivalent_gate(v3_gate, "v3", "v4", draft) == v4_gate

    # Storage-lane translations are versioned and reversible too.
    assert draft.equivalent_gate("Q09_NEWS", "v3", "v4") == "Q10_NEWS"
    assert draft.equivalent_gate("Q10_NEWS", "v4", "v3") == "Q09_NEWS"


def test_version_aware_phase_display_never_silently_reinterprets_rows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Current active v3: the same stored token has different semantics under a
    # v4 stamp and must translate back to the active v3 gate with provenance.
    assert phase_ids.phase_qid("Q10", "v3") == "Q10"
    assert phase_ids.phase_qid("Q10", "v4") == "Q09"
    assert phase_ids.normalize_phase_id("Q10", "v4") == "Q09"
    assert phase_ids.display_phase("Q10", "v4") == "Q09 (v4:Q10)"
    assert phase_ids.display_phase("Q10", "v2") == "Q10 (v2:Q10)"

    # Simulate the future authorized default switch without loading the draft
    # as DEFAULT_MANIFEST. Historical v3 Q10 then renders exactly as proposed.
    monkeypatch.setattr(phase_ids, "ACTIVE_GATE_CONTRACT_VERSION", "v4")
    assert phase_ids.phase_qid("Q10", "v3") == "Q11"
    assert phase_ids.normalize_phase_id("Q10", "v3") == "Q11"
    assert phase_ids.display_phase("Q10", "v3") == "Q11 (v3:Q10)"


def test_unstamped_phase_rows_keep_the_legacy_alias_fallback() -> None:
    assert phase_ids.phase_qid("P9") == "Q11"
    assert phase_ids.normalize_phase_id(" p9 ") == "Q11"
    assert phase_ids.display_phase("P9", None) == "Q11"
    assert phase_ids.phase_qid("COMPILE_EA", "v3") == "COMPILE_EA"


def test_v4_is_linear_with_a_trigger_only_phase3_entry() -> None:
    draft = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    ordinal = {gate.id: gate.ordinal for gate in draft.gates}

    assert [gate.ordinal for gate in draft.gates] == list(range(18))
    assert [gate.id for gate in draft.gates if gate.ordinal <= 14 and gate.next is None] == [
        "Q14"
    ]
    assert draft.next_by_phase["Q14"] is None
    assert draft.next_by_phase["Q17"] is None
    assert "Q15" not in {target for target in draft.next_by_phase.values() if target}
    for gate in draft.gates:
        if gate.next is not None:
            assert ordinal[gate.next] == gate.ordinal + 1

    order, names, successors = phase_ids.build_phase_tables(draft)
    assert order == list(draft.phase_ids)
    assert names == draft.display_names
    assert successors == draft.next_by_phase
    # Explicit v4 inspection does not mutate the active v3 module defaults.
    assert phase_ids.PHASE_ORDER == [f"Q{i:02d}" for i in range(17)]
    assert phase_ids.PHASE_NEXT["Q16"] == "Q11"


def test_v4_preserves_v3_criteria_for_every_mapped_gate() -> None:
    """Every v4 gate with a real top-level v3 source keeps that gate's name and
    evidence_role (evidence_role modulo the mechanical incumbent-gate renumber)
    and authority/runner; the Q09<-Q10A promotion is the only exemption."""

    draft = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    v3 = {g.id: g for g in gate_manifest.load_gate_manifest(gate_manifest.V3_MANIFEST).gates}
    source_by_gate = gate_manifest.V4_SOURCE_BY_GATE

    checked_mapped = 0
    for gate in draft.gates:
        source = v3.get(source_by_gate[gate.id])
        if source is None:
            # The only None source is the promoted non-top-level Q10A stage.
            assert gate.id == "Q09"
            assert source_by_gate[gate.id] == "Q10A"
            continue
        checked_mapped += 1
        assert gate.name == source.name, gate.id
        assert gate.authority == source.authority, gate.id
        assert gate.runner == source.runner, gate.id
        assert gate.evidence_role == gate_manifest._v3_role_to_v4(source.evidence_role), gate.id

    # Q00-Q08 plus the eight renumbered Phase-2/3 gates.
    assert checked_mapped == 17

    # The renumbered incumbent reference is the tracked v4 number, not a stale
    # v3 one and not a dropped suffix, and carries no new "holdout" criterion.
    q14 = next(g for g in draft.gates if g.id == "Q14")
    assert q14.name == "Best-Settings Head-to-Head"
    assert q14.evidence_role == "SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT_Q11"
    assert gate_manifest._v3_role_to_v4("DEPLOYMENT_READINESS") == "DEPLOYMENT_READINESS"


def test_v4_criteria_drift_from_v3_source_is_rejected(tmp_path: Path) -> None:
    """A silent criteria change on a mapped gate must fail closed, so a v3 pass
    can never be reused as a v4 pass under different stated criteria."""

    raw = json.loads(gate_manifest.V4_DRAFT_MANIFEST.read_text(encoding="utf-8"))

    def load_with_q14(**overrides: str) -> None:
        mutated = json.loads(json.dumps(raw))
        q14 = next(g for g in mutated["gates"] if g["id"] == "Q14")
        q14.update(overrides)
        path = tmp_path / "gate_manifest.v4.draft.json"
        path.write_text(json.dumps(mutated), encoding="utf-8")
        with pytest.raises(gate_manifest.GateManifestError, match="criteria drift"):
            gate_manifest.load_gate_manifest(path)

    # Added "+ Holdout" criterion (the exact drift the reviewer flagged).
    load_with_q14(name="Best-Settings Head-to-Head + Holdout")
    # Dropped incumbent-gate reference suffix entirely.
    load_with_q14(evidence_role="SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT")
    # Stale v3 number kept instead of the faithful v4 renumber.
    load_with_q14(evidence_role="SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT_Q10")
    # Authority tamper on a mapped Phase-2 gate.
    load_with_q14(authority="OWNER")


def test_v4_sha256_is_stable_and_binds_exact_draft_bytes() -> None:
    first = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    second = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    expected = hashlib.sha256(gate_manifest.V4_DRAFT_MANIFEST.read_bytes()).hexdigest()

    assert first.sha256 == second.sha256 == expected
    # LF-pinned hash of the criteria-preserving v4 draft (a4990f77a). The
    # manifest is byte-normalised to LF via .gitattributes so this stays stable
    # on both autocrlf (VPS) and LF (CI) checkouts; see review fix P2 #4.
    assert expected == "c51fbfffb1aca470207bc0d027b172625e8680095a7a5c75ceed6327e48ae0bc"


def test_v4_activation_guard_and_future_final_path_fail_closed(tmp_path: Path) -> None:
    original = json.loads(gate_manifest.V4_DRAFT_MANIFEST.read_text(encoding="utf-8"))

    # A future final filename is accepted only when its ACTIVE record is complete.
    active = json.loads(json.dumps(original))
    active["status"] = "ACTIVE"
    active["extension_topology"]["activation_guard"] = {
        "state": "ACTIVE",
        "requires_completed_review": "OWNER-RATIFY-GATE-MANIFEST-V4",
        "requires_approver": "OWNER",
        "default_manifest_switch": True,
        "activated_by": "OWNER",
        "activated_at": "2026-08-23T12:00:00Z",
        "review_refs": ["owner-ratification", "migration-review"],
    }
    final_path = tmp_path / gate_manifest.V4_MANIFEST.name
    final_path.write_text(json.dumps(active), encoding="utf-8")
    assert gate_manifest.load_gate_manifest(final_path).activation_state == "ACTIVE"

    missing_refs = json.loads(json.dumps(active))
    missing_refs["extension_topology"]["activation_guard"]["review_refs"] = []
    final_path.write_text(json.dumps(missing_refs), encoding="utf-8")
    with pytest.raises(gate_manifest.GateManifestError, match="review_refs"):
        gate_manifest.load_gate_manifest(final_path)

    # The checked-in READ_INERT draft can never be treated as DEFAULT_MANIFEST.
    saved = gate_manifest.DEFAULT_MANIFEST
    gate_manifest.DEFAULT_MANIFEST = gate_manifest.V4_DRAFT_MANIFEST
    try:
        with pytest.raises(
            gate_manifest.GateManifestError, match="cannot be loaded as the default"
        ):
            gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    finally:
        gate_manifest.DEFAULT_MANIFEST = saved


def test_v3_changes_no_authority_runner_next_or_verdict_dimension() -> None:
    v2 = gate_manifest.load_gate_manifest(gate_manifest.V2_MANIFEST)
    v3 = gate_manifest.load_gate_manifest(gate_manifest.V3_MANIFEST)

    def frozen_fields(gate: gate_manifest.Gate) -> tuple[object, ...]:
        return gate.id, gate.ordinal, gate.authority, gate.runner, gate.next

    assert [frozen_fields(gate) for gate in v3.gates] == [
        frozen_fields(gate) for gate in v2.gates
    ]
    assert v3.verdict_dimensions == v2.verdict_dimensions
    assert dict(v3.legacy_aliases) == dict(v2.legacy_aliases)


def test_manifest_alias_inverse_is_complete_and_has_no_invented_keys() -> None:
    contract = gate_manifest.load_gate_manifest()

    for qid in contract.phase_ids:
        expected = tuple(
            alias for alias, target in contract.legacy_aliases.items() if target == qid
        )
        assert phase_ids.Q_TO_LEGACY_ALIASES[qid] == expected
    assert "Q06" not in phase_ids.Q_TO_LEGACY_P
    assert "Q09" not in phase_ids.Q_TO_LEGACY_P
    assert "Q10" not in phase_ids.Q_TO_LEGACY_P


def test_write_contract_rejects_aliases_and_unknown_values() -> None:
    assert gate_manifest.write_phase_id("Q08") == "Q08"
    assert gate_manifest.write_phase_id("Q14") == "Q14"
    assert gate_manifest.write_phase_id("Q15") == "Q15"
    assert gate_manifest.write_phase_id("Q16") == "Q16"
    for noncanonical in (" q08 ", "q08", "Q8"):
        with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
            gate_manifest.write_phase_id(noncanonical)
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("P8")
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("Q17")


def test_loaded_contract_cannot_be_mutated_by_a_consumer() -> None:
    contract = gate_manifest.load_gate_manifest()

    with pytest.raises(TypeError):
        contract.legacy_aliases["P8"] = "Q09"
    with pytest.raises(TypeError):
        contract.extension_topology["optimization_fork"]["from"] = "Q09"


def test_read_contract_accepts_only_explicit_aliases() -> None:
    assert gate_manifest.read_phase_id("p8") == "Q08"
    assert gate_manifest.read_phase_id("q09") == "Q09"
    with pytest.raises(gate_manifest.GateManifestError, match="unknown"):
        gate_manifest.read_phase_id("P9N")


def test_duplicate_json_keys_and_non_contiguous_gates_fail_closed(tmp_path: Path) -> None:
    raw = gate_manifest.DEFAULT_MANIFEST.read_text(encoding="utf-8")
    duplicate = raw.replace(
        '"pipeline_version": "V5-Q10A-Q16-TARGET-2026-08-22",',
        '"pipeline_version": "V5-Q10A-Q16-TARGET-2026-08-22", "pipeline_version": "bad",',
    )
    duplicate_path = tmp_path / "duplicate.json"
    duplicate_path.write_text(duplicate, encoding="utf-8")
    with pytest.raises(gate_manifest.GateManifestError, match="duplicate JSON key"):
        gate_manifest.load_gate_manifest(duplicate_path)

    value = json.loads(raw)
    value["gates"][4]["next"] = "Q06"
    broken_path = tmp_path / "broken.json"
    broken_path.write_text(json.dumps(value), encoding="utf-8")
    with pytest.raises(gate_manifest.GateManifestError, match="non-contiguous"):
        gate_manifest.load_gate_manifest(broken_path)


def test_schemas_declare_closed_v1_v2_v3_and_v4_contracts() -> None:
    v1 = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v1.schema.json").read_text(encoding="utf-8")
    )
    v2 = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v2.schema.json").read_text(encoding="utf-8")
    )
    v3 = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v3.schema.json").read_text(encoding="utf-8")
    )
    v4 = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v4.schema.json").read_text(encoding="utf-8")
    )
    assert v1["additionalProperties"] is False
    assert v1["properties"]["gates"]["minItems"] == 14
    assert v1["properties"]["gates"]["maxItems"] == 14
    assert v2["additionalProperties"] is False
    assert v2["properties"]["gates"]["minItems"] == 17
    assert v2["properties"]["gates"]["maxItems"] == 17
    assert v2["properties"]["extension_topology"]["additionalProperties"] is False
    assert v3["additionalProperties"] is False
    assert v3["properties"]["gates"]["minItems"] == 17
    assert v3["properties"]["gates"]["maxItems"] == 17
    assert v3["properties"]["extension_topology"]["additionalProperties"] is False
    assert v4["additionalProperties"] is False
    assert v4["properties"]["gates"]["minItems"] == 18
    assert v4["properties"]["gates"]["maxItems"] == 18
    assert v4["$defs"]["extensionTopology"]["additionalProperties"] is False


def test_v3_json_schema_validates_candidate_when_jsonschema_is_available() -> None:
    jsonschema = pytest.importorskip("jsonschema")
    schema = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v3.schema.json").read_text(encoding="utf-8")
    )
    manifest = json.loads(gate_manifest.V3_MANIFEST.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(schema)
    jsonschema.validate(instance=manifest, schema=schema)


def test_v4_json_schema_validates_draft_when_jsonschema_is_available() -> None:
    jsonschema = pytest.importorskip("jsonschema")
    schema = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v4.schema.json").read_text(encoding="utf-8")
    )
    manifest = json.loads(gate_manifest.V4_DRAFT_MANIFEST.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(schema)
    jsonschema.validate(instance=manifest, schema=schema)


def test_v3_fail_closed_on_baseline_cap_dependency_or_activation_drift(tmp_path: Path) -> None:
    original = json.loads(gate_manifest.V3_MANIFEST.read_text(encoding="utf-8"))
    mutations = [
        ("baseline", lambda value: value["extension_topology"]["baseline_stage"].update({"reuse_policy": "REUSE_ANY_Q08"})),
        ("cap", lambda value: value["extension_topology"]["optimization_fork"].update({"pattern_filter_cap_per_direction": 4})),
        ("dependency", lambda value: value["extension_topology"]["q16_dependencies"][0].update({"source_phase": "Q10"})),
        ("activation", lambda value: value["extension_topology"]["activation_guard"].update({"review_refs": ["9b40ff25"]})),
    ]
    for name, mutate in mutations:
        value = json.loads(json.dumps(original))
        mutate(value)
        path = tmp_path / f"broken_{name}.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        with pytest.raises(gate_manifest.GateManifestError, match="v3"):
            gate_manifest.load_gate_manifest(path)


def test_v3_activation_guard_fail_closed_invariants(tmp_path: Path) -> None:
    original = json.loads(gate_manifest.V3_MANIFEST.read_text(encoding="utf-8"))

    def _write(value: dict[str, object], name: str) -> Path:
        path = tmp_path / f"guard_{name}.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    # ACTIVE requires BOTH review refs.
    for bad_refs in ([], ["9b40ff25"], ["d5c13a08"], ["other"]):
        value = json.loads(json.dumps(original))
        value["extension_topology"]["activation_guard"]["review_refs"] = bad_refs
        with pytest.raises(gate_manifest.GateManifestError, match="review refs"):
            gate_manifest.load_gate_manifest(_write(value, "refs"))

    # ACTIVE must switch the default.
    value = json.loads(json.dumps(original))
    value["extension_topology"]["activation_guard"]["default_manifest_switch"] = False
    with pytest.raises(gate_manifest.GateManifestError, match="must switch the default"):
        gate_manifest.load_gate_manifest(_write(value, "switch"))

    # A READ_INERT manifest can never become the default.
    inert_guard = {
        "state": "READ_INERT",
        "requires_completed_review": "OPS-Q10-REALIGN-E1-E2",
        "requires_approver": "CLAUDE",
        "default_manifest_switch": False,
    }
    value = json.loads(json.dumps(original))
    value["extension_topology"]["activation_guard"] = dict(inert_guard)
    inert_path = _write(value, "inert")
    # Loaded off the default path a READ_INERT manifest is a valid fixture ...
    assert gate_manifest.load_gate_manifest(inert_path).activation_state == "READ_INERT"
    # ... but it may never be loaded as the active default.
    saved = gate_manifest.DEFAULT_MANIFEST
    gate_manifest.DEFAULT_MANIFEST = inert_path
    try:
        with pytest.raises(
            gate_manifest.GateManifestError, match="cannot be loaded as the default"
        ):
            gate_manifest.load_gate_manifest(inert_path)
    finally:
        gate_manifest.DEFAULT_MANIFEST = saved

    # A READ_INERT guard that tries to set the switch is rejected outright.
    value = json.loads(json.dumps(original))
    value["extension_topology"]["activation_guard"] = {
        **inert_guard, "default_manifest_switch": True,
    }
    with pytest.raises(gate_manifest.GateManifestError, match="v3"):
        gate_manifest.load_gate_manifest(_write(value, "inert_switch"))


def test_v2_topology_and_legacy_aliases_fail_closed(tmp_path: Path) -> None:
    raw = json.loads(gate_manifest.V2_MANIFEST.read_text(encoding="utf-8"))
    raw["extension_topology"]["optimization_fork"]["rejoins"] = "Q12"
    broken_fork = tmp_path / "broken_fork.json"
    broken_fork.write_text(json.dumps(raw), encoding="utf-8")
    with pytest.raises(gate_manifest.GateManifestError, match="optimization fork"):
        gate_manifest.load_gate_manifest(broken_fork)

    raw = json.loads(gate_manifest.V2_MANIFEST.read_text(encoding="utf-8"))
    raw["legacy_aliases"]["P10"] = "Q16"
    broken_alias = tmp_path / "broken_alias.json"
    broken_alias.write_text(json.dumps(raw), encoding="utf-8")
    with pytest.raises(gate_manifest.GateManifestError, match="legacy_aliases"):
        gate_manifest.load_gate_manifest(broken_alias)


def test_renderers_use_shared_phase_ids_without_local_display_maps() -> None:
    cockpit_source = (STRATEGY_FARM / "render_cockpit.py").read_text(encoding="utf-8")
    dashboard_source = (
        STRATEGY_FARM / "dashboards" / "render_dashboards.py"
    ).read_text(encoding="utf-8")

    assert "\nPHASE_DISPLAY =" not in cockpit_source
    assert "_q_with_legacy =" not in cockpit_source
    assert "Q_DISPLAY_ORDER = [" not in cockpit_source
    assert "PHASE_NAME.get(phase, phase)" in cockpit_source
    assert "next_phase_id" in dashboard_source
    assert "PHASE_ORDER[idx + 1]" not in dashboard_source
    assert "phase_label(phase, include_name=True)" in dashboard_source

    from tools.strategy_farm import render_cockpit
    from tools.strategy_farm.dashboards import render_dashboards

    contract = gate_manifest.load_gate_manifest()
    for alias, target in contract.legacy_aliases.items():
        assert render_cockpit.phase_label(alias) == target
        assert render_dashboards.phase_label(alias) == target
    assert render_cockpit.phase_label("P5b") == "Q05"
    assert render_dashboards.qxx_text("legacy P5c and P9b") == "legacy Q05 and Q12"


def test_state_name_adapter_display_ids_match_manifest() -> None:
    repo_root = STRATEGY_FARM.parents[1]
    adapter = json.loads(
        (repo_root / "framework" / "registry" / "state_name_adapter.json").read_text(
            encoding="utf-8"
        )
    )
    contract = gate_manifest.load_gate_manifest()

    assert {
        alias.upper(): target for alias, target in adapter["phase_display_id"].items()
    } == dict(contract.legacy_aliases)
    for state in adapter["owner_state_to_v5"].values():
        legacy = str(state.get("phase") or "").upper()
        if legacy in contract.legacy_aliases:
            assert state["display_phase"] == contract.legacy_aliases[legacy]
