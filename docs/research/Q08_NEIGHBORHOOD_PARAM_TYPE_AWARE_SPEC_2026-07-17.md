# Q08 Neighborhood / PBO — parameter-type-aware perturbation spec (2026-07-17)

**Origin:** OWNER, 2026-07-17. Rule refinement: *a neighborhood (robustness) FAIL is NOT an
accepted soft-fail — it disqualifies.* Corollary raised by OWNER: a ±10% numeric perturbation is
**meaningless for non-continuous parameters** ("man kann einen Wochentag nicht um 10% schieben").
Therefore an `INVALID` neighborhood that comes from perturbing the *wrong kind of parameter* must
not be read as either a pass or a fail — it is a **test defect** to be fixed, and the parameter
excluded from ±10% perturbation.

## Evidence — QM5_13117 EURGBP/AUDJPY cointegration (the trigger case)

Neighborhood run perturbed 7 params ±10% (archived: `…\Q08\neighborhood\…\perturbations.stale_*.json`).
Only **2 of 14** perturbations produced any trades — **both `strategy_atr_period_d1`**, and there the
EA was **robust** (PF 1.41 / 1.44, 180 trades). Every other perturbation returned **0 trades**:

| param | class | ±10% result | correct handling |
|---|---|---|---|
| `strategy_atr_period_d1` (20) | continuous tuning knob | **PF 1.41/1.44, 180 tr — robust** | ✅ perturb ±10% (works today) |
| `strategy_beta` (−0.1220) | **fitted cointegration hedge ratio** | 0 trades (spread no longer stationary) | ❌ never ±10%; re-fit or exclude |
| `strategy_entry_z` (2.0) | continuous tuning knob | 0 trades (impossible → regen broke) | ✅ should perturb; **regen bug** |
| `strategy_exit_z` (0.5) | continuous tuning knob | 0 trades (regen broke) | ✅ should perturb; **regen bug** |
| `strategy_z_lookback_d1` (60) | continuous tuning knob | 0 trades (regen broke) | ✅ should perturb; **regen bug** |
| `strategy_atr_sl_mult` (2.0) | continuous tuning knob | 0 trades (regen broke) | ✅ should perturb; **regen bug** |
| `strategy_deviation_points` (20) | continuous tuning knob | 0 trades (regen broke) | ✅ should perturb; **regen bug** |

Two distinct defects are visible in one run:

1. **Structural / fitted parameter mis-perturbation** (OWNER's point). `strategy_beta` is a *measured*
   regression slope between the two legs, not a free knob. A ±10% shift destroys cointegration → 0
   trades. Same class as day-of-week, month, session-hour, N-trading-days, pair selection: **not
   continuously perturbable.**

2. **Setgen perturbation-regen is broken** (the dominant bug here). Legitimate continuous knobs
   (`entry_z`, `exit_z`, `z_lookback`, `sl_mult`, `deviation_points`) all returned 0 trades — impossible
   if the regenerated setfile were correct (a *lower* `entry_z` must yield *more* trades, not zero). The
   setfile regeneration drops/empties params (the known setgen-param-empty class). Only `atr_period`
   survived regen.

Net: 13117's robustness is **unmeasurable** from this run. Its `INVALID` is 100% a test defect, not a
merit signal. On the single param that was actually testable, it passed.

## Required fix (deliverable for Codex — task 032d28e1, priority 90)

The Q08 neighborhood + PBO perturbation engine must become **parameter-type-aware**:

**A. Classify each param before perturbing** (from the EA's input metadata / setfile):
- **continuous tuning knob** (period, multiplier, threshold, z-band, lookback, ATR mult, points) →
  perturb ±10% (round to the input's step/`stepsize`; if integer, use ±1 minimum so the perturbation is
  real, not a no-op rounding back to baseline).
- **discrete / ordinal calendar param** (day-of-week, month, session hour, N-trading-days, window
  days-before/after) → perturb by **±1 lattice step**, never ±%.
- **structural / fitted coefficient** (cointegration `beta`, regression slopes, PCA loadings) → **exclude
  from perturbation** OR re-fit on the perturbed sub-sample; a naïve ±% is invalid and must not count as a
  breach.
- **fixed infra params** (RISK_FIXED, magic, portfolio weight, news flags) → never perturbed (already so).

**B. A perturbation that yields 0 trades (or an empty/invalid setfile) is an INVALID PERTURBATION,
not a robustness breach.** Drop it from the breach test and log it as a regen defect; if *all*
continuous-knob perturbations come back 0-trade, the neighborhood verdict is `INVALID` (tooling), never
`FAIL`. Fix the regen so ±10% on a real knob produces a setfile that trades.

**C. Verdict semantics under the OWNER rule:**
- neighborhood **FAIL** (a *valid* perturbation on a *legitimate* knob breaches the DD/robustness
  ceiling, e.g. QM5_10476 `strategy_ao_slow_period −10%` → DD ratio 1.589) → **blocks** (not soft).
- neighborhood **INVALID** (no valid perturbation set could be built) → **not admissible until resolved**;
  route as tooling, do not admit on it.
- neighborhood **PASS** (≥2 valid perturbations on real knobs, none breaching) → clears 8.5.

**D. PBO (8.7)** needs ≥2 distinct valid configs. 13117 had `n_configs=1` (source `work_items.Q03`).
Use the same param-type-aware perturbed configs (or Q03/Q04 config history) to reach ≥2; if a strategy
genuinely exposes <2 distinct configs (pure-calendar), mark 8.7 `INVALID_NA` (structurally
inapplicable), not a vacuous PBO.

## Validation targets
- **QM5_13117** — expect PASS-shaped neighborhood once only `atr_period/entry_z/exit_z/z_lookback/sl_mult`
  are perturbed (beta excluded) and regen is fixed.
- **QM5_13301 (DE40)** — re-run must produce a non-null baseline + valid perturbations.
- **QM5_10513** — resolve degenerate baseline.
- **QM5_10476** — regression check: must still FAIL (its breach is a *valid* one — the reference for a
  true neighborhood fail).

## Downstream note — turn-of-month index EA (in build)
The turn-of-month card's params are **calendar-discrete** (window days-before/after, exit-day N). Under
this spec they must be perturbed by ±1 lattice step, never ±%. Flag on that EA's Q08 so it is not
mis-INVALIDed the way 13117 was.
