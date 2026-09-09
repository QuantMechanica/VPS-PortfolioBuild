"""Read-only authentication of the already-reviewed, exact Balke recovery.

This is not generic sibling approval. The pinned September 1 registration and
the separately released review hold authorize only this existing measurement
program. Historical rows remain byte-for-byte unchanged, including provenance.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

Q12_ID = "2ea9cd64-2f17-5444-bcff-ad50f4481831"
PROGRAM_ID = "DL089_QM5_41097_USDJPY_DWX_2019_2025"
REGISTRATION_SHA = "00cc3f4895ca04dd030fa95e726a780f680b8052dbfd6e8e95753f109f745b55"
REVIEW_HOLD = "Q12_LEGACY_CENSUS_RECOVERY_REVIEW_PENDING"


def _read_bound(binding):
    path = Path(binding["path"])
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != binding["sha256"]:
        raise ValueError(f"legacy recovery binding drift: {path}")
    return raw


def authenticate(conn, q12_row, artifact_root: Path):
    try:
        from tools.strategy_farm.recover_legacy_opt_census import _done_row_digest, _canonical_bytes
    except ModuleNotFoundError:
        from recover_legacy_opt_census import _done_row_digest, _canonical_bytes

    payload = json.loads(q12_row["payload_json"])
    recovery = payload.get("legacy_census_recovery") or {}
    declaration = payload["pattern_filter_sweep"]
    if (q12_row["id"] != Q12_ID or q12_row["ea_id"] != "QM5_13213"
            or q12_row["symbol"] != "USDJPY.DWX"
            or declaration["program_id"] != PROGRAM_ID
            or recovery.get("schema") != "qm.dl089-legacy-census-recovery/v1"):
        raise ValueError("legacy recovery is outside the reviewed exact scope")
    hold = conn.execute("SELECT * FROM work_item_holds WHERE work_item_id=?", (Q12_ID,)).fetchone()
    if (hold is None or hold["hold_code"] != REVIEW_HOLD or hold["active"]
            or not hold["released_at"] or not hold["release_note"]):
        raise ValueError("legacy recovery independent review release is missing")
    base = artifact_root / PROGRAM_ID
    reg = json.loads(_read_bound({"path": str(base / "runner_registration.json"), "sha256": REGISTRATION_SHA}))
    unsigned = {k: v for k, v in declaration.items() if k != "declaration_sha256"}
    if hashlib.sha256(_canonical_bytes(unsigned)).hexdigest() != declaration["declaration_sha256"]:
        raise ValueError("legacy declaration content hash mismatch")
    for key, expected in (("q12_work_item_id", Q12_ID), ("program_id", PROGRAM_ID),
                          ("subject_ea_id", "QM5_13213"), ("measurement_ea_id", "QM5_41097"),
                          ("declaration_sha256", declaration["declaration_sha256"]),
                          ("annual_cells_sha256", declaration["annual_cells_sha256"]),
                          ("wf_cells_sha256", declaration["wf_cells_sha256"])):
        if reg.get(key) != expected:
            raise ValueError(f"legacy registration identity mismatch: {key}")
    sealed_declaration = json.loads((base / "q12_declaration.json").read_text(encoding="utf-8"))
    if sealed_declaration != declaration:
        raise ValueError("legacy declaration payload differs from recovery artifact")
    _read_bound(reg["legacy_source_ledger"])
    bindings = reg["measurement_bindings"]
    for binding in bindings.values():
        _read_bound(binding)
    q02 = conn.execute("SELECT * FROM work_items WHERE id=?", (reg["legacy_q02_work_item_id"],)).fetchone()
    if (q02 is None or q02["ea_id"] != "QM5_41097" or q02["symbol"] != "USDJPY.DWX"
            or q02["phase"] != "Q02" or q02["status"] != "done" or q02["verdict"] != "PASS"
            or q02["ex5_sha256"] != bindings["binary"]["sha256"]
            or q02["mq5_sha256"] != bindings["source"]["sha256"]
            or Path(q02["evidence_path"]) != Path(reg["legacy_q02_evidence"]["path"])):
        raise ValueError("legacy measurement Q02 identity is no longer valid")
    _read_bound(reg["legacy_q02_evidence"])
    adoption = json.loads(_read_bound({"path": reg["done_adoption_path"], "sha256": reg["done_adoption_sha256"]}))
    ids = [r["work_item_id"] for r in adoption["rows"]]
    if len(ids) != 486 or len(set(ids)) != 486 or adoption["q12_work_item_id"] != Q12_ID:
        raise ValueError("legacy adoption universe mismatch")
    rows = conn.execute("SELECT * FROM work_items WHERE id IN (" + ",".join("?" * len(ids)) + ")", ids).fetchall()
    if len(rows) != 486 or _done_row_digest(rows) != adoption["done_rows_digest"]:
        raise ValueError("legacy adopted rows changed after independent review")
    for record in adoption["rows"]:
        _read_bound({"path": record["evidence_path"], "sha256": record["evidence_sha256"]})
    source = Path(bindings["source"]["path"])
    return {
        "ea_id": "QM5_41097", "ea_label": source.stem, "timeframe": "H1",
        "ea_dir": source.parent, "source": source,
        "binary": Path(bindings["binary"]["path"]),
        "source_base_setfile": Path(bindings["setfile"]["path"]),
        "base_setfile": Path(bindings["setfile"]["path"]),
        "card_path": bindings["card"]["path"], "bindings": bindings,
        "legacy_adopted_ids": frozenset(ids),
        "legacy_q02": {"created": False, "work_item_id": q02["id"], "status": "done", "verdict": "PASS"},
    }
