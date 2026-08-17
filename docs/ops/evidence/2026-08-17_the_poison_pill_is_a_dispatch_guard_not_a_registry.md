# The poison pill is a dispatch guard, not a registry — 803 poisoned pairs are unrecorded

Corrects my own certification from two rounds ago, which closed brief item 1.4.

## What I said, and what is actually true

I reported `poison_pill_quarantine` as "the per-pair stopping rule: threshold exactly 5, refreshed
continuously inside `dispatch_work_items`, enforced by claim-order exclusion, 184 active seals — the
good version of the fail-closed pattern", and closed 1.4 on it.

The enforcement claim stands. The **scope** claim did not, and `scan()` says so in one line:

```python
triples = conn.execute(
    "SELECT DISTINCT ea_id,symbol,phase FROM work_items WHERE status='pending'"
).fetchall()
```

**It only diagnoses triples that currently have a pending row.** A pair that has already burned its
threshold and has nothing queued is never examined, never sealed, and never recorded.

## The measurement

Triples with ≥ 5 infra-class terminal rows (`INFRA_FAIL` / `INVALID`) and **zero** merit verdicts:

| | count |
|---|---:|
| eligible triples | **1,158** |
| visible to `scan()` (a pending row exists) | 173 |
| invisible (nothing queued) | 985 |
| …of those, sealed at an earlier queued moment | 182 |
| **invisible and never sealed — unrecorded poisoned pairs** | **803** |

Currently sealed in the table: **184**. So an inventory built from `poison_pill_quarantine` sees
184 where the true population is 1,158 — a **6.3× undercount**.

By phase: **Q02 786**, Q03 6, Q08 4, Q04 4, Q05 3.

The tail is severe — these are pairs that failed far past the threshold and hold no record:

| pair | infra failures |
|---|---:|
| QM5_10692 / NDX / Q05 | **42** |
| QM5_10440 / NDX / Q05 | 34 |
| QM5_12406 / NDX / Q02 | 24 |
| QM5_10792 / WS30 / Q02 | 22 |
| QM5_11062 / {AUDUSD, EURUSD, GBPUSD, NDX} / Q02 | 15 each |

**Control:** QM5_10681 / GDAXI / Q04 — 6 infra failures, 0 merit verdicts, 0 pending — predicted
invisible, and it is. That is the case that surfaced this: it produced a fresh
`stream_and_selfreport_missing` today and no seal fired.

## What is and is not broken

**Safety holds.** If anything re-queues one of the 803, `refresh_pending` runs at dispatch, the pair
becomes visible, and it is sealed before it can be claimed. Nothing escapes *at the moment it
matters*. As a dispatch guard the design is sound and arguably deliberate — you only need to block
what is about to run.

**Visibility does not hold.** There is no standing record of which pairs are dead. That matters
concretely for Phase 2.2: BUILD-1 must screen the pool for pairs with a never-passed phase, and the
obvious source for "known-bad" is this table — which would answer 184 when the answer is 1,158.

So the precise statement, replacing mine: **`poison_pill_quarantine` is a dispatch-time guard scoped
to queued pairs, not a registry of poisoned pairs.** Item 1.4's closure stands for the stopping-rule
question; it does not license using the table as an inventory.

## A second qualification, of my own 1.6 census

The same scoping error is in my emitter census: I classified only EAs **with queued work**, so an EA
whose broken row has already completed is invisible there too. QM5_10681 is proof — it is
demonstrably broken on GDAXI and absent from my 16-EA requalification set. The 44-row figure is
"queued rows on proven-broken binaries", **not** "all proven-broken pairs", and I should have named
that unit when I published it.

## And a counter-example to the emitter story, recorded rather than explained away

QM5_10681's binary was built **2026-07-14**, *after* the 2026-07-10 magic-0 fix, and it still emits
nothing on GDAXI across five attempts (07-21 ×3, 07-22, 08-17) — while having produced economic
verdicts on NDX. So the magic-0 mechanism is **not the only cause** of a missing stream, and the
cause here is symbol-specific.

This does not weaken the behavioural method — it vindicates it. A build-date rule would have called
QM5_10681 clean (post-fix binary); behaviour correctly calls it broken. **The classifier survives
the counter-example; the causal story needs a second mechanism.**

## Deliberately not done

No change to `scan()`, no seals written, no pairs retired. Widening the scan from pending-only to
all triples would seal 803 pairs in one pass — a large, irreversible-feeling state change that
belongs to a decision, not to a monitoring round. And it may be wrong: sealing a pair that nothing
intends to run costs nothing today and could block a later legitimate requalification.

**What I recommend instead** is a read-only inventory: the same query, materialised as evidence, so
BUILD-1 can screen against 1,158 without changing dispatch behaviour at all.

## Evidence

- `tools/strategy_farm/poison_pill_quarantine.py:108-122` (`scan`), `:191-213` (`refresh_pending`),
  `:21` (`DEFAULT_THRESHOLD = 5`), `:125-138` (`_single_observation_pending`)
- counts above, computed over all `work_items` triples
- control QM5_10681/GDAXI/Q04, and its full history: 5 GDAXI INFRA_FAIL, NDX economic FAIL
- corrects `2026-08-17_the_stopping_rule_already_exists_and_sealed_184_pairs_today.md` (scope) and
  qualifies `2026-08-17_point_1_6_emitter_requalification_is_44_rows_not_640.md` (unit)
