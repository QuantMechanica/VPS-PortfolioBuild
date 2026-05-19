"""Anti-orphan repair pass — auto-fix detected pipeline anomalies.

Where SAFE, auto-fix. Where unsafe (multi-cause failures), only log.
Runs every hour via QM_StrategyFarm_Repair_Hourly, plus on-demand via
`farmctl repair`. The watchdog DETECTS, this module REPAIRS.

Repair handlers (each is idempotent, returns count of actions taken):

  R1  Stranded cards_ready > 4h with no fresh live_log → flip parent task
      to a state where pump auto-picks (no-op if already pending);
      effectively a poke. (Pump §_claim_research_source picks them anyway
      after 2026-05-17 fix, so this is a safety net for older state.)

  R2  Stranded active source with no fresh codex_research / claude_research
      live_log activity → reset to cards_ready (let pump pick up again
      with fresh worker). Avoids the "stuck active forever" case.

  R3  Codex_review FAIL whose ONLY finding is the phantom build_result
      status check (now fixed) → delete the FAIL verdict + reset
      build_ea blocked→done so pump §5a re-spawns codex_review with
      corrected prompt. Idempotent — only fires if finding pattern
      matches the known bug.

  R4  Stranded P2-PASS without P3 promotion → call the same logic pump
      §10c uses, in case pump cycle hasn't run yet.

  R5  Stale work_items in status='active' with no MT5 process tied to
      their `claimed_by` terminal AND updated_at > 2h → reset to pending.
      Catches the case where MT5 worker crashes mid-backtest.

  R6  Ablation grandchildren (setfile_path has two `_ablation_`/`_grid_`
      tokens) — delete the work_item + setfile (the depth-tracker bug
      should be fixed, but this catches regressions).

  R7  Codex_review tasks pending > 30 min with no live_log activity → reset
      to pending state so pump re-spawns. Avoids stuck reviews.

Output: {repairs_applied: [...], skipped: [...], errors: [...]}. Each
repair record has {handler, target, action, detail}.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import time
from pathlib import Path

ROOT = Path(r"D:\QM\strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
LOG_DIR = ROOT / "logs"


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + (
        dt.datetime.now(dt.timezone.utc).strftime("%f")[:6]
    ) + "Z"


def _connect() -> sqlite3.Connection:
    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row
    return con


def _live_log_fresh(pattern: str, max_age_sec: int = 600) -> int:
    """Return count of live_log files matching pattern modified < max_age_sec."""
    now = time.time()
    n = 0
    for f in LOG_DIR.glob(pattern):
        try:
            if now - f.stat().st_mtime < max_age_sec:
                n += 1
        except OSError:
            pass
    return n


# ---------------------------------------------------------------------------

def repair_stranded_active_sources(con) -> list[dict]:
    """R2: active source assigned to worker X, but X has no fresh live_log →
    reset to cards_ready. Means worker died, source stuck active."""
    out = []
    rows = con.execute(
        "SELECT id, title, assigned_worker, updated_at FROM sources WHERE status='active'"
    ).fetchall()
    for r in rows:
        worker = (r["assigned_worker"] or "").lower()
        if not worker:
            continue
        # Check live_log freshness for this worker's research session
        pattern = (f"codex_research_{r['id']}.live.log" if worker == "codex"
                   else f"claude_research_{r['id']}.live.log")
        log_path = LOG_DIR / pattern
        fresh = False
        try:
            if log_path.exists():
                if time.time() - log_path.stat().st_mtime < 300:  # 5 min
                    fresh = True
        except OSError:
            pass
        if fresh:
            continue
        # Source has been active > 30 min with no log activity → reset
        try:
            t = dt.datetime.fromisoformat(r["updated_at"].replace("Z", "+00:00"))
        except Exception:
            t = None
        if t and (dt.datetime.now(dt.timezone.utc) - t).total_seconds() < 1800:
            continue  # too recent to reset
        con.execute(
            "UPDATE sources SET status='cards_ready', updated_at=? WHERE id=?",
            (_utc_now(), r["id"]),
        )
        out.append({
            "handler": "R2_stranded_active_source",
            "target": r["id"],
            "action": "reset active → cards_ready",
            "detail": f"worker={worker} title={r['title'][:60]!r} (no live_log activity)",
        })
    if out:
        con.commit()
    return out


def repair_phantom_codex_review_fails(con) -> list[dict]:
    """R3: codex_review with ONLY phantom-status-field finding.
    The §E prompt was fixed 2026-05-17 — any old FAILs caused solely by
    'no top-level status field' should be re-run.
    """
    out = []
    phantom_pattern = re.compile(r"missing.*top-level\s+status|no.*top-level\s+status|"
                                 r"no\s+accepted\s+top-level\s+status|expected.*status\s+field",
                                 re.IGNORECASE)
    rows = con.execute(
        "SELECT id, payload_json FROM tasks WHERE kind='codex_review' AND status='done' "
        "AND payload_json LIKE '%\"verdict\": \"FAIL\"%'"
    ).fetchall()
    for r in rows:
        payload = json.loads(r["payload_json"])
        findings = payload.get("findings") or []
        if not findings:
            continue
        # Only fix if EVERY finding matches the phantom-status pattern
        if all(phantom_pattern.search(str(f)) for f in findings):
            # Delete the FAIL verdict, reset build_ea, drop this codex_review row
            vp = payload.get("verdict_path")
            if vp and os.path.exists(vp):
                try: os.remove(vp)
                except OSError: pass
            build_id = payload.get("build_task_id")
            con.execute("DELETE FROM tasks WHERE id=?", (r["id"],))
            if build_id:
                brow = con.execute(
                    "SELECT payload_json, status FROM tasks WHERE id=? AND kind='build_ea'",
                    (build_id,),
                ).fetchone()
                if brow and brow["status"] in ("blocked", "failed"):
                    bp = json.loads(brow["payload_json"])
                    if bp.get("blocked_reason") == "codex_review_fail":
                        bp.pop("blocked_reason", None)
                        bp.pop("codex_review_findings", None)
                        bp["attempt"] = max(0, int(bp.get("attempt", 0)) - 1)
                        con.execute(
                            "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
                            (json.dumps(bp), _utc_now(), build_id),
                        )
            out.append({
                "handler": "R3_phantom_codex_review_fail",
                "target": r["id"],
                "action": "deleted FAIL + reset build to done",
                "detail": f"build_task_id={build_id!r} findings_count={len(findings)}",
            })
    if out:
        con.commit()
    return out


def repair_grandchildren_setfiles(con) -> list[dict]:
    """R6: work_items whose setfile_path has 2+ ablation/grid tokens =
    depth-tracker regression. Delete work_item + setfile."""
    out = []
    pat = re.compile(r"(_ablation_|_grid_).*(_ablation_|_grid_)")
    rows = con.execute(
        "SELECT id, ea_id, symbol, setfile_path FROM work_items WHERE status='pending'"
    ).fetchall()
    for r in rows:
        sp = r["setfile_path"] or ""
        if not pat.search(sp):
            continue
        con.execute("DELETE FROM work_items WHERE id=?", (r["id"],))
        if os.path.exists(sp):
            try: os.remove(sp)
            except OSError: pass
        out.append({
            "handler": "R6_grandchild_setfile",
            "target": r["id"],
            "action": "deleted work_item + setfile",
            "detail": f"ea={r['ea_id']} sym={r['symbol']} setfile={os.path.basename(sp)}",
        })
    if out:
        con.commit()
    return out


def repair_stale_active_work_items(con) -> list[dict]:
    """R5: work_items in 'active' status with NO live MT5 terminal backing
    them → reset to pending. Catches MT5 worker crashes immediately
    (don't wait 2h for the stale-active path).

    Two paths:
      a) No work_item live_log activity in 30 min → reset (slow path)
      b) claimed_by=Tn but no terminal64 process under D:/QM/mt5/Tn/ →
         reset IMMEDIATELY (fast path; means MT5 crashed/closed)

    OWNER 2026-05-17: the slow path missed a real crash because all
    terminals went down within minutes of being claimed. Fast path
    catches that case.
    """
    out = []
    # Map terminal name → True/False (is process running for that path?)
    live_terminals = _running_mt5_terminals()

    rows = con.execute(
        "SELECT id, ea_id, symbol, updated_at, claimed_by, payload_json FROM work_items WHERE status='active'"
    ).fetchall()
    for r in rows:
        try:
            t = dt.datetime.fromisoformat(r["updated_at"].replace("Z", "+00:00"))
            age_sec = (dt.datetime.now(dt.timezone.utc) - t).total_seconds()
        except Exception:
            age_sec = 0

        # Fast path: terminal claimed but no process for that path
        claimed = (r["claimed_by"] or "").upper()
        if claimed and claimed not in live_terminals and age_sec > 60:
            con.execute(
                "UPDATE work_items SET status='pending', claimed_by=NULL, "
                "attempt_count=COALESCE(attempt_count,0)+1, updated_at=? WHERE id=?",
                (_utc_now(), r["id"]),
            )
            out.append({
                "handler": "R5_dead_terminal_work_item",
                "target": r["id"],
                "action": f"reset active → pending (terminal {claimed} not running)",
                "detail": f"ea={r['ea_id']} sym={r['symbol']} age_min={age_sec/60:.0f}",
            })
            continue

        # Slow path: 2h old + no log activity → reset
        if age_sec < 7200:
            continue
        log_path = LOG_DIR / f"work_item_{r['id']}.log"
        if log_path.exists():
            try:
                if time.time() - log_path.stat().st_mtime < 1800:
                    continue
            except OSError:
                pass
        con.execute(
            "UPDATE work_items SET status='pending', claimed_by=NULL, "
            "attempt_count=COALESCE(attempt_count,0)+1, updated_at=? WHERE id=?",
            (_utc_now(), r["id"]),
        )
        out.append({
            "handler": "R5_stale_active_work_item",
            "target": r["id"],
            "action": f"reset active → pending (claimed_by={r['claimed_by']!r})",
            "detail": f"ea={r['ea_id']} sym={r['symbol']} age_h={age_sec/3600:.1f}",
        })
    if out:
        con.commit()
    return out


def _running_mt5_terminals() -> set[str]:
    """Return set of factory terminal names ('T1'..'T10') that currently have a
    terminal64.exe process tied to D:/QM/mt5/Tn/."""
    import subprocess
    try:
        out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-Process -Name terminal64 -ErrorAction SilentlyContinue | "
             "ForEach-Object { $_.Path } | Out-String"],
            capture_output=True, text=True, timeout=15,
        )
        paths = (out.stdout or "").splitlines()
    except Exception:
        return set()
    live: set[str] = set()
    import re as _re
    for p in paths:
        m = _re.search(r"\\mt5\\(T(?:[1-9]|10))\\", p, _re.IGNORECASE)
        if m:
            live.add(m.group(1).upper())
    return live


def repair_permanent_build_failures(con) -> list[dict]:
    """R10: build_ea status='blocked' with attempt_count >= MAX_RETRIES has
    nowhere to go — retry_blocked_builds skips it, so it pollutes the
    blocked queue indefinitely. Mark as 'failed' terminal status so the
    pipeline can move on.

    Observed pattern 2026-05-17: 14 of 15 blocked builds had attempt_count=3
    accumulating from bugs we'd already fixed (codex.cmd PATH issue,
    phantom status-field check, etc.). After bugs were fixed, they were
    stuck because nobody re-tried them. This handler closes the loop.

    Threshold: attempt_count >= 3 (matches retry_blocked_builds
    MAX_BUILD_RETRIES). Failures stay in DB as evidence — not deleted —
    just transitioned from 'blocked' (limbo) to 'failed' (terminal).
    """
    out = []
    MAX_BUILD_RETRIES = 3
    rows = con.execute(
        "SELECT id, payload_json FROM tasks WHERE kind='build_ea' AND status='blocked'"
    ).fetchall()
    for r in rows:
        p = json.loads(r["payload_json"])
        attempts = int(p.get("attempt_count", 0))
        if attempts < MAX_BUILD_RETRIES:
            continue
        p["final_failure"] = "permanent_blocked_retries_exhausted"
        p["failed_at"] = _utc_now()
        con.execute(
            "UPDATE tasks SET status='failed', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(p), _utc_now(), r["id"]),
        )
        out.append({
            "handler": "R10_permanent_build_failure",
            "target": r["id"],
            "action": "blocked → failed (retries exhausted)",
            "detail": f"ea={p.get('ea_id')} attempts={attempts} last={(p.get('last_blocked_reason') or p.get('blocked_reason') or '?')[:80]}",
        })
    if out:
        con.commit()
    return out


def repair_orphan_g0_claims(con) -> list[dict]:
    """R9: orphan .g0_claim files — card moved out of cards_draft/ (approved
    or rejected) but the claim lock got left behind. Or claim is older than
    1h (G0 batch should be long done by then). Clean up so future spawners
    aren't confused by stale state.
    """
    out = []
    drafts_dir = ROOT / "artifacts" / "cards_draft"
    if not drafts_dir.is_dir():
        return out
    now = time.time()
    for lock in drafts_dir.glob("*.g0_claim"):
        # Sibling card (strip the .g0_claim suffix)
        card = lock.with_suffix("")  # removes .g0_claim → leaves <stem>.md
        if not card.exists():
            try:
                lock.unlink()
                out.append({
                    "handler": "R9_orphan_g0_claim",
                    "target": lock.name,
                    "action": "deleted orphan (card moved out of cards_draft)",
                    "detail": f"sibling {card.name} no longer exists",
                })
            except OSError:
                pass
            continue
        # Card still present but claim is old → assume stale (spawn died)
        try:
            age = now - lock.stat().st_mtime
        except OSError:
            continue
        if age > 3600:  # > 1h
            try:
                lock.unlink()
                out.append({
                    "handler": "R9_orphan_g0_claim",
                    "target": lock.name,
                    "action": "deleted stale (>1h old, card still draft)",
                    "detail": f"age_h={age/3600:.1f}",
                })
            except OSError:
                pass
    return out


# NOTE: There was a R8 MT5 auto-restart handler here. Removed 2026-05-17 —
# MT5 is launched TRANSIENTLY by run_smoke.ps1 per backtest, NOT as a
# persistent service. Auto-restarting idle terminal64.exe processes was
# pure RAM waste. The real fix lives in dispatch_work_items: detect when
# a work_item is "active" but its run_smoke.ps1 child has died, and reset
# it to pending immediately. R5_dead_terminal handles that.


def repair_stranded_codex_review_pending(con) -> list[dict]:
    """R7: codex_review status='pending' but no live_log activity in 30min →
    the spawn failed silently or codex crashed. Delete the task so pump
    re-spawns next cycle."""
    out = []
    rows = con.execute(
        "SELECT id, payload_json, updated_at FROM tasks WHERE kind='codex_review' AND status='pending'"
    ).fetchall()
    for r in rows:
        try:
            t = dt.datetime.fromisoformat(r["updated_at"].replace("Z", "+00:00"))
            age_sec = (dt.datetime.now(dt.timezone.utc) - t).total_seconds()
        except Exception:
            continue
        if age_sec < 1800:  # < 30 min — give it time
            continue
        log_path = LOG_DIR / f"codex_review_{r['id']}.live.log"
        if log_path.exists():
            try:
                if time.time() - log_path.stat().st_mtime < 600:  # active < 10 min
                    continue
            except OSError:
                pass
        # Stranded — delete so pump re-creates
        payload = json.loads(r["payload_json"])
        vp = payload.get("verdict_path")
        if vp and os.path.exists(vp) and os.path.getsize(vp) == 0:
            try: os.remove(vp)
            except OSError: pass
        con.execute("DELETE FROM tasks WHERE id=?", (r["id"],))
        out.append({
            "handler": "R7_stranded_codex_review",
            "target": r["id"],
            "action": "deleted pending codex_review task",
            "detail": f"age_min={age_sec/60:.0f} build_task_id={payload.get('build_task_id','?')[:8]!r}",
        })
    if out:
        con.commit()
    return out


# ---------------------------------------------------------------------------

def run_all() -> dict:
    """Run all repair handlers. Returns summary + per-handler counts."""
    started_at = _utc_now()
    con = _connect()
    all_repairs: list[dict] = []
    errors: list[dict] = []
    handlers = [
        repair_stranded_active_sources,
        repair_phantom_codex_review_fails,
        repair_grandchildren_setfiles,
        repair_stale_active_work_items,
        repair_stranded_codex_review_pending,
        repair_orphan_g0_claims,
        repair_permanent_build_failures,
    ]
    try:
        for fn in handlers:
            try:
                fixes = fn(con)
                all_repairs.extend(fixes)
            except Exception as exc:
                errors.append({"handler": fn.__name__, "error": repr(exc)})
    finally:
        con.close()

    summary = {
        "started_at": started_at,
        "finished_at": _utc_now(),
        "repairs_applied": len(all_repairs),
        "by_handler": {},
        "errors": errors,
    }
    for r in all_repairs:
        h = r["handler"]
        summary["by_handler"][h] = summary["by_handler"].get(h, 0) + 1
    return {"summary": summary, "repairs": all_repairs, "errors": errors}
