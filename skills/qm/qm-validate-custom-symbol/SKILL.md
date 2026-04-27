---
name: qm-validate-custom-symbol
description: Use when introducing a new custom symbol on T1-T5 OR verifying broker time / DST behavior of an existing symbol against DarwinexZero MT5 server time. Don't use when the symbol is already in `framework/registry/` with `validation_status=PASS` within the last 90 days, or for purely intentional read-only chart inspection.
owner: DevOps + Pipeline-Operator
reviewer: Quality-Tech
last-updated: 2026-04-27
basis: docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md (verbatim procedure mirror)
---

# qm-validate-custom-symbol

Validation procedure for any custom symbol imported via Tick Data Manager (TDM) onto factory terminals T1-T5. Mirrors the DarwinexZero New-York-Close server-time convention that is enforced on the broker side and cannot be changed in the terminal.

This skill is the procedure that ran on `EURUSD.DWX` on Wave-0 day 1 (P0-21 PASS, evidence path: `D:\QM\reports\setup\tick-data-timezone\REPORT_2026-04-25_test_eurusd_dst_match.md`).

## When to use

- A new custom symbol is being imported via TDM (e.g. `WS30.DWX`, `XAUUSD.DWX`)
- Tick Data Suite has been upgraded
- Any broker / data-source setting changed
- An existing symbol's `validation_status` is older than 90 days

## When NOT to use

- Symbol already has `validation_status=PASS` < 90 days old in `framework/registry/`
- Read-only chart inspection (no import, no backtest dependency)
- Strategy PASS/FAIL evaluation — timezone/DST mismatch is **never** a strategy signal (it is `SETUP_DATA_MISMATCH`)

## DarwinexZero time convention

DarwinexZero MT4/MT5 terminal time is set on the broker server as **New-York-Close**:

- `GMT+3` during US summertime
- `GMT+2` when US Daylight Saving Time has ended
- The offset is server-side; it cannot be changed in the terminal

Source: https://www.darwinexzero.com/docs/de/time-in-darwinex-metatrader-terminals

`broker_time` ≠ `local_time` ≠ `utc_time`. Never compare or merge timestamped artifacts without naming which time field is being used.

## Procedure

1. **Configure TDM.** Base GMT offset = `+2`, DST = enabled. The legacy DST option label "European" is observed legacy — do **not** treat it as proof. EU and US DST transitions differ in March and November, so the selected DST option must be verified.

2. **Pick two transition windows.** Cover both DST switches:
   - **March transition:** one week spanning the US DST start AND the EU DST start (different days)
   - **October/November transition:** one week spanning the EU DST end AND the US DST end

3. **Pick a sample symbol.** High-liquidity, already visible in DarwinexZero MT5. Default = `EURUSD`. For new custom symbols, also run the comparison against the new symbol once a peer is verified.

4. **Export sample bars.** Export M15 or H1 bars for both windows with the intended TDM settings.

5. **Open the live MT5 chart.** In the connected DarwinexZero MT5 terminal, open the same symbol/timeframe and scroll to the same dates.

6. **Compare timestamps.** At each of:
   - Daily open
   - Friday close
   - At least two intraday candles per window

7. **Save evidence.** Write to `D:\QM\reports\setup\tick-data-timezone\`:
   - TDM settings screenshot
   - Exported sample path (full path, not just filename)
   - MT5 chart screenshot
   - Short QA note naming which time field was used for which artifact

8. **Acceptance criteria.** Exported bars reproduce DarwinexZero's documented server-time behavior:
   - `GMT+2` outside US DST
   - `GMT+3` during US DST
   - 0-second offset on candle opens
   - Sub-pip OHLC differences acceptable

9. **Update registry.** Write `validation_status=PASS` (with date + evidence path) to `framework/registry/` for the symbol. On mismatch: classify `SETUP_DATA_MISMATCH`, file an issue, do **not** mark PASS.

## After PASS

- Master copy lives on T1 (`D:\QM\mt5\T1\Bases\Custom\`)
- Inherit to T2-T5 by copying the Custom directory
- Per-terminal verification still required — do not assume copy-equivalence across terminals
- `portable.txt` marker file must exist in each terminal's install root (per `processes/process_registry.md` § Factory Setup Standards)

## Boundary

- This procedure does **not** trade live, does **not** touch T6, and does **not** evaluate strategy quality
- T6 has its own data directory and is never used for TDM imports

## References

- `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md` — full source spec (mirrored above)
- `docs/ops/DWX_IMPORT_AUTOMATION.md` — `<root>.DWX` naming convention
- `references/tick_csv_columns.md` — expected CSV column order for TDM exports
- `decisions/2026-04-26_tds_renewal_skip.md` — why TDS license is not currently renewed (existing exports cover Wave-0)
- Wave-0 evidence: `D:\QM\reports\setup\tick-data-timezone\REPORT_2026-04-25_test_eurusd_dst_match.md`
