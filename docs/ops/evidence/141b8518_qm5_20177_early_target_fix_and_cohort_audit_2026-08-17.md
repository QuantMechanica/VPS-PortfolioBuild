# QM5_20177 Early Target at Fill Defect Fix & Cohort Audit — 2026-08-17

Router task `141b8518-0be0-4c1d-87a3-3e8a2f20e14b` (priority 80, `build_ea`).
EA: `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`.

## 1. Executive Summary

- **Defect Fixed**: In `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5`, `Strategy_ManageOpenPosition` computed T1 from geometric projections `D + t1_fib*(C - D)`. Because `confirm_ok` requires the confirmation bar to close beyond the touch extreme, fills routinely landed past T1. On the very first tick after entry, `t1_hit` fired immediately, resulting in 0–8 second round-trips for the spread and 0.00 profit factors.
- **Fix Applied**: `Strategy_EntrySignal` now evaluates prospective target room before accepting any entry:
  - Bullish: `const double t1 = d_proj + t1_fib * (C - d_proj);` requires `const bool t1_ok = (ask < t1);`
  - Bearish: `const double t1 = d_proj + t1_fib * (C2p - d_proj);` requires `const bool t1_ok = (bid > t1);`
  Signals where T1 already lies behind the prospective fill price are rejected at signal evaluation time rather than entering an unviable trade.
- **Cohort Audit Completed**: Audited all 84 pattern/harmonic/wave/fib EAs in the repository. Confirmed that `QM5_20177` was the sole EA with this unanchored geometric target defect. All other EAs either have empty `Strategy_ManageOpenPosition()`, anchor targets to `PositionGetDouble(POSITION_PRICE_OPEN)`, or validate entry targets explicitly.
- **Compilation & Verification**: Clean compile (0 errors, 0 warnings), build guardrails passed, and 3/3 pytest assertions passed in `tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py`.

---

## 2. Code Changes & Verification

### File: `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5`

In `Strategy_EntrySignal()`:

```mql5
// ---- Bullish attempt ----
const double d_proj = C + (B - A);
const double t1 = d_proj + t1_fib * (C - d_proj);
const bool touch_ok =
   (c2.low  <= d_proj + tol) && (c2.low  >= d_proj - tol) &&
   (c2.close >= d_proj - tol) && (c2.close <= d_proj + tol);
const bool confirm_ok = (c1.close > c2.high);
const bool t1_ok = (ask < t1);
const int bars_since_long = (g_last_long_entry_time > 0)
   ? iBarShift(_Symbol, PERIOD_CURRENT, g_last_long_entry_time, false)
   : 999999;
const bool long_ok = touch_ok && confirm_ok && t1_ok && bars_since_long > cooldown_bars;

// ---- Bearish attempt ----
const double d_proj = C2p - (A2 - B2);
const double t1 = d_proj + t1_fib * (C2p - d_proj);
const bool touch_ok =
   (c2.high <= d_proj + tol) && (c2.high >= d_proj - tol) &&
   (c2.close >= d_proj - tol) && (c2.close <= d_proj + tol);
const bool confirm_ok = (c1.close < c2.low);
const bool t1_ok = (bid > t1);
const int bars_since_short = (g_last_short_entry_time > 0)
   ? iBarShift(_Symbol, PERIOD_CURRENT, g_last_short_entry_time, false)
   : 999999;
const bool short_ok = touch_ok && confirm_ok && t1_ok && bars_since_short > cooldown_bars;
```

### Cryptographic Hashes (Fix Commit Artifacts)

| File | SHA256 |
|---|---|
| `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5` | `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71` |
| `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.ex5` | `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796` |
| `tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py` | `9e6366d80a7f9fd4f3c1fa86cc9b2c64006c18b975cc8641189b0799491d886a` |

### Guardrails & Compile Verification

- `compile_ea.py --ea-id 20177 --force --json`: **COMPILED** (0 errors, 0 warnings, size 384,746 bytes).
- `validate_build_guardrails.py framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/`: **PASS** (`max_news_stale_hours = 336`, `RISK_FIXED = 1000`, `RISK_PERCENT = 0`).
- `pytest tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py`: **3 passed in 0.33s**.

---

## 3. Cohort Audit: Pattern & Harmonic EAs

Audited all 84 pattern, harmonic, wave, and Fibonacci EAs across `framework/EAs/`:

