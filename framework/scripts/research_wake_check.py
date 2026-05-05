"""Research auto-wake heuristic — pulls active pipeline state from Paperclip and
resumes the Research agent if exactly one EA remains in testing (per OWNER directive
2026-05-05, memory: project_qm_research_wake_condition).

Wake condition: count EAs currently in pipeline (phase < P10) == 1.
The signal is "almost out of EAs to test" — order new research before queue empty.

Usage:
    python research_wake_check.py            # check + log
    python research_wake_check.py --execute  # also POST resume if condition met
    python research_wake_check.py --force    # resume regardless of count (OWNER use)

Loop integration: invoke from CoS heartbeat or add to a daily cron routine.
Idempotent: resume on already-running agent is a no-op (returns same status).
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

PAPERCLIP_API = "http://127.0.0.1:3100"
COMPANY_ID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
RESEARCH_AGENT_ID = "7aef7a17-d010-4f6e-a198-4a8dc5deb40d"

# Phase tokens we recognise as "still in pipeline" (not graduated).
# Per PIPELINE_PHASE_SPEC.md: G0..P10. P10 = live burn-in graduation point.
ACTIVE_PHASES = {"G0", "P1", "P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8", "P9", "P9b"}


def fetch_json(url: str) -> dict | list:
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:300]
        raise SystemExit(f"HTTP {e.code} on {url}: {body}")


def count_active_eas() -> tuple[int, list[str], dict]:
    """Return (count, ea_labels_in_pipeline, raw_diagnostics).

    Heuristic: scan active issues (todo + in_progress + in_review + blocked) for
    titles mentioning a QM5_NNNN EA + an active phase token. Group by EA label,
    count distinct EA labels with at least one active-phase issue.
    """
    issues_url = f"{PAPERCLIP_API}/api/companies/{COMPANY_ID}/issues?status=todo,in_progress,in_review,blocked"
    data = fetch_json(issues_url)
    issues = data if isinstance(data, list) else data.get("issues", data.get("data", []))

    ea_to_phases: dict[str, set[str]] = {}
    for i in issues:
        title = i.get("title", "")
        upper = title.upper()
        # Extract EA label from title (e.g. "QM5_1003" or "SRC04_S03")
        ea_label = None
        for token in title.split():
            t = token.strip(":,.()[]").upper()
            if t.startswith("QM5_") and len(t) > 4:
                ea_label = t.split("_BLOCK")[0].split(":")[0]
                break
        if not ea_label:
            continue
        # Match active-phase token in title
        for phase in ACTIVE_PHASES:
            if (
                f" {phase} " in f" {upper} "
                or f" {phase}—" in upper
                or f"({phase})" in upper
                or upper.endswith(f" {phase}")
                or f"PHASE={phase}" in upper.replace(" ", "")
            ):
                ea_to_phases.setdefault(ea_label, set()).add(phase)
                break

    in_pipeline = sorted(ea_to_phases.keys())
    return len(in_pipeline), in_pipeline, {"per_ea_phases": {ea: sorted(p) for ea, p in ea_to_phases.items()}, "total_issues_scanned": len(issues)}


def resume_research(reason: str) -> dict:
    """POST /api/agents/{id}/resume on loopback (no bearer; local_trusted mode)."""
    url = f"{PAPERCLIP_API}/api/agents/{RESEARCH_AGENT_ID}/resume"
    req = urllib.request.Request(url, method="POST", headers={"Content-Type": "application/json"})
    req.data = json.dumps({"resumeReason": reason}).encode("utf-8")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--execute", action="store_true", help="actually POST resume if condition met (default: check-only)")
    ap.add_argument("--force", action="store_true", help="POST resume regardless of count (OWNER override)")
    ap.add_argument("--threshold", type=int, default=1, help="EA count threshold for wake (default 1)")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of human")
    args = ap.parse_args()

    count, eas, diag = count_active_eas()
    ts = datetime.now(timezone.utc).isoformat()

    decision = "no_action"
    detail = f"count={count} EAs in pipeline; threshold={args.threshold}"
    resume_response = None

    if args.force:
        decision = "force_wake"
        if args.execute:
            resume_response = resume_research(f"OWNER force-wake at {ts} via research_wake_check.py")
            detail = f"forced wake regardless of count. resume_response={resume_response.get('status')}"
    elif count <= args.threshold:
        decision = "wake"
        if args.execute:
            resume_response = resume_research(f"auto-wake at {ts}: only {count} EA(s) left in pipeline (eas={eas})")
            detail = f"woke Research; resume_response={resume_response.get('status')}"
        else:
            detail = f"WOULD wake Research (--execute not set). count={count} eas={eas}"
    else:
        decision = "skip"
        detail = f"count={count} > threshold={args.threshold}; Research stays paused. eas={eas}"

    output = {
        "ts_utc": ts,
        "decision": decision,
        "ea_count": count,
        "eas_in_pipeline": eas,
        "threshold": args.threshold,
        "executed": args.execute,
        "resume_response": resume_response,
        "detail": detail,
        "diagnostics": diag,
    }
    if args.json:
        print(json.dumps(output, indent=2))
    else:
        print(f"[research_wake_check {ts}] decision={decision}")
        print(f"  EAs in pipeline ({count}): {eas}")
        print(f"  detail: {detail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
