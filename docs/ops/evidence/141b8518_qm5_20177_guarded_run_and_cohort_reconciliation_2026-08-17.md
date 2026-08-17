# QM5_20177 Guarded Run Enqueue, Full-Geometry Positive Test & Cohort Reconciliation — 2026-08-17

**Task ID:** `141b8518-0be0-4c1d-87a3-3e8a2f20e14b` (priority 80, `build_ea`, agent `gemini`).  
**EA:** `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`.  
**Review Reference:** `ebc92749-1481-4485-94ae-c4850e86a343` (Codex review of fix commit `24e5bb90ac7a1f430abe1879a67fba6c638baa75`).  
**Artifact Path:** `docs/ops/evidence/141b8518_qm5_20177_guarded_run_and_cohort_reconciliation_2026-08-17.md`.

---

## 1. Executive Summary

This evidence artifact comprehensively addresses all blocking findings and new deliverables established in Codex review `ebc92749` and Claude review `review_close_verdict`:

1. **Governed Single-Symbol Q02 Backtest Enqueued (USDJPY)**:
   - Enqueued append-only Q02 canary work item `af79d508-0959-4a93-bd2d-f3178a68f633` for `USDJPY.DWX` bound to the current guarded EX5 binary (`8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796`), exactly preserving historical predecessor `c7f7a083-837c-470e-9501-fec5eb566f28`.
   - Re-qualification cost is strictly capped to this single symbol to prevent compute waste across the full 6-symbol matrix while verifying the mathematical derivation.
2. **Reconciled Ground-Truth Q02 Trade Population**:
   - Replaced the previously mislabeled distribution with verified ground truth directly extracted from the 6 canonical Q02 `summary.json` receipts.
   - All 42 historical trades across the 6 symbols resulted in $0.00$ profit factor due to immediate 0–8s partial and full closes against unanchored pre-entry geometric projections.
3. **Full-Geometry Positive Simulation Test**:
   - Upgraded `tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py` to model the complete mathematical and geometric execution path of `Strategy_EntrySignal` (D1 RSI regime, spread filter, fractal pivot identification, $BC/AB$ ratio, bar length bounds $[3, 60]$, $CD$ time-symmetry, $D_{proj}$ calculation, touch tolerance, confirmation close, cooldown tracking, and $T_1$ guard).
   - Proven that when complete geometry is satisfied with $AB < 1.3089 \times ATR14$ (leaving room to $T_1$), the signal is **ACCEPTED**; when standard macro swings or confirmation overshoot place $T_1$ behind fill, the signal is **REJECTED**.
   - Static test suite passes **3/3 in 0.28s**.
4. **Reproducible & Complete Cohort Audit (255 EAs, 1 Defective Instance)**:
   - Generated a machine-readable audit (`docs/ops/evidence/2026-08-17_pattern_harmonic_cohort_complete_audit.json`) scanning all **3,624 EAs** in the repository.
   - 255 pattern/harmonic/wave/Fibonacci/reversal EAs were categorized; explicitly enumerated previously omitted EAs (`QM5_11891`, `QM5_11892`).
   - Confirmed that across the entire 3,624 EA repository, `QM5_20177` is the **sole isolated instance** carrying unanchored geometric target management.

---

## 2. Reconciled Q02 Ground-Truth Population

The 42-trade population from the pre-fix Q02 backtest run (EX5 SHA-256 `1a2f22d4edc56afdbabd403bda0bc330c0667f7c3e859b9dc3f7c5689d5e1f09`) is verified from canonical summary files:

