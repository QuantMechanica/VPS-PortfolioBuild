# Point 1.1 — Q09_NEWS decision paper

Completes the v2 brief's §5 1.1: per-option time to the FTMO book, and the precise answer to
"what statement about the strategies is lost under B and C".

Three things changed while completing it. All three make option A cheaper and options B and C
narrower than the brief assumed.

---

## 1 · What the news arm actually proves

Not a quality question. **A rule-compliance question.** OWNER, binding, 2026-08-04:

> Das Q09_NEWS-Gate liefert durch verschiedene Backtests EMPFEHLUNGEN: (1) **Ist der EA
> Prop-Firm-sicher?** (z. B. Handel direkt zur News verletzt FTMO-Regeln.) (2) Funktioniert er an
> News-Tagen besser oder schlechter? … **nicht FTMO-safe → kommt NICHT ins FTMO-Portfolio**;
> handelt an News-Tagen schlechter → News-Tage werden blockiert.

Verified in current code, not taken from the note:

| Claim | Verification |
|---|---|
| a dedicated FTMO admission contract exists | `tools/strategy_farm/portfolio/ftmo_q09_admission.py` |
| it is fail-closed across five surfaces | consumed by `ftmo_qualification`, `ftmo_book_readiness`, `ftmo_timebox_eval`, `ftmo_book3_standalone_evaluator`, `make_challenge_setfiles` |
| absence = exclusion | base result is `{"admitted": False, reason_code: FTMO_Q09_EVIDENCE_MISSING}` |
| a DXZ-scoped lock is not automatically enough | reason code `FTMO_Q09_SCOPE_NOT_FTMO` exists |

So the news arm is the **only** mechanism that establishes whether an EA trades directly into news.
That is an FTMO rule violation, not a performance preference. **This is the answer to "what is lost
under B and C", and it is heavier than the v1 framing suggested.**

---

## 2 · The finding that reshapes the options: the two gates are independent

`assert_q10_dependency_gate` (the Q10 contract) and `ftmo_q09_admission` are **separate machines**:

- `q09_news_schema.py` contains **no** reference to `ftmo`
- `ftmo_q09_admission.py` contains **no** reference to `Q10`, `PASS_PORTFOLIO` or `Q09_PORTFOLIO`;
  it reads only `work_items`, `q09_news_tests` and the cell relation

**Consequence, and it is the decisive one for this decision:**

> Options B and C loosen or remove the **Q10 dependency contract**. That frees the **DZ** chain.
> It does **not** touch FTMO admission. The FTMO book still requires Q09_NEWS evidence per sleeve
> under either option.

So B and C are **DZ-side decisions**. Neither shortens the path to the FTMO book by a single day.
Making the FTMO book faster via B or C would require *additionally* disabling
`ftmo_q09_admission` — a separate, larger decision that discards the prop-firm-safety semantics
OWNER ratified on 08-04, and one nobody has yet proposed.

### One correction to my own expectation

I expected the single DXZ-scoped lock to fail FTMO admission with `SCOPE_NOT_FTMO`. **It does not.**
Running the real gate:

```
QM5_11422/USDCAD.DWX -> admitted=True  reason=FTMO_Q09_ADMITTED
source_target_compliance=DXZ   deployment_compliance=FTMO
```

The module's second admission path applies: a complete **7x4** matrix contains a viable FTMO
configuration. The cell table confirms both compliance families are populated — `NONE` 40,
`FTMO` 35, `DXZ` 35, `5ERS` 35. **So one 7x4 run buys DXZ and FTMO compliance together. There is no
separate FTMO surcharge.** That is a materially better characterisation of option A than the brief's.

Pool result from the real gate, not a proxy: **1 of 34 FTMO-admissible, 33 `FTMO_Q09_EVIDENCE_MISSING`.**
Same single pair as the DXZ arm.

---

## 3 · The cost model, rebuilt — the brief's 19–36 days assumed serial execution

**I must withdraw my own figure.** The 19–36 days came from a cells/hour rate, and that rate is not
substantiable: `q09_news_cells.created_at` is **identical within each work item**, i.e. write-time,
not compute-time. No throughput can be derived from it.

Two further corrections to numbers I reported earlier:

| I said | Actual |
|---|---|
| the closure took **145 cells** | **86** (`44e2c70d`). 145 is the total across all five cell-producing attempts (19+21+13+6+86) |
| **7 attempts** | **11 work items** for QM5_11422: 1 `PENDING_RUNNER`, 7 `REVIEW_REQUIRED`, 1 `INFRA_FAIL`, 1 `INVALID_EVIDENCE`, 1 `CONFIG_LOCKED` |

### The defensible unit, measured

83 terminal Q09_NEWS work items:

| | hours |
|---|---:|
| median | **2.4** |
| p90 | 32.0 |
| max | 42.2 |
| **the one `CONFIG_LOCKED`** | **28.6** |
| `REVIEW_REQUIRED` median (fails fast) | 7.2 |
| `INFRA_FAIL` median | 16.6 |

The successful adjudication is the long one because it actually ran 86 cells; most attempts are
short because they fail fast.

### And the variable the brief omitted entirely: parallelism

Q09_NEWS rows are **ordinary claimable work items**. Measured: they have run on **nine terminals**
(T1–T6, T8, T9, T10), there is **no Q09-specific concurrency cap** in the claim path, and the
observed **peak was 22 simultaneous Q09_NEWS rows in flight**.

Calendar cost for the remaining 33 pairs, unit = one long closure (28.6 h) plus two fast failures
(~7.2 h each) ≈ **43 h of work-item time per pair**:

