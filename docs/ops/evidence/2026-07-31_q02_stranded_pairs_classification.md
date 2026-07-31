# Q02 stranded-exhausted pairs — classification and governed-canary proposal

**Task:** `5589f742-8071-4aed-942a-2773b90df27f`

**Status:** READY FOR CLAUDE REVIEW

**Mode:** read-only analysis and proposal only; no requeue, wave, work-item status change, terminal launch, or live action

**Snapshot:** `2026-07-31T23:02:15+00:00`

## Result

The exact health-check predicate returned **279** Q02/P2 EA-symbol pairs and
3,446 work-item rows in the consistent read transaction. The routed brief
recorded 278 pairs. The one-pair drift is real farm activity, not scope
expansion: `QM5_12382 / NDX.DWX` entered the predicate when work item
`c1b2c4c8-f068-4d6d-aa63-821b1b45b253` changed to terminal
`INFRA_FAIL/cold_cache_retries_exhausted:NO_HISTORY` at
`2026-07-31T22:53:05+00:00`. This packet classifies the complete 279-pair
snapshot rather than silently dropping the new member.

| Classification | Pairs | Share | Disposition |
|---|---:|---:|---|
| `VALID_ZERO_TRADES` | 2 | 0.7% | RETIRE-list draft only; Claude review required before execution |
| `INVALID_EVIDENCE_DEFECT` | 244 | 87.5% | repair/preflight or guarded disposition repair; no bulk rerun |
| `UNCLEAR` | 33 | 11.8% | recover row-bound evidence first; no blind requeue |
| **Total** | **279** | **100.0%** | |

The primary-cause distribution is mutually exclusive:

| Primary cause | Pairs |
|---|---:|
| `ONINIT_FAILED` | 98 |
| `ACTIVE_TIMEOUT` | 46 |
| `SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE` | 33 |
| `BARS_ZERO` | 24 |
| `NO_HISTORY_TRANSIENT` | 21 |
| `LOG_BOMB` | 17 |
| `SETFILE_MISSING` | 13 |
| `ROW_BOUND_PASS_DISPOSITION_MISMATCH` | 10 |
| `TIMEOUT_METATESTER_HUNG` | 7 |
| `REPORT_MISSING` | 3 |
| `SETFILE_HEADER_INCOMPLETE` | 3 |
| `SHARED_BASES_LOCK_STORM` | 2 |
| `VALID_ZERO_TRADES` | 2 |

The row-level graveyard remains dominated by
`summary_missing_retries_exhausted` (2,682 of 3,446 rows). It is not treated
as a cause when a newer or row-bound artifact supplies a specific mechanism.
Only the 33 pairs for which the generic label is all that remains are
classified `UNCLEAR`.

## Method and evidence boundary

The SQL in the JSON is byte-for-byte equivalent in predicates to
`health.py::chk_q02_stranded_exhausted_pairs`: Q02 and legacy P2 are grouped as
one history; each pair has at least 12 `INFRA_FAIL` rows, no pending/active
successor, and no terminal non-infra disposition. The selected rows have
snapshot digest
`b73c2ef0d03874d29910bf144075decdd7bdb708ed05b875320402754b493453`.

Classification precedence is fail-closed:

1. A zero-trade aggregate is accepted only when every run is `OK`, total
   trades are zero, the aggregate says `MIN_TRADES_NOT_MET`, and EA, symbol,
   dates, EX5, setfile, stable-deployment, and news-calendar identity checks
   all pass.
2. A currently missing setfile is an evidence defect. A row-bound `PASS/OK`
   aggregate stored as `INFRA_FAIL` is a disposition defect and is not rerun.
3. Current setfiles are checked for all required headers and case-insensitive
   duplicate header/input keys, split into identical-value and conflicting-value
   classes.
4. Otherwise the most recent row carrying a specific direct
   `verdict_reason`, `final_failure`, or aggregate reason supplies the primary
   cause. Generic summary-missing history alone remains `UNCLEAR`.

This is classification evidence, not a pipeline verdict and not authorization
to change a work item.

## Required classes and examples

### A — valid zero trades

Only two members exist, so these are the exhaustive 2/2 examples; a third
cannot be supplied without fabrication.

