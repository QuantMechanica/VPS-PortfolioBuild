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
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(r"D:\QM\strategy_farm")
REPO_ROOT = Path(__file__).resolve().parents[2]
FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"
DB = ROOT / "state" / "farm_state.sqlite"
HEALTH_FILE = ROOT / "state" / "health.json"
ALARMS_LOG = ROOT / "state" / "health_alarms.log"
QUOTA_SNAPSHOT = ROOT / "state" / "quota_snapshot.json"
LOG_DIR = ROOT / "logs"
CODEX_BRIDGE_HEARTBEAT = ROOT / "state" / "codex_bridge_heartbeat.txt"
ZERO_TRADE_DEAD_THRESHOLD = 0.80
ZERO_TRADE_DEAD_MIN_DONE = 5
ZERO_TRADE_REWORK_DEDUP_HOURS = 6
PHASE_ACTIVE_TIMEOUT_MIN = {
    "P2": 8,
    "P3": 60,
    "P3.5": 30,
    "P4": 30,
    "P5": 30,
    "P5b": 30,
    "P5c": 30,
    "P6": 30,
    "P7": 30,
    "P8": 30,
}


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


def _creationflags_no_window() -> int:
    if sys.platform == "win32" and hasattr(subprocess, "CREATE_NO_WINDOW"):
        return subprocess.CREATE_NO_WINDOW
    return 0


