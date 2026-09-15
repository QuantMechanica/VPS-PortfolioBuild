# Head-of-line claim-order preflight starvation — root cause, fix, watch signal

Ticket `c30eebc8-c655-4425-9c01-7dc43348992a` (`agent_tasks`, priority 76). Fleet-wide
claim starvation 2026-09-15 ~08:59Z–09:31Z: all ten `terminal_worker` daemons reported
`no_pending_claimable` for ~32 minutes despite hundreds of plain claimable rows sitting
behind a handful of doomed Q08 rows at the head of the claim order. The orchestrator's
same-day incident response *parked* the 45 context-less Q08 rows as a workaround
(`docs/ops/evidence/2026-09-14_q08_context_repair/hold_q08ctx_*_20260915*.json`,
commit `108c71b7d7`) — this ticket is the actual code fix plus a watch tripwire so the
next row class that hits the same shape (in-lock rejection *after* the out-of-lock
preflight window, instead of before it) doesn't reproduce the deadlock silently.

## Timeline (from the worker logs, read-only)

`extract_starvation_timeline.py` scans all ten `terminal_worker_T*.log` files for
`stage_event=="claim_result"` entries inside `[2026-09-15T08:47Z, 2026-09-15T09:32Z]`
and writes `starvation_timeline_0847_0932.csv` (1,119 claim attempts across the fleet).
`claimed=true` rows in that window:

| at_utc | terminal | item |
|---|---|---|
| 08:47:03.786Z | T5 | 18d9a92c… |
| 08:47:24.880Z | T7 | 4709596e… |
| 08:47:43.552Z | T9 | 6c8af3ce… |
| 08:48:02.704Z | T10 | 84c98b8c… |
| 08:51:44.627Z | T6 | 49b48658… |
| 08:57:12.382Z | T2 | 6809b09f… |
| **08:59:04.305Z** | **T10** | **a4fdec8b…** |
| **09:31:35.132Z** | **T3** | **c10e8ca8…** (drain-predrain item, not a normal claim) |
| 09:31:47.207Z | T2 | 11060418… |
| 09:31:57.802Z | T10 | de326c7b… |

**Zero fleet-wide claims between 08:59:04Z and 09:31:35Z** — a 32-minute gap, matching
the ticket's own timeline exactly (parking landed ~09:31Z per the hold-file
`created_at` timestamps, claims resumed within a minute). Every other claim attempt in
the window (1,109 of 1,119 rows) is `claimed=false`.

## Root cause (bound to code)

`terminal_worker.claim_atomic`'s per-row claim scan (`_claim_with_fifo_turn`, the inner
function under `BEGIN IMMEDIATE`) processes candidates in claim order. Two checks apply
to a Q08 row, in the **wrong relative order**:

1. **History preflight gate** (`terminal_worker.py:6198` before this fix, now
   `terminal_worker.py:6198` after the new block above it) — if the candidate's history
   fingerprint isn't cached yet, the scan **aborts the whole transaction** and returns
   `history_preflight_required`, so the out-of-lock preflight can run outside the lock.
   The caller (`claim_atomic`'s `for _preflight_index in range(CLAIM_PREFLIGHT_MAX_CANDIDATES)`
   loop, `terminal_worker.py:6459` pre-fix) then computes exactly one candidate's
   preflight, caches it, and re-scans **from the top of the claim order** — this budget
   is `CLAIM_PREFLIGHT_MAX_CANDIDATES = 8` (`terminal_worker.py:135`) round trips per
   claim attempt.
2. **Q08 DSR-context seal** (`_seal_q08_dsr_at_claim`, `terminal_worker.py:5111`, called
   at the tail of the per-row loop) — this is a **cheap, mostly claim-time-independent,
   in-lock** check (window/timeframe resolution, single-configuration build-identity
   match) that used to run **only after** the history-preflight gate had already let
   the row through.

