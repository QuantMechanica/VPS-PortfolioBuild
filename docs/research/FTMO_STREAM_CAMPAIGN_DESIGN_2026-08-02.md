# FTMO-venue attested stream campaign — wave-1 design

**Date:** 2026-08-02
**Decision owner:** OWNER / Claude review
**Implementer:** Codex
**Scope:** five sealed historical sleeves; research evidence only

## Decision

Wave 1 must run in a **native, tester-only FTMO-Demo lane**, not in the normal
T1-T10/Darwinex queue and not in the existing Book3 replay lane. The normal
queue and Book3 both inherit Darwinex bid/ask history. Repricing only commission
and swap would leave that spread in every realized trade and would correctly be
refused by `ftmo_timebox_eval.py` as `REFUSED_DXZ_SPREAD_INHERITANCE`.

The daily exporter is now implemented at
`tools/strategy_farm/portfolio/ftmo_daily_net_export.py`. It is read-only with
respect to terminals, queues, databases, and live settings. It refuses output
unless all of the following bind to the same run:

1. a `run_smoke/v2` PASS summary and its hashed native report;
2. a report headed by FTMO-Demo, with an FTMO company, the native FTMO symbol,
   model-4 real ticks, and the requested window;
3. the exact set file, with `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and no
   `qm_news_stale_max_hours` value above 336;
4. a homogeneous `FULL_POSITION_LIFECYCLE_ACTUAL_V1` Q08 trade harvest whose
   identity and money fields reconcile deal-by-deal to the report;
5. account-scope daily equity snapshots from that run; and
6. the pinned FTMO snapshot
   `7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da`,
   including active, non-null commission, long-swap, and short-swap terms.

There is currently **no provisioned native FTMO tester lane** in the factory.
The installed FTMO profile is the live/trial data directory; it is not an
admissible research lane and must not be contacted, copied opportunistically,
or used to start a tester. Consequently, wave-1 enqueue is gated. Issuing a
normal `farmctl enqueue-backtest` command now would create Darwinex evidence,
not FTMO evidence. No enqueue is authorized until the lane receipt described
below exists and Claude has reviewed it.

This is an infrastructure gate, not a pipeline verdict and not evidence that a
sleeve fails the FTMO time-box.

## Cost-basis attestation

### Pinned terms

| Evaluator symbol | Native FTMO symbol | Snapshot code | Commission | Swap long / short | Contract |
|---|---|---|---:|---:|---:|
| XAUUSD | `XAUUSD` | `XAU/USD` | 0.0014% | -75.93 / -23.55 points | 100, 2 digits, USD P/L |
| GDAXI | `GER40.cash` | `GER40.cash` | 0% | -424.13 / -27.07 points | 1, 2 digits, EUR P/L |

An instrument is excluded if either swap side, commission value/type, active
flag, contract size, digits, swap type, or profit currency is absent. There is
no substitution, zero-fill, proxy, or cross-instrument approximation.

### Evidence chain

The report itself supplies the spread provenance: a native FTMO-Demo report on
`XAUUSD` or `GER40.cash`, with model-4 real ticks, realizes profit through the
FTMO bid/ask stream. A `.DWX` report is refused before any daily row is written.

Commission and swap are then checked twice:

- the Q08 full-lifecycle row must exactly reconcile native entry commission,
  exit commission, swap, profit, and net to the report within the existing
  money tolerance; and
- native deal commission and rollover swap must reconcile to the pinned
  percent/point schedule. XAUUSD is USD-denominated. GER40.cash uses the
  report-reconciled profit-currency conversion; an uncheckable rollover fails
  closed.

The exporter writes a separate
`qm.ftmo-daily-net-export-receipt/v1` receipt with SHA-256 bindings for the
summary, report, Q08 trades, equity log, snapshot, set file, and output stream.
The receipt is audit evidence; it does not authorize selection, pipeline
promotion, deployment, challenge purchase, or live use.

## What can be reused, and what is missing

| Component | Existing capability | Reuse decision / missing item |
|---|---|---|
| Book3 Q02 isolation | Held work items (`FTMO_BOOK3_Q02_ISOLATED_ONLY`), exact-window payloads, immutable pre/post stream harvesting, full-lifecycle reconciliation, isolated evidence roots | Reuse the hold, snapshot/delta, hash-receipt, and no-promotion patterns. Do not reuse its prices: the Book3 symbols are `.DWX`, so spread remains Darwinex. Do not release or edit its holds. |
| Book3 runner | Binds EX5/set/calendar identities and prevents ordinary factory collection | Its contract is deliberately specific to Book3/T10. A native FTMO runner must be a separate contract; widening the Book3 contract would blur the survivor-port boundary. |
| 20009 news path | Exact FTMO `PRE30_POST30`, high-impact, fail-closed policy; `qm_news_stale_max_hours=336`; source/Common-file hash and coverage checks | Reuse the same calendar seed/copy preflight and FTMO compliance profile. Refresh `D:/QM/data/news_calendar` and the FILE_COMMON copies when stale; never raise 336. The 20009 EA or live governor is not part of this campaign. |
| `venue_cost_model.json` | Records the pinned FTMO commission/swap terms and explicitly labels the DXZ spread/swap axes open | Reuse terms and mappings. It does not convert a DXZ report into FTMO evidence. |
| Native FTMO terminal | FTMO terminal installation/live-trial profile exists outside the research fleet | **Missing:** two dedicated portable tester-only profiles, provisioned from an approved receipt, logged into FTMO-Demo, AutoTrading disabled, no charts/live profile, native history and real ticks for XAUUSD and GER40.cash. The live/trial data directory is forbidden. |
| Native lane lifecycle | T1-T10 workers own process trees, reports, retries, and terminal capacity | **Missing:** reviewed FTMO-lane claim/monitor/harvest wiring. It must own only `FTMO_STREAM1/2`, cap concurrency at two, and never classify its rows as Q-pipeline PASS/FAIL. |
| Daily conversion | No prior `FTMO_DAILY_NET_V1` producer | Implemented by `ftmo_daily_net_export.py`, with focused tests. |

### Required lane-provision receipt

Before enqueue, Claude must review a durable receipt for each of
`FTMO_STREAM1` and `FTMO_STREAM2` proving:

- the resolved portable root is dedicated to research and is neither an
  AppData/live-trial directory nor `T_Live`;
- server is FTMO-Demo and company contains FTMO;
- AutoTrading/Experts is disabled and was not enabled by provisioning;
- native `XAUUSD` and `GER40.cash` real-tick history covers the common campaign
  window;
- the runner can bind terminal EXE, server profile, EX5, set file, tester INI,
  report, Q08 trade delta, and equity-log delta by hash; and
- the lane owns a capacity permit that leaves at least eight of ten normal
  factory slots available.

The receipt must not contain or expose account secrets. Provisioning and
credential handling are outside this ticket's authority.

## `FTMO_DAILY_NET_V1` stream contract

Every JSONL row has exactly these fields; no extras are admitted by the
evaluator:

| Field | Contract |
|---|---|
| `schema` | Literal `FTMO_DAILY_NET_V1` |
| `sleeve_id` | Sealed `<ea_id>:<evaluator_symbol>` identity |
| `symbol` | Evaluator symbol (`XAUUSD` or `GDAXI`), not broker alias |
| `date` | Continuous Europe/Prague broker-calendar date, `YYYY-MM-DD` |
| `net_return` | Account-equity close / broker-midnight equity - 1 |
| `intraday_low_return` | Conservative daily low / broker-midnight equity - 1; never above `min(0, net_return)` |
| `trade_count` | Number of full-lifecycle positions opened that broker day |
| `eligible_start` | True only on an observed broker trading day (or the reconciled final weekday); closed/missing calendar days remain in the stream but are false |
| `flat_at_end` | False when any reconciled lifecycle crosses that broker midnight |
| `venue` | Literal `FTMO` |
| `spread_basis` | Literal `FTMO_TERMS` |
| `commission_basis` | Literal `FTMO_TERMS` |
| `swap_basis` | Literal `FTMO_TERMS` |
| `cost_snapshot_sha256` | Exact pinned digest above |

The equity close comes from account-scope `EQUITY_SNAPSHOT` rows. The final
tester day has no next-day tick with which the framework can emit a rollover
snapshot; only for that final date, the exporter uses initial deposit plus
native report net after the report parser proves every entry has a matching
exit. Missing calendar dates are forward-filled and retained so the evaluator
sees a strictly contiguous calendar.

The intraday low is the existing conservative Q08 bound: broker-day start
balance plus the sum of the MAE of every trade whose lifecycle overlaps that
day, treating all overlapping MAEs as simultaneous. The full-lifecycle money
helper includes entry commission and caps realized losses consistently. This
can make the low more adverse than any observed simultaneous path; it cannot
claim a better low merely because the exact intraday equity trace is absent.

## Wave 1

All five streams use the **common overlap window 2018-07-02 through
2025-12-31**. A common calendar is required by the evaluator for a composition;
using the longer XAU history would make mixed XAU/GDAXI compositions
inadmissible. The set files already specify `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

