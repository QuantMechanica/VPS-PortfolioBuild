# QM5_1058 FX Pairs Q02 Requeue - 2026-07-02

## Mission fit

- Selected `QM5_1058_gatev-fx-pairs-zscore` under priority 2: built diverse FX/market-neutral EA stuck at Q02 by infra, not by strategy verdict.
- Latest prior Q02 rows for `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, and `NZDUSD.DWX` ended as `INFRA_FAIL` with `summary_missing_retries_exhausted`, no evidence path, and empty report roots.
- No pending or active `QM5_1058` Q02/Q03 rows existed before requeue.

## Repair

- Refreshed the compiled `.ex5` with `compile_one.ps1`.
- Stamped build hashes on all `QM5_1058` backtest setfiles with scoped `build_check.ps1`.
- Used the existing logical basket manifest/setfile path:
  `QM5_1058_EURUSD_GBPUSD_GGR_D1`, host `EURUSD.DWX`, timeframe `D1`, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Queue mutation

- Inserted one basket-scoped Q02 row via `farmctl._auto_enqueue_q02_for_build`.
- Work item: `eeeb44cc-0cc3-4127-8107-18df9f96fa3f`
- Symbol: `QM5_1058_EURUSD_GBPUSD_GGR_D1`
- Status: `pending`
- Payload includes `portfolio_scope=basket`, `host_symbol=EURUSD.DWX`, `basket_symbol_count=4`, `traded_symbols=[EURUSD.DWX, GBPUSD.DWX]`, `tester_currency=USD`, and `risk_mode=RISK_FIXED`.

## Validation

- `pwsh -NoProfile -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1058_gatev-fx-pairs-zscore/QM5_1058_gatev-fx-pairs-zscore.mq5 -Strict`
  - PASS, 0 errors, 0 warnings.
- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_1058_gatev-fx-pairs-zscore -RepoRoot C:\QM\repo`
  - PASS, 0 failures, 17 warnings.
  - Warnings are framework/static advisories and a gated-data warning on the pair `CopyClose` helper; source comment documents the call path is behind the `QM_IsNewBar` gate.

## Guardrails

- Did not run a backtest in this unit.
- Did not touch portfolio gates, `T_Live`, live manifests, or AutoTrading.
