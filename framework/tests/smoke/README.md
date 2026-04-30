# V5 Smoke Fixtures

This folder provides the Step 24 smoke regression fixture:

- `QM5_1001_framework_smoke.mq5` - smoke EA that validates framework init, first tick path, and shutdown hooks.
- `QM5_1001_framework_smoke.set` - canonical test inputs for the smoke EA.
- `expected_events.json` - required/forbidden log events for smoke gate validation.

## Contract

- Use symbol `EURUSD.DWX` in smoke runs to match the current magic registry seed row (`ea_id=1001`, `symbol_slot=0`).
- Risk contract follows V5 hard rule: both `RISK_PERCENT` and `RISK_FIXED` inputs are present; smoke baseline uses fixed `$1000`.
- Friday close is enabled by default.

## Runner Scaffold

Use the minimal wrapper in `framework/scripts/run_backtest_smoke.ps1` for the canonical smoke path:

```powershell
pwsh -File framework/scripts/run_backtest_smoke.ps1 -Year 2024 -Terminal T1
```

Notes:

- Wrapper defaults to `QM5_1001_framework_smoke` with `Model=4`, `Runs=2`, `MinTrades=0`, and the fixture set file.
- Symbol must carry the `.DWX` suffix for backtest/research runs.
