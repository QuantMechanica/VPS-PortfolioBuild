# P2 — Recovery-operator inventory, and the question my catch-up list never asked

## Method: convergence is measurable without reading a scheduler

A fail-closed label that *promises* recovery is worthless until it is known whether the recovery has
ever happened. That is testable from stored verdicts alone: for every `(ea, symbol, phase)` triple
that ever hit a class, **did that triple later obtain a PASS at the same phase?**

57,267 candidate rows since 2026-06-01, grouped by reason token.

## The inventory — with the distinction that makes it readable

Low convergence is only a *finding* for classes that promise recovery. For a deliberate seal or an
economic verdict, 0 % is the intended outcome. Both kinds appear in the table, so both are labelled.

| Class | triples | converged | conv % | reading |
|---|---:|---:|---:|---|
| `summary_missing_retries_exhausted` | 8,054 | 3,522 | 43.7 % | recovery works about half the time; class stopped occurring 07-29 |
| `run_smoke_fail` | 3,298 | 2,032 | 61.6 % | works |
| `G1_NO_REAL_TICKS` | 133 | 123 | **92.5 %** | works well |
| `shared_bases_history_lock_transient_cap_exhausted` | 93 | 57 | 61.3 % | works |
| `LOG_BOMB` | 171 | 89 | 52.0 % | works |
| `ACTIVE_TIMEOUT` | 431 | 151 | 35.0 % | partial |
| `cold_cache_retries_exhausted` | 173 | 58 | 33.5 % | partial |
| `setfile_missing` | 403 | 33 | 8.2 % | the 329-row vacuum, independently confirmed |
| **`poison_pill`** | 183 | 0 | 0 % | **correct — the seal IS the decision** |
| **`F1` / `F2` / `F3`** | 1,350 | 74 | ~5 % | **correct — economic fold verdicts** |
| **`P2_PRESCREEN_run_smoke_fail`** | 4 | 0 | 0 % | **correct — MIN_TRADES economic** |
| **`q08_zero_trade_baseline`** | 7 | **0** | **0 %** | **finding** |
| **`q08_8.5_neighborhood`** | 6 | **0** | **0 %** | **finding** |
| **`q08_degenerate_neighborhood_baseline`** | 4 | **0** | **0 %** | **finding** |
| **`worker_staged_ex5_destination_path_mismatch`** | 7 | **0** | **0 %** | **finding** |

Nine classes have 0 % convergence with ≥2 triples; four of those are genuine findings, the rest are
correct-by-design.

**I am deliberately not reporting the 9,031 total stranded triples as a headline.** That figure mixes
deliberate seals and economic verdicts with real strandings, and quoting it would overstate by an
order of magnitude — the same error I made with the retry slot-hours.

## The Q08.5 neighbourhood is one cluster, not three classes

Three tokens, **15 distinct pairs, and not one has ever passed Q08:**

```
QM5_10440 NDX      LIVE-ROSTER
QM5_13213 USDJPY   Q14-COHORT · LIVE-ROSTER · Q10-PASS
QM5_1567  EURUSD   LIVE-ROSTER · Q10-PASS
QM5_10582/10590/10771×2/10939/11124/11147/11916/1230/12354/1567×2  —
```

**Three live-roster sleeves, two of them holding a Q10 PASS, have never passed Q08.** QM5_13213/USDJPY
is the pair that produced the only challenger ever generated. And `farmctl.py:4272-4278` states the
intent plainly — *"so the stranded-INFRA sweep re-derives instead of counting a strategy fail"* —
which has now been measured across 15 pairs and 4 weeks and has never once occurred.

## The question my catch-up list never asked

My BUILD-0 list asked three questions: does a verdict exist, is its evidence retrievable, was it
produced under today's contract. **It never asked whether the pair actually PASSED.**

Checked across all 36 delivery pairs:

| | |
|---|---:|
| pairs with ≥1 phase they have **never passed** | **34 of 36** |
| gate actions where a gate **ran and never passed** | **42** |
| gate actions with **no row at all** | 13 |

And the 42 split into two kinds that must not be conflated:

- **The gate answered, negatively** — `FAIL_SOFT`, `FAIL_HARD`, `FAIL`, `FAIL_PORTFOLIO`. These are
  *rejections*, not gaps in the record. Five pool pairs sit on `Q09_PORTFOLIO=FAIL_PORTFOLIO`
  (QM5_10123, 10128, 10142, 10145, 10183); four roster sleeves sit on `Q08=FAIL_SOFT/FAIL_HARD`
  (QM5_10513, 10706, 10919, 10939). Whether such a pair belongs in the pool or roster is the
  **FAIL_PORTFOLIO policy question already open with OWNER**, not a re-run.
- **The gate never answered** — `INFRA_FAIL`. That is a genuine gap and belongs in the catch-up:
  QM5_10403 (Q08), QM5_10440 (Q05 + Q08), QM5_10692 (Q05), QM5_10911 (Q05), QM5_10938 (Q05).

**The worst single case: QM5_10440/NDX is in the live 24-sleeve roster with `Q05=INFRA_FAIL`,
`Q08=INFRA_FAIL` and `Q10=FAIL`.** A deployed sleeve that never passed Q05, never passed Q08, and
whose Q10 verdict is a FAIL.

## What this does to the numbers I reported an hour ago

It cuts both ways and I want both directions visible:

- **P1.4 removed 99 actions** (date-only staleness) — the catch-up got cheaper: 110 runs, 10.3 h.
- **P2 adds a class I had not counted** — 42 never-passed gate actions, of which the `INFRA_FAIL`
  subset is real catch-up work and the `FAIL_*` subset is a policy decision.

So the catch-up list is not yet stable, and I am not presenting 10.3 h as final. The right next step
is to fold "never passed, and the reason is infra" into the list and re-cost it, keeping the
negatively-answered gates out as policy. That is arithmetic on data I already have.

## The rule, applied to itself

The new binding rule says a fail-closed label needs a named operator, proven to have run on at least
one case. Applied to the four zero-convergence findings: **none of them has a proven operator.** They
therefore cannot be accepted as backlog, and the four are the first entries in the inventory that
must either get a scheduled trigger or a terminal disposition.

For the two open guard tickets this is now doubly binding — `268d88ed` and `1025125e` were told to
follow the DL-082 §3a taxonomy, and DL-082 §3a is precisely one of the classes measured here at 0 %.
Copying its vocabulary is right; copying its unimplemented recovery path would make them the fifth
and sixth entries on this list.

## Evidence

- `artifacts/recovery_operator_inventory_20260817.json` — all classes, convergence per class, re-runnable
- 57,267 rows since 2026-06-01; convergence = a later PASS at the same phase for the same pair
- `farmctl.py:4272-4278` — DL-082 §3a, the documented-but-unrealised re-derivation
- the 36 delivery pairs from `artifacts/build0_catchup_list_20260817.json`
- related: `2026-08-17_P1_fanout_halves_the_catchup_and_repeats_my_own_error.md`
