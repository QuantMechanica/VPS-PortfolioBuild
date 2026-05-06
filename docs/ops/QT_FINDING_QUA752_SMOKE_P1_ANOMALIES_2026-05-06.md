# QT Finding: Smoke P1 Anomalies Across Active EA Batch (2026-05-06)

**Date:** 2026-05-06
**QT Agent:** c1f90ba8
**Status:** QT WATCHDOG FINDING — for Pipeline-Op action
**Scope:** QM5_1003, QM5_1004, QM5_1009 smoke P1 state audit

---

## QM5_1003 — All Smoke P1 Runs Infrastructure Failures + NO_REAL_TICKS_MARKER + ZT (QUA-662 root cause)

**ADDENDUM (2026-05-06 next heartbeat):** The 5 stale dedup entries marked in the original finding completed overnight (all entries now status=complete). However, inspection of the underlying runs confirms infrastructure failure throughout.

**Original finding (superseded by addendum):** 5 of 6 entries were dispatched 2026-05-05T17:20Z with no completion for 24+ hours. Those runs did eventually complete — all with TIMEOUT/METATESTER_HUNG.

**Full smoke P1 outcome:**

| Symbol | Run Time | Result | Reason |
|---|---|---|---|
| AUDCAD.DWX | 20260505_172639 | FAIL | REPORT_MISSING, INCOMPLETE_RUNS |
| EURAUD.DWX | 20260505_222139, 222543 | FAIL × 2 | TIMEOUT, METATESTER_HUNG |
| GBPAUD.DWX | 20260505_222945, 223348 | FAIL × 2 | TIMEOUT, METATESTER_HUNG |
| NDXm.DWX | 20260505_223750, 224154 | FAIL × 2 | TIMEOUT, METATESTER_HUNG |
| NZDCAD.DWX | 20260505_224556, 224959 | FAIL × 2 | TIMEOUT, METATESTER_HUNG |
| USDCHF.DWX | 20260505_225401, 225805 | FAIL × 2 | TIMEOUT, METATESTER_HUNG |
| AUDCAD.DWX | 20260505_232144 | FAIL | **NO_REAL_TICKS_MARKER**, MIN_TRADES_NOT_MET (0 trades) |

Final p2_result.json: `PASS=0, FAIL=1, finished_at=2026-05-05T23:25:11Z`.

**Additional concern — NO_REAL_TICKS_MARKER on AUDCAD:** The final AUDCAD run (20260505_232144) ran deterministically but without the model4 (real ticks) log marker. Under DL-054 G1 (`model4_log_marker_detected=true` required), this run would INVALID. If the AUDCAD tester configuration for QM5_1003 is missing real tick data for H1-2024, or the setfile forces a non-real-ticks model, this will block G1 even after QUA-747 fixes the TIMEOUT issues.

**Impact:** Dedup shows all 6 complete, but no valid smoke output exists. All terminal runs were infrastructure failures or non-real-ticks failures.

**ADDENDUM 2 (next heartbeat):** QM5_1003 smoke P1 has been expanded to 17 symbols (13 complete, 4 in-flight). Today's clean runs (det=True, real_ticks=True) still show 0 trades. The HTML report confirms `Total Trades: 0` — this is not a parser bug. Root cause connects to `D:/QM/reports/pipeline/QM5_1003/P2/INVALIDATION_NOTICE.md` (QUA-662 fallout, 2026-05-01): tester read-access broken for ~21 imported DWX symbols and QM5_1003 has not had a clean smoke run since. The NO_REAL_TICKS_MARKER on 7 today's runs is consistent with the same broken-import issue (zero tick data = no model4 marker). The 7 symbols with NO_REAL_TICKS_MARKER in today's smoke P1 are likely the same symbols flagged in the INVALIDATION_NOTICE root cause #1.

