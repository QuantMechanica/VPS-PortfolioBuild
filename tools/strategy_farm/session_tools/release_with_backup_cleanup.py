"""Release held COMPILE_EA rows one by one (governed release_compile_wave.py --work-item-id --apply) and, after each
release, delete the redundant per-call pre-mutation backups it wrote, keeping the newest one per class.

Why: release_compile_wave writes a fresh 701 MB backup per call (identity reuse fails because holds change); on
2026-09-06 this drove D: to 43.8 GB and the tester cache purge tore down idle workers. Until ticket 70f55cbf lands,
this wrapper keeps the disk flat. Receipt of deletions: docs/ops/evidence/<date>_backup_cleanup_receipt_<hhmmZ>.json.

Usage: python release_with_backup_cleanup.py <authority-substring> "<release note>"
"""
import datetime
import json
import pathlib
import shutil
import sqlite3
import subprocess
import sys

REPO = pathlib.Path(r"C:\QM\repo")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
BACKUPS = pathlib.Path(r"D:\QM\strategy_farm\state\backups")
CLASS = "farm_state_before_compile_wave_"
auth_sub = sys.argv[1]
note = sys.argv[2]


def held_rows():
    con = sqlite3.connect(DB, uri=True, timeout=30)
    rows = con.execute(
        "select w.id, w.ea_id from work_items w join work_item_holds h on h.work_item_id=w.id and h.active=1 "
        "where w.phase='COMPILE_EA' and w.status='pending' and json_extract(w.payload_json,'$.compile_source_repair_authority') like ? "
        "order by w.ea_id", (f"%{auth_sub}%",)).fetchall()
    con.close()
    return rows


def cleanup():
    files = sorted([f for f in BACKUPS.iterdir() if f.name.startswith(CLASS) and f.suffix == ".sqlite"],
                   key=lambda f: f.stat().st_mtime, reverse=True)
    deleted = []
    for f in files[1:]:
        side = f.with_name(f.name + ".identity.json")
        deleted.append({"file": f.name, "bytes": f.stat().st_size})
        f.unlink()
        if side.exists():
            side.unlink()
    return deleted


def log(msg):
    print(f"{datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')} {msg}", flush=True)


rows = held_rows()
log(f"held rows for authority {auth_sub}: {len(rows)}")
released = []
deleted_all = []
for wid, ea in rows:
    r = subprocess.run([sys.executable, str(REPO / "tools/strategy_farm/release_compile_wave.py"), "--work-item-id", wid,
                        "--apply", "--release-note", note], capture_output=True, text=True, cwd=str(REPO))
    out = r.stdout + r.stderr
    ok = '"release_count": 1' in out
    released.append((ea, wid, ok))
    log(f"release {ea} {wid[:8]} ok={ok}")
    deleted_all += cleanup()
    free = shutil.disk_usage("D:/").free / 2 ** 30
    log(f"  cleanup deleted={len(deleted_all)} total, D: free {free:.1f} GB")
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%H%MZ")
receipt = {"schema": "qm.backup-cleanup-receipt/v1", "at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "actor": "claude-session-018mXkPPkaHQ2fPuduPCBcWc", "reason": "per-row release backups (701 MB each) deleted right after each release; newest one kept",
           "released": [{"ea_id": e, "work_item_id": w, "ok": o} for e, w, o in released], "deleted": deleted_all,
           "deleted_bytes": sum(d["bytes"] for d in deleted_all), "d_free_gb_after": round(shutil.disk_usage("D:/").free / 2 ** 30, 1)}
p = REPO / f"docs/ops/evidence/{datetime.date.today().isoformat()}_backup_cleanup_receipt_{stamp}.json"
p.write_text(json.dumps(receipt, indent=1), encoding="utf-8")
log(f"done: released {sum(1 for _,_,o in released if o)}/{len(released)}; receipt {p.name}")
