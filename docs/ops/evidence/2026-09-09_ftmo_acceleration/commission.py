"""Commission the delegated FTMO acceleration work via the canonical router.

Explicit invocation only. Idempotent per program/workstream. Does not run workers,
write work_items, touch terminals, change trading or send messages to people.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO))
from tools.strategy_farm import agent_router
from tools.strategy_farm.sqlite_busy import retry_sqlite_busy

PROGRAM = "FTMO_ACCELERATION_20260909"
ROOT = Path("D:/QM/strategy_farm")
DECISION = "decisions/2026-09-09_ftmo_acceleration_delegated.md"
INTAKE = "docs/ops/evidence/2026-09-09_ftmo_acceleration/intake.json"
COMMON = {
    "program_id": PROGRAM,
    "authority_evidence": str(REPO / DECISION),
    "requested_by": "Codex operating decision under OWNER direct delegation, 2026-09-09",
    "delivery_target_utc": "2026-09-12T22:00:00Z",
    "program_path": str(REPO / "docs/ops/FTMO_ACCELERATION_2026-09-09.md"),
    "input_snapshot": str(REPO / INTAKE),
    "hard_limits": [
        "External spend zero. No account purchase, order submission, AutoTrading toggle, T_Live or FTMO-demo deployment changes.",
        "No change to empirical thresholds, existing verdicts, R5 population or 25-pair guarded-builder prerequisite. Pilot preparation is not a builder bypass.",
        "Do not open sealed holdout results before a new prospective plan is sealed. Previously exposed diagnostics remain exploratory.",
        "Existing running tasks are not interrupted. Reuse predecessor work; do not duplicate downloads, calendar repair, or work_items.",
        "Finish a concrete reviewable artifact, implementation and applicable tests. Missing inputs must have an exact source/gap and executable next action; do not invent costs or probabilities.",
        "Scope is repository work and isolated governed tests only. New trading identities require full applicable requalification; never inherit old evidence across changed trading code.",
    ],
}

TASKS = [
    {
        "workstream": "admission",
        "priority": 99,
        "agent": "codex",
        "parent_id": None,
        "title": "FTMO acceleration A: current-contract admission and a bounded FTMO-target qualification path for the existing qualified pool",
        "summary": (
            "The frozen intake contains 16 contiguous-Q14 pairs. After the bounded NEWS-phase reader repair, "
            "12 return SCOPE_NOT_FTMO, 3 EVIDENCE_MISSING, 1 NOT_CONFIG_LOCKED; zero are admitted. "
            "Review the phase repair in portfolio/ftmo_q09_admission.py (27 tests passed); then inspect "
            "current Q09_NEWS_V3 versus V2 semantics, aggregate hashes, occurrence view, inert seed fanout "
            "and current binary/calendar identities. Deliver an executable dry-run planner for target-FTMO "
            "qualification of at most five selected incumbents, reusing exact admissible evidence. "
            "A DXZ single-column lock cannot be relabelled FTMO. Do not manufacture more seeds or re-run "
            "obsolete matrices. The prospective shortlist from B is required before any selected native "
            "qualification batch is enqueued; deliver planner and tests now without waiting for B. "
            "Implement compatibility repairs only with version-bound equivalence/negative tests; unsupported "
            "contracts fail explicitly. Do not auto-promote candidates or change the normal book guard."
        ),
        "acceptance": [
            "Per-pair current-contract/identity/calendar matrix with reason codes and remaining target-specific test cost.",
            "Planner dry-run is deterministic, deduplicates existing rows and uses active phase names and exact artifact bindings.",
            "Tests cover historical/current phase coexistence, latest-result precedence, V2/V3 seed semantics, missing FTMO coverage and tampered evidence.",
            "Report explicitly separates source compatibility, news admission, cost eligibility and deployment eligibility.",
        ],
    },
    {
        "workstream": "cost_shortlist",
        "priority": 98,
        "agent": "codex",
        "parent_id": "0cb1153d-e55d-4912-b2f1-4092a37eed93",
        "title": "FTMO acceleration B: measured cost closure and an exposed-data shortlist of at most five incumbents",
        "summary": (
            "Extend accepted M08 using the frozen 16-pair intake. Inspect every candidate with available "
            "exposed evidence; select zero to five for a prospective pilot using normalized net expectancy, "
            "drawdown, trading frequency, holding costs and correlation, never raw dollar-PnL ranking. "
            "Initial investigation candidates from published cost coverage are 10706/GBPUSD, 11421/EURUSD, "
            "11422/USDCAD and 13054/XTIUSD; these are not an approved roster. 1537/XAGUSD has negative "
            "historical projected PnL before spread in the Sept-5 snapshot and requires explicit cost triage. "
            "Read the Sept-6 terminal snapshot/account terms: actual account is Standard and native oil "
            "triple-rollover day differs from the old generic Wednesday assumption. Bind exact current "
            "lot/tick/contract/margin/swap data read-only from the already-running demo or existing native "
            "receipts; realized commissions only from broker deals. Do not start or reconfigure terminals. "
            "Use overlapping same-instrument/timezone/point-normalized FTMO and reference observations; "
            "obtain only shortlist data through existing governed export/backfill facilities, reusing "
            "3032534e/f6d18a6e rather than waiting for or duplicating a 37-symbol backfill. Unknown spread "
            "or slippage remains explicit; publish cost break-even sensitivity when a full net score is "
            "not yet supportable. No sealed OOS is opened, no live portfolio is changed."
        ),
        "acceptance": [
            "Reproducible per-pair normalized comparison with selection/exclusion reasons, evidence identity and exposed-data labels.",
            "Versioned cost evidence with native units, clock binding, source freshness, realized-versus-provisional classification and measured gaps.",
            "A zero-to-five prospective roster proposal with shared-risk/correlation assessment, not an FTMO approval claim.",
            "Document exactly which small data acquisition is still required; historical multi-year projection is not a forward-return forecast.",
        ],
    },
    {
        "workstream": "execution",
        "priority": 97,
        "agent": "codex",
        "parent_id": "7cc4ab4c-ae16-4eb7-9409-4ce5ff179d77",
        "title": "FTMO acceleration C: isolated governor and shared-risk integration canary, starting with the 11421 execution-contract gap",
        "summary": (
            "Reassess M09-B against delivered Sept-6 collector and the current demo; its original absent-collector "
            "blocker is stale. Read the Sept-8 FTMO Governance Nachqualifikation analysis in the company vault. "
            "Specify and implement an isolated, versioned FTMO execution path for 11421 preserving its strategy "
            "mechanics. Bind the governor heartbeat/entry lock/risk scaling and atomic shared stop-risk "
            "reservation; provide lifecycle handling for existing pending orders and positions, news changes, "
            "Friday/session closure, restart and missing ticks. Use existing framework mechanisms. Test "
            "negative cases from M01-M12 in that analysis and produce source/binary/set/include-closure "
            "bindings with a requalification plan. Compile/test only through approved isolated factory "
            "mechanisms and existing registry/G0 authority; no ad-hoc ID allocation or deployment. "
            "Do not modify the running demo/T_Live or declare current old-binary evidence valid for the "
            "changed execution path. Complete the reusable canary before touching other candidates."
        ),
        "acceptance": [
            "A concrete isolated implementation and an exact changed-behavior/requalification manifest.",
            "Native tests for stale/torn/missing governor state, concurrent last-budget reservation, pending cancellation, restart/day anchor and close/delete failure.",
            "Exposure-reducing operations remain executable on a halt; failures and broker acknowledgement are observable.",
            "No runtime deployment changes; clearly distinguish source tests, native test evidence and still-unperformed qualification.",
        ],
    },
    {
        "workstream": "economics",
        "priority": 96,
        "agent": "claude",
        "parent_id": "1bf87710-04c7-4cbc-b342-0bc0d660a5fd",
        "title": "FTMO acceleration D: first-reward economic pilot contract and decision, separate from R5 certification",
        "summary": (
            "Implement the delegated operating decision, not another generic permission request. Prepare a "
            "bounded zero-fee prospective pilot contract now; integrate A/B/C results before sealing. "
            "Fix the account variant (actual capture account is Standard), selected roster <=5, risk "
            "budget, cost/execution versions, observation cap, data-quality criteria, operational stop "
            "rules and one predeclared evaluation point. Existing capture-only data are exploratory and "
            "cannot be recycled as confirmation. Distinguish operational evidence from edge inference. "
            "Model cash received through first reward: provider payout plus fee refund minus all attempt "
            "fees and marginal costs; separate P1, conditional P2 and reward probabilities, dependencies, "
            "failure/retry and time-to-payout. Browse official current FTMO terms for sourced model inputs. "
            "Provide a break-even sensitivity frontier where probabilities are unknown; do not convert "
            "an illustrative R5 5.75-year sample calculation into a mandatory wait for free research. "
            "R5 and the paid purchase gate remain separate; no statistical threshold waiver or invented "
            "success probability. Final disposition PROCEED_WITH_FREE_PILOT / CONTINUE_EVIDENCE / REJECT, "
            "with concrete reasons and the next executable step. Missing A/B/C outputs do not prevent "
            "building the model and draft contract now, but do prevent sealing or a ready claim."
        ),
        "acceptance": [
            "A reproducible economics model and scenario table with source provenance and no hidden assumed success rate.",
            "A prospective contract with exact numerical operating choices explicitly labelled internal policy, grounded by B/C evidence before sealing.",
            "A bounded first-reward decision with risk/time/cost uncertainty, next action and a finite review point.",
            "No altered R5 verdict, purchase, live deployment or retrospective confirmation.",
        ],
    },
]


def main() -> None:
    if sys.argv[1:] != ["--apply"]:
        print(json.dumps(TASKS, indent=2, ensure_ascii=False))
        return
    receipt_path = Path(__file__).with_name("commission_receipt.json")
    if receipt_path.exists():
        raise SystemExit("Receipt already exists; verify it rather than recommissioning")
    receipts = []
    for task in TASKS:
        with sqlite3.connect(f"file:{(ROOT / 'state/farm_state.sqlite').as_posix()}?mode=ro", uri=True) as conn:
            matches = []
            for task_id, state, raw in conn.execute("SELECT id,state,payload_json FROM agent_tasks WHERE payload_json LIKE ?", (f"%{PROGRAM}%",)):
                p = json.loads(raw)
                if p.get("program_id") == PROGRAM and p.get("workstream") == task["workstream"]:
                    matches.append({"task_id": task_id, "state": state, "reused": True})
        if len(matches) > 1:
            raise RuntimeError(f"Duplicate workstream: {task['workstream']}")
        if matches:
            result = matches[0]
        else:
            payload = {**COMMON, **{k: task[k] for k in ("workstream", "title", "summary", "acceptance")}}
            result = retry_sqlite_busy(lambda: agent_router.enqueue_task(
                ROOT, "ops_issue", priority=task["priority"],
                parent_id=task["parent_id"], payload=payload, assigned_agent=task["agent"],
            ), attempts=16)
        receipts.append({**result, "workstream": task["workstream"], "priority": task["priority"], "lane": task["agent"]})
        print(json.dumps(receipts[-1]), flush=True)
    with receipt_path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump({"program_id": PROGRAM, "commissioned_at_utc": datetime.now(timezone.utc).isoformat(), "tasks": receipts}, handle, indent=2)
        handle.write("\n")
    print(json.dumps(receipts, ensure_ascii=False))


if __name__ == "__main__":
    main()
