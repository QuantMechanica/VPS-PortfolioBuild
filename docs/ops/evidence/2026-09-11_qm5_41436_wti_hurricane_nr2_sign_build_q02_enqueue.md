# QM5_41436 WTI Hurricane NR2 Sign Build And Q02 Enqueue

Date: 2026-09-11

## Outcome

`QM5_41436_wti-hurr-nr2-sign-cont` is a new branch-only WTI D1 structural hurricane-season
sleeve. It follows the own-week direction only when the immediately completed week's full range
is strictly narrower than the preceding completed week's range, then exits at the next normalized
week. It is not admitted to the portfolio and makes no decorrelation claim.

## G0 And Q01 Evidence

- source/build commit: `bbabc16ba7` plus set-hash intake correction `5d126d7bd5`;
- canonical dedup: no exact match; six fuzzy family neighbors manually resolved;
- card schema lint: PASS, no ML hits or missing sections;
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings, repeated immediately
  before the successful compile enqueue;
- symbol scope: `SINGLE_SYMBOL_OK`;
- build guardrails: PASS with zero findings;
- reference oracle: 12/12 PASS;
- compile work item: `bc0fe3d3-68a6-45ee-83b4-1c3341ee4ee6`;
- compile: `COMPILE_OK`, 0 errors, 0 compiler warnings;
- strict build check: PASS at `D:/QM/reports/framework/21/build_check_20260911_085628.json`;
- MQ5 SHA-256: `2272eaa66d1ff84050c9a39f45c2937f9d5605843c95025794d44f1c42637cc6`;
- EX5 SHA-256: `36b99f86771e817486894df4e37399306d5a4281d3d6e369b547092ebda43054`.

The compile generator blanked `strategy_symbol` because its card discovery was undecidable. The
canonical fixed-risk set was repaired to `XTIUSD.DWX`; Q02 intake then returned `ELIGIBLE`, D1,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, setfile SHA-256
`64eeb70a1434ed905054e18b10db8e1057d1aea1b371e53f354785e6dd5699d2`.

## Paced Q02 Decision

Five one-second whole-host CPU samples were `71.585104, 77.526318, 76.186378, 80.275499,
88.391765` percent. The maximum remained below the exclusive 97% ceiling. Exactly one Q02 row was
enqueued: `ae5f4df7-e2ac-437d-b736-b99e5b635c6c`, pending on `XTIUSD.DWX` D1. No manual backtest,
dispatch tick, terminal control, or retry was run.

The worker subsequently completed that row as `ZERO_TRADES`. The evidence-bound report is valid,
uses the required source/binary/set hashes, Model 4, `XTIUSD.DWX` D1, and 2018-07-02 through
2022-12-31. Initialization passed, but the authenticated EA log contains zero `STRATEGY_STATE`
decision markers and zero entry markers. This is recorded as an entry-hook observability failure
requiring bounded same-economics diagnosis, not as a strategy PASS or automatic economic reject.
No repair, parameter change, compile, or retry was attempted.

No `T_Live`, AutoTrading, deploy/live manifest, portfolio gate, portfolio admission, or
correlation waiver was touched.
