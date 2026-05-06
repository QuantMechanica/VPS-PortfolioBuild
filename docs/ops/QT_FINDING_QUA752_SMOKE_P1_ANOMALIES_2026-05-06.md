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

---

## QM5_1004 — All Smoke P1 Runs Infrastructure Failures

**Finding:** All 6 QM5_1004 smoke P1 dedup entries show `status=complete`, but every underlying run produced `REPORT_MISSING` or `METATESTER_HUNG` (INCOMPLETE_RUNS). No clean tester output exists for QM5_1004 smoke P1.

Latest QM5_1004 p2_result.json: `PASS=0, FAIL=1, finished_at=2026-05-05T22:12:33Z`. All summary runs show REPORT_MISSING.

**Impact:** The smoke P1 "pass" in the dedup is a false completion — there are no valid backtest reports. QM5_1004 cannot advance through the pipeline without a clean smoke run.

**Context:** QUA-747 (P2 toolchain infra) is in_progress and likely will fix the REPORT_MISSING failure mode. QM5_1004 smoke dedup must be cleared and re-dispatched after QUA-747 resolves.

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
| QM5_1003 | 6/6 dedup complete, 0 valid reports (TIMEOUT+NO_REAL_TICKS) | Clear dedup + verify real tick data + re-dispatch after QUA-747 |
| QM5_1004 | 6/6 dedup complete, 0 valid reports | Clear dedup + re-dispatch after QUA-747 |
| QM5_1009 | 10/10 complete, 0 trades all symbols | v2 build per ZT root cause; fix NON_DET check |
| QM5_1017 | 3/3 complete, 0 trades (expected) | No action — ADRs cover G4 |

**QT Formal Recommendation:** Pipeline-Op should not advance QM5_1003 or QM5_1004 past smoke P1 until clean runs are on file. QM5_1009 advancement depends on R-and-D v2 signoff. QM5_1017 can advance under zero-trade ADR protocol.
