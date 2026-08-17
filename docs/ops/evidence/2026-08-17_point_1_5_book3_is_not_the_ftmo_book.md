# Point 1.5 — Book-3 is a measurement instrument, not the FTMO book

Answers the v2 brief's four questions, and corrects a cost figure I published this morning.

---

## The four questions, answered

### Is Book-3 the FTMO book of this delivery? **No.**

`docs/ops/evidence/2026-07-30_ftmo_book3_research_only_runtime_projection.json`:

```
projection_kind   RESEARCH_ONLY_RUNTIME_EVALUATION
book_id           FTMO_BOOK3_STANDALONE_R0_R1_R2
status            RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED
evidence_class    RESEARCH_ONLY_RUNTIME_PROJECTION
```

Its own readiness block settles it:

| check | value |
|---|---|
| input_integrity | PASS |
| native_stream_reconciliation | PASS |
| shared_account_model | COMPLETE_**RESEARCH_ONLY** |
| strict_qualification | **UNVERIFIED** |
| money_gate | **SETUP_DATA_MISSING** |
| **paid_challenge** | **NO_GO** |

Book-3 declares itself not a tradeable book. It is the apparatus that proves the *measurement* can
be trusted.

### Are three symbols a decision belonging in the target spec? **No — they are not sleeves.**

They are **rungs of the fidelity ladder**, one native (EA, symbol) run each:

| rung | EA | symbol | trades | lifecycle mismatches | reconciliation |
|---|---|---|---:|---:|---|
| R0 | 9936 | USDJPY.DWX | 1,143 | **0** | PASS |
| R1 | 10145 | XAUUSD.DWX | 291 | **0** | PASS |
| R2 | 13108 | XTIUSD.DWX | 548 | **0** | PASS |

Three rungs, ascending, chosen to exercise the reconciliation across different instruments and trade
counts — not a portfolio-size decision. **There is no "3-symbol FTMO book" to ratify.**

### Do Book-1 and Book-2 exist? **No.**

No `BOOK1`/`BOOK2` artifact exists anywhere in `tools/` or `docs/`; the only grep hits are incidental
substrings inside unrelated filenames (`ftmo_density_compare`, `gen_dxz24_*`). "Book-3" is not the
third of a series — the numeral belongs to the R0/R1/R2 construction, not to a sequence of books.

### What is the fidelity ladder? **A measurement-fidelity contract, not a composition method.**

`tools/strategy_farm/ftmo_book3_fidelity_gate.py`:

```
MEASUREMENT_CONTRACT       FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET
FULL_LIFECYCLE_MONEY_BASIS FULL_POSITION_LIFECYCLE_ACTUAL_V1
MONEY_TOLERANCE   0.005      VOLUME_TOLERANCE  0.005
EXPECTED_EXECUTION_INPUT_COUNT 307
```

with 11 `SUCCESS_CHECK_KEYS` and 12 `RUNTIME_SOURCE_ROLES`. It proves that an **isolated** re-run
reproduces the **joint** run's money and volume to within half a cent, with the execution inputs and
runtime sources provably unchanged.

That is genuinely valuable and directly serves Phase 3: it is the guarantee that a book's simulated
P&L means what it says. **All three rungs reconcile with 0 lifecycle mismatches**, so the instrument
works.

---

## What this changes

### 1 · The FTMO book does not exist yet, in any form

Not as a roster, not as a candidate, not as a 3-symbol draft. What exists is: a target rulepack
(research contract), a fidelity instrument that works, and zero selected sleeves. **The FTMO book is
entirely Phase 3.2 output.** Phase 3.1 is unblocked by this answer — the cost model can proceed —
but it now has no pre-existing book to cost.

### 2 · I must withdraw a number from this morning's 1.1 paper

I wrote that Q09 closure "book-scoped" costs **~1 day at 5-way concurrency**, on the premise that
Book-3's three symbols might be the FTMO book. **That premise is false**, so the figure has no
basis and I am withdrawing it.

