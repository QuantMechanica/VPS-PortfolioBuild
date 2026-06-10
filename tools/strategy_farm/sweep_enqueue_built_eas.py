"""One-shot sweep (Claude, 2026-06-10, OWNER-approved acceleration):

1. Enqueue Q02 work_items for built EAs (.ex5 on disk) that have ZERO
   work_items in the DB (never entered the pipeline). Symbol-staged per
   OWNER gate-acceleration #2: diverse stage-1 wave (<=3 symbols across
   asset buckets), remainder deferred to the sidecar.
2. Re-enqueue (ea, symbol, setfile) rows stranded on INFRA_FAIL at
   Q02/Q03/Q08 with nothing pending/active and no non-INFRA done row.
3. Promote deferred symbols (state/q02_deferred_symbols.json): an EA's
   deferred setfiles are enqueued as soon as ANY of its Q02 rows is a done
   PASS (a chance was found -> confirm breadth), or whenever the queue has
   spare capacity (pending < 50% of the ceiling). Deferral never kills a
   symbol; it only deprioritizes it (OWNER: symbols differ, do not miss a
   chance by gating on a subset).

Filters: registry status=active, no _obsolete_ dirs, setfiles must exist.
Idempotent: skips (ea,symbol,phase) pairs with pending/active rows.

Wave mode: never pushes the pending work_items queue above QUEUE_CEILING
(default 7000, soft build-backpressure is 8000) — part 1 enqueues whole EAs
in priority order until the ceiling, then stops. Re-running tops up the next
wave (EAs already enqueued have work_items and are skipped). Part 2
(stranded re-runs, ~76 rows) always runs. Designed to be safe under an
hourly scheduled task.

Usage: python claude_sweep_enqueue_2026-06-10.py [--apply] [--queue-ceiling N]
Default is dry-run. Evidence JSON written either way.
"""
import csv
import json
import re
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
EAS = Path(r"C:\QM\repo\framework\EAs")
REGISTRY = Path(r"C:\QM\repo\framework\registry\ea_id_registry.csv")
EVIDENCE = Path(r"D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json")
SETFILE_RE = re.compile(r"_([A-Z][A-Z0-9.]{2,})_([A-Z0-9]+)_backtest\.set$")
PRIORITY_EAS = {"QM5_1049", "QM5_1047", "QM5_1085", "QM5_1158"}
APPLY = "--apply" in sys.argv
QUEUE_CEILING = 7000
if "--queue-ceiling" in sys.argv:
    QUEUE_CEILING = int(sys.argv[sys.argv.index("--queue-ceiling") + 1])
NOW = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00")

sys.path.insert(0, r"C:\QM\repo\tools\strategy_farm")
import farmctl  # staging helpers (_stage_q02_setfiles, _record_q02_deferral)
try:
    import strategy_priority as _sp
    _SCORES = _sp.compute_scores()
except Exception:
    _SCORES = {}

def _prio(ea_id):
    # cohort first, then strategy_priority score desc, then stable id order
    return (0 if ea_id in PRIORITY_EAS else 1,
            -float(_SCORES.get(ea_id, {}).get("score", 0.0)),
            ea_id)

