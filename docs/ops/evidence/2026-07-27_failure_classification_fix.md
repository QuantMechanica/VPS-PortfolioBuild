# Q02 summary-missing failure classification — census ranks 1, 2, 3

Date: 2026-07-27
Author: Claude (board-advisor lane)
Scope: census ranks 1 (43k `summary_missing_retries_exhausted`), 2 (Q02 INFRA_FAIL share),
3 (the old-pending tail).
Authority for headline volumes: `docs/ops/evidence/2026-07-27_factory_loose_ends_census.md`.
Pattern reused (not reinvented): the Q08 INVALID/INFRA_FAIL boundary fix,
`docs/ops/evidence/2026-07-27_q08_invalid_boundary_fix.md`.
Constraints honoured: **claim path untouched**; **no requeue**; **no bulk verdict
mutation applied**; reclassification is payload-only and reversible.

## 1. The defect

At summary-missing exhaustion (`terminal_worker._finish_work_item`, after
`MAX_WORK_ITEM_RETRIES`) the worker stamped **one** graveyard label —
`final_failure="summary_missing_retries_exhausted"`, `verdict="INFRA_FAIL"` — on every
row. Measured live 2026-07-27:

```
Q02 rows with final_failure=summary_missing_retries_exhausted : 43,736
  (census sampled 43,422 at 12:09 UTC; the delta is live queue drift)
Q02 INFRA_FAIL total                                          : 49,894  (68% of all Q02 rows)
```

That single label says only "we produced no summary and gave up". It conflates a
terminal-side transient, a deterministic EA/build defect, and a row the pipeline has
already resolved elsewhere — so historical evidence production overwhelms strategy
measurement in every count anyone takes.

## 2. What row-bound evidence actually survives

The named evidence sources are the aggregate, the payload reason, and the run log. For
this **historical** population the first and third are almost entirely purged by the
log/cache pruners (measured over all 43,736 rows):

| Evidence | Rows present | Share |
|---|---:|---:|
| run log on disk (`log_path`) | 474 | 1.1% |
| report root on disk (`D:/QM/reports/work_items/<id>`) | 534 | 1.2% |

So for ~99% of historical rows the ONLY surviving row-bound evidence is the payload plus
the row's own `(ea_id, symbol)` key resolved against the same `work_items` table — the
same row-keyed-DB-join basis the Q08 valid-setfile distribution used
(`2026-07-27_q08_valid_setfile_infra_fail_distribution.md`). The **forward** classifier,
by contrast, runs while the fresh log is still present and reads it directly. Both emit
the same action vocabulary.

The 474 surviving logs (a recent-rerun sample) were read to ground the forward
signatures: **445 clean-exit-no-report + 29 report-latched-but-unparsed, 100% reached
`terminal_start`, 0 timeouts, 0 log-bombs** — i.e. the surviving sample is entirely
deterministic, corroborating the DB-derived split below.

## 3. Disjoint classes with counts (measured, sum to population)

Historical cascade (first match wins), all from row-bound evidence, verified read-only
and reproduced by `classify_summary_missing.py` (dry-run):

| # | Class (action) | Subclass | Count | % | Evidence basis |
|---|---|---|---:|---:|---|
| 1 | DETERMINISTIC_NO_SUMMARY | `log_bomb` | 4,236 | 9.7% | `attempt_count>=99` / LOG_BOMB marker (journal flood, poison sentinel) |
| 2 | SUPERSEDED | `pair_has_verdict` | 26,651 | 60.9% | the `(ea,symbol)` pair already has a real (non-NULL, non-INFRA) Q02 verdict |
| 3 | DETERMINISTIC_NO_SUMMARY | `input_missing` | 181 | 0.4% | current set file absent OR EA registry status != active |
| 4 | IN_FLIGHT | `pair_open` | 4,517 | 10.3% | the pair still has a pending/active Q02 successor |
| 5 | TRANSIENT | `transient_token` | 33 | 0.1% | `verdict_reason` carries ACTIVE_TIMEOUT / NO_HISTORY / METATESTER_HUNG / … |
| 6 | DETERMINISTIC_NO_SUMMARY | `never_worked` | 8,118 | 18.6% | pair has ONLY ever INFRA_FAILed (the "119/119 never worked" cohort) |
| | **total** | | **43,736** | 100% | |

Rollup on the retryability axis (the Q08 vocabulary):

```
DETERMINISTIC (non-retryable -> INVALID) : 12,535  (28.7%)   = log_bomb + input_missing + never_worked
SUPERSEDED  (a verdict already exists)   : 26,651  (60.9%)
IN_FLIGHT   (a successor is queued)      :  4,517  (10.3%)
TRANSIENT   (retryable -> INFRA_FAIL)    :     33  (0.1%)
UNCLASSIFIED (no evidence survived)      :      0
```

