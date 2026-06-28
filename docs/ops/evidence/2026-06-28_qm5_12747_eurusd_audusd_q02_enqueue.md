# QM5_12747 EURUSD/AUDUSD Cointegration Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. The strict survivors, `QM5_12533`
EURJPY/GBPJPY and `QM5_12532` AUDUSD/NZDUSD, are already built and have Q02
PASS rows. The later positive DEV/OOS exploratory baskets are also already
built through `QM5_12739`.

To avoid duplicate work, I built the strongest remaining unbuilt OOS-ranked
pair from the same rerun: `EURUSD.DWX` / `AUDUSD.DWX`.

This is explicitly not a strict-threshold survivor. The rerun metrics were:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD~AUDUSD | -0.06 | 1.59 | +9.27% | 22 | 0.73 | 92d |

## Build

- EA: `QM5_12747_edgelab-eurusd-audusd-cointegration`.
- Card: `strategy-seeds/cards/edgelab-eurusd-audusd-cointegration_card.md`.
- Manifest: `framework/EAs/QM5_12747_edgelab-eurusd-audusd-cointegration/basket_manifest.json`.
- Logical symbol: `QM5_12747_EURUSD_AUDUSD_COINTEGRATION_D1`.
- Host symbol/timeframe: `EURUSD.DWX`, `D1`.
- Basket legs: `EURUSD.DWX`, `AUDUSD.DWX`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

Validation:

- `compile_one.result=PASS`.
- `compile_one.errors=0`, `compile_one.warnings=0`.
- `build_check.result=PASS`.
- `build_check.failures=0`.
- `build_check.warnings=16`, all existing framework include advisories.
- Build report: `D:/QM/reports/framework/21/build_check_20260628_132237.json`.
- Compile log: `C:/QM/repo/framework/build/compile/20260628_132237/QM5_12747_edgelab-eurusd-audusd-cointegration.compile.log`.

## Q02 Queue

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`.

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12747_q02_enqueue_20260628_132338.sqlite`

Inserted one non-duplicate logical-basket Q02 row:

| Field | Value |
|---|---|
| Work item | `10ab28c1-ed36-4af8-a64a-8997431a892d` |
| EA | `QM5_12747` |
| Symbol | `QM5_12747_EURUSD_AUDUSD_COINTEGRATION_D1` |
| Status at insert | `pending` |
| Setfile | `framework/EAs/QM5_12747_edgelab-eurusd-audusd-cointegration/sets/QM5_12747_edgelab-eurusd-audusd-cointegration_QM5_12747_EURUSD_AUDUSD_COINTEGRATION_D1_D1_backtest.set` |
| Tester currency/deposit | `USD` / `100000` |
| Risk fixed | `1000` |
| Timeout | `120` minutes |
| Priority track | `true` |
| Enqueued by | `codex_board_advisor_qm5_12747_eurusd_audusd_q02_enqueue_2026-06-28` |

No manual MT5 run was launched. The paced worker fleet owns execution.
