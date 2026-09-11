# QM5_41439 XNG Winter NR2 Breakout — Build And Q02 CPU-Ceiling Stop

Date: 2026-09-11  
Branch: `agents/board-advisor`

## Outcome

`QM5_41439_xng-winter-nr2-breakout` is a new symmetric XNG winter contraction/breakout
candidate. It freezes the newest of two completed weekly ranges only when that range is strictly
narrower, then waits for the first later completed D1 close outside the box. It is not certified
`QM5_12567`'s long-only two-day cumulative-RSI pullback logic, and it differs from the all-year
seven-week XNG contraction and immediate expanding-range CLV neighbors.

The source packet and G0 card are approved, identity `41439` and magic `414390000` are allocated,
the V5 EA and fixed-risk preset are built, and the resident worker returned `COMPILE_OK` with zero
errors and zero warnings. Thirteen deterministic reference tests and SPEC validation passed. The
mandatory PACER input-pin audit returned `ok=true` with zero `EA_FRAMEWORK_INPUT_PINNED` hits
immediately before compile enqueue.

## Governed Receipts

- Research commit: `a06d69c50f`
- Build-source commit: `e1964b1c66`
- Compile work item: `790255b0-7bb6-41cd-9419-33daf5f14bc3`
- MQ5 SHA-256: `8e43b1aff84f48f8e25e902b05845219d1b2c044753530d787ef7c3300038142`
- EX5 SHA-256: `fc213b00ae0e90dd742bd51a6dd64744429a36fd701f31270ceb87968ddff89d`
- Q02 dry-run: eligible after repairing the generated empty `strategy_symbol` to exact
  `XNGUSD.DWX`
- Q02 setfile SHA-256: `92211fe21c31792cdd9e71ceec35a01799d9813f3179ec9d71b996611e113762`

## Binding CPU Stop

The fresh five-sample whole-host CPU window averaged `93.187870%` and peaked at `98.047568%`.
Because the maximum was not strictly below the `97.0%` ceiling, admission was `false`. The work-
item census showed only the completed `COMPILE_EA` row and zero Q02 rows for `QM5_41439`.

Per the mission's hard stop, no resample, Q02 enqueue, manual tester dispatch, optimization,
portfolio-gate or live-manifest edit, `T_Live` access, AutoTrading action, or live authorization
occurred.
