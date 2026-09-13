"""Apply the OOS-2026 window re-enqueue (Orchestrator 2026-09-13).

Thin GOVERNED wrapper over ``oos_2026_confirmation repair-oos-window``.  Dry-run
by default; nothing is written unless ``--apply`` is passed.

What ``--apply`` does (all via the tested campaign tool, one mutation-lock
transaction, pre-mutation state backup, CAS-guarded, receipt written only after
the commit):

  * PATCHES the 37 pending rows held under OOS_WINDOW_MISMATCH: writes the 2026
    campaign window (2026.01.01..2026.04.06, from campaign_plan.json
    full_from_utc/full_to_utc) into their payloads and RELEASES the
    OOS_WINDOW_MISMATCH hold (append-only ledger + event rows; work_items.status
    unchanged).  These rows never ran (no verdict), so patching the unclaimed
    pending payload IS the append-only-equivalent re-enqueue.
  * MINTS 15 append-only successors for the done rows that measured 2024, each
    with the 2026 window, and records a work_item_supersedes edge
    (source_encoding=repair:oos-2026-window/v1).  The historical rows are left
    intact.
  * LEAVES the 3 NEWS_CALENDAR_TAINTED rows untouched (window already correct,
    no OOS_WINDOW_MISMATCH hold) -- out of scope for the window re-enqueue.

Window binding: the CAMPAIGN CONTRACT, not a setfile.  farmctl's spawn builder
never set from_date/to_date for single-symbol NEWS rows (root cause of the 2024
fallback); repair-oos-window injects the payload window from the plan and stamps
the campaign_plan sha that the spawn re-verifies.

The 15 done rows need NO separate retire2 disposition: their wrong-lane/2024
evidence was already adjudicated INVALID_EVIDENCE (append-only ADJUDICATION_
RECEIPT rows) by the q09-news-review-lane-closure on 2026-09-13T16:01Z; this tool
only adds the corrected reruns.

DOWNSTREAM BLOCKERS this repair does NOT clear (see README.md):
  1. NEWS_LANE_MISMATCH -- the 37 patched rows and 15 successors stay on the
     historical Q09_NEWS lane; the NEWS runner binds Q10_NEWS only, so
     farmctl._news_lane_spawn_refusal refuses them (pending_runner, never
     run_smoke).  A separate Q09_NEWS->Q10_NEWS lane migration is required
     before the cohort can execute.  report-misphased-rows lists all 40.
  2. NEWS_CALENDAR_TIMESTAMP_DEFECT -- the standing containment rule re-holds
     new Q09_NEWS/Q10_NEWS rows until E1 (tester-branch DST calendar repair).
     As of 2026-09-13 the defect is still contained; a correctly-windowed,
     correctly-laned row would still wait for E1.

Usage:
    python -X utf8 tools/strategy_farm/session_tools/apply_oos_2026_reenqueue_0913.py            # dry-run (default)
    python -X utf8 tools/strategy_farm/session_tools/apply_oos_2026_reenqueue_0913.py --apply    # write
    ... --apply --work-item-id <id> [--work-item-id <id> ...]                                     # scope to named rows
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO))  # make `tools.strategy_farm` importable
from tools.strategy_farm import oos_2026_confirmation as oos  # noqa: E402

DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
MUTATION_LOCK = Path("D:/QM/strategy_farm/state/FACTORY_MUTATION.lock")
FARM_ROOT = Path("D:/QM/strategy_farm")
CAMPAIGN_PLAN = Path("D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json")
EVID = REPO / "docs/ops/evidence/2026-09-13_oos_2026_reenqueue"

BLOCKERS = (
    "\nDOWNSTREAM BLOCKERS (NOT cleared by this window repair):\n"
    "  1. NEWS_LANE_MISMATCH: rows stay on historical Q09_NEWS; active lane is\n"
    "     Q10_NEWS. farmctl._news_lane_spawn_refusal refuses them (pending_runner).\n"
    "     A separate Q09_NEWS->Q10_NEWS lane migration is required to execute.\n"
    "  2. NEWS_CALENDAR_TIMESTAMP_DEFECT: standing containment re-holds new\n"
    "     Q09_NEWS/Q10_NEWS rows until E1 (tester-branch DST calendar repair).\n"
)


def _summary(result: dict) -> dict:
    return {
        "mode": result.get("mode"),
        "window": result.get("window"),
        "counts": result.get("counts"),
        "patched_work_items": result.get("patched_work_items"),
        "released_holds": result.get("released_holds"),
        "minted_successors": result.get("minted_successors"),
        "state_backup": result.get("state_backup"),
        "receipt_path": result.get("receipt_path"),
    }


def _receipt_path(wids: tuple[str, ...] | None) -> Path:
    if wids:
        tag = wids[0] if len(wids) == 1 else f"scoped_{len(wids)}"
        return EVID / f"repair_receipt_{tag}.json"
    return EVID / "repair_receipt.json"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true",
                    help="REQUIRED to write. Without it this is a read-only dry run.")
    ap.add_argument("--work-item-id", action="append", dest="work_item_ids", default=None,
                    help="scope the repair to this exact campaign work item (repeatable, fail-closed)")
    args = ap.parse_args()
    wids = tuple(args.work_item_ids or ()) or None

    if not args.apply:
        plan = oos.plan_oos_window_repair(DB, campaign_plan_path=CAMPAIGN_PLAN, work_item_ids=wids)
        print(json.dumps({k: plan[k] for k in ("mode", "window", "campaign_plan_sha256", "counts")}, indent=2))
        print(BLOCKERS)
        print("DRY-RUN only (default). Nothing was written. Re-run with --apply to write.")
        return 0

    out = _receipt_path(wids)
    if out.exists():
        print(f"refusing to overwrite existing receipt: {out}")
        return 1
    result = oos.apply_oos_window_repair(
        DB, MUTATION_LOCK, out,
        campaign_plan_path=CAMPAIGN_PLAN, farm_root=FARM_ROOT, work_item_ids=wids,
    )
    print(json.dumps(_summary(result), indent=2, default=str))
    print(BLOCKERS)
    print(f"APPLIED. Receipt: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