Key finding, MEASURED not assumed (the brief asked): the population is **not**
transient. Only 0.1% carry an explicit transient signature; 60.9% are already resolved
elsewhere and 28.7% are deterministic defects. This matches the Q08 finding that ≤2% of
that gate's INFRA_FAIL rows were genuinely transient. Spot-checks confirmed the two
load-bearing classes (SUPERSEDED pairs carry FAIL/INVALID/ZERO_TRADES verdicts;
NEVER_WORKED pairs are INFRA-only, e.g. QM5_10009/AUDUSD 15/15).

## 4. Implemented going-forward (census rank 1/2)

`farmctl.classify_summary_missing_run(payload, log_text)` (`farmctl.py`, next to the
Q08 helpers) classifies a fresh exhaustion from, in order of authority: the log's LAST
`run_smoke.stage=terminal_exit` signature (`timed_out` / `valid_report_latched` /
`log_bomb`), then explicit `verdict_reason` tokens, then whether `terminal_start` was
ever reached. Vocabulary is the shared `SM_CLASS_*`.

`terminal_worker._finish_work_item` (the exhaustion `else` branch) now calls it and, per
the Q08 pattern:

| Signature | Subclass | verdict |
|---|---|---|
| clean exit, no valid report | `no_report` | **INVALID** (deterministic) |
| valid report latched, still no summary | `report_unparsed` | **INVALID** |
| `log_bomb=True` | `log_bomb` | **INVALID** |
| explicit ONINIT_FAILED / REPORT_FORMAT_DRIFT / INVALID_REPORT / … | `deterministic_token` | **INVALID** |
| `timed_out=True` | `terminal_timeout` | INFRA_FAIL (retryable) |
| never reached `terminal_start` | `launch_fault` | INFRA_FAIL |
| explicit transient token | `transient_token` | INFRA_FAIL |
| log unreadable / no discriminating evidence | `unclassified` | INFRA_FAIL |

The generic `final_failure` tag is preserved (back-compat for existing surveys) and the
honest `verdict_reason` becomes `summary_missing:<subclass>`. **Fail-open by contract:**
any unreadable/ambiguous evidence yields UNCLASSIFIED → INFRA_FAIL, i.e. the prior
behaviour, so a recoverable run is never wrongly demoted to non-retryable.

Why this cannot reduce MT5 saturation: the classifier runs only at the exhaustion
boundary, when the row is already terminal after its retries. It changes the terminal
**label** and future retry-eligibility, not the retry burn, so no running or claimable
backtest is affected. INVALID is already a first-class Q02 verdict (1,578 exist today)
and `_aggregate_work_item_verdict` (`farmctl.py:5553`) already treats INVALID exactly
like INFRA_FAIL, so parent aggregation and downstream enqueue are unchanged.

## 5. Historical reclassification — tool built, apply deferred (census rank 1)

`tools/strategy_farm/classify_summary_missing.py` stamps `failure_class`,
`failure_subclass`, `failure_class_evidence` into `payload_json` **only** — it never
touches `verdict`, `status`, `attempt_count`, `evidence_path`, `claimed_by` or
`updated_at`, and never requeues. It therefore has **zero** claim-path/routing impact;
it only makes the honest cause visible to reason histograms, dashboards and the new
detectors. Safety mirrors the ratified `backfill_verdict_reason.py`: dry-run default,
reversible pre-apply snapshot, each UPDATE guarded on the exact prior `payload_json`
(a row a worker changed is skipped, never clobbered), `--revert`, batched commits.

Dry-run projection against the live DB (reproduces §3): **43,736 rows would receive a
`failure_class`** — 12,535 DETERMINISTIC / 26,651 SUPERSEDED / 4,517 IN_FLIGHT /
33 TRANSIENT.

**Not applied.** Consistent with the two sibling same-day fixes (Q08 boundary,
state-machine exits both delivered mechanism + projection and deferred the write), and
with `backfill_verdict_reason.py`'s own "Factory OFF while applying" contract: a 43k-row
write belongs in a quiescent window, not against the live saturated fleet, and the
factory must not be stopped here (hard constraint). Apply is a single reversible command
in that window:

```
python tools/strategy_farm/classify_summary_missing.py            # dry-run projection
python tools/strategy_farm/classify_summary_missing.py --apply    # payload-only, reversible
python tools/strategy_farm/classify_summary_missing.py --revert <snapshot>
```

Promoting the DETERMINISTIC class's stored `verdict` from INFRA_FAIL to INVALID (so old
defects can never be re-run by a future sweep) is a further, OWNER-gated step and is
deliberately out of scope here.

## 6. Rank 3 — the old-pending tail: established, deliberate, now visible

Measured now: **1,457 pending rows >14d** (Q02 1,432; census 1,458), oldest
`created_at` 2026-05-23. `>30d` has fallen 325 → 108 as the queue drains, confirming the
census's "draining in aggregate" while the inherited tail lingers.

