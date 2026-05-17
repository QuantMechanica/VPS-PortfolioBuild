"""Pipeline health checks — catch silent failures early.

OWNER 2026-05-17: "wie können wir das in Zukunft früher erkennen". Each
check is a single SQL or filesystem query that returns OK / WARN / FAIL plus
a human-readable detail string and an action_hint. The whole thing runs
every 15 min via QM_StrategyFarm_Health_15min, writes to
D:/QM/strategy_farm/state/health.json (read by render_cockpit.py for a
top-of-page red banner), and appends FAILs to health_alarms.log.

The 10 invariants below cover every silent failure we hit overnight
2026-05-16/17:
  1. codex_review FAIL clustering (we hit 12/12 FAIL silently)
  2. cards_ready stagnation (4 sources idle for hours)
  3. Pump scheduled task non-zero exit (LastResult=112)
  4. P2-PASS without matching P3 work_item (8 ablations stranded)
  5. Ablation grandchildren (2nd-gen `_ablation_NN_ablation_MM`)
  6. Claude-review starvation (builds pending, no review spawn)
  7. MT5 dispatch idle while work_items pending
  8. Codex zero-activity while builds pending
  9. Source pool drained (need to add more sources)
 10. Tampermonkey quota snapshot stale (Chrome tabs closed)
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
from pathlib import Path

ROOT = Path(r"D:\QM\strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
HEALTH_FILE = ROOT / "state" / "health.json"
ALARMS_LOG = ROOT / "state" / "health_alarms.log"
QUOTA_SNAPSHOT = ROOT / "state" / "quota_snapshot.json"
LOG_DIR = ROOT / "logs"


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _connect() -> sqlite3.Connection:
    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row
    return con


def _check(name: str, status: str, value, threshold, detail: str, hint: str) -> dict:
    return {
        "name": name,
        "status": status,            # OK | WARN | FAIL
        "value": value,
        "threshold": threshold,
        "detail": detail,
        "action_hint": hint,
    }


def chk_codex_review_fail_rate(con) -> dict:
    """If > 80% of codex_review verdicts in last 1h are FAIL, the §E prompt
    or the build pipeline is broken — none of these reach Claude review."""
    cutoff = (_utc_now() - dt.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT payload_json FROM tasks WHERE kind='codex_review' AND status='done' "
        "AND updated_at >= ?", (cutoff,)
    ).fetchall()
    n = len(rows)
    n_fail = sum(1 for r in rows if '"verdict": "FAIL"' in r["payload_json"])
    rate = n_fail / n if n > 0 else 0
    if n >= 3 and rate >= 0.8:
        return _check("codex_review_fail_rate_1h", "FAIL", round(rate, 2), 0.8,
                      f"{n_fail}/{n} codex_reviews FAIL in last hour",
                      "Inspect verdict JSONs in artifacts/verdicts/codex_review_*.json; "
                      "likely a prompt-schema mismatch or systematic build defect")
    if n >= 3 and rate >= 0.5:
        return _check("codex_review_fail_rate_1h", "WARN", round(rate, 2), 0.5,
                      f"{n_fail}/{n} codex_reviews FAIL in last hour",
                      "Look at common findings — early sign of regression")
    return _check("codex_review_fail_rate_1h", "OK", round(rate, 2), 0.8,
                  f"{n_fail}/{n} FAIL", "")


def chk_cards_ready_stagnation(con) -> dict:
    """Sources stuck in cards_ready > 4h without an active worker mining
    them = mining-resume is broken."""
    cutoff = (_utc_now() - dt.timedelta(hours=4)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT id, title, updated_at FROM sources "
        "WHERE status='cards_ready' AND updated_at < ?", (cutoff,)
    ).fetchall()
    n = len(rows)
    if n >= 3:
        return _check("cards_ready_stagnation", "FAIL", n, 3,
                      f"{n} sources in cards_ready > 4h with no resume",
                      "Pump §_claim_research_source should pick these up; "
                      "verify codex_research is spawning, check live_log activity")
    if n >= 1:
        return _check("cards_ready_stagnation", "WARN", n, 1,
                      f"{n} source(s) cards_ready > 4h",
                      "Pump will pick them up next cycle")
    return _check("cards_ready_stagnation", "OK", 0, 3, "no stagnation", "")


def chk_pump_task_health() -> dict:
    """Scheduled task QM_StrategyFarm_Pump_5min LastResult must be 0."""
    try:
        out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-ScheduledTaskInfo -TaskName 'QM_StrategyFarm_Pump_5min').LastTaskResult"],
            capture_output=True, text=True, timeout=15,
        )
        result = int((out.stdout or "0").strip() or "0")
    except Exception as exc:
        return _check("pump_task_lastresult", "WARN", "?", 0,
                      f"could not query task: {exc}",
                      "Run Get-ScheduledTask QM_StrategyFarm_Pump_5min manually")
    if result != 0:
        return _check("pump_task_lastresult", "FAIL", result, 0,
                      f"pump last exit code {result} (non-zero)",
                      "Run pump manually: python tools/strategy_farm/farmctl.py pump; "
                      "check error output. Code 112 = ERROR_DISK_FULL (also: any script abort)")
    return _check("pump_task_lastresult", "OK", 0, 0, "last run exit 0", "")


def chk_p2_pass_no_p3(con) -> dict:
    """P2-PASS work_items that lack a corresponding P3 work_item.
    The pump §10c promotion logic should always be at 0; > 5 = bug."""
    n = con.execute(
        """
        SELECT COUNT(*) FROM work_items w
        WHERE w.status='done' AND w.verdict='PASS' AND w.phase='P2'
          AND NOT EXISTS (
            SELECT 1 FROM work_items w2
            WHERE w2.ea_id=w.ea_id
              AND w2.symbol=w.symbol
              AND w2.setfile_path=w.setfile_path
              AND w2.phase='P3'
          )
        """
    ).fetchone()[0]
    if n >= 10:
        return _check("p2_pass_no_p3", "FAIL", n, 10,
                      f"{n} P2-PASS work_items without P3 promotion",
                      "Pump §10c is failing or backlogged; run farmctl pump manually")
    if n >= 3:
        return _check("p2_pass_no_p3", "WARN", n, 3,
                      f"{n} P2-PASS without P3 promotion (pump catches up gradually)",
                      "Next pump cycle (≤5 min) should promote them")
    return _check("p2_pass_no_p3", "OK", n, 10, f"{n} pending promotion", "")


def chk_ablation_grandchildren(con) -> dict:
    """work_items whose setfile_path has TWO `_ablation_` or `_grid_` tokens
    = depth-tracker bug, ablation child got re-ablated."""
    rows = con.execute("SELECT id, setfile_path FROM work_items WHERE status='pending'").fetchall()
    pat = re.compile(r"(_ablation_|_grid_).*(_ablation_|_grid_)")
    n = sum(1 for r in rows if r["setfile_path"] and pat.search(r["setfile_path"]))
    if n > 0:
        return _check("ablation_grandchildren", "FAIL", n, 0,
                      f"{n} work_items have grandchild setfile names",
                      "Depth filter regressed — check pump §10a/§10b setfile_path NOT LIKE clauses")
    return _check("ablation_grandchildren", "OK", 0, 0, "no grandchildren", "")


def chk_claude_review_starved(con) -> dict:
    """Lots of done builds with passing codex_review but no Claude review
    spawn — Claude is silently absent or the gate logic is wrong."""
    cutoff = (_utc_now() - dt.timedelta(hours=4)).strftime("%Y-%m-%dT%H:%M:%SZ")
    # Build_ea done with PASSed codex_review but no ea_review yet
    n_starved = con.execute(
        """
        SELECT COUNT(*) FROM tasks b
        WHERE b.kind='build_ea' AND b.status='done'
          AND EXISTS (
            SELECT 1 FROM tasks cr
            WHERE cr.kind='codex_review' AND cr.status='done'
              AND cr.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
              AND cr.payload_json LIKE '%"verdict": "PASS"%'
          )
          AND NOT EXISTS (
            SELECT 1 FROM tasks r WHERE r.kind='ea_review'
              AND r.payload_json LIKE '%"build_task_id": "' || b.id || '"%'
          )
        """
    ).fetchone()[0]
    # Last claude_review spawn (any kind) — proxy via ea_review tasks created
    n_recent = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='ea_review' AND created_at >= ?",
        (cutoff,),
    ).fetchone()[0]
    if n_starved >= 3 and n_recent == 0:
        return _check("claude_review_starved", "FAIL", n_starved, 3,
                      f"{n_starved} builds awaiting Claude review, 0 spawned in last 4h",
                      "Pump §5c gate broken or Claude blocked; check active_claude_count "
                      "and MAX_PARALLEL_CLAUDE in farmctl pump output")
    if n_starved >= 5:
        return _check("claude_review_starved", "WARN", n_starved, 5,
                      f"{n_starved} builds waiting for Claude review",
                      "Pump caps at 1 review/cycle — will catch up")
    return _check("claude_review_starved", "OK", n_starved, 3, "no starvation", "")


def chk_mt5_dispatch_idle(con) -> dict:
    """Pending P2/P3 work_items > 5 but no dispatch actions in last 30min =
    MT5 dispatcher is stuck."""
    n_pending = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending'"
    ).fetchone()[0]
    if n_pending < 5:
        return _check("mt5_dispatch_idle", "OK", n_pending, 5,
                      f"{n_pending} pending (low queue)", "")
    # Active work_items mean dispatch IS happening — but cross-check that
    # the active ones aren't all stranded (claimed_by terminal with no live
    # process). A stranded "active" is functionally the same as idle.
    rows = list(con.execute(
        "SELECT id, claimed_by, updated_at FROM work_items WHERE status='active'"
    ))
    if not rows:
        return _check("mt5_dispatch_idle", "FAIL", n_pending, 5,
                      f"{n_pending} pending, 0 active — dispatcher idle",
                      "Run farmctl pump (or wait for next 5-min cycle). "
                      "Inline worker-PID check should auto-release if MT5 died.")
    # Active rows exist — count how many are bound to a still-running MT5
    try:
        import subprocess as _sp
        out = _sp.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name terminal64 -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        n_mt5_alive = int((out.stdout or "0").strip() or "0")
    except Exception:
        n_mt5_alive = -1
    if n_mt5_alive == 0:
        return _check("mt5_dispatch_idle", "FAIL", len(rows), 0,
                      f"{n_pending} pending, {len(rows)} active rows but 0 terminal64 processes alive",
                      "Stranded active work_items — pump's inline PID check "
                      "will release them next cycle. If persisting, run "
                      "`farmctl repair` manually.")
    return _check("mt5_dispatch_idle", "OK", n_pending, 5,
                  f"{n_pending} pending, {len(rows)} active, {n_mt5_alive} terminal64 alive", "")


def chk_codex_zero_activity(con) -> dict:
    """Codex 0 active + build_ea pending > 0 + last build_ea created > 30min
    ago. Means codex isn't spawning despite work being available."""
    try:
        out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name codex -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        n_codex = int((out.stdout or "0").strip() or "0")
    except Exception:
        n_codex = 0
    n_pending_builds = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    if n_codex == 0 and n_pending_builds >= 3:
        return _check("codex_zero_activity", "FAIL", n_codex, 1,
                      f"0 codex procs but {n_pending_builds} pending build_ea tasks",
                      "Run farmctl pump manually; check codex.cmd is on PATH and codex CLI works")
    return _check("codex_zero_activity", "OK", n_codex, 1,
                  f"{n_codex} codex, {n_pending_builds} pending", "")


