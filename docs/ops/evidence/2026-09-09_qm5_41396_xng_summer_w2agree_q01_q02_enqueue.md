# QM5_41396 Q01 Build And Q02 Enqueue Evidence

Date: 2026-09-09  
EA: `QM5_41396_xng-summer-w2agree`  
Host: `XNGUSD.DWX`, D1

## Outcome

The new low-frequency natural-gas sleeve implements a summer-only structural
continuation hypothesis. On the first tradable bar of a normalized week in
June, July, or August, it trades only when the two immediately completed
adjacent weeks have strict matching open-to-close log-return signs. The build
passed Q01 and one Q02 canary was enqueued. The paced fleet subsequently
claimed and ran that row without a manual dispatch from this mission; the
result was `ZERO_TRADES`.

## Q01 Evidence

- Reference vectors: 14 PASS.
- Strategy Card schema lint: PASS.
- `SPEC.md` validation: PASS.
- PACER framework-input pin audit: PASS with zero
  `EA_FRAMEWORK_INPUT_PINNED` findings, run before compile enqueue.
- Strict framework build check: PASS, zero warnings.
- Compile: `COMPILE_OK`, zero errors and zero warnings, work item
  `ec0c4f42-df9f-4372-a4c6-84d9dd06be79`, terminal T3.
- MQ5 SHA-256:
  `3cdfb7db6ac755a96c533c1aff2d4ee2015b20fef3ca5d887ce3f428ab93074e`.
- EX5 SHA-256:
  `c0de9c7f84a945f00c8349d047bce0c92eb926090a719b2e33bcadb1ccb877df`.
- Bound fixed-risk setfile SHA-256:
  `de8720f427daf010fc07e8e02d122e8328fef8a04e5e8eca7007cb479eaa1177`.

Compile evidence is at
`D:\QM\reports\work_items\ec0c4f42-df9f-4372-a4c6-84d9dd06be79\QM5_41396\COMPILE_EA\compile_evidence.json`.

## CPU Admission And Q02

Five one-second total-CPU samples were 87.8248%, 88.6154%, 85.8626%,
83.6201%, and 79.8176%. Their average was 85.1481% and maximum was 88.6154%,
so every observation remained strictly below the 97% ceiling.

The governed first-Q02 intake enqueued work item
`bd47f2f3-b8e2-461a-8a41-84a4092d0a1c` for `XNGUSD.DWX` D1 without priority
boost. The receipt is
`D:\QM\strategy_farm\artifacts\receipts\first_q02_intake\ec0c4f42-df9f-4372-a4c6-84d9dd06be79_bd47f2f3-b8e2-461a-8a41-84a4092d0a1c.json`.

Before the closing read-only status check, the paced fleet claimed the pending
row on non-live terminal T2. The artifact-bound 2018-07-02 through 2022-12-31
Model-4 run completed with `ZERO_TRADES`. This is not a Q02 PASS or a strategy
rejection. Its recovery classification is recorded in
`docs/ops/evidence/2026-09-09_qm5_41396_zero_trades_recovery_investigation.md`.

## Scope Boundary

No manual backtest was launched or dispatched by this mission. AutoTrading was
not toggled, and no `T_Live`, deploy-manifest, portfolio-gate, admission, or
correlation-waiver state was touched. The fleet-run zero-trade result requires
entry-clock recovery before economics can be evaluated. Q09 alone may
establish realized decorrelation from the certified portfolio.
