"""Compact operational digest for the 15-minute orchestrator heartbeat.

The heartbeat costs model tokens every time it fires, so the measuring is done here,
deterministically and read-only, and the model only judges what the FLAGS line surfaces.
A quiet cycle should be readable in a few hundred tokens.

Design rules:
  * strictly read-only -- opens the farm DB with mode=ro, never writes to it;
  * never raises: every probe is guarded, a broken probe reports itself as a flag;
  * delta-aware -- persists its own state so "nothing changed" is distinguishable from
    "everything is fine", which are very different operational situations;
  * every flag names the measured number, because a flag without a number cannot be
    triaged without re-measuring.

Usage:  python tools/strategy_farm/heartbeat_snapshot.py [--json]
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO = Path(r"C:\QM\repo")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
STATE = Path(r"D:/QM/reports/state/heartbeat_state.json")
QUOTA = Path(r"D:/QM/reports/state/quota_governor_state.json")
FLAG_DIR = Path(r"D:/QM/strategy_farm/state")
SYMBOL_LIST_GENERATOR = REPO / "tools" / "vault" / "gen_symbol_list_page.py"

# A task claimed but silent for longer than this is stuck, not working.
STUCK_IN_PROGRESS_H = 3
# The agent lane is head-blocked if REVIEW is this deep with nothing routable.
REVIEW_BACKLOG_ALERT = 15
# Completions per hour below this, with a deep queue, means the factory is not working.
THROUGHPUT_FLOOR = 1


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.replace(microsecond=0).isoformat()


def guarded(fn):
    """Probe wrapper: a failing probe becomes a finding, never an exception."""
    def inner(out, *a, **kw):
        try:
            return fn(out, *a, **kw)
        except Exception as exc:  # noqa: BLE001 - a heartbeat must not die on one probe
            out["flags"].append(f"PROBE_FAILED:{fn.__name__}:{type(exc).__name__}")
        return None
    return inner


@guarded
def probe_quota(out):
    """Spend posture per agent. Drives how much work may be dispatched this cycle."""
    data = json.loads(QUOTA.read_text(encoding="utf-8"))
    agents = {}
    for name, a in (data.get("agents") or {}).items():
        used, elapsed = a.get("used_pct"), a.get("elapsed_pct")
        agents[name] = {
            "used_pct": used,
            "elapsed_pct": elapsed,
            "projected_eow_pct": a.get("projected_eow_pct"),
            "five_hour_used_pct": a.get("five_hour_used_pct"),
            "action": a.get("action"),
            "why": a.get("why"),
        }
        # Ahead of linear pace by more than 10 points, or projected to blow the week.
        if isinstance(used, (int, float)) and isinstance(elapsed, (int, float)):
            if used - elapsed > 10:
                out["flags"].append(f"QUOTA_AHEAD_OF_PACE:{name}:used={used}%:elapsed={elapsed}%")
        proj = a.get("projected_eow_pct")
        if isinstance(proj, (int, float)) and proj > 100:
            out["flags"].append(f"QUOTA_PROJECTED_OVER:{name}:{proj}%")
        fh = a.get("five_hour_used_pct")
        if isinstance(fh, (int, float)) and fh > 80:
            out["flags"].append(f"QUOTA_5H_HIGH:{name}:{fh}%")
    out["quota"] = agents
    out["quota_as_of"] = data.get("ts")

    flags = sorted(p.name for p in FLAG_DIR.glob("*.flag")) if FLAG_DIR.exists() else []
    flags += sorted(p.name for p in Path(r"D:/QM/reports/state").glob("*.flag"))
    if flags:
        out["throttle_flags"] = flags
        for f in flags:
            if "LOW_TOKENS" in f or "DISABLED" in f or "LOW_QUOTA" in f:
                out["flags"].append(f"THROTTLE_FLAG:{f}")


@guarded
def probe_factory(out, conn):
    """Throughput and queue depth -- the primary saturation metric."""
    since = _iso(_now() - timedelta(hours=1))
    done_1h = conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='done' AND updated_at >= ?", (since,)
    ).fetchone()[0]
    active = conn.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0]
    pending = conn.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
    out["factory"] = {"done_1h": done_1h, "active": active, "pending": pending}

    if pending > 50 and active == 0:
        out["flags"].append(f"FACTORY_IDLE_WITH_QUEUE:active=0:pending={pending}")
    elif pending > 50 and done_1h < THROUGHPUT_FLOOR:
        out["flags"].append(f"FACTORY_THROUGHPUT_LOW:done_1h={done_1h}:pending={pending}:active={active}")

    # Verdicts in the last hour, so a sudden INFRA wave is visible as it happens.
    rows = conn.execute(
        "SELECT verdict, COUNT(*) FROM work_items WHERE status IN ('done','failed') "
        "AND updated_at >= ? GROUP BY verdict ORDER BY 2 DESC", (since,)
    ).fetchall()
    verdicts = {str(v or "NULL"): n for v, n in rows}
    out["verdicts_1h"] = verdicts
    total = sum(verdicts.values())
    infra = sum(n for v, n in verdicts.items() if "INFRA" in v or "INVALID" in v)
    if total >= 5 and infra / total > 0.5:
        out["flags"].append(f"INFRA_WAVE:{infra}/{total}_last_hour")


@guarded
def probe_agent_lane(out, conn):
    """The lane that went silently idle for three days on 2026-08-21."""
    states = dict(conn.execute("SELECT state, COUNT(*) FROM agent_tasks GROUP BY state").fetchall())
    routable = states.get("TODO", 0) + states.get("BACKLOG", 0)
    review = states.get("REVIEW", 0)
    in_progress = states.get("IN_PROGRESS", 0)
    out["agent_tasks"] = states

    if review >= REVIEW_BACKLOG_ALERT:
        out["flags"].append(f"REVIEW_BACKLOG:{review}_awaiting_claude")
    if routable == 0 and review > 0:
        out["flags"].append(f"LANE_HEADBLOCKED:routable=0:review={review}")

    # Claimed but silent: the signature of a dead worker holding a ticket.
    cutoff = _iso(_now() - timedelta(hours=STUCK_IN_PROGRESS_H))
    stuck = conn.execute(
        "SELECT id, task_type, assigned_agent, updated_at FROM agent_tasks "
        "WHERE state='IN_PROGRESS' AND updated_at < ? ORDER BY updated_at LIMIT 8", (cutoff,)
    ).fetchall()
    if stuck:
        out["stuck_in_progress"] = [
            {"id": r[0][:8], "type": r[1], "agent": r[2], "since": (r[3] or "")[:16]} for r in stuck
        ]
        out["flags"].append(f"TASKS_STUCK_IN_PROGRESS:{len(stuck)}:oldest={(stuck[0][3] or '')[:16]}")
    out["in_progress"] = in_progress

    # What is waiting to be picked up, so routing decisions have their input.
    todo = conn.execute(
        "SELECT id, task_type, priority, assigned_agent, created_at FROM agent_tasks "
        "WHERE state IN ('TODO','BACKLOG') ORDER BY priority DESC, created_at LIMIT 10"
    ).fetchall()
    out["queued"] = [
        {"id": r[0][:8], "type": r[1], "prio": r[2], "agent": r[3], "created": (r[4] or "")[:16]}
        for r in todo
    ]


@guarded
def probe_goal(out, conn):
    """Distance to the actual objective: survivors that could reach a book."""
    def n(sql, *a):
        return conn.execute(sql, a).fetchone()[0]

    out["funnel"] = {
        "Q10_PASS": n("SELECT COUNT(DISTINCT ea_id||symbol) FROM work_items "
                      "WHERE phase='Q10' AND verdict LIKE 'PASS%'"),
        "Q14_rows": n("SELECT COUNT(*) FROM work_items WHERE phase='Q14'"),
        "Q09_NEWS_pending": n("SELECT COUNT(*) FROM work_items "
                              "WHERE phase='Q09_NEWS' AND status='pending'"),
        "pass_soft_q06": n("SELECT COUNT(*) FROM work_items "
                           "WHERE phase='Q06' AND verdict='PASS_SOFT'"),
    }


@guarded
def probe_health(out):
    """farmctl health, reduced to what changed and what is failing."""
    proc = subprocess.run(
        [sys.executable, str(REPO / "tools" / "strategy_farm" / "farmctl.py"), "health"],
        capture_output=True, text=True, cwd=str(REPO), timeout=180,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )
    data = json.loads(proc.stdout)
    fails, warns = [], []
    for c in data.get("checks", []):
        entry = f"{c.get('name')}={c.get('value')}"
        if c.get("status") == "FAIL":
            fails.append(entry)
        elif c.get("status") == "WARN":
            warns.append(entry)
    out["health"] = {"fail": fails, "warn": warns}


@guarded
def probe_scheduled_tasks(out):
    """The recurring jobs ARE the operation. A job that fails silently is invisible work lost.

    Reports only tasks whose last result is neither success nor "currently running"
    (267009 = 0x41301), and only if the task is enabled -- a disabled leftover is not an
    incident. Known-expected failures are carried in EXPECTED so a real regression stands out.
    """
    # Failures that are understood and tracked elsewhere; listed so they do not drown the signal.
    EXPECTED = {
        "QM_Public_Snapshot_Hourly": "publication guard fail-closed behind the QM5_20172 hold (CEO-MP-#7)",
        "QM_StrategyFarm_MailboxSourceIntake_Daily": "non-zero RC while extraction succeeds; postconditions are authoritative",
    }
    # SYSTEM/service tasks whose MultipleInstancesPolicy=IgnoreNew and
    # ExecutionTimeLimit >> cadence make an occasional 0x800710E0 (2147946720,
    # "operator/administrator refused the request") an expected benign overlap-
    # refusal: the prior still-running instance is doing the work. This is
    # code-scoped (only 0x800710E0), NOT name-scoped -- any OTHER non-zero code on
    # these tasks (e.g. 267014 killed@time-limit) is still a real failure and must
    # surface (MNT-003, 2026-08-21; see docs/ops/evidence/2026-08-21_mnt003_*.md).
    BENIGN_IGNORENEW_OVERLAP = {
        "QM_StrategyFarm_Pump_5min",
        "QM_StrategyFarm_CodexOrchestration_15min",
        "QM_StrategyFarm_ClaudeOrchestration_15min",
        "QM_StrategyFarm_GeminiOrchestration_15min",
        "QM_StrategyFarm_Dashboard_Hourly",
    }
    ps = (
        "Get-ScheduledTask | Where-Object {$_.TaskName -like 'QM*' -and $_.State -ne 'Disabled'} | "
        "ForEach-Object { $i = $_ | Get-ScheduledTaskInfo; "
        "[pscustomobject]@{n=$_.TaskName; rc=$i.LastTaskResult; last=$i.LastRunTime} } | "
        "ConvertTo-Json -Compress"
    )
    proc = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps],
        capture_output=True, text=True, timeout=120,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )
    rows = json.loads(proc.stdout or "[]")
    if isinstance(rows, dict):
        rows = [rows]
    bad, expected_bad = [], []
    for r in rows:
        rc = r.get("rc")
        if rc in (0, 267009, None):  # 267009 = still running
            continue
        name = r.get("n")
        if rc == 2147946720 and name in BENIGN_IGNORENEW_OVERLAP:
            expected_bad.append(f"{name}:rc={rc}")  # MNT-003 benign IgnoreNew overlap
            continue
        (expected_bad if name in EXPECTED else bad).append(f"{name}:rc={rc}")
    out["tasks_failing"] = bad
    out["tasks_failing_expected"] = expected_bad
    if bad:
        out["flags"].append(f"SCHEDULED_TASK_FAILING:{len(bad)}:{bad[0]}")


@guarded
def probe_source_lane(out):
    """The front of the funnel. It starves quietly: nothing breaks, nothing arrives."""
    leads = Path(r"D:/QM/reports/sourcing_intake/leads.csv")
    if not leads.exists():
        out["flags"].append("SOURCE_LANE_NO_LEADS_FILE")
        return
    import csv as _csv
    with leads.open(encoding="utf-8", newline="") as fh:
        rows = list(_csv.DictReader(fh))
    status = [str(r.get("status") or "") for r in rows]
    new = sum(1 for s in status if s == "NEW")
    qualified = sum(1 for s in status if s.startswith("QUALIFIED"))
    rejected = sum(1 for s in status if s.startswith("REJECTED"))
    deferred = sum(1 for s in status if s.startswith("DEFERRED"))
    out["source_lane"] = {
        "leads_total": len(rows), "NEW": new, "QUALIFIED": qualified,
        "REJECTED": rejected, "DEFERRED": deferred,
        "leads_mtime": datetime.fromtimestamp(leads.stat().st_mtime, timezone.utc).isoformat()[:16],
    }
    adjudicated = qualified + rejected + deferred
    # The intake can be perfectly healthy and still deliver nothing: that is an INPUT-quality
    # problem, not a plumbing problem, and the two need different fixes.
    if adjudicated >= 20 and qualified == 0:
        out["flags"].append(f"SOURCE_YIELD_ZERO:{qualified}/{adjudicated}_qualified")
    age_h = (_now() - datetime.fromtimestamp(leads.stat().st_mtime, timezone.utc)).total_seconds() / 3600
    if age_h > 26:  # runs twice daily; more than a day of silence is a stall
        out["flags"].append(f"SOURCE_LANE_STALE:{age_h:.0f}h_since_last_lead_write")


def deltas(out, prev):
    """Only changes are worth a model's attention."""
    d = {}
    if not prev:
        d["first_run"] = True
        return d
    pf, cf = prev.get("factory", {}), out.get("factory", {})
    for k in ("done_1h", "active", "pending"):
        if k in pf and k in cf and pf[k] != cf[k]:
            d[k] = f"{pf[k]}->{cf[k]}"
    p_new = set(out.get("health", {}).get("fail", [])) - set(prev.get("health", {}).get("fail", []))
    p_gone = set(prev.get("health", {}).get("fail", [])) - set(out.get("health", {}).get("fail", []))
    if p_new:
        d["health_new_fail"] = sorted(p_new)
        out["flags"].append(f"HEALTH_NEW_FAIL:{len(p_new)}")
    if p_gone:
        d["health_recovered"] = sorted(p_gone)
    pa, ca = prev.get("agent_tasks", {}), out.get("agent_tasks", {})
    for k in set(pa) | set(ca):
        if pa.get(k, 0) != ca.get(k, 0):
            d[f"tasks_{k}"] = f"{pa.get(k, 0)}->{ca.get(k, 0)}"
    return d