Consequence: when Q08 rows bunched at the head of the claim order are the kind that will
**always** fail the DSR-context seal regardless of when they're claimed (bad window,
unresolvable timeframe, or — the actual failure mode measured in this incident, see the
parking-journal reasons `SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_I…` in
`docs/ops/evidence/2026-09-14_q08_context_repair/hold_q08ctx_010fd451_20260915c.json` =
`BUILD_IDENTITY_MISMATCH:<role>` truncated — a stale sha binding), the scan pays for a
full out-of-lock history-preflight round trip on each of them *before* ever discovering
they were doomed anyway. With `CLAIM_PREFLIGHT_MAX_CANDIDATES = 8` and 45 context-less
Q08 rows sitting at the head, the budget exhausts on doomed rows every single claim
attempt; `skip_unchecked_history` then defers every other row for the rest of that one
pass (`history_preflight_deferred`, `terminal_worker.py:6166` region pre-fix), so the
scan never reaches the plain claimable rows behind them. Measured during the incident
(09:2xZ, per-pass): `history_skipped≈103`, `q08_dsr_context_skipped≈7-8`,
`ram_class_skipped≈296`, while **347 plain ≤14GB rows were claimable** and unreached.

RAM-class, poison-pill, and terminal-avoid rejections already run *before* the history
gate (cheap, in-lock, no budget spent) — Q08 DSR context was the **one** exception, and
that ordering bug is the root cause.

## Fix

`tools/strategy_farm/dsr_cohort.py`:
- Extracted `_resolve_single_configuration_identity(candidate, payload, timeframe)`
  (`:832`) — the card-declaration + build-identity-match half of
  `assemble_single_configuration`, with **no dependency on
  `payload['claimed_at_iso']`** (unlike the factory-search-ledger step that follows it,
  which genuinely needs the claim timestamp — `_factory_search_before_q08_claim`,
  `:273`, raises `Q08_CLAIM_TIMESTAMP_REQUIRED` at `:282` if it's missing, by design:
  that step proves no governed optimization row predates the *actual* claim). Both
  `assemble_single_configuration` and the new precheck call this shared helper, so they
  can never drift apart.
- Added `claimability_precheck(conn, candidate_row, payload, *, ledger_root=...)`
  (`:772`) — a claim-time-independent subset of `assemble()`'s checks: identity,
  timeframe, window, then either "DL-089 ledger found" (claimable, defer full assembly
  to the real seal) or the new `_resolve_single_configuration_identity` check. **Only a
  `False` result is authoritative** — `True` is not a promise of eventual claimability,
  it just means nothing catches this row *yet*. The factory-search-ledger step is never
  called from here.

`tools/strategy_farm/terminal_worker.py` (`:6157`–`:6197`): for phase `Q08` candidates,
**and only when the Q08 DSR preflight is actually enabled**
(`os.environ[Q08_DSR_CONTEXT_PREFLIGHT_ENV] == "1" and os.environ["QM_DSR_V2"] == "1"`
— the exact same gate `_seal_q08_dsr_at_claim` already uses, so this is inert when the
feature flag is off, byte-for-byte the pre-fix behavior), the new precheck runs
**before** the history-preflight gate. A `False` verdict skips the row immediately
(`skipped_q08_dsr_context.append(..., stage="claim_time_independent_precheck")`,
`continue`) without ever touching `CLAIM_PREFLIGHT_MAX_CANDIDATES`. A `True`/unresolved
verdict falls through to the unchanged flow (history preflight if needed, then the real
claim-time seal).

**Why this is safe (verified, not asserted):**
- `_merge_history_window_payload` (the thing the history-preflight gate would otherwise
  add to `payload` before the DSR check used to run) only ever writes
  `from_year/to_year/requested_*_year/history_first_year/history_last_year/history_adjusted`
  — none of which `_timeframe`, `_candidate_window`, `_find_ledger`, or
  `_resolve_single_configuration_identity` read. Running the precheck *before* that merge
  cannot change its answer relative to running the equivalent checks *after* it.
- The precheck's `False` set is a strict subset of `assemble()`'s own failure modes (it
  calls the *same* functions `assemble()` calls, not reimplementations) — it can never
  reject a row the real check would have admitted.
- Confirmed no accidental regression: `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`
  and the `dsr_cohort`/`terminal_worker` suites were diffed against unmodified `HEAD`
  under the *same* live-machine environment (`QM_DSR_V2=1`,
  `QM_Q08_DSR_CONTEXT_PREFLIGHT=1` are set process-wide on this VPS) — the same 8 tests
  fail identically on pristine `HEAD` (pre-existing test fixtures with unresolvable
  `dummy.set` timeframes, unrelated to this change; not fixed here to avoid scope creep
  on live-claim-logic code). No new failures introduced.

**No change to:** claim priority semantics, gate thresholds, verdicts, or any active
hold (the 45 parked `Q08_DSR_CONTEXT_UNAVAILABLE` holds are untouched — release remains
gated on their DSR contexts sealing or an explicit follow-up). No worker was restarted
by this ticket.

