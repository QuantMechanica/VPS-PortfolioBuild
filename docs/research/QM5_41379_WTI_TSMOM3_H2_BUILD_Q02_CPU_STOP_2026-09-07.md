# QM5_41379 WTI Three-Month Momentum / Two-Month Hold — Build And Q02 CPU Stop

`QM5_41379_wti-tsmom3-h2` is a new low-frequency structural WTI sleeve. It
follows the sign of the exact three-completed-month return only at odd broker-
month boundaries and holds the package through the intervening even month.

## Build Result

- Source: complete-read, peer-reviewed Moskowitz, Ooi, and Pedersen (2012),
  with the standalone WTI `k=3,h=2` efficacy limitation retained.
- Dedup: no exact identity; the existing three-month/monthly-renewal and
  twelve-month/two-month-hold siblings are mechanically distinct.
- PACER audit: PASS with zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Reference vectors: 13/13 PASS; card and SPEC lint: PASS.
- Initial governed compile produced 0 errors/warnings but build check rejected
  one redundant `EA_SYMBOL_HARDCODED` comparison. The source-only repair
  removed that literal comparison and kept the preset-bound host check.
- Final governed compile work item:
  `106fef27-0c57-4585-a64c-b9019e4d99bf`, `COMPILE_OK`, zero errors/warnings,
  build check PASS.
- Final binary SHA-256:
  `9779fd6b8fbd51232172e15173c22568067d11f79692be4cff20d337e97ce366`.

## Q02 Stop And Containment

The first-Q02 dry run was eligible for the exact XTIUSD.DWX D1 fixed-risk
preset. The mandatory five CPU samples were 97.7%, 87.0%, 89.8%, 94.7%, and
79.0%. The maximum 97.7% breached the binding 97% ceiling, so Q02 admission
was denied and no backtest was authorized.

Recording the completed build task unexpectedly invoked the legacy automatic
Q02 path and appended pending row
`cbdc6809-d507-4d0f-9a27-a709dc5aa46c`. It was unclaimed and had not started.
The governed hold tool immediately attached the non-restart hold
`PACER_Q02_CPU_CEILING_STOP`; readback proved the row unclaimable. Release
requires a fresh five-sample window strictly below 97% and explicit OWNER-
paced continuation.

## Safety Boundary

No manual backtest, terminal control, priority boost, portfolio gate,
`T_Live`, deploy/live manifest, AutoTrading, or live surface was touched.
