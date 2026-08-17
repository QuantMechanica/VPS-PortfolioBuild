# Phase 1.1 — The Q09_NEWS closure has no operator, and closing it for the pool costs 19–36 days

## The closure step, named

`tools/strategy_farm/q09_news_contract.py` is the adjudicator. It emits
`verdict: CONFIG_LOCKED` together with **two locked arms** — `CONTROL_OFF` and `POLICY_ON` — each
carrying a 5-seed set with per-seed `setfile_sha256` and `evidence_sha256`. That is exactly what
`assert_q10_dependency_gate` later demands (`q09_news_arms == 2`, matching `aggregate_sha256`, control
seeds).

## Who calls it: nobody

| Link | State |
|---|---|
| `bind-q09-plan` — makes a Q09_NEWS row executable | **manual `farmctl` subcommand** (`farmctl.py:23054`, `:23439`). `farmctl.py:1155`: *"A Q09_NEWS row becomes executable only after bind-q09-plan writes the complete self-hashed dispatch binding."* |
| the adjudicator that sets `CONFIG_LOCKED` | **no caller anywhere in the codebase.** It has only its own `__main__` / `build_parser` at `q09_news_contract.py:749-763` |
| a scheduled trigger | **none.** The only Q09-adjacent task is `QM_NewsCalendar_Refresh`, which refreshes calendar *data*, not the gate |

So the most expensive gate in the pipeline is gated behind **two manual steps, neither of which anything
invokes.** This is the "fail-closed label without a named operator" class at the worst possible place —
exactly as the brief anticipated.

## The positive control: the one successful closure, reconstructed

`QM5_11422/USDCAD`, work item `44e2c70d`, closed **2026-08-08T07:41:49Z**:

```
contract_version          Q09_NEWS_V2          matrix_scope     7x4
selection  2019-01-01 → 2023-12-31  (60 complete months)
holdout    2024-01-01 → 2025-12-31  (24 complete months)
arms       2                        cells            145
chosen_temporal  OFF                chosen_compliance  DXZ
```

Two things worth noting about the *content* of the success:

- It carries its own **holdout** (60 selection months, 24 held-out) — the discipline Phase 3.7 asks for
  is already implemented inside this contract.
- `chosen_temporal: OFF`. After 145 cells the adjudicator concluded the news filter offers no robust
  improvement for this pair and locked "OFF". That is a legitimate and useful null result — but it means
  145 cells bought the finding *that the filter does not help here*, not a filter configuration.

## The gate has been exercised on exactly one pair, ever

| | |
|---|---:|
| Q09_NEWS work items | **91** |
| distinct pairs with a Q09_NEWS row | **38** |
| **pairs with any adjudication evidence** | **1** |
| `q09_news_tests` rows | 9 — 1 `CONFIG_LOCKED`, 1 `INVALID_EVIDENCE`, 7 `REVIEW_REQUIRED` |
| cells in the whole database | 272 — **all of them QM5_11422/USDCAD** |

And that one pair took **seven attempts** to close: 4 → 18 → 19 → 22 → 24 → 40 → **145** cells.

The other 82 rows produced no adjudication evidence at all:

| Verdict | rows | reading |
|---|---:|---|
| `REVIEW_REQUIRED` | 32 | ran, did not lock, wrote no test row |
| `INFRA_FAIL` | 24 | infrastructure |
| `PENDING_RUNNER` | 18 | **the phase runner did not exist when these ran** |
| (pending) | 8 | the `Q09_AWAITING_SEALED_PLAN` holds |

**So the earlier framing "the dam holds 8 rows" was far too small.** The dam is not 8 held rows; it is
that 37 of 38 pairs have never produced the evidence the Q10 contract requires.

## The cost of closing it for the pool

At the one measured data point:

| Basis | cells for 34 pool pairs | at ~10.7 completions/h |
|---|---:|---:|
| optimistic — first-attempt success at 145 cells | ~4,930 | **~460 h ≈ 19 days** exclusive factory time |
| observed — 272 cells per pair actually closed | ~9,250 | **~865 h ≈ 36 days** |

For scale, everything else currently on the list: the catch-up is **10.8 h**, Z3 is zero. **The Q09_NEWS
arm is one to two orders of magnitude larger than the rest of the delivery work combined**, and it sits
upstream of all of it, because a Q10 verdict cannot be re-earned without it.

I am giving a band rather than a point because n=1. The 145-cell figure is the only successful closure
in existence, and the six failed attempts before it are the only evidence about how often first attempts
succeed — which is zero for one.

## What this makes decision 1 look like

The brief's decision 1 is "Q09_NEWS before the catch-up". On these numbers that framing understates the
choice. The options are:

1. **Close the arm for the pool** — 19–36 days of exclusive factory time, and the one completed instance
   returned `OFF`, i.e. "the news filter does not help this pair". If that generalises, the spend buys
   contract compliance rather than book quality.
2. **Automate the two manual steps first**, then decide the spend. The adjudicator exists and works; it
   has no invoker. Wiring it costs a fraction of one pair's cell budget.
3. **Question the contract.** A Q10 gate that 37 of 38 pairs cannot satisfy, whose satisfaction cost is
   19–36 days, and whose single satisfied instance concluded "OFF", is a candidate for re-scoping rather
   than for a 36-day campaign. That is OWNER's call and I am not proposing it as the answer — only
   noting that it is on the table and that the numbers put it there.

**My recommendation is option 2 first**, because it is cheap, it is a precondition for either other
option, and it converts a manual ceremony into something whose cost can then be measured properly rather
than estimated from n=1.

## 1.2 — the pool split recomputed against both arms

Same predicate reading, applied to the 34 Q10 PASS pairs. The expectation was pre-registered as
"closer to one than sixteen":

| | pairs |
|---|---:|
| **tenable under both arms of the current contract** | **1** — QM5_11422/USDCAD |
| not tenable | **33** |
| undecidable | **0** |

Earlier figure, computed with the **portfolio arm alone**: 16 tenable / 12 not / 6 undecidable. The
"undecidable" bucket disappears entirely, because the news arm is a binary fact — a `CONFIG_LOCKED` row
exists for the pair or it does not.

**And a subtlety that matters more than the count.** QM5_11422/USDCAD's own chronology:

```
Q09_PORTFOLIO  PASS_PORTFOLIO  2026-07-24
Q10            PASS            2026-07-25
Q09_NEWS       CONFIG_LOCKED   2026-08-08   <- fourteen days AFTER its Q10
```

So even the one tenable pair earned its Q10 before its news arm existed; the arm was closed
retrospectively. Which means: **zero of the 34 Q10 PASS verdicts were produced under the contract now in
force.** One of them is re-earnable today; none was originally compliant. That is a cleaner statement of
the same fact and it removes any suggestion that the pool contains a compliant core to build on.

## Deliberately not done

No `bind-q09-plan` run, no adjudication invoked, no hold released. Every one of those is a factory-time
or contract-state commitment, and the point of 1.1 was to price the bottleneck, not to start paying it.

## Evidence

- `q09_news_contract.py:693-712` (the two locked arms), `:749-763` (its only entry point)
- `farmctl.py:1155` (the bind-q09-plan precondition), `:23054`, `:23439` (the manual subcommand)
- `q09_news_tests` — 9 rows, one pair; `q09_news_cells_by_work_item` — 272 cells, one pair
- work item `44e2c70d` (QM5_11422/USDCAD), the single `CONFIG_LOCKED`, with its 7-attempt curve
- 91 Q09_NEWS work items across 38 pairs, split by verdict above
