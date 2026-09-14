"""Park every pending, unheld candidate whose RAM reservation class is a flat 44 GB (single_index_tick /
heavy_or_unknown_multisymbol) - Orchestrator 2026-09-14 03:5xZ, GRUEN queue/hold operation, reversible.

Why: 782 of the 851 rows in the canonical claim snapshot carried the 44 GB classes. Every worker scanned them
under FACTORY_MUTATION.lock (slow), skipped them all, deferred the few ordinary rows (8-preflight bound) and
lost the retry to the lock convoy -> fleet idle, watchdog dispatch_stall livelock. Parking them shrinks the scan
to runnable rows. Release condition: ticket 6cdc6811 (class calibration from measured peaks) or RAM upgrade.
Default dry-run (writes the plan); --apply parks in batches of 60 through governed_work_item_hold (one backup
per batch). Plan/journal: docs/ops/evidence/2026-09-14_44gb_reservation_park/.
"""
from __future__ import annotations
import argparse, datetime as dt, json, os, sqlite3, subprocess, sys
from pathlib import Path
sys.path.insert(0, "C:/QM/repo/tools/strategy_farm"); sys.path.insert(0, "C:/QM/repo"); os.chdir("C:/QM/repo")
import terminal_worker as tw, farmctl  # noqa: E402
EVID = Path("C:/QM/repo/docs/ops/evidence/2026-09-14_44gb_reservation_park"); EVID.mkdir(parents=True, exist_ok=True)
HOLD = "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914"
CLASSES = {"single_index_tick", "heavy_or_unknown_multisymbol"}

def plan() -> list[dict]:
    c = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True); c.row_factory = sqlite3.Row
    sql = farmctl.pending_claim_order_sql(); rows = c.execute(sql.replace("LIMIT ?", "LIMIT 5000") if "LIMIT ?" in sql else sql).fetchall()
    ms = tw._multisymbol_ea_ids(); out = []
    for r in rows:
        p = json.loads(r["payload_json"] or "{}")
        try:
            m = tw._work_item_is_multisymbol(r, p, ms); cls, gb, src = tw._ram_reservation_detail_for_candidate(r, p, m)
        except Exception as exc:
            continue
        if cls in CLASSES and float(gb) >= 44.0:
            out.append({"id": r["id"], "ea_id": r["ea_id"], "symbol": r["symbol"] or "", "phase": r["phase"], "ram_class": cls, "reservation_gb": gb})
    return out

def main() -> int:
    ap = argparse.ArgumentParser(); ap.add_argument("--apply", action="store_true"); ap.add_argument("--batch", type=int, default=60)
    a = ap.parse_args(); rows = plan()
    (EVID / "plan.json").write_text(json.dumps({"generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "hold_code": HOLD, "rows": rows}, indent=1), encoding="utf-8")
    from collections import Counter
    print("rows", len(rows), Counter((r["phase"], r["ram_class"]) for r in rows).most_common(8))
    if not a.apply:
        return 0
    journal = EVID / "hold_journal.jsonl"
    for i in range(0, len(rows), a.batch):
        batch = rows[i:i + a.batch]
        by_phase: dict[tuple, list] = {}
        for r in batch:
            by_phase.setdefault((r["phase"], r["ea_id"]), []).append(r)
        # governed tool takes one ea-id/phase per invocation -> group
        for (phase, ea), grp in by_phase.items():
            cmd = ["python", "-X", "utf8", "tools/strategy_farm/governed_work_item_hold.py", "apply", "--ea-id", ea, "--phase", phase,
                   "--hold-code", HOLD, "--reason", "2026-09-14 Orchestrator: flat 44 GB RAM reservation class cannot be admitted on the 63 GB host (52 GB free) except one row per ~2 h drain window; 782 such rows starved every claim scan (watchdog dispatch_stall livelock). Parked until class calibration (ticket 6cdc6811) or RAM upgrade.",
                   "--release-condition", "RAM reservation class recalibrated from measured peaks (ticket 6cdc6811) or host RAM upgraded; release via farmctl.release_work_item_hold"]
            for r in grp:
                cmd += ["--target", f"{r['id']}={r['symbol']}"]
            rr = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
            ok = rr.returncode == 0 and '"status": "ok"' in (rr.stdout or "")
            with journal.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "ea_id": ea, "phase": phase, "n": len(grp), "rc": rr.returncode, "ok": ok, "tail": ((rr.stdout or "") + (rr.stderr or ""))[-300:]}) + "\n")
            print(("ok " if ok else "FAIL "), ea, phase, len(grp))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