**Rollback:** the fix is entirely inert unless both `QM_DSR_V2=1` and
`QM_Q08_DSR_CONTEXT_PREFLIGHT=1` are set (the same flag `_seal_q08_dsr_at_claim` already
requires) — unsetting either reverts every worker to pre-fix behavior without a code
change. To remove the code path entirely, revert the `terminal_worker.py:6157`–`:6197`
block and the two `dsr_cohort.py` additions; nothing else references them.

## Tests

- `tools/strategy_farm/tests/test_dsr_cohort.py`:
  `test_claimability_precheck_agrees_with_attach_on_a_sealed_dl089_candidate`,
  `test_claimability_precheck_rejects_unresolvable_window_same_as_assemble`,
  `test_claimability_precheck_rejects_unresolvable_timeframe`,
  `test_claimability_precheck_never_needs_claimed_at_iso_on_the_single_configuration_path`
- `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`:
  `test_head_of_line_doomed_q08_rows_do_not_starve_a_claimable_row_behind_them` (builds
  a claim order with `CLAIM_PREFLIGHT_MAX_CANDIDATES + 2` doomed Q08 rows ahead of one
  plain claimable row; asserts the plain row is claimed in one `claim_atomic` call and
  the only out-of-lock history preflight paid for is its own — none of the doomed rows
  consume the budget),
  `test_head_of_line_doomed_q08_rows_report_the_precheck_stage_when_no_row_is_claimable`
  (companion: all-doomed queue ends `no_pending_claimable` with zero preflight retries
  spent and every skip attributed to `stage=claim_time_independent_precheck`),
  `test_q08_precheck_disabled_by_default_flag_leaves_starvation_path_unchanged`
  (regression guard: flag off ⇒ row is claimed exactly as before this fix existed).

All pass; run:
```
python -m pytest tools/strategy_farm/tests/test_dsr_cohort.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
```

## Watch / health signal

`tools/strategy_farm/health.py`: new check `chk_q08_head_of_line_claim_starvation`
(`:1450`, registered in `ALL_CHECKS`) — `FAIL` when ≥8 terminals each show a
`claim_result` log entry in the last 10 minutes and **none** of them `claimed=true`,
while the farm DB has at least one `pending` row not blocked by an active hold,
supersede, or poison-pill quarantine (the same predicate `claim_atomic`'s own in-lock
blocked-check uses, minus the live host-RAM/commit admission checks a read-only check
cannot evaluate). Runs on the existing `QM_StrategyFarm_Health_15min` schedule, written
into `D:/QM/strategy_farm/state/health.json`.

`tools/strategy_farm/session_tools/hourly_watch_0909.py`: reads that same
`health.json` check by name and appends an `ALERT` line when it's `FAIL` — single
source of truth, no duplicated log-scanning logic in the one-shot watch script.

Test: `tools/strategy_farm/tests/test_health_q08_head_of_line_claim_starvation.py`
(6 cases: no backlog ⇒ OK, 8 idle terminals + backlog ⇒ FAIL, a recent claim on one of
the 8 ⇒ OK, stale entries outside the 10-minute window ⇒ OK, an active hold removing a
row from the backlog ⇒ OK, only 7 idle terminals ⇒ OK).

**Caveat, stated plainly:** "claimable rows with reservation ≤14GB" from the ticket's
acceptance text is approximated here as "pending rows not blocked by a hold, supersede,
or poison-pill" — replicating the *exact* live-RAM-dependent admission arithmetic
(`_commit_reservation_gb_for_item` and friends, which need a live host free-RAM probe)
inside a periodic read-only health check was judged out of scope for this ticket; the
approximation is honest about the false-positive risk it doesn't cover (a fleet
genuinely RAM-saturated, not starved, could in principle also trip this FAIL) and is
documented in the check's own docstring.

## Evidence files in this directory

- `README.md` — this file
- `extract_starvation_timeline.py` — read-only log scanner (re-runnable)
- `starvation_timeline_0847_0932.csv` — 1,119 claim_result rows, 2026-09-15 08:47–09:32Z
- `ticket_payload.json`, `q08_context_unavailable_rows_parked.json` — carried over from
  the same-day parking response (commit `108c71b7d7`)

## Hard limits honored

Read-only against logs and DB throughout evidence gathering; the code fix changes claim
admission-window *mechanics* only (no priority/threshold/verdict/hold semantics); no
worker was restarted by this ticket; tests were written and run before this README.
