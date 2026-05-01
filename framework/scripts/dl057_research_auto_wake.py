#!/usr/bin/env python3
"""DL-057 enforcement — Research auto-wake pulse.

Polls Paperclip API for the conditions defined in DL-057 R-057-1:
    - ≥1 EA in P0/P1/P2 (baseline queue) state
    - ≥1 matrix mid-run on T1-T5
    - ≥1 Strategy Card in unresolved G0 review
Research is paused while ANY of those is true. Resumes when ALL are false.

When all-three-false flips on, this script wakes Research with a comment on
its rolling tracker (or creates the rolling tracker if absent). When still-
paused, it does NOTHING (silent — DL-046 anti-theater).

Designed to run as a 15-minute scheduled task. Idempotent: writes a state
file under D:/QM/reports/ops/dl057_research_pulse_state.json so it doesn't
re-wake Research on every tick.

Usage:
    python dl057_research_auto_wake.py
        # standard run, posts wake-comment if conditions are met
    python dl057_research_auto_wake.py --dry-run
        # logs what it would do without posting

Authority: DL-057, OWNER directive 2026-05-01.
Companion: paperclip-prompts/research.md (Research's BASIS).
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------

PAPERCLIP_BASE = "http://127.0.0.1:3100"
COMPANY_ID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
RESEARCH_AGENT_ID = "7aef7a17-d010-4f6e-a198-4a8dc5deb40d"

# Phases that count as "baseline queue" — Research stays paused while any of
# these are active. Per DL-057 R-057-1.
BASELINE_QUEUE_PHASES = ("P0", "P1", "P2")

# Statuses that count as "active" for queue purposes.
ACTIVE_STATUSES = ("todo", "in_progress", "in_review")

STATE_FILE = Path(r"D:\QM\reports\ops\dl057_research_pulse_state.json")
LOG_FILE = Path(r"D:\QM\reports\ops\dl057_research_pulse.log")


# -------------------------------------------------------------------------
# Paperclip API helpers
# -------------------------------------------------------------------------


def http_get_json(path: str, timeout: float = 10.0) -> object:
    url = f"{PAPERCLIP_BASE}{path}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_post_json(path: str, body: dict, timeout: float = 10.0) -> object:
    url = f"{PAPERCLIP_BASE}{path}"
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def list_company_issues() -> list[dict]:
    """Return all issues for the company (one page; Paperclip returns big lists)."""
    res = http_get_json(f"/api/companies/{COMPANY_ID}/issues?limit=500")
    if isinstance(res, list):
        return res
    if isinstance(res, dict):
        return res.get("items", res.get("issues", []))
    return []


# -------------------------------------------------------------------------
# DL-057 condition checks
# -------------------------------------------------------------------------


def title_phase(issue: dict) -> str | None:
    """Heuristic: extract phase token from title.

    Pipeline-Op convention: titles include 'P0', 'P1', 'P2', etc. as words.
    """
    title = (issue.get("title") or "").upper()
    for phase in ("P0", "P1", "P2", "P3.5", "P3", "P4", "P5B", "P5C", "P5", "P6", "P7", "P8", "P9B", "P9", "P10"):
        if f" {phase} " in f" {title} " or f"_{phase}_" in title or f" {phase}:" in title:
            return phase
    return None


def is_baseline_queue_active(issues: list[dict]) -> tuple[bool, list[dict]]:
    matches = []
    for issue in issues:
        if str(issue.get("status", "")).lower() not in ACTIVE_STATUSES:
            continue
        phase = title_phase(issue)
        if phase in BASELINE_QUEUE_PHASES:
            matches.append(issue)
    return bool(matches), matches


def is_g0_review_unresolved(issues: list[dict]) -> tuple[bool, list[dict]]:
    """Strategy Card G0 review not yet resolved.

    Heuristic: title contains 'G0' or 'Strategy Card' AND status in {in_progress,
    in_review, todo} AND title implies review (not just creation).
    """
    matches = []
    for issue in issues:
        if str(issue.get("status", "")).lower() not in ACTIVE_STATUSES:
            continue
        title = (issue.get("title") or "").upper()
        is_g0 = " G0 " in f" {title} " or "G0/" in title or " G0:" in title
        is_card = "STRATEGY CARD" in title or "STRATEGY-CARD" in title or "_S0" in title
        is_review = "REVIEW" in title or "VERDICT" in title or "G0" in title
        if (is_g0 or is_card) and is_review:
            matches.append(issue)
    return bool(matches), matches


# Entries older than this without a completion are zombies (stale state from
# crashed/abandoned runs — e.g. the QUA-662 invalidated loop).
ZOMBIE_AGE_SECONDS = 12 * 60 * 60  # 12h


def is_matrix_mid_run() -> tuple[bool, str]:
    """Pipeline-Op dispatch state. Read D:/QM/Reports/pipeline/dispatch_state.json.

    Returns True if any (ea_id, phase, symbol) row is genuinely in_flight (not
    yet released AND not stale-zombie). Entries older than ZOMBIE_AGE_SECONDS
    without a completion are ignored — they represent crashed/invalidated runs
    (e.g. the QUA-662 broken loop) that Pipeline-Op should clean up but might
    not have yet.
    """
    state_path = Path(r"D:\QM\Reports\pipeline\dispatch_state.json")
    if not state_path.exists():
        return False, "no dispatch_state.json"
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return False, f"unparseable: {exc}"
    dedup = state.get("dedup", {})
    now_epoch = int(time.time())
    in_flight = []
    zombies = []
    for key, rec in dedup.items():
        if str(rec.get("status", "")) in ("complete", "failed", "cancelled"):
            continue
        ts = int(rec.get("ts", 0))
        if ts > 0 and (now_epoch - ts) > ZOMBIE_AGE_SECONDS:
            zombies.append(key)
            continue
        in_flight.append(key)
    if in_flight:
        return True, f"{len(in_flight)} live in_flight ({len(zombies)} zombies ignored)"
    if zombies:
        return False, f"0 live in_flight ({len(zombies)} zombies — Pipeline-Op should prune)"
    return False, "0 rows in_flight"


# -------------------------------------------------------------------------
# Wake mechanism
# -------------------------------------------------------------------------


def find_research_rolling_tracker(issues: list[dict]) -> dict | None:
    """Find the existing Research rolling tracker issue (if any).

    Heuristic: assigneeAgentId == RESEARCH_AGENT_ID AND title contains 'rolling'.
    """
    for issue in issues:
        if issue.get("assigneeAgentId") != RESEARCH_AGENT_ID:
            continue
        title = (issue.get("title") or "").lower()
        if "rolling" in title or "tracker" in title or "extraction queue" in title:
            return issue
    return None


def wake_research(rolling_tracker: dict, snapshot: dict, *, dry_run: bool = False) -> dict:
    """Post a wake comment on Research's rolling tracker."""
    body = (
        "## Wake — DL-057 baseline queue empty\n\n"
        f"Per DL-057 R-057-1, all three pause conditions are now FALSE as of "
        f"{snapshot['ts_utc']}:\n\n"
        f"- baseline queue (P0/P1/P2) issues active: **0** ({snapshot['queue_active_count']} hits in last poll)\n"
        f"- matrix mid-run on T1-T5: **{snapshot['matrix_mid_run']}** ({snapshot.get('matrix_detail', '')})\n"
        f"- Strategy Card G0 review unresolved: **0** ({snapshot['g0_unresolved_count']} hits)\n\n"
        "Resume your work per DL-057 R-057-2:\n"
        "1. Extract ≤3 cards from the current SRC (continuing whichever SRC has open cards).\n"
        "2. Run dedup against `framework/registry/ea_id_registry.csv` + `framework/registry/magic_numbers.csv` "
        "+ existing strategy fingerprints (R-057-3).\n"
        "3. Hand to QB for G0 review per DL-030 Class 2.\n"
        "4. Exit after extraction. Do NOT loop into a second cycle in the same heartbeat.\n\n"
        "Single SRC at a time per DL-040; this is always 1 run per OWNER 2026-05-01.\n\n"
        f"— Auto-wake by `framework/scripts/dl057_research_auto_wake.py` (poll {snapshot['ts_utc']})"
    )
    if dry_run:
        return {"dry_run": True, "would_post": body[:300] + "..."}
    issue_id = rolling_tracker["id"]
    res = http_post_json(f"/api/issues/{issue_id}/comments", {"body": body})
    return res if isinstance(res, dict) else {"raw": str(res)}