What survives from that paper is the part that did not depend on the premise: the pool-scoped cost
is **~12 days at 5-way concurrency**, not 19–36 serial, and cost scales with **book size**. But book
size is now an **open output of 3.2**, not a known 3. The honest statement is:

> Q09 closure costs roughly **43 h of work-item time per pair**, divided by achieved concurrency.
> The number of pairs is unknown until BUILD-4 selects a roster.

### 3 · A live inconsistency between the target rules and the gate that enforces them

The rulepack `FTMO_2S_100K_SWING_V1` — target `FTMO Challenge 2-Step / USD 100000 / **Swing**`,
sourced to FTMO's own FAQ pages, retrieved 2026-07-29 and hashed — encodes:

```
rule_id  ftmo_swing_news
"News restrictions do not apply during Evaluation and the published selected-news
 restriction does not apply to Swing FTMO Accounts."
evaluation_restricted: false      ftmo_account_swing_restricted: false

rule_id  ftmo_swing_weekend
"Overnight and weekend holding restrictions do not apply during Evaluation or to
 Swing FTMO Accounts."
```

Meanwhile `portfolio/ftmo_q09_admission.py` is fail-closed on news evidence across five surfaces and
contains **no reference** to the rulepack, to `swing`, or to `evaluation_restricted`. It is blind to
the target's actual rules.

**So on two independent grounds — Phase 1 *is* the Evaluation, and the account *is* Swing — the
news restriction does not apply to this delivery's target, while the gate that enforces news
evidence does not know that.**

This qualifies the strongest argument in my 1.1 paper. I weighted option A heavily on prop-firm
safety, quoting OWNER's binding 2026-08-04 semantics ("Handel direkt zur News verletzt
FTMO-Regeln"). That statement is correct in general and I am not second-guessing it — but for the
*named target* the rulepack says the restriction is inapplicable, and the rulepack carries official
provider sources while my argument carried a general principle.

**Three things keep this from being a simple "so drop the gate":**

1. The rulepack is `lifecycle_status: RESEARCH_CONTRACT_ONLY` — it is not ratified as the binding
   target spec.
2. The gate is fail-closed *today* and blocks 33 of 34 pairs regardless of whether the underlying
   rule applies. Operationally it binds whatever the rulepack says.
3. The news arm's **second** leg — does the EA perform better or worse on news days — is a quality
   question that Swing status does not touch at all.

**This is a decision for OWNER and it is narrow:** should `ftmo_q09_admission` consult the target
rulepack, so that a Swing/Evaluation target relaxes the *safety* leg while keeping the *edge* leg?
That is not the same as options A/B/C — it is a fourth path that neither the brief nor my paper had,
and it is the cheapest of all if the rulepack is ratified.

I am not implementing it. Wiring a gate to a research-only contract would be exactly the
"unreviewed change into the verdict" failure.

---

## What I deliberately did not do

No change to the admission gate, the rulepack's lifecycle status, or any Book-3 artifact. No
re-costing of Q09 beyond withdrawing the unsupported figure — the replacement number needs 3.2's
roster size, which does not exist.

## Evidence

- `docs/ops/evidence/2026-07-30_ftmo_book3_research_only_runtime_projection.json` — projection kind,
  book_id, readiness block, three rungs with reconciliation
- `tools/strategy_farm/ftmo_book3_fidelity_gate.py` — measurement contract, tolerances, check keys
- `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json` — `ftmo_swing_news`,
  `ftmo_swing_weekend`, official sources with retrieval timestamps and snapshot hash
- `tools/strategy_farm/portfolio/ftmo_q09_admission.py` — no rulepack/swing reference
- absence check: no `BOOK1`/`BOOK2` artifact in `tools/` or `docs/`
- corrects `docs/ops/evidence/2026-08-17_point_1_1_q09_news_decision_paper.md` §3 (the book-scoped
  ~1 day figure) and qualifies its §5 recommendation
