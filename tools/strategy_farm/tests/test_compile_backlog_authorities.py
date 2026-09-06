"""Exact CEO-selected backlog bindings and append-only successor behaviour."""
import copy
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import compile_work_items as cwi


AUTHORITIES = tuple(cwi.BACKLOG_SOURCE_REPAIR_REGISTRATIONS)


def context(tmp_path, monkeypatch, authority):
    binding = cwi.BACKLOG_SOURCE_REPAIR_REGISTRATIONS[authority]
    evidence = tmp_path / binding.get("evidence_path", cwi.BACKLOG_SOURCE_REPAIR_EVIDENCE)
    evidence.parent.mkdir(parents=True)
    evidence.write_bytes(b"CEO selected current committed source; predecessors remain evidence\n")
    if "evidence_sha256" in binding:
        monkeypatch.setitem(binding, "evidence_sha256", cwi.sha256_file(evidence))
    else:
        monkeypatch.setattr(cwi, "BACKLOG_SOURCE_REPAIR_EVIDENCE_SHA256", cwi.sha256_file(evidence))
    rows = [{"id": ident, "phase": cwi.COMPILE_EA_PHASE, "status": item["status"],
             "verdict": item["verdict"], "claimed_by": None,
             "payload_json": json.dumps({"ea_label": binding["ea_label"], "mq5_sha256": item["source_sha256"]})}
            for ident, item in binding["predecessors"].items()]
    args = {"repo_root": tmp_path, "ea_id": binding["ea_id"], "source_sha": binding["source_sha256"],
            "inventory": {"work_rows": {binding["ea_id"]: rows}}}
    return binding, evidence, rows, args


@pytest.mark.parametrize("authority", AUTHORITIES)
def test_each_registered_authority_is_exact_and_self_expiring(tmp_path, monkeypatch, authority):
    binding, evidence, rows, args = context(tmp_path, monkeypatch, authority)
    label = binding["ea_label"]
    assert cwi._source_repair_authorized(label, authority, **args)
    assert not cwi._source_repair_authorized(label, authority + ":other", **args)
    assert not cwi._source_repair_authorized(label + "-other", authority, **args)
    for field, value in [("source_sha", "0" * 64), ("ea_id", "999999"), ("repo_root", None), ("inventory", None)]:
        assert not cwi._source_repair_authorized(label, authority, **{**args, field: value})
    if rows:
        for field, value in [("id", "unknown"), ("phase", "Q02"), ("status", "active"),
                             ("verdict", "UNEXPECTED_VERDICT"), ("claimed_by", "T1"), ("payload_json", "{}")]:
            changed = copy.deepcopy(args)
            changed["inventory"]["work_rows"][binding["ea_id"]][0][field] = value
            assert not cwi._source_repair_authorized(label, authority, **changed)
        missing = copy.deepcopy(args)
        missing["inventory"]["work_rows"][binding["ea_id"]] = rows[1:]
        assert not cwi._source_repair_authorized(label, authority, **missing)
    evidence.write_bytes(b"changed evidence")
    assert not cwi._source_repair_authorized(label, authority, **args)
    evidence.unlink()
    assert not cwi._source_repair_authorized(label, authority, **args)


@pytest.mark.parametrize("authority", AUTHORITIES)
def test_worker_rechecks_exact_successor_lineage_and_evidence(tmp_path, monkeypatch, authority):
    binding, _, rows, args = context(tmp_path, monkeypatch, authority)
    payload = {"append_only_source_repair": True, "compile_source_repair_authority": authority,
               "mq5_sha256": binding["source_sha256"],
               "source_repair_predecessor_work_item_ids": sorted(binding["predecessors"]),
               "source_repair_superseded_predecessor_work_item_ids": binding["superseded_predecessors"],
               "source_repair_artifact_bindings": cwi._backlog_source_repair_artifact_bindings(authority)}
    rows.append({"id": "successor", "phase": cwi.COMPILE_EA_PHASE, "status": "active", "payload_json": json.dumps(payload)})
    assert cwi._source_repair_authorized(binding["ea_label"], authority, **args, current_work_item_id="successor")
    assert not cwi._source_repair_authorized(binding["ea_label"], authority, **args, current_work_item_id="absent")
    for key in payload:
        bad = {k: v for k, v in payload.items() if k != key}
        rows[-1]["payload_json"] = json.dumps(bad)
        assert not cwi._source_repair_authorized(binding["ea_label"], authority, **args, current_work_item_id="successor")


