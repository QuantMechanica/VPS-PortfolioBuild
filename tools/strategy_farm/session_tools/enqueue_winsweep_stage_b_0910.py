"""Commission WINSWEEP stage-B tooling ahead of the stage-A adjudication (OWNER 2026-09-10 ~20:35Z: pushe und optimiere)."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
PLAN = "docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md"
T = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-10 (OWNER ~20:35Z: ueberwache alles, pushe und optimiere)",
    "model_tier": "codex_high",
    "codex_model_tier": "terra",
    "codex_reasoning_effort": "high",
    "required_capabilities": ["code", "ops"],
    "title": "WINSWEEP stage B tooling: plan --stage B from a COMPLETE stage-A report (top-5 plateau windows x exit {15,16,17,19,20,21} = 30 windows x 7 years), idempotent enqueue under the same sealed program, exit-axis report with the plan section-5 rule; stage-A report must also emit the refutation verdict explicitly",
    "objective": "Have stage B ready the moment stage A (420 cells, 334 MEASURED at 20:26Z) completes, so the exit axis runs without an idle gap. Everything is fixed by " + PLAN + " sections 3-5 (read first, copy numbers, do not reinterpret).",
    "spec": [
        "S1 plan --stage B: refuse unless the stage-A report is complete (all 420 cells MEASURED or explicitly listed as append-only rerun-of INFRA cells); derive the top-5 plateau windows exactly per section 5 (admissibility first, DEV median costed return_to_maxdd, plateau median over the start+-1 x length+-1 neighbourhood, ties shorter length then earlier start); write the stage-B cell list (30 windows x 2019..2025) into the program declaration ledger as an amendment record (append-only, sha256, stage-A report sha bound) and render setfiles changing only strategy_exit_hour on the 5 windows' stage-A setfiles.",
        "S2 enqueue --stage B --apply: deterministic uuid5 cell ids, cell_key WINSWEEP_...:<year>:s<start>_l<length>_x<exit>, same OPT_CENSUS payload contract as stage A (worker adapter 1b4644149e + queue-order owner e144b67f), dry-run first, idempotent (second run 0), frontier priority = stage-A rows.",
        "S3 report --stage B: per window costed return_to_maxdd per year, DEV/OOS medians, plateau over the exit axis (exit +-1 within the tested set), final configuration rule: stage-B winner only if it beats the stage-A winner with exit 18 by >= 1.10 on the plateau DEV score AND passes the OOS confirmation; otherwise the stage-A winner with exit 18 stands. Also make the stage-A report print the section-2 refutation verdict (H-WIN kept / refuted) and the winner OOS confirmation values explicitly.",
        "S4 Tests: temp-DB test for plan/enqueue idempotency and for the refusal on an incomplete stage A; unit test of the plateau/tie rule with a synthetic surface; DL089 identity hash unchanged.",
    ],
    "hard_limits": [
        "No stage-B enqueue against production in this ticket unless stage A is complete at the time; if complete, run dry-run and stop, the orchestrator applies after adjudicating stage A",
        "No change to the pre-registered rule, grid, metric or split; no EA source/binary change; no verdicts touched; append-only",
        "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md",
    ],
    "acceptance": ["plan/enqueue/report --stage B implemented with tests; refusal on incomplete stage A proven", "stage-A report prints refutation verdict + OOS confirmation values", "dry-run evidence for stage B if stage A is complete, else documented refusal output"],
    "expected_artifact": "tools/strategy_farm/window_sweep.py + tests + docs/ops/evidence/2026-09-XX_window_sweep_stage_b_tooling.md",
    "evidence": [PLAN, "docs/ops/evidence/WINDOW_SWEEP_IMPLEMENTATION_2026-09-09.md", "docs/ops/evidence/2026-09-10_winsweep_queue_order.md"],
}

if __name__ == "__main__":
    for _ in range(6):
        r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", "88",
                            "--assigned-agent", "codex", "--payload-json", json.dumps(T, ensure_ascii=False)],
                           capture_output=True, text=True, cwd=REPO)
        if r.returncode == 0:
            print("enqueue ok", json.loads(r.stdout)["task_id"])
            break
        print("retry", r.stderr.strip()[-200:])
        time.sleep(8)
