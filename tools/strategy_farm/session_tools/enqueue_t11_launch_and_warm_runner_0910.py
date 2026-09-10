"""Commission two OWNER-approved acceleration items (OWNER 2026-09-10 ~20:45Z "Umsetzen"):
A) governed T11 research launch path (unblocks ASTRA-T11-PRESCREEN), B) warm-runner V4a resident MT5 backend + staged rollout."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
COMMON = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-10 (OWNER ~20:45Z: Umsetzen - T11-Vorfilter-Launchpfad, Zensus-Reihenfolge nach Zaehlernutzen, Warm-Runner V4a)",
    "required_capabilities": ["code", "ops"],
    "hard_limits": [
        "Never start terminal64.exe manually; every MT5 launch goes through a governed, tested launch path; never T_Live, never the FTMO terminal",
        "No verdict, threshold, gate, counter or card change; no EA source/binary change; append-only evidence",
        "Worker code changes are shipped Default-OFF behind a flag; activation only via the staggered idle-worker reload run by the orchestrator (session_tools/reload_chunk63.py pattern); never restart workers yourself",
        "Commit with explicit pathspecs, LF, co-author trailer; RESULT line in docs/ops/OPEN_ITEMS_STATUS.md; every claim with a file path",
    ],
}
A = dict(COMMON, model_tier="codex_high", codex_model_tier="terra", codex_reasoning_effort="high", **{
    "title": "T11 research launch path: install the custom-symbol catalog on T11 from the signed source, extend the governed research launch contract to the disabled canary terminal T11 (isolation audit, CPU/RAM guard, artefact-only), prove it with one real-tick smoke cell, then hand back to ASTRA-T11-PRESCREEN",
    "finding": "ASTRA-T11-PRESCREEN (b48ba1fb, docs/ops/evidence/b48ba1fb_t11_prescreen_2026-09-10/T11_PRESCREEN_FIDELITY_2026-09-10.md) stopped fail-closed: D:/QM/mt5/T11/Bases/symbols.custom.dat is absent (the earlier native experiment repaired a separate disposable lab, not the T11 root) and custom_history_smoke_admission.py:79 requires an active governed terminal, so no research launch on T11 is possible today. T1..T10 carry the catalog (e.g. D:/QM/mt5/T1/Bases/symbols.custom.dat, 20,480 bytes, 2026-05-22).",
    "spec": [
        "S1 Catalog: derive the T11 symbols.custom.dat from the signed custom-history manifest / an authenticated fleet terminal copy (state which, with sha256 before/after), verify T11's private Bases/Custom (43 GB, history + ticks) is content-verified against the signed manifest for USDJPY.DWX 2019-2025 with the existing verifier, and record the result in docs/ops/evidence/2026-09-XX_t11_launch_path.md.",
        "S2 Launch contract: add a research_canary launch mode (T11 only, T12 as declared-but-disabled fallback) to the governed launch tooling (reuse isolated_work_item_runner.py / custom_history_smoke_admission.py where possible): no work_items rows, no FACTORY_MUTATION.lock, no state-DB writes, artefact root D:/QM/reports/research/<program>/, CPU guard (max N MetaTester agents, pause when fleet CPU > 90 % for 5 min), RAM guard (stop < 20 GB free), tester model/commission from framework/registry/tester_defaults.json.",
        "S3 Proof: run exactly one real-tick per-year smoke cell (QM5_41398 WINSWEEP baseline setfile s3_l3, year 2021) on T11 through the new path and compare net_profit/profit_factor/total_trades/report sha with the fleet's MEASURED cell for the same cell key (must be identical); attach both summaries.",
        "S4 Hand-back: update the ASTRA ticket b48ba1fb by reference in OPEN_ITEMS (do not edit its payload): the orchestrator re-opens the fidelity measurement once S3 passes.",
    ],
    "acceptance": ["symbols.custom.dat present on T11 with documented provenance", "research_canary launch mode tested (unit tests + the S3 smoke cell identical to the fleet result)", "isolation proof: zero work_items rows, worker map unchanged, guard log"],
    "expected_artifact": "docs/ops/evidence/2026-09-XX_t11_launch_path.md + tests + smoke summaries",
    "evidence": ["docs/ops/evidence/b48ba1fb_t11_prescreen_2026-09-10/T11_PRESCREEN_FIDELITY_2026-09-10.md", "tools/strategy_farm/isolated_work_item_runner.py", "tools/strategy_farm/custom_history_smoke_admission.py", "docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md"],
})
B = dict(COMMON, model_tier="codex_high", codex_model_tier="terra", codex_reasoning_effort="high", **{
    "title": "Warm-runner V4a: implement the reviewed resident-MT5 session backend for the existing Default-OFF QM_ENABLE_WARM_CELL_RUNNER runner, validate 20/20 warm-vs-cold identical cells on one canary terminal, then staged fleet rollout plan",
    "finding": "Both V4a tickets (c7536f46, 7d800fe1) ended DEVIATION_STOP: the single-session orchestration and exact-parity validator exist behind QM_ENABLE_WARM_CELL_RUNNER (Default-OFF, not wired into the production worker) but only with an injected test backend; zero warm cells ever ran against MT5; the 20-cell cold reference (7,394 s total) is bound with hashes in docs/ops/evidence/7d800fe1_v4a_phase2_warm_runner_usdjpy_2026-08-27.md. The relaunch of terminal64.exe per census cell is the overhead this removes; census is now ~80 cells/h fleet-wide with the terminal restart inside every cell.",
    "spec": [
        "S1 Backend: implement the resident-session backend against the real tester (one terminal64 process per worker kept alive across cells; per-cell tester.ini/setfile swap via the governed command surface; report collection unchanged; crash/hang detection with fallback to the cold path for that cell) behind the existing flag; cold path must stay byte-identical (prove with the existing COLD_PATH_UNCHANGED check).",
        "S2 Validation on ONE canary worker terminal designated by the orchestrator (default T10; never T_Live/FTMO/T11): the 20 bound cold reference cells re-run warm; exact parity on identity, report fields and canonical trade bytes as the existing validator requires; timing table cold vs warm per cell and the projected fleet gain in cells/h.",
        "S3 Rollout plan (no fleet activation in this ticket): flag semantics, staged activation T10 -> T5 -> fleet with the staggered reload, rollback = unset flag + reload, monitoring signals (cells/h, INFRA rate, RAM per resident terminal, commit headroom interaction with the 8 GB reservation), and the interaction with the DL-089 lane caps and the custom-history copy-on-claim isolation (a resident terminal must not keep a private Custom copy across programs without re-audit).",
    ],
    "acceptance": ["20/20 warm cells identical to the bound cold references on the canary (hash table)", "measured speed-up per cell and projected fleet cells/h", "flag stays Default-OFF; cold path proven unchanged; rollout + rollback runbook in docs/ops/"],
    "expected_artifact": "docs/ops/evidence/2026-09-XX_v4a_warm_runner_backend.md + tests + timing CSV",
    "evidence": ["docs/ops/evidence/c7536f46_v4a_warm_terminal_runner_2026-08-27.md", "docs/ops/evidence/7d800fe1_v4a_phase2_warm_runner_usdjpy_2026-08-27.md", "tools/strategy_farm/mt5_qm_warm_fixture.py", "docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md"],
})

if __name__ == "__main__":
    for key, prio, payload in (("A_T11", 90, A), ("B_WARM", 84, B)):
        for _ in range(6):
            r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", str(prio),
                                "--assigned-agent", "codex", "--payload-json", json.dumps(payload, ensure_ascii=False)],
                               capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                print("enqueue ok", key, json.loads(r.stdout)["task_id"])
                break
            print("retry", key, r.stderr.strip()[-200:])
            time.sleep(8)
