# FX cointegration frontier — hard CPU-ceiling stop

Date: 2026-08-17 Europe/Berlin (`2026-08-17T15:32:26Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; no queue mutation because the
explicit backtest CPU ceiling is binding

## Outcome

The checked-in sign-aware reconciliation at commit `a80493291` still accounts
for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`. There is no unbuilt
frozen-scan relationship for a non-duplicate Card and EA.

The two preferred anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, Q04 FAIL.

The latest exact scan fallbacks are terminal as well. Frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX` in `QM5_1257`, advanced from Q02 PASS to a Q04
strategy FAIL and was retired without Q05. Rank 65, `USDCHF.DWX` /
`AUDUSD.DWX` in `QM5_1156`, completed its exact logical Q02 row with a strategy
FAIL. Re-carding either relationship or creating another Q02 identity would
be duplicate or invalid funnel work.

## Binding resource stop

Five two-second whole-machine CPU samples were 94.09%, 93.41%, 91.56%,
99.32%, and 93.13% (average 94.30%, maximum 99.32%). The maximum crossed the
explicit 97% hard ceiling.

The path-aware terminal scan found six active factory terminals: `T1`, `T2`,
`T3`, `T4`, `T6`, and `T7`. `T2` already owns active multi-symbol Q02 work item
`c2636b77-481e-426c-b0e8-15623c25468c`. `T_Live` and the unrelated FTMO
terminal were observed only so they could be excluded; neither was controlled.

Per the mission stop condition, no Card, EA, registry row, magic row, basket
manifest, setfile, queue row, dispatch tick, backtest, terminal reservation,
priority mutation, Factory state, or terminal state was created or changed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260817T153226Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- Concurrent unrelated staged and untracked work was left untouched.
