# Fresh Q02 INFRA_FAIL diagnosis

Date: 2026-07-27
Router task: `5fe39217-3478-4344-b26c-6076b5ce1a53`

## Verdict

The five failures do **not** share one cause. Row-bound evidence separates them
into three mechanisms:

1. three full-window tests were killed by the 45-minute active-item watchdog while
   MT5 was still making forward progress;
2. one EA deterministically generated a 4.03 GB log and tripped the log-bomb guard;
3. one symbol repeatedly had no usable history on three different terminals.

These are respectively timeout-policy/capacity, EA/framework logging, and
terminal/data failures. `INFRA_FAIL` hides that distinction.

## Case-by-case evidence

| Work item | Mechanism | Evidence | Classification / fixability |
|---|---|---|---|
| `49ab260f…` / QM5_9940 / SP500.DWX | **Premature ACTIVE_TIMEOUT.** The full run started at 15:13:30 and advanced 10%, 21%, 26%, 34%, 37%, 38%, 39%, then 42% at 15:53:31. At about 45 minutes the watchdog killed it and a different test started on T2 at 15:58:17. | `D:/QM/strategy_farm/logs/work_item_49ab260f-da5c-4ad2-8ab2-a10152aea229.log` records `timeout_seconds=7200`, a normal spawn, then exit with `timed_out=False`, `valid_report_latched=False`; `D:/QM/mt5/T2/logs/20260727.log:3022-3031` records progress and replacement. The six-month prescreen had already passed with 26 trades: archived `...requeued_20260727T1247510000/QM5_9940/20260725_084200/summary.json`. | Pipeline timeout policy, not terminal failure. Fixable with progress-aware leases or a timeout at least as long as the sanctioned 7,200-second run timeout. |
| `5a6ce70f…` / QM5_11072 / USDCAD.DWX | **Deterministic LOG_BOMB.** The tester-side EA log reached 4.03 GB and the guard killed the run. This reproduced on 2026-07-24 and 2026-07-27. | `...requeued_20260727T1835030000/QM5_11072/20260727_135205/summary.json`: `LOG_BOMB;INCOMPLETE_RUNS`, file `QM5_11072_ea-11072.log`, 4.03 GB. The earlier `...requeued_20260727T1247510000/.../20260724_204607/summary.json` records the same 4.03 GB mechanism. | EA/framework logging defect, not transient infrastructure. Fixable by rate-limiting/deduplicating the emitting event, then rerunning normally. |
| `93077cce…` / QM5_10591 / GBPJPY.DWX | **Premature ACTIVE_TIMEOUT plus extreme test cost.** The run remained at 0% for 15 minutes and reached only 2% after about 45 minutes; the watchdog replaced it at 17:04. | Work-item log records a 7,200-second allowed timeout but exit `timed_out=False`/no report. `D:/QM/mt5/T6/logs/20260727.log:4788-4800` shows 0%, 1%, 2% progress before replacement. The preceding attempt's summary (`...requeued_20260727T1247510000/.../20260727_013907/summary.json`) also records BARS_ZERO/report-missing/hung outcomes. | Current failure is timeout-policy/capacity. A progress-aware lease is fixable, but at the observed rate this EA is too expensive for the ordinary lane without a separate capacity decision. |
| `9eefa526…` / QM5_10792 / NDX.DWX | **NO_HISTORY across terminals.** Three attempts each on T6, T7 and T9 produced empty/M0-1970 reports with `NO_HISTORY_LOG` and `HISTORY_CONTEXT_INVALID`. | Summaries at `...requeued_20260727T1835030000/QM5_10792/20260727_130157`, `.../20260727_152213`, and `.../20260727_163438` each record `NO_HISTORY;INCOMPLETE_RUNS`, with three invalid attempts. Payload records cold-cache cap 3 and avoid-terminal expansion. | Terminal/data provisioning failure. It is potentially fixable by repairing the existing NDX custom-symbol history availability; this task did not re-import history. |
| `b0af005d…` / QM5_10485 / USDJPY.DWX | **Premature ACTIVE_TIMEOUT.** The full run advanced from 7% to 37% between 19:12 and 19:52 before replacement at 19:53:59. | Work-item log records `timeout_seconds=7200`, then `timed_out=False` with no report. `D:/QM/mt5/T2/logs/20260727.log:3418-3429` records continuous progress and replacement. Its six-month prescreen passed with 621 trades (`...requeued_20260727T1247510000/QM5_10485/20260726_024337/summary.json`). | Pipeline timeout policy, not a signal or terminal fault. Fixable with a progress-aware/consistent timeout. |

The news calendar was not the mechanism in these cases: every work-item log records
`news_calendar_status=OK` with the current FILE_COMMON path before launch.

## Signature count in the 814-row release

The release is exactly the union of the two batch timestamps
`2026-07-27T18:34:41Z` (50 rows) and `18:35:03Z` (764 rows), where
`requeued_by = 'requeue_stranded_infra'`.

Read-only SQLite query:

```sql
SELECT json_extract(payload_json,'$.requeue_prior_verdict_reason') AS reason,
       COUNT(*)
FROM work_items
WHERE json_extract(payload_json,'$.requeued_by')='requeue_stranded_infra'
  AND json_extract(payload_json,'$.requeued_at_utc') IN
      ('2026-07-27T18:34:41+00:00','2026-07-27T18:35:03+00:00')
GROUP BY reason;
```

Relevant counts:

- `ACTIVE_TIMEOUT`: **8 / 814**.
- `run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS`: **7 / 814**.
- explicit `NO_HISTORY`: **33 / 814**, plus
  `cold_cache_retries_exhausted`: **3 / 814**; therefore **36 / 814** carry
  the same no-history/cold-cache family seen in QM5_10792.
- These three observed families cover **51 / 814** rows. They do not explain the
  other 763, dominated by 703 `summary_missing_retries_exhausted` rows.

This count is a historical-signature census, not a prediction that all 51 will
repeat after requeue.

## ZERO_TRADES: `c5734bae…` / QM5_11062 / WS30.DWX

This was a valid completed test, not an initialization or history failure:

- `.../QM5_11062/20260727_125103/summary.json` records run status `OK`,
  exit code 0, `oninit_failure=false`, a real-ticks marker, a 15,671,060-byte
  report, and exactly zero trades.
- The report contains the expected M1/WS30 inputs and has an empty Orders table.
  Therefore no pending bracket order was accepted; this is not merely an order
  that never filled.
- The exact silent suppression branch is **NOT ESTABLISHED**. The EA has multiple
  uninstrumented early returns in `Strategy_EntrySignal` (history length,
  calculated range, tick metadata, spread-to-range, and normalized price/stop
  checks), and the row-bound tester log named in the summary is no longer present.
  The evidence cannot distinguish those branches without a diagnostic build.

At the query snapshot, the 814-row release had 808 pending, four active and two
completed PASS; **zero had completed ZERO_TRADES**. Thus prevalence of this outcome
inside the 814 is currently 0 observed, but the eventual rate is NOT ESTABLISHED.

## Operational answer

There is no single repair that lifts all 814. Three targeted fixes are justified:
a progress-aware active lease for the eight timeout-signature rows, log-volume repair
for the seven log-bomb rows, and existing-history availability repair for the 36
no-history/cold-cache rows. Together they address 51 known-signature rows, but they
do not justify a yield claim for the 703 summary-missing rows or the still-running
release.
