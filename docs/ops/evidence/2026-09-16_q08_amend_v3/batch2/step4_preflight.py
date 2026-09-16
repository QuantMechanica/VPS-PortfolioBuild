"""D1 batch-2 step 4 (read-only): Q07 predecessor map + current build hashes + enqueue preflight mirror.

Mirrors the enqueue-backtest cascade gates batch-1 used (repair_fresh_enqueue/fresh_enqueue_preflight.txt):
  - Q07 predecessor: most recent Q07 row for (ea_id, symbol) with status=done AND verdict=PASS
    (batch-2 watch: for QM5_10269/QM5_10280 the Q07 completed TODAY 2026-09-16 — the bound
    predecessor must be that fresh PASS row, not an older symbol)
  - artifact failure mirror: exactly one EA dir, exactly one <label>.ex5 inside
  - setfile exists; Q07/Q08 setfile agreement
  - current build hashes (mq5/ex5/setfile/spec/card) from canonical EA dir + card dir
Writes q07_predecessor_map.json, ea_current_build_hashes.json, fresh_enqueue_preflight.txt.
Read-only.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

REPO = Path("C:/QM/repo")
OUT_DIR = Path(__file__).parent
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
EA_ROOT = REPO / "framework" / "EAs"
CARDS_D = Path("D:/QM/strategy_farm/artifacts/cards_approved")
BATCH2 = ["456f590f", "ff0b551b", "a591ff4c", "885b82ab", "bb5eccf7", "1494bfb4", "b11e5b43", "aec37e79"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    step1 = {r["prefix"]: r for r in json.loads((OUT_DIR / "step1_staged_match.json").read_text())["batch2_step1"]}
    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    pred_map, hashes, lines = [], {}, []
    all_ok = True
    for prefix in BATCH2:
        s1 = step1[prefix]
        ea_id, symbol = s1["ea_id"], s1["symbol"]
        label = s1["label"]
        q08_row = conn.execute("SELECT * FROM work_items WHERE id LIKE ?", (prefix + "%",)).fetchone()
        # Q07 predecessor: newest done/PASS for same symbol
        q07 = conn.execute(
            "SELECT id, status, verdict, symbol, setfile_path, updated_at FROM work_items "
            "WHERE ea_id=? AND phase='Q07' AND status='done' AND symbol=? ORDER BY updated_at DESC LIMIT 1",
            (ea_id, symbol)).fetchone()
        q07_ok = bool(q07 and q07["verdict"] == "PASS")
        # artifact-failure mirror
        ea_dirs = sorted(p for p in EA_ROOT.glob(f"{ea_id}_*") if p.is_dir())
        ex5_files = sorted(p.name for p in ea_dirs[0].glob("*.ex5")) if len(ea_dirs) == 1 else []
        artifact_failure = None
        if len(ea_dirs) != 1:
            artifact_failure = {"reason": "ea_dir_missing_or_ambiguous", "dirs": [d.name for d in ea_dirs]}
        elif ex5_files != [f"{label}.ex5"]:
            artifact_failure = {"reason": "duplicate_or_missing_ex5", "detail": ex5_files}
        ea_dir = ea_dirs[0] if len(ea_dirs) == 1 else None
        setfile_q08 = Path(q08_row["setfile_path"])
        setfile_q07 = Path(q07["setfile_path"]) if q07 else None
        setfile_exists = setfile_q08.is_file()
        same_setfile = bool(setfile_q07 and setfile_q07.name == setfile_q08.name)
        files_ok = {}
        h = {"ea": ea_id, "symbol": symbol, "label": label}
        if ea_dir is not None:
            for role, p in (("mq5", ea_dir / f"{label}.mq5"), ("ex5", ea_dir / f"{label}.ex5"),
                            ("spec", ea_dir / "SPEC.md"), ("setfile", setfile_q08),
                            ("card", CARDS_D / f"{label}.md")):
                files_ok[role] = p.is_file()
                h[f"{role}_sha"] = sha(p) if p.is_file() else None
        h["files_ok"] = files_ok
        hashes[prefix] = h
        gates = {"q07_done_pass": q07_ok, "setfile_exists": setfile_exists,
                 "artifact_failure": artifact_failure, "q07_q08_same_setfile": same_setfile,
                 "files_ok_all": all(files_ok.values())}
        ok = q07_ok and setfile_exists and artifact_failure is None and same_setfile and all(files_ok.values())
        all_ok = all_ok and ok
        pred_map.append({
            "q08_prefix": prefix, "q08_id": q08_row["id"], "ea_id": ea_id, "symbol": symbol,
            "q07_id": q07["id"] if q07 else None, "q07_prefix": q07["id"][:8] if q07 else None,
            "q07_status": q07["status"] if q07 else None, "q07_verdict": q07["verdict"] if q07 else None,
            "q07_updated_at": q07["updated_at"] if q07 else None,
            "q07_setfile": str(setfile_q07) if setfile_q07 else None,
            "q08_setfile": str(setfile_q08),
            "predecessor_ok": q07_ok, "card_has_declaration": b"qm-dsr-single-configuration" in (CARDS_D / f"{label}.md").read_bytes(),
        })
        lines.append(f"{prefix} {ea_id} {symbol} Q07={q07['id'][:8] if q07 else 'NONE'}({q07['status'] if q07 else '-'}/{q07['verdict'] if q07 else '-'}) "
                     f"setfile_exists={setfile_exists} same_setfile={same_setfile} artifact_failure={artifact_failure} bindings_ok={all(files_ok.values())}")
        print(lines[-1])
    (OUT_DIR / "q07_predecessor_map.json").write_text(json.dumps(pred_map, indent=2), encoding="utf-8")
    (OUT_DIR / "ea_current_build_hashes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    (OUT_DIR / "fresh_enqueue_preflight.txt").write_text(
        "FRESH-ENQUEUE PREFLIGHT batch-2 (read-only mirror of enqueue_cascade_backtest_for_ea gates)\n"
        + "\n".join(lines) + ("\nALL PREFLIGHT GATES PASS\n" if all_ok else "\nSOME GATES FAILED\n"), encoding="utf-8")
    print("ALL PREFLIGHT GATES PASS" if all_ok else "SOME GATES FAILED")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
