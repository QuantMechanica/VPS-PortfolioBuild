# QUA-662 zero-trades integrity blocker (2026-05-01T10:28Z)

## Critical finding

Audit of all `36` symbols in frozen P2 `report.csv` shows:
- `Total Trades = 0` across the board
- `Profit Factor = 0.00` in sampled reports

Audit artifact:
- `D:/QM/reports/pipeline/QM5_1003/P2/zero_trade_audit_20260501.json`

## Implication

The apparent P2 `PASS` matrix is a harness-level PASS (report file generated), not strategy-valid baseline evidence.
This is a **zero-trades recovery** class condition and blocks meaningful progression to P5/P5b/P6/P7.

## Classification

- Not an EA-quality PASS signal.
- Not ready for downstream phase inference.
- Requires dedicated zero-trades recovery workflow before claiming baseline completion quality.

## Unblock owner/action

- owner: CTO + Development + Pipeline-Operator
- action:
  1. Fix tester invocation/input mapping so EA/symbol/period/deposit/leverage fields are valid in report settings (current reports show malformed defaults like `Period: M0 (1970...)`, `Initial Deposit: 0`, `Leverage: 1:0`).
  2. Re-run P2 baseline with non-zero-trade acceptance guard.
  3. Regenerate `report.csv` and re-open P3.5/P5 progression only after zero-trades condition clears.

## Next action

- Switch to zero-trades recovery path for `QM5_1003` immediately; do not treat current P2/P3.5 evidence as production-valid baseline quality.
