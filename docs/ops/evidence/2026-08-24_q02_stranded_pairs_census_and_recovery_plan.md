# Census + staged recovery plan for the 88 stranded Q02 (EA, symbol) pairs

- **Task ID:** 9e23d73f-7b94-494f-95f1-0ccd83013501 (claude, ops_issue, priority 65)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Evidence source:** `farmctl health` FAIL `q02_stranded_exhausted_pairs`, 2026-08-24T14:11Z
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)
- **Status:** Analysis + plan only. **No requeue was executed, no verdict was
  changed, no row was deleted.** Per the task's own constraint, disposition
  proposals go to OWNER as a template; execution is a separate, later action.

## 1. Definition (reproduced from `health.chk_q02_stranded_exhausted_pairs`)

A `(ea_id, symbol)` pair is "stranded" when its `Q02`/`P2` work-item history has:
1. No row with a non-`INFRA_FAIL` terminal verdict (i.e. never got a real PASS/FAIL/
   ZERO_TRADES/INVALID disposition),
2. No `pending`/`active` successor currently queued, and
3. At least 12 (`sweep_enqueue_built_eas.MAX_INFRA_ATTEMPTS`) rows with
   `verdict='INFRA_FAIL'`.

Re-running this exact query against the live DB just now (not the 14:11Z snapshot)
returns **88 pairs**, matching the task's evidence source count exactly — the set is
stable.

## 2. Census

Full table: `docs/ops/evidence/2026-08-24_q02_stranded_pairs_census.csv` (89 rows incl.
header) — columns: `ea_id, symbol, infra_fail_rows, distinct_reason_count,
distinct_reasons, last_updated, ea_dir_exists, ea_dir_name, registry_status,
classification, terminal_work_item_id, current_repo_ex5_sha256`.