| Symbol | Pre-Fix Trades | Pre-Fix Verdict | Pre-Fix PF | Work Item ID | Summary Path |
|---|---:|---|---:|---|---|
| **USDJPY.DWX** | **8** | FAIL | 0.00 | `c7f7a083-837c-470e-9501-fec5eb566f28` | `D:\QM\reports\work_items\c7f7a083-837c-470e-9501-fec5eb566f28\QM5_20177\20260816_181004\summary.json` |
| **GBPUSD.DWX** | **6** | FAIL | 0.00 | `ba38e217-fc92-4265-8678-f6c910f898e8` | `D:\QM\reports\work_items\ba38e217-fc92-4265-8678-f6c910f898e8\QM5_20177\20260816_180825\summary.json` |
| **EURUSD.DWX** | **8** | FAIL | 0.00 | `cd946f00-aa75-4d11-b119-1cd2a2e51d90` | `D:\QM\reports\work_items\cd946f00-aa75-4d11-b119-1cd2a2e51d90\QM5_20177\20260816_175114\summary.json` |
| **WS30.DWX** | **14** | FAIL | 0.00 | `a0c57304-3d83-4e02-a414-3561736f0eb5` | `D:\QM\reports\work_items\a0c57304-3d83-4e02-a414-3561736f0eb5\QM5_20177\20260816_172303\summary.json` |
| **XAUUSD.DWX** | **6** | FAIL | 0.00 | `90c7c269-8038-4c9c-8bbf-e8747bf4ea32` | `D:\QM\reports\work_items\90c7c269-8038-4c9c-8bbf-e8747bf4ea32\QM5_20177\20260816_123741\summary.json` |
| **NDX.DWX** | **0** | ZERO_TRADES | 0.00 | `cd2f56fd-ae3f-4ab0-a875-fbc77c09dc66` | `D:\QM\reports\work_items\cd2f56fd-ae3f-4ab0-a875-fbc77c09dc66\QM5_20177\20260816_133325\summary.json` |
| **Total** | **42** | | | | |

*Clarification on previous presentation error:* In the prior draft, the per-symbol labels for EURUSD (8), WS30 (14), XAUUSD (6), and NDX (0) were transposed as (6, 8, 0, 14) during table transcription. The verified counts above match the on-disk summary json records with 100% precision.

---

## 3. Governed Single-Symbol Backtest Enqueue

To satisfy Deliverable 1 from Claude's review without burning multi-symbol compute:

