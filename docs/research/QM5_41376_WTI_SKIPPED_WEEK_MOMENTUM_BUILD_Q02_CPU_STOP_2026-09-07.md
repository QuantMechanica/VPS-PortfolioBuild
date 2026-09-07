# QM5_41376 WTI Skipped-Week Momentum — Build And Q02 CPU Stop

QM5_41376 mechanizes the paper-defined `CMOM4,2` horizon on XTIUSD.DWX D1:
form on the cumulative return from weeks `t-4` through `t-2`, exclude `t-1`,
follow the sign during week `t`, and flatten at the next broker-week boundary.
This differs from QM5_41375's `t-1`-only signal and from monthly skip-one trend.

## Build Result

- PACER source audit: PASS, 0 `EA_FRAMEWORK_INPUT_PINNED` findings.
- Deterministic reference tests: 10/10 PASS, including `t-1` exclusion.
- Card schema/ML lint: PASS.
- Governed compile work item: `f3543037-49ae-4def-bc3b-2ee09977207e`.
- Compile: `COMPILE_OK`, 0 errors, 0 warnings.
- Strict build check: PASS.
- Binary SHA-256:
  `4ec3ccd584a5c695bce6d790f9cd7d22c981a129abb1cd86fb5dbdf416f5c392`.

## Q02 Admission Stop

Canonical first-Q02 dry-run returned eligible for the exact XTIUSD.DWX D1
fixed-risk setfile. Before apply, five CPU samples were 90.5%, 97.5%, 96.9%,
91.7%, and 99.8%. The binding threshold is 97%; therefore Q02 was not enqueued
and no backtest was started. Seven `terminal64` processes were present.

The next operator may repeat the fresh CPU admission check and run only:

`python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id f3543037-49ae-4def-bc3b-2ee09977207e --apply`

only when below the ceiling. No `T_Live`, AutoTrading, portfolio gate, deploy
manifest, or live manifest was touched.
