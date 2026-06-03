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

  R11 Pending work_items whose setfile/EA dir/.ex5 is missing → mark
      failed INVALID immediately, without waiting for a terminal slot.

  R12 Incomplete P2 parent fanout with only one pending symbol while the EA
      has a full canonical setfile set → add the missing pending symbols.

  R13 Historical codex_review_fail caused only by build-smoke framework
      infra errors after a successful compile → clear the stale review and
      return the build to done for fresh review/P2 handling.

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
import uuid
from pathlib import Path

import farmctl

ROOT = Path(r"D:\QM\strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
LOG_DIR = ROOT / "logs"
REPORTS_DIR = ROOT / "reports"
QUEUE_DIR = ROOT / "queue"
REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_DIR = REPO_ROOT / "framework" / "registry"


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
        # Check live_log freshness for this worker's research session
        fresh = False
        if worker:
            pattern = (f"codex_research_{r['id']}.live.log" if worker == "codex"
                       else f"claude_research_{r['id']}.live.log")
            log_path = LOG_DIR / pattern
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
            "detail": f"worker={worker or 'unassigned'} title={r['title'][:60]!r} (no live_log activity)",
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
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
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


def _pending_work_item_artifact_failure(row: sqlite3.Row) -> dict | None:
    setfile_path = Path(str(row["setfile_path"] or ""))
    if not setfile_path.exists():
        return {"reason": "setfile_missing", "detail": str(setfile_path)}

    ea_id = str(row["ea_id"] or "")
    ea_root = REPO_ROOT / "framework" / "EAs"
    ea_dir_from_setfile = farmctl._ea_dir_from_setfile_path(setfile_path, ea_id)
    candidates = (
        [ea_dir_from_setfile]
        if ea_dir_from_setfile is not None
        else sorted(p for p in ea_root.glob(f"{ea_id}_*") if p.is_dir())
    )
    if not candidates:
        return {"reason": "ea_dir_missing", "detail": str(ea_root / f"{ea_id}_*")}
    if len(candidates) > 1:
        return {"reason": "ea_dir_ambiguous", "detail": [p.name for p in candidates]}

    ea_dir = candidates[0]
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    if not ex5.exists():
        return {"reason": "ex5_missing", "detail": str(ex5)}
    return None


def repair_pending_unclaimable_work_items(con) -> list[dict]:
    """R11: fail pending work_items that can never run because artifacts are missing."""
    out = []
    rows = con.execute(
        """
        SELECT id, ea_id, symbol, phase, setfile_path, payload_json
        FROM work_items
        WHERE status='pending'
        """
    ).fetchall()
    now = _utc_now()
    for r in rows:
        failure = _pending_work_item_artifact_failure(r)
        if not failure:
            continue

        report_root = ROOT / "reports" / "work_items" / str(r["id"])
        evidence_dir = report_root / str(r["ea_id"]) / str(r["phase"])
        evidence_dir.mkdir(parents=True, exist_ok=True)
        evidence_path = evidence_dir / "preflight_failure.json"
        try:
            payload = json.loads(r["payload_json"] or "{}")
        except Exception:
            payload = {}
        payload.update({
            "preflight_failed_at": now,
            "preflight_failure": failure,
            "report_root": str(report_root),
            "verdict_reason": failure.get("reason") or "preflight_failed",
            "repair_handler": "R11_pending_unclaimable_work_item",
        })
        evidence = {
            "created_at": now,
            "detail": failure.get("detail"),
            "ea_id": r["ea_id"],
            "phase": r["phase"],
            "reason": failure.get("reason") or "preflight_failed",
            "setfile_path": r["setfile_path"],
            "symbol": r["symbol"],
            "verdict": "INVALID",
        }
        evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        con.execute(
            """
            UPDATE work_items
            SET status='failed', verdict='INVALID', evidence_path=?,
                claimed_by=NULL, payload_json=?, updated_at=?
            WHERE id=?
            """,
            (str(evidence_path), json.dumps(payload, sort_keys=True), now, r["id"]),
        )
        out.append({
            "handler": "R11_pending_unclaimable_work_item",
            "target": r["id"],
            "action": "pending → failed INVALID",
            "detail": f"ea={r['ea_id']} sym={r['symbol']} reason={failure.get('reason')}",
        })
    if out:
        con.commit()
    return out


def _ea_dir_for_id(ea_id: str) -> Path | None:
    return farmctl._preferred_ea_dir(ea_id)


def _canonical_setfiles_for_ea(ea_id: str) -> list[tuple[str, str]]:
    ea_dir = _ea_dir_for_id(ea_id)
    if not ea_dir:
        return []
    if not (ea_dir / f"{ea_dir.name}.ex5").exists():
        return []
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return []

    pattern = re.compile(rf"^{re.escape(ea_dir.name)}_(?P<symbol>.+?)_(?P<period>[A-Z0-9]+)_backtest\.set$")
    out: list[tuple[str, str]] = []
    for path in sorted(sets_dir.glob("*.set")):
        name = path.name
        if any(token in name for token in ("_ablation_", "_grid_", "_synth_", "_freq_")):
            continue
        m = pattern.match(name)
        if m:
            out.append((m.group("symbol"), str(path.resolve())))
    return out


def repair_incomplete_p2_parent_fanout(con) -> list[dict]:
    """R12: expand old one-symbol P2 parent tasks to their full canonical setfile set."""
    out = []
    parents = con.execute(
        """
        SELECT parent_task_id, ea_id, COUNT(*) row_count, COUNT(DISTINCT symbol) symbol_count
        FROM work_items
        WHERE status='pending' AND phase='P2' AND parent_task_id IS NOT NULL
        GROUP BY parent_task_id, ea_id
        HAVING symbol_count=1
        """
    ).fetchall()
    now = _utc_now()
    for parent in parents:
        ea_id = str(parent["ea_id"] or "")
        parent_task_id = str(parent["parent_task_id"] or "")
        setfiles = _canonical_setfiles_for_ea(ea_id)
        if len(setfiles) <= int(parent["row_count"] or 0):
            continue
        # Guard against exploration-heavy parents; R12 is only for canonical full-fanout gaps.
        if len(setfiles) > 60:
            continue

        existing_symbols = {
            row["symbol"]
            for row in con.execute(
                "SELECT symbol FROM work_items WHERE parent_task_id=? AND phase='P2'",
                (parent_task_id,),
            ).fetchall()
        }
        sample = con.execute(
            "SELECT payload_json FROM work_items WHERE parent_task_id=? AND phase='P2' LIMIT 1",
            (parent_task_id,),
        ).fetchone()
        payload = sample["payload_json"] if sample else "{}"
        created = 0
        for symbol, setfile_path in setfiles:
            if symbol in existing_symbols:
                continue
            wid = str(uuid.uuid4())
            con.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status,
                   attempt_count, parent_task_id, payload_json, created_at, updated_at)
                VALUES
                  (?, 'backtest', 'P2', ?, ?, ?, 'pending',
                   0, ?, ?, ?, ?)
                """,
                (wid, ea_id, symbol, setfile_path, parent_task_id, payload, now, now),
            )
            created += 1
        if created:
            out.append({
                "handler": "R12_incomplete_p2_parent_fanout",
                "target": parent_task_id,
                "action": f"created {created} pending P2 work_items",
                "detail": f"ea={ea_id} canonical_setfiles={len(setfiles)}",
            })
    if out:
        con.commit()
    return out


def _latest_codex_reviews_for_build(con, build_id: str) -> list[sqlite3.Row]:
    return con.execute(
        """
        SELECT id, payload_json, updated_at
        FROM tasks
        WHERE kind='codex_review'
          AND payload_json LIKE ?
        ORDER BY updated_at DESC
        """,
        (f'%"build_task_id": "{build_id}"%',),
    ).fetchall()


def _review_findings(payload: dict) -> list[str]:
    findings = payload.get("findings") or []
    if not findings:
        verdict = payload.get("verdict") or {}
        if isinstance(verdict, dict):
            findings = verdict.get("findings") or verdict.get("issues") or []
    if isinstance(findings, str):
        return [findings]
    return [str(item) for item in findings]


def _infra_only_codex_review_findings(findings: list[str]) -> bool:
    if not findings:
        return False
    infra_markers = (
        "framework_error",
        "report_missing",
        "metatester_hung",
        "incomplete_runs",
        "model4_marker_required",
        "run_smoke",
        "resolve-dispatchterminal",
        "setfilepath",
        "terminal already running",
        "tester produced no",
        "stale ",
        "smoke report path is null",
    )
    code_markers = (
        "itime timestamp",
        "qm_isnewbar",
        "magic_numbers.csv",
        "raw indicator",
        "qm_indicator",
        "0 trades",
        "min_trades_not_met",
        "zero trades",
        "entrysignal",
        "exitsignal",
    )
    for finding in findings:
        text = finding.lower()
        if any(marker in text for marker in code_markers):
            return False
        if not any(marker in text for marker in infra_markers):
            return False
    return True


def repair_infra_only_codex_review_failures(con) -> list[dict]:
    """R13: undo stale Codex review failures caused only by old build-smoke infra errors."""
    out = []
    rows = con.execute(
        """
        SELECT id, card_id, payload_json
        FROM tasks
        WHERE kind='build_ea' AND status='blocked'
          AND payload_json LIKE '%"blocked_reason": "codex_review_fail"%'
        """
    ).fetchall()
    now = _utc_now()
    for r in rows:
        try:
            payload = json.loads(r["payload_json"] or "{}")
        except Exception:
            continue
        build_result_path = payload.get("build_result_path")
        if not build_result_path:
            continue
        br_path = Path(build_result_path)
        if not br_path.exists():
            continue
        try:
            build_result = json.loads(br_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if build_result.get("compile_succeeded") is not True:
            continue
        blocked = str(build_result.get("blocked_reason") or "")
        smoke = str(build_result.get("smoke_result") or "")
        if "framework_error" not in (blocked + " " + smoke).lower():
            continue

        reviews = _latest_codex_reviews_for_build(con, r["id"])
        if not reviews:
            continue
        parsed_reviews: list[tuple[sqlite3.Row, dict, list[str]]] = []
        for review in reviews:
            try:
                review_payload = json.loads(review["payload_json"] or "{}")
            except Exception:
                review_payload = {}
            findings = _review_findings(review_payload)
            parsed_reviews.append((review, review_payload, findings))
        latest_findings = parsed_reviews[0][2]
        if not _infra_only_codex_review_findings(latest_findings):
            continue

        build_result["build_smoke_framework_error"] = blocked
        build_result["blocked_reason"] = ""
        build_result["smoke_result"] = "deferred_p2_smoke"
        build_result["smoke_skipped_reason"] = "historical_framework_error_treated_as_deferred_p2_smoke"
        br_path.write_text(json.dumps(build_result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

        payload["needs_p2_smoke_via_pump"] = True
        payload["smoke_skipped_reason"] = "historical_framework_error_treated_as_deferred_p2_smoke"
        payload["infra_only_codex_review_repaired_at"] = now
        payload["infra_only_codex_review_findings"] = latest_findings
        payload.pop("blocked_reason", None)
        payload.pop("codex_review_findings", None)

        con.execute(
            "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(payload, sort_keys=True), now, r["id"]),
        )
        for review, _review_payload, _findings in parsed_reviews:
            con.execute("DELETE FROM tasks WHERE id=?", (review["id"],))
        out.append({
            "handler": "R13_infra_only_codex_review_failure",
            "target": r["id"],
            "action": f"blocked → done; deleted {len(parsed_reviews)} stale codex_review row(s)",
            "detail": f"ea={r['card_id']} findings={len(latest_findings)}",
        })
    if out:
        con.commit()
    return out


def repair_strategy_farm_gc(con) -> list[dict]:
    """R14: bounded farm garbage collection for old logs/prompts/tmp files."""
    del con
    out: list[dict] = []
    now = time.time()
    seven_days = 7 * 24 * 60 * 60
    one_day = 24 * 60 * 60

    def remove_old_files(root: Path, pattern: str, max_age_sec: int, handler: str) -> None:
        if not root.exists():
            return
        try:
            candidates = list(root.rglob(pattern))
        except OSError:
            return
        removed = 0
        bytes_removed = 0
        for path in candidates:
            try:
                resolved = path.resolve()
                root_resolved = root.resolve()
                if resolved == root_resolved or root_resolved not in resolved.parents:
                    continue
                if not path.is_file():
                    continue
                stat = path.stat()
                if now - stat.st_mtime < max_age_sec:
                    continue
                bytes_removed += stat.st_size
                path.unlink()
                removed += 1
            except OSError:
                continue
        if removed:
            out.append({
                "handler": handler,
                "target": str(root),
                "action": f"deleted {removed} stale file(s)",
                "detail": f"pattern={pattern} bytes_removed={bytes_removed}",
            })

    remove_old_files(LOG_DIR, "*", seven_days, "R14_gc_old_logs")
    remove_old_files(REPORTS_DIR, "*", seven_days, "R14_gc_old_reports")
    remove_old_files(QUEUE_DIR, "*.md", seven_days, "R14_gc_stale_queue_prompts")
    remove_old_files(REGISTRY_DIR, "ea_id_registry.csv.*.tmp", one_day, "R14_gc_orphan_registry_tmp")
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
        repair_pending_unclaimable_work_items,
        repair_incomplete_p2_parent_fanout,
        repair_infra_only_codex_review_failures,
        repair_strategy_farm_gc,
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
