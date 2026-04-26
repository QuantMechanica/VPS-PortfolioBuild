# Tick Data Manager DarwinexZero Time Rule

Created: 2026-04-22
Owner: DevOps + Pipeline-Operator
Reviewer: Quality-Tech

## Source Of Truth

DarwinexZero MT4/MT5 terminal time is configured as New York Close server time:

- GMT+3 during US summertime
- GMT+2 when US Daylight Saving Time has ended
- the time is set on the Darwinex MetaTrader server and cannot be changed in the terminal

Official source:
https://www.darwinexzero.com/docs/de/time-in-darwinex-metatrader-terminals

This is a broker/server-time convention. It does not mean the physical trading server is located in a GMT+2 region.

## Time Fields

- `local_time`: Windows server operational time, currently `Europe/Vienna` / `W. Europe Standard Time`. Use for Task Scheduler, dashboard generation, operator logs, and human-readable run notes.
- `broker_time`: DarwinexZero MT5 server time, New-York-Close convention. Use for MT5 bars, trade timestamps, and Tick Data Manager validation.
- `utc_time`: normalized UTC timestamp. Use for machine comparison, public dashboard snapshots, and cross-system joins.

Do not compare or merge timestamped artifacts without naming which time field is being used.

## Tick Data Manager Default

- Base GMT offset: `+2`
- DST: enabled
- DST rule: must reproduce DarwinexZero's US-DST-based switch from GMT+2 to GMT+3

The legacy local screenshot shows `GMT offset +2` with `DST: European`. Treat that as an observed legacy setting, not as final proof. EU and US daylight-saving transitions differ during parts of March and November, so the selected Tick Data Manager DST option must be verified before large downloads or gate backtests.

## Required Verification

Before the first bulk tick download, after Tick Data Suite upgrades, and after any broker/data-source setting change:

1. Configure Tick Data Manager with base GMT offset `+2` and DST enabled.
2. Pick at least two one-week samples:
   - March transition check: week spanning the US DST start and the EU DST start.
   - October/November transition check: week spanning the EU DST end and the US DST end.
3. Use a high-liquidity symbol already visible in DarwinexZero MT5, preferably `EURUSD`.
4. Export M15 or H1 bars for the sample windows with the intended Tick Data Manager settings.
5. Open the same symbol/timeframe in the connected DarwinexZero MT5 terminal and scroll to the same dates.
6. Compare candle open timestamps at daily open, Friday close, and at least two intraday candles.
7. Save evidence in `D:\QM\reports\setup\tick-data-timezone\`:
   - Tick Data Manager settings screenshot
   - exported sample path
   - MT5 chart screenshot
   - short QA note
8. Acceptance: exported bars reproduce DarwinexZero's documented server-time behavior: GMT+2 outside US DST and GMT+3 during US DST.
9. If timestamps differ, classify the issue as `SETUP_DATA_MISMATCH`.

Timezone/DST mismatch is never a strategy PASS/FAIL signal.

## Phase 0 Todo

Create Paperclip issue: `P0: Verify Tick Data Manager DarwinexZero GMT/DST settings`.

Owner: DevOps + Pipeline-Operator
Reviewer: Quality-Tech
Gate: must pass before any bulk tick download or V5 gate backtest.

## Status (2026-04-26)

P0-21 **PASS on T1** per `D:\QM\reports\setup\tick-data-timezone\REPORT_2026-04-25_test_eurusd_dst_match.md` — TEST-EURUSD verified against broker EURUSD across winter / US-DST-only / both-DST windows with 0-second offset and sub-pip OHLC differences.

**TDS renewal:** SKIPPED per `decisions/2026-04-26_tds_renewal_skip.md`. Existing exports (~30 symbols, ~500GB) cover V5 first-wave; future fresh imports require short-term re-buy (€32.90/month).

**Custom-symbol naming convention:** `<root>.DWX` for every TDM-imported symbol per `docs/ops/DWX_IMPORT_AUTOMATION.md` (e.g., `EURUSD.DWX`, `XAUUSD.DWX`, `WS30.DWX`). T1 is master; T2-T5 inherit by copying `D:\QM\mt5\T1\Bases\Custom\`.

**Open follow-ups** (post-Wave-0): T2-T5 propagation + per-terminal verification, `portable.txt` drop, AppData `…BA21BF\` rename, full TDS recipe (settings + tick source + contract spec) captured here as a How-To section.
