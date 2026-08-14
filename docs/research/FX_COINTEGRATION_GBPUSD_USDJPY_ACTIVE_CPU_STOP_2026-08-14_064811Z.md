# FX cointegration fallback — active Q02 CPU-ceiling stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 GBPUSD/USDJPY logical Q02
ACTIVE on T4; governed fleet at 10/10 capacity

## Outcome

No duplicate Card, EA, basket manifest, or Q02 row was created. The committed
sign-aware reconciliation of `analyze_cross_asset_v3.py
--include-negative-hedges` covers all 66 scan relationships. The original scan
had only two qualifying positive-beta survivors, and both requested anchors
are already beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker. A new scan-derived
pair would duplicate an existing relationship and governed build.

## Existing-pair advance

The non-duplicate fallback selected by the frozen scan remains rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved and
built `QM5_1257_lemishko-fx-cointpair` basket. Its exact logical row is:

- logical symbol: `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`
- Q02 work item: `d4cd660c-c81a-41d3-8a4c-ad21d3319816`
- Q02 task: `39ee6910-5d04-4087-83b0-65a6fd6b22f9`
- state at the current sample: `active`, attempt 0, claimed by `T4`
- tester config: `D:/QM/reports/work_items/d4cd660c-c81a-41d3-8a4c-ad21d3319816/QM5_1257/20260814_063902/raw/run_01/tester.ini`

This is a genuine state advance from the prior `PENDING` observation at
`2026-08-14T05:11:14Z`. The governed worker claimed it after the signed
custom-history containment was repaired and released. The row was already
enqueued exactly once, so no enqueue, requeue, priority, timestamp, dispatch,
or reservation mutation was warranted.

The implementation remains bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. Its basket manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`; the logical H1 setfile uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No refit, added filter, banned or
ML indicator, rescue tuning, or profitability claim was introduced.

## Binding CPU ceiling

The path-aware canonical scan at `2026-08-14T06:48:11Z` observed all ten
factory terminals `T1` through `T10` running exact active work items. T4 is
running the selected GBPUSD/USDJPY logical basket. The separately observed
`T_Live` and FTMO terminals were excluded and were not controlled.

The backtest CPU ceiling is therefore binding. Per the mission stop rule, no
additional tester, queue mutation, dispatch tick, terminal reservation, or
terminal control followed. The active Q02 is left to the governed worker for
normal classification.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live deployment artifact
  changed.
- No Card, EA, registry, magic row, basket manifest, setfile, or external queue
  row changed.
- Concurrent unrelated worktree files were not staged or modified.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_active_cpu_stop_20260814T064811Z_board_advisor.json`.
