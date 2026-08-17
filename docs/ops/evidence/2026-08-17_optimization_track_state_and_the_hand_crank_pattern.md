# The optimisation track works end-to-end — it ran once, on 9 of 34 survivors (2026-08-17)

OWNER, 2026-08-17: *"Die Optimierungsgates sind zudem noch gar nicht gelaufen … diese EAs
müssen sich ja auch wiederum durch die Pipeline beweisen."*

The second half is exactly right and is already enforced. The first half needs one
correction, and it is good news: **the track has run, and its one challenger went the whole
way through the pipeline and was judged on merit.** What is missing is not machinery — it is
throughput and an operator.

## Measured state

| Phase | Rows | Verdicts |
|---|---:|---|
| Q10 | 41 | 40 `PASS`, 1 `FAIL` |
| **Q14** (opt admission) | **14** | 11 `OPT_ELIGIBLE`, 3 `OPT_REJECTED` |
| **Q15** (challenger freeze) | **1** | 1 `CHALLENGER_SPAWNED` |
| **Q16** (swap evaluation) | **0** | — |
| Q11 / Q12 / Q13 | 0 | — |

**Every Q14 row carries the timestamp 2026-08-13 04:49.** One batch, then nothing. Q15 fired
once on 2026-08-14 08:05. There has been no optimisation activity since.

## Q14 covered 9 of 34 survivor pairs — by design, not by oversight

**Correction to my first reading.** Q14 does not sweep the survivor pool. `enqueue-opt-admission`
reports `frozen_cohort_pairs: 9` against `source_q10_pass_pairs: 34`, and the cohort is an
explicit hand-authored `cohort_freeze` list in
`tools/strategy_farm/config/opt_program.v1.json`, bound to `program_id
SURVIVOR_OPTIMIZATION_2026-08-12_V1` and a `q10_snapshot_sha256`. The 25 other pairs were
never *skipped* — they are outside a deliberately frozen cohort. Extending to them is a
**programme decision**, not a gap to fill, and it requires new config authorship (below).

Of the 34 `(EA, symbol)` pairs holding a Q10 `PASS`, **9 are in the frozen cohort and 25 are
outside it**:

**Assessed (9):** `QM5_10128`/XAUUSD, `QM5_10145`/XAUUSD, `QM5_10183`/XAUUSD,
`QM5_10692`/NDX, `QM5_10706`/GBPUSD, `QM5_10911`/GDAXI, `QM5_11422`/USDCAD,
`QM5_13213`/USDJPY, `QM5_13301`/GDAXI

**Outside the frozen cohort (25):** `QM5_10123`/XAUUSD, `QM5_10142`/SP500, `QM5_10403`/XAUUSD,
`QM5_10513`/XAUUSD, `QM5_10919`/XTIUSD, `QM5_10938`/GDAXI, `QM5_10939`/GBPUSD,
`QM5_11132`/SP500, `QM5_11165`/AUDCAD, `QM5_11165`/EURUSD, `QM5_11421`/AUDUSD,
`QM5_11421`/EURUSD, `QM5_11708`/EURUSD, `QM5_12567`/XAUUSD, `QM5_12778`/AUDUSD,
`QM5_12969`/USDJPY, `QM5_12989`/XAUUSD, `QM5_13013`/NDX, `QM5_13036`/GDAXI,
`QM5_13117`/EURGBP, `QM5_13128`/NDX, `QM5_1328`/EURJPY, `QM5_1556`/XAUUSD,
`QM5_1567`/EURUSD, `QM5_20048`/XTIUSD

The three rejections are worth noting because they are the gate working as intended:
`QM5_10128`, `QM5_10145` and `QM5_10183` were all rejected `MAX_DRAWDOWN_BELOW_12` — turned
away **for already being good enough to leave alone**. Optimisation effort is reserved for
survivors with room to improve, not spent on the cleanest ones.

Eligibility came on two criteria, and five EAs qualified on both: `TRADES_GTE_60` and
`TRADES_GTE_150_AND_MAX_DRAWDOWN_GTE_12`. `QM5_11422`/USDCAD qualified on the first only.

## The one challenger proved itself, and failed honestly

Q15 spawned `QM5_21001` from `QM5_13213`/USDJPY under opt card
`OPT-13213-USDJPY-EXIT-SURGERY-1e2bb8e4c42f21f7`, lane `DEVELOPMENT_NO_TERMINAL`, trial
ledger `D:\QM\reports\opt_track\OPT-13213-USDJPY-EXIT-SURGERY-1e2bb8e4c42f21f7\trial_ledger.json`.

It then ran the full pipeline like any other candidate:

| Phase | Verdict | When |
|---|---|---|
| Q15 | CHALLENGER_SPAWNED | 08-14 08:05 |
| Q02 | INFRA_FAIL, then **PASS** | 08-15 21:51 / 22:39 |
| Q03 | PASS | 08-16 04:27 |
| Q04 | PASS_SOFT (×2) | 08-16 04:19 / 04:52 |
| Q05 | PASS (×2) | 08-16 05:31 / 05:57 |
| **Q06** | **FAIL (×2)** | 08-16 06:35 / 06:53 |