Method: for every stranded pair, pulled every `Q02`/`P2` row's
`payload_json.verdict_reason` (the free-text infra sub-classification, e.g.
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`), checked whether the EA's directory
still exists under `framework/EAs/` and its `ea_id_registry.csv` status, and recorded
the terminal (most recent) row's `id` plus the EX5 SHA256 currently sitting in the
repo for that EA (needed later for `--expected-current-ex5-sha256` at execution time).

**Error-class frequency across all 88 pairs' full attempt history** (a pair can carry
multiple tokens across its 12+ attempts):

| reason token | pairs carrying it at least once |
|---|---:|
| `INCOMPLETE_RUNS` | 77 |
| `summary_missing_retries_exhausted` | 60 |
| `ONINIT_FAILED` | 38 |
| `NO_HISTORY` | 35 |
| `cold_cache_retries_exhausted` | 26 |
| `BARS_ZERO` | 23 |
| `ACTIVE_TIMEOUT` | 22 |
| `METATESTER_HUNG` | 12 |
| `REPORT_MISSING` | 10 |
| `TIMEOUT` | 8 |
| `shared_bases_history_lock_transient_cap_exhausted` | 6 |
| `summary_missing` | 4 |
| `LOG_BOMB` | 4 |
| `setfile_missing` | 1 |
| `unclassified` | 1 |

**None** of the 88 EA directories are missing and **none** are `retired` in
`ea_id_registry.csv` — this cohort is not a stale/orphaned-identity problem, it is a
live-EA retry-exhaustion problem.

## 3. Classification: recoverable vs. deterministically dead

**Rule applied:** if every single attempt for a pair (12+ attempts, spanning the
pair's full retry history) reports the *exact same* `verdict_reason` token set with no
variation, that is evidence of a structural/deterministic defect a blind retry cannot
fix — the environment/infra varied across those attempts (different times of day,
different terminals, different days) but the outcome never did. If the reason token
mix *varies* across attempts (e.g. sometimes `TIMEOUT`, sometimes `METATESTER_HUNG`,
sometimes `NO_HISTORY`/`BARS_ZERO`/`cold_cache_retries_exhausted`), that pattern matches
transient infra/environment contention, which the same forensics sweep in this cycle
(`docs/ops/evidence/2026-08-24_throughput_forensics.md`) independently confirmed is a
real, current condition on this fleet (CPU pauses up 60%, long-run terminal occupancy).

- **72 pairs — `RECOVERABLE_MIXED_TRANSIENT`.** Reason tokens vary across the attempt
  history; classified recoverable, staged requeue proposed (§4).
- **14 pairs — `LIKELY_DEAD_DETERMINISTIC_ONINIT`.** Every attempt, with no exception,
  reports exactly `ONINIT_FAILED;INCOMPLETE_RUNS`, spanning 12+ attempts each over
  16 hours to 3 days per pair (e.g. `QM5_11325` GBPUSD.DWX: 2026-08-10T19:31Z through
  2026-08-11T11:24Z, 12/12 identical). This is the exact doctrine already on record
  from the 2026-08-20 INPUTSVALID-FRAMEWORK-PIN incident: **`ONINIT_FAILED` must never
  be blindly requeued** — it is reproducible across arbitrary time windows, which rules
  out a transient shared-resource cause and points at the EA's own `OnInit()` (a pinned
  input, a missing precondition the EA itself requires, or a genuine framework-contract
  violation). Requeuing without a source-level fix would just burn another 12 attempts.
  Pairs: `QM5_11325`×2, `QM5_11353`×3, `QM5_11388`×2, `QM5_11619`×1, `QM5_12435`×1,
  `QM5_12436`×1, `QM5_1626`×2, `QM5_20073`×1, `QM5_20144`×1.
- **2 pairs — `LIKELY_DEAD_DETERMINISTIC_SINGLE_REASON`.** `QM5_1560` SP500.DWX and
  WS30.DWX: every attempt reports `LOG_BOMB;INCOMPLETE_RUNS` — the EA is flooding the
  tester log (e.g. an unconditional per-tick `Print()`), which is a code defect, not
  infrastructure. No retry will change this outcome either.

**16 pairs total need an EA-source fix before any retry is useful — 10 distinct EAs**
(`QM5_11325`, `QM5_11353`, `QM5_11388`, `QM5_11619`, `QM5_12435`, `QM5_12436`,
`QM5_1626`, `QM5_20073`, `QM5_20144`, `QM5_1560`; several have multiple stranded
symbols — see §5 for the per-EA symbol list).

## 4. Staged recovery plan for the 72 recoverable pairs (proposal, not executed)

**Headroom precondition — check before every batch, not just once:**

```
python C:/QM/repo/tools/strategy_farm/farmctl.py health
```

Require the `mt5_worker_saturation` check to read `OK` or `WARN` (never `FAIL`), **and**

```
python C:/QM/repo/tools/strategy_farm/farmctl.py mt5-slots
```

to show at least 2 currently-idle slots before enqueuing that batch. Given this same
cycle's forensics finding (long-run Q10 parents occupying 4+ terminals for hours, 22
concurrent Codex hosts on a 16-logical-CPU host), the fleet is presently **not** a good
time for a bulk requeue burst — this is exactly why execution is deferred to whoever
runs this plan with a fresh headroom check at that time, not bundled into this task.

**Batches** (72 pairs grouped by EA into 9 batches of ≤10, so one EA's canary evidence
never splits across batches): full per-pair detail (`terminal_work_item_id`,
`current_repo_ex5_sha256`) is in the census CSV; batch membership:

| batch | pairs | EAs |
|---|---:|---|
| 1 | 10 | QM5_10000, QM5_10001, QM5_10016, QM5_10037, QM5_10189, QM5_10269, QM5_10327 |
| 2 | 7 | QM5_10369, QM5_10466, QM5_10565, QM5_10574, QM5_10591 |
| 3 | 10 | QM5_10718 |
| 4 | 9 | QM5_10907, QM5_11056, QM5_11100, QM5_11145, QM5_11147, QM5_11232, QM5_11235, QM5_11605 |
| 5 | 8 | QM5_11619 (AUDUSD/EURUSD only — its GBPUSD pair is in the dead cohort, §3), QM5_11625, QM5_11673, QM5_1194, QM5_1208, QM5_1225 |
| 6 | 7 | QM5_1229, QM5_1231, QM5_12356, QM5_12430, QM5_12486 |
| 7 | 10 | QM5_12538, QM5_12582, QM5_12705, QM5_12972, QM5_12975 |
| 8 | 9 | QM5_12997, QM5_13037, QM5_13212, QM5_1383, QM5_1536, QM5_1642, QM5_1800, QM5_20143 |
| 9 | 2 | QM5_9940 |

**Exact command per pair** (governed append-only rerun — Q02 is the entry gate, so
unlike a Q05+ cascade rerun there is no upstream `--from-work-item-id` predecessor to
bind; **never omit `--append-only-rerun-of`** — per the standing incident record
`feedback_enqueue_backtest_requeue_trap_2026-08-22`, a rerun without it silently
requeues the terminal row itself, wiping its verdict/evidence rather than creating a
new row):

```
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest \
  --ea <EA_LABEL> --phase Q02 \
  --append-only-rerun-of <terminal_work_item_id from the census CSV, full UUID> \
  --rerun-reason "q02_stranded_recovery_2026-08-24: recoverable-transient cohort, staged batch <N>" \
  --expected-current-ex5-sha256 <current_repo_ex5_sha256 from the census CSV>
```

After each batch, re-run `farmctl.py health` before starting the next batch; if
`q02_stranded_exhausted_pairs` count does not drop by roughly the batch size within a
reasonable window, or if the fleet health check regresses to `FAIL`, halt and
re-triage rather than continuing to the next batch.

## 5. OWNER decision template for the 16 deterministically-dead pairs (not executed)

| EA | affected symbols | reason | proposed disposition |
|---|---|---|---|
| QM5_11325 | GBPUSD, USDJPY | ONINIT_FAILED, 12/12 identical | Investigate `OnInit()` — likely a pinned/missing precondition (news calendar, seed, or symbol-availability check specific to this EA). Do not requeue until source-reviewed. |
| QM5_11353 | AUDCHF, AUDJPY, AUDNZD | ONINIT_FAILED, 12/12 identical | Same as above; affects 3 symbols identically, suggesting a universe-independent OnInit defect. |
| QM5_11388 | GBPUSD, USDJPY | ONINIT_FAILED, 12/12 identical | Same as above. |
| QM5_11619 | GBPUSD | ONINIT_FAILED, 12/12 identical | Same as above (this EA's other stranded symbol, if any, is separately classified — see census CSV). |
| QM5_12435 | XAUUSD | ONINIT_FAILED, 12/12 identical | Same as above. |
| QM5_12436 | XAUUSD | ONINIT_FAILED, 12/12 identical | Same as above. |
| QM5_1626 | NDX, XAUUSD | ONINIT_FAILED, 12/12 identical | Same as above; 2 symbols. |
| QM5_20073 | XAUUSD | ONINIT_FAILED, 12/12 identical | Same as above. |
| QM5_20144 | USDCHF | ONINIT_FAILED, 12/12 identical | Same as above. |
| QM5_1560 | SP500, WS30 | LOG_BOMB, every attempt | EA is flooding the tester log (likely an unconditional per-tick `Print()`/logging call). Fix the logging call site, then requeue; do not requeue as-is. |

**Recommended OWNER options per row (template — OWNER selects, this task does not
act):**
1. Route to a `review_ea`/rework task for source repair (OnInit precondition audit or
   log-call fix), then requeue via the same append-only mechanism once fixed.
2. Reclassify explicitly as a non-infra terminal disposition (e.g. `INVALID`) if OWNER
   judges the defect severe enough to retire the pair without further investigation —
   this requires a real governed verdict write, which this task does not perform.
3. Leave as-is (no action) if OWNER deprioritizes these EAs relative to farm capacity.

## 6. Not done

- No `enqueue-backtest` command was run. No `work_items` row was created, modified, or
  deleted. No verdict was written or changed anywhere.
- No OWNER decision was assumed; §5 is a proposal template only.
- Batch execution (§4) requires a fresh headroom check at execution time, not the
  snapshot in this document.

## 7. Artifacts

- Census CSV: `docs/ops/evidence/2026-08-24_q02_stranded_pairs_census.csv`
- This document.
