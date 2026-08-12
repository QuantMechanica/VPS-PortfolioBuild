# The FTMO book answer — does the composed book make passing more likely?

**Date:** 2026-07-28 (live-verified against `farm_state.sqlite`, the source tree, and the
step-2 harvest on `D:`)
**Author:** Claude (board-advisor worktree) — Answer agent
**Goal (OWNER, verbatim):** *"Ziel ist, dass der FTMO Backtest EA endlich gefahren werden
kann und wir sehen, ob er das Bestehen einer Challenge wahrscheinlicher macht!"*
**Binds to:** `2026-07-28_measurement_preregistration.md` (the rules, committed 409a3986b) and
`2026-07-28_multisym_steps23_EXECUTED.md` (the data, committed 843b8aaf7).

---

## Bottom line for OWNER

**The runs did not complete a valid 3-sleeve measurement, so there is no P(pass) number to
report — and inventing one would be dishonest.** The preregistration anticipated this exact
situation and named its outcome in advance: this is the **fourth sentence (D)** —
*"Not answerable from this run; the book measured is not the book that can be deployed."*
Two things stand between NOW and the answer, and the second is deeper than the first:

1. **The 3-sleeve run was never built.** The joint EA source still wires only ONE satellite.
2. **Even the cheap 2-sleeve de-risk that DID run failed its admission gate** — a framework
   design contradiction makes the satellite's trades un-harvestable and, separately, the
   satellite that ran is not the admitted 10145.

One Codex-lane build pass — one file, one recompile — clears both. Nothing about *what the
numbers would have been* is computed below; per the mandate, a stopped chain is reported as a
stop, not a guess.

The one thing that **is** established and in hand: the **runner-alone** anchor (Arm R),
recomputed on the fresh vintage and the truncated common window — **first-passage 85.1%** at
1× (§3). The joint book has **never** been measured for P(pass); every "0.641" it is compared
against is an archived-vintage FUND_SCORE proxy, not a pass rate, and is now known to be
suspect.

---

## 1. The verdict, mapped to the preregistered outcomes

The preregistration (§7) fixed four possible sentences before any scoring. Sentences (A)/(B)/(C)
are only reachable *"if the runs completed and gates admitted."* They did not. The applicable
preregistered outcome is:

> **(D) — "Not answerable from this run; the book measured is not the book that can be
> deployed."** Forced by a §6.2 satellite-fidelity precondition failure
> (`measurement_preregistration.md:356-360`).

This is not the analysis failing. It is the analysis **correctly refusing to launder an
undeployable, unmeasurable book's number into a deployment decision** — the precise reason (D)
was written into the preregistration.

The paired first-passage statistic (§2.7) was never run, because its inputs — the per-slot
substreams for a *faithful, deployable* book — **do not exist** (§2 below). Running the
estimator on what was harvested would score a 2-sleeve account containing an infidelic
satellite, i.e. the book (D) forbids scoring.

---

## 2. Which run/gate stopped the chain, and why

### 2a. Step 3 (the 3-sleeve run) — NEVER BUILT (binary blocker)

The joint binary `QM5_20181_ftmo-joint-multisym-timer.mq5` (mq5 sha **`f102f620…`**,
byte-unchanged since step-1, verified this session) wires exactly one satellite:

- `g_sat_count = s1_enabled ? 1 : 0` (`…mq5:284`); only sleeve fn `QM20181_Run10145` exists;
  **no `Run13108`, no `s2_*` input group** (grep this session: zero hits).

So a 3-sleeve run against the current binary would silently run 2 sleeves. The Codex-lane
slot-2 (13108) build (blocker **B1**) has **not landed** — the newest commit touching the EA
is `59bfb928b` (the isolation/replay repair), and the newest QM5_20181 Q02 work item in
`farm_state.sqlite` is the 2-sleeve step-2 run (`c0192be6…`, done). **No `basket_symbol_count=3`
item exists.** The two pending 20181 items (`50ada76a` Q03, `9ca73d45` Q04, created 13:25Z) are
the automatic single-symbol cascade off the step-2 Q02 pass — **not** a 3-sleeve book.

