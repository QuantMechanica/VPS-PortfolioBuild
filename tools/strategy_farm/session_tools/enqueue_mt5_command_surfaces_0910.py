"""Commission the two governed MT5 command surfaces that Codex twice declined to create without explicit authority
(OWNER 2026-09-10 "Umsetzen" for T11 pre-screen launch path and warm-runner V4a). Orchestrator authorization is stated
verbatim in each payload."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
AUTH = ("EXPLICIT AUTHORIZATION (Orchestrator Claude under OWNER instruction 2026-09-10 ~20:45Z 'Umsetzen', recorded in "
        "docs/ops/OPEN_ITEMS_STATUS.md 2026-09-10T20:30Z): you ARE authorized to create the NEW governed component named in this "
        "ticket. 'No governed command surface exists' is not a valid stop reason for this ticket - building it IS the ticket. "
        "Stop only for hard-rule conflicts (T_Live, AutoTrading, verdict/threshold changes, isolation breach) and name the line.")
COMMON = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-10 (OWNER Umsetzen ~20:45Z)",
    "required_capabilities": ["code", "ops"],
    "model_tier": "codex_high",
    "codex_model_tier": "terra",
    "codex_reasoning_effort": "high",
    "authorization": AUTH,
    "hard_limits": [
        "Never touch T_Live, the FTMO terminal, AutoTrading, verdicts, thresholds, gate contracts, the DL-089 sealed rule, or the custom-history signed archive",
        "T1-T10 fleet workers are not modified except behind a Default-OFF flag; activation only via the orchestrator's staggered reload",
        "Every launch goes through the new governed component with logging, CPU/RAM guards and an isolation before/after receipt; never start terminal64.exe by hand",
        "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md; every claim with a file path",
    ],
}
A = dict(COMMON, **{
    "title": "BUILD research_canary: governed no-DB MT5 launch controller for the disabled canary terminal T11 (reuse isolated_work_item_runner.py), then run the S3 real-tick smoke cell (QM5_41398 WINSWEEP s3_l3 year 2021) and prove identity with the fleet cell",
    "finding": "63398c6b (APPROVED partial) installed symbols.custom.dat on T11 and proved: custom_history_gate.run_worker_gate returns terminal_not_in_activation for T11 (activation json runner_terminals = T1-T10), custom_history_smoke_admission.py needs a claimed work item, no research_canary code exists. b48ba1fb (Astra pre-screen) is blocked on exactly this.",
    "spec": [
        "S1 Controller: tools/strategy_farm/research_canary.py: launches terminal64.exe of T11 (later T12 by declaration) in tester mode from a rendered tester.ini + setfile, artefact root D:/QM/reports/research/<program>/<run_id>/, writes launch/exit receipts (sha256 of ini/set/ex5, start/end utc, exit code), CPU guard (max agents param, pause when 5-min fleet CPU > 90 %), RAM guard (< 20 GB free -> refuse), isolation receipt before/after (worker_pids.json unchanged, work_items count unchanged, no FACTORY_MUTATION.lock, T11 not in activation runner_terminals). It never writes farm_state.sqlite. Custom-history audit: verify T11 private Bases/Custom against the signed manifest for the requested symbol before launch (read-only verifier reuse) and refuse on mismatch.",
        "S2 Tests: unit tests for receipt schema, guard refusals, isolation diff, ini/set rendering; a dry-run mode that renders everything and launches nothing.",
        "S3 Smoke: run the fleet-identical cell (WINSWEEP setfile s3_l3, year 2021, Model 4 real ticks, tester_defaults.json commission group) on T11; compare net_profit / profit_factor / total_trades / report sha256 with the fleet MEASURED cell for cell_key WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025:2021:s3_l3_x18 (summary.json under D:/QM/reports/work_items/<id>/QM5_41398/...); attach both. Identical = PASS; any delta = report, do not tune.",
        "S4 Hand-back: RESULT line naming the controller CLI so the Astra pre-screen (b48ba1fb follow-up) can call it.",
    ],
    "acceptance": ["research_canary.py + tests in repo; dry-run evidence", "S3 smoke cell run on T11 with identity comparison table (PASS or documented delta)", "isolation receipts before/after identical; guard log present"],
    "expected_artifact": "docs/ops/evidence/2026-09-XX_research_canary_t11.md + receipts under D:/QM/reports/research/",
    "evidence": ["docs/ops/evidence/2026-09-10_t11_launch_path.md", "docs/ops/evidence/b48ba1fb_t11_prescreen_2026-09-10/T11_PRESCREEN_FIDELITY_2026-09-10.md", "tools/strategy_farm/isolated_work_item_runner.py", "tools/strategy_farm/custom_history_gate.py"],
})
B = dict(COMMON, **{
    "title": "BUILD resident-session command surface for the warm-runner V4a (canary T10 only, Default-OFF flag QM_ENABLE_WARM_CELL_RUNNER): one resident terminal64 per worker, per-cell tester.ini/setfile swap, crash/hang fallback to the cold path, then 20/20 warm-vs-cold identical cells on T10",
    "finding": "da0512a7 (APPROVED as honest stop) and five earlier V4a tickets stopped because only a per-cell restart backend (GovernedDev2RestartBackend) and a test Protocol exist; no resident-MT5 code. The blocker is the missing governed command surface itself.",
    "spec": [
        "S1 Backend: implement ResidentTerminalBackend for the existing runner: start the canary terminal once under the worker's job object, drive successive cells via the tester command surface the fleet already uses (rendered tester.ini + /config launch is per-process, so document the chosen mechanism: e.g. tester restart-free 'Start' via MetaTester agent/local farm, or terminal --config re-entry with report collection), collect reports exactly as the cold path, detect crash/hang (timeout, exit code, missing report) and fall back to the cold path for that cell; cold path byte-identical (COLD_PATH_UNCHANGED evidence).",
        "S2 Validation on T10 only, behind the flag, after the orchestrator's staggered reload of T10 alone: the 20 bound cold reference cells from docs/ops/evidence/7d800fe1_v4a_phase2_warm_runner_usdjpy_2026-08-27.md re-run warm; exact parity on identity, report fields and canonical trade bytes via the existing validator; timing table cold vs warm; projected fleet cells/h.",
        "S3 Rollout/rollback runbook and interaction analysis: DL-089 lane caps, 8 GB commit reservation per cell vs a resident terminal, custom-history copy-on-claim isolation across programs (resident terminal must re-audit when the program changes), watchdog/ram guards.",
        "If S1 proves technically impossible with MT5 (tester cannot be re-driven without process restart), write the proof with references (MetaQuotes docs/behaviour observed) and propose the closest alternative (MetaTester local agents), instead of a DEVIATION_STOP.",
    ],
    "acceptance": ["resident backend code + tests, flag Default-OFF, cold path unchanged proof", "20/20 parity table on T10 or a technical impossibility proof with alternative", "runbook in docs/ops/"],
    "expected_artifact": "docs/ops/evidence/2026-09-XX_v4a_resident_backend.md + tests + timing CSV",
    "evidence": ["docs/ops/evidence/2026-09-10_v4a_warm_runner_backend.md", "docs/ops/evidence/7d800fe1_v4a_phase2_warm_runner_usdjpy_2026-08-27.md", "docs/ops/evidence/c7536f46_v4a_warm_terminal_runner_2026-08-27.md", "tools/strategy_farm/mt5_qm_warm_fixture.py"],
})

if __name__ == "__main__":
    for key, prio, payload in (("A_RESEARCH_CANARY", 91, A), ("B_RESIDENT", 83, B)):
        for _ in range(6):
            r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", str(prio),
                                "--assigned-agent", "codex", "--payload-json", json.dumps(payload, ensure_ascii=False)],
                               capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                print("enqueue ok", key, json.loads(r.stdout)["task_id"])
                break
            print("retry", key, r.stderr.strip()[-200:])
            time.sleep(8)