@pytest.mark.parametrize("ea", ["1538", "41164", "41165", "41166", "41172", "41193"])
def test_candidate_waives_only_governed_blockers_and_keeps_exact_predecessors(tmp_path, monkeypatch, ea):
    authority = next(a for a in AUTHORITIES if cwi.BACKLOG_SOURCE_REPAIR_REGISTRATIONS[a]["ea_id"] == ea)
    binding, _, rows, args = context(tmp_path, monkeypatch, authority)
    binding = copy.deepcopy(binding)
    label = binding["ea_label"]
    folder = tmp_path / "framework/EAs" / label
    folder.mkdir(parents=True)
    source = folder / (label + ".mq5")
    source.write_bytes(b"#property strict\n// D1 fixture\n")
    binding["source_sha256"] = cwi.sha256_file(source)
    monkeypatch.setitem(cwi.BACKLOG_SOURCE_REPAIR_REGISTRATIONS, authority, binding)
    inventory = args["inventory"]
    inventory.update({"open_compile": {ea: [r for r in rows if r["status"] == "pending"]},
                      "registry_by_id": {ea: [{"status": "active"}]},
                      "active_magics": {ea: [{"symbol": "EURUSD.DWX"}]}, "build_ids": set()})
    monkeypatch.setattr(cwi, "infer_timeframe", lambda *a: {"timeframe": "D1", "source": "fixture", "candidates": ["D1"]})
    monkeypatch.setattr(cwi, "_bound_setfile_hashes", lambda p: ["historical-bound-set"])
    candidate = cwi.classify_candidate(tmp_path / "farm", tmp_path, label, inventory, source_repair_authority=authority)
    assert candidate["eligible"] is True
    assert set(candidate["source_repair_waived_reasons"]) == {"WORK_ITEMS_EXIST", "BOUND_SETFILE_HASH_EXISTS"}
    assert candidate["source_repair_predecessor_work_item_ids"] == sorted(binding["predecessors"])
    assert candidate["source_repair_superseded_predecessor_work_item_ids"] == binding["superseded_predecessors"]
    assert candidate["source_repair_artifact_bindings"] == cwi._backlog_source_repair_artifact_bindings(authority)
    # An already-open successor remains idempotent, and an unrelated source is refused.
    new = {"id": "already-open", "phase": cwi.COMPILE_EA_PHASE, "status": "pending",
           "payload_json": json.dumps({"mq5_sha256": binding["source_sha256"]})}
    rows.append(new)
    inventory["open_compile"][ea].append(new)
    again = cwi.classify_candidate(tmp_path / "farm", tmp_path, label, inventory, source_repair_authority=authority)
    assert again["reason"] == "OPEN_COMPILE_EA_EXISTS"
    new["payload_json"] = json.dumps({"mq5_sha256": "a" * 64})
    assert not cwi._source_repair_authorized(label, authority, **{**args, "source_sha": binding["source_sha256"]})


# Router ticket 690fc42a: EA_ML_FORBIDDEN predicate defect, EA source UNCHANGED.
ML_PREDICATE_AUTHORITY = "router_ops_issue:690fc42a-ab37-4c25-82e4-afbc51b23d7b:QM5_41193"


def _canonical_sha256(path: Path) -> str:
    """Hash the canonical LF bytes; a CRLF checkout must not move the binding."""
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def test_ml_predicate_registration_binds_the_unchanged_committed_source():
    binding = cwi.BACKLOG_SOURCE_REPAIR_REGISTRATIONS[ML_PREDICATE_AUTHORITY]
    assert binding["ea_id"] == "41193"
    assert binding["ea_label"] == "QM5_41193_xtixng-fracd-rv"
    assert binding["superseded_predecessors"] == []
    assert binding["evidence_path"] == "docs/ops/evidence/2026-09-06_ml_predicate_sweep_690fc42a.md"
    assert list(binding["predecessors"]) == ["37e3b310-7384-48df-8d3a-92eb4f80c0da"]
    predecessor = binding["predecessors"]["37e3b310-7384-48df-8d3a-92eb4f80c0da"]
    assert predecessor["status"] == "failed"
    assert predecessor["verdict"] == "COMPILE_FAIL"
    # The predicate was fixed, not the EA: successor and predecessor share one source.
    assert predecessor["source_sha256"] == binding["source_sha256"]
    assert cwi._backlog_source_repair_artifact_bindings(ML_PREDICATE_AUTHORITY) == [
        {"path": binding["evidence_path"], "sha256": binding["evidence_sha256"]}
    ]


def test_ml_predicate_registration_matches_the_committed_repo_bytes():
    repo_root = Path(__file__).resolve().parents[3]
    binding = cwi.BACKLOG_SOURCE_REPAIR_REGISTRATIONS[ML_PREDICATE_AUTHORITY]
    label = binding["ea_label"]
    source = repo_root / "framework" / "EAs" / label / (label + ".mq5")
    evidence = repo_root / binding["evidence_path"]
    if not source.exists() or not evidence.exists():  # pragma: no cover - partial checkout
        pytest.skip("checkout does not carry the bound artifacts")
    assert _canonical_sha256(source) == binding["source_sha256"]
    assert _canonical_sha256(evidence) == binding["evidence_sha256"]


