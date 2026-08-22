# FX cointegration frontier hard CPU stop

Date: 2026-08-22 UTC (`2026-08-22T03:46:14Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; the former rank-21 continuation is
now terminal at Q04; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The durable sign-aware
relationship reconciliation recorded in `a80493291` covers all 66
relationships from `analyze_cross_asset_v3.py --include-negative-hedges`.
The repository inventory contains a corresponding EA directory for every
governed scan relationship, so creating another scan-derived Card, registry
allocation, basket manifest, or EA would duplicate governed work.

Fresh canonical farm reads confirm that the preferred anchors are not blocked
at Q02 by ONINIT or NO_HISTORY:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

## Existing-pair fallback changed state

The preceding frontier stop selected frozen-scan rank 21,
`EURUSD.DWX` / `AUDJPY.DWX`, implemented once as
`QM5_20203_eurusd-audjpy`. Its logical Q02 PASS remains canonical, but its
single Q04 successor is no longer pending:

- Q02 PASS: `85be20b6-d19d-46a2-9084-8786d9837399`.
- Q04 FAIL: `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445`, completed at
  `2026-08-21T14:57:05Z`.

This is a material change from the latest checked-in frontier snapshot, which
still recorded that Q04 row as pending. Re-enqueueing it would duplicate a
terminal economic verdict. The earlier rank-58 fallback
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` is likewise terminal: Q02 PASS,
then Q04 FAIL.

## Binding CPU stop

The required five-sample CPU preflight returned 98.26%, 95.90%, 98.25%,
94.34%, and 79.50%. The 98.26% maximum exceeded the explicit 97% hard
ceiling (93.25% average).

The immediately preceding supported path-aware slot view observed four
factory terminals (`T1`, `T2`, `T3`, and `T6`). T2 was running the
multi-symbol Q02 basket `QM5_20291_XAU_XAG_HKURT_D1`, which independently
occupied the farm's serialized basket lane. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

Per the mission stop condition, no further candidate advancement, Q02/Q04
enqueue, requeue, dispatch, tester launch, terminal reservation, terminal
control, or queue mutation followed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260822T034614Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, magic row, or
  external queue row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