The tester-cost range is a planning estimate, not pipeline evidence. It uses
the latest comparable full-history DXZ baseline elapsed time (run tag to
summary publication) and adds native-profile/tick-sync margin.

| Order / lane | Sleeve | Native symbol / TF | Exact set file | Common window | DXZ proxy | Estimated FTMO terminal cost | Current blocker |
|---|---|---|---|---|---:|---:|---|
| 1 / A | `10128:XAUUSD` | `XAUUSD` / D1 | `framework/EAs/QM5_10128_bb-breakout/sets/QM5_10128_bb-breakout_XAUUSD.DWX_D1_backtest.set` | 2018-07-02..2025-12-31 | 10.4 min | 15-25 terminal-min | None in sealed inventory; sole `CHALLENGE_READY` sleeve. |
| 2 / B | `13036:GDAXI` | `GER40.cash` / M15 | `framework/EAs/QM5_13036_balke-go-long-regime/sets/QM5_13036_balke-go-long-regime_GDAXI.DWX_M15_backtest.set` | same | 4.6 min | 10-20 terminal-min | Q03 pass missing. This does not block historical stream production, but the stream earns no pipeline promotion. |
| 3 / A | `10145:XAUUSD` | `XAUUSD` / D1 | `framework/EAs/QM5_10145_tsm-meanret/sets/QM5_10145_tsm-meanret_XAUUSD.DWX_D1_backtest.set` | same | 10.6 min | 15-25 terminal-min | Current qualification evidence predates current build. The run must bind the reviewed current EX5; old Q08 bytes cannot be reused. |
| 4 / A | `10183:XAUUSD` | `XAUUSD` / D1 | `framework/EAs/QM5_10183_carver-multi-sig/sets/QM5_10183_carver-multi-sig_XAUUSD.DWX_D1_backtest.set` | same | 13.2 min | 18-30 terminal-min | Missing Q02/Q03 and Q04 `PASS_SOFT`; no pipeline credit implied. |
| 5 / B | `13301:GDAXI` | `GER40.cash` / M5 | `framework/EAs/QM5_13301_balke-minute-range-breakout/sets/QM5_13301_balke-minute-range-breakout_GDAXI.DWX_M5_backtest.set` | same | 19.9 min | 25-40 terminal-min | **Do not enqueue yet:** two `QM5_13301_*` EA directories make the build non-clean; Q04 is `PASS_SOFT`. Claude must close the build-identity ambiguity first. |

