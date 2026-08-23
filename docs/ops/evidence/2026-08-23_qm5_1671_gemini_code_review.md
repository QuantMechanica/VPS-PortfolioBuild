# QM5_1671 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `58c58dcb-4fbe-4da7-a3b1-365334a7ef77`

Source task: `4a5c9ed6-20b8-47e3-91d3-1aa4e51d4385` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_1671_ehlers-ebsw-cycle-extract-composite-h4/build_identity.json`

Verdict: **REQUEST_CHANGES — wrong cycle primitive and ineffective period gate; do not promote to PIPELINE**

## Findings

### 1. Critical — the implementation is not the approved fixed 4-tap Hilbert transform

The approved card binds both cycle extraction and EBSW phase to an Ehlers fixed 4-tap FIR Hilbert-transform analytic signal. The EA computes quadrature as only:

```mql5
quad0 = (filt[0] - filt[4]) / 4.0;
quad1 = (filt[1] - filt[5]) / 4.0;
```

This two-point centered difference is not the named 4-tap FIR Hilbert transform. It changes phase, amplitude, phase unwrap, inferred period, zero crossings and every downstream decision. The same substitution is used for the EBSW component.

Required correction: implement the approved fixed coefficient/tap transform and verify amplitude, phase and period against deterministic reference vectors from the named Ehlers primitive.

### 2. Critical — the mandatory outside-band rejection can never fire

The card requires an unqualified signal when the extracted period lies outside `[10, 48]`. The EA first clamps every raw period into that range and only then evaluates:

```mql5
period_ok = (g_cycle_period >= strategy_period_min &&
             g_cycle_period <= strategy_period_max);
```

That condition is tautologically true. A too-short or too-long cycle is relabeled as exactly 10 or 48 and admitted. An invalid/near-zero phase delta is also replaced with period 20 rather than marked unavailable.

Required correction: retain raw-period validity separately, reject unavailable/out-of-band observations, and clamp only presentation values—never the admission value.

### 3. Critical — the time stop is not bound to the period extracted at entry

The approved card explicitly says `1.5 × cycle_period` where the period was extracted at entry. `Strategy_ExitSignal()` instead uses the current global `g_cycle_period`, which is recalculated on each closed bar. The stop therefore expands or contracts after entry. A restart resets the global to 20 and loses the entry contract entirely.

Required correction: seal the entry period into durable position-associated provenance and use that immutable value for the position's complete lifetime.

### 4. High — news blackout suppresses all risk exits and state progression

`OnTick()` returns on `!news_allows` before Friday close, spread/state advance, open-position management, amplitude-collapse counting and `Strategy_ExitSignal()`. A news pause therefore becomes an exit pause. It can also lose closed-bar observations required for the three-consecutive-bar amplitude-collapse rule.

Required correction: keep news blackout mandatory for new entries while allowing Friday close, risk management, strategy exits and closed-bar exit-state accounting.

### 5. High — H4 scope is not enforced

Indicator data is H4, but `QM_IsNewBar()` follows the chart timeframe and no H4 initialization guard exists. A non-H4 chart can evaluate the same cached H4 cross on the wrong execution clock.

Required correction: fail closed outside H4 or bind the execution clock explicitly to H4.

### 6. Medium — cooldown advances before order acceptance and is restart volatile

Direction/time globals are updated before `QM_TM_OpenPosition()` succeeds. A rejected order consumes cooldown, while a restart clears it. Update cooldown from confirmed entry evidence and make it recoverable.

## Checks that passed

- The approved card exists with `g0_status: APPROVED`; the EA-local card copy matches the reviewed mechanics.
- EA registry row `1671 / ehlers-ebsw-cycle-extract-composite-h4` is active.
- Thirteen active magic rows and thirteen corresponding H4 setfiles exist.
- All 13 backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_build_guardrails.py framework/EAs/QM5_1671_ehlers-ebsw-cycle-extract-composite-h4`: `PASS`, 14 files, zero findings, `max_news_stale_hours=336`.
- MQ5 SHA-256 matches `build_identity.json`: `b9808e004e82b6bce626cb7c6f881b3fa5e6d4b53f44e673bb42a04a44102a21`.
- EX5 SHA-256 matches `build_identity.json`: `18a2492edf2f67d554f59e2b34add3be48d383a3afc1ca72d97f527cd35ee4b5`.
- Roofing filters, amplitude/ATR gate, D1 regime filter, bar-count helper, spread gate, request initialization and MAE hook are present.
- No ML, martingale or grid logic is present.

These checks establish artifact consistency and baseline hardening only. They do not establish the approved Ehlers composite and are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict or trade stream was changed by this review. `T_Live` and AutoTrading were not touched. The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a fresh mandatory Codex review before any acceptance or enqueue.
