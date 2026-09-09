"""Commission the 2026-09-09 implementation plan (OWNER 2026-09-09 ~18:30Z: "alles dementsprechend zur Umsetzung planen"):
T1 FTMO manifest addendum, T2 FTMO launcher-readiness health probe, T3 Dukascopy downloader hardening. Pinned to codex."""
import json
import subprocess
import time

REPO = "C:/QM/repo"
DATA_DIR = "C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850"
COMMON = {
    "requested_by": "Orchestrator Claude interactive session 2026-09-09 (OWNER instruction 2026-09-09 ~18:30Z)",
    "required_capabilities": ["code", "ops"],
    "hard_limits": [
        "Never start/stop/signal any terminal64.exe; never touch C:/QM/mt5/T_Live; never toggle AutoTrading",
        "No verdict, threshold or gate change; no live-account action; FTMO demo files are read-only for these tickets",
        "Commit with explicit pathspecs, LF, co-author trailer; report RESULT in docs/ops/OPEN_ITEMS_STATUS.md",
    ],
}
T1 = dict(COMMON, model_tier="codex_medium", codex_reasoning_effort="medium", **{
    "title": "FTMO demo manifest addendum 2026-09-09: record deployed EX5/preset hashes that deviate from the sealed 2026-09-06 M13 table (QM5_11421 rebuilt 2026-09-08 undocumented; 10706/11910/21505/1537 post-signature rebuilds)",
    "summary": "verify_ftmo_demo_instrumentation_contract.ps1 was re-pinned to deployed reality on 2026-09-09 (commit 388760053b) after QM_FTMO_AtLogon had failed profile_contract_failed since 2026-09-06. The verifier now pins deployed SHA-256 values that differ from docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md for five sleeves. Write an addendum section (dated 2026-09-09) into that manifest file listing per sleeve: chart, EA, deployed EX5 SHA-256, deployed preset path + SHA-256, sealed value, reason (cite the manifest own post-signature rebuild notes for 10706/11910/21505/1537; for QM5_11421 cite the 2026-09-08 01:11 chart-panel-standard rebuild and mark it as previously undocumented), and the verifier commit. Hashes must be recomputed with Get-FileHash from the deployed data dir " + DATA_DIR + " and must equal the values pinned in the verifier; any mismatch is a finding, not something to paper over.",
    "acceptance": [
        "Addendum section present in the manifest with a 5-row deviation table plus governor/telemetry/11422/13054/20048 listed as matching",
        "Every hash in the addendum equals the verifier pin (script or one-liner evidence in the commit message / OPEN_ITEMS)",
        "Verifier still exits 0 (run via native Windows PowerShell host, not git-bash)",
    ],
    "expected_artifact": "docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md (addendum) + OPEN_ITEMS RESULT line",
    "evidence": [
        "tools/strategy_farm/verify_ftmo_demo_instrumentation_contract.ps1 @388760053b",
        "docs/ops/OPEN_ITEMS_STATUS.md 2026-09-09T18:15Z entry",
        "D:/QM/reports/state/live_launcher_events.jsonl 2026-09-09T16:44:50Z",
    ],
})
T2 = dict(COMMON, model_tier="codex_medium", codex_reasoning_effort="medium", **{
    "title": "Health probe ftmo_launcher_readiness: surface FTMO/T_Live launcher contract drift as a distinct FAIL (verifier rc + last launcher exit per boot) in farmctl health and the 06:00 mail",
    "summary": "Since 2026-09-06 the FTMO demo terminal had no working autostart: the fail-closed verifier rejected the redeployed M13 profile, QM_FTMO_AtLogon exited 2 profile_contract_failed, and the only signals were live_launcher_events.jsonl and the generic chronic FAIL live_mt5_uptime (FTMO degraded), which was filtered as known noise. Implement a named health check ftmo_launcher_readiness (and t_live_launcher_readiness using the same pattern if T_Live_ON.ps1 has a comparable verifier) that (1) runs verify_ftmo_demo_instrumentation_contract.ps1 read-only under the native PowerShell host and reports rc, (2) reads the latest launcher record per launcher from D:/QM/reports/state/live_launcher_events.jsonl and FAILs when exit_code != 0 for the current boot (boot time from Win32_OperatingSystem.LastBootUpTime), (3) is wired into farmctl health and the 06:00 HTML mail as its own line, never merged into live_mt5_uptime. Add one SOP line to the FTMO runbook: after every FTMO demo change (attach/detach, rebuild, preset) re-run the verifier and re-pin it in the same commit.",
    "acceptance": [
        "farmctl health shows ftmo_launcher_readiness on the current state; if the 2026-09-09T16:44Z exit-2 record for the current boot makes it WARN/FAIL, say so explicitly and document the expected clearing condition (next successful launcher run)",
        "Unit test or dry-run evidence for the FAIL path (simulated exit_code=2 record)",
        "SOP line committed in the FTMO runbook",
    ],
    "expected_artifact": "health module change + test evidence under docs/ops/evidence/2026-09-XX_ftmo_launcher_readiness_probe.md",
    "evidence": [
        "tools/strategy_farm/FTMO_ON.ps1 (Write-LiveLauncherExitRecord)",
        "docs/ops/OPEN_ITEMS_STATUS.md 2026-09-09T18:15Z entry",
    ],
})
T3 = dict(COMMON, model_tier="codex_high", codex_reasoning_effort="high", **{
    "decision_id": "OWNER-DEC-DUKASCOPY-BACKFILL-20260829",
    "parent_claude_task": "3032534e-eaf0-5b68-b09f-2127ebb315b0",
    "title": "Dukascopy backfill P1 hardening: make tools/dukascopy/download_bi5.py survive the measured ~50% TCP/TLS failure rate to the Dukascopy edge (retry/backoff, bounded concurrency, resume, per-hour success ledger) and re-measure the projected wall time",
    "summary": "Decision-bound Claude task 3032534e stopped the detached download after 6/304621 hours because ~50% of connections to the Dukascopy edge failed at TCP/TLS, projecting 167 days instead of 3-5 (evidence docs/ops/evidence/2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md). Harden the downloader: exponential backoff with jitter per hour-file, bounded concurrency (start 6, configurable), HTTP keep-alive session reuse, optional proxy env passthrough, resumable ledger of done/failed hours, and a --measure mode that samples N=300 hour-files and reports success rate + effective throughput. Then run the measurement (no production import, no factory action) and report the projected wall time for the full 304621-hour window. Do not touch the signed 2017-2025 archive; 2026 is the mutable year; Dukascopy public bi5 only, no purchase.",
    "acceptance": [
        "download_bi5.py hardened with tests for retry/resume",
        "Measurement report with success rate, hours/min, projected total wall time, and a recommendation (proceed / need proxy or different egress)",
        "No import into any terminal, no history mutation",
    ],
    "expected_artifact": "docs/ops/evidence/2026-09-XX_dukascopy_p1_hardening_measurement.md",
    "evidence": [
        "docs/ops/DUKASCOPY_BACKFILL_PLAN_2026-08-29.md",
        "docs/ops/evidence/2026-09-09_dukascopy_backfill_datafeed_connectivity_degraded.md",
    ],
})

if __name__ == "__main__":
    ids = []
    for prio, payload in ((72, T1), (76, T2), (85, T3)):
        for _ in range(6):
            r = subprocess.run(
                ["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", str(prio),
                 "--assigned-agent", "codex", "--payload-json", json.dumps(payload, ensure_ascii=False)],
                capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                tid = json.loads(r.stdout)["task_id"]
                ids.append(tid)
                print("enqueue ok", tid[:8], prio, payload["title"][:60])
                break
            print("retry", r.stderr.strip()[-200:])
            time.sleep(8)
    print("IDS", ids)
