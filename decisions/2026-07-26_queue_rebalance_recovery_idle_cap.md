# Queue-rebalance: recovery-class idle-cap + Q08 insufficient-trades reason (ULTRACODE WS-A+H)

**Date:** 2026-07-26 · **Decided by:** OWNER (2026-07-26 ULTRACODE directive; direction
pre-ratified) · **Built by:** Claude (Opus) · **Reviewer:** Codex (bilateral) ·
**Status:** STAGED (round 2 — post-Codex-CHANGES-REQUIRED) — code merges + classifier
`--apply` run ONLY in tonight's Factory-OFF window. **Scope:**
`tools/strategy_farm/{farmctl.py,terminal_worker.py}`,
`tools/strategy_farm/classify_recovery_pending.py` (new), tests. No live DB writes by the
builder; live reads were URI `mode=ro` + `PRAGMA query_only=ON`.

**Round-2 base:** canonical `agents/board-advisor` HEAD (code-identical, for the touched
files, to the `d9ebd731…` tree Codex reviewed). Round-1's `1c486f747` base was 3 days /
~2000 lines of `farmctl.py` stale; this patch is rebased onto the live board-advisor code.

Authority: `docs/ops/plans/2026-07-26_ULTRACODE_PROGRAMME.md` (v2, WS-A+H) +
`docs/ops/evidence/2026-07-26_codex_challenge_ultracode.md` (PROCEED-WITH-REVISIONS) +
`docs/ops/evidence/2026-07-26_codex_review_ultracode_wave.md` (round-1 CHANGES-REQUIRED).

## WS-A — recovery is idle-only, capped, provenance-tagged

### Problem
The Q02 pending pool is ~2,139 rows; ~1,678–1,683 are recovery debris (stranded
infra-fail requeues, deferred promotions, post-build auto_q02) that FIFO-compete with
genuine priority/frontier work. Codex's challenge established: (a) the production
claimants are `terminal_worker.claim_atomic` (primary) AND `farmctl.dispatch_work_items`
(secondary) — BOTH must be atomic; (b) a hard 20% *reservation* would violate Operating
Rule 22 (recovery only on idle capacity); (c) an in-memory ratio is not concurrency- or
restart-safe.

### Rule (ordering contract)
One selector, every claimant: `farmctl.pending_claim_order_sql()` is now the single
ordering contract, used by both `terminal_worker._priority_pending_query` (primary
claimant) and the `farmctl.dispatch_work_items` secondary claimant. It preserves the
prior `priority_track → phase → basket → winner → asset → FIFO` ordering **exactly** and
only PREPENDS a `_recovery_rank` (recovery rows sort LAST). Recovery rows are those
carrying the payload marker `recovery_class` (set by the classifier). Inert until the
classifier tags rows: with zero tags every `_recovery_rank` is 0 and the emitted order is
byte-identical to the prior contract.

Recovery is claimable **only when no eligible priority/frontier row exists** (idle-only —
recovery sorts last, so the claim loop reaches it only after every higher-priority row was
claimed or skipped by a resource filter, i.e. the resource-filter fallback), AND bounded by
a **durable rolling idle-cap**:

- **Denominator:** the last `CLAIM_RECOVERY_WINDOW = 5` SUCCESSFUL claims across the whole
  worker-set (all terminals sharing this farm DB share ONE ledger: `claim_class_ledger`).
- **Cap:** recovery may take at most `CLAIM_RECOVERY_MAX_IN_WINDOW = 1` of them (allowed
  only when none of the last 4 recorded claims was recovery). Long-run recovery share
  ≤ 20%, and only on idle capacity, so the realised share is far lower.