ARTIFACT_MD = Path(r"D:/QM/reports/state/heartbeat.md")
# G: is Google Drive for Desktop -- a PER-USER mount. It exists for qm-admin (the account the
# proven Vault-writing tasks run under) and does NOT exist for SYSTEM. The write is therefore
# best-effort: D: always holds the truth, the Vault copy is the operator's window onto it.
VAULT_MD = Path(r"G:/My Drive/QuantMechanica - Company Reference/08 Current State/Heartbeat.md")
EVENTS = Path(r"D:/QM/reports/state/heartbeat_events.jsonl")
EVENT_RENDER_LIMIT = 25

# Flags that mean "the factory is not doing its job right now" rather than "worth a look".
CRITICAL = ("FACTORY_IDLE_WITH_QUEUE", "FACTORY_THROUGHPUT_LOW", "DB_UNREACHABLE",
            "LANE_HEADBLOCKED", "INFRA_WAVE")


def _flag_key(flag: str) -> str:
    """Flag identity without its measured value, so a moving number is not a new event."""
    return flag.split(":", 1)[0]


def record_events(out, prev):
    """Append only TRANSITIONS -- a flag that appears or clears. A flag that merely persists
    is not news, and a ledger that repeats it every 15 minutes buries the one that matters."""
    now_keys = {_flag_key(f): f for f in out.get("flags", [])}
    prev_keys = {_flag_key(f): f for f in (prev.get("flags") or [])}
    events = []
    for k, f in now_keys.items():
        if k not in prev_keys:
            events.append({"ts": out["ts"], "kind": "RAISED", "flag": f})
    for k, f in prev_keys.items():
        if k not in now_keys:
            events.append({"ts": out["ts"], "kind": "CLEARED", "flag": f})
    if not events:
        return []
    try:
        with EVENTS.open("a", encoding="utf-8") as fh:
            for e in events:
                fh.write(json.dumps(e) + "\n")
    except Exception as exc:  # noqa: BLE001
        out["flags"].append(f"EVENT_LOG_WRITE_FAILED:{type(exc).__name__}")
    return events


