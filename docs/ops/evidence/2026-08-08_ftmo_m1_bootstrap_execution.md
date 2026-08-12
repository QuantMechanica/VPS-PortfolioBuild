# FTMO M1 bootstrap — Saturday OWNER-window execution record

Date: 2026-08-08 (window granted Sat/Sun per ticket `1b00f708` verdict)
Executed by: Claude (orchestration + review fixups), tooling by Codex
(`ae5331f67`, review APPROVED, ticket `a6322102`)

## Outcome

**FTMO side COMPLETE** — the expiring resource (shared demo `1514165262`,
expiry ~2026-08-16) is secured:

| Lane / symbol | Result | Coverage | Projection |
|---|---|---|---|
| FTMO_STREAM1 / XAUUSD | PASS (HOLD_PARTIAL→resolved) | 100,000 M1 bars, 101.66 days, 2026-04-28T07:55Z → 2026-08-07T23:49Z, ticks aligned | `XAUUSD_FTMO_M1.jsonl` sha `257549cd…73066` (11.5 MB) |
| FTMO_STREAM2 / GER40.cash | PASS | 100,000 M1 bars, 105.17 days, 2026-04-24T18:38Z → 2026-08-07T22:49Z, ticks aligned | `GER40_cash_FTMO_M1.jsonl` (12.0 MB) |

Both lanes ran strictly serially; `qm.ftmo-history-coverage/v1` observations
were written for BOTH lanes with zero holds (STREAM2 run receipt). The
challenge terminal (PID 10400) was observed-only throughout; AutoTrading
untouched; identity re-checked every poll cycle.

**DXZ side PARKED** (own store, no expiry): the fresh-profile chart series
for `XAUUSD.DWX` on T2 serves only a 2025-09-16→~2025-12 window to
position-based CopyRates (100k bars, `kept=0` for the 2026 window) although
the Custom store provably holds 2026 real-tick data (daily backtests).
Chart-series/cache semantics for custom symbols on virgin `/config` profiles
need a different extraction route (tester-context or series-cache priming).
Completion is scheduled post-migration (isolated per-terminal stores make
this cleaner) and is NOT deadline-bound.

## Seven live defects found and fixed during the window

The mocked test suite (80+5 green) could not see any of these; every one
was found by executing against the real platform, fixed, tested, committed:

1. `10ca5dc58` — WMI `/Date(ms)/` CreationDate format (PowerShell 5.1
   ConvertTo-Json) unparsed → instant refusal.
2. `fd4e4614b` (1/3) — startup.ini lacked `[Common]` Login/Server → terminal
   never connected, all CopyRates 4401.
3. `fd4e4614b` (2/3) — first-sync retry budget far too small (12×~3s);
   now connect-wait 180s + 40 retries with backoff.
4. `fd4e4614b` (3/3) — termination guard compared CreationDate at 100ns
   ticks vs millisecond input → structural false "drift"; now second
   granularity (PID+path+second).
5. `e72f4b618` — deep time-window requests stay 4401 even when connected
   (backward server backfill); position-request warm-up + honest
   `SERIES_FIRSTDATE` depth; tolerant identity scan (unrelated incomplete
   process rows no longer abort); exhausted deep-tick 4401 = "no ticks",
   never discards bars.
6. `0c1bd8b29` — per-path login context; a partial earlier patch had left
   the FTMO login unconditional and hijacked T2's Darwinex login; dxz now
   reads login/server from untracked
   `D:/QM/strategy_farm/state/dxz_factory_login.json` (account material
   stays out of the repo).
7. `6a0b…/last` — time-window CopyRates on fresh profiles returns instant
   0/no-error outside the loaded series cache; bars now fetched
   position-based and filtered; `NO_BARS_IN_WINDOW` closes the last
   printless death path; tick failure yields null coverage
   (contract-allowed) instead of deleting bars.

Orphan handling: two doomed idle-wait runs were terminated via guarded
path-verified kills (only the exact spawned PIDs); no factory claim, no
T_Live/challenge process was ever signalled.

## Remaining for close-out (post-migration, before 2026-08-16)

1. DXZ-side extraction of `XAUUSD.DWX` / `GDAXI.DWX` M1 spreads (route via
   tester-context run or primed series cache) to the two spec paths.
2. `portfolio/ftmo_spread_calibration.py --spec 2026-08-02 …` with the
   .DWX spread-field plausibility check (real TDS bid/ask spreads, nonzero)
   BEFORE accepting any delta — a zero/synthetic .DWX spread field would
   double-count costs and voids the result.
3. Session-bucket quantile table → evidence + ticket `1b00f708` close.
