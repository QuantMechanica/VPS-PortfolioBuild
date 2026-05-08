# QUA-662 P5 input blocker (2026-05-01T10:22Z)

## Current state

- P2: complete (`36/36`, PASS)
- P3.5: complete (`AUTO_PASS`)
- Next gate: `P5`

## P5 runner contract (verified)

`p5_stress_runner.py` requires explicit scalar inputs:
- `--clean-pf`
- `--stress-pf`
- `--clean-trades`
- `--stress-trades`

It also validates calibration readiness from:
- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`

## Blocker evidence

1. Calibration file is present and `measurement_status=MEASURED` (not blocking).
2. No existing `QM5_1003` stress-metric artifacts found under `D:/QM/reports/...` that provide the required P5 scalar inputs.
3. No canonical in-checkout step currently converts executed stress runs into the required scalar pair (`clean_pf`, `stress_pf`, `clean_trades`, `stress_trades`) automatically for this EA.

## Impact

- P5 cannot be executed with evidence-grade inputs from the current artifact chain until the clean/stress scalar metric step is supplied.
- Any synthetic/manual placeholder metrics would violate gate integrity.

## Unblock owner/action

- owner: CTO + Pipeline-Operator
- action:
  1. Provide canonical stress metric generation step for `QM5_1003` yielding: clean_pf, stress_pf, clean_trades, stress_trades.
  2. Confirm approved command contract to pass those metrics into `p5_stress_runner.py`.

## Next action on unblock

- Execute P5 immediately and aggregate phase results into `D:/QM/reports/pipeline/QM5_1003/index.json`.
