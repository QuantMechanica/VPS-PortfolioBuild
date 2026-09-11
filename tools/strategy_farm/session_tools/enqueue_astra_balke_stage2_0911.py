"""Commission the Balke stage-2 matrix on the stage-A winner (Astra continuation of d444a7a8, 2026-09-11)."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
T = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-11 (continuation of d444a7a8 APPROVED partial; stage-A adjudicated)",
    "codex_model_tier": "astra",
    "scalpel": True,
    "model_tier": "astra",
    "codex_reasoning_effort": "high",
    "required_capabilities": ["code", "ops", "research"],
    "title": "ASTRA-BALKE-STAGE2: on the stage-A winner s0_l8 (00:00-08:00 fixed UTC+3, exit 18) build the sibling QM5_41405 with clock modes x outside-range rules x buffer x ATR-band on/off, plus the Balke minute-granular 00:00-07:30 configuration, and run the governed per-year matrix (2019-2025) with cell 0 reproducing the stage-A winner cells exactly",
    "context": [
        "Stage A result (pre-registered plan, tool-adjudicated): H-WIN KEPT; winner start 0 / length 8 / exit 18 (plateau 1.56 vs baseline 03-06 0.78, OOS pooled costed PF 1.21). docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md. Stage B (exit axis) runs in parallel; if it changes the exit, re-run only the affected cells.",
        "Your S1/S2 findings (BALKE_CLOCK_AUDIT_2026-09-09.md): range end 03 UTC = broker 05 winter / 06 summer on the 03-06 window; 7 fade-only days (invalid-price rejections) confirmed with one fill loss 869.92. Sibling QM5_41405 is reserved (magic 414050000, 2e7d5619 APPROVED); 41398 binary untouched.",
        "Balke captions (docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md): USDJPY range 00:00-07:30 broker server time, delete + close 18:00, no range filter, no trailing/BE, max 1 buy + 1 sell, SL opposite side, no TP, order buffer points input (demo 20 points).",
    ],
    "steps": [
        "S1 Sibling QM5_41405 = 41398 source + inputs: strategy_clock_mode {GMT3_FIXED (default, bit-identical to 41398) | BROKER_DST (raw broker hour, NY-close GMT+2/+3) | CET_LOCAL}, strategy_outside_range_rule {AS_IS (default) | SKIP_DAY | MARKET_ENTRY_BREAKOUT_DIR | OPPOSITE_STOP_ONLY}, strategy_entry_buffer_points (default 0), strategy_range_band_enabled (default true), strategy_range_bar_period {H1 default | M30 | M5} with minute-granular strategy_range_end_minute (default 0) so 07:30 is expressible; defaults reproduce 41398 exactly (prove with cell 0 = stage-A winner cells 2019-2025 identical trade lists). Compile via COMPILE_EA queue only; magic 414050000.",
        "S2 Matrix (pre-registered here, per-year OPT_CENSUS-style cells like WINSWEEP, own program id BALKE2_QM5_41405_USDJPY_DWX_2019_2025 with declaration + trial count): on the s0_l8 window: 3 clock modes x 4 outside rules x buffer {0, 20 pts} x ATR band {on, off} = 48 configs, plus 2 Balke-config cells (00:00-07:30 M30 range bars, exit 18, band off, max 1 buy + 1 sell, buffer 0 and 20) = 50 configs x 7 years = 350 cells (~17 h at 2 lanes; GELB cost reported). Score, DEV/OOS split, plateau over neighbouring buffer/band, admissibility exactly as the stage-A plan section 4-5. Refutation criteria: H-CLOCK: BROKER_DST/CET plateau not >= 1.10 x GMT3_FIXED -> keep fixed clock; H-OUTSIDE: no rule beats AS_IS by >= 1.10 -> keep AS_IS; H-BUFFER: 20 pts not >= 1.10 x 0 -> keep 0; H-BAND: band off not >= 1.10 x on -> keep on; H-BALKE: the Balke config not >= 1.10 x the best fixed-clock config -> keep ours.",
        "S3 Report docs/research/BALKE_STAGE2_RESULT_2026-09-XX.md: per-config table, hypothesis outcomes, recommended single configuration for a fresh Q02-Q10 chain (never by overwriting 41398), and the fade-only-day economics (from S2 of the audit) under each outside rule.",
    ],
    "hard_limits": [
        "New sibling only (QM5_41405); 41398 binary, sets and verdicts untouched; no gate/threshold/verdict change; backtests only under governed factory claims with RISK_FIXED; never T_Live; symbols are inputs; no ML",
        "Pre-register the matrix + criteria in the report file BEFORE enqueue (commit hash bound into the program declaration); no change after cells run",
        "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md; every claim with a file path",
    ],
    "acceptance": ["QM5_41405 compiled via COMPILE_EA with cell 0 identical to the stage-A winner cells (trade-list identity proof)", "350-cell matrix enqueued idempotently as its own declared program; report refuses selection until complete", "final report with hypothesis outcomes and one recommended configuration"],
    "expected_artifact": "docs/research/BALKE_STAGE2_RESULT_2026-09-XX.md + declaration + CSV",
    "evidence": ["docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md", "docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md", "docs/ops/evidence/BALKE_CLOCK_AUDIT_2026-09-09.md", "docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md", "tools/strategy_farm/window_sweep.py"],
}

if __name__ == "__main__":
    for _ in range(6):
        r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", "89",
                            "--assigned-agent", "codex", "--payload-json", json.dumps(T, ensure_ascii=False)],
                           capture_output=True, text=True, cwd=REPO)
        if r.returncode == 0:
            print("enqueue ok", json.loads(r.stdout)["task_id"])
            break
        print("retry", r.stderr.strip()[-200:])
        time.sleep(8)
