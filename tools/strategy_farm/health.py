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


def _is_codex_auth_broken(con) -> bool:
    """Shared helper: same logic as chk_codex_auth_broken, returns bool.
    Used by downstream checks for cascade suppression."""
    import time as _t
    import re as _re
    pattern = _re.compile(rb"401 Unauthorized")
    auth_path = Path(r"C:/Users/Administrator/.codex/auth.json")
    auth_mtime = auth_path.stat().st_mtime if auth_path.exists() else 0.0
    n_401 = 0
    for log in LOG_DIR.glob("codex_*.live.log"):
        try:
            log_mtime = log.stat().st_mtime
            if _t.time() - log_mtime > 900:
                continue
            # Stale 401: log last touched before the most recent `codex login`.
            # Those 401s are pre-login and don't reflect current auth state.
            if log_mtime < auth_mtime:
                continue
            with open(log, "rb") as fh:
                fh.seek(max(0, log.stat().st_size - 8192))
                tail = fh.read()
            if pattern.search(tail):
                n_401 += 1
        except OSError:
            continue
    auth_age_h = None
    if auth_path.exists():
        try:
            auth_age_h = (_t.time() - auth_mtime) / 3600
        except OSError:
            pass
    try:
        import subprocess as _sp
        out = _sp.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name codex -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        n_codex = int((out.stdout or "0").strip() or "0")
    except Exception:
        n_codex = -1
    n_pending = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    return (n_401 >= 2) or (n_codex == 0 and n_pending >= 1 and auth_age_h is not None and auth_age_h > 12)


def chk_codex_review_fail_rate(con) -> dict:
    """Codex review FAIL rate. Distinguish two classes:

    SYSTEM FAIL — phantom field check, schema drift, prompt-vs-producer
      mismatch. Fire RED. Example past incident: build_result missing
      `status` field that didn't exist.

    STRATEGY QUALITY — smoke_sanity 0-trade etc. The review IS doing its
      job catching weak strategy ideas. Pump §4b short-circuits these
      before codex_review is even spawned, but if some leak through that's
      not a system bug, just normal upstream noise. WARN/OK, not FAIL.

    Method: count FAILs by section. If section_fails are dominated by
    smoke_sanity (≥80% of FAILs touch it and no other section), call it
    strategy-quality. Else system.
    """
    cutoff = (_utc_now() - dt.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT payload_json FROM tasks WHERE kind='codex_review' AND status='done' "
        "AND updated_at >= ?", (cutoff,)
    ).fetchall()
    n = len(rows)
    n_fail = 0
    fails_smoke_only = 0
    fails_other = 0
    for r in rows:
        try:
            p = json.loads(r["payload_json"])
        except Exception:
            continue
        if (p.get("verdict") or "").upper() != "FAIL":
            continue
        n_fail += 1
        secs = p.get("sections") or {}
        failed_secs = {k for k, v in secs.items() if v == "FAIL"}
        # Strategy-quality classification: ONLY smoke_sanity (or smoke + build_result
        # which co-fail when smoke had 0 trades) failed
        if failed_secs and failed_secs.issubset({"smoke_sanity", "build_result"}):
            fails_smoke_only += 1
        else:
            fails_other += 1
    rate = n_fail / n if n > 0 else 0
    if n < 3:
        return _check("codex_review_fail_rate_1h", "OK", round(rate, 2), 0.8,
                      f"{n_fail}/{n} FAIL (low volume)", "")
    if fails_other >= 2:
        return _check("codex_review_fail_rate_1h", "FAIL", round(rate, 2), 0.8,
                      f"{fails_other}/{n} system-class FAILs in last hour",
                      "Inspect verdicts that FAIL on framework_corset, magic_registry, "
                      "or forbidden_grep — those indicate Codex producing bad code or "
                      "a schema drift, NOT just strategy quality")
    if rate >= 0.8 and fails_smoke_only >= 3:
        # All FAILs are strategy-quality (0-trade). Pump §4b should be
        # short-circuiting most of these BEFORE codex_review now, so this
        # rate should drop. Surface as WARN.
        return _check("codex_review_fail_rate_1h", "WARN", round(rate, 2), 0.8,
                      f"{fails_smoke_only}/{n} FAIL all on smoke_sanity (strategy quality)",
                      "Strategies producing 0 trades. Pump §4b will short-circuit "
                      "future ones before codex_review spawns. Watch the pattern — "
                      "if persists, consider tightening G0 trade-frequency check.")
    return _check("codex_review_fail_rate_1h", "OK", round(rate, 2), 0.8,
                  f"{n_fail}/{n} FAIL ({fails_smoke_only} strategy-quality, {fails_other} system)", "")


