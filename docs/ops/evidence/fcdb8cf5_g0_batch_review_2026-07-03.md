# G0 Batch Review - 10 Claude-Authored Cards

Task: `fcdb8cf5-3aeb-4f5d-baca-c7405c5ccaf7`
Reviewer: Codex
Date: 2026-07-03

## Verdict

APPROVED all 10 cards and moved them from:

- `D:/QM/strategy_farm/artifacts/cards_review/`

to:

- `D:/QM/strategy_farm/artifacts/cards_approved/`

Reviewed cards:

- `QM5_12966_gdaxi-weekly-oversold-swing.md`
- `QM5_12967_uk100-weekly-oversold-swing.md`
- `QM5_12968_xag-weekly-oversold-swing.md`
- `QM5_12969_usdjpy-gotobi-nakane-fix.md`
- `QM5_12970_sp500-overnight-session.md`
- `QM5_12971_spx-pre-fomc-drift.md`
- `QM5_12972_gdaxi-pre-ecb-drift.md`
- `QM5_12973_eurusd-monthend-fix-fade.md`
- `QM5_12974_xau-asia-session-drift.md`
- `QM5_12975_ehlers-pma-triple-swing.md`

## Review Notes

R1-R4 pass under `C:/QM/repo/processes/qb_reputable_source_criteria.md`:

- Each card has a single frontmatter `source_id`.
- Entry and exit rules are mechanical.
- Each target has at least one DWX-testable instrument.
- No card uses ML, online learning, grid, martingale, or discretionary logic.

Survivor ports `12966`-`12968` preserve the parent `QM5_12915` parameters:
`sma_regime=200`, `entry_lookback_low=10`, `sma_exit=10`, `time_stop_days=15`.
The ports are symbol/session diversification attempts, not re-fits.

Calendar-signal cards `12971` and `12972` were approved because the 2026-07-03
operating rules explicitly permit news-calendar-as-signal patterns when the
position exits before the restricted event window and the calendar feed fails
closed. This supersedes the older 2026-06-09 research caution that pre-FOMC drift
was weak post-2015, while preserving that risk as a downstream gate concern.

Distinctness caveats accepted:

- `12970` is the pure/no-filter SP500 overnight baseline; related to `QM5_10020`,
  which has a rolling filter and broader index basket.
- `12971` is the fail-closed local-calendar/pre-blackout variant; related to
  older static-calendar FOMC cards `QM5_1094` and `QM5_1213`.
- `12972` is the intraday local-calendar/pre-blackout ECB variant; related to
  older D1 pre-ECB card `QM5_1181`.
- `12974` is the pure clock-only XAU Asia-session variant; related to `QM5_12792`,
  which uses an early-session drift/ATR continuation gate.
- `12973` is a post-fix fade and is distinct from `QM5_10763`, which trades
  directional hedge-rebalancing flow into the WMR fix.
- `12975` uses fixed rolling OLS-slope PMA triple-screen logic and is distinct
  from the existing WMA-cascade Ehlers PMA cross card `QM5_1521`.

## Focused Verification

Final path/frontmatter check:

- All 10 expected files exist in `cards_approved`.
- None of the 10 expected files remains in `cards_review`.
- All 10 have `g0_status: APPROVED`.
- All 10 have `r1_track_record`, `r2_mechanical`, `r3_data_available`,
  and `r4_ml_forbidden` set to `PASS`.
- No `card_body_incomplete` or `card_body_missing` markers remain.

Body coverage check using the same helper as `farmctl approve-card`:

- `_verify_card_body_coverage(...)` returned `{'ok': True, 'missing': []}` for
  all 10 approved cards.

DWX symbol matrix check:

- Found all required symbols:
  `EURUSD.DWX`, `GBPUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`,
  `UK100.DWX`, `USDJPY.DWX`, `XAGUSD.DWX`, `XAUUSD.DWX`.

Calendar archive check:

- `D:/QM/data/news_calendar/news_calendar_2015_2025.csv` exists.
- Federal Funds Rate rows by year:
  2018=8, 2019=8, 2020=9, 2021=8, 2022=8, 2023=8, 2024=8.
- ECB Main Refinancing Rate rows by year:
  2018=8, 2019=8, 2020=8, 2021=8, 2022=8, 2023=8, 2024=8.

## Operational Notes

- `G:` company-reference drive was not mounted in the headless session, so the
  Google Drive reference docs could not be read.
- Repo-local `EDGE_LAB_CHARTER_2026-05-22.md`,
  `PROFITABILITY_TRACK_2026-05-21.md`,
  `OPERATING_RULES_2026-07-03.md`, and the canonical R1-R4 criteria were read.
- No terminal, live trading, AutoTrading, or backtest process was started.
