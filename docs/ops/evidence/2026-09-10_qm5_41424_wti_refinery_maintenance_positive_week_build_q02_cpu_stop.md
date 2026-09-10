# QM5_41424 WTI Refinery-Maintenance Positive-Week Reversion - Build And Q02 CPU Stop

Date: 2026-09-10

## Outcome

One new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, and compiled. Q02 was not enqueued because the binding
whole-host CPU admission window breached its exclusive 97% ceiling.

- Identity: QM5_41424 / `wti-refmaint-posweek-fade`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414240000`
- Signal: in February, March, September, or October, short after one strictly
  positive completed WTI week and exit at the next broker week
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen 3.5 ATR hard stop
- Compile work item: `ec65f795-ad77-465a-9620-93c35c7e2905`
- Compile verdict: `COMPILE_OK`; zero compiler errors/warnings; strict
  build-check PASS

## Source And Non-Duplicate Boundary

The source record combines official U.S. Energy Information Administration
refinery-maintenance seasonality with Yang-Goncu-Pantelous academic commodity-
reversal lineage. Neither source establishes the exact weekly WTI CFD rule.

Canonical dedup found no exact identity. `QM5_41421` shorts only after a
strictly negative maintenance-season week as continuation, so its state is
mutually exclusive with this positive-week fade. `QM5_41392` trades XNG,
uses different months, and is two-sided.

## Deterministic Build Evidence

- Card schema lint: PASS; prohibited-ML hits 0.
- Reference suite: 12/12 PASS.
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- The locked guard compares only strategy inputs, `qm_ea_id`,
  `qm_magic_slot_offset`, and fixed-risk mode. RNG/news/Friday-close inputs are
  not equality-pinned; stress rejection is range/finiteness-only.
- MQ5 SHA-256:
  `6c71c99d57084e78a219aa20df4348ae363a5aa27b12561f2fa53bb4725fcd7b`.
- EX5 SHA-256:
  `15e5522651c4562453dc849fccfd7dff7789386eb9074830aaa4a798e1e5bf59`.
- Final required-symbol-bound setfile SHA-256:
  `0157a36a7b2a813a26bdcf6b6877080dedcd17089a509f64fb7b5129244a19d9`.

The governed setfile generator emitted a blank `strategy_symbol`; it was
restored to the approved `XTIUSD.DWX` binding after compile without changing
the MQ5 or EX5. The compile build-check's three warnings concern optional card
inferences and do not change its PASS verdict.

## Binding Capacity Stop

The five whole-host CPU samples were 57.23%, 65.53%, 97.27%, 95.90%, and
95.02%. Average was 82.19%; maximum was 97.27%. Because the maximum was not
strictly below the exclusive 97% ceiling, no Q02 intake or backtest was
enqueued.

## Safety Boundary

No manual backtest, optimization, live/demo/shadow/stress preset, terminal
control, AutoTrading, `T_Live`, deploy/live manifest, portfolio gate,
portfolio admission, correlation waiver, or decorrelation claim was touched.
