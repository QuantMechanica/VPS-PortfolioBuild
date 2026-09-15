"""Stale-task disposition — classifier + GATED dry-run applier (§18 backlog hygiene).

Follow-up directive §18 asks for a disposition of the stale ``agent_tasks``
backlog (the 326 TODO / 73 BLOCKED rows at 2026-09-15) WITHOUT the auditor
writing the farm DB. This tool separates the two safely:

  * ``--classify --out plan.csv``  — READ-ONLY. Deterministically classifies
    every TODO + BLOCKED row into one of {COMMISSION, PARK, CLOSE, KEEP} from
    ``task_type`` + ``verdict`` + ``payload`` + age + priority, and writes the
    plan CSV. No DB write. This is what the auditor runs to produce the plan.

  * ``--plan plan.csv``           — DRY-RUN (default). Prints the exact
    ``agent_router.py`` command each row WOULD run. No DB write.

  * ``--plan plan.csv --apply``   — the ORCHESTRATOR runs this. Executes each
    row's disposition through the sanctioned ``agent_router.py`` verbs
    (``update-task`` for state moves). Mutations require the canonical router
    checkout (agent_router enforces this), so ``--apply`` must be run from
    ``C:/QM/repo`` — never a worktree.

Safety rails (never relaxed by this tool):
  * ``build_ea`` rows are candidate-pool members. A PARK/CLOSE of a build_ea row
    is skipped UNLESS ``--allow-candidate-park`` is passed explicitly — the
    orchestrator/OWNER opts in per run, so a candidate build is never silently
    parked or failed. CLOSE of a build_ea additionally requires
    ``--allow-candidate-close`` (a stricter, separate opt-in), because moving a
    candidate to a terminal state touches the candidate universe (ROT).
  * CLOSE/PARK use ``update-task`` which APPENDS a verdict; it never deletes an
    existing verdict or trade stream.
  * The tool only ever calls ``agent_router.py``; it opens the DB read-only for
    classification and never writes the DB itself.

CSV columns: ``id,state,task_type,priority,created_age_days,disposition,
target_lane,target_state,reason``.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
DB_DEFAULT = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
ROUTER = REPO_ROOT / "tools" / "strategy_farm" / "agent_router.py"

DISPOSITIONS = {"COMMISSION", "PARK", "CLOSE", "KEEP"}
SUPERSEDED_KEYWORDS = ("way to 25", "way-to-25", "way_to_25", "drain doctrine",
                       "drain-first", "global drain", "drain before book")


def _connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def _parse_ts(value: Any) -> dt.datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        p = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return p if p.tzinfo else p.replace(tzinfo=dt.timezone.utc)


def _required_skills(row: sqlite3.Row) -> list[str]:
    try:
        return list(json.loads(row["required_skills_json"] or "[]"))
    except (ValueError, TypeError):
        return []


def classify_row(row: sqlite3.Row, *, now: dt.datetime) -> dict[str, Any]:
    """Deterministic single-row classification. Returns the plan record."""
    state = row["state"]
    ttype = row["task_type"]
    priority = row["priority"] or 0
    created = _parse_ts(row["created_at"])
    age_days = (now - created).days if created else None
    blob = ((row["payload_json"] or "") + " " + (row["verdict"] or "")).lower()
    skills = _required_skills(row)

    disposition = "KEEP"
    target_lane = ""
    target_state = ""
    reason = "recent/active or no rule matched -> keep"

    # 1) Explicit directive-superseded doctrine (CBE abolished Way-to-25 + global drain).
    if any(k in blob for k in SUPERSEDED_KEYWORDS):
        disposition, target_state = "CLOSE", "FAILED"
        reason = "superseded_by_CBE: Way-to-25 / global-drain doctrine abolished (OWNER-DEC-CBE-20260915)"

    # 2) Video-analysis skill -> OWNER human lane hold.
    elif "video_analysis" in skills:
        disposition, target_state = "PARK", "BLOCKED"
        target_lane = "owner"
        reason = "awaiting_human_lane:owner (video_analysis; agy has no video tool)"

    # 3) review_ea head-blocks the lane; review closure is Claude's exclusive duty.
    elif ttype == "review_ea":
        disposition, target_lane = "COMMISSION", "claude"
        reason = "review_ea head-blocks the agent lane; commission to Claude (review closure duty)"

    # 4) build_ea candidate rows.
    elif ttype == "build_ea":
        if "owner-retire" in blob or "owner_retire" in blob:
            disposition, target_state = "CLOSE", "FAILED"
            reason = "owner_retired_ea_id (executes a prior OWNER retirement; candidate-guard applies)"
        elif state == "BLOCKED" and "precondition_hold" in blob:
            disposition, target_state = "PARK", "BLOCKED"
            reason = "awaiting_magic_registry_allocation (ordered ops precondition; not a CBE supersession)"
        elif state == "TODO" and (age_days or 0) > 30 and priority < 50:
            disposition, target_state = "PARK", "BLOCKED"
            reason = ("legacy_build_backlog_pre_CBE: volume-era build (age>30d, prio<50); "
                      "CBE trigger is a qualified pool, not build volume -> OWNER cohort decision")
        else:
            reason = "recent or prioritised build -> keep in queue"

    # 5) ops / triage backlog.
    elif ttype in ("ops_issue", "triage_failure"):
        if "owner_decision_execution" in skills:
            disposition, target_state = "PARK", "BLOCKED"
            target_lane = "owner"
            reason = "awaiting OWNER decision execution (decision-bound)"
        elif (age_days or 0) > 30:
            disposition, target_state = "PARK", "BLOCKED"
            reason = "aged_ops_backlog (age>30d) -> park for explicit re-triage"
        else:
            disposition, target_lane = "COMMISSION", "codex"
            reason = "active ops/triage -> commission to codex (ops+code)"

    # 6) research backlog (research is throttled unless the ready-card reservoir < 5).
    elif ttype == "research_strategy":
        if (age_days or 0) > 30:
            disposition, target_state = "PARK", "BLOCKED"
            reason = "research_throttled: aged research row; research created only when reservoir<5"
        else:
            disposition, target_lane = "COMMISSION", "gemini"
            reason = "active research -> commission to gemini (agy research lane)"

    return {
        "id": row["id"],
        "state": state,
        "task_type": ttype,
        "priority": priority,
        "created_age_days": age_days if age_days is not None else "",
        "disposition": disposition,
        "target_lane": target_lane,
        "target_state": target_state,
        "reason": reason,
    }


def classify_all(db: Path, *, now: dt.datetime | None = None) -> list[dict[str, Any]]:
    now = now or dt.datetime.now(dt.timezone.utc)
    conn = _connect_ro(db)
    try:
        rows = list(conn.execute(
            "SELECT id,task_type,state,priority,required_capabilities_json,"
            "required_skills_json,payload_json,verdict,created_at,updated_at "
            "FROM agent_tasks WHERE state IN ('TODO','BLOCKED') "
            "ORDER BY state, task_type, created_at"))
    finally:
        conn.close()
    return [classify_row(r, now=now) for r in rows]


def write_plan_csv(records: list[dict[str, Any]], out: Path) -> None:
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    cols = ["id", "state", "task_type", "priority", "created_age_days",
            "disposition", "target_lane", "target_state", "reason"]
    with out.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for rec in records:
            w.writerow(rec)


def _router_command(rec: dict[str, Any]) -> list[str] | None:
    """The agent_router.py argv a disposition maps to (None for KEEP)."""
    disp = rec["disposition"]
    tid = rec["id"]
    reason = rec["reason"]
    if disp == "KEEP":
        return None
    if disp == "CLOSE":
        return [sys.executable, str(ROUTER), "update-task", tid,
                "--state", rec.get("target_state") or "FAILED",
                "--verdict", f"SUPERSEDED_CBE_DISPOSITION: {reason}"]
    if disp == "PARK":
        return [sys.executable, str(ROUTER), "update-task", tid,
                "--state", rec.get("target_state") or "BLOCKED",
                "--verdict", f"PARK ({rec.get('target_lane') or 'n/a'}): {reason}"]
    if disp == "COMMISSION":
        # Keep the row routable (TODO) and annotate the intended lane; the router
        # then routes it by capability. update-task cannot assign a lane, so the
        # annotation documents intent without bypassing the router.
        return [sys.executable, str(ROUTER), "update-task", tid,
                "--state", "TODO",
                "--verdict", f"COMMISSIONED->{rec.get('target_lane') or 'router'}: {reason}"]
    return None


def _is_candidate_skip(rec: dict[str, Any], *, allow_park: bool, allow_close: bool) -> str | None:
    if rec["task_type"] != "build_ea":
        return None
    if rec["disposition"] == "PARK" and not allow_park:
        return "build_ea PARK requires --allow-candidate-park"
    if rec["disposition"] == "CLOSE" and not allow_close:
        return "build_ea CLOSE requires --allow-candidate-close"
    return None


def run_plan(plan: Path, *, apply: bool, allow_park: bool, allow_close: bool,
             limit: int | None = None) -> dict[str, Any]:
    with Path(plan).open(encoding="utf-8", newline="") as fh:
        records = list(csv.DictReader(fh))
    summary = {"total": len(records), "by_disposition": {}, "executed": 0,
               "skipped_candidate_guard": 0, "keep": 0, "refused": 0, "actions": []}
    done = 0
    for rec in records:
        disp = rec.get("disposition", "KEEP")
        summary["by_disposition"][disp] = summary["by_disposition"].get(disp, 0) + 1
        if disp == "KEEP":
            summary["keep"] += 1
            continue
        guard = _is_candidate_skip(rec, allow_park=allow_park, allow_close=allow_close)
        if guard:
            summary["skipped_candidate_guard"] += 1
            summary["actions"].append({"id": rec["id"], "action": "SKIP", "why": guard})
            continue
        cmd = _router_command(rec)
        if not cmd:
            continue
        if limit is not None and done >= limit:
            summary["actions"].append({"id": rec["id"], "action": "LIMIT_STOP"})
            break
        printable = [c for c in cmd]
        if not apply:
            summary["actions"].append({"id": rec["id"], "action": "DRY_RUN", "cmd": printable})
            done += 1
            continue
        proc = subprocess.run(cmd, capture_output=True, text=True)
        ok = proc.returncode == 0
        summary["executed"] += 0 if not ok else 1
        if not ok:
            summary["refused"] += 1
        summary["actions"].append({
            "id": rec["id"], "action": "APPLIED" if ok else "REFUSED",
            "returncode": proc.returncode, "stdout_tail": proc.stdout[-300:],
        })
        done += 1
    return summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB_DEFAULT, help="farm_state.sqlite (read-only)")
    parser.add_argument("--classify", action="store_true",
                        help="classify TODO+BLOCKED rows and write --out plan CSV (read-only)")
    parser.add_argument("--out", type=Path, help="plan CSV path for --classify")
    parser.add_argument("--plan", type=Path, help="plan CSV to apply / dry-run")
    parser.add_argument("--apply", action="store_true",
                        help="EXECUTE the plan via agent_router.py (orchestrator, from C:/QM/repo)")
    parser.add_argument("--allow-candidate-park", action="store_true",
                        help="permit PARK of build_ea candidate rows")
    parser.add_argument("--allow-candidate-close", action="store_true",
                        help="permit CLOSE of build_ea candidate rows")
    parser.add_argument("--limit", type=int, default=None, help="cap actions this run")
    args = parser.parse_args(argv)

    if args.classify:
        if not args.out:
            parser.error("--classify requires --out")
        records = classify_all(args.db)
        write_plan_csv(records, args.out)
        counts: dict[str, int] = {}
        for rec in records:
            counts[rec["disposition"]] = counts.get(rec["disposition"], 0) + 1
        print(json.dumps({"classified": len(records), "by_disposition": counts,
                          "out": str(args.out)}, indent=2, sort_keys=True))
        return 0

    if args.plan:
        summary = run_plan(args.plan, apply=args.apply,
                           allow_park=args.allow_candidate_park,
                           allow_close=args.allow_candidate_close, limit=args.limit)
        # keep the console readable: drop the per-action list unless small
        head = {k: v for k, v in summary.items() if k != "actions"}
        head["mode"] = "APPLY" if args.apply else "DRY_RUN"
        print(json.dumps(head, indent=2, sort_keys=True))
        if not args.apply:
            for a in summary["actions"][:20]:
                print("  DRY", a.get("id"), a.get("action"),
                      (a.get("cmd") or a.get("why") or ""))
        return 0

    parser.error("pass --classify --out <csv>, or --plan <csv> [--apply]")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
