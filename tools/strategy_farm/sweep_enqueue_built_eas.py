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

Usage: python sweep_enqueue_built_eas.py [--apply] [--queue-ceiling N] [--ea QM5_12580] [--symbols EURUSD.DWX,GBPUSD.DWX]
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
_FACTORY_OFF_FLAG = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
if _FACTORY_OFF_FLAG.exists():
    print(json.dumps({"skipped": "FACTORY_OFF.flag set", "flag": str(_FACTORY_OFF_FLAG)}))
    raise SystemExit(0)
APPLY = "--apply" in sys.argv
QUEUE_CEILING = 7000
if "--queue-ceiling" in sys.argv:
    QUEUE_CEILING = int(sys.argv[sys.argv.index("--queue-ceiling") + 1])
# Part-2 retry cap: stop re-enqueuing a (ea,phase,symbol,setfile) once it has
# accumulated this many INFRA_FAIL rows. Bounds hourly churn for EAs with a
# permanent infra defect (non-DWX symbol, M1 gaps, German-locale terminal,
# skeleton id) while still giving transient meltdown casualties ample retries.
MAX_INFRA_ATTEMPTS = 12
if "--max-infra-attempts" in sys.argv:
    MAX_INFRA_ATTEMPTS = int(sys.argv[sys.argv.index("--max-infra-attempts") + 1])
# Part-2 per-run rate limit: drip-feed the stranded-INFRA backlog instead of
# dumping the whole pool (~4400) at once. 2026-06-19: an unbounded Part-2 re-dump
# every hour flooded Q02 (13k INFRA / 0 PASS in 6h, graveyard FAIL). Re-enqueued
# items become pending/active and are excluded next run, so successive runs walk
# the backlog without re-flooding. Tune via --max-part2-per-run.
MAX_PART2_PER_RUN = 250
if "--max-part2-per-run" in sys.argv:
    MAX_PART2_PER_RUN = int(sys.argv[sys.argv.index("--max-part2-per-run") + 1])
TARGET_EAS = set()
if "--ea" in sys.argv:
    for raw in sys.argv[sys.argv.index("--ea") + 1].split(","):
        ea_id = raw.strip()
        if ea_id:
            TARGET_EAS.add(ea_id)
TARGET_SYMBOLS = set()
if "--symbols" in sys.argv:
    for raw in sys.argv[sys.argv.index("--symbols") + 1].split(","):
        symbol = raw.strip()
        if symbol:
            TARGET_SYMBOLS.add(symbol)
NOW = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00")

sys.path.insert(0, r"C:\QM\repo\tools\strategy_farm")
import farmctl  # staging helpers (_stage_q02_setfiles, _record_q02_deferral)
REQUEUE_EXCLUDED_EAS = farmctl.load_requeue_excluded_eas()

# 2026-07-19 (Q08 INFRA_FAIL storm RCA): a deterministic setgen defect in the
# baseline setfile (zero strategy params, empty value, or a duplicate strategy
# assignment) makes the Q08.5 neighborhood runner raise a hard ValueError on
# EVERY run — re-enqueuing that (ea,symbol,setfile) can never succeed until the
# setfile is regenerated, yet the blunt MAX_INFRA_ATTEMPTS counter still burns
# up to 12 full Q08 baseline backtests per pair. Pre-validate with the runner's
# OWN parser (single source of truth) and refuse the doomed re-enqueue.
# framework/scripts has no __init__.py -> module import via sys.path, appended
# (not inserted) so it can never shadow tools/strategy_farm modules.
try:
    sys.path.append(r"C:\QM\repo\framework\scripts")
    from q08_5_neighborhood_runner import (
        parse_setfile_assignments as _q08_parse_setfile,
    )
except Exception:  # import must NEVER break the sweep
    _q08_parse_setfile = None


def _q08_setfile_deterministic_defect(setfile_path):
    """Return a defect token if this setfile will deterministically fail Q08.5.

    parse_setfile_assignments raises on duplicate / empty-value strategy params
    and returns {} when the strategy block has no non-framework params (the
    `card_defaults_source=not_found` case). None => not a known deterministic
    setgen defect; allow the retry (transient infra, or a repaired setfile)."""
    if _q08_parse_setfile is None or not setfile_path:
        return None
    try:
        assignments = _q08_parse_setfile(Path(setfile_path))
    except ValueError as exc:
        msg = str(exc).lower()
        if "duplicate strategy parameter" in msg:
            return "duplicate_strategy_params"
        if "empty strategy parameter" in msg:
            return "empty_strategy_value"
        return "setfile_parse_error"
    except OSError:
        return None
    return "empty_strategy_params" if not assignments else None


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
        raw_ea_id = (row.get("ea_id") or "").strip()
        try:
            reg[int(raw_ea_id)] = (row["status"].strip().lower(), row["slug"].strip())
        except (KeyError, ValueError):
            m = re.fullmatch(r"QM5_(\d+)", raw_ea_id)
            if m:
                reg[int(m.group(1))] = (row["status"].strip().lower(), row["slug"].strip())
                continue
            continue

