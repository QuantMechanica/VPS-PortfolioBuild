# QM5_41381 WTI Nine-Month Momentum / Two-Month Hold — Build And Q02 Enqueue

`QM5_41381_wti-tsmom9-h2` is a new low-frequency structural WTI sleeve. It
follows the sign of the exact prior nine completed broker-month return only at
odd-month boundaries and holds the package through the intervening even month.

## Build Result

- Source: complete-read, peer-reviewed Moskowitz, Ooi, and Pedersen (2012),
  with standalone WTI `k=9,h=2` efficacy explicitly unproven.
- Dedup: no exact identity. `QM5_20293` is `k=9,h=1`; `QM5_20281` is
  `k=12,h=2`; `QM5_41379` and `QM5_41380` are `k=3,h=2` and `k=1,h=2`.
- PACER audit: PASS with zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Reference vectors: 13/13 PASS; card lint PASS.
- Governed compile work item `4b1d5e17-c622-4436-9948-e0fb054adc61`:
  `COMPILE_OK`, zero compiler errors/warnings, build check PASS. Build check
  emitted three non-failing card-resolution warnings because its lookup expects
  the exact EA label while the governed approved-card convention adds `_card`.
- Binary SHA-256:
  `ffa10c71395bbe5a399df8b62782259f793cd62ff734ed90c6fc455ab96e76f7`.

## Q02 Enqueue

The exact fixed-risk `XTIUSD.DWX` D1 intake dry run was eligible. A fresh
five-sample CPU window measured 72.3%, 65.6%, 63.1%, 66.7%, and 64.4%; the
maximum remained below the binding 97% ceiling. The governed intake appended
exactly one pending Q02 work item:
`bb254af8-2ddd-4450-9f73-f0ca96c3d688`. No priority boost or manual backtest
was used.

## Safety Boundary

No terminal control, portfolio gate, `T_Live`, deploy/live manifest,
AutoTrading, or live surface was touched.
