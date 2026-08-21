"""One-shot sweep (Claude, 2026-06-10, OWNER-approved acceleration):

1. Enqueue Q02 work_items for built EAs (.ex5 on disk) that have ZERO
   work_items in the DB (never entered the pipeline). One liquid-symbol
   canary is staged first; the remainder stays in the deferred sidecar.
2. Re-enqueue (ea, symbol, setfile) rows stranded on INFRA_FAIL at
   Q02/Q03/Q04/Q07/Q08 with nothing pending/active, no terminal non-INFRA
   disposition, and no work for the same EA/symbol at a deeper phase.
3. Promote deferred symbols (state/q02_deferred_symbols.json) only after the
   MNT-038 canary state machine permits fanout. Deterministic infra/invalid
   failures stop; a first zero-trade host gets one sequential confirmation;
   an economic or heterogeneous result releases the remaining cohort.

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
import atexit
import json
import os
import re
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
REPO_ROOT = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo"))
REPORT_ROOT = Path(os.environ.get("QM_REPORT_ROOT", r"D:\QM\reports"))
DB = FARM_ROOT / "state" / "farm_state.sqlite"
EAS = REPO_ROOT / "framework" / "EAs"
REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
EVIDENCE = REPORT_ROOT / "state" / "claude_sweep_enqueue_2026-06-10.json"
SETFILE_RE = re.compile(r"_([A-Z][A-Z0-9.]{2,})_([A-Z0-9]+)_backtest\.set$")
PRIORITY_EAS = {"QM5_1049", "QM5_1047", "QM5_1085", "QM5_1158"}
_FACTORY_OFF_FLAG = FARM_ROOT / "state" / "FACTORY_OFF.flag"
_FACTORY_MUTATION_LOCK = FARM_ROOT / "state" / "FACTORY_MUTATION.lock"
if _FACTORY_OFF_FLAG.exists():
    print(json.dumps({"skipped": "FACTORY_OFF.flag set", "flag": str(_FACTORY_OFF_FLAG)}))
    raise SystemExit(0)
APPLY = "--apply" in sys.argv


def _release_mutation_lock() -> None:
    global _MUTATION_LOCK
    if _MUTATION_LOCK is None:
        return
    _MUTATION_LOCK.__exit__(None, None, None)
    _MUTATION_LOCK = None


def _acquire_mutation_lock() -> FactoryMutationLock | None:
    lock = FactoryMutationLock(
        _FACTORY_MUTATION_LOCK,
        owner="sweep_enqueue_built_eas",
    )
    try:
        lock.__enter__()
    except RuntimeError:
        return None
    return lock


_MUTATION_LOCK: FactoryMutationLock | None = None
if APPLY:
    _MUTATION_LOCK = _acquire_mutation_lock()
    if _MUTATION_LOCK is None:
        print(json.dumps({
            "skipped": "factory mutation lock busy",
            "lock": str(_FACTORY_MUTATION_LOCK),
        }))
        raise SystemExit(0)
    atexit.register(_release_mutation_lock)
    if _FACTORY_OFF_FLAG.exists():
        print(json.dumps({"skipped": "FACTORY_OFF.flag set after lock", "flag": str(_FACTORY_OFF_FLAG)}))
        raise SystemExit(0)
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
# Q04 and Q07 can be reclassified to INFRA_FAIL after their phase-specific
# operators finish.  Keep those rows on the same bounded hourly recovery path
# as Q02/Q03/Q08; Q05/Q06 remain with the separately governed deep-phase tool.
STRANDED_INFRA_PHASES = ("Q02", "Q03", "Q04", "Q07", "Q08")
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

sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))
import farmctl  # staging helpers (_stage_q02_setfiles, _record_q02_deferral)
from q08_recovery_lineage import build_q08_recovery_lineage
from review_entry_gate import build_index as build_review_entry_index, blocked as review_blocked
REQUEUE_EXCLUDED_EAS = farmctl.load_requeue_excluded_eas()

# 2026-07-19 (Q08 INFRA_FAIL storm RCA): a deterministic setgen defect in the
# baseline setfile (zero strategy params, empty value, or a noncanonical
# duplicate shape) makes the Q08.5 neighborhood runner raise a hard ValueError
# on EVERY run. Canonical markerless ablation base+override blocks are accepted
# with MT5 last-value-wins semantics. Pre-validate with the runner's OWN parser
# (single source of truth) and refuse only the doomed re-enqueue.
# framework/scripts has no __init__.py -> module import via sys.path, appended
# (not inserted) so it can never shadow tools/strategy_farm modules.
try:
    sys.path.append(str(REPO_ROOT / "framework" / "scripts"))
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
    _SCORES = _sp.compute_scores(
        cards_dir=FARM_ROOT / "artifacts" / "cards_approved",
        db=DB,
    )
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
          "part2_stranded": {"enqueued": [], "skipped": [], "parked": []}}
deferred_records = []

def pending_active_exists(ea_id, symbol, phase):
    return cur.execute(
        "SELECT 1 FROM work_items WHERE ea_id=? AND symbol=? AND phase=? "
        "AND status IN ('pending','active') LIMIT 1", (ea_id, symbol, phase)
    ).fetchone() is not None


def deeper_phase_work_item(ea_id, symbol, phase):
    """Return evidence that this pair already advanced beyond ``phase``.

    An older INFRA_FAIL remains historical once any deeper-phase work exists.
    Re-enqueueing the earlier phase would spend tester capacity on a lineage
    that the farm has already advanced, even when that deeper row later failed.
    """
    phase_rank = {name: index for index, name in enumerate(farmctl.PHASE_ORDER)}
    current_rank = phase_rank.get(phase)
    if current_rank is None:
        return None
    deeper_phases = farmctl.PHASE_ORDER[current_rank + 1:]
    if not deeper_phases:
        return None
    placeholders = ",".join("?" for _ in deeper_phases)
    return cur.execute(
        f"SELECT id,phase,status,verdict,updated_at FROM work_items "
        f"WHERE ea_id=? AND symbol=? AND phase IN ({placeholders}) "
        "ORDER BY updated_at DESC,id DESC LIMIT 1",
        (ea_id, symbol, *deeper_phases),
    ).fetchone()

def insert_wi(
    phase,
    ea_id,
    symbol,
    setfile,
    payload,
    *,
    allow_logical_basket=False,
):
    if phase in {"Q02", "P2"} and farmctl.is_q02_requeue_excluded(ea_id, REQUEUE_EXCLUDED_EAS):
        report.setdefault("requeue_excluded_refused", []).append({
            "ea_id": ea_id,
            "phase": phase,
            "symbol": symbol,
            "setfile": Path(setfile).name,
        })
        return None
    # OWNER directive 2026-06-20: only ever enqueue .DWX custom symbols. Bare
    # broker symbols have no local history -> the tester fails history sync with
    # "file opening or reading error [32]" and the item INFRA_FAILs without ever
    # producing a result. Refuse non-.DWX outright.
    if (
        not str(symbol).upper().endswith(".DWX")
        and not allow_logical_basket
    ):
        report.setdefault("non_dwx_refused", []).append({"ea_id": ea_id, "symbol": symbol})
        return None
    archive_admission = farmctl.custom_history_archive_admission(
        FARM_ROOT,
        ea_id=str(ea_id),
        symbols=[symbol],
        payload=payload,
    )
    if not archive_admission.get("ok"):
        report.setdefault("archive_coverage_refused", []).append({
            "ea_id": ea_id,
            "phase": phase,
            "symbol": symbol,
            "setfile": Path(setfile).name,
            "reason": archive_admission.get("reason"),
            "detail": archive_admission.get("detail"),
            "missing_symbols": archive_admission.get("missing_symbols") or [],
        })
        return None
    farmctl._stamp_custom_history_archive_admission(payload, archive_admission)
    farmctl._apply_q02_multisymbol_timeout_min(
        payload,
        phase=phase,
        ea_id=str(ea_id),
        symbol=str(symbol),
    )
    work_item_id = str(uuid.uuid4())
    if APPLY:
        cur.execute(
            "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, "
            "status, attempt_count, payload_json, created_at, updated_at) "
            "VALUES (?, 'backtest', ?, ?, ?, ?, 'pending', 0, ?, ?, ?)",
            (work_item_id, phase, ea_id, symbol, str(setfile),
             json.dumps(payload), NOW, NOW))
    return work_item_id

# E3 (v6): a review must precede pipeline entry. Built once here rather than per EA -- Part 1
# iterates ~3,700 directories. EAs with no task history are absent from the index and therefore
# not gated; see review_entry_gate for why that exemption is load-bearing.
review_entry_index = build_review_entry_index(con)
report["review_entry_gate"] = {
    "schema": "qm.review-entry-gate/v1",
    "blocked_eas": len(review_entry_index),
    "blocked": [],
}

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
    # E3 gate sits AFTER the binary/setfile checks so its reported count means exactly
    # "would otherwise have been enqueued", not "was going to fail some other check anyway".
    entry_block = review_blocked(review_entry_index, ea_id)
    if entry_block:
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "reason": "review_entry_gate", "detail": entry_block})
        report["review_entry_gate"]["blocked"].append(
            {"ea_id": ea_id, "part": "part1_never_tested", "detail": entry_block})
        continue
    manifest_path = pick / "basket_manifest.json"
    basket_manifest = None
    if manifest_path.exists():
        try:
            basket_manifest = json.loads(
                manifest_path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            basket_manifest = None
        required_manifest_fields = (
            "logical_symbol",
            "host_symbol",
            "host_timeframe",
        )
        if (
            not isinstance(basket_manifest, dict)
            or any(
                not str(basket_manifest.get(field) or "").strip()
                for field in required_manifest_fields
            )
        ):
            report["part1_never_tested"]["skipped"].append(
                {
                    "ea_id": ea_id,
                    "reason": "basket_manifest_invalid",
                    "manifest": str(manifest_path),
                })
            continue
        basket_manifest["manifest_path"] = str(manifest_path.resolve())
    parsed = []
    if basket_manifest:
        logical_symbol = str(basket_manifest["logical_symbol"])
        host_timeframe = str(basket_manifest["host_timeframe"])
        expected_logical_path = (
            pick
            / "sets"
            / f"{pick.name}_{logical_symbol}_{host_timeframe}_backtest.set"
        )
        logical_matches = (
            [expected_logical_path]
            if expected_logical_path.exists()
            else sorted(
                (pick / "sets").glob(
                    f"*_{logical_symbol}_{host_timeframe}_backtest.set"
                )
            )
        )
        if not logical_matches:
            report["part1_never_tested"]["skipped"].append(
                {
                    "ea_id": ea_id,
                    "reason": "basket_manifest_missing_logical_setfile",
                    "dir": pick.name,
                })
            continue
        logical_path = logical_matches[0].resolve()
        payload_extra = farmctl._basket_q02_payload(basket_manifest)
        parsed.append((
            logical_path,
            logical_symbol,
            host_timeframe,
            payload_extra,
        ))
        for sf in sets:
            if sf.resolve() != logical_path.resolve():
                report["part1_never_tested"]["skipped"].append(
                    {
                        "ea_id": ea_id,
                        "reason": "basket_manifest_logical_setfile_preferred",
                        "setfile": sf.name,
                    })
    else:
        for sf in sets:
            m = SETFILE_RE.search(sf.name)
            if not m:
                report["part1_never_tested"]["skipped"].append(
                    {"ea_id": ea_id, "reason": "setfile_parse_failed", "setfile": sf.name})
                continue
            symbol = m.group(1)
            reason = farmctl._q02_symbol_skip_reason(symbol)
            if reason:
                report["part1_never_tested"]["skipped"].append(
                    {"ea_id": ea_id, "symbol": symbol, "reason": reason, "setfile": sf.name})
                continue
            parsed.append((sf, symbol, m.group(2), {}))
    eligible_parsed = []
    for sf, symbol, tf, payload_extra in parsed:
        reason = farmctl._q02_symbol_skip_reason(
            symbol,
            allow_logical_basket=bool(basket_manifest),
        )
        if reason:
            report["part1_never_tested"]["skipped"].append(
                {"ea_id": ea_id, "symbol": symbol, "reason": reason, "setfile": sf.name})
            continue
        eligible_parsed.append((sf, symbol, tf, payload_extra))
    parsed = eligible_parsed
    stage1, deferred = farmctl._stage_q02_setfiles(parsed)
    # Resolve once before any stage-1 row is inserted. Otherwise the first
    # insert would make later symbols in the same fresh-EA cohort look like
    # non-first Q02s and only part of the cohort would receive the marker.
    priority_track = (
        ea_id in PRIORITY_EAS
        or farmctl._q02_priority_track_required(con, REPO_ROOT, ea_id)
    )
    if deferred and APPLY:
        # Defer the sidecar write until the same final interlock check as the DB
        # commit.  Otherwise OFF racing this sweep could roll back SQLite while
        # leaving a promoted/deferred file mutation behind.
        deferred_records.append((
            ea_id,
            deferred,
            "sweep_enqueue",
            priority_track,
            len(parsed),
            [item[1] for item in stage1],
        ))
    for deferred_item in deferred:
        _sf, _sym, _tf = deferred_item[:3]
        report["part1_never_tested"]["skipped"].append(
            {"ea_id": ea_id, "symbol": _sym, "reason": "staged_deferred_symbol"})
    for stage1_item in stage1:
        sf, symbol, tf, payload_extra = stage1_item
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
                   "enqueued_at_utc": NOW,
                   "q02_fanout_policy": farmctl.Q02_CANARY_FANOUT_POLICY,
                   "q02_fanout_canary": bool(deferred),
                   "q02_fanout_canary_index": 1 if deferred else None}
        payload.update(payload_extra)
        # Keep this legacy sweep aligned with every other Q02 creator. Basket
        # rows are especially easy to strand because their logical symbol does
        # not receive an asset-class tie-break from the physical host.
        if priority_track:
            payload["priority_track"] = True
        if not insert_wi(
            "Q02",
            ea_id,
            symbol,
            sf,
            payload,
            allow_logical_basket=bool(payload_extra.get("basket_manifest")),
        ):
            continue
        budget_left -= 1
        report["part1_never_tested"]["enqueued"].append(
            {"ea_id": ea_id, "symbol": symbol, "setfile": sf.name,
             "priority_track": priority_track})

# ---------- Part 2: stranded INFRA_FAIL at Q02/Q03/Q04/Q07/Q08 ----------
part2_count = 0
report["part2_stranded"]["rate_limited"] = False
for phase in STRANDED_INFRA_PHASES:
    if part2_count >= MAX_PART2_PER_RUN:
        break
    params = [phase]
    target_filter = ""
    if TARGET_EAS:
        target_filter = "AND x.ea_id IN (%s)" % ",".join("?" for _ in TARGET_EAS)
        params.extend(sorted(TARGET_EAS))
    phase_rank = {name: index for index, name in enumerate(farmctl.PHASE_ORDER)}
    deeper_phases = farmctl.PHASE_ORDER[phase_rank[phase] + 1:]
    deeper_filter = ""
    if deeper_phases:
        deeper_filter = (
            "AND NOT EXISTS ("
            "SELECT 1 FROM work_items z "
            "WHERE z.ea_id=x.ea_id AND z.symbol=x.symbol "
            "AND z.phase IN (%s))"
        ) % ",".join("?" for _ in deeper_phases)
        params.extend(deeper_phases)
    # Retry stranded infra at the symbol/setfile level. An EA can have some
    # valid phase results while other symbols remain blocked by transient MT5
    # failures, and those rows still need a chance to re-enter the funnel.
    stranded_rows = cur.execute(f"""
        SELECT x.ea_id, x.symbol, x.setfile_path, MAX(x.updated_at), COUNT(*)
        FROM work_items x
        WHERE x.phase=?
          AND x.status IN ('done','failed')
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
                AND y.status IN ('done','failed')
                AND y.verdict IS NOT NULL
                AND y.verdict!='INFRA_FAIL'
          )
          {deeper_filter}
        GROUP BY x.ea_id, x.symbol, x.setfile_path
        ORDER BY MAX(x.updated_at) ASC
        """, params).fetchall()
    for ea_id, symbol, setfile, _ts, infra_attempts in stranded_rows:
        if part2_count >= MAX_PART2_PER_RUN:
            break
        source = cur.execute(
            """
            SELECT id,status,payload_json,updated_at
            FROM work_items
            WHERE ea_id=? AND phase=? AND symbol=?
              AND ifnull(setfile_path, '')=ifnull(?, '')
              AND status IN ('done','failed') AND verdict='INFRA_FAIL'
            ORDER BY updated_at DESC,id DESC
            LIMIT 1
            """,
            (ea_id, phase, symbol, setfile),
        ).fetchone()
        if source is None:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "terminal_infra_source_missing"})
            continue
        try:
            source_payload = json.loads(source["payload_json"] or "{}")
        except (TypeError, json.JSONDecodeError):
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "terminal_infra_source_payload_invalid",
                 "source_work_item_id": source["id"]})
            continue

        terminal_disposition = cur.execute(
            """
            SELECT id,status,verdict,updated_at
            FROM work_items
            WHERE ea_id=? AND phase=? AND symbol=?
              AND ifnull(setfile_path, '')=ifnull(?, '')
              AND status IN ('done','failed')
              AND verdict IS NOT NULL AND verdict!='INFRA_FAIL'
            ORDER BY updated_at DESC,id DESC
            LIMIT 1
            """,
            (ea_id, phase, symbol, setfile),
        ).fetchone()
        if terminal_disposition is not None:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "terminal_noninfra_disposition",
                 "source_work_item_id": source["id"],
                 "disposition_work_item_id": terminal_disposition["id"],
                 "disposition_status": terminal_disposition["status"],
                 "disposition_verdict": terminal_disposition["verdict"]})
            continue

        advanced = deeper_phase_work_item(ea_id, symbol, phase)
        if advanced is not None:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "historical_phase_advanced",
                 "source_work_item_id": source["id"],
                 "advanced_work_item_id": advanced["id"],
                 "advanced_phase": advanced["phase"],
                 "advanced_status": advanced["status"],
                 "advanced_verdict": advanced["verdict"]})
            continue

        basket_payload = None
        is_logical_basket = (
            phase == "Q02"
            and source_payload.get("portfolio_scope") == "basket"
        )
        if is_logical_basket:
            budget_wall_streak = farmctl._q02_budget_wall_streak(
                con,
                ea_id,
                symbol,
                setfile,
            )
            if budget_wall_streak:
                breaker = {
                    "schema": "qm.q02-basket-budget-wall-breaker/v1",
                    "hold_code": farmctl.Q02_BASKET_BUDGET_WALL_HOLD_CODE,
                    "threshold": farmctl.Q02_BASKET_BUDGET_WALL_BREAKER_THRESHOLD,
                    "consecutive_failures": budget_wall_streak,
                    "parked_at_utc": NOW,
                }
                if APPLY:
                    source_payload["budget_wall_breaker"] = breaker
                    cur.execute(
                        """
                        UPDATE work_items
                        SET payload_json=?, updated_at=?
                        WHERE id=? AND status IN ('done','failed')
                          AND verdict='INFRA_FAIL'
                        """,
                        (json.dumps(source_payload, sort_keys=True), NOW, source["id"]),
                    )
                    cur.execute(
                        """
                        INSERT INTO work_item_holds
                          (work_item_id,hold_code,reason,active,release_on_restart,
                           created_at,updated_at,released_at,release_note)
                        VALUES (?,?,?,1,0,?,?,NULL,NULL)
                        ON CONFLICT(work_item_id) DO UPDATE SET
                          hold_code=excluded.hold_code,
                          reason=excluded.reason,
                          active=1,
                          release_on_restart=0,
                          updated_at=excluded.updated_at,
                          released_at=NULL,
                          release_note=NULL
                        """,
                        (
                            source["id"],
                            farmctl.Q02_BASKET_BUDGET_WALL_HOLD_CODE,
                            (
                                "logical-basket Q02 reached its granted budget wall "
                                f"{len(budget_wall_streak)} consecutive times; "
                                "manual performance/budget review required"
                            ),
                            NOW,
                            NOW,
                        ),
                    )
                report["part2_stranded"]["parked"].append({
                    "ea_id": ea_id,
                    "phase": phase,
                    "symbol": symbol,
                    "source_work_item_id": source["id"],
                    "hold_code": farmctl.Q02_BASKET_BUDGET_WALL_HOLD_CODE,
                    "threshold": farmctl.Q02_BASKET_BUDGET_WALL_BREAKER_THRESHOLD,
                    "consecutive_failures": budget_wall_streak,
                    "applied": APPLY,
                })
                continue
            manifest_path = Path(str(source_payload.get("basket_manifest") or ""))
            try:
                manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
            except (OSError, json.JSONDecodeError):
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "basket_manifest_missing_or_invalid",
                     "source_work_item_id": source["id"]})
                continue
            if not isinstance(manifest, dict):
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "basket_manifest_not_object",
                     "source_work_item_id": source["id"]})
                continue
            required = ("logical_symbol", "host_symbol", "host_timeframe")
            if (
                any(not str(manifest.get(key) or "").strip() for key in required)
                or str(manifest["logical_symbol"]) != symbol
            ):
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "basket_manifest_contract_mismatch",
                     "source_work_item_id": source["id"]})
                continue
            host_reason = farmctl._q02_symbol_skip_reason(str(manifest["host_symbol"]))
            if host_reason:
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": host_reason, "host_symbol": manifest["host_symbol"],
                     "source_work_item_id": source["id"]})
                continue
            manifest["manifest_path"] = str(manifest_path.resolve())
            basket_payload = farmctl._basket_q02_payload(manifest)

        reason = farmctl._q02_symbol_skip_reason(
            symbol,
            allow_logical_basket=is_logical_basket,
        )
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
        # E3 applies here too: re-running a row for an EA whose review says the build is
        # defective spends tester capacity on evidence that will have to be superseded.
        entry_block = review_blocked(review_entry_index, ea_id)
        if entry_block:
            report["part2_stranded"]["skipped"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "reason": "review_entry_gate", "detail": entry_block})
            report["review_entry_gate"]["blocked"].append(
                {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                 "part": "part2_stranded", "detail": entry_block})
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
                   "enqueued_at_utc": NOW,
                   "requeue_source": {
                       "work_item_id": source["id"],
                       "status": source["status"],
                       "verdict": "INFRA_FAIL",
                       "updated_at": source["updated_at"],
                   }}
        if basket_payload is not None:
            payload.update(basket_payload)
        if source_payload.get("priority_track") is True:
            payload["priority_track"] = True
        if phase == "Q08":
            recovery_lineage, lineage_error = build_q08_recovery_lineage(
                con,
                REPORT_ROOT,
                ea_id=ea_id,
                symbol=symbol,
                setfile_path=setfile,
            )
            if lineage_error:
                report["part2_stranded"]["skipped"].append(
                    {"ea_id": ea_id, "phase": phase, "symbol": symbol,
                     "reason": "q08_recovery_lineage_invalid",
                     "detail": lineage_error,
                     "setfile": Path(setfile).name})
                continue
            if recovery_lineage is not None:
                payload["q08_recovery_lineage"] = recovery_lineage
        new_work_item_id = insert_wi(
            phase,
            ea_id,
            symbol,
            setfile,
            payload,
            allow_logical_basket=is_logical_basket,
        )
        if not new_work_item_id:
            continue
        report["part2_stranded"]["enqueued"].append(
            {"ea_id": ea_id, "phase": phase, "symbol": symbol,
             "setfile": Path(setfile).name,
             "work_item_id": new_work_item_id,
             "source_work_item_id": source["id"],
             "source_status": source["status"],
             "logical_basket": is_logical_basket,
             "reason": "stranded_infra_fail"})
        part2_count += 1
        if part2_count >= MAX_PART2_PER_RUN:
            report["part2_stranded"]["rate_limited"] = True
            break

# ---------- Part 3: promote deferred symbols after the MNT-038 canary ----------
report["part3_deferred_promotion"] = {
    "policy": farmctl.Q02_CANARY_FANOUT_POLICY,
    "promoted": [],
    "stopped": [],
    "waiting": [],
    "kept_deferred": 0,
}
deferred_file = farmctl.Q02_DEFERRED_SYMBOLS_FILE
try:
    deferred_state = (json.loads(deferred_file.read_text(encoding="utf-8"))
                      if deferred_file.exists() else {})
except (json.JSONDecodeError, OSError):
    deferred_state = {}
deferred_state_present = bool(deferred_state)
if deferred_state:
    pending_q = cur.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
    for ea_id in sorted(deferred_state):
        if TARGET_EAS and ea_id not in TARGET_EAS:
            continue
        entry = deferred_state[ea_id]
        deferred_setfiles = list(entry.get("setfiles") or [])

        all_rows = cur.execute(
            "SELECT * FROM work_items WHERE ea_id=? AND phase IN ('Q02','P2') "
            "ORDER BY updated_at,id",
            (ea_id,),
        ).fetchall()
        build_task_id = str(entry.get("build_task_id") or "").strip()
        if build_task_id:
            build_rows = []
            for row in all_rows:
                try:
                    row_payload = json.loads(row["payload_json"] or "{}")
                except (TypeError, json.JSONDecodeError):
                    continue
                if str(row_payload.get("build_task_id") or "").strip() == build_task_id:
                    build_rows.append(row)
            all_rows = build_rows

        canary_symbols = [
            str(symbol) for symbol in entry.get("canary_symbols") or [] if str(symbol)
        ]
        if not canary_symbols:
            deferred_symbols = {
                str(item.get("symbol") or "") for item in deferred_setfiles
            }
            canary_symbols = list(dict.fromkeys(
                str(row["symbol"])
                for row in all_rows
                if str(row["symbol"] or "") not in deferred_symbols
            ))

        # DEFECT 2(b): STOPPED is not a terminal sink. Re-evaluate cheaply every
        # sweep — if a canary produced a fresh economic verdict after the stop
        # (self-healed cold cache, or a late PASS), the stop is contradicted and
        # the cohort re-opens for a fresh decision. No verdict is ever written.
        if entry.get("fanout_state") == "STOPPED":
            revival = farmctl._q02_canary_revival(
                all_rows, entry.get("fanout_stopped_at")
            )
            if revival is None:
                report["part3_deferred_promotion"]["stopped"].append({
                    "ea_id": ea_id,
                    "reason": (entry.get("fanout_stop") or {}).get("reason")
                    or "previous_canary_stop",
                    "deferred_setfiles": len(deferred_setfiles),
                })
                report["part3_deferred_promotion"]["kept_deferred"] += len(
                    deferred_setfiles
                )
                continue
            entry["fanout_state"] = "AWAITING_CANARY"
            entry["fanout_revived_at"] = NOW
            entry["release_reason"] = revival["release_reason"]
            entry.setdefault("fanout_revival_history", []).append(revival)
            report["part3_deferred_promotion"].setdefault("revived", []).append({
                "ea_id": ea_id,
                "reason": revival["release_reason"],
                "symbol": revival.get("symbol"),
                "verdict": revival.get("verdict"),
            })
            # fall through to the normal decision path below

        if farmctl.is_q02_requeue_excluded(ea_id, REQUEUE_EXCLUDED_EAS):
            # GAP 4: never rewrite a legacy sidecar entry in an unevaluated
            # format. Stamp the policy and an explicit terminal marker so nothing
            # rides the sidecar unannotated.
            entry["fanout_policy"] = farmctl.Q02_CANARY_FANOUT_POLICY
            entry["fanout_state"] = "LEGACY_EXCLUDED"
            report["part3_deferred_promotion"].setdefault("skipped", []).append(
                {"ea_id": ea_id, "reason": "requeue_excluded_q02",
                 "deferred_setfiles": len(deferred_setfiles)})
            report["part3_deferred_promotion"]["kept_deferred"] += len(
                deferred_setfiles
            )
            continue

        cohort_symbols = list(dict.fromkeys(
            canary_symbols
            + [str(item.get("symbol") or "") for item in deferred_setfiles]
        ))
        decision = farmctl._q02_canary_fanout_decision(
            all_rows, canary_symbols, cohort_symbols
        )
        entry["fanout_policy"] = farmctl.Q02_CANARY_FANOUT_POLICY
        entry["canary_symbols"] = canary_symbols
        entry["fanout_last_decision"] = decision

        if decision["action"] == "WAIT":
            entry["fanout_state"] = "AWAITING_CANARY"
            report["part3_deferred_promotion"]["waiting"].append({
                "ea_id": ea_id,
                "reason": decision["reason"],
                "canary_symbols": canary_symbols,
                "deferred_setfiles": len(deferred_setfiles),
            })
            report["part3_deferred_promotion"]["kept_deferred"] += len(
                deferred_setfiles
            )
            continue
        if decision["action"] == "STOP":
            entry["fanout_state"] = "STOPPED"
            entry["fanout_stopped_at"] = NOW
            entry["fanout_stop"] = decision
            report["part3_deferred_promotion"]["stopped"].append({
                "ea_id": ea_id,
                "reason": decision["reason"],
                "canary_symbols": canary_symbols,
                "deferred_setfiles": len(deferred_setfiles),
            })
            report["part3_deferred_promotion"]["kept_deferred"] += len(
                deferred_setfiles
            )
            continue
        if pending_q >= QUEUE_CEILING:
            entry["fanout_state"] = "AWAITING_CAPACITY"
            report["part3_deferred_promotion"]["waiting"].append({
                "ea_id": ea_id,
                "reason": "queue_ceiling_reached",
                "deferred_setfiles": len(deferred_setfiles),
            })
            report["part3_deferred_promotion"]["kept_deferred"] += len(
                deferred_setfiles
            )
            continue

        def promote(sf, promotion_reason, *, canary_index=None):
            reason = farmctl._q02_symbol_skip_reason(sf["symbol"], allow_logical_basket=True)
            if reason:
                report["part3_deferred_promotion"].setdefault("skipped", []).append(
                    {"ea_id": ea_id, "symbol": sf["symbol"],
                     "reason": reason, "setfile": Path(sf["setfile"]).name})
                return False
            if TARGET_SYMBOLS and sf["symbol"] not in TARGET_SYMBOLS:
                report["part3_deferred_promotion"].setdefault("skipped", []).append(
                    {"ea_id": ea_id, "symbol": sf["symbol"],
                     "reason": "target_symbol_filter"})
                return False
            if not Path(sf["setfile"]).is_file():
                report["part3_deferred_promotion"].setdefault("skipped", []).append(
                    {"ea_id": ea_id, "symbol": sf["symbol"],
                     "reason": "setfile_missing", "setfile": sf["setfile"]})
                return False
            if pending_active_exists(ea_id, sf["symbol"], "Q02"):
                report["part3_deferred_promotion"].setdefault("skipped", []).append(
                    {"ea_id": ea_id, "symbol": sf["symbol"],
                     "reason": "existing_pending_active"})
                return False
            payload = {"host_symbol": sf["symbol"], "host_timeframe": sf.get("tf"),
                       "enqueued_by": "sweep_enqueue.deferred_promotion",
                       "promotion_reason": promotion_reason,
                       "enqueued_at_utc": NOW,
                       "q02_fanout_policy": farmctl.Q02_CANARY_FANOUT_POLICY,
                       "q02_fanout_canary": canary_index is not None,
                       "q02_fanout_canary_index": canary_index}
            if entry.get("priority_track") is True:
                payload["priority_track"] = True
            if entry.get("build_task_id"):
                payload["build_task_id"] = entry["build_task_id"]
            if entry.get("q02_cohort_size"):
                payload["q02_cohort_size"] = entry["q02_cohort_size"]
            if not insert_wi("Q02", ea_id, sf["symbol"], sf["setfile"], payload):
                return False
            report["part3_deferred_promotion"]["promoted"].append(
                {"ea_id": ea_id, "symbol": sf["symbol"],
                 "reason": payload["promotion_reason"]})
            return True

        if decision["action"] == "CONFIRM":
            if not deferred_setfiles:
                entry["fanout_state"] = "STOPPED"
                entry["fanout_stopped_at"] = NOW
                entry["fanout_stop"] = {
                    **decision,
                    "reason": "null_signal_no_confirmation_host",
                }
                continue
            # Cross-asset confirmation (DEFECT 1): when the decision names the
            # unprobed asset classes to reach, promote the lowest-ranked deferred
            # host from those classes first so a metal/index strategy is probed
            # before any identical-null stop. Otherwise confirm the next liquid
            # host overall (first-null single confirmation).
            confirmation_pool = deferred_setfiles
            promote_classes = decision.get("promote_asset_classes")
            if promote_classes:
                targeted = [
                    item for item in deferred_setfiles
                    if farmctl._q02_asset_class(item["symbol"]) in set(promote_classes)
                ]
                if targeted:
                    confirmation_pool = targeted
            confirmation = min(
                confirmation_pool,
                key=lambda item: farmctl._q02_canary_symbol_rank(item["symbol"]),
            )
            confirmation_index = len(canary_symbols) + 1
            if promote(
                confirmation,
                "null_signal_confirmation",
                canary_index=confirmation_index,
            ):
                pending_q += 1
                if APPLY:
                    entry["setfiles"] = [
                        item for item in deferred_setfiles if item is not confirmation
                    ]
                    entry["canary_symbols"] = list(dict.fromkeys(
                        canary_symbols + [str(confirmation["symbol"])]
                    ))
                    entry["fanout_state"] = "AWAITING_CONFIRMATION"
                report["part3_deferred_promotion"]["kept_deferred"] += max(
                    0, len(deferred_setfiles) - 1
                )
            else:
                report["part3_deferred_promotion"]["kept_deferred"] += len(
                    deferred_setfiles
                )
            continue

        remaining = []
        for sf in deferred_setfiles:
            if promote(sf, decision["reason"]):
                pending_q += 1
            else:
                remaining.append(sf)
        report["part3_deferred_promotion"]["kept_deferred"] += len(remaining)
        if APPLY:
            if remaining:
                entry["setfiles"] = remaining
                entry["fanout_state"] = "RELEASE_PARTIAL"
            else:
                deferred_state.pop(ea_id, None)
if APPLY:
    # Factory_OFF writes the flag before stopping this task and waits for the
    # global mutation lock.  If the flag arrived during the read/plan phase,
    # roll back every pending SQLite insert and leave sidecars untouched.
    if _FACTORY_OFF_FLAG.exists():
        con.rollback()
        print(json.dumps({
            "skipped": "FACTORY_OFF.flag set before commit",
            "flag": str(_FACTORY_OFF_FLAG),
        }))
        raise SystemExit(0)
    con.commit()
    # Persist promotions/removals from the snapshot before appending new
    # stage-1 deferrals.  Reversing this order overwrites every newly recorded
    # cohort whenever the sidecar was non-empty at sweep start.
    if deferred_state_present:
        deferred_file.write_text(json.dumps(deferred_state, indent=1),
                                 encoding="utf-8")
    for (
        ea_id,
        deferred,
        source,
        priority_track,
        cohort_size,
        canary_symbols,
    ) in deferred_records:
        farmctl._record_q02_deferral(
            ea_id,
            deferred,
            source,
            priority_track=priority_track,
            cohort_size=cohort_size,
            canary_symbols=canary_symbols,
        )
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
