# FX cointegration frontier hard CPU stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact rank-21 Q04 successor remains
pending once; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The checked-in sign-aware
reconciliation in commit `a80493291` covers all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`, and the scan script still
has SHA-256
`870e3c67d7c05a75f62ab9e89d421dd94d337288f5c623395cafcf03300433d6`.
Creating another relationship Card, build, registry allocation, or basket
manifest would duplicate governed work.

The requested anchors do not need Q02 setup repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither has a current Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The highest-ranked exact frozen-scan relationship still awaiting its next
economic verdict remains rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, implemented as
`QM5_20203_eurusd-audjpy`. Its reputable-source, OWNER-approved Card is
structural, deterministic, non-ML, and low-frequency D1. The basket manifest
declares EURUSD/AUDJPY as the traded legs and AUDUSD/USDJPY as conversion-only
histories. The logical backtest setfile retains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The exact Q02 row `85be20b6-d19d-46a2-9084-8786d9837399` is DONE/PASS. Its
single exact Q04 successor `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains
PENDING, unclaimed, at attempt zero. No duplicate enqueue, requeue, priority
mutation, or timestamp restamp was performed.

## Binding CPU ceiling

The path-anchored factory scan at `2026-08-20T06:02:26Z` found five running
factory terminals: T2, T3, T5, T6, and T10. The database concurrently held
seven active work items, including the active Q09_NEWS pilot. There were no
orphaned factory terminal processes, and the paced launch gate remained `1`.

Five whole-host CPU samples at two-second intervals were `99.54%`, `91.83%`,
`99.27%`, `94.68%`, and `96.26%` (average `96.316%`, maximum `99.54%`). The
maximum exceeds the mission's explicit `97%` hard ceiling. Per the stop
condition, no Q04 dispatch, tester, queue mutation, terminal reservation, or
terminal control followed.

This is a materially new capacity snapshot rather than a duplicate work item:
the earlier `04:34Z` evidence observed seven running factory terminals
(T1/T2/T3/T4/T7/T8/T9), while this sample observed five different running
terminals (T2/T3/T5/T6/T10) and an active Q09_NEWS pilot. The selected FX row
itself remains unchanged, which is exactly why it was not duplicated.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T060342Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. T_Live and the unrelated FTMO terminal were observed only so they
could be excluded from factory counts. Concurrent unrelated worktree changes
were left unstaged and untouched.
