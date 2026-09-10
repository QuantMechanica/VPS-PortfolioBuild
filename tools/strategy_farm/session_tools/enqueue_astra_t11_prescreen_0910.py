"""Commission ASTRA-T11-PRESCREEN (OWNER 2026-09-10 ~19:30Z): can MT5 optimizer / cheaper modelling modes on T11
pre-sort census and sweep cells before real-tick confirmation? Real-tick backtests stay the only evidence class."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
T = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-10 (OWNER ~19:30Z: Astra soll mit T11 pruefen, ob Optimierungen oder andere Backtestvarianten fuer manche Backtests der Schedule nutzbar sind; am Ende immer noch Real-Tick, aber eventuell Vorsortierung oder andere Optionen)",
    "codex_model_tier": "astra",
    "scalpel": True,
    "model_tier": "astra",
    "codex_reasoning_effort": "high",
    "required_capabilities": ["code", "ops", "research"],
    "title": "ASTRA-T11-PRESCREEN: measure on T11 whether MT5 optimizer passes and cheaper modelling modes (1-minute OHLC, generated every-tick, open-prices) can PRE-SORT census/sweep cells before real-tick confirmation - fidelity calibrated on already MEASURED real-tick cells (WINSWEEP + DL-089 QM5_41398)",
    "objective": "Quantify speed-up AND fidelity of cheap pre-screens against the factory's real-tick per-year cells, then propose a governed pre-screen protocol (candidate ordering only, never a verdict). Real-tick Model 4 per-year cells remain the only evidence class for verdicts and the counter.",
    "context": [
        "Fleet: 10 workers T1-T10 run ~80 real-tick census cells/h (Model 4, per-year 2019..2025, 8 GB commit each); gate throughput collapsed to ~1 row/h (Clear-ETA 61 d), OWNER capped census at G=3 for 48 h (2026-09-10 19:00Z). Any pre-screen that cuts the number of real-tick cells materially changes the economics.",
        "T11 = disabled canary terminal (D:/QM/mt5/T11, listed in disabled_terminals.txt, 43 GB private Bases/Custom .DWX history incl. ticks, never claimed by a worker, used for latency_lab_20260908 and QM5_900001/900002 demo runs). T12 is the same class. Use T11 ONLY.",
        "Prior work to build on, not repeat: V4b MT5-native optimizer feasibility (docs/ops/evidence/3e129337_v4b_mt5_native_optimizer_feasibility_2026-08-27.md, disposable prototype only); V4a warm-terminal cell runner (docs/ops/evidence/c7536f46_v4a_warm_terminal_runner_2026-08-27.md) and its USDJPY validation (docs/ops/evidence/7d800fe1_v4a_phase2_warm_runner_usdjpy_2026-08-27.md).",
        "Ground truth for calibration already exists: WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025 (>=318 MEASURED real-tick per-year cells over 60 windows, setfiles under D:/QM/strategy_farm/artifacts/opt_census/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/setfiles, summaries under D:/QM/reports/work_items/<id>/QM5_41398/<ts>/summary.json runs[0]: net_profit, profit_factor, drawdown, total_trades) and the DL-089 QM5_41398 pattern census (>=340 MEASURED cells, opt_pp_* arms). EA binary/sets are inputs-only; do not rebuild anything.",
        "Hard rules: symbols are inputs, RISK_FIXED for backtests, no ML libraries, no invented commission/swap values (use tester_defaults.json), evidence = CSV/report/log paths.",
    ],
    "steps": [
        "S1 T11 readiness (read-only first): confirm T11 is not bound to any worker/scheduler (worker_pids.json, disabled_terminals.txt, no claims), its Custom history covers USDJPY.DWX 2019-2025 with ticks, tester_defaults.json model/commission values, and record the T11 terminal build. Document how a T11 run is isolated from the fleet (no work_items rows, no FACTORY_MUTATION.lock, no state DB writes).",
        "S2 Speed matrix on T11 for ONE representative cell set (the 60 WINSWEEP windows x 7 years): wall time per cell-equivalent for (a) real ticks Model 4 per-year (reference, single run to calibrate against fleet runtime), (b) real ticks single full-window 2019-2025 run with per-year split from the trade list, (c) 1-minute OHLC, (d) every tick generated, (e) open prices only, and (f) the MT5 optimizer (complete + genetic) over strategy_range_start_hour/strategy_range_end_hour with the pass table as output, in the cheapest mode that passes S3 fidelity, using N local MetaTester agents (start with 4). Report agent count, CPU cost and RAM per mode.",
        "S3 Fidelity vs ground truth: for every (window, year) with a MEASURED real-tick cell, compute cheap-mode net_profit/profit_factor/trades and evaluate: Spearman rank correlation per year and pooled; top-5 / top-10 overlap on the plateau score of docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md section 5; sign agreement; false-negative rate = share of real-tick top-10 windows a cheap-mode cut-off at the top 50 % / 30 % would have dropped. Same analysis for >=100 DL-089 pattern-census cells (bar-based predicates are expected to be high-fidelity; pending-stop fills are the risk for open-prices mode).",
        "S4 Other options worth a number each: warm terminal (no relaunch per cell, V4a) applied to census cells; single full-window run + per-year split instead of 7 launches (data-load amortisation); optimizer forward-testing as a first plateau filter; tick-cache reuse across cells of one program; MetaTester local agent parallelism vs the current one-terminal-per-worker model; running pre-screens on T11/T12 outside the fleet caps. For each: speed-up factor, fidelity caveat, isolation risk, implementation effort (S/M/L).",
        "S5 Protocol proposal (no implementation): which programs/phases may use a pre-screen (e.g. window sweeps and pattern census arms, never Q02-Q10 verdict runs), which mode and cut-off, and the confirmation rule (real-tick for the surviving top X % plus a random control sample of the dropped cells to keep measuring the false-negative rate). Write it as an OWNER decision card draft with the numbers from S2-S4; include the expected reduction in real-tick cells for the 6,453-cell census backlog.",
    ],
    "hard_limits": [
        "T11 only. Never T1-T10, never T12 unless T11 is unusable (then say so and stop), never T_Live or the FTMO terminal. No work_items rows, no state-DB writes, no FACTORY_MUTATION.lock, no changes to worker config or scheduled tasks.",
        "CPU guard: at most 4 MetaTester agents; pause runs when fleet CPU stays above 90 % for 5 minutes (the OWNER just freed CPU for Q02 intake); log the guard decisions. RAM guard: stop if free RAM < 20 GB.",
        "No verdict, threshold, gate, counter or card change; no EA source or binary change; results are artefact-only under D:/QM/reports/research/t11_prescreen_2026-09-10/ plus the report in docs/research/.",
        "Every number with a file path (tester report, pass table CSV, summary.json). NICHT GEZEIGT / not measured where a mode could not run.",
        "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md.",
    ],
    "acceptance": [
        "docs/research/T11_PRESCREEN_FIDELITY_2026-09-XX.md with the S2 speed table, S3 fidelity tables (rank correlation, top-k overlap, false-negative rate per cut-off) for both ground-truth sets, S4 option table, S5 decision-card draft",
        "CSV evidence under docs/ops/evidence/ (cheap-mode vs real-tick per cell) and raw tester outputs under D:/QM/reports/research/t11_prescreen_2026-09-10/",
        "Proof of isolation: zero new work_items rows attributable to T11, no worker restarts, CPU-guard log",
    ],
    "expected_artifact": "docs/research/T11_PRESCREEN_FIDELITY_2026-09-XX.md + CSVs + D:/QM/reports/research/t11_prescreen_2026-09-10/",
    "evidence": [
        "docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md",
        "docs/ops/evidence/3e129337_v4b_mt5_native_optimizer_feasibility_2026-08-27.md",
        "docs/ops/evidence/c7536f46_v4a_warm_terminal_runner_2026-08-27.md",
        "docs/ops/evidence/7d800fe1_v4a_phase2_warm_runner_usdjpy_2026-08-27.md",
        "framework/registry/tester_defaults.json",
        "docs/ops/OPEN_ITEMS_STATUS.md 2026-09-10T19:05Z (census cap decision)",
    ],
}

if __name__ == "__main__":
    for _ in range(6):
        r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", "86",
                            "--assigned-agent", "codex", "--payload-json", json.dumps(T, ensure_ascii=False)],
                           capture_output=True, text=True, cwd=REPO)
        if r.returncode == 0:
            print("enqueue ok", json.loads(r.stdout)["task_id"])
            break
        print("retry", r.stderr.strip()[-200:])
        time.sleep(8)