- **Target Symbol:** `USDJPY.DWX` (densest pre-fix trade population among FX majors: 8 trades).
- **Enqueued Successor Work Item ID:** `af79d508-0959-4a93-bd2d-f3178a68f633`.
- **Predecessor Work Item ID:** `c7f7a083-837c-470e-9501-fec5eb566f28` (preserved append-only).
- **Bound Current EX5 SHA-256:** `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796`.
- **Bound Current MQ5 SHA-256:** `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71`.
- **Bound Setfile SHA-256:** `20e75b585034f0af6e1b6c0b3b16aaf9d50c1eb10b2abc3519c999e72fdb584b`.
- **Risk Contract:** `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.
- **Enqueue Invocation:**
  ```powershell
  python tools/strategy_farm/farmctl.py enqueue-backtest `
    --ea QM5_20177 `
    --phase Q02 `
    --from-work-item-id c7f7a083-837c-470e-9501-fec5eb566f28 `
    --append-only-rerun-of c7f7a083-837c-470e-9501-fec5eb566f28 `
    --rerun-reason "repaired_early_target_at_fill_defect_task_141b8518" `
    --expected-current-ex5-sha256 8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796
  ```

---

## 4. Full-Geometry Positive Simulation Test

The static test suite in `tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py` was upgraded to implement a full mathematical simulation function `simulate_strategy_entry_signal()`.

### 4.1 Inputs & Rules Tested
1. **Regime & Filters:** D1 RSI $\in [30, 70]$, Spread $\le 0.35 \times ATR14$.
2. **Fractal Structure:** 3 alternating pivots $A, B, C$ ($C>A, B>A$ for long; $C<A, A>B$ for short).
3. **Ratio & Rhythm:** $BC/AB \in [0.382, 0.886]$, $ab\_bars \in [3, 60]$, $cd\_bars \ge 1$, time symmetry $\le 30\%$.
4. **Touch & Confirmation:** $c_2$ low/close $\in [D_{proj} \pm 0.5 \times ATR14]$, $c_1.close > c_2.high$ (long).
5. **Cooldown:** $bars\_since\_long > 18$.
6. **Target Guard:** $Ask < T_1 = D_{proj} - 0.382 \times (B - A)$ (long).

### 4.2 Test Cases Pinned
- **Bullish Positive Case:** $AB = 1.0 \times ATR14 < 1.3089 \times ATR14$, $A=100.0, B=110.0, C=104.0, D_{proj}=114.0, T_1=110.18$. Touch bar $c_2 \in [109.0, 119.0]$ (low 109.5, high 109.8), confirmation bar $c_1.close = 109.9 > 109.8$, $Ask = 110.00 < 110.18$. Result: **ACCEPTED** (`touch_ok=True, confirm_ok=True, t1_ok=True, cooldown_ok=True`).
- **Bullish Defective Case:** $AB = 5.0 \times ATR14$, $A=100.0, B=150.0, C=120.0, D_{proj}=170.0, T_1=150.90$. Touch bar $c_2$ low 166.0, high 169.0, confirmation $c_1.close = 169.5$, $Ask = 169.60 > 150.90$. Result: **REJECTED** (`t1_ok=False`).
- **Bearish Positive Case:** $AB = 1.0 \times ATR14$, $A=120.0, B=110.0, C=116.0, D_{proj}=106.0, T_1=109.82$. Touch bar $c_2$ high 110.5, low 110.2, confirmation $c_1.close = 110.0 < 110.2$, $Bid = 110.00 > 109.82$. Result: **ACCEPTED** (`touch_ok=True, confirm_ok=True, t1_ok=True`).

### 4.3 Test Execution
```text
python -m pytest tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py -v
============================= test session starts =============================
tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py::test_qm5_20177_entry_signal_rejects_early_target_at_fill PASSED [ 33%]
tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py::test_qm5_20177_full_geometry_positive_acceptance_and_rejection PASSED [ 66%]
tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py::test_qm5_20177_build_guardrails_compliance PASSED [100%]
============================== 3 passed in 0.28s ==============================
```

---

## 5. Reconciled Cohort Audit (255 EAs Enumerated)

A comprehensive Python audit script scanned all **3,624 EAs** in `framework/EAs/` against keywords (`pattern`, `harmonic`, `wave`, `fib`, `abcd`, `gartley`, `butterfly`, `bat`, `cypher`, `drive`, `crab`, `shark`, `5-0`, `demark`, `sperandeo`, `123`, `goodman`, `unger`, `samuels`, `pesavento`, `carney`, `elliott`, `zigzag`, `sinewave`, `ttm`, `differential`).

The full machine-readable inventory is saved at `docs/ops/evidence/2026-08-17_pattern_harmonic_cohort_complete_audit.json`.

### 5.1 Cohort Breakdown Summary

| Category | Description | Count | Defect Exposure |
|---|---|---:|---|
| **Category 1** | Empty `Strategy_ManageOpenPosition()`, fixed broker SL/TP at entry, ATR trailing stops, or bar-count time stops without target levels. Includes previously omitted `QM5_11891` (pending-order housekeeping) and `QM5_11892` (time-stop only). | **231** | Immune |
| **Category 2** | Position management targets anchored directly to `PositionGetDouble(POSITION_PRICE_OPEN)` / live entry price. | **18** | Immune |
| **Category 3** | Signal-time target room validation or breakout-driven geometry. | **5** | Immune |
| **Category 4** | Unanchored geometric target projection compared to live bid/ask without fill validation. | **1** | **Defective** (`QM5_20177`) |
| **Total Pattern Cohort** | | **255** | |

### 5.2 Whole-Repository Audit (All 3,624 EAs)
Across all 3,624 EAs in `framework/EAs/`, exactly **1 EA** (`QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`) computes management targets from pre-entry projection variables without referencing `POSITION_PRICE_OPEN`.

---

## 6. Build Guardrails, Verification & Artifact Hashes

| File | SHA256 Hash | Status |
|---|---|---|
| `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5` | `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71` | Clean (0E/0W) |
| `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.ex5` | `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796` | Bound |
| `tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py` | `111cd88c6eb1d46fd3cf06ccc934ed442de96f364da4ea060812d7a159c5fb0e` | 3/3 PASSED |
| `docs/ops/evidence/2026-08-17_pattern_harmonic_cohort_complete_audit.json` | `513cb0606e414838a398a787e8ab3ca44302b65c87be934ffcbd234772a36f59` | Generated |

- `validate_build_guardrails.py`: **PASS** (`max_news_stale_hours = 336`, `RISK_FIXED = 1000`, `RISK_PERCENT = 0`).
- `pytest tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py`: **3 passed in 0.28s**.

---

## 7. Disposition & Hand-Off

- **Router Task ID:** `141b8518-0be0-4c1d-87a3-3e8a2f20e14b`
- **Assigned State:** `REVIEW` (per Hard Rule: Gemini code tasks remain in `REVIEW` for Codex/Claude audit; no self-approval or movement to `PIPELINE`).
- **Verdict:** `GUARDED_RUN_ENQUEUED_AND_FULL_GEOMETRY_TEST_PINNED`
- **Next Steps:**
  1. Let the paced terminal worker finish the single-symbol USDJPY Q02 canary `af79d508-0959-4a93-bd2d-f3178a68f633`.
  2. If the guarded canary confirms 0 or near-0 trades as derived, proceed with the card-level amendment (Option 1: anchoring targets to `POSITION_PRICE_OPEN` + $R$-multiples) as outlined by Claude.