Lane A runs the three XAU sleeves serially; lane B runs the two GER40 sleeves
serially, with 13301 held until its build identity is clean. Starting with
10128 and 13036 produces one clean sleeve per instrument quickly and exercises
both cost schedules before spending the remainder of the wave.

Current EX5/set identities to freeze in the future enqueue manifest are:

| Sleeve | EX5 SHA-256 | Set SHA-256 |
|---|---|---|
| 10128:XAUUSD | `0d53e12208e39784c778145f607ed29d84b7a37e155d71caa767aba503064499` | `0c3c9cd5c1071406d216d9a964bdc2f3e74c0d810560f661ed2871f7236004f5` |
| 13036:GDAXI | `1cfe279753f0d73bc8a9d7ac92abf15643fbb4ba72853cec621d9b89575809ab` | `80dc96e896fa109ef31964af8c617468e6737b1f0823f1616d1117b44c732b70` |
| 10145:XAUUSD | `ebe9ca4c848cf6b0648417be51990318eb8ef4fa5e755146204e13e6f49192dc` | `0acbbeb78f4093f556b1e061f5fba94b25b3025dbf267f2dc13939ed8e2abb0b` |
| 10183:XAUUSD | `2c33af263d70e4d5a287cbcff04a393ee707cfd5438c0a4a9e1582789f0c1987` | `ae747dc0b8f7fcb32ab02a4c32c0ac58dcddee8d8119415b88b73c1bc1154976` |
| 13301:GDAXI | `3f3deac97d4819bf030bcf3e5153bc21f439a6aedb0ca430b3967fcbb236c625` | `3d07e1360e75a92b754fbeb60d8da9fa3901f1bd6efa73449d2081f73c71b511` |