# --- registry: ea_id -> (status, slug) ---
reg = {}
with REGISTRY.open(encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        try:
            reg[int(row["ea_id"])] = (row["status"].strip().lower(), row["slug"].strip())
        except (KeyError, ValueError):
            continue

con = sqlite3.connect(DB)
con.row_factory = sqlite3.Row
cur = con.cursor()

wi_eas = {r[0] for r in cur.execute("SELECT DISTINCT ea_id FROM work_items")}

pending_now = cur.execute(
    "SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
budget = max(0, QUEUE_CEILING - pending_now)

report = {"generated_at": NOW, "apply": APPLY,
          "pending_at_start": pending_now, "queue_ceiling": QUEUE_CEILING,
          "wave_budget": budget,
          "part1_never_tested": {"enqueued": [], "skipped": []},
          "part2_stranded": {"enqueued": [], "skipped": []}}

def pending_active_exists(ea_id, symbol, phase):
    return cur.execute(
        "SELECT 1 FROM work_items WHERE ea_id=? AND symbol=? AND phase=? "
        "AND status IN ('pending','active') LIMIT 1", (ea_id, symbol, phase)
    ).fetchone() is not None

def insert_wi(phase, ea_id, symbol, setfile, payload):
    if APPLY:
        cur.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
            "status, attempt_count, payload_json, created_at, updated_at) "
            "VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', 0, ?, ?, ?)",
            (str(uuid.uuid4()), phase, ea_id, symbol, str(setfile),
             json.dumps(payload), NOW, NOW))

# ---------- Part 1: built, never tested ----------
ea_dirs = {}
for d in sorted(EAS.iterdir()):
    if not d.is_dir() or "_obsolete_" in d.name.lower():
        continue
    m = re.match(r"QM5_(\d+)", d.name)
    if not m:
        continue
    ea_dirs.setdefault(f"QM5_{m.group(1)}", []).append(d)

budget_left = budget
for ea_id in sorted((e for e in ea_dirs if e not in wi_eas), key=_prio):
    dirs = ea_dirs[ea_id]
    if budget_left <= 0:
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "reason": "queue_ceiling_reached"})
        continue
    num = int(ea_id.split("_")[1])
    status, slug = reg.get(num, (None, None))
    if status != "active":
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "reason": f"registry_status={status}"})
        continue
    # DL-069: prefer the registered-slug dir when multiple
    pick = None
    for d in dirs:
        if slug and d.name == f"{ea_id}_{slug}":
            pick = d
            break
    if pick is None:
        pick = dirs[0]
    if not any(pick.rglob("*.ex5")):
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "reason": "no_ex5", "dir": pick.name})
        continue
    sets = sorted((pick / "sets").glob("*_backtest.set")) if (pick / "sets").is_dir() else []
    if not sets:
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "reason": "no_setfiles", "dir": pick.name})
        continue
    parsed = []
    for sf in sets:
        m = SETFILE_RE.search(sf.name)
        if not m:
            report["part1_never_tested"]["skipped"].append(
                {"ea_id": ea_id, "reason": "setfile_parse_failed", "setfile": sf.name})
            continue
        parsed.append((sf, m.group(1), m.group(2)))
    stage1, deferred = farmctl._stage_q02_setfiles(parsed)
    if deferred and APPLY:
        farmctl._record_q02_deferral(ea_id, deferred, "sweep_enqueue")
    for _sf, _sym, _tf in deferred:
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "symbol": _sym, "reason": "staged_deferred_symbol"})
    for sf, symbol, tf in stage1:
        if pending_active_exists(ea_id, symbol, "Q02"):
            report["part1_never_tested"]["skipped"].append(
                {"ea_id": ea_id, "symbol": symbol, "reason": "existing_pending_active"})
            continue
        payload = {"host_symbol": symbol, "host_timeframe": tf,
                   "enqueued_by": "claude_sweep_enqueue_2026-06-10.never_tested",
                   "enqueued_at_utc": NOW}
        if ea_id in PRIORITY_EAS:
            payload["priority_track"] = True
        insert_wi("Q02", ea_id, symbol, sf, payload)
        budget_left -= 1
        report["part1_never_tested"]["enqueued"].append(
            {"ea_id": ea_id, "symbol": symbol, "setfile": sf.name,
             "priority_track": ea_id in PRIORITY_EAS})