def chk_source_pool(con) -> dict:
    """Pending source pool < 10 = we'll run dry, need to seed more."""
    n = con.execute(
        "SELECT COUNT(*) FROM sources WHERE status='pending'"
    ).fetchone()[0]
    if n == 0:
        return _check("source_pool_drained", "FAIL", n, 10,
                      "0 pending sources — research will starve",
                      "Seed more sources: see tools/strategy_farm/seed_*.py examples")
    if n < 10:
        return _check("source_pool_drained", "WARN", n, 10,
                      f"only {n} pending sources",
                      "Add more sources before pool drains")
    return _check("source_pool_drained", "OK", n, 10, f"{n} pending sources", "")


def chk_quota_snapshot_fresh() -> dict:
    """Quota snapshot from Tampermonkey scrapers — stale = Chrome tabs closed
    or receiver dead."""
    if not QUOTA_SNAPSHOT.exists():
        return _check("quota_snapshot_fresh", "WARN", "missing", 300,
                      "quota_snapshot.json missing",
                      "Start QM_StrategyFarm_QuotaReceiver and open both Tampermonkey tabs")
    try:
        snap = json.loads(QUOTA_SNAPSHOT.read_text(encoding="utf-8"))
    except Exception as exc:
        return _check("quota_snapshot_fresh", "WARN", "unreadable", 300,
                      f"snapshot unreadable: {exc}", "Check receiver process")
    now = _utc_now()
    ages: dict = {}
    for src in ("codex", "claude"):
        s = snap.get(src) or {}
        ra = s.get("received_at")
        if ra:
            try:
                t = dt.datetime.fromisoformat(ra.replace("Z", "+00:00"))
                ages[src] = int((now - t).total_seconds())
            except Exception:
                pass
    max_age = max(ages.values()) if ages else None
    if max_age is None:
        return _check("quota_snapshot_fresh", "WARN", "no timestamps", 300,
                      "no received_at timestamps in snapshot",
                      "Open Tampermonkey tabs (chatgpt.com / claude.ai)")
    if max_age > 600:  # > 10 min
        return _check("quota_snapshot_fresh", "FAIL", max_age, 600,
                      f"oldest snapshot {max_age}s old (codex={ages.get('codex','?')}s, "
                      f"claude={ages.get('claude','?')}s)",
                      "Refresh Tampermonkey tabs in Chrome")
    if max_age > 300:
        return _check("quota_snapshot_fresh", "WARN", max_age, 300,
                      f"oldest snapshot {max_age}s old",
                      "Tabs may have lost focus — check Chrome")
    return _check("quota_snapshot_fresh", "OK", max_age, 300,
                  f"codex={ages.get('codex','?')}s, claude={ages.get('claude','?')}s", "")


