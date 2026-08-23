# FX cointegration frontier: Q06 active / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T08:46:59Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier fully mechanized; selected existing FX
basket advanced from pending to active Q06 through the governed fleet; stopped
at the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. Another
scan-derived identity would duplicate governed work.

Fresh supported work-item queries reconfirmed that the preferred anchors do
not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has terminal Q02 PASS
  (`e4890d77-b865-4a48-b946-315faefca920`) and Q04 PASS, followed by Q05
  FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has terminal Q02 PASS
  (`76cb11ee-7e9d-4d75-be9d-626c205bca62`), followed by Q04 FAIL.

Neither anchor has a current ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The non-duplicate continuation remains the structural D1 `NZDUSD.DWX` /
`EURAUD.DWX` basket `QM5_20208_nzdusd-euraud`, rank 27 in the frozen scan. A
fresh supported operator query returned exactly four lineage rows:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.
- Q06 `776e6310-7ad6-41ba-8a08-4d63e045d4e5`: active on T6, attempt 0,
  with no verdict yet.

There is exactly one Q06 row. Since the preceding snapshot at
`2026-08-23T07:48:26Z`, the governed fleet advanced it from pending and
unclaimed to active on T6. An enqueue, requeue, priority restamp, duplicate
dispatch, or manual tester launch was therefore neither needed nor valid.

## Binding CPU stop

Five whole-host samples were 88.022568%, 99.713680%, 99.137564%, 85.104537%,
and 86.047710%. Their 91.605212% average was below the ceiling, but the
99.713680% maximum exceeded the explicit 97% hard ceiling. `D:` retained
129.52 GiB free.

The supported work-item view showed eight active rows: six Q09_NEWS and two
Q06. At `08:46:27Z`, the supported path-aware process scan observed two
governed factory terminals, T4 and T10. T1, T2, T3, T5, T6, and T8 had
claimed rows but no visible terminal process in that instantaneous scan. Two
terminal reservations were present (T4 and T10). These are observations of
active fleet rotation, not inferred verdicts or repair diagnoses. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them; neither
was controlled.

This snapshot is non-duplicate relative to the preceding
`2026-08-23T07:48:26Z` evidence: the selected Q06 row changed from pending to
active on T6, the active phase mix changed from one Q07 plus nine Q09_NEWS
rows to two Q06 plus six Q09_NEWS rows, and the supported visible factory
roster changed from T4/T7 to T4/T10. The hard ceiling remains triggered by
the maximum sample.

Per the mission stop condition, no candidate advancement, queue mutation,
dispatch tick, tester launch, terminal reservation, terminal control,
compile, or backtest followed. Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q06_active_cpu_stop_20260823T084659Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, magic row, or
  external queue row changed.
- All concurrent unrelated worktree changes were left unstaged and untouched.
