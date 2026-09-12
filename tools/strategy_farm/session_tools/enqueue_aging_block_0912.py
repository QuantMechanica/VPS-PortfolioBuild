"""OWNER 2026-09-12 ~06:5xZ: after the Codex reset use Sol (Codex) and Opus/Sonnet for the open programming;
the whole Aging/Stranded health block must be resolved. Six tickets: prescreen re-issue (Model=1, successor of
ef55f2ff), Q09 autoseal holds, artifact binding drift, Q08 INVALID rate, Q02 stranded pairs, backup-gap ack."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
DEC = ("OWNER-DEC-PRESCREEN-OHLC-20260911 (T12 usable, 1-minute tests on all terminals for speed, successful EAs "
       "verified on real ticks). Binding invariant: real-tick Model=4 evidence stays the only class for verdicts, "
       "counter and book; OHLC-M1 = tester.ini Model=1 (NOT Model=2, which is open prices) is PRESCREEN only.")
HL = ["Never T_Live/FTMO; worker code Default-OFF, activated only by the orchestrator staggered reload; commit with "
      "explicit pathspecs (LF); RESULT line in docs/ops/OPEN_ITEMS_STATUS.md; every claim with a path; never "
      "overwrite verdict evidence; dry-run before any state change"]
REQ = ("Orchestrator Claude 2026-09-12 (OWNER: after the Codex reset use Sol and Opus/Sonnet for open programming; "
       "resolve the Aging/Stranded health block)")


def ticket(title, spec, acceptance, evidence, prio, tier="codex_high", ctier="sol", extra=None):
    payload = {"requested_by": REQ, "title": title, "spec": spec, "acceptance": acceptance, "evidence": evidence,
               "hard_limits": HL, "required_capabilities": ["code", "ops"], "model_tier": tier,
               "codex_model_tier": ctier, "codex_reasoning_effort": "high"}
    if extra:
        payload.update(extra)
    return prio, payload


TICKETS = [
    ticket("RE-ISSUE (successor of ef55f2ff, withhold justified): BUILD fleet OHLC-M1 pre-screen cell class with "
           "tester.ini Model=1 (1-minute OHLC; research_canary.MODEL_NAMES[1] == ohlc-m1): per-year OPT_CENSUS cells "
           "declared PRESCREEN (verdict taxonomy PRESCREEN_MEASURED, never MEASURED), governed promote step (real-tick "
           "Model=4 cells for the declared keep fraction plus a seeded 10 pct control sample of dropped arms), FN "
           "tracking with suspension above 10 pct, first program = config_sweep/window_sweep declarations",
           ["S1 cell class: declaration field prescreen_model=1; tester.ini rendering identical except Model; "
            "evidence_class=PRESCREEN in the summary; claim path identical (priority_track, queue owner)",
            "S2 promote --keep <fraction> --control 0.10 --apply (idempotent; ledger amendment with ranking snapshot sha)",
            "S3 FN tracking + suspend flag + report table",
            "S4 tests + dry run on the WINSWEEP_QM5_41405 declaration; no production enqueue (orchestrator step)"],
           ["prescreen cells enqueue/claim/measure through the normal worker after the orchestrator reload",
            "promote + control + FN report with tests", "PRESCREEN never appears as MEASURED (test)"],
           ["docs/ops/evidence/2026-09-11_fleet_ohlc_prescreen_build_review.md", "tools/strategy_farm/research_canary.py",
            "tools/strategy_farm/config_sweep.py", "docs/ops/evidence/2026-09-11_t11_prescreen_pilot_orch.md"],
           95, extra={"owner_decision": DEC, "predecessor_task": "ef55f2ff-2e3d-4d36-bc7f-3d6b0c0d1e34"}),
    ticket("Q09 sealed-plan holds: resolve the three grouped autoseal failure causes (Q09_AUTOSEAL_DERIVE_LINEAGE_FAILED "
           "16, Q09_AUTOSEAL_BIND_PLAN_FAILED 8, Q09_AUTOSEAL_VALIDATE_Q08_VINTAGE_FAILED 6) so the governed binder "
           "releases the 30 Q10_NEWS AWAITING_SEALED_PLAN holds (oldest 468 h: d81d9ea8 QM5_1556, 08fe4173 QM5_11476, "
           "84608819 QM5_12831)",
           ["S1 per cause: reproduce on the named ids, root cause with evidence paths (Q08-bound binary/setfile "
            "vintage, lineage derivation, plan binding)",
            "S2 fix the binder deterministically (author + hash-bind q09-news-run-plan/v2 where the vintage is valid); "
            "never release a hold by hand",
            "S3 tests; dry-run report of which holds would release; RESULT with counts"],
           ["cause table with ids", "binder releases holds through the ordinary claim predicate", "tests pass"],
           ["farmctl health checks q09_sealed_plan_hold_age and q09_autoseal_hold_census", "tools/strategy_farm/farmctl.py",
            "docs/ops/OPERATING_RULES_2026-07-03.md"], 90),
    ticket("Pending artifact binding drift: 63 CONTENT_CHANGED bindings across 33 pending rows (e.g. 8abafefb QM5_10203 "
           "Q02 mq5, 824ca951/a0d6400a QM5_20181 Q02 mq5+setfile, 8084f025 QM5_10593 Q04): per-EA review and governed "
           "successors from the final build; exact non-restart holds where a rebuild is pending; report runnable/created",
           ["S1 group the 33 rows by EA and drift class; decide per EA whether the working copy is the intended final "
            "build (governed COMPILE_EA receipt) or an in-progress rebuild",
            "S2 final builds: append-only successor rows bound to the final artifact hashes (farmctl enqueue-backtest "
            "--append-only-rerun-of), old rows superseded; in-progress rebuilds: exact hold with reason",
            "S3 dry-run first, then apply; RESULT table"],
           ["health check pending_artifact_binding_drift at 0 or every remaining row classified with reason",
            "no verdict evidence overwritten"],
           ["farmctl health check pending_artifact_binding_drift", "tools/strategy_farm/farmctl.py"], 85),
    ticket("Q08 INVALID rate 47 pct over 7 days (25 of 53 Q08 rows): find why the gate runs but yields no verdict "
           "(unauthenticatable / missing evidence), fix the runner or evidence contract, re-run the affected rows append-only",
           ["S1 list the 25 INVALID rows with verdict_reason and evidence paths; classify",
            "S2 root cause + fix with tests",
            "S3 append-only reruns for rows whose cause is infra; RESULT with counts"],
           ["INVALID cause table", "fix committed with tests", "reruns enqueued append-only"],
           ["farmctl health check phase_invalid_rate_7d", "tools/strategy_farm/farmctl.py"], 85),
    ticket("Q02 stranded exhausted pairs (3 EA/symbol pairs with at least 12 INFRA_FAIL rows, no terminal disposition, no "
           "successor): classify by row-bound aggregate and verdict_reason; route valid zero-trade outcomes to "
           "RETIRE/frequency floor and INVALID outcomes to evidence repair; one governed canary before any requeue",
           ["S1 identify the 3 pairs (health check q02_stranded_exhausted_pairs) with the INFRA_FAIL signatures",
            "S2 disposition per pair with evidence; canary rerun for at most one pair", "S3 RESULT"],
           ["3 pairs dispositioned or canaried with evidence paths"],
           ["farmctl health check q02_stranded_exhausted_pairs"], 70, tier="codex_medium", ctier="luna"),
    ticket("Backup calendar continuity: the nightly backup gap 2026-08-18 (G: drive not mounted) fails the health check "
           "forever because a later healthy run does not close the gap; add a governed acknowledgment record (dated, "
           "reason, evidence path) that the check honours, and document the rule in docs/ops",
           ["S1 read the check and backup_nightly.log", "S2 acknowledgment file/format + check support with tests",
            "S3 write the 2026-08-18 acknowledgment; RESULT"],
           ["health check backup_calendar_continuity OK with the acknowledgment; test added"],
           ["D:/QM/reports/state/backup_nightly.log", "tools/strategy_farm/health.py"], 60,
           tier="codex_medium", ctier="luna"),
]

if __name__ == "__main__":
    for prio, payload in TICKETS:
        for _ in range(6):
            r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority",
                                str(prio), "--assigned-agent", "codex", "--payload-json",
                                json.dumps(payload, ensure_ascii=False)], capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                print("enqueue ok", prio, json.loads(r.stdout)["task_id"][:8], payload["title"][:70])
                break
            print("retry", r.stderr.strip()[-160:])
            time.sleep(8)