| parallelism | 33 pairs | 12 sleeves | 8 sleeves | 3 sleeves |
|---|---:|---:|---:|---:|
| serial (the brief's implicit assumption) | **59 d** | 21 d | 14 d | 5.4 d |
| 5 concurrent | **11.8 d** | 4.3 d | 2.9 d | 1.1 d |
| 10 concurrent | **5.9 d** | 2.2 d | 1.4 d | 0.5 d |
| 22 concurrent (observed peak) | **2.7 d** | 1.0 d | 0.7 d | 0.2 d |

**Two levers the brief did not price, and together they are worth an order of magnitude:**

1. **Parallelism.** 19–36 days was a serial estimate. At 5-way concurrency the whole pool is ~12
   days; at the concurrency this workload has actually demonstrated, under 3.
2. **Scope.** The FTMO book needs its **own sleeves**, not the whole pool. If Book-3's three symbols
   are the book (1.5, still open), closure costs **~1 day at 5-way concurrency**, not 19–36.

Honest caveat, stated because it is the weakest link: **n = 1 for a successful closure**, and that
one ran during three documented rounds of infrastructure repair. Whether a clean repeat is faster or
slower is unmeasured. The 43 h/pair unit is an estimate built from 83 duration observations but only
one success.

Opportunity cost is real but is a **throughput share, not an exclusive lock**: Q09 rows compete with
Q02–Q08 for the same ten terminals. Running 5-way means roughly half the factory on Q09.

---

## 4 · The options, completed

| | A — wire it up and pay | B — loosen the contract | C — abolish the contract |
|---|---|---|---|
| **Time to FTMO book** | pool: **~12 d @5-way** (2.7 d @22-way, 59 d serial). Book-sized: **~1–4 d** | **unchanged** — FTMO admission is a separate gate | **unchanged**, same reason |
| **Time to DZ v1** | already delivered | already delivered | already delivered |
| **Time to DZ v2** | unblocks Q10 for the pool | unblocks it sooner, cheaper | unblocks it immediately |
| **What you get** | both books contract-compliant from one 7x4 run per pair | 34 pairs can earn Q10 for the DZ chain | same, permanently |
| **What is lost** | 19–36 d → **corrected to ~12 d at 5-way, ~1–4 d if book-scoped** | **the prop-firm-safety determination** for the DZ chain's own records; FTMO keeps its gate | the same, permanently, **plus the ability to ever measure it** |
| **Risk** | n=1 on the success rate | the DZ book stops carrying news-behaviour evidence | an FTMO sleeve could trade into news undetected **if** the admission gate is later disabled too |

### The question the brief asked me to answer first

*What should the news arm prove?* It should prove **two** things, and they are not the same:

1. **Prop-firm safety** — does this EA trade directly into news? A rule question with a binary
   answer and real money consequences. **This is not optional for FTMO and is enforced independently
   of Q10.**
2. **News-day edge** — does it perform better or worse on news days? A quality question. The single
   completed adjudication answered `chosen_temporal: OFF` — the no-robust-improvement fallback.

The `OFF` result is evidence about **(2)**, not about (1). At n = 1 it hints the *filter* adds
nothing for that pair; it says nothing about whether the pair is *safe*. **Conflating the two would
be the mistake here**, and my v1 framing ("the gate finds nothing") did conflate them.

---

## 5 · Recommendation

**A, scoped to the book rather than the pool, with the automation wired first.**

Reasoning, in order of weight:

1. **B and C do not buy what this delivery needs.** The goal is an FTMO book at P(pass) ≥ 80 %.
   Neither option shortens that path by a day, because FTMO admission is independent. They are
   worth considering on their own DZ merits — but not as a way to reach the FTMO book faster.
2. **A is roughly an order of magnitude cheaper than stated** once parallelism and book-scoping are
   priced: ~1–4 days for a book-sized set, not 19–36 for the pool.
3. **Wiring the adjudicator is cheap and compatible with all three options** — even abolishing a
   contract is better done knowing what it costs. `q09_news_contract.py` works; it has no caller.
4. **One 7x4 run serves both books**, so the spend is not FTMO-specific overhead.

**What I am not deciding:** whether the contract *should* bind Q10 for the DZ chain. That is a real
question — 33 of 34 pairs cannot satisfy it today and the one that can took 11 attempts — but it is
OWNER's, and after this analysis it is a *DZ* question, not the FTMO blocker it appeared to be.

**Blocked on 1.5:** the book-scoped cost cannot be finalised until Book-3's status is settled — is
it this delivery's FTMO book, and are three symbols a decision? That question now carries a price
tag: it is the difference between ~1 day and ~12.

---

## Evidence

- `tools/strategy_farm/portfolio/ftmo_q09_admission.py` — docstring, reason codes, five consumers
- independence: `q09_news_schema.py` has no `ftmo` reference; `ftmo_q09_admission.py` has no `Q10`,
  `PASS_PORTFOLIO` or `Q09_PORTFOLIO` reference
- live gate run over the 34-pair pool: 1 `FTMO_Q09_ADMITTED`, 33 `FTMO_Q09_EVIDENCE_MISSING`
- positive control: QM5_11422/USDCAD returns `admitted=True`, `source_target_compliance=DXZ`,
  `deployment_compliance=FTMO`
- 83 terminal Q09_NEWS work items with durations; peak 22 concurrent; 9 terminals; no phase cap
- cell relations reconciled: `q09_news_cells` 145 rows across 5 work items (closure = 86);
  `q09_news_cells_by_work_item` view = 272; `q09_news_cell_occurrences` = 253
- compliance families in cells: NONE 40, FTMO 35, DXZ 35, 5ERS 35
- OWNER semantics 2026-08-04, verified against the code above rather than relied on
