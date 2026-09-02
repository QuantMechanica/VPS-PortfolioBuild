# Terminal claim write-lock narrowing

**Router task:** `09c5a4b4-8a97-4c13-845a-ca5150c3bce6`
**Implementation:** `522662de1d` on `agents/board-advisor`

## Result

Candidate ordering and selector evaluation no longer run inside
`BEGIN IMMEDIATE`. The claim connection is `PRAGMA query_only=ON` through the
candidate walk. It temporarily becomes writable only for terminal-state
housekeeping, an item-bound hold, or the final exact-row claim.

The final claim re-reads the exact row and requires the same pending payload,
`claimed_by IS NULL`, no active hold, and no supersession edge. The `UPDATE`
repeats those predicates. A lost race continues to the next candidate without
changing the losing row. Claim-class ledger advancement stays in the same short
transaction as the successful status transition.

No selector SQL, priority order, lane token, pruning token, resource gate,
isolation rule, history receipt, verdict, or threshold changed.

## Measurement and regression proof

Every successful claim result and resident-worker `claimed` event now includes
`claim_write_lock_ms`.

Twenty isolated claims against the canonical schema measured:

- minimum: 2.976 ms;
- mean: 4.048 ms;
- maximum: 8.752 ms; and
- mean end-to-end selector time: 430.453 ms.

The maximum is 114× below the `<1 s` acceptance limit. Machine-readable values
are in `docs/ops/evidence/2026-09-02_claim_write_lock_measurement.json`.

The new optimistic-race regression inserts an active hold from a competing
`BEGIN IMMEDIATE` writer after the candidate has been read. The writer succeeds
during selection; the final CAS sees the hold and leaves the row
`pending/unclaimed`. The existing two-worker same-row race still yields exactly
one winner. This directly covers the former writer-convoy boundary without
changing queue semantics.

Worker suite result: **209 passed plus four subtests**, 0 failed, in 80.73 s.
The first suite pass exposed one pre-existing identity-spawner test that read
live host RAM (2.68 GB at that instant); that test now mocks the headroom policy
because it tests inherited identity, while the actual headroom policy retains
its own tests. The complete rerun is green.

## Live rollout guard

A staggered reload was considered only for workers with both no active row and
no `run_smoke.ps1` child. At 16:07Z the host had 5.31 GB free RAM and six active
terminal rows. The governed spawner reported RAM-throttled admission; stopping
an idle worker would therefore reduce the running fleet and refuse its
replacement. No worker was stopped, no active tester was interrupted, and no
terminal was started manually.

Consequently, live before/after busy-share evidence is truthfully deferred
until an idle worker and governed replacement headroom coincide. The code-level
writer concurrency regression and lock-duration metric are complete; resident
workers will emit comparable `claim_write_lock_ms` after a safe staggered
reload. This task does not claim live rollout completion.

## Rollback

Revert `522662de1d`, then reload only naturally idle workers one at a time after
confirming no active row and no tester child. No database repair, hold release,
lineage edit, or verdict rewrite is required. Never reload an active worker and
never start `terminal64.exe` manually.