Those hashes are a planning snapshot. The lane preparer must re-read and pin
them at enqueue; drift is a refusal, not an automatic update.

## Throughput and isolation

The estimated total is 83-140 terminal-minutes after profiles are warm. With
two serial lanes, expected campaign wall-clock is roughly 45-75 minutes, plus
the first native history/tick synchronization. Cold sync is not bounded by the
DXZ proxy and should be budgeted separately rather than hidden in a PASS/FAIL
timeout.

The host-wide cap is two FTMO tester processes and the normal DXZ capacity
floor is eight. The scheduler must acquire both a dedicated FTMO lane lease and
a shared capacity permit before launch. If the normal factory already consumes
all ten permits, FTMO waits; it does not stop or preempt an active T1-T10 test.
Rows, summaries, reports, Q08 deltas, equity deltas, receipts, and final streams
remain under `D:/QM/reports/ftmo_stream/wave1/`. Nothing is mirrored into
`D:/QM/reports/pipeline`, no Q phase is advanced, and no pipeline verdict is
derived from this campaign.

## Enqueue handback

### Current state: intentionally no executable enqueue

There is no safe enqueue command to give Claude against the current runtime.
The only available generic command would dispatch `.DWX` data and produce the
exact false attestation this ticket is meant to prevent. Therefore:

```text
ENQUEUE_STATUS=BLOCKED_NATIVE_FTMO_TESTER_LANE_NOT_PROVISIONED
SAFE_ENQUEUE_COMMAND_COUNT=0
FORBIDDEN_SUBSTITUTE=python tools/strategy_farm/farmctl.py enqueue-backtest ...
```

Claude's next deterministic action is to review this design/exporter and route
one infrastructure task for the two lane receipts plus claim/monitor/harvest
wiring. Only that reviewed runner may publish the five exact enqueue commands.
The commands must name the five sleeve identities and hashes above, the common
window, native symbols, pinned snapshot digest, a lane A/B assignment, an
output root, and `max_concurrent=2`. They must refuse if the 13301 build remains
ambiguous.

This is not an invitation to run `terminal64.exe` directly, reuse the FTMO
live/trial profile, toggle AutoTrading, release Book3 holds, or reserve/stop an
active T1-T10 terminal.

### Exact exporter command after each admissible run

The lane runner must create one stable run root with `summary.json`,
`raw/run_01/report.htm`, `q08_trades.jsonl`, and `equity_log.jsonl`. For
10128, for example:

```powershell
$runRoot = 'D:/QM/reports/ftmo_stream/wave1/W1_01_QM5_10128_XAUUSD'
python tools/strategy_farm/portfolio/ftmo_daily_net_export.py `
  --sleeve-id '10128:XAUUSD' `
  --symbol XAUUSD `
  --native-symbol XAUUSD `
  --ftmo-code 'XAU/USD' `
  --summary "$runRoot/summary.json" `
  --report "$runRoot/raw/run_01/report.htm" `
  --q08-trades "$runRoot/q08_trades.jsonl" `
  --equity-log "$runRoot/equity_log.jsonl" `
  --cost-snapshot artifacts/ftmo_symbol_snapshot_2026-07-11.json `
  --setfile framework/EAs/QM5_10128_bb-breakout/sets/QM5_10128_bb-breakout_XAUUSD.DWX_D1_backtest.set `
  --out "$runRoot/10128_XAUUSD.ftmo_daily_net_v1.jsonl" `
  --receipt-out "$runRoot/10128_XAUUSD.ftmo_daily_net_v1.receipt.json"
```

The other four commands differ only in the table-bound sleeve, native symbol,
FTMO code, set file, and run root. The exporter has no `--venue` override and
no cost-digest override; a non-FTMO report or a different snapshot is refused.

## Focused verification

Run from `C:/QM/repo`:

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_daily_net_export.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_ftmo_stream_reconciliation.py tools/strategy_farm/tests/test_ftmo_report_cost_reconcile.py
.........................................                           [100%]
41 passed, 5 subtests passed in 1.44s
```

The new tests prove exact evaluator-schema acceptance, report/Q08/equity/cost
binding, final-day reconciliation, and fail-closed refusal of a Darwinex
report, missing swap terms, a news-staleness limit above 336, and a legacy Q08
money basis.
