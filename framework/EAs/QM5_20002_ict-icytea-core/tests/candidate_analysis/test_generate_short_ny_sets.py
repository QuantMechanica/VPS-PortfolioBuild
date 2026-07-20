from __future__ import annotations

import importlib.util
import json
from pathlib import Path


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "generate_short_ny_sets.py"
)
SPEC = importlib.util.spec_from_file_location("generate_short_ny_sets", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(subject)


def test_compile_binding_is_exact_and_remains_research_only() -> None:
    binding = subject.load_compile_binding()
    assert binding["research_status"] == "CARD_INTAKE_NOT_APPROVED"
    assert binding["release_state"] == "RESEARCH_CANDIDATE_CARD_INTAKE_NOT_APPROVED"
    assert binding["compile"]["evidence_sha256"] == subject.EXPECTED_COMPILE_EVIDENCE_SHA256
    assert binding["compiled_binary"]["sha256"] == subject.EXPECTED_COMPILED_EX5_SHA256


def test_frozen_family_has_four_complete_sets_and_manifest() -> None:
    contract = subject.load_contract()
    assert contract["schema_version"] == 2
    assert contract["contract_revision"] == 3
    assert [row["role"] for row in contract["data_bindings"]["news_calendars"]] == [
        "PRIMARY_QM_NEWS_CALENDAR",
        "SECONDARY_QM_NEWS_CALENDAR_REQUIRED_BY_QM_NewsInit",
    ]
    outputs = subject.build_outputs(contract)
    assert len(outputs) == 5
    set_outputs = {path: raw for path, raw in outputs.items() if path.suffix == ".set"}
    assert len(set_outputs) == 4
    assert all(raw.count(b"\n") == 63 for raw in set_outputs.values())
    assert all(
        f"; compile_binding_sha256={subject.EXPECTED_COMPILE_BINDING_SHA256}\n".encode()
        in raw
        for raw in set_outputs.values()
    )
    assert all(
        f"; compile_evidence_sha256={subject.EXPECTED_COMPILE_EVIDENCE_SHA256}\n".encode()
        in raw
        for raw in set_outputs.values()
    )
    assert all(
        f"; compiled_ex5_sha256={subject.EXPECTED_COMPILED_EX5_SHA256}\n".encode()
        in raw
        for raw in set_outputs.values()
    )
    assert all(b"TradeLongs=false\n" in raw for raw in set_outputs.values())
    assert all(b"TradeShorts=true\n" in raw for raw in set_outputs.values())
    assert all(b"KZ_London_on=false\n" in raw for raw in set_outputs.values())
    assert all(b"KZ_NewYork_on=true\n" in raw for raw in set_outputs.values())

    manifest = json.loads(outputs[subject.MANIFEST_PATH].decode("ascii"))
    assert manifest["schema_version"] == 2
    assert manifest["contract_sha256"] == subject.EXPECTED_CONTRACT_SHA256
    assert manifest["compile_binding_commit"] == subject.COMPILE_BINDING_COMMIT
    assert manifest["compile_binding_sha256"] == subject.EXPECTED_COMPILE_BINDING_SHA256
    assert manifest["compile_evidence_sha256"] == subject.EXPECTED_COMPILE_EVIDENCE_SHA256
    assert manifest["compiled_ex5_git_commit"] == subject.COMPILED_EX5_COMMIT
    assert manifest["compiled_ex5_sha256"] == subject.EXPECTED_COMPILED_EX5_SHA256
    assert [(row["arm"], row["symbol"]) for row in manifest["sets"]] == [
        ("A_SHORT_NY_NO_HTF", "EURUSD.DWX"),
        ("A_SHORT_NY_NO_HTF", "GBPUSD.DWX"),
        ("B_SHORT_NY_H1_BIAS", "EURUSD.DWX"),
        ("B_SHORT_NY_H1_BIAS", "GBPUSD.DWX"),
    ]
    assert {row["visible_input_count"] for row in manifest["sets"]} == {52}


def test_only_preregistered_arm_axis_changes() -> None:
    outputs = subject.build_outputs(subject.load_contract())
    eur_a = outputs[
        subject.OUTPUT_ROOT / "QM5_20002_EURUSD_DWX_M1_short_ny_no_htf.set"
    ].decode("ascii")
    eur_b = outputs[
        subject.OUTPUT_ROOT / "QM5_20002_EURUSD_DWX_M1_short_ny_h1_bias.set"
    ].decode("ascii")
    normalized_a = eur_a.replace("A_SHORT_NY_NO_HTF", "ARM").replace(
        "short_ny_no_htf", "ARM"
    ).replace("UseHTFBias=false", "UseHTFBias=AXIS")
    normalized_b = eur_b.replace("B_SHORT_NY_H1_BIAS", "ARM").replace(
        "short_ny_h1_bias", "ARM"
    ).replace("UseHTFBias=true", "UseHTFBias=AXIS")
    assert normalized_a == normalized_b


def test_checked_in_outputs_match_generator() -> None:
    outputs = subject.build_outputs(subject.load_contract())
    for path, expected in outputs.items():
        assert path.read_bytes() == expected