- **Advance:** the ledger is advanced INSIDE the same `BEGIN IMMEDIATE` transaction as the
  successful claim (concurrency-safe: competing workers serialise on the write, so "one in
  five" means successful eligible claims, not query attempts).
- **Restart behaviour:** the ledger is a DB table, not an in-memory counter — a worker
  restart / VPS reboot does NOT reset the window.

### RATIFIED contract clause — the idle-only escape (explicit, not an implicit exception)
`recovery_claim_allowed(conn)` has exactly two regimes. This clause is a **ratified part of
the contract**, not a silent fallback:

1. **Frontier has work** (at least one non-recovery pending row exists anywhere in the
   farm): recovery is throttled to the rolling cap above.
2. **Frontier globally empty** (there is NO non-recovery pending row anywhere): the cap is
   suspended and **every recovery row is eligible** — recovery drains freely. Rationale:
   the cap exists to protect the frontier's throughput; when there is no frontier work to
   protect, throttling recovery would only idle the factory. It also prevents a
   *drain-stall*: a pure "share of the last N successful claims" window can never advance
   if recovery is the only producer of claims, so without this clause a recovery-only
   backlog would deadlock behind its own cap. This is the intended, ratified behaviour and
   is asserted by tests (`test_recovery_drains_freely_when_frontier_globally_empty`,
   `test_dispatch_recovery_drains_when_frontier_globally_empty`).

No-starvation invariant: priority/frontier work is NEVER blocked by recovery (recovery
sorts last and is cap-throttled while any frontier work exists); recovery is NEVER starved
either (the idle-only escape guarantees it drains once the frontier empties).

### Both claimants are claim-then-spawn with full compare-and-swap (round-2 repair)
Codex round-1 accepted the primary `claim_atomic` ledger transaction but REJECTED the
secondary `dispatch_work_items` path because it (1) read the recovery cap on a separate
connection, (2) spawned the MT5 runner BEFORE securing the DB claim, (3) updated the row by
`id` with no `status='pending'` guard, and (4) did not use the affected-row count as the
compare-and-swap outcome before recording the ledger. Round-2 rewrites the secondary
Phase-2 loop to the SAME discipline as the primary:

- For every candidate, ONE `BEGIN IMMEDIATE` transaction does, in order: read the recovery
  idle-cap decision (`recovery_claim_allowed`), attempt the claim
  `UPDATE … SET status='active', claimed_by=? … WHERE id=? AND status='pending'`, take
  `cur.rowcount == 1` as the compare-and-swap outcome, and — only on a won claim — advance
  the durable `claim_class_ledger`, then commit.
- The MT5 runner is spawned **only after** the claim is won. A lost CAS (the row was taken
  by `claim_atomic` or a prior pass between the selector snapshot and the transaction)
  NEVER spawns and NEVER overwrites the winning claimant; the terminal is returned and the
  loop advances. A capped recovery row NEVER spawns.
- The pre-spawn claim payload carries `claimed_by_worker_pid` so a concurrent
  `claim_atomic` for the same terminal treats the freshly-claimed row as worker-busy (not a
  stale claim to release) during the spawn window; a short-lived dispatch process is handled
  by `claim_atomic`'s existing orphan-child adoption path once the runner PID is live.

Both entry points are exercised by their REAL production code in
`tests/test_ultracode_wsa_claim.py` (the round-1 `_dispatch_style_claim` replica Codex
rejected is deleted): deterministic proofs that dispatch secures the claim before spawn,
advances the ledger only on a won claim, refuses to spawn / overwrite on a lost CAS, and
reads the recovery cap inside the claim transaction — plus a genuine multi-connection
contention test running REAL `dispatch_work_items` concurrently with REAL
`claim_atomic` (no double-claim; queue drains).

### Provenance & compare-and-swap (classifier)
`classify_recovery_pending.py` tags pending Q02 rows whose explicit
`payload["enqueued_by"]` provenance matches EXACTLY one of the three recovery lineages —
`stranded_infra_fail`, `deferred_promotion`, `auto_q02` — never by string-guessing verdict
reasons. `never_tested` (fresh discovery) is excluded; `priority_track` rows are skipped.
Each target row id is bound to its PRE- and POST-image payload SHA256 in a durable batch
manifest; `--apply`/`--revert` mutate a row only when its current payload still hashes to
the expected image (true compare-and-swap). Read-only dry-run census (live DB, `mode=ro`):
~**1,678–1,683 would tag** (stranded_infra_fail ≈1,327–1,332 · deferred_promotion 209 ·
auto_q02 142), ~15 priority_track skipped —
`D:\QM\reports\ultracode_20260726\wsa2\recovery_tag_manifest.json`. Codex verified this
classifier sound in round 1; it is NOT re-run here. Apply/revert run ONLY in the
Factory-OFF window, and only AFTER the claimant contract lands and the census is
regenerated in Factory-OFF.

### Rollback
1. **Data:** `classify_recovery_pending.py --manifest <manifest> --revert` (CAS-untag)
   restores every tagged row's exact pre-image; recovery rows return to normal ordering.
2. **Code inertness:** with zero `recovery_class`-tagged rows, `_recovery_rank` is 0 for all
   rows and ordering is byte-identical to the prior contract — the change is inert until the
   classifier runs.
3. **Full code:** revert this patch (single constant flip is not needed — the mechanism is
   dormant without tags).

## WS-H — Q08 top-level-infra insufficient-trades → INVALID

`farmctl._derive_phase_runner_verdict`, for Q08 (P5c) ONLY, evaluates the authenticated
dominant sub-gate evidence BEFORE the generic top-level `INFRA_FAIL/ERROR/TIMEOUT` return. A
Q08 run the harness labelled infra whose ONLY blocking sub-gates are the explicit
insufficient-trades / `INSUFFICIENT_*` family (authenticated: `sub_gates` present,
`n_trades` > 0, no genuine-infra token, no computed FAIL, no non-insufficient INVALID)
reclassifies to `INVALID` (a merit-adjacent could-not-compute, not retry-owed infra).
Genuine launch/transport/report/timeout failures, and any mixed/missing/unauthenticated
evidence, keep `INFRA_FAIL`.

Codex verified in round 1 that this precedence repair is **forward-safe**: on the available
corpus **zero historical rows reclassify and zero unrelated phases change** — the one live
top-level `INFRA_FAIL` Q08 row (QM5_11124/SP500) is a genuine MIXED case (computed 8.4 FAIL
+ PBO lineage-invalid + regime-join-failed) that WS-H correctly PRESERVES. WS-H is a
forward-looking taxonomy repair. Rollback: revert the single added branch.
