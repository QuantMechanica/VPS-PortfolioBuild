# QM5_12739 GBPUSD/AUDUSD Cointegration Q02 Enqueue

Date: 2026-06-28
Branch: agents/board-advisor
EA: QM5_12739_edgelab-gbpusd-audusd-cointegration
Instrument class: market-neutral FX cointegration basket

## Decision

`QM5_12532` and `QM5_12533` were checked first and were not Q02-blocked; both
already have logical-basket Q02 PASS records and later failed Q04. The strict
66-pair scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` only
hard-certified those two baskets, so the next action was to choose a
non-duplicate exploratory FX cointegration pair.

The next unbuilt positive DEV/OOS candidate from the same scan rerun was
`GBPUSD~AUDUSD`:

| pair | DEV Sharpe | OOS net Sharpe | OOS return | OOS state changes | hedge beta | half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPUSD~AUDUSD | 0.52 | 0.30 | +2.37% | 20 | 0.74 | 57d |

This is explicitly sub-threshold versus the original OOS net Sharpe hard bar,
so the card is marked as a high-risk exploratory next-best sleeve.

## Repo Artifacts

- Card: `strategy-seeds/cards/edgelab-gbpusd-audusd-cointegration_card.md`
- EA source: `framework/EAs/QM5_12739_edgelab-gbpusd-audusd-cointegration/QM5_12739_edgelab-gbpusd-audusd-cointegration.mq5`
- Compiled EX5: `framework/EAs/QM5_12739_edgelab-gbpusd-audusd-cointegration/QM5_12739_edgelab-gbpusd-audusd-cointegration.ex5`
- Basket manifest: `framework/EAs/QM5_12739_edgelab-gbpusd-audusd-cointegration/basket_manifest.json`
- Q02 setfile: `framework/EAs/QM5_12739_edgelab-gbpusd-audusd-cointegration/sets/QM5_12739_edgelab-gbpusd-audusd-cointegration_QM5_12739_GBPUSD_AUDUSD_COINTEGRATION_D1_D1_backtest.set`
- Build artifact: `artifacts/qm5_12739_build_result.json`

The Q02 setfile is canonical `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, with news filters explicitly disabled for the structural
baseline.

## Validation

- Compile: PASS, errors 0, warnings 0.
  - Log: `C:\QM\repo\framework\build\compile\20260628_092507\QM5_12739_edgelab-gbpusd-audusd-cointegration.compile.log`
  - Summary: `D:\QM\reports\compile\20260628_092507\summary.csv`
- Build check: PASS, failures 0, warnings 16.
  - Report: `D:\QM\reports\framework\21\build_check_20260628_092950.json`
  - Warnings are existing shared-framework DWX advisory warnings.

Hashes after build:

- MQ5 SHA256: `43325836b507ca456e9b69e33fc3684fbd44a69e542664595f7087f2b47a2daa`
- EX5 SHA256: `427a060858667d2111c90b7cb584dac4886762da5bcceeead79bc4c0411cd076`
- Setfile header `build_hash`: `43ec1b28d04856961a3e42e4ace183fa93f8ea6199a845ee1d1c437c101e089d`
- Setfile SHA256: `2c6ebdb1171280ff5ed91eee2f38d65c525ab9ae854d70e26f9e63ada2d77cd9`

## Q02 Queue

Farm DB backup before enqueue:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12739_q02_enqueue_20260628_092640Z.sqlite`

Inserted one non-duplicate logical-basket Q02 work item:

- ID: `b61b0973-bd5a-4368-b860-2b91f252cbea`
- Parent task: `qm5-12739-initial-q02-enqueue-20260628_092640Z-b61b0973`
- Phase: `Q02`
- Kind: `backtest`
- Status after final check: `active`
- Claimed by: `T4`
- Symbol: `QM5_12739_GBPUSD_AUDUSD_COINTEGRATION_D1`
- Host symbol: `GBPUSD.DWX`
- Host timeframe: `D1`
- Basket legs: `GBPUSD.DWX`, `AUDUSD.DWX`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12739_edgelab-gbpusd-audusd-cointegration\sets\QM5_12739_edgelab-gbpusd-audusd-cointegration_QM5_12739_GBPUSD_AUDUSD_COINTEGRATION_D1_D1_backtest.set`
- Created: `2026-06-28T09:26:40+00:00`
- Updated: `2026-06-28T09:26:53+00:00`

No manual MT5 backtest was launched. The paced fleet owns the active Q02 run.

## Safety

No `T_Live` files, AutoTrading settings, deploy manifests, portfolio admission
gate files, portfolio KPI files, or Q08 contribution files were touched.