**Third-member decision, for the record — RESOLVED (was open in the repair doc):** the repair
brief left 13301 as the documented candidate and found "no comparable TIMER-SAFE replacement"
(`2026-07-27_20181_repair.md:51-65`). The **later** docs supersede it:
`goal_blocker_chain.md §B3-decision` and `goal_implementation.md item 3` **decide slot-2 =
13108** (timer-safe, deployable, rank-17 OOS FUND_SCORE 0.527) and reject 13301 as
per-tick-trailing → undeployable. This still needs a **one-line OWNER confirm** before B1
(`goal_blocker_chain.md:230-233`). So the TIMER-SAFE question is answered — 13108 — pending
OWNER's confirmation.

### 2b. Step 2 (the 2-sleeve de-risk) — RAN, then FAILED its admission gate

The 2-sleeve run (`c0192be6…`, USDJPY.DWX Q02, priority-track, staged-EX5 sha `60ee13b7…`
pre==post==required) **completed** — done/PASS, account net 204,018 / PF 1.35, T1,
12:52:59Z→13:16:40Z. The satellite even traded (149 XAUUSD fills). But every admission gate
that matters failed (`multisym_steps23_EXECUTED.md`, table lines 46-52):

| Gate | Criterion | Result |
|---|---|---|
| Satellite **fidelity** (the point of step 2) | satellite ≡ fresh standalone 10145 @ 1.0 | **CANNOT COMPUTE** — satellite un-harvestable |
| Satellite **deployability** | reproduces admitted 10145 | **FAIL** — 34 "Market closed" drops + entry shortfall (149 vs 314) |
| Runner **invariance** | runner unchanged with satellite on | **FAIL — 0.999125** (1 shifted exit, 2020-08-11) |

**Why the satellite is un-harvestable (the decisive, structural cause — `steps23 §3.1`):**
the q08 emitter only keeps deals whose opening magic is *owned* per
`QM_FrameworkOwnsMagicSymbol` (`QM_Common.mqh:400-429`), and that predicate returns true for a
foreign-symbol satellite magic **only in basket mode** (`:414-415`). The joint EA
**deliberately stays out of basket mode** to keep the runner byte-identical (F3), and binds the
satellite magic with `QM_MagicChecked` — which registers **no** `(magic,symbol)` context. So
`QM_FrameworkOwnsMagicSymbol(201810001,"XAUUSD.DWX")` returns **false** → the satellite's
closing deals are excluded → **zero** satellite rows reach the q08 stream. Verified on disk:
the harvest dir holds `step2_runner_…jsonl` (1,143 rows, all magic 201810000) and
`step2_equity_…jsonl` (309k rows) but **no `…_XAUUSD_…` satellite stream at all**.

This is a design contradiction, not a tuning miss:
runner-fidelity-by-avoiding-basket-mode is mutually exclusive with
satellite-harvest-via-ownership as the framework is currently written. The §3.1 fix has **not**
landed in `QM_Common.mqh` (newest commit there is `7dc4751ca`, an unrelated audit bundle).

**Consequence for the preregistration preconditions (§6):** the **§6.2 satellite-fidelity gate
cannot be evaluated** (no satellite stream to compare), and independently the satellite that ran
is **not** the admitted 10145 (§3.2: fixed 01:00 `OnTimer` entry dropped 34 XAUUSD entries as
"Market closed" and fired 149 vs the native 314). Both route to **outcome (D)**.

---

## 3. What IS established vs what is NOT ESTABLISHED

Per the standing evidence rule, each line is tagged with its basis. No inference is promoted to
a result.

### Established (computed, committed, filesystem-anchored)

