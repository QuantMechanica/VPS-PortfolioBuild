# FX cointegration frontier: Q06 retry / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T09:17:41Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier fully mechanized; selected existing FX
basket rotated from active Q06 back to its unique pending retry; stopped at
the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from `analyze_cross_asset_v3.py
--include-negative-hedges`: 66 covered and zero uncovered. Another
scan-derived identity would duplicate governed work.

Fresh supported work-item queries reconfirmed that the preferred anchors do
not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has terminal Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has terminal Q02 PASS, followed
  by Q04 FAIL.

Neither anchor has a current ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The non-duplicate continuation remains the structural D1 `NZDUSD.DWX` /
`EURAUD.DWX` basket `QM5_20208_nzdusd-euraud`, rank 27 in the frozen scan. A
fresh supported operator query returned exactly four lineage rows:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.
- Q06 `776e6310-7ad6-41ba-8a08-4d63e045d4e5`: pending, unclaimed,
  `attempt_count=1`, with no verdict or evidence path.

This is a material state change from the preceding snapshot at
`2026-08-23T08:46:59Z`, which observed the same unique Q06 row active on T6
at attempt 0. The attempt directory contains only the generated `tester.ini`;
no summary, aggregate, or tester report was present. That is insufficient to
infer an economic or implementation verdict. The governed worker returned
the existing row to pending for its retry, so an enqueue, requeue, priority
restamp, duplicate dispatch, or manual tester launch was neither needed nor
valid.

The generated tester configuration binds the canonical basket host
`NZDUSD.DWX`, D1, the full 2018-07-02 through 2025-12-31 range, USD 100,000
tester account, and the Q06 harsh-stress setfile. No strategy or risk setting
was changed.

## Binding CPU stop

Five whole-host samples were 94.145999%, 88.035240%, 91.201679%, 100%, and
100%. Their 94.676584% average was below the ceiling, but the 100% maximum
exceeded the explicit 97% hard ceiling.

The supported work-item view showed six active rows, all Q09_NEWS. The
supported path-aware process scan observed four governed factory terminals:
T2, T4, T5, and T9. `T_Live` and the unrelated FTMO terminal were observed
only to exclude them; neither was controlled.

Per the mission stop condition, no candidate advancement, queue mutation,
dispatch tick, tester launch, terminal reservation, terminal control,
compile, or backtest followed. Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q06_retry_cpu_stop_20260823T091741Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- All concurrent unrelated worktree changes were left unstaged and untouched.