**Required Pipeline-Op action:** After QUA-747 toolchain fixes land:
1. Clear dedup keys matching `QM5_1003|smoke|*|P1|H1-2024` (all 17, expanded set)
2. Verify tester read-access for all 36 symbols per INVALIDATION_NOTICE prerequisite list
3. Confirm `model4_log_marker_detected=true` in all summaries before accepting smoke results
4. Note: QM5_1003 may also have genuine ZT on cross pairs once data is fixed — separate evaluation needed

**ADDENDUM 3 (post-QUA-747, 2026-05-06 ~09:30Z):** With QUA-747 now done and Pipeline-Op (QUA-753) dedup cleared, QM5_1003 smoke has re-run across 35/36 symbols (GBPAUD still in-flight on T1). Full latest-row breakdown:

| Category | Count | Symbols |
|---|---|---|
| **False-positive PASS** | 2 | AUDCHF.DWX, EURNZD.DWX |
| NO_REAL_TICKS_MARKER (QUA-662) | 18 | GBPAUD, USDCHF, NZDCAD, AUDJPY, AUDUSD, UK100, CADCHF, EURUSD, GBPCAD, GBPJPY, GBPNZD, USDJPY, USDCAD, GBPUSD, GDAXIm, NZDCHF, NZDUSD, XTIUSD |
| Pure infra modal (residual) | 5 | AUDCAD, XAGUSD, EURJPY, GBPCHF, NZDJPY |
| MIN_TRADES_NOT_MET (clean) | 11 | AUDNZD, CADJPY, CHFJPY, EURAUD, EURCAD, EURCHF, EURGBP, NDXm, WS30, XAUUSD, XNGUSD |

**False-positive PASS finding:** Both AUDCHF and EURNZD show `verdict=PASS` in report.csv, but their summary.json files have `model4_log_marker_detected=False`, `total_trades=None`, `verdict=None`, and `reason_classes=['NO_REAL_TICKS_MARKER']`. Under DL-054 G1 (`model4_log_marker_detected=true` required), both are G1 INVALID. The tester log for EURNZD (run_01/20260506.log) shows the QM5_1017 EA running on EURNZD — the shared MT5 tester log was captured with overlapping session content. p2_baseline.py appears to write PASS when `verdict=None` without enforcing G1. This is a toolchain bug (CTO action required).

**Post-QUA-747 modal rate for QM5_1003:** 5/35 pure infra + 18/35 NO_REAL_TICKS = 23/35 failures. QUA-662 (broken tester read-access for imported DWX symbols) is the dominant root cause. The 5 residual pure infra failures (EURJPY, GBPCHF, NZDJPY, AUDCAD, XAGUSD) ran post-fix but still fail with REPORT_MISSING/TIMEOUT — likely QUA-662 manifestation where broken read-access causes tester hang rather than NO_REAL_TICKS marker.

**Updated Pipeline-Op action (supersedes prior list):**
1. QUA-662 (broken tester read-access on ~18 imported DWX symbols) must be resolved before QM5_1003 can produce valid smoke results
2. CTO to fix p2_baseline.py false-positive PASS: enforce G1 gate (`model4_log_marker_detected=true`) before writing PASS verdict to report.csv
3. After QUA-662 fix: clear QM5_1003 dedup (all 36 keys) and re-dispatch from scratch
4. QM5_1003 may have genuine ZT on some cross pairs once data is fixed — 11 clean MIN_TRADES symbols suggest strategy is selective by pair

---

## QM5_1004 — Infrastructure Fixed, Strategy ZT Revealed

**Original finding:** All 6 smoke P1 entries produced REPORT_MISSING/METATESTER_HUNG. Root cause: EA_MAGIC_NOT_REGISTERED on OnInit (magic_numbers.csv not deployed to tester). See `QT_FINDING_QM5_1004_ZT_ONINT_FAIL_2026-05-06.md`.

**ADDENDUM (post-QUA-747, 2026-05-06 ~09:30Z):** QUA-747 fix (`b935e03f`) deployed magic_numbers.csv and ea_id_registry.csv to all tester terminals. QM5_1004 re-smoked with full cohort (36 symbols).