- **Arm-R anchor — runner-alone first-passage P(pass) = 85.1% at 1×**, on the fresh vintage and
  the preregistered truncated window 2018-07-02..2025-12-31 (all 1,142 starts; 972 pass / 135
  breach / 35 censored; median 52 td; conservative ESS 21; 95% band [69.9, 100.3]).
  OOS-split (from 2022-11-30, 457 starts) 71.8% — brackets the prior archived-vintage 75.3%,
  confirming the estimator is consistent and the gap is *window*, not vintage. Secondary 60/30
  sprint KPI: 3.06% (an OWNER objective, NOT an FTMO rule).
  Basis: `goal_implementation.md item 5`; script
  `tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py` (verified present); fresh
  9936 stream sha `352b9e3e…`. This is the **only** P(pass) number legitimately in hand.
- **Vintage confound retired.** The prop-firm include `f0301ecf` is **NON-CAUSAL** at the q08
  event level (trade-event multiset symdiff = 0 over 8,951 events; the only two stream diffs are
  the news-calendar snapshot). The fresh-vs-archive drift (72 shifted exits + ~25 entry diffs)
  is **archived news-calendar vintage**, not the wrapper. Basis: `goal_implementation.md item 1`,
  `goal_blocker_chain.md §B0`. → The §6.1 precondition is satisfied for the *comparison* (both
  arms would come from one fresh run); it does not rescue §6.2.
- **The true-intraday-equity instrument now works.** Step 2 harvested a per-bar **plus intraday
  lows** account equity stream (`step2_equity_20181_USDJPY_DWX.jsonl`, 309,018 rows, 64.9 MB,
  verified on disk). Earlier pass rates used the per-trade `mae_acct` proxy; the machinery to
  replace it with genuine intraday −5%/day detection is now proven to harvest. (What it cannot
  yet do: answer the bias question — see below.)

### NOT ESTABLISHED (the chain stopped before these; no speculation)

- **Joint-book P(pass) (Arm B), and the paired difference Δ = P(pass|B) − P(pass|R).** Requires
  per-slot substreams for a faithful deployable book. The 3-sleeve run does not exist; the
  2-sleeve run's satellite is un-harvestable and infidelic. **Not computable. Not estimated.**
- **The −5%/day breach count from TRUE intraday equity vs the MAE proxy** — the question that
  decides whether earlier pass rates were biased, and in which direction. The instrument exists
  (above), but the only intraday stream harvested belongs to the **failed 2-sleeve infidelic
  book**, whose satellite is a different strategy than admitted 10145 and whose account P&L is
  therefore not a deployable book's path. Pointing the breach detector at it would answer the
  question for a book that cannot ship. **Direction NOT ESTABLISHED — deferred to the re-run on
  the deployable binary, where runner-alone and the faithful book share one intraday stream.**
- **Realised pairwise sleeve correlations.** Require ≥2 harvestable per-sleeve substreams. Only
  slot-0 was harvestable; slot-1 was not. **Not computable.**
- **FUND_SCORE from the joint equity vs the 0.641 archived-vintage estimate.** The deployable
  timer-safe book is not 0.641 (that was a per-tick standalone-13301 measurement on archived
  streams). The best *deployable* book is rank-17 `9936+10145+13108` at OOS 0.527
  (`runner_satellite_composition.md:35`), and even that is un-measured on a faithful joint run.
  Comparing any harvested number to 0.641 is explicitly forbidden by the preregistration
  (`§5 row a`, `§4a`). **Not computed.**

---

## 4. The single action that resumes the chain

**One Codex-lane build pass on `QM5_20181_ftmo-joint-multisym-timer.mq5` — one file, one
recompile → one new ex5 SHA — clears every blocker at once,** because they are all the same
source (`multisym_steps23_EXECUTED.md §5`, "Recommended next step"). In priority order of leverage:

1. **§3.1 (decisive) — make the satellite harvestable.** Register each satellite's
   `(magic,symbol)` as a framework magic-context at init so `QM_FrameworkOwnsMagicSymbol`
   (`QM_Common.mqh:405-412`) owns it **without** basket mode → the q08 Pass-2 loop emits the
   satellite's (already symbol-tagged) closes; the harvester splits by magic. *Until §3.1 is
   fixed, no multi-symbol joint run can be measured at the per-sleeve level — this is the single
   highest-leverage fix for OWNER's goal.*
