# QM5_41423 WTI Fresh Two-Week Streak Reversion - Build And Q02 Handoff

Date: 2026-09-10

## Outcome

A new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, compiled, and handed to one paced Q02 row.

- Identity: QM5_41423 / `wti-wstreak2-fade`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414230000`
- Signal: after a fresh two-week same-sign streak with an opposite predecessor,
  trade opposite the newest streak sign for one broker week
- Lifecycle: first new-week attempt, frozen 3.5 ATR stop, next-week close
- Compile work item: `49537786-e298-4eef-87d5-645a57def313`
- Q02 work item: `f3a0a713-9280-4db5-8a78-af8f0fee1006`, pending

## Source And Non-Duplicate Boundary

Yang, Goncu, and Pantelous provide academic commodity-reversal lineage.
Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, provide a complete published-paper record and
explicit WTI membership. Neither source establishes the exact weekly fade.

The canonical scan found no exact identity across 4,903 registry rows, 1,513
cards, and 45 Strategy Wiki nodes. Manual review separates the disjoint
five-endpoint fresh three-week fade (`QM5_41415`), the directionally opposite
two-week continuation (`QM5_41419`), and month-gated seasonal siblings.

## Deterministic Evidence

- Card schema lint: PASS; prohibited-ML hits 0.
- Reference suite: 6/6 PASS.
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- The locked guard compares only strategy inputs, `qm_ea_id`,
  `qm_magic_slot_offset`, and the fixed-risk mode. It does not equality-compare
  RNG, news, Friday-close, or stress inputs; stress is checked only for finite
  inclusive `0..1` range.
- Governed compile: `COMPILE_OK`, zero compiler errors/warnings, strict
  build-check PASS.
- MQ5 SHA-256:
  `3f4d14b141a211498454dac8f377f96d7bf263060bbdaa9d56e3acbd4f228e76`.
- EX5 SHA-256:
  `50cdfdd38ee24c00545b829abee47b2f0f600d3c1f2b0b0a19e7b1d418f2c5db`.
- Q02 setfile SHA-256:
  `37748c6d77441db03f0a9f643700f4461b90792e4e5f6f630c46ff56fe5de283`.
- Q02 risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Capacity Admission And Queue Result

The final five-sample whole-host CPU window was `89.96`, `88.02`, `87.71`,
`91.12`, and `85.27` percent: average `88.42`, maximum `91.12`. Both remained
strictly below the binding 97 percent ceiling. The hash-bound first-Q02 dry run
returned `ELIGIBLE`; exactly one Q02 row was then enqueued. No manual tester or
dispatch command was run.

## Safety Boundary

No optimization, live/demo/shadow/stress preset, AutoTrading, `T_Live`, deploy
or live manifest, portfolio gate, portfolio admission, correlation waiver, or
decorrelation claim was touched.
