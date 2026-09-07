# QM5_41380 WTI One-Month Momentum / Two-Month Hold — Build And Q02 Enqueue

`QM5_41380_wti-tsmom1-h2` is a new low-frequency structural WTI sleeve. It
follows the sign of the immediately prior completed broker-month return only
at odd-month boundaries and holds the package through the intervening even
month.

## Build Result

- Source: complete-read, peer-reviewed Moskowitz, Ooi, and Pedersen (2012),
  with standalone WTI `k=1,h=2` efficacy explicitly unproven.
- Dedup: no exact identity. `QM5_20187` is `k=1,h=1`; `QM5_20281` is
  `k=12,h=2`; `QM5_41379` is `k=3,h=2`.
- PACER audit: PASS with zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Reference vectors: 13/13 PASS; card lint PASS.
- Governed compile work item `11955a06-a0a7-4376-8e09-a94c4dd4886f`:
  `COMPILE_OK`, zero errors/warnings, build check PASS.
- Binary SHA-256:
  `942784cf4c624183b8723830d80de748103b0a75b84860b3bfdff69871e241a3`.

## Q02 Enqueue

The exact fixed-risk `XTIUSD.DWX` D1 intake dry run was eligible. A fresh
five-sample CPU window measured 84.6%, 84.3%, 78.9%, 79.9%, and 85.7%; the
maximum remained below the binding 97% ceiling. After two fail-closed
mutation-lock refusals, the same governed intake appended exactly one pending
Q02 work item: `39f66ffd-dc0b-44cb-ac21-60f574055cf0`. No priority boost or
manual backtest was used.

## Safety Boundary

No terminal control, portfolio gate, `T_Live`, deploy/live manifest,
AutoTrading, or live surface was touched.