def chk_cards_ready_stagnation(con) -> dict:
    """Sources stuck in cards_ready > 4h. Suppressed when codex_auth_broken
    is upstream (codex_research can't run if codex is gated)."""
    auth_broken = _is_codex_auth_broken(con)

    cutoff = (_utc_now() - dt.timedelta(hours=4)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT id, title, updated_at FROM sources "
        "WHERE status='cards_ready' AND updated_at < ?", (cutoff,)
    ).fetchall()
    n = len(rows)
    if auth_broken and n >= 1:
        return _check("cards_ready_stagnation", "WARN", n, 3,
                      f"{n} sources cards_ready (codex_auth_broken upstream)",
                      "Will resume once OWNER runs `codex login` and codex circuit breaker clears")
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
    """Dispatch idle = pending queue piling up with no progress.

    Smarter check than "is terminal64 alive right now" — MT5 spawns
    transiently per backtest, so terminal64=0 between launches doesn't
    mean idle. Look at:
      (a) Pending count vs active rows — many pending, no active = idle.
      (b) IF active rows exist, check pwsh.exe parents (run_smoke.ps1
          workers) are alive — that's the real signal MT5 work is in
          flight. terminal64 may be 0 just between runs.
      (c) Per-work_item recent log activity also confirms progress.

    Previous logic alarmed on "0 terminal64" — false-positive when pwsh
    workers were mid-backtest with terminal64 transiently absent.
    """
    n_pending = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending'"
    ).fetchone()[0]
    if n_pending < 5:
        return _check("mt5_dispatch_idle", "OK", n_pending, 5,
                      f"{n_pending} pending (low queue)", "")
    rows = list(con.execute(
        "SELECT id, claimed_by, updated_at FROM work_items WHERE status='active'"
    ))
    if not rows:
        return _check("mt5_dispatch_idle", "FAIL", n_pending, 5,
                      f"{n_pending} pending, 0 active — dispatcher idle",
                      "Run farmctl pump (or wait for next 5-min cycle).")
    # Active rows exist. Check pwsh.exe worker procs (run_smoke.ps1 parents).
    # They wrap terminal64.exe and outlive each terminal64 spawn.
    try:
        import subprocess as _sp
        out = _sp.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name pwsh -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        n_pwsh = int((out.stdout or "0").strip() or "0")
    except Exception:
        n_pwsh = -1
    # Also check work_item live_log activity in last 5 min — proves work is
    # actually progressing, not just zombie pwsh.
    fresh_wi_logs = 0
    try:
        import time as _t
        for f in LOG_DIR.glob("work_item_*.log"):
            if _t.time() - f.stat().st_mtime < 300:
                fresh_wi_logs += 1
    except Exception:
        pass
    if n_pwsh >= len(rows) or fresh_wi_logs >= 1:
        return _check("mt5_dispatch_idle", "OK", n_pending, 5,
                      f"{n_pending} pending, {len(rows)} active, {n_pwsh} pwsh workers, "
                      f"{fresh_wi_logs} fresh work_item logs", "")
    # Active rows but no pwsh workers AND no fresh logs → truly stranded
    return _check("mt5_dispatch_idle", "FAIL", len(rows), 0,
                  f"{n_pending} pending, {len(rows)} active, {n_pwsh} pwsh, "
                  f"{fresh_wi_logs} fresh logs — workers dead",
                  "Stranded active work_items. Inline PID check should "
                  "release them next pump cycle.")


