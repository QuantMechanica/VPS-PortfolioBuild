# QM5_12532 Q05 Timeout Requeue

## Scope

Mission fallback was used: every registered approved `edgelab-*-cointegration`
pair through `QM5_12803` already has an EA source and `.ex5`, so no
non-duplicate unbuilt FX cointegration pair was available in the registry.

`QM5_12532` was selected as the existing forex basket to advance because:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has logical-basket Q02 `PASS`.
- The same logical basket has Q04 `PASS`.
- Its latest Q05 evidence was infrastructure-invalid after the tester hit the
  old 1800-second `run_smoke.ps1` timeout.

`QM5_12533` was checked first per mission priority. It is not Q02-blocked: its
logical basket has Q02 `PASS` and later Q04 `FAIL`.

## Change

`framework/scripts/q05_stress_medium.py` now uses:

- `DEFAULT_TIMEOUT_SEC = 3300`
- `RUNNER_HEADROOM_SEC = 120`

This keeps Q05's Python subprocess window at 3420 seconds, inside the existing
60-minute Q05 active timeout envelope, while giving full-history D1 basket
stress runs materially more time than the previous 1800-second tester ceiling.

Added unit coverage in `framework/scripts/tests/test_q05_q07_verdicts.py` for
the default `-TimeoutSeconds 3300` argument and wrapper timeout.

## Requeue

Command:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12532 --phase Q05
```

Result:

- Requeued work item: `82cab3d1-bf05-4aa4-8278-86c8064b16e7`
- Symbol: `QM5_12532_AUDNZD_COINTEGRATION_D1`
- Status after: `pending`
- Updated at: `2026-06-30T04:18:13+00:00`
- Archived prior report root:
  `D:/QM/reports/work_items/82cab3d1-bf05-4aa4-8278-86c8064b16e7.requeued_20260630T0418130000`

Payload retained basket context:

- `host_symbol`: `AUDUSD.DWX`
- `host_timeframe`: `D1`
- `q04_latest_full_year`: `2024`
- `tester_currency`: `USD`
- `tester_deposit`: `100000`

## Validation

```powershell
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py::Q05Q07VerdictTests::test_q05_default_timeout_leaves_worker_headroom
python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_enqueue_q05_checks_basket_manifest_symbols_not_logical_symbol tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_enqueue_q05_accepts_q04_soft_pass_verdicts tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_q05_runner_cmd_receives_latest_full_year_cap
```

Results:

- Q05 timeout-headroom test: `1 passed`
- Q05 cascade tests: `3 passed`

Safety: no manual backtest launched, no T_Live/AutoTrading touched, no
portfolio gate files touched.
