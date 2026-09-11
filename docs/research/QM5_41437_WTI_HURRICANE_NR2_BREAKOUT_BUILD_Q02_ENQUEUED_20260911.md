# QM5_41437 WTI Hurricane NR2 Close Breakout - Build And Q02 Enqueue

Date: 2026-09-11  
Branch: `agents/board-advisor`  
Outcome: `Q01 PASS; Q02 ENQUEUED_ACTIVE`

## Edge

`QM5_41437_wti-hurr-nr2-breakout` is a low-frequency WTI D1 structural hurricane-season sleeve.
During August-October it requires the newest of two completed weeks to have a strictly smaller
full range, freezes that week's high-low box, and enters with the first later completed current-
week D1 close strictly outside the box. It is symmetric long/short, uses one weekly attempt, a
frozen `3.5*ATR(20,D1)` stop, no target, and exits in the next normalized week.

The identity is not cosmetic. `QM5_41436` enters immediately in the prior week's body direction;
`QM5_41434/41435` use range expansion and upper-quartile close location; `QM5_41061` is an all-year
strict NR7 breakout; and `QM5_13075` requires literal inside-week containment plus SMA, ATR-range,
buffer, and close-location filters. The canonical scan found no exact match; three expected fuzzy
hurricane neighbors were manually resolved. Q09 alone may establish realized correlation.

## Deterministic Build Evidence

- source/build commit: `371a0cab43`;
- approved card: `strategy-seeds/cards/approved/QM5_41437_wti-hurr-nr2-breakout_card.md`;
- source approval: `decisions/2026-09-11_wti_hurricane_nr2_breakout_source_approval.md`;
- registered slot: 0, `XTIUSD.DWX`, magic `414370000`;
- card schema/ML lint: PASS;
- reference oracle: 12/12 PASS;
- symbol scope: `SINGLE_SYMBOL_OK`;
- build guardrails: PASS;
- mandatory PACER audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings;
- compile work item: `27ca36d0-4048-42b9-8322-cce59d692de4`;
- compile: `COMPILE_OK`, zero errors, zero compiler warnings, strict build-check PASS;
- MQ5 SHA-256: `2aba16ce9c760075f6ea293de920a437cf0d6c820b04cca9da878ede309ea6d3`;
- EX5 SHA-256: `ca62f06e4d9d1d771dd7fac4b1c0adc7529ca6f4c9e5b947ba73ce2618c89be8`.

The compile generator could not choose a unique card and blanked `strategy_symbol`; the canonical
fixed-risk set was restored to the approved `XTIUSD.DWX` binding. Build guardrails then passed and
first-Q02 intake returned `ELIGIBLE` with `RISK_FIXED=1000`, `RISK_PERCENT=0` and set SHA-256
`bd5f678519437cd924928d7cd5ebfb6d5534409c16870044d002df591f2ee847`.

## Paced Q02 Decision

Five one-second whole-host CPU samples were `48.371050, 59.167998, 77.834375, 83.400216,
82.434142` percent. The 83.400216% maximum remained below the exclusive 97% ceiling. Exactly one
Q02 row was enqueued: `e29b85e8-c31d-42a5-a3d2-3abb5ed8ecae` for `XTIUSD.DWX` D1. A resident
worker had claimed it on T1 when status was checked; no manual tester, dispatch tick, or retry was
run.

No portfolio gate, portfolio admission, deploy/live manifest, `T_Live`, terminal control,
AutoTrading state, or live operation was touched.
