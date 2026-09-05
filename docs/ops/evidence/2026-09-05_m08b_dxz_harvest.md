# M08-B DXZ overlapping-window harvest

RESULT: REVIEW. One governed measurement completed; all six symbols have explicit EMPTY coverage in the requested 2026-05-26 through 2026-09-04 server-date interval. Matched FTMO/DXZ minutes remain zero for each symbol. No spread delta, cost adoption or pipeline verdict was invented.

The run selected **T3**, which was process-free, claim-free and unreserved at acquisition. Earlier T1 availability changed before execution; the canonical selector rechecked it. One reservation covered compilation and extraction, then the exact owned terminal process was closed and only this reservation released. Total elapsed factory cost including compile was **58.297 seconds** (0.97 minute), below the one-hour budget. Active backtests were not interrupted.

## Measured coverage

| Symbol | Last cached M1 server label | Matching minutes | Delta p50 / p90 |
|---|---|---:|---|
| GBPUSD.DWX | 2026-04-24T23:54:00 | 0 | null / null |
| EURUSD.DWX | 2026-04-06T02:59:00 | 0 | null / null |
| USDCAD.DWX | 2025-12-31T23:59:00 | 0 | null / null |
| NZDUSD.DWX | 2025-12-31T23:58:00 | 0 | null / null |
| XTIUSD.DWX | 2025-12-31T23:59:00 | 0 | null / null |
| XAGUSD.DWX | 2025-12-31T23:58:00 | 0 | null / null |

All six return NO_CACHED_M1_IN_REQUESTED_WINDOW after the existing position-based CopyRates synchronization. The reviewed comparator specification binds custom .DWX archive histories; it does not harvest a current native Darwinex broker-symbol history. EURUSD/GBPUSD stop in April; the other four stop in December 2025. Repeating this extraction cannot create missing dates. A governed archive backfill or separately reviewed native-comparator input is required before overlapping minute evidence exists. Neither was introduced here.

## Timestamp repair and attestation

The review copy [QM_M1_SpreadHarvest.mq5](2026-09-05_m08b_dxz_harvest/QM_M1_SpreadHarvest.mq5) retains raw server labels, declares offset +180 minutes, and writes explicit UTC converted by subtraction. It permits only a bounded 2026 interval inside both US and EU summer regimes, refuses other intervals, records empty coverage as EMPTY and disables optional deep tick probing for this spread-only measurement. Its v2 rows are not silently sent through the old strict v1 projection reader. The canonical harvester source is unchanged; [patch](2026-09-05_m08b_dxz_harvest/timestamp_fix.patch) is ready for review. The canonical compile helper now accepts an explicit source path while retaining its static no-trading check, fresh EX5 check and 0E/0W log requirement. The default source path remains unchanged.

[Darwinex documents](https://www.darwinexzero.com/docs/de/time-in-darwinex-metatrader-terminals) GMT+3 during US summertime and GMT+2 outside it. That rule is a declaration here, not empirical proof of this custom archive or the earlier FTMO exports. No transition week lies in the requested window. The [custom-symbol validation skill](C:/Users/Administrator/.codex/skills/qm/qm-validate-custom-symbol/SKILL.md) requires transition-window comparisons for a validation PASS; no such PASS or registry change is claimed. [MetaQuotes notes](https://www.mql5.com/en/docs/dateandtime/timetradeserver) that TimeTradeServer is a client-calculated current value; it is not used as historical offset evidence. Historical last-cache labels remain raw without a Z suffix, including dates outside the declared conversion interval.

Source SHA-256 `c791f50daeea832cc652db1541231203a3d5e4ec29cc7c312e21475936af29e0` equals staged source. Executed EX5 SHA-256 `b889fff3cbf374f5bdc1079be815747ee6e1405802981a50d39a4fd1fe06908b`. MetaEditor compiled with **0 errors, 0 warnings**; exact compiler and compile-log hashes are in the [receipt](2026-09-05_m08b_dxz_harvest/run_182301/receipt.json). A gzip copy of that binary is evidence only, never an EA deployment.

## Verification and artifacts

23 bootstrap tests pass, including explicit-source and default-source compile bindings. The six EMPTY coverage documents and compiled binary are deterministic gzip files with verified raw/stored hashes. All six earlier frozen FTMO inputs also reproduce both hashes. [Matched-minute table and four session bands per symbol](2026-09-05_m08b_dxz_harvest/matched_minutes.json) retain n=0 and null quantiles throughout. Old literal-Z FTMO clock evidence remains unverified. No empirical row-conversion test is claimed because this run had no bars in the window. [Verification](2026-09-05_m08b_dxz_harvest/verification.json). No live setting, admission, economic input or existing verdict changed.
