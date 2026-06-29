# QM5_12766 USDJPY/USDCHF Q02 Infra Requeue

Date: 2026-06-29
Actor: Codex Board Advisor

## Scope

Advanced one diverse market-neutral FX basket that was stuck at Q02 by infrastructure failure, without touching portfolio gates, T_Live manifests, or AutoTrading.

## Diagnosis

- EA: `QM5_12766_edgelab-usdjpy-usdchf-cointegration`
- Instrument sleeve: USDJPY/USDCHF D1 cointegration basket
- Prior Q02 work item: `c097d38d-f428-4c8b-a90c-104d1e072c0d`
- Prior terminal: `T4`
- Prior evidence: `D:\QM\reports\work_items\c097d38d-f428-4c8b-a90c-104d1e072c0d\QM5_12766\20260629_124503\summary.json`
- Prior verdict: `INFRA_FAIL`
- Failure classes: `NO_HISTORY`, `INCOMPLETE_RUNS`

The failed run launched the correct host symbol, `USDJPY.DWX`, with the logical basket setfile. The invalid reports showed empty symbol/expert, M0 1970 period, and zero bars. `framework/registry/dwx_symbol_history_ranges.csv` confirms both `USDJPY.DWX` and `USDCHF.DWX` have D1 history on `T1,T2,T3,T4,T5`, so this is treated as terminal/cache launch infrastructure rather than a strategy-code failure.

## Action

Created a DB backup before mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12766_q02_requeue_20260629_152046Z.sqlite`

Inserted one non-duplicate pending Q02 work item:

- New work item: `c2f9cb77-7ea7-43ca-9f4e-d7c8749c8207`
- Phase: `Q02`
- Symbol: `QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1`
- Host symbol: `USDJPY.DWX`
- Host timeframe: `D1`
- Basket symbols: `USDJPY.DWX`, `USDCHF.DWX`
- Risk mode: `RISK_FIXED`, `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Window: `2018.07.02` to `2024.12.31`
- Queue marker: `priority_track=true`

No pending or active duplicate existed before insert.