def render_markdown(out) -> str:
    """A page an operator can read in fifteen seconds, worst news first."""
    flags = out.get("flags", [])
    crit = [f for f in flags if _flag_key(f) in CRITICAL]
    verdict = "KRITISCH" if crit else ("AUFMERKSAMKEIT" if flags else "RUHIG")
    fa, at = out.get("factory", {}), out.get("agent_tasks", {})
    q, h = out.get("quota", {}), out.get("health", {})
    sl, fu = out.get("source_lane", {}), out.get("funnel", {})

    L = []
    L.append("# Heartbeat — Fabrik & Agenten")
    L.append("")
    L.append(f"> **{verdict}** · gemessen {out.get('ts', '?')} UTC · alle 15 Minuten von")
    L.append("> `QM_Orchestrator_Heartbeat_15min`. Diese Seite wird **überschrieben** — sie zeigt")
    L.append("> immer den letzten Stand. Was sich geändert hat, steht unten im Ereignisprotokoll.")
    L.append("")
    if flags:
        L.append("## Auffälligkeiten")
        L.append("")
        for f in flags:
            L.append(f"- {'**' + f + '**' if _flag_key(f) in CRITICAL else f}")
        L.append("")
    else:
        L.append("Keine Auffälligkeiten. Alle Prüfungen im erwarteten Bereich.")
        L.append("")

    L.append("## Kennzahlen")
    L.append("")
    L.append("| Bereich | Stand |")
    L.append("|---|---|")
    L.append(f"| Fabrik | {fa.get('done_1h')} Läufe/h · {fa.get('active')} aktiv · "
             f"{fa.get('pending')} in der Queue |")
    L.append(f"| Agenten-Tasks | " + " · ".join(f"{k} {v}" for k, v in sorted(at.items())) + " |")
    for name, v in q.items():
        L.append(f"| Quote {name} | {v.get('used_pct')} % verbraucht bei {v.get('elapsed_pct')} % "
                 f"Wochenzeit · Hochrechnung {v.get('projected_eow_pct')} % · {v.get('action')} |")
    L.append(f"| Health | {len(h.get('fail', []))} FAIL · {len(h.get('warn', []))} WARN |")
    if h.get("fail"):
        L.append(f"| Health-FAIL | {', '.join(h['fail'])} |")
    if sl:
        L.append(f"| Quellen-Zulauf | {sl.get('leads_total')} Leads · **{sl.get('QUALIFIED')} qualifiziert** "
                 f"· {sl.get('REJECTED')} abgelehnt · {sl.get('NEW')} offen |")
    L.append(f"| Trichter | Q10-PASS {fu.get('Q10_PASS')} · Q14 {fu.get('Q14_rows')} · "
             f"Q09_NEWS offen {fu.get('Q09_NEWS_pending')} · Q06 PASS_SOFT {fu.get('pass_soft_q06')} |")
    tf = out.get("tasks_failing") or []
    if tf:
        L.append(f"| Fehlschlagende Aufgaben | {', '.join(tf)} |")
    L.append("")

    if out.get("stuck_in_progress"):
        L.append("## Hängende Tickets")
        L.append("")
        for s in out["stuck_in_progress"]:
            L.append(f"- `{s['id']}` {s['type']} bei {s['agent']} — still seit {s['since']}")
        L.append("")

    L.append("## Ereignisprotokoll")
    L.append("")
    L.append("Nur Übergänge: eine Auffälligkeit, die auftaucht oder verschwindet. Eine, die")
    L.append("einfach bestehen bleibt, ist keine Neuigkeit.")
    L.append("")
    try:
        lines = EVENTS.read_text(encoding="utf-8").strip().splitlines()[-EVENT_RENDER_LIMIT:]
        if lines:
            L.append("| Zeit (UTC) | | Auffälligkeit |")
            L.append("|---|---|---|")
            for ln in reversed(lines):
                e = json.loads(ln)
                mark = "🔴 neu" if e["kind"] == "RAISED" else "🟢 weg"
                L.append(f"| {e['ts'][:16]} | {mark} | `{e['flag']}` |")
        else:
            L.append("*(noch keine Übergänge aufgezeichnet)*")
    except Exception:  # noqa: BLE001
        L.append("*(Ereignisprotokoll nicht lesbar)*")
    L.append("")
    L.append("---")
    L.append("")
    L.append("Rohdaten: `D:\\QM\\reports\\state\\heartbeat_state.json` · Protokoll:")
    L.append("`D:\\QM\\reports\\state\\heartbeat_events.jsonl` · Messung:")
    L.append("`tools/strategy_farm/heartbeat_snapshot.py`")
    L.append("")
    return "\n".join(L)


