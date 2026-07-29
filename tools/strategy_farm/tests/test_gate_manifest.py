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


def test_manifest_is_contiguous_and_matches_current_phase_contract() -> None:
    contract = gate_manifest.load_gate_manifest()

    assert list(contract.phase_ids) == phase_ids.PHASE_ORDER
    assert contract.names == phase_ids.PHASE_NAME
    assert contract.verdict_dimensions == gate_manifest.REQUIRED_VERDICT_DIMENSIONS
    assert contract.gates[-1].next is None
    assert len(contract.sha256) == 64


def test_write_contract_rejects_aliases_and_unknown_values() -> None:
    assert gate_manifest.write_phase_id("Q08") == "Q08"
    for noncanonical in (" q08 ", "q08", "Q8"):
        with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
            gate_manifest.write_phase_id(noncanonical)
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("P8")
    with pytest.raises(gate_manifest.GateManifestError, match="non-canonical"):
        gate_manifest.write_phase_id("Q14")


def test_loaded_contract_cannot_be_mutated_by_a_consumer() -> None:
    contract = gate_manifest.load_gate_manifest()

    with pytest.raises(TypeError):
        contract.legacy_aliases["P8"] = "Q09"


def test_read_contract_accepts_only_explicit_aliases() -> None:
    assert gate_manifest.read_phase_id("p8") == "Q08"
    assert gate_manifest.read_phase_id("q09") == "Q09"
    with pytest.raises(gate_manifest.GateManifestError, match="unknown"):
        gate_manifest.read_phase_id("P9N")


def test_duplicate_json_keys_and_non_contiguous_gates_fail_closed(tmp_path: Path) -> None:
    raw = gate_manifest.DEFAULT_MANIFEST.read_text(encoding="utf-8")
    duplicate = raw.replace(
        '"pipeline_version": "V5-Q00-Q13-2026-07-29",',
        '"pipeline_version": "V5-Q00-Q13-2026-07-29", "pipeline_version": "bad",',
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


def test_schema_declares_closed_contract() -> None:
    schema = json.loads(
        (STRATEGY_FARM / "schemas" / "gate_manifest.v1.schema.json").read_text(encoding="utf-8")
    )
    assert schema["additionalProperties"] is False
    assert schema["properties"]["gates"]["minItems"] == 14
    assert schema["properties"]["gates"]["maxItems"] == 14
