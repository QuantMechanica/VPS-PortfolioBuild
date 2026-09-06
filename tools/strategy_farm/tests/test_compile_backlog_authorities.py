"""Exact CEO-selected backlog bindings and append-only successor behaviour."""
import copy
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


@pytest.mark.parametrize("ea", ["1538", "41164", "41165", "41166", "41172"])
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
