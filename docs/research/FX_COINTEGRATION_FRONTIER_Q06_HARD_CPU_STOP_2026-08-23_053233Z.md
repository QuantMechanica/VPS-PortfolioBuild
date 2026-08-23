# FX cointegration frontier: rotating Q09 roster / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T05:32:33Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier fully mechanized; selected existing FX
basket already has one Q06 successor; stopped at the explicit backtest CPU
ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. Another
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

## Binding CPU stop

Five whole-host samples were 100%, 100%, 98.554460%, 100%, and 98.947559%.
Their 99.500404% average and 100% maximum both exceed the explicit 97% hard
ceiling. `D:` retained 121.43 GiB free.

The supported work-item view showed ten active rows, all Q09_NEWS and claimed
across T1-T10. At `05:32:34Z`, the supported path-aware process scan observed
five governed factory terminals on T4, T6, T7, T8, and T9. T1, T2, T3, T5,
and T10 had claimed rows but no visible terminal process in that instantaneous
scan. T3 appeared in an immediate direct process snapshot, bringing that
second instantaneous roster to six. These are observations of active rotation,
not inferred verdicts or repair diagnoses. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

This snapshot is non-duplicate relative to the preceding
`2026-08-23T04:34:14Z` evidence: the supported visible roster rotated from
T1/T2/T4/T6/T7/T8/T10 to T4/T6/T7/T8/T9, and T3 then appeared during the
observation window. The singular selected Q06 row and ten active Q09_NEWS
claims remain unchanged.

Per the mission stop condition, no candidate advancement, queue mutation,
tester launch, terminal reservation, terminal control, compile, or backtest
followed. Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q06_cpu_stop_20260823T053233Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, magic row, or
  external queue row changed.
- All concurrent unrelated worktree changes were left unstaged and untouched.
