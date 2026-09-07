"""Commission the Dukascopy backfill continuation (OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES, task 3032534e,
CEO loop 2026-09-07 14:2xZ): ticket A = governed read-only T1 tick-tail probe (splice CSV), ticket B = P1/P2/P3 build.
"""
import json
import subprocess
import time

REPO = "C:/QM/repo"
COMMON = {
    "requested_by": "CEO claude-session-018mXkPPkaHQ2fPuduPCBcWc (decision-bound task 3032534e-eaf0-5b68-b09f-2127ebb315b0 for OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES)",
    "owner_instruction_utc": "2026-09-07T14:16:34Z",
    "decision_id": "OWNER-DEC-DUKASCOPY-BACKFILL-20260829",
    "parent_claude_task": "3032534e-eaf0-5b68-b09f-2127ebb315b0",
    "model_tier": "codex_high",
    "codex_reasoning_effort": "high",
    "required_capabilities": ["code", "ops"],
    "hard_limits": [
        "The signed 2017-2025 custom-history archive is never touched (manifest hash must re-verify unchanged); 2026 is the mutable year",
        "No manual terminal start: any MT5 execution runs under a governed factory claim / existing governed lane; never T_Live, never T2-T10 for this phase",
        "No purchase (OWNER 27.08.); Dukascopy public bi5 only",
        "No verdict, threshold or gate change; existing verdicts are never modified",
        "Commit with explicit pathspecs, LF, co-author trailer; never stage framework/registry/dxz23_execution_contracts.json",
    ],
}
A = dict(COMMON, **{
    "title": "Dukascopy backfill step 1 (Codex): governed READ-ONLY T1 tick-tail probe - the exact last genuine .DWX tick timestamp (ms) per symbol for all 37 universe symbols, written as the splice CSV; runs under a factory claim, never a manual terminal start; unblocks P1 (task 3032534e, OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES)",
    "summary": "P0 (task bd73130a, docs/ops/evidence/2026-09-02_dukascopy_backfill_p0_block.md) stopped fail-closed because the history-range builder reports HCC year coverage, not the last genuine tick per symbol. Required: (1) an MQL5 script or service under mt5_diagnostics/ that, for each of the 37 symbols in framework/registry/dwx_symbol_matrix.csv (.DWX custom symbols), reads the custom-symbol tick history read-only (CopyTicks / CopyTicksRange from the end, or the Bases/Custom .tkc tail if CopyTicks cannot reach it) and writes symbol, last_tick_time_msc (broker time), last_tick_utc, last_tick_bid/ask, tick_count_last_day, first_tick_time_msc, source_terminal, probe_sha256 into a CSV + JSON sidecar under D:/QM/reports/dukascopy/splice/<stamp>/; (2) a Python wrapper following the governed pattern of mt5_diagnostics/qm1537_native_d1_export.py (compiles the read-only script with the terminal's MetaEditor into an artifact dir, launches ONLY an exact config with Enabled=0/AllowLiveTrading=0/AllowDllImport=0, terminates only the process it owns) BUT bound to D:/QM/mt5/T1 and executed under a factory claim: either as a new work_item phase (e.g. DIAG_PROBE, claimed by the T1 worker like any other item, so the claim serializes against backtests and the custom-history isolation gate stays fail-closed) or by proving that the existing T_Export-style lane is acceptable for T1 - document the choice and why no history mutation is possible (read-only flags, no Custom-symbol writes, hash of Bases/Custom manifest before/after); (3) a verification step: the probe result must be consistent with docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv (last covered period per symbol) and with the signed archive manifest (2017-2025 untouched, hash re-verified); (4) tests for the CSV schema, time conversion (broker NY-close GMT+2/+3 -> UTC per docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md) and the fail-closed wrapper; (5) evidence README under docs/ops/evidence/2026-09-07_dukascopy_p0_tick_tail_probe/ with the run receipt and the 37-row splice CSV path. Do NOT start P1 downloads. If the probe needs a factory claim type that does not exist, deliver the phase/claim wiring with tests and stop in REVIEW before the first production run - the CEO runs it.",
    "evidence": ["docs/ops/DUKASCOPY_BACKFILL_PLAN_2026-08-29.md", "docs/ops/evidence/2026-09-02_dukascopy_backfill_p0_block.md", "docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv", "mt5_diagnostics/qm1537_native_d1_export.py", "framework/registry/dwx_symbol_matrix.csv", "docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md", "docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md"],
})
B = dict(COMMON, **{
    "title": "Dukascopy backfill step 2 (Codex build): P1 throttled bi5 downloader (UTC -> Darwinex NY-close GMT+2/+3), P2 append-only converter into the prepare_import.py input format from the splice timestamp with source sidecar, P3 reconciliation harness (M1 OHLC p95 <= 1.5x typical spread, session coverage >= 99 %, DST 0-second criterion; fail-closed per symbol) - build + tests + dry runs only, no production download (task 3032534e, OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES)",
    "summary": "Plan docs/ops/DUKASCOPY_BACKFILL_PLAN_2026-08-29.md section 3 is the spec. P1: tools/dukascopy/download_bi5.py - hourly bi5 files (LZMA, 20-byte records), symbol mapping FX 1:1; GDAXI<-DEU.IDX/EUR, SP500<-USA500.IDX/USD, NDX<-USATECH.IDX/USD, WS30<-USA30.IDX/USD, UK100<-GBR.IDX/GBP, XAUUSD/XAGUSD direct, XTIUSD<-LIGHT.CMD/USD, XNGUSD<-GAS.CMD/USD; window = per-symbol splice timestamp minus the overlap (>= 2025-10-01) to now; throttle 5-10 req/s with resume, checksum manifest per file, detached-night mode (log + progress JSON, no console dependency), never blocks the factory (I/O only). Time conversion UTC -> Darwinex NY-close broker time GMT+2 outside US DST / GMT+3 during US DST exactly per docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md with unit tests on the 2025/2026 DST transition weeks. P2: tools/dukascopy/convert_to_import.py - output in the D:/QM/mt5/T1/dwx_import/prepare_import.py input format (TDM-CSV compatible or .bin - read prepare_import.py and verify_import.py first), append-only from the splice timestamp (never emits a tick <= splice), per-symbol import sidecar with source=dukascopy, splice_timestamp, file hashes, so a symbol can later be re-imported from its DWX tail (rollback contract). P3: tools/dukascopy/reconcile_overlap.py - overlap window where both sources exist (at least 2025-10 -> 2026-04): per symbol Dukascopy vs DWX on M1: OHLC delta median/p95 in points, tick-density ratio, spread distribution, session/holiday coverage, DST transition weeks with the 0-second offset criterion (pattern REPORT_2026-04-25_test_eurusd_dst_match.md); acceptance per symbol p95 M1 close delta <= 1.5x typical spread, session coverage >= 99 %, DST exact; compute < 2 h; output CSV per symbol + summary report; FAIL symbols are listed and never spliced. Deliver: code, tests (synthetic bi5 fixtures, DST cases, splice boundary, reconciliation thresholds), a 1-symbol 1-day dry run against the public endpoint (small, throttled) proving the pipeline end to end into a scratch dir (no T1 import), and an evidence README under docs/ops/evidence/2026-09-07_dukascopy_p1_p3_build/ with the exact night-run command lines for the CEO. The DWX side of P3 reads the T1 custom history read-only through the same governed probe route as step 1 (or from an exported M1 CSV produced under a factory claim) - never a manual terminal start. No production download, no import, no OFF window.",
    "evidence": ["docs/ops/DUKASCOPY_BACKFILL_PLAN_2026-08-29.md", "docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md", "docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv", "D:/QM/mt5/T1/dwx_import/prepare_import.py", "D:/QM/mt5/T1/dwx_import/verify_import.py", "framework/registry/dwx_symbol_matrix.csv", "framework/registry/tester_defaults.json"],
})

if __name__ == "__main__":
    for prio, payload in ((87, A), (86, B)):
        for i in range(6):
            r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "enqueue", "ops_issue", "--priority", str(prio),
                                "--payload-json", json.dumps(payload, ensure_ascii=False)], capture_output=True, text=True, cwd=REPO)
            if r.returncode == 0:
                print("enqueue ok", json.loads(r.stdout)["task_id"][:8], payload["title"][:40]); break
            time.sleep(8)
    for i in range(4):
        r = subprocess.run(["python", "tools/strategy_farm/agent_router.py", "route-many", "--max-routes", "2"], capture_output=True, text=True, cwd=REPO)
        if r.returncode == 0:
            print("route", r.stdout.strip()[-260:].replace("\n", " ")); break
        time.sleep(8)