def test_ml_predicate_authority_refuses_a_different_source_or_a_missing_predecessor(tmp_path, monkeypatch):
    binding, _, rows, args = context(tmp_path, monkeypatch, ML_PREDICATE_AUTHORITY)
    label = binding["ea_label"]
    assert cwi._source_repair_authorized(label, ML_PREDICATE_AUTHORITY, **args)
    # A recompiled/edited source is not covered by this authority.
    assert not cwi._source_repair_authorized(
        label, ML_PREDICATE_AUTHORITY, **{**args, "source_sha": "b" * 64})
    # The failed predecessor must still be present, unclaimed and COMPILE_FAIL.
    for mutation in ({"id": "other"}, {"status": "done"}, {"verdict": "COMPILE_OK"},
                     {"claimed_by": "T4"}, {"phase": "Q02"}):
        changed = copy.deepcopy(args)
        changed["inventory"]["work_rows"]["41193"][0].update(mutation)
        assert not cwi._source_repair_authorized(label, ML_PREDICATE_AUTHORITY, **changed)
    empty = copy.deepcopy(args)
    empty["inventory"]["work_rows"]["41193"] = []
    assert not cwi._source_repair_authorized(label, ML_PREDICATE_AUTHORITY, **empty)
    # An unrelated in-flight compile on a different source is not waived.
    rows.append({"id": "in-flight", "phase": cwi.COMPILE_EA_PHASE, "status": "pending",
                 "payload_json": json.dumps({"mq5_sha256": "c" * 64})})
    assert not cwi._source_repair_authorized(label, ML_PREDICATE_AUTHORITY, **args)


FRAMEWORK_INPUT_PIN_AUTHORITIES = tuple(
    sorted(cwi.FRAMEWORK_INPUT_PIN_SOURCE_REPAIR_REGISTRATIONS)
)
FRAMEWORK_INPUT_PIN_WAVE1_AUTHORITIES = tuple(
    sorted(cwi.FRAMEWORK_INPUT_PIN_WAVE1_SOURCE_REPAIR_REGISTRATIONS)
)


@pytest.mark.parametrize("authority", FRAMEWORK_INPUT_PIN_AUTHORITIES)
def test_framework_input_pin_authority_matches_repaired_source_and_evidence(authority):
    binding = cwi.FRAMEWORK_INPUT_PIN_SOURCE_REPAIR_REGISTRATIONS[authority]
    repo_root = Path(__file__).resolve().parents[3]
    source = (
        repo_root / "framework" / "EAs" / binding["ea_label"]
        / f'{binding["ea_label"]}.mq5'
    )
    assert _canonical_sha256(source) == binding["source_sha256"]
    evidence = repo_root / binding["evidence_path"]
    if not evidence.exists():
        evidence = Path(r"C:\QM\repo") / binding["evidence_path"]
    assert hashlib.sha256(evidence.read_bytes()).hexdigest() == binding["evidence_sha256"]
    assert len(binding["predecessors"]) == 1
    predecessor = next(iter(binding["predecessors"].values()))
    assert predecessor["status"] == "done"
    assert predecessor["verdict"] == "COMPILE_OK"
    assert predecessor["source_sha256"] != binding["source_sha256"]


@pytest.mark.parametrize("authority", FRAMEWORK_INPUT_PIN_AUTHORITIES)
def test_framework_input_pin_authority_dry_run_is_eligible(tmp_path, monkeypatch, authority):
    binding, _evidence, _rows, args = context(tmp_path, monkeypatch, authority)
    assert cwi._source_repair_authorized(binding["ea_label"], authority, **args)


def test_framework_input_pin_wave1_registration_is_exact_and_hash_bound():
    assert len(FRAMEWORK_INPUT_PIN_WAVE1_AUTHORITIES) == 70
    assert all(authority.startswith(
        "router_ops_issue:0b971b15-c37f-4ea6-8304-f61d76433862:QM5_"
    ) for authority in FRAMEWORK_INPUT_PIN_WAVE1_AUTHORITIES)
    repo_root = Path(__file__).resolve().parents[3]
    evidence = repo_root / cwi.FRAMEWORK_INPUT_PIN_WAVE1_EVIDENCE
    assert hashlib.sha256(evidence.read_bytes()).hexdigest() == (
        cwi.FRAMEWORK_INPUT_PIN_WAVE1_EVIDENCE_SHA256
    )
    for authority in FRAMEWORK_INPUT_PIN_WAVE1_AUTHORITIES:
        binding = cwi.FRAMEWORK_INPUT_PIN_WAVE1_SOURCE_REPAIR_REGISTRATIONS[authority]
        source = repo_root / "framework" / "EAs" / binding["ea_label"] / (
            binding["ea_label"] + ".mq5"
        )
        assert source.read_bytes().count(b"\r") == 0
        assert hashlib.sha256(source.read_bytes()).hexdigest() == binding["source_sha256"]