# ---------------------------------------------------------------------------

ALL_CHECKS = [
    ("codex_review_fail_rate", chk_codex_review_fail_rate, True),  # needs con
    ("cards_ready_stagnation", chk_cards_ready_stagnation, True),
    ("pump_task_health",       chk_pump_task_health,       False),
    ("p2_pass_no_p3",          chk_p2_pass_no_p3,          True),
    ("ablation_grandchildren", chk_ablation_grandchildren, True),
    ("claude_review_starved",  chk_claude_review_starved,  True),
    ("mt5_dispatch_idle",      chk_mt5_dispatch_idle,      True),
    ("codex_zero_activity",    chk_codex_zero_activity,    True),
    ("source_pool",            chk_source_pool,            True),
    ("quota_snapshot_fresh",   chk_quota_snapshot_fresh,   False),
]


def run_all() -> dict:
    """Run all health checks. Returns the result dict and writes health.json."""
    con = _connect()
    results = []
    try:
        for _, fn, needs_con in ALL_CHECKS:
            try:
                results.append(fn(con) if needs_con else fn())
            except Exception as exc:
                results.append(_check(fn.__name__, "WARN", "exception", "?",
                                      f"check raised: {exc!r}",
                                      "Investigate health.py — check code"))
    finally:
        con.close()

    summary = {"ok": 0, "warn": 0, "fail": 0}
    for r in results:
        key = r["status"].lower()
        if key in summary:
            summary[key] += 1
    overall = "FAIL" if summary["fail"] > 0 else ("WARN" if summary["warn"] > 0 else "OK")

    payload = {
        "checked_at": _utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "overall": overall,
        "summary": summary,
        "checks": results,
    }
    HEALTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    HEALTH_FILE.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

    # Append alarms to log
    fails = [r for r in results if r["status"] == "FAIL"]
    if fails:
        ALARMS_LOG.parent.mkdir(parents=True, exist_ok=True)
        with ALARMS_LOG.open("a", encoding="utf-8") as f:
            for r in fails:
                f.write(f"{payload['checked_at']}\t{r['name']}\t{r['value']}\t{r['detail']}\n")
    return payload