def sync_symbol_list_page(out) -> None:
    """Refresh the generated Vault symbol page from the canonical matrix.

    The heartbeat task runs as qm-admin, which owns the Google Drive mount.
    Failure is recorded in the durable heartbeat state but does not prevent the
    independent heartbeat page/state writes below.
    """
    try:
        proc = subprocess.run(
            [sys.executable, str(SYMBOL_LIST_GENERATOR), "--write"],
            capture_output=True,
            text=True,
            cwd=str(REPO),
            timeout=60,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        if proc.returncode != 0:
            raise RuntimeError(f"generator exit {proc.returncode}")
        out["symbol_list_mirror"] = "ok"
    except Exception as exc:  # noqa: BLE001 - heartbeat remains fail-soft on G: outages
        out["symbol_list_mirror"] = f"unavailable:{type(exc).__name__}"


def main() -> int:
    out = {"ts": _iso(_now()), "flags": []}
    probe_quota(out)
    probe_health(out)
    probe_scheduled_tasks(out)
    probe_source_lane(out)
    try:
        conn = sqlite3.connect(DB, uri=True, timeout=20)
        conn.execute("PRAGMA busy_timeout=15000")
        probe_factory(out, conn)
        probe_agent_lane(out, conn)
        probe_goal(out, conn)
        conn.close()
    except Exception as exc:  # noqa: BLE001
        out["flags"].append(f"DB_UNREACHABLE:{type(exc).__name__}")

    prev = {}
    try:
        prev = json.loads(STATE.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001 - first run, or a corrupted state file
        pass
    out["delta"] = deltas(out, prev)
    out["events"] = record_events(out, prev)

    sync_symbol_list_page(out)
    md = render_markdown(out)

    # Best-effort Vault mirror FIRST, so its outcome is part of the state we persist.
    # A missing G: is not an incident -- it means this run happened without the user mount
    # (e.g. as SYSTEM), and D: still carries the full result.
    try:
        VAULT_MD.parent.mkdir(parents=True, exist_ok=True)
        VAULT_MD.write_text(md, encoding="utf-8")
        out["vault_mirror"] = "ok"
    except Exception as exc:  # noqa: BLE001
        out["vault_mirror"] = f"unavailable:{type(exc).__name__}"

    try:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(out, indent=1), encoding="utf-8")
        ARTIFACT_MD.write_text(md, encoding="utf-8")
    except Exception as exc:  # noqa: BLE001
        out["flags"].append(f"STATE_WRITE_FAILED:{type(exc).__name__}")

    if "--json" in sys.argv:
        print(json.dumps(out, indent=1))
        return 0

    f = out["flags"]
    print(f"FLAGS: {' | '.join(f) if f else 'none'}")
    fa = out.get("factory", {})
    print(f"factory: done_1h={fa.get('done_1h')} active={fa.get('active')} pending={fa.get('pending')}")
    at = out.get("agent_tasks", {})
    print("tasks: " + " ".join(f"{k}={v}" for k, v in sorted(at.items())))
    q = out.get("quota", {})
    print("quota: " + " | ".join(
        f"{k} used={v.get('used_pct')}% pace={v.get('elapsed_pct')}% 5h={v.get('five_hour_used_pct')} {v.get('action')}"
        for k, v in q.items()))
    h = out.get("health", {})
    print(f"health FAIL({len(h.get('fail', []))}): {', '.join(h.get('fail', [])) or '-'}")
    print(f"funnel: {out.get('funnel')}")
    print(f"source_lane: {out.get('source_lane')}")
    tf = out.get("tasks_failing") or []
    print(f"tasks_failing({len(tf)}): {', '.join(tf) or '-'}"
          + (f"  [expected: {', '.join(out.get('tasks_failing_expected') or []) or '-'}]"))
    if out.get("delta"):
        print(f"delta: {json.dumps(out['delta'])}")
    if out.get("stuck_in_progress"):
        print(f"stuck: {json.dumps(out['stuck_in_progress'])}")
    if out.get("queued"):
        print(f"queued_top: {json.dumps(out['queued'][:5])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
