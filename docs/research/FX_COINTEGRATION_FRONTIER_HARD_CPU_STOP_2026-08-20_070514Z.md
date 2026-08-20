# FX cointegration frontier hard CPU stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact rank-21 Q04 successor remains
pending once; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The checked-in sign-aware
reconciliation in commit `a80493291` covers all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`, and the scan script
retains SHA-256
`870e3c67d7c05a75f62ab9e89d421dd94d337288f5c623395cafcf03300433d6`.
Creating another relationship Card, registry allocation, basket manifest, or
EA would duplicate governed work.

The preferred anchors do not have a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The highest-ranked exact frozen-scan relationship still awaiting its next
economic verdict is rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, implemented once as
`QM5_20203_eurusd-audjpy`. Its reputable-source, OWNER-approved Card is
structural, deterministic, non-ML, and low-frequency D1. Its manifest declares
EURUSD/AUDJPY as traded legs and AUDUSD/USDJPY as conversion-only histories.
The logical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The exact logical Q02 work item
`85be20b6-d19d-46a2-9084-8786d9837399` is DONE/PASS. Its single Q04 successor
`113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains PENDING, unclaimed, at attempt
zero. No duplicate enqueue, requeue, priority mutation, or timestamp restamp
was performed.

Static revalidation passed: the Card schema lint reported no missing sections
and no ML hits; symbol-scope validation returned `BASKET_OK` with zero
violations; and all 45 FX basket-manifest regression tests passed.

## Binding capacity stop

The first five-sample CPU window at `07:02:38Z` peaked at 95.71%, below the
97% hard ceiling. By the second window at `07:05:03Z`, all five samples were
100%. The second window is binding under the mission's explicit stop rule.

The path-anchored scan at `07:05:31Z` found seven running factory terminals:
T1, T2, T3, T4, T5, T6, and T8. The database also held seven active work
items. T5 was already running the logical XAU/XAG basket
`QM5_20233_XAU_XAG_SKEW_RANK_D1` at Q05, so the farm-wide one-multisymbol-job
serialization rule independently blocks the pending EURUSD/AUDJPY basket.
There were no orphaned factory terminal processes, the paced launch gate
remained `1`, and Factory was ON.

Per the CPU-ceiling stop condition, no Q04 dispatch, queue mutation, tester
launch, reservation, terminal reconciliation, or terminal control followed.
Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T070514Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. T_Live and the unrelated FTMO terminal were observed only so they
could be excluded from factory counts. Concurrent unrelated worktree changes
were left unstaged and untouched.