def _json_obj(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _summary_net_profit_total(summary: dict) -> float | None:
    runs = summary.get("runs")
    if isinstance(runs, list) and runs:
        total = 0.0
        seen = False
        for run in runs:
            if not isinstance(run, dict):
                continue
            value = run.get("net_profit")
            try:
                total += float(value)
                seen = True
            except (TypeError, ValueError):
                continue
        if seen:
            return total
    for key in ("net_profit", "profit"):
        try:
            return float(summary[key])
        except (KeyError, TypeError, ValueError):
            continue
    return None


def _work_item_p2_net_profit(row: sqlite3.Row) -> float | None:
    payload = _json_obj(row["payload_json"])
    recovered = payload.get("recovered_stats")
    if isinstance(recovered, dict):
        try:
            return float(recovered["net_profit"])
        except (KeyError, TypeError, ValueError):
            pass
    evidence_path = row["evidence_path"]
    if not evidence_path:
        return None
    path = Path(evidence_path)
    if not path.exists():
        return None
    try:
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    return _summary_net_profit_total(summary if isinstance(summary, dict) else {})


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
            creationflags=_creationflags_no_window(),
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
    """Profitable P2-PASS work_items that lack a corresponding P3 work_item.

    P2 PASS only means the smoke/backtest completed and met the minimum
    trade gate. P2 rows with non-positive net profit are intentionally not
    promoted by the pump profit filter, so the detector must not count them
    as stranded promotion work.
    """
    rows = con.execute(
        """
        SELECT w.* FROM work_items w
        WHERE w.status='done' AND w.verdict='PASS' AND w.phase='P2'
          AND NOT EXISTS (
            SELECT 1 FROM work_items w2
            WHERE w2.ea_id=w.ea_id
              AND w2.symbol=w.symbol
              AND w2.setfile_path=w.setfile_path
              AND w2.phase='P3'
          )
        """
    ).fetchall()
    promotable = [r for r in rows if (_work_item_p2_net_profit(r) or 0.0) > 0.0]
    n = len(promotable)
    if n >= 10:
        return _check("p2_pass_no_p3", "FAIL", n, 10,
                      f"{n} profitable P2-PASS work_items without P3 promotion",
                      "Pump §10c is failing or backlogged; run farmctl pump manually")
    if n >= 3:
        return _check("p2_pass_no_p3", "WARN", n, 3,
                      f"{n} profitable P2-PASS without P3 promotion (pump catches up gradually)",
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


def _parse_utc_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    text = str(value).strip()
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        parsed = dt.datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except ValueError:
        try:
            return dt.datetime.strptime(text, "%Y-%m-%d %H:%M:%S").replace(tzinfo=dt.timezone.utc)
        except ValueError:
            return None


def chk_active_row_age(con) -> dict:
    rows = con.execute(
        """
        SELECT id, phase, ea_id, symbol, claimed_by, updated_at
        FROM work_items
        WHERE status='active'
        """
    ).fetchall()
    now = _utc_now()
    offenders = []
    for r in rows:
        phase = str(r["phase"] or "")
        timeout_min = PHASE_ACTIVE_TIMEOUT_MIN.get(phase)
        if timeout_min is None:
            continue
        updated = _parse_utc_datetime(r["updated_at"])
        if updated is None:
            continue
        age_min = (now - updated).total_seconds() / 60.0
        if age_min > timeout_min:
            offenders.append((age_min, timeout_min, r))
    if not offenders:
        return _check("active_row_age", "OK", 0, 1, "no active rows beyond phase timeout", "")
    worst_age, worst_timeout, worst = max(offenders, key=lambda x: x[0])
    status = "FAIL" if worst_age > (2 * worst_timeout) else "WARN"
    detail = (
        f"{len(offenders)} active rows exceed phase timeout; worst "
        f"{worst['ea_id']} {worst['symbol']} {worst['phase']} "
        f"terminal={worst['claimed_by']} age={worst_age:.1f}m timeout={worst_timeout}m"
    )
    return _check("active_row_age", status, round(worst_age, 1), worst_timeout,
                  detail, "Run farmctl pump; active_timeouts should fail hung rows and release MT5 slots")


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
            creationflags=_creationflags_no_window(),
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


def chk_zerotrade_rework_backlog(con) -> dict:
    """EAs with recurrent P2 zero-trade FAILs must have a recent rework task.

    WARN if any EA crosses the 80% / 5-sample threshold without a rework
    task in the last 6 hours. FAIL if more than 10 EAs are in that state,
    which indicates a systemic build/strategy-class issue rather than a
    single bad EA.
    """
    rows = con.execute(
        """
        SELECT ea_id,
               SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) AS done,
               SUM(CASE WHEN status='done' AND verdict='FAIL'
                         AND payload_json LIKE '%MIN_TRADES_NOT_MET%'
                        THEN 1 ELSE 0 END) AS zt
        FROM work_items
        WHERE phase='P2'
        GROUP BY ea_id
        HAVING done >= ?
           AND (zt * 1.0 / done) >= ?
        ORDER BY ea_id
        """,
        (ZERO_TRADE_DEAD_MIN_DONE, ZERO_TRADE_DEAD_THRESHOLD),
    ).fetchall()

    cutoff = (_utc_now() - dt.timedelta(hours=ZERO_TRADE_REWORK_DEDUP_HOURS)).strftime("%Y-%m-%dT%H:%M:%S+00:00")
    backlog = []
    for r in rows:
        ea_id = r["ea_id"]
        existing = con.execute(
            """
            SELECT id FROM tasks
            WHERE card_id=? AND kind='build_ea'
              AND payload_json LIKE '%ZERO_TRADE_RECURRENT%'
              AND created_at >= ?
            ORDER BY created_at DESC LIMIT 1
            """,
            (ea_id, cutoff),
        ).fetchone()
        if existing:
            continue
        done = int(r["done"] or 0)
        zt = int(r["zt"] or 0)
        backlog.append(f"{ea_id}:{zt}/{done}")

    n = len(backlog)
    detail = ", ".join(backlog[:10]) if backlog else "no uncovered recurrent zero-trade EAs"
    if n > 10:
        return _check("zerotrade_rework_backlog", "FAIL", n, 10,
                      f"{n} EAs need zero-trade rework tasks ({detail})",
                      "Run farmctl pump; if backlog remains, inspect detector or widespread EA entry bugs.")
    if n > 0:
        return _check("zerotrade_rework_backlog", "WARN", n, 1,
                      f"{n} EA(s) need zero-trade rework tasks ({detail})",
                      "Next pump cycle should create build_ea + codex_inbox auto-rework tasks.")
    return _check("zerotrade_rework_backlog", "OK", 0, 1, detail, "")


def _has_auto_build_task_file(ea_id: str) -> bool:
    inbox = ROOT / "codex_inbox"
    for rel in ("", ".processing", ".archive"):
        d = inbox / rel if rel else inbox
        if d.is_dir() and any(d.glob(f"auto-build-{ea_id}-*.md")):
            return True
    return False


def chk_unbuilt_cards_count(con) -> dict:
    """Approved cards with no matching .ex5 and no bridge auto-build task."""
    cards_dir = ROOT / "artifacts" / "cards_approved"
    if not cards_dir.is_dir():
        return _check("unbuilt_cards_count", "OK", 0, 3,
                      "cards_approved missing or empty", "")
    unbuilt = []
    for card_md in sorted(cards_dir.glob("QM5_*.md")):
        m = re.match(r"(QM5_\d{4})_(.+)\.md$", card_md.name)
        if not m:
            continue
        ea_id, slug = m.group(1), m.group(2)
        label = f"{ea_id}_{slug}"
        ex5 = FRAMEWORK_EAS_DIR / label / f"{label}.ex5"
        if ex5.exists() or _has_auto_build_task_file(ea_id):
            continue
        unbuilt.append(ea_id)
    n = len(unbuilt)
    detail = ", ".join(unbuilt[:10]) if unbuilt else "no approved cards waiting for auto-build task"
    if n > 10:
        return _check("unbuilt_cards_count", "FAIL", n, 10,
                      f"{n} approved cards lack .ex5 and auto-build task ({detail})",
                      "Run farmctl pump; it should emit up to 2 auto-build bridge tasks per cycle.")
    if n > 3:
        return _check("unbuilt_cards_count", "WARN", n, 3,
                      f"{n} approved cards lack .ex5 and auto-build task ({detail})",
                      "Next pump cycles should drain this via auto-build .md tasks.")
    return _check("unbuilt_cards_count", "OK", n, 3, detail, "")


def chk_unenqueued_eas_count(con) -> dict:
    """Reviewed and built EAs that still have no P2 work_items."""
    rows = con.execute(
        """
        SELECT card_id, id AS review_task_id
        FROM tasks
        WHERE kind='ea_review' AND status='done'
        GROUP BY card_id
        """
    ).fetchall()
    waiting = []
    for r in rows:
        ea_id = r["card_id"]
        if not ea_id:
            continue
        wi_count = con.execute(
            "SELECT COUNT(*) FROM work_items WHERE ea_id=? AND phase='P2'",
            (ea_id,),
        ).fetchone()[0]
        if wi_count > 0:
            continue
        terminal_task_exists = con.execute(
            """
            SELECT 1 FROM tasks
            WHERE kind='backtest_p2'
              AND card_id=?
              AND status IN ('done', 'failed')
            LIMIT 1
            """,
            (ea_id,),
        ).fetchone()
        if terminal_task_exists:
            continue
        candidates = sorted(p for p in FRAMEWORK_EAS_DIR.glob(f"{ea_id}_*") if p.is_dir())
        if not candidates:
            continue
        ex5 = candidates[0] / f"{candidates[0].name}.ex5"
        if ex5.exists():
            waiting.append(ea_id)
    n = len(waiting)
    detail = ", ".join(waiting[:10]) if waiting else "no reviewed built EAs waiting for P2 enqueue"
    if n > 10:
        return _check("unenqueued_eas_count", "FAIL", n, 10,
                      f"{n} reviewed built EAs have no P2 work_items ({detail})",
                      "Run farmctl pump; it should enqueue up to 3 EAs into P2 per cycle.")
    if n > 3:
        return _check("unenqueued_eas_count", "WARN", n, 3,
                      f"{n} reviewed built EAs have no P2 work_items ({detail})",
                      "Next pump cycles should enqueue P2 work_items.")
    return _check("unenqueued_eas_count", "OK", n, 3, detail, "")


def chk_codex_bridge_heartbeat(con) -> dict:
    """Interactive bridge heartbeat freshness."""
    if not CODEX_BRIDGE_HEARTBEAT.exists():
        return _check("codex_bridge_heartbeat", "WARN", "missing", 300,
                      "codex bridge heartbeat file missing",
                      "Ensure the Codex /goal poller touches state/codex_bridge_heartbeat.txt each cycle.")
    age = int((_utc_now().timestamp()) - CODEX_BRIDGE_HEARTBEAT.stat().st_mtime)
    if age > 1800:
        return _check("codex_bridge_heartbeat", "FAIL", age, 1800,
                      f"heartbeat stale for {age}s",
                      "Restart or inspect the interactive Codex bridge.")
    if age > 300:
        return _check("codex_bridge_heartbeat", "WARN", age, 300,
                      f"heartbeat stale for {age}s",
                      "Bridge may be idle or wedged; check Codex terminal.")
    return _check("codex_bridge_heartbeat", "OK", age, 300,
                  f"heartbeat age {age}s", "")


def chk_disk_free_space(con) -> dict:
    """D: free-space watchdog for reports/log growth."""
    free_gb = shutil.disk_usage("D:/").free / (1024 ** 3)
    value = round(free_gb, 1)
    if free_gb < 10:
        return _check("disk_free_gb", "FAIL", value, 10,
                      f"D: free {free_gb:.1f}GB < 10GB threshold",
                      "Investigate D:/QM/reports + D:/QM/strategy_farm/logs for cleanup. "
                      "NEVER delete state/farm_state.sqlite or cards_approved/.")
    if free_gb < 25:
        return _check("disk_free_gb", "WARN", value, 25,
                      f"D: free {free_gb:.1f}GB < 25GB warn",
                      "Consider rotating logs older than 30 days.")
    return _check("disk_free_gb", "OK", value, 25,
                  f"D: free {free_gb:.1f}GB", "")


def chk_p_pass_stagnation(con) -> dict:
    """Alert if no P3+ PASS verdicts arrive for 6h/12h."""
    cutoff_6h = (_utc_now() - dt.timedelta(hours=6)).strftime("%Y-%m-%dT%H:%M:%S")
    cutoff_12h = (_utc_now() - dt.timedelta(hours=12)).strftime("%Y-%m-%dT%H:%M:%S")
    phases = ("P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8")
    placeholders = ",".join("?" for _ in phases)
    n_recent_p3plus = con.execute(
        f"""
        SELECT COUNT(*) FROM work_items
        WHERE phase IN ({placeholders})
          AND verdict='PASS'
          AND updated_at >= ?
        """,
        (*phases, cutoff_6h),
    ).fetchone()[0]
    if n_recent_p3plus == 0:
        n_12h = con.execute(
            f"""
            SELECT COUNT(*) FROM work_items
            WHERE phase IN ({placeholders})
              AND verdict='PASS'
              AND updated_at >= ?
            """,
            (*phases, cutoff_12h),
        ).fetchone()[0]
        if n_12h == 0:
            return _check("p_pass_stagnation", "FAIL", n_12h, 1,
                          "0 P3+ PASS verdicts in last 12h",
                          "Pipeline stuck on infrastructure or strategy quality. "
                          "Trigger Gmail alarm + check bridge_review_pending.md.")
        return _check("p_pass_stagnation", "WARN", n_recent_p3plus, 1,
                      "0 P3+ PASS in last 6h (had >=1 in last 12h)",
                      "Watch for next cascade. If next iter still 0, escalate.")
    return _check("p_pass_stagnation", "OK", n_recent_p3plus, 1,
                  f"{n_recent_p3plus} P3+ PASS in last 6h", "")


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
    ("active_row_age",         chk_active_row_age,         True),
    ("codex_zero_activity",    chk_codex_zero_activity,    True),
    ("source_pool",            chk_source_pool,            True),
    ("zerotrade_rework_backlog", chk_zerotrade_rework_backlog, True),
    ("unbuilt_cards_count",    chk_unbuilt_cards_count,    True),
    ("unenqueued_eas_count",   chk_unenqueued_eas_count,   True),
    ("codex_bridge_heartbeat", chk_codex_bridge_heartbeat, True),
    ("disk_free_space",        chk_disk_free_space,        True),
    ("p_pass_stagnation",      chk_p_pass_stagnation,      True),
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
