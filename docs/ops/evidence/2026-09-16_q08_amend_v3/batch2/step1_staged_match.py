"""D1 batch-2 step 1 (read-only): verify the 8 staged amendments still match current card bytes.

For each batch-2 manifest row:
  - live D: card sha256 == manifest card_sha_before (byte-unamended since D1 stopped)
  - live card carries no qm-dsr-single-configuration block
  - staged .AMENDED.staged.md sha256 == manifest card_sha_after_staged
  - C: mirror (repo copy) sha == live D: sha when the mirror exists
  - DB row state: status/verdict/claimed_by, existing supersedes edge, active holds
  - Q07 predecessor candidates (latest done/PASS Q07 per EA) for step-4 use
Writes step1_staged_match.json next to this script. Read-only: no DB or card writes.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

REPO = Path("C:/QM/repo")
MANIFEST = REPO / "docs/ops/evidence/2026-09-16_q08_dsr_unblock/staged_card_amendment/manifest.json"
STAGED = MANIFEST.parent
CARDS_C = REPO / "artifacts/cards_approved"
OUT = Path(__file__).parent / "step1_staged_match.json"
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"

BATCH2 = ["456f590f", "ff0b551b", "a591ff4c", "885b82ab", "bb5eccf7", "1494bfb4", "b11e5b43", "aec37e79"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    manifest = {m["row"].split("-")[0]: m for m in json.loads(MANIFEST.read_text(encoding="utf-8"))}
    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    rows = []
    ok_all = True
    for prefix in BATCH2:
        m = manifest[prefix]
        label = Path(m["card_d"]).stem
        card_d = Path(m["card_d"])
        staged = STAGED / f"{label}.AMENDED.staged.md"
        live_sha = sha(card_d)
        staged_sha = sha(staged) if staged.is_file() else None
        live_bytes = card_d.read_bytes()
        card_c = CARDS_C / (label + ".md")
        mirror_sha = sha(card_c) if card_c.is_file() else None

        wi = conn.execute("SELECT * FROM work_items WHERE id LIKE ?", (prefix + "%",)).fetchone()
        sup = conn.execute("SELECT superseded_by_work_item_id FROM work_item_supersedes WHERE work_item_id=?", (wi["id"],)).fetchone()
        holds = [dict(r) for r in conn.execute(
            "SELECT hold_code, active FROM work_item_holds WHERE work_item_id=? AND active=1", (wi["id"],))]
        q07s = [dict(r) for r in conn.execute(
            "SELECT id, status, verdict, symbol, setfile_path, updated_at FROM work_items "
            "WHERE ea_id=? AND phase='Q07' AND status='done' ORDER BY updated_at DESC", (m["ea_id"],))]

        checks = {
            "card_byte_unamended": live_sha == m["card_sha_before"],
            "no_declaration_block": b"qm-dsr-single-configuration" not in live_bytes,
            "staged_matches_manifest": staged_sha == m["card_sha_after_staged"],
            "mirror_matches_live": (mirror_sha == live_sha) if mirror_sha else None,
            "wi_pending": wi["status"] == "pending",
            "wi_not_claimed": not wi["claimed_by"],
            "not_superseded_yet": sup is None,
            "no_active_holds": len(holds) == 0,
            "q07_done_pass_exists": any(q["verdict"] == "PASS" for q in q07s),
        }
        ok = all(v is not False for v in checks.values())
        ok_all = ok_all and ok
        rows.append({
            "prefix": prefix, "ea_id": m["ea_id"], "symbol": m["symbol"], "label": label,
            "live_card_sha256": live_sha, "manifest_card_sha_before": m["card_sha_before"],
            "staged_sha256": staged_sha, "manifest_card_sha_after_staged": m["card_sha_after_staged"],
            "wi_id": wi["id"], "wi_status": wi["status"], "wi_verdict": wi["verdict"],
            "wi_claimed_by": wi["claimed_by"], "wi_mq5_sha256": wi["mq5_sha256"],
            "wi_ex5_sha256": wi["ex5_sha256"], "wi_setfile_sha256": wi["setfile_sha256"],
            "already_superseded_by": sup["superseded_by_work_item_id"] if sup else None,
            "active_holds": holds,
            "q07_candidates": q07s,
            "checks": checks, "ok": ok,
        })
        print(prefix, m["ea_id"], "OK" if ok else f"FAIL {checks}")
    OUT.write_text(json.dumps({"batch2_step1": rows, "all_ok": ok_all}, indent=2), encoding="utf-8")
    print("ALL OK" if ok_all else "SOME FAILED", "->", OUT)
    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main())