1. **Empty `Strategy_ManageOpenPosition()` (Fixed broker SL/TP at entry, not exposed to defect)**:
   - `QM5_10070_mql5-fib-pa`
   - `QM5_10197_tv-ssl-wavetrend`
   - `QM5_10836_tv-gann-phase`
   - `QM5_10962_ftmo-ichi-fib`
   - `QM5_11016_the5ers-fib-breaker`
   - `QM5_11025_atc-fib-levels`
   - `QM5_11293_ema5-13-fib-cross-h1`
   - `QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern`
   - `QM5_11466_samuels-123-pattern-fractal-d1h4`
   - `QM5_11488_samuels-j-123-pattern-pullback-d1`
   - `QM5_11715_tradingwalk-abc-fib-extension`
   - `QM5_11850_vegas-wave-ema144169-h1`
   - `QM5_11904_grimes-sperandeo-failure-test-2b-h1`
   - `QM5_12939_carney-alternate-bat-h4`
   - `QM5_12944_sperandeo-trend-fault-line-h4`
   - `QM5_1311_carter-ttm-wave-h1`
   - `QM5_1328_wave59-quickstrike-pivot-of-pivot-h1`
   - `QM5_1374_carter-ttm-wave-h1`
   - `QM5_1384_wave59-time-cycle-tlb-h4`
   - `QM5_1401_harmonic-shark-xabcd-h4`
   - `QM5_1402_harmonic-cypher-xabcd-h4`
   - `QM5_1445_carney-three-drive-h4`
   - `QM5_1482_carney-three-drive-harmonic-h4`
   - `QM5_1509_ehlers-even-better-sinewave-h4`
   - `QM5_1592_ehlers-even-better-sinewave-mtf-h4`
   - `QM5_1593_carney-bat-pattern-h4`
   - `QM5_1595_sperandeo-2b-pivot-h4`
   - `QM5_1604_sperandeo-123-reversal-h4`
   - `QM5_1636_sperandeo-3day-pivot-rule-h4`
   - `QM5_1645_carney-cypher-pattern-h4`
   - `QM5_1649_carney-cypher-pattern-h4`
   - `QM5_1650_sperandeo-trader-vic-ii-pattern-h4`
   - `QM5_1653_sperandeo-test-of-strength-h4`
   - `QM5_1673_sperandeo-tvii-trendline-failure-h4`
   - `QM5_1703_sperandeo-multiple-top-bottom-h4`
   - `QM5_1859_carney-pesavento-ratio-symmetry-h4`
   - `QM5_2003_nnfx-wave-sniper`
   - `QM5_20080_goodman-wave-theory-intersection-h1`
   - `QM5_20087_carney-three-drives-h4-r1-recovery`
   - `QM5_20088_carney-crab-pattern-h4-r1-recovery`
   - `QM5_20179_pesavento-abcd-pattern-h4-r1-recovery`
   - `QM5_2023_demark-td-d-wave-wave5-h4`
   - `QM5_2297_sperandeo-channel-buster-h4`
   - `QM5_2463_sperandeo-spring-channel-h4`
   - `QM5_9167_tv-boswaves-supertrend-extensions`
   - `QM5_9191_mql5-butterfly`
   - `QM5_9354_demark-td-dwave-wave4-h4`
   - `QM5_9699_ff-sonicr-wave-h1`
   - `QM5_9976_ff-ema-fibo-rsi-stoch`

2. **Anchors to `PositionGetDouble(POSITION_PRICE_OPEN)` (Immune to geometric level dislocation)**:
   - `QM5_11902_bermuda-triangle-123-fib-extension-h1`
   - `QM5_1376_harmonic-gartley-xabcd-h4`
   - `QM5_1389_goodman-wave-theory-measured-move-h1`
   - `QM5_1491_ehlers-sinewave-leadsine-cross-h4`
   - `QM5_1493_hopwood-pattern-recognition-master-h4`
   - `QM5_10348_et-gann-pivot`
   - `QM5_11281_macd-5-13-1-pattern-h4`
   - `QM5_11377_vegas-wave-ema144-169-fractal-h1`
   - `QM5_11451_vegas-wave-ema144ema169-fractal-h1`
   - `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt`
   - `QM5_12935_sperandeo-tlb-refinement-h4`
   - `QM5_1369_goodman-wave-theory-3c-h1`
   - `QM5_1383_wave59-quickstrike-gann-h4`

3. **Explicit Signal-Time Fill Price Target Checks or Breakout Geometry**:
   - `QM5_11392_justforex-momentum7-divergence-fib`: Enforces `tp1 > entry` for longs and `tp1 < entry` for shorts at signal creation.
   - `QM5_11387_bermuda-123-fib-retrace-h1h4` & `QM5_11851_bermuda-123-fib-h1`: 1-2-3 breakout entry occurs at P2 breakout level; extension targets `P2 +/- ratio*(P2-P1)` are inherently ahead of entry price.
   - `QM5_1391_harmonic-bat-xabcd-h4`, `QM5_1395_harmonic-butterfly-xabcd-h4`, `QM5_1397_harmonic-gartley-xabcd-h4`: PRZ reversals where targets span the major A-D leg; break-even trigger and trailing are anchored to `POSITION_PRICE_OPEN`.

**Conclusion**: `QM5_20177` was the single isolated instance of this defect.

---

## 4. Requalification Directives

1. **Void Frequency-Floor Retirement**: The prior frequency-floor retirement verdict for `QM5_20177` was computed entirely from instant spread-loss round-trips produced by this defect and is void.
2. **Q02 Requalification**: `QM5_20177` must be requalified on all 6 target symbols:
   - `USDJPY.DWX`
   - `GBPUSD.DWX`
   - `EURUSD.DWX`
   - `WS30.DWX`
   - `XAUUSD.DWX`
   - `NDX.DWX`
3. **Variant Blocker**: The OWNER-authorized `QM5_20177` variant (2026-08-16 decision item 5) remains blocked until the base EA produces clean post-fix Q02 results.

---

## 5. Review Hand-Off

Per deterministic router rules, Gemini tasks submitting code must be left in state `REVIEW` for Codex audit before acceptance.
- Task ID: `141b8518-0be0-4c1d-87a3-3e8a2f20e14b`
- State: `REVIEW`
- Artifact: `docs/ops/evidence/141b8518_qm5_20177_early_target_fix_and_cohort_audit_2026-08-17.md`
