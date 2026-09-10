"""Commission WINSWEEP queue-order support (Orchestrator 2026-09-10 ~00:5xZ) as a Codex ticket."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
T = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-10 (follow-up to 49af4f08; OWNER 2026-09-09 ~21:45Z window sweep is the top research priority)",
    "model_tier": "codex_high",
    "codex_model_tier": "terra",
    "codex_reasoning_effort": "high",
    "required_capabilities": ["code", "ops"],
    "title": "WINSWEEP queue order: make window-sweep programs addressable by the governed queue-order lever so their OPT_CENSUS cells can rank ahead of the rolling XAU/NDX frontier (420 stage-A cells unclaimable in practice since 2026-09-09T23:56Z)",
    "finding": [
        "farmctl.pending_claim_order_sql (top-down selector ON) ranks OPT_CENSUS frontier rows by _opt_census_idle_program_rank, then _opt_census_queue_order_rank, then ... _asset_rank, then updated_at. _opt_census_queue_order_rank reads queue_order_at from the row's q12_work_item_id owner; rows without a Q12 owner get the sentinel and sort after every explicitly ordered program; among sentinel rows USDJPY (_asset_rank 3) sorts after XAU (0) and NDX (1), whose frontier windows are re-boosted continuously, so USDJPY programs starve (DL089_QM5_13213: 2 of 1085 cells in 10 h; WINSWEEP: 0 of 420).",
        "Snapshot 2026-09-10T00:4xZ via farmctl.pending_claim_order_sql: first DL089_QM5_13213 row at position 15, first WINSWEEP row at position 21, behind Q10_NEWS/Q02 rows that the census workers cannot claim and 10145/13013 frontier rows.",
        "Mitigation already applied by the orchestrator with the existing tool set_dl089_queue_order.py (apply, queue_order_at=2026-08-20T00:00:00+00:00 on Q12 owner 97908d93 ea QM5_13213, rank 51 -> 1, backup written; reason + owner-instruction recorded in the tool output). This lifts the DL-089 41398 pattern census but NOT WINSWEEP, because window_sweep.py rows carry no q12_work_item_id and the tool only targets phase=Q12 pattern rows.",
    ],
    "spec": [
        "S1 Design the smallest generic extension so a window program (schema qm.window-sweep.v1) participates in the SAME queue-order mechanism: either (a) WINSWEEP rows reference a governed owner row whose payload.queue_order_at the existing _opt_census_queue_order_rank subquery reads (the window declaration/ledger row, or a synthetic Q12-like owner created by window_sweep.py under the declaration), or (b) _opt_census_queue_order_rank reads a queue_order_at from the window program ledger for rows with program_id starting WINSWEEP_. Prefer (a) if it keeps farmctl.pending_claim_order_sql byte-identical for all existing rows; otherwise (b) with a proof that the cold order for every non-window row is unchanged (hash of the ordered id list before/after on the production DB read-only).",
        "S2 Extend set_dl089_queue_order.py (or add window_sweep.py queue-order plan|apply|list with the same safety contract: plan/apply, backup, reason, owner-decision, revalidation inside the write transaction, only queue_order_at written) so the operator can place WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025 at an explicit queue_order_at.",
        "S3 Tests: ordering test on a temp DB with XAU/NDX frontier rows + WINSWEEP rows, showing WINSWEEP rows rank first after the lever and last before it; DL089 identity test (existing 1,085-cell plan hash unchanged; claim order for a fixture of non-window rows unchanged).",
        "S4 Because the worker imports farmctl.pending_claim_order_sql, any change there requires the staggered idle-worker reload before it takes effect: state this in the RESULT and do NOT restart workers yourself (orchestrator runs session_tools/reload_chunk59.py pattern). Then the orchestrator applies the lever.",
        "S5 Report the structural finding for OWNER as a separate paragraph in OPEN_ITEMS: USDJPY (asset rank 3) programs are systematically starved by rolling XAU/NDX frontier boosts under the top-down selector; propose (do not implement) a fairness option (round-robin over idle programs before asset rank) as a candidate OWNER decision.",
    ],
    "hard_limits": [
        "No change to gate thresholds, verdicts, DL-089 sealed rule, or existing row payloads except queue_order_at through the governed lever; append-only",
        "No worker restart, no terminal start, never T_Live",
        "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md",
    ],
    "acceptance": [
        "After orchestrator reload + lever apply, farmctl.pending_claim_order_sql places WINSWEEP rows ahead of every sentinel OPT_CENSUS row (position printed), and the first WINSWEEP cell is claimed and MEASURED within one hour of the lever",
        "Tests pass; DL089 plan hash identical; ordered-id-list hash for non-window rows identical before/after",
    ],
    "expected_artifact": "tools/strategy_farm/window_sweep.py (+ farmctl.py / set_dl089_queue_order.py if needed) + tests + docs/ops/evidence/2026-09-10_winsweep_queue_order.md",
    "evidence": [
        "docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md",
        "docs/ops/evidence/WINDOW_SWEEP_IMPLEMENTATION_2026-09-09.md",
        "tools/strategy_farm/farmctl.py pending_claim_order_sql (line ~2377)",
        "tools/strategy_farm/set_dl089_queue_order.py",
    ],
}

if __name__ == "__main__":
    for _ in range(6):
        r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", "95",
                            "--assigned-agent", "codex", "--payload-json", json.dumps(T, ensure_ascii=False)],
                           capture_output=True, text=True, cwd=REPO)
        if r.returncode == 0:
            print("enqueue ok", json.loads(r.stdout)["task_id"])
            break
        print("retry", r.stderr.strip()[-200:])
        time.sleep(8)