def chk_codex_zero_activity(con) -> dict:
    """Codex 0 active + build_ea pending > 0 = codex stuck.

    Suppressed when codex_auth_broken is firing — that's the upstream
    cause of 0 codex, not a separate problem. Same for cards_ready
    stagnation downstream.
    """
    # Upstream check: codex auth broken takes precedence
    auth_broken = _is_codex_auth_broken(con)

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
    if auth_broken and n_codex == 0:
        return _check("codex_zero_activity", "WARN", n_codex, 1,
                      f"0 codex (auth_broken upstream; circuit breaker active)",
                      "Downstream of codex_auth_broken — will recover once OWNER runs `codex login`")
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


def chk_codex_auth_broken(con) -> dict:
    """Detect Codex authentication failures.

    Two signals (either trips alarm):
      a) Recent codex_*.live.log files contain 401 Unauthorized (auth
         actively failing right now)
      b) `auth.json` age > 12h AND there are pending build_ea tasks but
         0 codex procs (pipeline silent because circuit breaker is
         suppressing 401 spam, but auth is still stale)
    """
    import time as _t
    import re as _re
    pattern = _re.compile(rb"401 Unauthorized")
    auth_path = Path(r"C:/Users/Administrator/.codex/auth.json")
    auth_mtime = auth_path.stat().st_mtime if auth_path.exists() else 0.0
    n_401 = 0
    for log in LOG_DIR.glob("codex_*.live.log"):
        try:
            log_mtime = log.stat().st_mtime
            age = _t.time() - log_mtime
            if age > 900:
                continue
            # Stale 401: log last touched before the most recent `codex login`.
            # Those 401s are pre-login and don't reflect current auth state.
            if log_mtime < auth_mtime:
                continue
            with open(log, "rb") as fh:
                fh.seek(max(0, log.stat().st_size - 8192))
                tail = fh.read()
            if pattern.search(tail):
                n_401 += 1
        except OSError:
            continue

    # Signal (b): auth.json stale + pipeline silent on codex
    auth_age_h: float | None = None
    if auth_path.exists():
        try:
            auth_age_h = (_t.time() - auth_mtime) / 3600
        except OSError:
            pass
    try:
        import subprocess as _sp
        out = _sp.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name codex -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        n_codex = int((out.stdout or "0").strip() or "0")
    except Exception:
        n_codex = -1
    n_pending = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    pipeline_silent_on_codex = (n_codex == 0 and n_pending >= 1
                                and auth_age_h is not None and auth_age_h > 12)

    if n_401 >= 2 or pipeline_silent_on_codex:
        detail = (f"{n_401} recent 401-logs"
                  + (f", auth_age={auth_age_h:.1f}h" if auth_age_h else "")
                  + (f", {n_pending} builds pending with 0 codex" if pipeline_silent_on_codex else ""))
        return _check("codex_auth_broken", "FAIL", n_401 or 1, 1,
                      detail,
                      "Run `codex login` interactively on the VPS. The pump circuit "
                      "breaker is preventing new spawns until then.")
    if n_401 == 1:
        return _check("codex_auth_broken", "WARN", 1, 1,
                      f"1 recent codex log has 401 — could be transient",
                      "Watch for more. If recurs, OWNER must `codex login`.")
    return _check("codex_auth_broken", "OK", 0, 1,
                  f"no 401 errors; auth_age={auth_age_h:.1f}h" if auth_age_h else "no 401", "")


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
    ("codex_auth_broken",      chk_codex_auth_broken,      True),
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
