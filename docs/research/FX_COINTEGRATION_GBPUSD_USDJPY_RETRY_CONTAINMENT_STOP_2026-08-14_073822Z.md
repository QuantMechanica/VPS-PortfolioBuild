# FX cointegration fallback — Q02 retry containment stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 GBPUSD/USDJPY Q02 returned
to PENDING after one infrastructure attempt; signed custom-history containment
is active

## Outcome

No duplicate Card, EA, basket manifest, setfile, or Q02 row was created. The
committed sign-aware reconciliation of `analyze_cross_asset_v3.py
--include-negative-hedges` covers all 66 scan relationships, so a new
scan-derived pair would duplicate an existing governed build.

The two requested anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair advance and retry state

The non-duplicate fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as pair slot 8 in the approved and built
`QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`.

The governed worker claimed the row on T4 at `2026-08-14T06:38:24Z`. The run
reached MT5 launch and returned `run_smoke_exit_code=0`, but emitted no summary
or authenticated report; the only run artifact is `tester.ini`. At
`2026-08-14T06:52:39Z` the worker returned the same row to PENDING in place
with `attempt_count=1`, `prior_failure=summary_missing`, and `avoid_terminals`
set to T4. The row has no active hold or poison-pill quarantine and remains
enqueued exactly once. No enqueue, requeue, priority, timestamp, reservation,
or dispatch mutation was performed by this mission.

This is infrastructure evidence, not a strategy verdict. The implementation
remains bound to the OWNER-approved Lemishko, Landi, and Caicedo-Llano (2024)
SSRN Card with R1-R4 PASS. Its basket manifest declares `GBPUSD.DWX` and
`USDJPY.DWX`; the logical H1 setfile uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No refit, added filter, banned or
ML indicator, rescue tuning, or profitability claim was introduced.

## Binding capacity and integrity stop

The target was already active during the prior 10/10 factory CPU-ceiling
sample. After that attempt, multiple terminal-worker daemons logged
`MemoryError` while verifying staged EX5 hashes. A read-only operating-system
sample at `2026-08-14T07:38:22Z` showed only 2,370,660 KiB free out of
66,185,976 KiB, while two unrelated governed MT5 jobs remained active on T3
and T5.

A stricter signed control also blocks the retry. Automatic custom-history
containment re-engaged at `2026-08-14T07:30:38Z`. Worker audit
`faff615961831140381b8d8ac9a3ef8ad87c6ce313b5f89e9dcb51517bb8c81c`
is `FAIL_CLOSED` because T8 is missing three manifest-bound archives:

- `history/SP500.DWX/2020.hcc`
- `history/SP500.DWX/2021.hcc`
- `history/UK100.DWX/2022.hcc`

The audit emitted six findings: one `MANIFEST_ARCHIVE_FILE_MISSING` and one
`TERMINAL_MANIFEST_INCOMPLETE` per archive. Bypassing containment, restoring
archives, stopping active workers, or forcing another tester would exceed this
branch-only mission. Per the explicit capacity stop rule, no additional
backtest or dispatch was started.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live deployment artifact
  changed.
- No Card, EA, registry, magic row, basket manifest, setfile, or external queue
  row changed.
- Concurrent unrelated worktree changes were not staged or modified.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_retry_containment_stop_20260814T073822Z_board_advisor.json`.