# -------------------------------------------------------------------------
# State persistence
# -------------------------------------------------------------------------


def load_state() -> dict:
    if not STATE_FILE.exists():
        return {"last_woken_ts_utc": None, "last_pause_state": None, "last_run_ts_utc": None}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return {"last_woken_ts_utc": None, "last_pause_state": None, "last_run_ts_utc": None}


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")


def append_log(line: str) -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="dl057_research_auto_wake")
    p.add_argument("--dry-run", action="store_true", help="Log what would happen, don't post")
    args = p.parse_args(argv)

    now_iso = datetime.now(timezone.utc).isoformat()

    try:
        issues = list_company_issues()
    except urllib.error.URLError as exc:
        append_log(f"{now_iso}  ERROR  paperclip API unreachable: {exc}")
        return 1
    except Exception as exc:  # noqa: BLE001
        append_log(f"{now_iso}  ERROR  list_company_issues: {exc}")
        return 1

    queue_active, queue_hits = is_baseline_queue_active(issues)
    g0_unresolved, g0_hits = is_g0_review_unresolved(issues)
    matrix_active, matrix_detail = is_matrix_mid_run()

    snapshot = {
        "ts_utc": now_iso,
        "queue_active_count": len(queue_hits),
        "queue_active_titles": [i.get("title", "")[:60] for i in queue_hits[:3]],
        "g0_unresolved_count": len(g0_hits),
        "g0_unresolved_titles": [i.get("title", "")[:60] for i in g0_hits[:3]],
        "matrix_mid_run": matrix_active,
        "matrix_detail": matrix_detail,
    }

    state = load_state()
    state["last_run_ts_utc"] = now_iso

    is_paused = queue_active or g0_unresolved or matrix_active
    state["last_pause_state"] = "PAUSED" if is_paused else "RESUMABLE"

    if is_paused:
        append_log(
            f"{now_iso}  PAUSED  queue={len(queue_hits)} g0={len(g0_hits)} matrix={matrix_active} "
            f"(detail={matrix_detail})"
        )
        save_state(state)
        return 0

    # All three pause conditions are FALSE → check whether to wake.
    last_woken = state.get("last_woken_ts_utc")
    if last_woken:
        # Don't re-wake within 1 hour of last wake (prevent spam if Research
        # processes in <1h between scheduled-task ticks).
        try:
            last_woken_dt = datetime.fromisoformat(last_woken.replace("Z", "+00:00"))
            elapsed_s = (datetime.now(timezone.utc) - last_woken_dt).total_seconds()
            if elapsed_s < 3600:
                append_log(
                    f"{now_iso}  RESUMABLE_RECENT_WAKE  last_woken={last_woken} "
                    f"({int(elapsed_s)}s ago, < 1h cooldown)"
                )
                save_state(state)
                return 0
        except Exception:  # noqa: BLE001
            pass

    rolling_tracker = find_research_rolling_tracker(issues)
    if rolling_tracker is None:
        append_log(
            f"{now_iso}  RESUMABLE_NO_TRACKER  Research has no rolling tracker issue; "
            f"manual: create one assigned to {RESEARCH_AGENT_ID} with 'rolling tracker' in title"
        )
        save_state(state)
        return 0

    wake_res = wake_research(rolling_tracker, snapshot, dry_run=args.dry_run)
    if args.dry_run:
        append_log(f"{now_iso}  DRY_RUN_WAKE  on issue {rolling_tracker.get('identifier')}")
    else:
        append_log(
            f"{now_iso}  WOKE_RESEARCH  issue={rolling_tracker.get('identifier')} "
            f"comment_id={wake_res.get('id', 'unknown')}"
        )
        state["last_woken_ts_utc"] = now_iso
    save_state(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
