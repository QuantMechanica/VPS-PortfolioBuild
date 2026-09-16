"""D1 batch-2 post-amend proofs (a)+(b)+pre-repair precheck, mirroring batch1_proofs.json.

For each of the 8 amended batch-2 rows:
  - live card sha256 == journal card_sha_after == staged manifest card_sha_after_staged (proof a)
  - declaration() parses; candidate/spec/locked-parameter correctness (proof b)
  - claimability_precheck on the STAGED row (expect BUILD_IDENTITY_MISMATCH:mq5 — the D1-class
    defect that the disposition+fresh-enqueue repair removes)
  - factory-search-ledger check with a synthetic claimed_at (proof d axis): expect CLEAN
  - full assemble_single_configuration with claimed_at_iso: expect the ONLY refusal to be
    the build-identity gate (orthogonal to the declaration)
Writes batch2_proofs.json. Read-only.
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

EVID = REPO / "docs/ops/evidence/2026-09-16_q08_amend_v3"
STAGED_MANIFEST = REPO / "docs/ops/evidence/2026-09-16_q08_dsr_unblock/staged_card_amendment/manifest.json"
JOURNAL = EVID / "card_amend_journal.jsonl"
OUT = EVID / "batch2/batch2_proofs.json"
STAGED = REPO / "docs/ops/evidence/2026-09-16_q08_dsr_unblock/staged_card_amendment"
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
BATCH2 = ["456f590f", "ff0b551b", "a591ff4c", "885b82ab", "bb5eccf7", "1494bfb4", "b11e5b43", "aec37e79"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    manifest = {m["row"].split("-")[0]: m for m in json.loads(STAGED_MANIFEST.read_text(encoding="utf-8"))}
    journal = {}
    for line in JOURNAL.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        rec = json.loads(line)
        journal.setdefault(rec["row"].split("-")[0], rec)  # first occurrence = this batch's amend
    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    out = {}
    all_ok = True
    claimed_at = datetime.now(timezone.utc).isoformat()
    for prefix in BATCH2:
        m = manifest[prefix]
        j = journal.get(prefix) or {}
        label = Path(m["card_d"]).stem
        ea_dir = Path(m["setfile"]).parent.parent
        card_d = Path(m["card_d"])
        card_bytes = card_d.read_bytes()
        live_sha = hashlib.sha256(card_bytes).hexdigest()
        row = conn.execute("SELECT * FROM work_items WHERE id LIKE ?", (prefix + "%",)).fetchone()
        payload = json.loads(row["payload_json"] or "{}")

        # proof (b): declaration correctness
        decl_ok, decl_why = True, "ok"
        locked_match = False
        locked_count = None
        try:
            decl = single.declaration(card_bytes)
            candidate = {"ea_id": m["ea_id"], "symbol": m["symbol"], "timeframe": m["timeframe"]}
            if {k: decl.get(k) for k in ("ea_id", "symbol", "timeframe")} != candidate:
                decl_ok, decl_why = False, "candidate mismatch"
            elif decl.get("spec_sha256") != sha(ea_dir / "SPEC.md"):
                decl_ok, decl_why = False, "spec sha mismatch"
            else:
                effective = single.effective_parameters((ea_dir / f"{label}.mq5").read_bytes(), Path(m["setfile"]).read_bytes())
                locked_match = decl["locked_parameters"] == effective
                locked_count = len(decl["locked_parameters"])
                if not locked_match:
                    decl_ok, decl_why = False, "locked parameter drift"
                elif not (decl.get("complete") and decl.get("no_optimization_search") and decl.get("research_trial_count") == 0):
                    decl_ok, decl_why = False, "truth flags wrong"
        except Exception as exc:  # noqa: BLE001
            decl_ok, decl_why = False, f"declaration:{exc}"

        precheck = dsr_cohort.claimability_precheck(conn, dict(row), payload)
        fs = dsr_cohort._factory_search_before_q08_claim(
            conn, dict(row), {**payload, "claimed_at_iso": claimed_at})
        assemble_ok, assemble_err, mode = True, None, None
        try:
            assembled = dsr_cohort.assemble_single_configuration(
                conn, dict(row), {**payload, "claimed_at_iso": claimed_at},
                m["timeframe"], None, None)
            mode = assembled.get("mode")
        except Exception as exc:  # noqa: BLE001
            assemble_ok, assemble_err = False, repr(exc)

        # staged .AMENDED.staged.md was built under the V2 citation at staging time; the governed
        # apply writes the V3 citation (tool constants). Proof (a) per batch-1 standard: live ==
        # journal.card_sha_after, and the amend chained from the staged-before bytes. The
        # declaration ``` block must be byte-identical between live and staged (only the two
        # citation lines above it may differ).
        staged_bytes = (STAGED / f"{label}.AMENDED.staged.md").read_bytes()
        block_live = card_bytes.split(b"```qm-dsr-single-configuration", 1)[1]
        block_staged = staged_bytes.split(b"```qm-dsr-single-configuration", 1)[1]
        rec = {
            "ea_id": m["ea_id"], "label": label,
            "hashes_match": live_sha == j.get("card_sha_after") and j.get("card_sha_before") == m["card_sha_before"],
            "declaration_block_byte_identical_to_staged": block_live == block_staged,
            "card_sha_after": live_sha,
            "journal": {"before": j.get("card_sha_before"), "after": j.get("card_sha_after")},
            "declaration_correct": decl_ok, "declaration_why": decl_why,
            "locked_params_match_effective": locked_match,
            "locked_parameter_count": locked_count,
            "manifest_locked_parameter_count": m["locked_parameter_count"],
            "count_match": locked_count == m["locked_parameter_count"],
            "precheck": precheck,
            "factory_search": {"clean": fs["complete"] and not fs["optimization_rows"],
                               "work_items_examined": fs["work_items_examined"],
                               "optimization_rows": fs["optimization_rows"]},
            "assemble_ok": assemble_ok, "assemble_error": assemble_err, "assemble_mode": mode,
        }
        ok = (rec["hashes_match"] and rec["declaration_block_byte_identical_to_staged"]
              and decl_ok and locked_match and rec["count_match"]
              and not precheck.get("claimable")
              and precheck.get("reason", "").startswith("SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH")
              and rec["factory_search"]["clean"]
              and not assemble_ok and "BUILD_IDENTITY_MISMATCH" in (assemble_err or ""))
        rec["ok"] = ok
        all_ok = all_ok and ok
        out[prefix] = rec
        print(prefix, m["ea_id"], "OK" if ok else f"FAIL {rec}")
    OUT.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print("ALL OK" if all_ok else "SOME FAILED", "->", OUT)
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
