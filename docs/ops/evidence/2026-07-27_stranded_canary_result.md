# Stranded Q02 canary — single-pass result

Date: 2026-07-27  
Router task: `5145ce0b-acb5-49b6-a981-ef0ad3d082a8`  
Requeue journal: `D:\QM\reports\state\stranded_canary_10_20260727.json`

## Verdict

**INCONCLUSIVE — 3 of 10 selected pairs reached a real Q02 verdict during this
orchestration pass; all 3 recovered from the silent-infrastructure state.** Two
were still active and five were pending at the 2026-07-27 13:54 UTC cutoff.
Those seven are not counted as failures. No terminal was interrupted, manually
started, or reserved for the canary.

Exactly ten existing work items were requeued at 2026-07-27 12:47:51 UTC using
the crash-safe plan/apply path in `requeue_stranded_infra.py`. No eleventh pair
was changed. The ordinary scheduled workers claimed the rows.

## Selection and observed outcomes

The July sample is intentionally larger because a July recurrence would identify
a mechanism still active after the June lock-storm improvement. All EAs and
symbols are distinct.

| Cohort | Work item | Pair | Selection reason | State at cutoff | Row-bound outcome / mechanism | Evidence |
|---|---|---|---|---|---|---|
| July | `49ab260f-da5c-4ad2-8ab2-a10152aea229` | `QM5_9940 / SP500.DWX` | Highest observed infra count (37); tests whether a heavily affected pair is transient | active on T2 since 13:12:32 UTC | No verdict yet; prior reason `ACTIVE_TIMEOUT`. Do not infer failure while active. | Work-item report root `D:\QM\reports\work_items\49ab260f-da5c-4ad2-8ab2-a10152aea229` |
| July | `b0af005d-2565-44dc-8f9e-d3668f6f6583` | `QM5_10485 / USDJPY.DWX` | Second high-infra-count pair (26), distinct symbol | pending | No new outcome; prior reason `ACTIVE_TIMEOUT` | Work-item row and requeue journal |
| July | `c1dad1ca-735b-4829-bfb7-61a80feea8f7` | `QM5_10226 / EURUSD.DWX` | July history-failure representative | pending | No new outcome; prior reason `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS` | Work-item row and requeue journal |
| July | `93077cce-bac0-4d3a-aa77-70e9e9a99353` | `QM5_10591 / GBPJPY.DWX` | July active-timeout representative, distinct EA/symbol | pending | No new outcome; prior reason `ACTIVE_TIMEOUT` | Work-item row and requeue journal |
| July | `511318c1-60c0-4a17-b8a0-20a4483b9744` | `QM5_11912 / AUDUSD.DWX` | July bars-zero/on-init representative | done | **PASS**; recovered. Runtime 4m46s. Prior reason `run_smoke_fail:BARS_ZERO;ONINIT_FAILED;INCOMPLETE_RUNS`. | `D:\QM\reports\work_items\511318c1-60c0-4a17-b8a0-20a4483b9744\QM5_11912\20260727_124811\summary.json` |
| July | `5a6ce70f-38e6-4a3d-b953-8c935a4865f2` | `QM5_11072 / USDCAD.DWX` | July log-bomb/incomplete representative; selected by the canonical eligibility plan, with its prior mechanism retained explicitly | active on T6 since 13:52:04 UTC | No verdict yet; prior reason `run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS` | Work-item report root `D:\QM\reports\work_items\5a6ce70f-38e6-4a3d-b953-8c935a4865f2` |
| June | `9eefa526-10f9-4772-8acc-38c6a528b98f` | `QM5_10792 / NDX.DWX` | June on-init representative | pending after retry backoff | No real verdict yet. Three governed transient attempts; current reason `cold_cache_retry:NO_HISTORY`, prior `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. | Work-item row; transient evidence `D:\QM\mt5\T2\logs\20260727.log` |
| June | `fc0c0e57-d5a4-4da1-8365-64cf8f769978` | `QM5_10809 / XAUUSD.DWX` | June exhausted-summary representative | pending | No new outcome; prior reason `summary_missing_retries_exhausted` | Work-item row and requeue journal |
| June | `47b62d39-5ccb-4201-9404-d49e626c5b90` | `QM5_12406 / XTIUSD.DWX` | June exhausted-summary representative on a commodity | done | **PASS**; recovered. Runtime 4m42s. | `D:\QM\reports\work_items\47b62d39-5ccb-4201-9404-d49e626c5b90\QM5_12406\20260727_132418\summary.json` |
| June | `c5734bae-5d82-4ed3-a843-834426e89a15` | `QM5_11062 / WS30.DWX` | June exhausted-summary representative on an index | done | **ZERO_TRADES** (`Q02_ZERO_TRADES`); recovered from infrastructure limbo to a real strategy verdict. Runtime 2m23s. | `D:\QM\reports\work_items\c5734bae-5d82-4ed3-a843-834426e89a15\QM5_11062\20260727_125103\summary.json` |

## Answers required by the brief

1. **Recovery fraction:** 3/3 completed canaries recovered to a real verdict;
   3/10 of the full sample is demonstrated recovered. The final ten-item
   recovery fraction is not yet knowable because seven rows remain nonterminal.
   Treating those seven as failures would be false.
2. **June versus July:** observed June recovery is 2/2 completed; observed July
   recovery is 1/1 completed. The sample does not yet support a cohort
   difference. The June NDX row did expose repeated `cold_cache_retry:NO_HISTORY`,
   a history/cache mechanism distinct from the earlier on-init reason, but it is
   not a terminal failure.
3. **Common cause:** no common terminal failure exists among completed rows.
   The only repeated nonterminal friction observed is governed transient
   infrastructure/history retry. The long-running SP500 case and NDX cold-cache
   retries show why the stranded set cannot yet be assumed cheaply recoverable.
4. **Cost to recover the remaining 1,246:** the three completed runs consumed
   11m51s of tester occupancy (mean 3m57s). At that successful-run mean alone,
   1,246 pairs require about **82 tester-hours**. This is a strict lower bound:
   the SP500 canary already exceeded 41 minutes at cutoff and NDX consumed
   multiple attempts without a verdict. The live queue held **2,067 pending**
   work items at cutoff and is draining net-negative on 8 of the last 10 days,
   so bulk recovery would directly delay existing work. OWNER should not approve
   the remaining 1,246 from this incomplete canary.

## Durable detection

Commit `74315d1b1` adds `q02_stranded_exhausted_pairs` to
`tools/strategy_farm/health.py` and focused tests in
`tools/strategy_farm/tests/test_health_q02_stranded.py`.

The invariant groups Q02 rows by EA/symbol and raises FAIL when a pair has:

- no real verdict;
- no pending or active successor; and
- at least 12 infrastructure-failure rows.

Focused verification: `5 passed`. Its first recorded run surfaced **844** pairs.
A fresh run at 13:54 UTC surfaced **845** pairs:

`FAIL: 845 Q02 EA/symbol pairs have no real verdict, no queued successor, and >= 12 INFRA_FAIL rows`

The changing count is expected while the factory runs and is precisely why this
must be a live invariant rather than a one-off census.

## Handoff

The seven nonterminal work-item IDs above must be read again after the normal
workers finish. A follow-up may replace this inconclusive snapshot with the
final 10/10 fraction, but must not requeue additional pairs or relaunch these
rows manually.