2. **§3.2 — reconcile satellite entry with native new-bar detection** (enter on the first open
   tick of the new D1 bar, not a fixed 01:00 `OnTimer` fire) so it stops dropping 34 "Market
   closed" entries and matches admitted 10145's entry count.
3. **B1 — wire slot-2 = 13108** (`s2_*` inputs, `Run13108` sleeve fn, `g_sat_count`→2,
   `eqmagics[2]`), pending the OWNER one-line confirm of 13108 over 13301.
4. (Same pass) §3.3 wire the satellite's FW1 news filter; §2 diagnose/​restore the
   runner-invariance perturbation.

Then this workflow re-runs the (now harvestable) 2-sleeve de-risk **plus** a fresh standalone
10145 reference (its ex5 is 07-14, stale — recompile first), gates satellite + 13108 fidelity in
isolation, confirms the runner is unperturbed, and only then enqueues the 3-sleeve governed
priority-track run and hands the per-magic substreams + the single intraday account equity path
to the paired first-passage estimator (`challenge_firstpassage.py`, verified present). At that
point — and only then — the four numbers OWNER asked for (joint P(pass), the paired Δ against the
85.1% anchor, the true-intraday vs MAE breach delta, and the realised correlations / joint
FUND_SCORE) become computable.

**Blocking OWNER decision (one line):** confirm slot-2 = **13108** (timer-safe, deployable) vs a
conscious decision to measure a non-deployable 13301 variant.

---

## 5. Honest prior (unchanged, and not a substitute for the measurement)

The preregistration's expected outcome, on every independent line, was **(C) indistinguishable**:
the runner alone already carries ~85% first-passage P(pass) at 1× — the only deployable sizing —
and the pool sits 1–2 orders short of challenge-grade edge, so the composed book was expected to
raise the point estimate ~10–15 pp but not resolvably at ESS ~9–21. That remains the prior. It is
**not** the answer. The measurement that would confirm or refute it has not run, and this document
does not pretend otherwise.

---

## Evidence index (all committed / filesystem-verified this session)

- Preregistration outcomes (A/B/C/D), §6.2 precondition, first-passage KPI:
  `docs/ops/evidence/2026-07-28_measurement_preregistration.md:328-360,306-324`
- Step-2 FAIL, un-harvestable root cause, gate table, §5 fix bundle:
  `docs/ops/evidence/2026-07-28_multisym_steps23_EXECUTED.md:16-56,113-165,195-221`
- Runner-alone 85.1% anchor + vintage non-causality:
  `docs/ops/evidence/2026-07-28_goal_implementation.md:34-66,164-205`
- Critical path / slot-2 = 13108 decision:
  `docs/ops/evidence/2026-07-28_goal_blocker_chain.md:33-47,132-159,230-233`
- TIMER-SAFE question origin (superseded): `docs/ops/evidence/2026-07-27_20181_repair.md:51-65`
- Source (this session): `QM5_20181…mq5` mq5 sha `f102f620…`; `…mq5:284` `g_sat_count = s1_enabled ? 1 : 0`;
  no `Run13108`/`s2_*`; framework un-fixed `QM_Common.mqh:400-429,414-415`.
- Farm DB (this session): `farm_state.sqlite` work_items — 20181 Q02 items = `a343f66e` (step-1,
  runner-only, done) + `c0192be6` (step-2, 2-sleeve, done); **no `basket_symbol_count=3` item**;
  pending `50ada76a` (Q03) / `9ca73d45` (Q04) = single-symbol cascade.
- Harvest on disk (this session): `D:/QM/reports/work_items/c0192be6…/harvest_steps23/` —
  `step2_runner_20181_USDJPY_DWX.jsonl` (1,143 rows) + `step2_equity_20181_USDJPY_DWX.jsonl`
  (309k rows, intraday lows); **no satellite stream**.
- Estimators present: `tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py`,
  `tools/strategy_farm/portfolio/challenge_firstpassage.py`.

*No terminal was launched, no work item mutated, no history imported. T5/T_Live untouched. All
state read-only from `farm_state.sqlite` and the tree.*