Why it does not resolve FIFO — established from the claim mechanism and the tail's
composition, NOT re-deriving the census counts:

- **Claim ordering is deliberately priority-first, not FIFO.** `pending_claim_order_sql`
  (`farmctl.py:851`) orders by `recovery_rank, priority_track, phase (Q02 last),
  basket, winner-EA, asset-class (METAL>INDEX>ENERGY>FX)` and only then
  `updated_at, created_at`. Age is the FINAL tie-break, so an old FX/non-winner Q02
  pre-screen loses to every newer metal/index/winner arrival.
- **86.8% of the old tail (1,204/1,387 Q02) is `recovery_class`-tagged**, which sorts
  DEAD LAST (`_recovery_rank=1`) and is idle-capped by the ratified Operating-Rule-22
  recovery throttle (`recovery_claim_allowed`, `farmctl.py:857`) — reached only when the
  frontier is idle, capped to ≤1 per `CLAIM_RECOVERY_WINDOW` claims fleet-wide.
- Tail composition: 1,121/1,387 non-winner EAs; 753 FX/OTHER; 508 METAL.

Not a claim-path defect and not the documented silent-skip starvation: **1,222/1,387
(88%) were `updated_at` within the last 2 days** — the rows are visited every cycle then
deprioritised, not silently ignored; **0** are in launch cooldown and **0** are in an
active poison quarantine. The persistent claim skips that *are* silent (`symbol active`,
`q04 active`, `multisym active`) are transient per-cycle conditions that self-clear and
cannot produce a 14-day tail; the persistent skips (history, launch cooldown, resource,
avoid-terminal, recovery cap) are all logged in the claim result.

Per the brief ("if the ordering is deliberate, say so and make the age visible") the fix
is a detector, **not** a claim-path change → zero saturation risk.

## 7. Detection (census rank 1/3)

Two read-only invariants in `health.py`, registered in `ALL_CHECKS`, run every 15 min:

- **`chk_pending_tail_age`** — surfaces pending rows older than 14d, the recovery-capped
  subset, per-phase split and the oldest `created_at`. WARN standing (an inherited tail
  exists), FAIL if it grows past 1,900 (above the ~1,458 inherited tail → genuine
  regrowth / drain stall). First live run: `WARN value=1457` (Q02=1432,
  recovery_class=1204, oldest 2026-05-23).
- **`chk_q02_summary_missing_unclassified`** — of Q02 summary-missing terminals updated
  in the last 48h, the share carrying NO `failure_class` (→ the forward classifier
  regressed) and the share `UNCLASSIFIED` (→ a new signature the classifier misses).
  FAIL on ≥50% missing, WARN on ≥50% unclassified, OK below 20 rows. First live run:
  `OK` (0 new summary-missing terminals in 48h — production has been ~0 for 5 days).

## 8. Tests

`tools/strategy_farm/tests/test_summary_missing_classification.py` — 25 tests, all pass:
forward classifier across every signature incl. fail-open and last-exit-wins-on-relaunch;
the historical cascade's six disjoint classes incl. precedence (superseded beats
input-missing); the reversible payload-only apply (verdict/status/updated_at asserted
untouched), the drift guard (row changed since inspection → skipped, never clobbered),
and a byte-identical revert; both detectors.

Regression (all pass, from repo root):
`test_verdict_taxonomy_ws2` 22 · `test_ultracode_wsh_q08_reason` 14 ·
`test_requeue_stranded_infra` 17 · `test_terminal_worker_atomic_claim` 53 ·
`test_terminal_worker_adoption` 4 · `test_terminal_worker_history_lock_storm` 13 ·
`test_terminal_worker_q_phase_stall` 1 · `test_ultracode_wsa_claim` 16.

## 9. Files changed

- `tools/strategy_farm/farmctl.py` — `classify_summary_missing_run` + `SM_CLASS_*` /
  token constants (shared vocabulary).
- `tools/strategy_farm/terminal_worker.py` — exhaustion boundary classifies + routes
  deterministic → INVALID, transient/unknown → INFRA_FAIL (fail-open).
- `tools/strategy_farm/classify_summary_missing.py` — new reversible historical
  reclassifier (payload-only, dry-run default, no requeue).
- `tools/strategy_farm/health.py` — `chk_pending_tail_age` +
  `chk_q02_summary_missing_unclassified` + registration.
- `tools/strategy_farm/tests/test_summary_missing_classification.py` — new tests.

## 10. Not done (deliberately)

- No bulk write applied to the 43,736 historical rows (Factory must stay ON; deferred to
  a quiescent window via the reversible tool).
- No verdict promotion of historical DETERMINISTIC rows to INVALID (OWNER-gated).
- No claim-path change (rank 3 is deliberate ordering; addressed by visibility).
- The QM5_20180 joint-EA fidelity divergence is a separate diagnosis.
