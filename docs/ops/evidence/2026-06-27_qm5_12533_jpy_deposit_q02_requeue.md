# QM5_12533 JPY Tester-Deposit Q02 Requeue - 2026-06-27

## Context

The 66-pair FX cointegration scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
had only two strict-threshold survivors: `QM5_12532` AUDUSD/NZDUSD and `QM5_12533`
EURJPY/GBPJPY. No unbuilt next-best strict FX pair was available, so the forex sleeve
work stayed on the blocked approved basket.

`QM5_12533` no longer fails Q02 on ONINIT or missing history. Work item
`6a3884da-336b-4903-85a3-45d00e9ab9bf` reached a real-tick tester report and failed
`MIN_TRADES_NOT_MET` with zero trades.

## Root Cause

The prior repair correctly moved the basket tester currency to `JPY` and set the logical
setfile to `RISK_FIXED=150000`, the JPY-equivalent of the canonical USD 1000 fixed-risk
budget. The tester deposit, however, still came from `framework/registry/tester_defaults.json`
as `Deposit=100000`.

`QM_FrameworkInit` caps fixed risk at 1% of account equity. Under `tester_currency=JPY`
with `Deposit=100000`, that cap reduced the requested `RISK_FIXED=150000` to `1000 JPY`
before leg sizing. That is too small for the EURJPY/GBPJPY ATR stop distances and can leave
both basket legs below broker minimum lot, producing a false zero-trade Q02 failure.

## Repair

- `framework/scripts/run_smoke.ps1` now reads `tester_deposit` or
  `tester_initial_deposit` from a basket `basket_manifest.json`, alongside the existing
  tester-currency handling.
- `run_smoke.ps1` also accepts an explicit `-TesterDepositOverride` for manual/operator
  runs.
- `framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/basket_manifest.json`
  now pins `tester_deposit=15000000`.
- The 15,000,000 JPY tester deposit preserves the framework 1% risk cap at `150000 JPY`,
  matching the logical basket `RISK_FIXED=150000` setfile without changing EA logic or
  live risk behavior.

## Validation

- `run_smoke.ps1` PowerShell parse check: PASS
- `build_check.ps1 -EALabel QM5_12533_edgelab-eurjpy-gbpjpy-cointegration -SkipCompile`: PASS
- Build-check report: `D:/QM/reports/framework/21/build_check_20260627_035446.json`
- Existing advisory warnings were limited to shared framework include warnings already
  emitted by `build_check`; no new MQL build failure was introduced.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12533_jpy_deposit_q02_requeue_20260627_035634.sqlite`

Inserted replacement logical-basket Q02 work item:

- Work item: `12165577-fb9d-40c3-a527-f41c57cb8c45`
- Parent task: `qm5-12533-jpy-deposit-q02-requeue-20260627_035634-12165577`
- EA: `QM5_12533`
- Symbol: `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`
- Setfile:
  `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`
- Status at insert: `pending`
- Supersedes: `6a3884da-336b-4903-85a3-45d00e9ab9bf`
- Payload risk settings: `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000`

No manual backtest was launched from this agent because the MT5/metatester fleet was already
busy; execution is left to the paced farm scheduler.