| EA / symbol | Work item | Identity-bound aggregate | SHA-256 | Result |
|---|---|---|---|---|
| `QM5_10989 / GDAXI.DWX` | `801b1c3b-ad77-4ecb-8d71-8434f10c26f5` | `D:\QM\reports\work_items\801b1c3b-ad77-4ecb-8d71-8434f10c26f5\QM5_10989\20260728_103516\summary.json` | `16cae7e736b75e35d4459a9ca3a47c214ef3ea09d4829e16bce120181e17525b` | one `OK` run, 0 trades, `MIN_TRADES_NOT_MET` |
| `QM5_11257 / EURUSD.DWX` | `61d328fa-d97f-4408-a457-7acf555d3b2e` | `D:\QM\reports\work_items\61d328fa-d97f-4408-a457-7acf555d3b2e\QM5_11257\20260728_182023\summary.json` | `37cffd81af9a4ee2c4c9617e1ef5eee202d399f2964e3cbb8960334d9891e26c` | one `OK` run, 0 trades, `MIN_TRADES_NOT_MET` |

These two rows form the RETIRE-list draft. No retirement was executed.

### B — invalid/evidence defect

| Cause example | Work item | Row-bound artifact |
|---|---|---|
| `QM5_1058 / EURUSD.DWX` — `ONINIT_FAILED` | `b8fa58d1-64a7-48f2-81be-ed98ae4017ef` | `D:\QM\reports\work_items\b8fa58d1-64a7-48f2-81be-ed98ae4017ef\QM5_1058\20260731_165419\summary.json` |
| `QM5_1180 / SP500.DWX` — `ACTIVE_TIMEOUT` | `6295d241-ae68-4c1f-a0f4-69457b6eb60f` | `D:\QM\strategy_farm\logs\work_item_6295d241-ae68-4c1f-a0f4-69457b6eb60f.log` |
| `QM5_1229 / EURCAD.DWX` — `BARS_ZERO` | `4bbd64fb-0a5c-4749-8a8e-72f7ff100659` | `D:\QM\reports\work_items\4bbd64fb-0a5c-4749-8a8e-72f7ff100659\QM5_1229\20260728_155247\summary.json` |

Important overlays:

- 13 latest bound setfiles are absent.
- 3 are header-incomplete:
  `QM5_1014/EURGBP.DWX` (`dd7101fd-3075-463a-af91-8d193791e5f2`),
  `QM5_1014/EURUSD.DWX` (`8ede5ab7-6f1f-4971-885c-7b9d9a506d51`), and
  `QM5_1017/NDX.DWX` (`44835bef-4772-4972-80cf-3c99ed6d9c3f`).
- 0 pairs have duplicate header keys, duplicate input keys, or conflicting
  duplicate values. The new duplicate classes were evaluated; zero is an
  observed result, not an omitted check.
- All 431 readable row-bound summaries report calendar status `OK`, and none
  exceeds the 336-hour maximum. There is therefore no directly evidenced
  calendar-hard member and no calendar canary candidate.
- 40 pairs carry a historical shared-bases/lock-storm marker, but only 2 retain
  it as the strongest current primary cause. Historical overlap is not allowed
  to override newer direct evidence.
- 10 pairs already contain a row-bound `PASS/OK` positive-trade aggregate while
  the row remains `INFRA_FAIL`. They need a reviewed guarded disposition repair,
  not another backtest.

### C — unclear

For these examples the missing aggregate is the finding. Each database
`evidence_path` is `NULL`; the retained work-item log/report root is shown as
the forensic starting point.

| EA / symbol | Work item | Aggregate | Fallback log / report root |
|---|---|---|---|
| `QM5_1114 / JPN225.DWX` | `14b6899d-b9a8-448f-98d7-024e3db3eb96` | `NULL` | `D:\QM\strategy_farm\logs\work_item_14b6899d-b9a8-448f-98d7-024e3db3eb96.log`; `D:\QM\reports\work_items\14b6899d-b9a8-448f-98d7-024e3db3eb96` |
| `QM5_1225 / AUDUSD.DWX` | `3dda93b2-80be-48f3-8a10-5cdf0a5a4bf2` | `NULL` | `D:\QM\strategy_farm\logs\work_item_3dda93b2-80be-48f3-8a10-5cdf0a5a4bf2.log`; `D:\QM\reports\work_items\3dda93b2-80be-48f3-8a10-5cdf0a5a4bf2` |
| `QM5_1225 / NZDUSD.DWX` | `3eacd6d8-22b2-4617-b1eb-4b34e9e5c0cf` | `NULL` | `D:\QM\strategy_farm\logs\work_item_3eacd6d8-22b2-4617-b1eb-4b34e9e5c0cf.log`; `D:\QM\reports\work_items\3eacd6d8-22b2-4617-b1eb-4b34e9e5c0cf` |

## Governed canary proposal — not executed

The five largest actionable runtime/evidence causes cover 206/244 defect pairs
(84.4%). The proposal binds two rows per cause and is sequential within each
cause: candidate 2 stays unqueued until candidate 1 has a reviewed terminal
disposition. Every candidate must be revalidated immediately before use. Claude
review and OWNER authorization are mandatory.