con = sqlite3.connect(DB)
con.row_factory = sqlite3.Row
cur = con.cursor()

wi_eas = {r[0] for r in cur.execute("SELECT DISTINCT ea_id FROM work_items")}

pending_now = cur.execute(
    "SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
budget = max(0, QUEUE_CEILING - pending_now)

report = {"generated_at": NOW, "apply": APPLY,
          "target_eas": sorted(TARGET_EAS),
          "target_symbols": sorted(TARGET_SYMBOLS),
          "requeue_excluded_eas_count": len(REQUEUE_EXCLUDED_EAS),
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
    if phase in {"Q02", "P2"} and farmctl.is_q02_requeue_excluded(ea_id, REQUEUE_EXCLUDED_EAS):
        report.setdefault("requeue_excluded_refused", []).append({
            "ea_id": ea_id,
            "phase": phase,
            "symbol": symbol,
            "setfile": Path(setfile).name,
        })
        return False
    # OWNER directive 2026-06-20: only ever enqueue .DWX custom symbols. Bare
    # broker symbols have no local history -> the tester fails history sync with
    # "file opening or reading error [32]" and the item INFRA_FAILs without ever
    # producing a result. Refuse non-.DWX outright.
    if not str(symbol).upper().endswith(".DWX"):
        report.setdefault("non_dwx_refused", []).append({"ea_id": ea_id, "symbol": symbol})
        return False
    if APPLY:
        cur.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
            "status, attempt_count, payload_json, created_at, updated_at) "
            "VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', 0, ?, ?, ?)",
            (str(uuid.uuid4()), phase, ea_id, symbol, str(setfile),
             json.dumps(payload), NOW, NOW))
    return True

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
    if TARGET_EAS and ea_id not in TARGET_EAS:
        continue
    if farmctl.is_q02_requeue_excluded(ea_id, REQUEUE_EXCLUDED_EAS):
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "reason": "requeue_excluded_q02"})
        continue
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
        symbol = m.group(1)
        reason = farmctl._q02_symbol_skip_reason(symbol, allow_logical_basket=True)
        if reason:
            report["part1_never_tested"]["skipped"].append(
                {"ea_id": ea_id, "symbol": symbol, "reason": reason, "setfile": sf.name})
            continue
        parsed.append((sf, symbol, m.group(2)))
    stage1, deferred = farmctl._stage_q02_setfiles(parsed)
    if deferred and APPLY:
        farmctl._record_q02_deferral(ea_id, deferred, "sweep_enqueue")
    for _sf, _sym, _tf in deferred:
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "symbol": _sym, "reason": "staged_deferred_symbol"})
    for sf, symbol, tf in stage1:
        if TARGET_SYMBOLS and symbol not in TARGET_SYMBOLS:
            report["part1_never_tested"]["skipped"].append(
                {"ea_id": ea_id, "symbol": symbol, "reason": "target_symbol_filter"})
            continue
        if pending_active_exists(ea_id, symbol, "Q02"):
            report["part1_never_tested"]["skipped"].append(
                {"ea_id": ea_id, "symbol": symbol, "reason": "existing_pending_active"})
            continue
        payload = {"host_symbol": symbol, "host_timeframe": tf,
                   "enqueued_by": "claude_sweep_enqueue_2026-06-10.never_tested",
                   "enqueued_at_utc": NOW}
        if ea_id in PRIORITY_EAS:
            payload["priority_track"] = True
        if not insert_wi("Q02", ea_id, symbol, sf, payload):
            continue
        budget_left -= 1
        report["part1_never_tested"]["enqueued"].append(
            {"ea_id": ea_id, "symbol": symbol, "setfile": sf.name,
             "priority_track": ea_id in PRIORITY_EAS})

