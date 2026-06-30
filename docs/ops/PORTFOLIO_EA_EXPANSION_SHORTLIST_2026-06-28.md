# Portfolio EA Expansion Shortlist - 2026-06-28

Context: live book currently has 13 D2c sleeves and is accepted as an aggressive
flat 0.75% risk-per-trade live test. Additional sleeves should improve
diversification rather than add more correlated XAU/US index exposure.

## Current book gap

- No additional `Q12_REVIEW_READY` candidates beyond the live 13-sleeve book.
- Best incremental value is in FX baskets / relative-value commodity sleeves.
- Avoid naive additions from stale Q08 streams: several look good in stream
  triage but already failed Q04/Q05 in the current farm evidence.

## Priority 1 - Active Rescue

### QM5_12712 EURGBP/EURAUD cointegration basket

Status at review:

- Q02 PASS
- Q03 PASS
- Q04 PASS on available 2023-2024 OOS folds
- Q05 previously failed by `ACTIVE_TIMEOUT`, not by strategy metrics

Root cause:

- Q04 recovery recorded `q04_latest_full_year=2024` because 2025 custom-symbol
  history was missing for the basket host/history context.
- Q05/Q06/Q07 still hardcoded full history through `2025.12.31`, so Q05 ran a
  bad 2025 window and timed out.

Action taken:

- Added a shared `full_history_window(latest_full_year)` helper.
- Extended Q05/Q06/Q07 runners with `--latest-full-year`.
- Passed `q04_latest_full_year`/`latest_full_year` through farm promotion and
  runner command construction.
- Requeued `QM5_12712` Q05 with `priority_track=true` and `q04_latest_full_year=2024`.
- Current Q05 run is active on T7 with `-Year 2024 -ToDate 2024.12.31`.

Portfolio read:

- Highest-value near-term candidate because it is true FX/basket exposure and
  addresses a pipeline defect rather than a proven edge failure.

## Priority 2 - Stress-Gate Borderline Repairs

### QM5_11476 USDJPY

- Q04 remains valid after native-report guard audit: `PASS_SOFT`
  (`0.871 / 1.516 / 1.120`).
- Directional decomposition showed the edge is long-side concentrated; the
  original short side drove the Q05 failure.
- Long-only rescue now has Q04 `PASS`, Q05 `PASS`, Q06 `PASS`, Q07 `PASS`.
- Q07 rerun after a retry-summary aggregation fix passed with seed PFs
  `1.10 / 1.10 / 1.14 / 1.09 / 1.07`, variance `6.36%`.
- Q08 standalone is `FAIL_SOFT`: Neighborhood PASS, PBO PASS, Regime PASS;
  soft signals are seasonal, chopping-block, and cost cushion.
- Q09 portfolio contribution is `FAIL_PORTFOLIO`: monthly max correlation
  `0.4446` exceeds the current `0.30` cap, and the current book would degrade
  from Sharpe `1.9598` to `1.8389` while MaxDD rises from `0.4504` to `0.4731`.
- Keep as a robust standalone/soft rescue candidate, but do not add it to the
  current book unchanged.

### QM5_10198 GBPUSD

- Q04 remains valid after native-report guard audit: `PASS`
  (`1.18 / 1.39 / 1.02`).
- Q05 PF is near floor (`0.970`), but DD is too high (`41.80%`).
- Keep as drawdown/filter repair, not quick admission.

### QM5_9636 GBPUSD

- Q04 remains valid after native-report guard audit: `PASS_SOFT`
  (`1.20 / 0.87 / 1.80`).
- Q05 PF is near floor (`0.980`), but DD is too high (`36.85%`).
- Keep as drawdown/filter repair.

### Removed From Borderline Repair

- `QM5_10041 GBPUSD`: old Q04 `PASS` corrects to `FAIL`
  (`0.69 / 0.73 / 1.38`) because the stream missed closing deals.
- `QM5_10300 XTIUSD`: old Q04 `PASS_SOFT` corrects to `FAIL`
  (`0.74 / 1.07 / 1.00`).
- `QM5_11708 AUDUSD`: old Q04 `PASS_LOWFREQ` corrects to `FAIL`
  (`0.23 / 0.91 / 0 trades`).
- `QM5_12361 WS30`: Q04 PASS, but Q05 fails on drawdown:
  `dd_pct=28.28 > 15`; index exposure overlaps existing book.

Evidence: `docs/ops/Q04_NATIVE_REPORT_GUARD_AUDIT_2026-06-28.md`.

## Priority 3 - Basket / Relative-Value Research Queue

- `QM5_12532 AUDNZD cointegration`: Q04 is now PASS on available 2023-2024
  evidence (`q04_latest_full_year=2024`). Q05 was briefly started by an old
  worker without the 2024 cap, so it was requeued; it is pending behind the
  active multi-symbol `QM5_12712` Q05 slot and should run with the capped window
  after that slot frees.
- `QM5_12606 XTI/XAG ratio`: Q02 PASS, Q04 invalid/low-frequency with too few
  pooled trades. Keep as lower-frequency commodity RV candidate.
- `QM5_12609 XTI/USDCAD spread`: one fold above 1, pooled PF below floor. Needs
  filter redesign if pursued.
- `QM5_12605 XTI/XAU breakout`: current Q04 evidence is PF-net 0 across folds;
  de-prioritize unless implementation bug is proven.
- `QM5_12608 XTI/XNG breakout`: still infra-failed in Q04; revisit only after
  runner/history stability is confirmed.

## Ops Notes

- T8-T10 were briefly enabled to expand throughput, but RAM fell below the safe
  headroom. They are disabled again in `D:/QM/strategy_farm/state/disabled_terminals.txt`.
- `farmctl.active_mt5_terminals()` now respects that disabled-terminal file.
- `start_terminal_workers.py` now avoids false worker detection from arbitrary
  PowerShell command lines.
- Active factory is back to T1-T7. `T_Live` was not touched.
- T1-T7 worker daemons were restarted after the Q05/Q06/Q07 cap patch so future
  claims load the current farm runner code.

## Next Actions

1. Wait for `QM5_12712` Q05 result.
2. If Q05 PASS, let cascade continue to Q06/Q07/Q08 with the propagated 2024 cap.
3. If Q05 FAIL by strategy metrics, inspect PF/DD/trades and decide whether a
   minimal basket filter refinement is justified.
4. Park `QM5_11476 USDJPY` for the current book after Q09 rejection; revisit
   only after a material book-composition change or a decorrelation/session
   filter. Treat `QM5_10198 GBPUSD` / `QM5_9636 GBPUSD` as the next
   drawdown-filter repairs.