**This is the requirement OWNER named, already satisfied: the optimised EA had to prove
itself through the pipeline, and it did not survive.** No swap was offered, which is why Q16
is empty — correctly so. The challenger-swap discipline (evaluate at Q09, never auto-swap)
was never reached because the candidate died four gates earlier.

That single case is the most valuable thing in the track: it demonstrates the loop
end-to-end — admit → spawn → build → full pipeline → merit verdict — with no shortcut and no
special pleading. **The machinery is proven. It has simply been used once.**

Ten further `OPT_ELIGIBLE` rows across five EAs (`QM5_10692`, `QM5_10706`, `QM5_10911`,
`QM5_13213`, `QM5_13301`) have **no Q15 row at all**. Nothing spawned them.

## The survivor pool that feeds Q14 is itself frozen

Every Q10 `PASS` is dated **2026-07-25 or 07-26**. Nothing has reached Q10 in three weeks,
because Q09_NEWS has produced zero completions since 2026-08-07 (see
`2026-08-17_q09_news_gate_dammed_since_08-07.md`). So even a fully-staffed Q14 would be
re-assessing the same 34 pairs — **the optimisation track cannot grow until the Q09 dam is
cleared.** That ordering matters for how the construction site is sequenced.

## The pattern this is the third instance of

Three independent findings today, one shape:

| Gate / tool | Built | Last ran | Backlog behind it |
|---|---|---|---|
| Q09_NEWS plan binding (`bind-q09-plan`) | hand CLI, no caller | 2026-08-07 | 8 rows, oldest 11 days |
| Stranded-infra recovery (`requeue_stranded_infra.py`) | 2026-07-25, unscheduled | never past assessment | 1,562 pairs, +57% at Q04 in 3 weeks |
| Q14/Q15 optimisation admission | `farmctl enqueue-opt-admission` exists | 2026-08-13 / 08-14, once | 10 unspawned eligibles (the 25 non-cohort pairs are a programme decision, not a backlog) |

**The automated core Q02–Q08 is well-wired and drains reliably** — Q04 clears its queue in
0.7 days, Q02 in 5.3, and 165 Q02 rows completed in the last 24 hours. **Every gate outside
that core is hand-cranked**, and each one stalls the moment attention moves elsewhere. None
of them fails loudly: rows behind a fail-closed hold, or pairs with no successor row at all,
look identical to an empty queue on every surface.

That is the structural answer to where the next investment belongs. It is not more gate
logic — the gates are built and correct. It is **scheduling and absence-alarming for the
gates that already exist.**

## Recommended sequencing for the optimisation construction site

1. **Clear the Q09 dam first** (task `65cc2c1c`). Until Q10 grows, Q14 has nothing new to
   assess and the whole track re-examines the same 34 pairs.
2. **Expanding the cohort beyond 9 is strategy work, and it is mine, not Codex's.** The
   programme is not a parameter sweep. Each `cohort_freeze` entry names a lever *and states a
   falsifiable mechanism in prose*, e.g. for `QM5_13213`/USDJPY under `EXIT_SURGERY`:
   *"Extending the fixed same-day exit by one or two hours captures breakout continuation
   without changing the GMT range anchor or stop logic."* Four levers exist —
   `EXIT_SURGERY`, `VOL_REGIME_FILTER`, `LOCKED_PORT`, `MTF_ENTRY` — and six of the seven
   surface profiles are **EA-specific** (`exit_10692_hold_bars`, `exit_10706_friday_hour`, …),
   with only `vol_prior_d1_atr_ratio` generic. So each new pair needs its mechanics read, a
   lever chosen, a surface profile authored and a hypothesis written that can be wrong. That
   cannot be batch-automated and should not be: it is exactly the discipline that separates
   this from curve-fitting. Admission itself is then cheap — an evidence read, no terminal
   cost.
3. **Spawn the 10 outstanding `OPT_ELIGIBLE` challengers,** staged, not all at once: each
   becomes a full pipeline run from Q02, and the queue already holds 1,000 pending rows.
   `QM5_21001` is the template and its Q06 failure is the honest baseline expectation — most
   challengers should be expected to lose.
4. **Do not weaken any gate for challengers.** `QM5_21001` shows the design works precisely
   because it was not spared. An optimised variant that cannot clear Q06 is not an
   improvement, whatever its in-sample trial ledger says.
5. **Schedule and alarm all three of the hand-cranked gates above.** The measured cost of not
   doing so is in the table: three weeks of frozen survivors, eleven days of dammed Q09, and
   a stranded-infra backlog that grew by more than half.

## Evidence

- `D:\QM\strategy_farm\state\farm_state.sqlite` — phase/verdict counts and per-row timestamps
- `D:\QM\reports\opt_track\OPT-13213-USDJPY-EXIT-SURGERY-1e2bb8e4c42f21f7\trial_ledger.json`
- Admission path: `farmctl.py` subcommand `enqueue-opt-admission`
- Programme design: survivor-optimisation v1.1 + DL-084 (Q14 → Q15 → Q16 → Q11 dual-book)
- Related: `2026-08-17_q09_news_gate_dammed_since_08-07.md`,
  `2026-08-17_stranded_infra_recovery_wave1.md`, `2026-08-17_pending_binding_drift.md`
