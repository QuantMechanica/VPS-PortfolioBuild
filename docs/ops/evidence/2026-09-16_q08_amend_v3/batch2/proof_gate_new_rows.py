"""D1 batch-2 five-proof gate on the 8 FRESH Q08 rows (mirrors batch-1 proof_gate_new_rows.json).

(a) card hashes: live card sha256 == journal card_sha_after for each EA
(b) declaration correctness: declaration() parses; candidate (ea_id/symbol/timeframe), spec_sha256,
    complete, no_optimization_search, research_trial_count=0; locked_parameters == effective(mq5,set)
(c) claimability_precheck on the NEW row: claimable (no BUILD_IDENTITY_MISMATCH)
identity: new row payload expected_mq5/ex5/setfile_sha256 + artifact_identity AND the
    mq5/ex5/setfile_sha256 work_items columns byte-equal to current canonical disk hashes
lineage: payload promoted_from_phase='Q07' and promoted_from_work_item == the bound Q07 predecessor
(d) factory-search clean on the NEW row (_factory_search_before_q08_claim with synthetic claimed_at)
(e) wiki: see wiki_cohort_check.py (ZERO_D1_ATTRIBUTABLE_DRIFT cohort standard)
Also: no holds on any new row; old row remains pending/NULL verdict with only a supersedes edge.
Writes proof_gate_new_rows.json. Read-only.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools/strategy_farm"))
sys.path.insert(0, str(REPO))
import dsr_cohort  # noqa: E402
import dsr_single_configuration as single  # noqa: E402

OUT_DIR = Path(__file__).parent
EVID = OUT_DIR.parent
CARDS_D = Path("D:/QM/strategy_farm/artifacts/cards_approved")
JOURNAL = EVID / "card_amend_journal.jsonl"
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"

NEW_ROWS = {
    "456f590f": {"ea": "QM5_10287", "new_id": "e1c0d6c1-1108-4974-ba3b-0a0bab7bfe9c"},
    "ff0b551b": {"ea": "QM5_9576", "new_id": "3043d412"},
    "a591ff4c": {"ea": "QM5_1230", "new_id": "db1da509"},
    "885b82ab": {"ea": "QM5_9973", "new_id": "aa660882"},
    "bb5eccf7": {"ea": "QM5_13012", "new_id": "bc626c1f"},
    "1494bfb4": {"ea": "QM5_11882", "new_id": "8dac9856"},
    "b11e5b43": {"ea": "QM5_10269", "new_id": "12d85591"},
    "aec37e79": {"ea": "QM5_10280", "new_id": "d3f0090c"},
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    journal = {}
    for line in JOURNAL.read_text(encoding="utf-8").splitlines():
        if line.strip():
            rec = json.loads(line)
            journal.setdefault(rec["row"].split("-")[0], rec)
    q07_map = {r["q08_prefix"]: r for r in json.loads((OUT_DIR / "q07_predecessor_map.json").read_text())}
    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    claimed_at = datetime.now(timezone.utc).isoformat()
    out, all_ok = {}, True
    for prefix, spec in NEW_ROWS.items():
        ea = spec["ea"]
        j = journal[prefix]
        label = Path(j["card_d"]).stem if j.get("card_d") else None
        if label is None:
            label = next(p.name for p in CARDS_D.glob(f"{ea}_*"))
        ea_dir = REPO / "framework" / "EAs" / label
        card_file = CARDS_D / f"{label}.md"
        card_bytes = card_file.read_bytes()

        row = conn.execute("SELECT * FROM work_items WHERE id LIKE ? AND phase='Q08'", (spec["new_id"] + "%",)).fetchone()
        if row is None:
            out[prefix] = {"ea_id": ea, "error": "new row not found"}
            all_ok = False
            continue
        payload = json.loads(row["payload_json"] or "{}")

        # (b) declaration
        decl_errs = []
        decl_ok = True
        try:
            decl = single.declaration(card_bytes)
            if {k: decl.get(k) for k in ("ea_id", "symbol", "timeframe")} != {"ea_id": ea, "symbol": row["symbol"], "timeframe": j["timeframe"]}:
                decl_ok = False; decl_errs.append("candidate mismatch")
            if decl.get("spec_sha256") != sha(ea_dir / "SPEC.md"):
                decl_ok = False; decl_errs.append("spec sha mismatch")
            if decl["locked_parameters"] != single.effective_parameters((ea_dir / f"{label}.mq5").read_bytes(), Path(row["setfile_path"]).read_bytes()):
                decl_ok = False; decl_errs.append("locked parameter drift")
            if not (decl.get("complete") and decl.get("no_optimization_search") and decl.get("research_trial_count") == 0):
                decl_ok = False; decl_errs.append("truth flags")
        except Exception as exc:  # noqa: BLE001
            decl_ok = False; decl_errs.append(f"declaration:{exc}")

        precheck = dsr_cohort.claimability_precheck(conn, dict(row), payload)

        disk = {"mq5": sha(ea_dir / f"{label}.mq5"), "ex5": sha(ea_dir / f"{label}.ex5"),
                "setfile": sha(Path(row["setfile_path"]))}
        identity_ok = (
            (row["mq5_sha256"] or None) == disk["mq5"]
            and (row["ex5_sha256"] or None) == disk["ex5"]
            and (row["setfile_sha256"] or None) == disk["setfile"]
            and payload.get("expected_mq5_sha256") == disk["mq5"]
            and payload.get("expected_ex5_sha256") == disk["ex5"]
            and payload.get("expected_setfile_sha256") == disk["setfile"]
            and (payload.get("artifact_identity") or {}).get("mq5_sha256", (payload.get("artifact_identity") or {}).get("ex5_sha256")) is not None
        )
        q07 = q07_map[prefix]
        lineage_ok = (
            payload.get("promoted_from_phase") == "Q07"
            and payload.get("promoted_from_work_item") == q07["q07_id"]
        )
        fs = dsr_cohort._factory_search_before_q08_claim(conn, dict(row), {**payload, "claimed_at_iso": claimed_at})
        holds = conn.execute("SELECT COUNT(*) c FROM work_item_holds WHERE work_item_id=? AND active=1", (row["id"],)).fetchone()["c"]
        old_row = conn.execute("SELECT id, status, verdict FROM work_items WHERE id LIKE ?", (prefix + "%",)).fetchone()
        disp = conn.execute(
            "SELECT w.kind, w.verdict FROM work_item_supersedes s JOIN work_items w ON w.id = s.superseded_by_work_item_id WHERE s.work_item_id = ?",
            (old_row["id"],)).fetchone()

        rec = {
            "ea_id": ea, "symbol": row["symbol"], "new_id": row["id"], "new_status": row["status"],
            "q07_id": q07["q07_id"],
            "a_card_hash_ok": sha(card_file) == j["card_sha_after"],
            "b_declaration_ok": decl_ok, "b_decl_err": decl_errs,
            "c_precheck": precheck,
            "identity_bound_to_current": bool(identity_ok),
            "lineage_ok": bool(lineage_ok),
            "d_factory_search_clean": fs["complete"] and not fs["optimization_rows"],
            "d_work_items_examined": fs["work_items_examined"],
            "holds_active_on_new_row": holds,
            "old_row": {"status": old_row["status"], "verdict": old_row["verdict"],
                        "disposition": disp["verdict"] if disp else None},
        }
        rec["ok"] = (rec["a_card_hash_ok"] and decl_ok and precheck.get("claimable") and identity_ok
                     and lineage_ok and rec["d_factory_search_clean"] and holds == 0
                     and old_row["status"] == "pending" and old_row["verdict"] is None and disp is not None)
        all_ok = all_ok and rec["ok"]
        out[prefix] = rec
        print(prefix, ea, row["id"][:8], "OK" if rec["ok"] else f"FAIL {rec}")
    (OUT_DIR / "proof_gate_new_rows.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
    print("ALL OK" if all_ok else "SOME FAILED")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
