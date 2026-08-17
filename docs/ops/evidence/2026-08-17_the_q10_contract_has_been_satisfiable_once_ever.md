# The Q10 contract has been satisfiable exactly once, ever — and my "5 re-derivations" were 1

## What I was told to do, and why I did not do it

The directive was explicit: *"Die 5 Re-Derivationen kosten keine Fabrikzeit und können sofort
erledigt werden — das ist der Teil, der keine Entscheidung braucht."*

Before mutating anything I read the contract those re-derivations were meant to satisfy. **Four of
the five cannot be satisfied by arithmetic, and doing it anyway would have forged a contract
satisfaction the evidence does not support.** So I performed none of them and corrected the number
instead.

## My classification tested one arm of a two-arm contract

`assert_q10_dependency_gate` — `q09_news_schema.py:1307-1344` — requires **both**:

1. a `Q09_PORTFOLIO` dependency whose work item verdict is `PASS_PORTFOLIO`, **and**
2. a `Q09_NEWS` dependency whose `q09_news_tests` row is **`CONFIG_LOCKED`**, whose
   `aggregate_sha256` matches the stored `parent_evidence_sha256`, with **exactly 2 rows** in
   `q09_news_arms` and control seeds present.

My P1.4 fan-out tested only condition 1. Measured against both:

| Pair | Q09_PORTFOLIO | Q09_NEWS | `CONFIG_LOCKED`? | arms | re-derivable |
|---|---|---|---|---:|---|
| **QM5_11422 / USDCAD** | PASS_PORTFOLIO | CONFIG_LOCKED | **yes** | **2** | **yes** |
| QM5_10440 / NDX | PASS_PORTFOLIO | INFRA_FAIL | no test row | 0 | no |
| QM5_10692 / NDX | PASS_PORTFOLIO | PENDING_RUNNER | no test row | 0 | no |
| QM5_12969 / USDJPY | PASS_PORTFOLIO | **no row at all** | — | — | no |
| QM5_1567 / EURUSD | PASS_PORTFOLIO | **no row at all** | — | — | no |

**1 of 5.** The other four need a Q09_NEWS arm that does not exist — which is a *run*, behind the
Q09_NEWS dam, not arithmetic.

## The wider finding, which is the real one

While checking the context:

| | |
|---|---:|
| `q09_news_tests` rows with `CONFIG_LOCKED` **in the entire database** | **1** |
| Q09_NEWS work items, `done` | 59 |
| Q09_NEWS work items, `pending` | 8 |
| active `Q09_AWAITING_SEALED_PLAN` holds | 8 |

**The Q09_NEWS arm has been completed exactly once, ever.** 59 Q09_NEWS runs have finished and
produced one locked configuration between them.

Since Q10 requires a `CONFIG_LOCKED` news arm, it follows that **the Q10 contract in force since
2026-07-29 can currently be satisfied by exactly one pair farm-wide** — QM5_11422/USDCAD.

That is a much stronger statement than "the dam holds 8 rows", and it sharpens the earlier finding
that 34 of 36 delivery pairs have a never-passed phase. Every Q10 PASS in the 34-pair pool predates
the contract, and **none of them except QM5_11422 could be re-executed under it today.** Not because
their strategies are weak, but because the arm the contract depends on has essentially never run to
completion.

## Why this matters for the two books rather than as bookkeeping

The pool feeding both builders is 34 pairs of Q10 PASS verdicts. Under today's contract:

- 33 of them could not be re-earned right now even with unlimited factory time, because the Q09_NEWS
  arm cannot be produced for them.
- The catch-up list's 116 runs do not fix this. A Q10 re-run would hit the same gate.
- So "make the delivery chain current" is **not** achievable by running backtests. It requires the
  Q09_NEWS arm to work first.

That reorders the dependency: **Q09_NEWS is upstream of the entire catch-up**, not a parallel item on
the remainder list where it has been sitting since 2026-08-07.

## What I changed and what I did not

**Changed:** `artifacts/build0_catchup_fanout_20260817.json` now carries the correction — re-derivable
5 → 1, with the four moved to blocked-behind-the-dam and the per-pair measurements recorded.

**Not changed:** no `work_item_dependencies` rows were written. For the four without a news arm that
would be forgery. For QM5_11422 the evidence does support it, but a single row is worth less than the
correct number, and I would rather the binder that owns this contract create it than hand-write a
dependency for a historical row — `bind-q09-plan` is the tool that seals these, and it should be the
one to do it.

## The pattern in my own errors, stated once

This is the third time today a number of mine was too confident because I tested a sufficient
condition rather than the actual predicate:

1. `ea_metrics` "overwrites" — I read `rows[-3:]` instead of querying by id.
2. 214 catch-up actions — I treated a date as staleness for phases the contract never touched.
3. These five — I tested the portfolio arm and not the news arm.

All three were caught by reading the code that defines the predicate rather than reasoning about what
it probably does. That is the habit worth keeping, and the cost of not having it is that the number
reaches a plan before it is right.

## Evidence

- `q09_news_schema.py:1307-1344` — `assert_q10_dependency_gate`, both arms and all sub-conditions
- `farmctl.py:6794-6800` — the Q10 dispatch call site that enforces it
- per-pair measurement of all five, plus the farm-wide `CONFIG_LOCKED` count of 1
- `artifacts/build0_catchup_fanout_20260817.json` — corrected in place
- related: `2026-08-17_P1_fanout_halves_the_catchup_and_repeats_my_own_error.md`,
  `2026-08-17_q09_news_gate_dammed_since_08-07.md`
