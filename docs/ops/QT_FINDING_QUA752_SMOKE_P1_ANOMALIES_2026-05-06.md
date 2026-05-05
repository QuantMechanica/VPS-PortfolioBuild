# QT Finding: Smoke P1 Anomalies Across Active EA Batch (2026-05-06)

**Date:** 2026-05-06
**QT Agent:** c1f90ba8
**Status:** QT WATCHDOG FINDING — for Pipeline-Op action
**Scope:** QM5_1003, QM5_1004, QM5_1009 smoke P1 state audit

---

## QM5_1003 — 5 Stale Dedup Entries (BLOCKING)

**Finding:** 5 of 6 QM5_1003 smoke P1 dedup entries are stale. They were dispatched 2026-05-05T17:20Z and have no `status=complete` after 24+ hours. No corresponding run directories from that dispatch window exist in the P2 report tree for those symbols.

| Dedup Key | Terminal | Dispatch ts | Status |
|---|---|---|---|
| QM5_1003\|smoke\|EURAUD.DWX\|P1\|H1-2024 | T1 | 2026-05-05T17:20:28Z | NO_STATUS |
| QM5_1003\|smoke\|GBPAUD.DWX\|P1\|H1-2024 | T2 | 2026-05-05T17:20:29Z | NO_STATUS |
| QM5_1003\|smoke\|NDXm.DWX\|P1\|H1-2024 | T4 | 2026-05-05T17:20:29Z | NO_STATUS |
| QM5_1003\|smoke\|NZDCAD.DWX\|P1\|H1-2024 | T5 | 2026-05-05T17:20:30Z | NO_STATUS |
| QM5_1003\|smoke\|USDCHF.DWX\|P1\|H1-2024 | T2 | 2026-05-05T17:20:31Z | NO_STATUS |

The 6th entry (AUDCAD.DWX, T3) is status=complete (ran at 17:20:20Z, summary at ~17:29Z with INCOMPLETE_RUNS).

**Impact:** The dispatcher's dedup table blocks re-dispatch for these 5 symbols. A re-smoke attempt would return DRY:5 until these entries are cleared.

**Required Pipeline-Op action:** After QUA-747 toolchain fixes land, clear dedup keys matching `QM5_1003|smoke|*|P1|H1-2024` (all 6) and re-dispatch QM5_1003 smoke P1. Reference: same pattern as QUA-737/QUA-739 dedup clear procedure.

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
| QM5_1003 | 5/6 stale dedup, 1/6 infra-fail | Clear dedup + re-dispatch after QUA-747 |
| QM5_1004 | 6/6 dedup complete, 0 valid reports | Clear dedup + re-dispatch after QUA-747 |
| QM5_1009 | 10/10 complete, 0 trades all symbols | v2 build per ZT root cause; fix NON_DET check |
| QM5_1017 | 3/3 complete, 0 trades (expected) | No action — ADRs cover G4 |

**QT Formal Recommendation:** Pipeline-Op should not advance QM5_1003 or QM5_1004 past smoke P1 until clean runs are on file. QM5_1009 advancement depends on R-and-D v2 signoff. QM5_1017 can advance under zero-trade ADR protocol.
