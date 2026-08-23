# FX cointegration frontier: existing Q06 row / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T00:21:10Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** the frozen 66-pair frontier is fully mechanized; the selected
existing FX basket already has one Q06 successor; stopped at the explicit
backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. Creating another
scan-derived identity would duplicate governed work.

The preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

Neither anchor has a current ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The non-duplicate continuation remains the structural D1 `NZDUSD.DWX` /
`EURAUD.DWX` basket `QM5_20208_nzdusd-euraud`, rank 27 in the frozen scan. A
fresh supported operator query returned exactly four lineage rows:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.
- Q06 `776e6310-7ad6-41ba-8a08-4d63e045d4e5`: PENDING, unclaimed, attempt 0.

There is exactly one Q06 row. The governed cascade already created the correct
successor, so an enqueue, requeue, priority restamp, or duplicate dispatch was
not valid.

The approved Card remains backed by the OWNER-ratified Tier-A Ernest Chan
cointegration-family extraction. Fresh hashes confirm that the Card, source,
EX5, basket manifest, and logical-basket setfile are unchanged from the prior
governed snapshot. The implementation remains fixed-beta, closed-D1, two-leg
relative value with no ML or banned indicator. The backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the manifest
declares NZDUSD and EURAUD as traded legs and AUDUSD/EURUSD as conversion
histories only.

## Binding CPU stop

The required five-sample whole-host preflight returned 100%, 100%, 100%,
99.95%, and 100%. The average was 99.99% and the maximum was 100%, both above
the explicit 97% hard ceiling. `D:` retained 123.90 GiB free and the paced
launch gate remained one, so CPU was the binding stop.

The supported work-item view showed ten active rows, all Q09_NEWS, claimed
across T1-T10. The path-aware slot census observed eight governed factory
testers on T1, T2, T3, T4, T5, T7, T8, and T10. T6 and T9 had claimed rows but
no visible tester process at that instant; this is recorded as an observation,
not an inferred verdict or repair diagnosis. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

This is a non-duplicate fleet snapshot relative to the preceding
`2026-08-22T22:18:01Z` evidence: the visible factory roster increased from five
to eight testers and the active queue now contains ten Q09_NEWS claims, while
the selected Q06 row itself remains singular and unchanged.

Per the mission stop condition, no candidate advancement, queue mutation,
tester launch, terminal reservation, terminal control, or backtest followed.
Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q06_cpu_stop_20260823T002110Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- The pre-existing untracked Q05 stress setfile and all concurrent unrelated
  worktree changes were left unstaged and untouched.