# ---------- Part 2: stranded INFRA_FAIL at Q02/Q03/Q08 ----------
for phase in ("Q02", "Q03", "Q08"):
    stranded = [r[0] for r in cur.execute(f"""
        SELECT ea_id FROM work_items WHERE phase=? GROUP BY ea_id
        HAVING SUM(CASE WHEN status IN ('pending','active') THEN 1 ELSE 0 END)=0
           AND SUM(CASE WHEN status='done' AND verdict!='INFRA_FAIL' THEN 1 ELSE 0 END)=0
           AND SUM(CASE WHEN status='done' AND verdict='INFRA_FAIL' THEN 1 ELSE 0 END)>0
        """, (phase,))]
    for ea_id in stranded:
        num = int(ea_id.split("_")[1]) if ea_id.startswith("QM5_") else None
        status, _slug = reg.get(num, (None, None))
        if status != "active":
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "reason": f"registry_status={status}"})
            continue
        # one re-run per distinct (symbol, setfile), most recent INFRA_FAIL row
        rows = cur.execute(
            "SELECT symbol, setfile_path, MAX(updated_at) FROM work_items "
            "WHERE ea_id=? AND phase=? AND verdict='INFRA_FAIL' "
            "GROUP BY symbol, setfile_path", (ea_id, phase)).fetchall()
        for symbol, setfile, _ts in rows:
            if not setfile or not Path(setfile).is_file():
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "setfile_missing"})
                continue
            if pending_active_exists(ea_id, symbol, phase):
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "existing_pending_active"})
                continue
            payload = {"host_symbol": symbol,
                       "enqueued_by": "claude_sweep_enqueue_2026-06-10.stranded_infra_fail",
                       "enqueued_at_utc": NOW}
            insert_wi(phase, ea_id, symbol, setfile, payload)
            report["part2_stranded"]["enqueued"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "setfile": Path(setfile).name})

# ---------- Part 3: promote deferred symbols (gate-acceleration #2) ----------
report["part3_deferred_promotion"] = {"promoted": [], "kept_deferred": 0}
deferred_file = farmctl.Q02_DEFERRED_SYMBOLS_FILE
try:
    deferred_state = (json.loads(deferred_file.read_text(encoding="utf-8"))
                      if deferred_file.exists() else {})
except (json.JSONDecodeError, OSError):
    deferred_state = {}
if deferred_state:
    pending_q = cur.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
    spare_capacity = pending_q < QUEUE_CEILING * 0.5
    for ea_id in sorted(deferred_state):
        entry = deferred_state[ea_id]
        has_pass = cur.execute(
            "SELECT 1 FROM work_items WHERE ea_id=? AND phase='Q02' "
            "AND status='done' AND verdict='PASS' LIMIT 1", (ea_id,)).fetchone()
        if not (has_pass or spare_capacity):
            report["part3_deferred_promotion"]["kept_deferred"] += len(entry["setfiles"])
            continue
        for sf in entry["setfiles"]:
            if not Path(sf["setfile"]).is_file():
                continue
            if pending_active_exists(ea_id, sf["symbol"], "Q02"):
                continue
            payload = {"host_symbol": sf["symbol"], "host_timeframe": sf.get("tf"),
                       "enqueued_by": "sweep_enqueue.deferred_promotion",
                       "promotion_reason": "stage1_pass" if has_pass else "spare_capacity",
                       "enqueued_at_utc": NOW}
            insert_wi("Q02", ea_id, sf["symbol"], sf["setfile"], payload)
            report["part3_deferred_promotion"]["promoted"].append(
                {"ea_id": ea_id, "symbol": sf["symbol"],
                 "reason": payload["promotion_reason"]})
        if APPLY:
            deferred_state.pop(ea_id, None)
    if APPLY:
        deferred_file.write_text(json.dumps(deferred_state, indent=1),
                                 encoding="utf-8")

if APPLY:
    con.commit()
EVIDENCE.write_text(json.dumps(report, indent=1), encoding="utf-8")

p1, p2 = report["part1_never_tested"], report["part2_stranded"]
print(f"APPLY={APPLY}")
print(f"part1 never_tested: enqueued={len(p1['enqueued'])} skipped={len(p1['skipped'])}")
print(f"part2 stranded:     enqueued={len(p2['enqueued'])} skipped={len(p2['skipped'])}")
from collections import Counter
print("part1 skip reasons:", dict(Counter(s['reason'] for s in p1['skipped'])))
print("part2 by phase:", dict(Counter(e['phase'] for e in p2['enqueued'])))
p3 = report["part3_deferred_promotion"]
print(f"part3 deferred: promoted={len(p3['promoted'])} kept={p3['kept_deferred']}")
print("priority_track items:", sum(1 for e in p1['enqueued'] if e['priority_track']))
print("evidence:", EVIDENCE)
