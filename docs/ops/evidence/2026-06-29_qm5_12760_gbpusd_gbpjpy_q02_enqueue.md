# QM5_12760 GBPUSD/GBPJPY Cointegration Basket Q02 Enqueue

Date: 2026-06-29

## Decision

- Built one non-duplicate exploratory FX market-neutral basket from the 66-pair cointegration scan tail: `GBPUSD.DWX` / `GBPJPY.DWX`.
- Existing proven baskets `QM5_12532` and `QM5_12533` already had logical basket Q02 PASS records, so no ONINIT / NO_HISTORY repair was needed first.
- Scan support is weak and sub-threshold, not a hard survivor: DEV Sharpe `-0.26`, OOS net Sharpe `0.10`, OOS return `0.95%`, OOS state changes `17`, hedge beta `0.01`, half-life `109d`.
- Strategy card marks this as high-risk exploratory and structural-only, based on Chan cointegration/statistical arbitrage criteria plus the in-house Darwinex `.DWX` D1 66-pair scan.

## Build

- EA: `framework/EAs/QM5_12760_edgelab-gbpusd-gbpjpy-cointegration/QM5_12760_edgelab-gbpusd-gbpjpy-cointegration.mq5`
- Manifest: `framework/EAs/QM5_12760_edgelab-gbpusd-gbpjpy-cointegration/basket_manifest.json`
- Setfile: `framework/EAs/QM5_12760_edgelab-gbpusd-gbpjpy-cointegration/sets/QM5_12760_edgelab-gbpusd-gbpjpy-cointegration_QM5_12760_GBPUSD_GBPJPY_COINTEGRATION_D1_D1_backtest.set`
- Build task: `fa63237b-e268-475d-98a4-aa64147473c3`
- Compile: PASS, errors `0`, warnings `0`
- Build check: PASS, failures `0`; warnings were existing shared-framework DWX advisory warnings
- SPEC validation: PASS

## Q02 Handoff

- Work item: `6154567b-875f-416c-903b-b171a4d4eefc`
- Phase: `Q02`
- Status at enqueue verification: `pending`
- Logical symbol: `QM5_12760_GBPUSD_GBPJPY_COINTEGRATION_D1`
- Host symbol/timeframe: `GBPUSD.DWX` / `D1`
- Enqueued by: `record_build_result.auto_q02`
- Duplicate pending/active count for same EA, phase, and logical symbol: `1`

## 2026-06-30 Payload Repair

The pending Q02 row remained unclaimed while newer basket rows had already
advanced. The EA already selected and warmed `USDJPY.DWX` for GBPJPY conversion
history, but `basket_manifest.json` only declared the two traded legs. The
manifest now declares `GBPUSD.DWX`, `GBPJPY.DWX`, and `USDJPY.DWX`, with
`USDJPY.DWX` documented as conversion history only.

The existing Q02 row was repaired in place, not duplicated:

| field | value |
|---|---|
| work item | `6154567b-875f-416c-903b-b171a4d4eefc` |
| status after repair | `pending` |
| basket_symbol_count | `3` |
| tester_deposit | `100000` |
| risk_fixed | `1000` |
| timeout_min | `120` |
| priority_track | `true` |
| conversion_history_symbols | `USDJPY.DWX` |
| updated_at UTC | `2026-06-29T22:33:21+00:00` |

DB backup before mutation:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12760_priority_payload_20260629_223320Z.sqlite
```

## Guardrails

- No manual MT5 backtest launched in this session.
- No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, or Q08 contribution artifacts were touched.
- Q02 execution is left to the paced fleet worker.
