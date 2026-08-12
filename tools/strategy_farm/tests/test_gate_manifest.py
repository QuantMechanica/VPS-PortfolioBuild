from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import gate_manifest  # noqa: E402
import phase_ids  # noqa: E402


def test_manifest_v2_matches_current_phase_contract_and_fork() -> None:
    contract = gate_manifest.load_gate_manifest()

    assert list(contract.phase_ids) == phase_ids.PHASE_ORDER
    assert contract.names == phase_ids.PHASE_NAME
    assert dict(contract.legacy_aliases) == phase_ids.LEGACY_P_TO_Q
    assert contract.verdict_dimensions == gate_manifest.REQUIRED_VERDICT_DIMENSIONS
    assert contract.schema_version == "qm.gate-manifest/v2"
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
    current = gate_manifest.load_gate_manifest()

    assert contract.schema_version == "qm.gate-manifest/v1"
    assert contract.phase_ids == tuple(f"Q{i:02d}" for i in range(14))
    assert contract.extension_topology is None
    assert contract.next_by_phase["Q13"] is None
    assert current.gates[:14] == contract.gates
    assert dict(current.legacy_aliases) == dict(contract.legacy_aliases)
    assert current.verdict_dimensions == contract.verdict_dimensions
    assert gate_manifest.write_phase_id("Q13", contract) == "Q13"
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("Q14", contract)


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
        '"pipeline_version": "V5-Q00-Q16-OPT-2026-08-12",',
        '"pipeline_version": "V5-Q00-Q16-OPT-2026-08-12", "pipeline_version": "bad",',
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


def test_schemas_declare_closed_v1_and_v2_contracts() -> None:
    v1 = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v1.schema.json").read_text(encoding="utf-8")
    )
    v2 = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v2.schema.json").read_text(encoding="utf-8")
    )
    assert v1["additionalProperties"] is False
    assert v1["properties"]["gates"]["minItems"] == 14
    assert v1["properties"]["gates"]["maxItems"] == 14
    assert v2["additionalProperties"] is False
    assert v2["properties"]["gates"]["minItems"] == 17
    assert v2["properties"]["gates"]["maxItems"] == 17
    assert v2["properties"]["extension_topology"]["additionalProperties"] is False


def test_v2_topology_and_legacy_aliases_fail_closed(tmp_path: Path) -> None:
    raw = json.loads(gate_manifest.DEFAULT_MANIFEST.read_text(encoding="utf-8"))
    raw["extension_topology"]["optimization_fork"]["rejoins"] = "Q12"
    broken_fork = tmp_path / "broken_fork.json"
    broken_fork.write_text(json.dumps(raw), encoding="utf-8")
    with pytest.raises(gate_manifest.GateManifestError, match="optimization fork"):
        gate_manifest.load_gate_manifest(broken_fork)

    raw = json.loads(gate_manifest.DEFAULT_MANIFEST.read_text(encoding="utf-8"))
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
    assert "next_phase_id" in dashboard_source
    assert "PHASE_ORDER[idx + 1]" not in dashboard_source

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
