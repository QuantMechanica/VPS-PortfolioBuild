# Backtest report latency repair — 2026-09-08

Owner instruction: monitor the factory much more closely, investigate tests that
finish computing but wait for reports, and reserve a test terminal if useful.
Scope: tester infrastructure only. No live EA, AutoTrading, orders, risk settings,
strategy mechanics, tick model, source history, gate threshold or historic verdict
was changed. Existing unrelated 41240 edits were preserved.

## Confirmed finding

Several native agents logged `Test passed in ...` and `thread finished` after
roughly 47 seconds to four minutes, then remained alive with flat CPU/IO. Their
terminals still showed Stop/testing progress, with no initial HTML report at all.
This is an engine-to-terminal/export handoff stall, not slow copying of an already
existing report. No visible save dialog or supported Windows wait-chain deadlock
was found. The internal MT5 cause is **not yet established**.

The runner originally only recognized terminal exit or a complete report and
otherwise waited its full computation timeout (commonly 7,200 seconds). Journal
tail extraction also read each complete file twice; this is a separate avoidable
IO/memory cost, not proof of the native hang's root cause.

## Native recovery acceptance at 17:12 Vienna

Every intervention first checked exact active work-item UUID, terminal PID/path/
creation time, tester configuration, a fresh exact-EA/symbol/timeframe completion
record, missing report, at least ten minutes since engine completion, and another
15-second interval of unchanged tester CPU and both journals. Evidence was saved
before stopping only that terminal/tester pair. The existing runner retained the
failed attempt and performed its normal identical-input retry.

| Terminal / EA | Original post-engine wait | Retry trades | Retry engine → report | DB outcome |
|---|---:|---:|---:|---|
| T1 / 41324 Balke USDJPY | 72.5 min | 169 | 3.866 s | MEASURED |
| T3 / 41302 Ichimoku | 42.8 min | 10 | 2.626 s | MEASURED |
| T5 / 41345 XAU weekly | 69.5 min | 36 | 8.578 s | MEASURED |
| T6 / 41163 Williams | 51.8 min | 28 | 2.434 s | MEASURED |
| T9 / 41305 November fade | 41.0 min | 12 | 7.301 s | MEASURED |

All five native reports have verified SHA-256 and Model 4 real-tick markers.
MEASURED is a census measurement, **not** portfolio/live qualification. In
particular, the 41345 measurement is losing; it was not presented as profitable.

T9 has an additional exact parity check: 15,368,978 ticks, 255 bars, all 72 native
trade-message records and final balance match between the stuck original and
successful retry. Normalized trade-stream SHA-256:
`31c37fd517a3cfb5c5fee5507902cf3e1a0f05271f4327d1b1cba9be7ee6628a`.

T7 / 41137 was separately reaped by the old outer `NO_FORWARD_PROGRESS` watchdog
during report-missing handoff. Its original Q03 row
`0521d493-ca0b-44ef-af1b-ddd1d4071853` remains INFRA_FAIL. The canonical enqueue API
created exactly one same-binary, same-setfile append-only Q03 rerun
`cc3a5cd7-49e2-4105-8c2c-80a6d62132ab`, bound to Q02 predecessor
`f1ea7aa8-337d-4c45-9d8d-d7be220d1ea2`. It was pending at acceptance; no fabricated
replacement verdict or edit of the old row.

## Permanent runner change

- Poll post-engine state every 15 seconds. Require a newly spawned exact-root
  agent and the exact fresh native completion as the **last** journal record.
  Old same-EA markers in an appended retry log do not qualify.
- After 600 seconds without tester CPU/journal progress and with the native
  report still absent, save `post_engine_stall.json`, terminate only the owned
  tester pair, and use the existing bounded report-missing retry budget
  (`Runs + 2`, maximum 10 attempts). Never accept an engine log as a report/PASS.
- Any existing report or renewed progress cancels that stall timer. Existing
  report completeness, finalization, logger authentication and gate checks stay
  in force. Ordinary computation timeouts retain their original semantics.
- Add UTC/elapsed events for engine completion, report first byte and terminal
  exit; numerical timings are culture-invariant for new launches.
