# QUA-775 Setfile Revalidation Snapshot

- timestamp_local: 2026-05-08 08:25:35 +02:00
- issue: QUA-775
- ea: QM5_1017
- scope: D1 curated-pair P2 redeploy blocker re-check

## Commands Run

1. python framework/scripts/p2_baseline.py --ea QM5_1017 --dry-run
2. python framework/scripts/p2_baseline.py --ea QM5_1017 --period D1 --dry-run
3. Get-ChildItem framework/EAs/QM5_1017_chan_pairs_stat_arb/sets | Sort-Object Name

## Results

- H1 dry-run: DRY=36, INVALID=0, no setfile_missing.
- D1 dry-run: DRY=7, INVALID=0, no setfile_missing.
- Current D1 setfiles present:
  - QM5_1017_chan_pairs_stat_arb_AUDCAD.DWX_D1_backtest.set
  - QM5_1017_chan_pairs_stat_arb_AUDUSD.DWX_D1_backtest.set
  - QM5_1017_chan_pairs_stat_arb_EURUSD.DWX_D1_backtest.set
  - QM5_1017_chan_pairs_stat_arb_GBPUSD.DWX_D1_backtest.set
  - QM5_1017_chan_pairs_stat_arb_NZDUSD.DWX_D1_backtest.set
  - QM5_1017_chan_pairs_stat_arb_XAGUSD.DWX_D1_backtest.set
  - QM5_1017_chan_pairs_stat_arb_XAUUSD.DWX_D1_backtest.set

## Operational Conclusion

The previously reported blocker (4/4 setfiles missing) is not reproducible from filesystem truth on this heartbeat. Setfile resolution is currently healthy for both H1 and D1 runner paths.

## Next Action

- Board/issue owner to refresh QUA-775 status from locked to in_progress and provide the exact intended D1 curated symbol subset if it differs from the runner's current D1 universe (7 symbols).
- Pipeline-Operator can execute the real D1 P2 run immediately once the target symbol subset is confirmed.

## Execution Follow-up (same heartbeat)

- Command: python framework/scripts/p2_baseline.py --ea QM5_1017 --period D1
- Shell timeout: 120s (wrapper returned 124), but runner emitted terminal [P2 DONE] and persisted outputs.
- Fresh artifact timestamps:
  - D:\QM\reports\pipeline\QM5_1017\P2\report.csv (updated 2026-05-08 08:27:42 +02:00)
  - D:\QM\reports\pipeline\QM5_1017\P2\p2_QM5_1017_result.json (updated 2026-05-08 08:27:42 +02:00)
- Current D1 outcome pattern: symbols executed; no setfile_missing emitted in this run; modal verdict remains FAIL via un_smoke_fail:MIN_TRADES_NOT_MET (expected for zero-trade scaffold behavior).

## Block State Update Recommendation

Setfile blocker condition is cleared by filesystem + runner evidence. If QUA-775 remains blocked, blocker reason should be revised away from missing setfiles to the actual gating condition (if any) based on report review.
