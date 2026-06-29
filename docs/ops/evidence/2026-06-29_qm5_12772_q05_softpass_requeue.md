# QM5_12772 Q05 Soft-Pass Requeue

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

- Mission path: all positive-hedge pairs from the 66-pair FX cointegration scan are already represented in the EA tree, so this advanced an existing FX cointegration sleeve instead of adding a duplicate basket.
- Target: `QM5_12772_edgelab-gbpjpy-audjpy-cointegration`.
- Funnel state before work:
  - Q02 logical basket: `PASS` on `QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1`, work item `0ef494c0-7669-4c98-9e5c-326ff70df987`.
  - Q04 walk-forward: `PASS_SOFT`, work item `1b418d74-da86-4fb2-aa41-74ebca065f05`.
  - Q05 stress: `INFRA_FAIL`, work item `dd43c7e2-7351-41e1-a4a4-f667d0789249`.

## Repair

`farmctl enqueue-backtest --ea <EA> --phase Q05` was inconsistent with the pump cascade:

- Pump auto-promotion accepts Q04 `PASS`, `PASS_SOFT`, and `PASS_LOWFREQ` for Q04 -> Q05.
- Manual cascade requeue accepted only Q04 hard `PASS`, preventing operator requeue of a legitimate Q04 soft-pass sleeve after Q05 infra failure.

Changed `tools/strategy_farm/farmctl.py` so the manual Q05 predecessor verdict set matches the pump rule: `PASS`, `PASS_SOFT`, `PASS_LOWFREQ`.

Added a focused regression test in `tools/strategy_farm/tests/test_farmctl_cascade.py` covering Q05 enqueue from Q04 `PASS_SOFT` and `PASS_LOWFREQ` basket rows.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q`
  - Result: `10 passed, 2 subtests passed`.

## Q05 Requeue

Command:

```powershell
python tools\strategy_farm\farmctl.py enqueue-backtest --ea QM5_12772 --phase Q05
```

Result:

- Requeued existing Q05 work item in place: `dd43c7e2-7351-41e1-a4a4-f667d0789249`.
- Created rows: `0`.
- Skipped rows: `0`.
- Current `farmctl work-items --ea QM5_12772` summary: `Q02_done_PASS=1`, `Q04_done_PASS_SOFT=1`, `Q05_pending=1`.

## Guardrails

- No manual MT5 backtest was launched; paced workers own Q05 execution.
- No `T_Live` manifest was touched.
- AutoTrading was not toggled.
- No portfolio admission, portfolio KPI, or Q08 contribution artifact was touched.