- Read at most 2 MiB for ordinary journal tails (64 KiB for the 15-second probe),
  without altering the original journals. UTF-16/UTF-8 and partial-record cases
  are covered by fixtures.

The updated runner's normal native path is already accepted by new census item
`b75770b5-1543-5bf3-b90b-6f9366194c21` on T9: report-first-byte and valid-report
latch events were emitted and it completed. The automatic 600-second stall/retry
branch is fixture-tested; a new real stalled-run acceptance remains open. Old
already-running PowerShell processes do not retroactively reload functions.

## Isolated T11 experiment

T11 was reserved from 16:27 to 17:09 and then released after confirming the lab
and updater were stopped. T11/T12 worker policy remains disabled. A private
portable lab under `D:\QM\mt5\T11\latency_lab_20260908` used production build 6182,
the existing MetaQuotes Moving Average sample EA, native EURUSD/M5, Model 4,
2026-09-01..05. No services, live charts/EAs, Custom history or junctions were
copied. The lab refused launches below 18 GiB free RAM; the factory took priority.

Four native reports contain identical 3,078 normalized table cells, 516,822 ticks
and 1,151 bars. Table-cell SHA-256:
`5acca1976630b7d5bf83ddf7ec7c7ba432b9c4291097805cdbb3b57054320d96`.

Baseline first-byte timings were 41.99 and 27.78 seconds from launch. The later
subdirectory run took 50.56 seconds. The first subdirectory attempt encountered
an MT5 updater handoff; its early observer incorrectly reported no report, while
the report arrived later. That original observation remains intact, the updater
tracking defect was fixed, and the attempt is excluded from timing conclusions.
**No report-directory speedup was demonstrated or rolled out.** The same build
worked normally in clean and production profiles, so a build defect is not proven.

Other hypotheses, not changes: 69k–109k files in some production terminal roots;
the import service still starts despite the existing Common/Services=0 setting;
MCP default-port collision messages. None is proven causal. We did not purge
reports/history, disable import services, or downgrade terminals speculatively.

## Evidence, tests, monitoring and open work

Primary snapshot:
`D:\QM\reports\maintenance\backtest_latency_20260908\acceptance_20260908T151256Z\acceptance.json`

SHA-256: `e8ac23d3bf0e5f733711c6edb1cca03d3185671c9ce43b9a0cf485a0db3e203a`.
The same folder contains stable native-journal snapshots and copies of the five
native HTML reports and summaries. Exact trade parity is recorded separately in
`D:\QM\reports\maintenance\backtest_latency_20260908\parity_20260908.json`.

17 targeted Python/PowerShell regression tests passed. Existing report-shell,
empty-log, legacy-logger and timeout-override tests were included. At 17:12 there
was no currently confirmed report stall; RAM available 29.15 GiB, D: free 118.88
GiB. Protected live terminal PIDs 15464 and 31728 remained running and untouched.

The final read-only 15-second observer started 17:12:58 Vienna for 50 minutes
(approximately until 18:02:58). Output:
`D:\QM\reports\maintenance\backtest_latency_20260908\tail_watch_final.jsonl`.
The permanent per-runner monitoring above continues independently thereafter.
Earlier observation files are retained; their exploratory mtime-based matches can
misidentify old same-EA markers after retries. Final observer uses record time,
exact identity and the last native record, not merely file mtime.

Open: native acceptance of the automatic 600-second retry branch; completion of
the T7 rerun; actual MT5 internal hang cause; broader controlled throughput study
before altering concurrency, services or report layout. The previously queued
11167 legacy canary has produced its first native selection summary with
`legacy_no_sv` and 2,095 authenticated events; the full matrix/holdout acceptance
remains open and no other legacy binary was enabled here.

External cross-checks: [MT5 startup/report configuration](https://www.metatrader5.com/en/terminal/help/start_advanced/start),
[Microsoft wait-chain limitations](https://learn.microsoft.com/en-us/windows/win32/api/wct/nf-wct-getthreadwaitchain).
The public [6182 startup-crash report](https://www.mql5.com/en/forum/515680) concerns
an immediate DLL-entry-point crash, unlike these living terminals; it is not a
root-cause attribution for this incident.