| Cause | Seq. 1 exact target | Seq. 2 exact target | Expected result | Cause-level abort |
|---|---|---|---|---|
| `ONINIT_FAILED` | `QM5_20143/GBPUSD.DWX` — `a03d2d06-57a0-4e81-aa80-1cbb93ea882b` | `QM5_1058/EURUSD.DWX` — `b8fa58d1-64a7-48f2-81be-ed98ae4017ef` | identity-bound `PASS`, `MIN_TRADES_NOT_MET`, or deterministic `INVALID` with attributable init event | first recurrent unattributed `ONINIT_FAILED`, or any EX5/setfile/calendar identity mismatch |
| `ACTIVE_TIMEOUT` | `QM5_20045/EURGBP.DWX` — `4fb3901c-3d70-420f-8727-8f36d190136a` | `QM5_12405/SP500.DWX` — `d119f278-5901-4ab5-93de-089201323756` | completion under the progress-aware reaper, or a justified no-progress/absolute-ceiling stop with bound progress evidence | any reap while progress exists, reap without progress evidence, or vanished disposition |
| `BARS_ZERO` | `QM5_10505/XAUUSD.DWX` — `20a72dd9-4c4c-4236-8cd6-1353ac8548c9` | `QM5_10718/GBPJPY.DWX` — `1acf7591-3cd7-4b23-b8b8-06d273f9ba3c` | nonzero bars and valid terminal report, or deterministic `INVALID` history diagnosis | first recurrent `BARS_ZERO` after successful symbol/date coverage preflight; no terminal fan-out |
| `NO_HISTORY_TRANSIENT` | `QM5_12382/NDX.DWX` — `c1b2c4c8-f068-4d6d-aa63-821b1b45b253` | `QM5_11232/EURUSD.DWX` — `8c0f5a34-448e-4cf4-808d-13dde7895eb3` | exact requested range available and valid report without `NO_HISTORY` | first recurrence after coverage preflight, or evidence that the requested range is unavailable; no history import |
| `LOG_BOMB` | reference `QM5_1560/USDJPY.DWX` — `5d28d955-129d-413c-a1a9-294c65628627` | reference `QM5_1196/GBPUSD.DWX` — `ef639b97-ac85-4585-b194-f87c3a96ee80` | repaired EA produces a bounded journal and valid report | configured log-bomb guard, first `LOG_BOMB`, or unbounded journal growth |

For `LOG_BOMB`, the IDs are diagnostic source rows. They must **never** be
flipped back to pending: the existing poison-row guard remains intact. After a
code/logging repair and regression proof, the governed canary creates one new
successor referencing the exact source row.

Global preconditions are fail-closed: candidate remains terminal
`INFRA_FAIL`; no open successor or non-infra disposition exists; canonical EX5
and setfile hashes match; the source and FILE_COMMON calendar copies are fresh
and identical without setting `qm_news_stale_max_hours` above 336; the setfile
has `RISK_FIXED > 0` and `RISK_PERCENT = 0`; and no active T1-T10 run is
interrupted. All ten proposed setfiles currently satisfy the two risk settings,
but that is rechecked at execution time.

No canary is proposed for calendar-hard or duplicate-setfile classes because
their observed counts are zero. Missing/header-defective setfiles are repaired
before any run. The ten disposition-mismatch pairs and the 33 unclear pairs are
not rerun.

## Durable artifacts and verification

- Classification CSV (279 rows):
  `docs/ops/evidence/2026-07-31_q02_stranded_pairs_classification.csv`,
  SHA-256 `d0ca06cfbc09051d1822a052cae1a8e5d93c24b6514b2d06754d153775b52fb2`.
- Full JSON packet (query, contract, counts, examples, RETIRE draft, canary
  controls, and 279 records):
  `docs/ops/evidence/2026-07-31_q02_stranded_pairs_classification.json`,
  SHA-256 `e7fb249ff320f97fc33e41a5d95346646930d025142424231d8666be0993c6ca`.
- Reproducible read-only generator:
  `tools/strategy_farm/classify_q02_stranded_pairs_report.py`.

Focused verification checks the generator compiles; JSON and CSV contain the
same 279 unique pairs; all records have zero open rows and zero non-infra
terminal rows in the captured cohort; class and cause sums equal 279; the two
RETIRE aggregates still hash-match and pass every identity check; all 431
calendar summaries are `OK`; duplicate counts remain zero; and all ten canary
setfiles satisfy `RISK_FIXED > 0`, `RISK_PERCENT = 0`. No database write path is
present in the generator: SQLite is opened with `mode=ro`.