**Post-fix results (36 symbols):**
- 35/36: `FAIL — MIN_TRADES_NOT_MET` | model4=True, det=True, total_trades=None
- 1/36 (EURAUD.DWX): `FAIL — REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS` (residual infra)

**Confirmed:** `model4_log_marker_detected=True` on all MIN_TRADES runs — OnInit succeeds, real ticks used. The magic registry fix is verified.

**New blocking issue — Strategy ZT:** 35/36 symbols including EURUSD, GBPUSD, USDJPY all produce 0 trades with real ticks. For a 20-bar breakout strategy, 0 trades on major pairs across H1 2024 is anomalous. Likely root cause: `QM_StopRulesReadATRValue()` returning false for DWX custom symbols in the tester context → `stop_distance=0.0` → `Strategy_EntrySignal` returns false on every bar → no entries ever staged. CTO investigation required.

**QT position:** Code review verdict (LIKELY AGREE from QUA-749) stands — the code logic is correct per card §3/§4. This is a runtime/config issue, not a code defect. The setfile gap (missing breakout_lookback, strategy_atr_period, atr_stop_mult params — card §4/§6) is secondary to the ZT root cause but must be resolved before any smoke result is meaningful.

---

## QM5_1009 (SRC04_S03) — Zero Trades + XAUUSD False-Positive NON_DETERMINISTIC

**Finding A — Zero trades:** All 5 smoke symbols produced 0 trades on both H1 and M15 2024. ZT root cause already on file: `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/ZT_RootCause_QM5_SRC04_S03_20260505.md`. Hypothesis: order_expiration_minutes=60 too short → stops expire before trigger. Proposed v2: increase to 240. Awaiting R-and-D signoff.

**QT position:** Code review AGREE stands (code is correct per DL-036). Zero-trade outcome is a strategy-parameter issue, not a code defect. v2 build should re-run full smoke after parameter adjustment.

**Finding B — NON_DETERMINISTIC false-positive:** XAUUSD H1 smoke flagged `deterministic=False` despite both runs showing identical stats (trades=0, pf=0.0, dd=0.0, netprofit=0.0). This appears to be a false-positive in `p2_baseline.py`'s determinism check — likely triggered by MT5 report HTML differences in a zero-trade session (timestamps, chart metadata) rather than real strategy variance.

**Required action:** Pipeline-Op / CTO to inspect the determinism check in p2_baseline.py: verify it compares extracted trade stats (trades/pf/dd/net_profit) rather than raw HTML. The SMAAtShift handle-per-call pattern noted in QT review remains non-blocking — no causal link to this false-positive confirmed.

---

## QM5_1017 — Smoke P1 Clean (Expected Zero Trades)

**Status: No action needed.** 3 smoke symbols all produced MIN_TRADES_NOT_MET with 0 trades (deterministic, expected for scaffold). AUDUSD had 2 prior infrastructure failures (REPORT_MISSING) before a clean deterministic run — consistent with QUA-747 toolchain state during dispatch. Zero-trade ADRs on file for all 36 symbols cover DL-054 G4.

---

## Summary for Pipeline-Op

| EA | Smoke P1 State | Action Required |
|---|---|---|
| QM5_1003 | 35/36 re-smoked post-QUA-747: 2 false-PASS, 18 NO_REAL_TICKS, 5 infra, 11 clean ZT | Fix QUA-662 + p2_baseline G1 bug + re-dispatch |
| QM5_1004 | Magic fix confirmed, 35/36 strategy ZT (no trades on EURUSD/GBPUSD/USDJPY) | CTO: investigate QM_StopRulesReadATRValue ZT root cause |
| QM5_1009 | 10/10 complete, 0 trades all symbols | v2 build per ZT root cause; fix NON_DET check |
| QM5_1017 | 3/3 complete, 0 trades (expected) | No action — ADRs cover G4 |

**QT Formal Recommendation:** Pipeline-Op should not advance QM5_1003 or QM5_1004 past smoke P1 until clean runs are on file. QM5_1009 advancement depends on R-and-D v2 signoff. QM5_1017 can advance under zero-trade ADR protocol.