# ---------- Part 2: stranded INFRA_FAIL at Q02/Q03/Q08 ----------
part2_count = 0
report["part2_stranded"]["rate_limited"] = False
for phase in ("Q02", "Q03", "Q08"):
    if part2_count >= MAX_PART2_PER_RUN:
        break
    params = [phase]
    target_filter = ""
    if TARGET_EAS:
        target_filter = "AND x.ea_id IN (%s)" % ",".join("?" for _ in TARGET_EAS)
        params.extend(sorted(TARGET_EAS))
    # Retry stranded infra at the symbol/setfile level. An EA can have some
    # valid phase results while other symbols remain blocked by transient MT5
    # failures, and those rows still need a chance to re-enter the funnel.
    stranded_rows = cur.execute(f"""
        SELECT x.ea_id, x.symbol, x.setfile_path, MAX(x.updated_at), COUNT(*)
        FROM work_items x
        WHERE x.phase=?
          AND x.verdict='INFRA_FAIL'
          {target_filter}
          AND NOT EXISTS (
              SELECT 1 FROM work_items y
              WHERE y.ea_id=x.ea_id
                AND y.phase=x.phase
                AND y.symbol=x.symbol
                AND ifnull(y.setfile_path, '')=ifnull(x.setfile_path, '')
                AND y.status IN ('pending','active')
          )
          AND NOT EXISTS (
              SELECT 1 FROM work_items y
              WHERE y.ea_id=x.ea_id
                AND y.phase=x.phase
                AND y.symbol=x.symbol
                AND ifnull(y.setfile_path, '')=ifnull(x.setfile_path, '')
                AND y.status='done'
                AND y.verdict!='INFRA_FAIL'
          )
        GROUP BY x.ea_id, x.symbol, x.setfile_path
        ORDER BY MAX(x.updated_at) ASC
        """, params).fetchall()
    for ea_id, symbol, setfile, _ts, infra_attempts in stranded_rows:
        if part2_count >= MAX_PART2_PER_RUN:
            break
        reason = farmctl._q02_symbol_skip_reason(symbol, allow_logical_basket=True)
        if reason:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": reason, "setfile": Path(setfile).name if setfile else None})
            continue
        if TARGET_SYMBOLS and symbol not in TARGET_SYMBOLS:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "target_symbol_filter"})
            continue
        num = int(ea_id.split("_")[1]) if ea_id.startswith("QM5_") else None
        status, _slug = reg.get(num, (None, None))
        if status != "active":
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "reason": f"registry_status={status}"})
            continue
        if infra_attempts >= MAX_INFRA_ATTEMPTS:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "infra_retry_cap_reached", "attempts": infra_attempts})
            continue
        if not setfile or not Path(setfile).is_file():
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "setfile_missing"})
            continue
        # Q08.5 neighborhood is the only Q08 sub-gate that hard-fails on setfile
        # structure; scope the deterministic-defect skip to Q08 so Q02/Q03 keep
        # their own retry semantics.
        if phase == "Q08":
            defect = _q08_setfile_deterministic_defect(setfile)
            if defect:
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "deterministic_setgen_defect", "defect": defect,
                     "setfile": Path(setfile).name})
                continue
        if pending_active_exists(ea_id, symbol, phase):
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "existing_pending_active"})
            continue
        if phase == "Q02" and farmctl.is_q02_requeue_excluded(ea_id, REQUEUE_EXCLUDED_EAS):
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "requeue_excluded_q02"})
            continue
        payload = {"host_symbol": symbol,
                   "enqueued_by": "claude_sweep_enqueue_2026-06-10.stranded_infra_fail",
                   "enqueued_at_utc": NOW}
        if not insert_wi(phase, ea_id, symbol, setfile, payload):
            continue
        report["part2_stranded"]["enqueued"].append(
            {"ea_id": ea_id, "phase": phase, "symbol": symbol,
             "setfile": Path(setfile).name})
        part2_count += 1
        if part2_count >= MAX_PART2_PER_RUN:
            report["part2_stranded"]["rate_limited"] = True
            break

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
        if TARGET_EAS and ea_id not in TARGET_EAS:
            continue
        entry = deferred_state[ea_id]
        has_pass = cur.execute(
            "SELECT 1 FROM work_items WHERE ea_id=? AND phase='Q02' "
            "AND status='done' AND verdict='PASS' LIMIT 1", (ea_id,)).fetchone()
        if not (has_pass or spare_capacity):
            report["part3_deferred_promotion"]["kept_deferred"] += len(entry["setfiles"])
            continue
        if farmctl.is_q02_requeue_excluded(ea_id, REQUEUE_EXCLUDED_EAS):
            report["part3_deferred_promotion"].setdefault("skipped", []).append(
                {"ea_id": ea_id, "reason": "requeue_excluded_q02",
                 "deferred_setfiles": len(entry["setfiles"])})
            continue
        for sf in entry["setfiles"]:
            reason = farmctl._q02_symbol_skip_reason(sf["symbol"], allow_logical_basket=True)
            if reason:
                report["part3_deferred_promotion"].setdefault("skipped", []).append(
                    {"ea_id": ea_id, "symbol": sf["symbol"],
                     "reason": reason, "setfile": Path(sf["setfile"]).name})
                continue
            if TARGET_SYMBOLS and sf["symbol"] not in TARGET_SYMBOLS:
                report["part3_deferred_promotion"].setdefault("skipped", []).append(
                    {"ea_id": ea_id, "symbol": sf["symbol"],
                     "reason": "target_symbol_filter"})
                continue
            if not Path(sf["setfile"]).is_file():
                continue
            if pending_active_exists(ea_id, sf["symbol"], "Q02"):
                continue
            payload = {"host_symbol": sf["symbol"], "host_timeframe": sf.get("tf"),
                       "enqueued_by": "sweep_enqueue.deferred_promotion",
                       "promotion_reason": "stage1_pass" if has_pass else "spare_capacity",
                       "enqueued_at_utc": NOW}
            if entry.get("priority_track") is True:
                payload["priority_track"] = True
            if entry.get("build_task_id"):
                payload["build_task_id"] = entry["build_task_id"]
            if entry.get("q02_cohort_size"):
                payload["q02_cohort_size"] = entry["q02_cohort_size"]
            if not insert_wi("Q02", ea_id, sf["symbol"], sf["setfile"], payload):
                continue
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
