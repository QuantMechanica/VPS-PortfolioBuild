# Measurement preregistration — does the composed FTMO book make passing more likely?

**Date:** 2026-07-28
**Author:** Claude (board-advisor worktree)
**Binds:** the Answer agent that will compose the joint QM5_20181 run into a P(pass)
verdict. Every rule below is fixed **before** any equity path is scored. Nothing in the
verdict logic (§7) may be chosen after seeing results.
**Status:** preregistration. Written before terminal hours are spent, precisely to
decide whether they should be.

The one question OWNER gets answered, verbatim: *"ob er das Bestehen einer Challenge
wahrscheinlicher macht"* — does the composed book make passing an FTMO Challenge more
probable than the runner alone.

---

## 0. Bottom line up front (read before reserving a terminal)

**The question is answerable in direction, not in magnitude, and only under one design.**

1. **The KPI is contested and the contest changes the answer.** FTMO removed the maximum
   trading period in 2024 (Codex-verified against ftmo.com, task `9b7c6aaf`;
   `docs/ops/evidence/2026-07-27_ftmo_first_passage_measurement.md:14-28`). The real
   Phase-1 rule is a **first-passage** problem (reach +10 % before −5 %/day or −10 %
   total, **no deadline**), not the 60/30 deadline that produced the 35.7 % baseline.
   Under the real rule, **leverage is pure variance** and 1× — the sizing
   `QM_Common.mqh:182` already forces — is optimal
   (`ftmo_first_passage_measurement.md:85-110`). This retires the whole "joint 1×-each
   vs runner 3×" sizing question in §3: **both arms must be at 1× per sleeve**, which is
   also the only live-deployable configuration.

2. **At the honest effective sample size the binary P(pass) test cannot resolve the
   plausible effect.** ESS is ~9–27 per arm (§1). The point estimate already exists —
   under first-passage, runner-alone 75.3 % vs 3-book 88.3 %, a **+13 pp** difference
   (`ftmo_first_passage_measurement.md:122,131`) — but the 88.3 % lower bound (~70 %)
   already overlaps the runner. Unpaired, the minimum detectable difference is 27–44 pp
   just to clear zero; the plausible 10–25 pp is unresolvable. **Only a paired design
   with a continuous mechanism metric has any chance**, and even it resolves only a
   difference near the top of the plausible range.

3. **The run may measure a book that cannot be deployed.** The rank-1 composition
   (0.641) that motivates the whole exercise contains 10145 and 13301, both
   **dormancy-disqualified as standalone sleeves** (151-day and 36-day max idle gaps
   vs the 30-day block; `2026-07-27_dormancy_handling_design.md:145,139`), and 13301 is
   **timer-infidelic** (per-tick trailing not reproducible in the OnTimer runner;
   `2026-07-27_20181_repair.md:51-65`). The 0.641 was measured on **archived-vintage
   standalone streams** now known to drift (`2026-07-27_multisym_step1_EXECUTED.md:51`).
   These are turned into hard **preconditions** in §6: if any fails, the honest answer is
   the **fourth** sentence — *"not answerable from this run; the book measured is not the
   book that can be deployed."*

**Expected deliverable, stated in advance so it is not a disappointment:** *the composed
book raises the point estimate of P(pass) by ~10–15 pp but the difference is not
resolvable at this sample size — indistinguishable.* Everything below is designed so that
if the truth is better than that, we can see it, and if it is not, we say so cleanly.

---

## 1. Power — can a plausible difference even be resolved? (Challenge Q1)

**The instrument.** One joint run yields **one** 7.5-year equity path (the established
common window is 2018-07-02..2025-12-31; pre-2018-07-02 is **NOT ESTABLISHED**,
`2026-07-27_multisym_step1_EXECUTED.md:69-72`). P(pass) is estimated from **overlapping**
window starts on that single path. Overlapping starts are not independent; the effective
sample size is (number of starts) ÷ (block length over which outcomes decorrelate).

**Honest ESS.** Two independent measurements of this sleeve class converge:

- First-passage book: ESS ≈ **12** (overlapping starts ÷ median resolution 62 td),
  Wald half-width ~18 pp (`ftmo_first_passage_measurement.md:131,147-150`).
- Single-account 60/30 deadline: passer-median deflator gives ESS 25 (±18.8 %); the
  decision-relevant P1-horizon and two-phase deflators give ESS **14** (±25 %) and
  **9** (±31 %), lower bound ~5–11 % (`2026-07-27_single_account_adversarial_review.md:192-206`).
- Composition study states it outright: *"effective independent samples … about 30 IS
  and 20 OOS"* (`2026-07-27_runner_satellite_composition.md:15`).

Take **ESS 9–27 per arm**, decision anchor **ESS ≈ 12–14** (the P1 horizon governs).

**Minimum detectable difference (MDD).** Computed for a two-proportion comparison,
`SE_diff = sqrt(2·p(1−p)/ESS)` unpaired and `sqrt(2·p(1−p)(1−ρ)/ESS)` paired; "clear
zero" = 1.96·SE, "80 % power" = 2.80·SE. Two anchors: p=0.36 (deadline KPI) and p=0.82
(first-passage KPI, the 75/88 regime).

| design | ESS | SE_diff | clear-0 (pp) | 80 %-power (pp) |
|---|---:|---:|---:|---:|
| unpaired, p=0.36 | 25 | 0.136 | 26.6 | 38.0 |
| unpaired, p=0.36 | 14 | 0.181 | 35.6 | 50.8 |
| unpaired, p=0.36 | 9 | 0.226 | 44.3 | 63.4 |
| unpaired, p=0.82 | 12 | 0.157 | 30.7 | 43.9 |
| **paired ρ=0.8, p=0.36** | 14 | 0.081 | **15.9** | 22.7 |
| **paired ρ=0.8, p=0.82** | 12 | 0.070 | **13.7** | 19.6 |
| **paired ρ=0.9, p=0.82** | 12 | 0.050 | **9.7** | 13.9 |

**Reading.** The plausible effect is 10–25 pp (observed point estimate +13 pp).

- **Unpaired is hopeless.** It cannot even clear zero for anything below ~27 pp. Two
  separately-run baselines is not a viable design.
- **Paired is marginal.** Because the joint book *contains* the runner as slot 0, the
  two arms' per-window outcomes are strongly positively correlated (ρ high). Pairing
  cancels the window-start / seasonal variance and pulls the clear-zero threshold down
  to **~10–16 pp** — right at the observed +13 pp. A difference near the **top** of the
  plausible range (~20–25 pp) is resolvable; **a 10–15 pp difference is not** (it needs
  80 % power ≈ 14–23 pp, above the effect).
- **The binary paired test is nearly degenerate.** At ESS ~12 and high ρ the expected
  number of **discordant** windows (one arm passes, the other fails) is **< 1–2**.
  McNemar has essentially nothing to test. **This is why the continuous mechanism metric
  (§7b) is not optional** — the magnitude of each window's outcome (FUND_SCORE / speed)
  carries the signal the pass/fail bit throws away.

**Verdict on Q1:** the binary P(pass) A/B test, taken alone, is **underpowered for the
plausible effect**. It can deliver a credible *positive* verdict only if the true
difference is ≥ ~20 pp under the paired design — which every prior (the pool is 1–2
orders of magnitude short of challenge-grade edge, `docs/research/GOAL_FTMO_PHASE1_P080.md:63-65,127-132`;
single-vs-shared already "indistinguishable and over-determined",
`single_account_adversarial_review.md:210-214`) says it is not. The measurement is worth
running **only** because (a) the paired design is cheap (one run yields both arms, §2)
and (b) the continuous metric can resolve direction where the binary cannot.

---

## 2. The exact paired comparison (Challenge Q2 — the preregistration proper)

The Answer agent MUST follow this pairing exactly.

### 2.1 One run, two arms — extracted, not separately run

The runner slot-0 stream is **proven invariant** to satellite enablement: same-vintage
runner vs standalone 9936 matched **1.000000** (`multisym_step1_EXECUTED.md:50`; F3
isolation `2026-07-27_20181_repair.md:14-27`). Therefore:

- **Arm R (runner-alone):** the account equity path built from the **slot-0 (9936)
  substream of the joint run**, satellites contributing zero.
- **Arm B (joint book):** the account equity path built from slot-0 + slot-1 + slot-2
  substreams of the **same joint run**.

Both arms come from **one binary, one vintage, one window, one set of emitted trades.**
This is the only way "same vintage and same window" (Challenge Q2) is *guaranteed* rather
than asserted. Do **not** run a separate standalone-9936 job for Arm R (that reopens the
vintage gap that voided the 0.914741 pair, `2026-07-27_multisym_runs_adversarial_review.md:29-74`).
Do **not** compose Arm B from the archived `sleeve_streams` JSONLs (that is the
suspect-vintage basis, §4a).

### 2.2 Window — identical, truncated, shared

- Scoring window for **both** arms: **2018-07-02 .. 2025-12-31** (the established common
  window). Any start or evaluation touching pre-2018-07-02 data is **excluded from both
  arms identically** (`multisym_step1_EXECUTED.md:69-72`).
- **The 35.7 % / 75.3 % runner baselines MUST be recomputed on this truncated window
  from the joint run's own slot-0 stream.** They were computed on 2017-10..2025-12
  (`single_account_adversarial_review.md:40`) and on the archived vintage. Reusing either
  published number as the Arm-R anchor is a preregistration violation — different window,
  different vintage.

### 2.3 Start set — identical, paired

- A **first-passage start** is every trading day `t` in the window on which the book has
  ≥1 tradable session remaining. Both arms are scored on the **identical set of start
  days**. Every start yields a paired outcome `(R_t, B_t)`; the statistic is the paired
  difference over that shared set. (First passage has no fixed horizon, so no start is
  dropped for "not enough window" except the censoring rule below.)
- For the secondary deadline KPI (§3.3), a start is admissible only if `t + 90 calendar
  days ≤ 2025-12-31` so both P1(60) + P2(30) fit; the **same admissibility mask applies
  to both arms**.

### 2.4 Deadline rule — fixed, primary vs secondary

- **PRIMARY KPI = first passage, no deadline** (the actual FTMO rule): pass = balance
  reaches +10 % on an **end-of-day, all-flat** basis with ≥4 trading days, before any day
  ≤ −5 % or cumulative ≤ −10 % (`ftmo_first_passage_measurement.md:18-41`). This is what
  "passing a Challenge" means as FTMO runs it today.
- **SECONDARY KPI = 60/30 deadline sprint** (`challenge_book_60d.py` D1=60, D2=30,
  P1_TARGET 0.10, P2_TARGET 0.05, DAILY_CAP 0.05, TOTAL_CAP 0.10), reported for
  continuity with the 35.7 % figure and labelled **explicitly** as an OWNER-imposed
  sprint objective, not an FTMO rule (`ftmo_first_passage_measurement.md:24-27`).
- Both KPIs run on both arms. The verdict (§7) is decided on the **primary**; the
  secondary is context only.

### 2.5 Dormancy rule — identical, open-only, on the union

- Clock resets on a position **OPEN** only; 30-day idle = block (OWNER-fixed, **not** an
  official FTMO number — never cite it as one, `dormancy_handling_design.md:12-24`).
- Because the book shares **one** account, the dormancy clock for Arm B runs on the
  **union of all three sleeves' opens**, not per-sleeve. This is computed identically for
  both arms (Arm R's union is just 9936's opens). A block event = fail, applied the same
  way to both. (Union dormancy admissibility is a §6 precondition.)

### 2.6 Censoring — identical, counted as fail

- A start still unresolved at 2025-12-31 is **counted as FAIL** and reported separately as
  a censored share, for both arms, identically (`ftmo_first_passage_measurement.md:39-41`).
  Because censoring is applied identically, it **cancels in the paired difference**; it
  affects only the absolute levels, which are reported as lower bounds.

### 2.7 Statistic

- Primary: **paired** difference `Δ = P(pass|B) − P(pass|R)` over the shared start set,
  with a paired (McNemar-exact / bootstrap-over-blocks) 95 % interval using the
  **conservative** deflator (ESS from the two-phase / no-deadline horizon, §1 — ESS ≈ 9–14,
  **not** the passer-median ESS 25). Report the discordant-pair count; if < 5, state
  plainly that the binary test is degenerate and defer to §7b.

---

## 3. Risk sizing (Challenge Q3) — decided now

**Decision: both arms at 1× per sleeve. No sweep in the decision path.**

Rationale, in order of force:

1. **1× is the only live-deployable sizing.** `QM_Common.mqh:179-182` hard-clamps every
   EA to `equity·0.01` via `QM_RiskSizerSetCapPct(1.0)`. The 5.0 override ceiling is
   dormant — **no EA calls `QM_FrameworkSetRiskCapPct`** (MEMORY; the whole 79.5→4.7
   wiring gap). Any sim optimum above 1×/sleeve is a **counterfactual we cannot deploy**;
   measuring it answers a question OWNER cannot act on.
2. **Under the real (no-deadline) rule, 1× is also optimal, not a constraint.** Leverage
   is pure variance against fixed barriers; P(pass) falls monotonically toward 50 % as
   size rises (`ftmo_first_passage_measurement.md:85-110`). The "3× optimum / 44 % breach"
   from the single-account review is an **artifact of the self-imposed 60/30 deadline**
   (`single_account_adversarial_review.md:230-255`) and must not anchor a no-deadline
   verdict.
3. **1×-each is the fair equal-gross-exposure contrast.** Arm B at 1×-per-sleeve carries
   3 units of gross across three sleeves; Arm R carries 1 unit on one. This directly
   tests OWNER's question — *does spreading exposure across a diversified book beat
   concentrating it in the runner?* — under total gross the cap permits (≤ 5.0).
4. The IS-chosen-leverage route is **rejected for the decision** because it reintroduces
   the selection instability the single-account review flagged (0.1 pp IS flip → 6 pp OOS
   swing, `single_account_adversarial_review.md:260-267`). A leverage sweep may be
   reported as **descriptive appendix only**, never as the verdict basis.

**Cap check:** Arm B aggregate gross at 1×-each = 3.0, within the ratified 5.0 ceiling.
Confirm in the run that no sleeve's realised sizing exceeds 1 % (the EA cannot, but the
sim must mirror it).

---

## 4. What would make the answer misleading even if computed correctly? (Challenge Q4)

Each confound is classified **tolerable / quantifiable / disqualifying**, with the gate
that contains it.

### (a) Vintage drift — **QUANTIFIABLE → precondition (§6.1)**
The composition targets (runner-alone 0.487, rank-1 0.641;
`runner_satellite_composition.md:13,19`) were measured on **archived standalone streams**
that no longer match the current EA: fresh 9936 vs archive = **0.835463** on the common
window (`multisym_step1_EXECUTED.md:51`). (The task STATE's 0.915136 and the void
20180-pair 0.914741 are *different* comparisons; the discrepancy is itself evidence the
vintage question is unsettled.) **Containment:** the paired design (§2.1) composes **both
arms from the joint run's own fresh-vintage emitted streams**, so drift cannot
differentially bias the *comparison*. What it still contaminates is the *interpretation
against 0.641* — the joint book's absolute score need not match 0.641 and must not be
claimed to.

### (b) 13301 substitution & timer-infidelity — **DISQUALIFYING for the rank-1 headline → precondition (§6.2)**
13301 uses per-tick trailing that the OnTimer runner cannot reproduce bar-gated; its
fidelity failure is an *accepted, expected* finding, not a surprise
(`2026-07-27_20181_repair.md:51-65`). So the joint run's slot-2 is a **different strategy**
than the standalone 13301 that produced 0.641. No TIMER-SAFE rank-1 substitute exists; the
best timer-safe book is rank-17 `9936+10145+13108` at OOS **0.527** vs 0.641
(`20181_repair.md:57-60`; `runner_satellite_composition.md:35`). **Consequence:** the
deployable book is measurably weaker than the 0.641 estimate. The measurement MUST run the
**deployable** composition (timer-safe satellites only) and report *that* book's P(pass).
If 13301 is retained for the run, its slot-2 fidelity vs a same-vintage standalone 13301
is a §6 gate; a fidelity failure means the number describes an undeployable book →
**fourth sentence**.

### (c) 2018-07 window truncation — **TOLERABLE → handled by §2.2**
Removes ~9 months and lowers ESS. Contained by recomputing **both** baselines on the
truncated window; it cancels in the paired difference. Report absolute levels as
window-conditioned.

### (d) Seasonal clustering of the overlapping windows — **QUANTIFIABLE → the ESS deflator**
Overlapping 60-day (or first-passage) windows cluster seasonally; this is *why* ESS
collapses to ~9–27 (§1). **Containment:** the headline CI uses the conservative
(long-horizon) deflator, not the passer-median. Do **not** report the narrow ±18.8 %
band as the headline — it is the most generous defensible number
(`single_account_adversarial_review.md:184-206`).

### (e) Satellite fidelity of 10145 inside the runner — **QUANTIFIABLE → precondition (§6.2)**
Only slot-0 (9936) fidelity is proven (1.000000). Slot-1 (10145) is an F4 transcription
(`20181_repair.md:29-41`); its equivalence to standalone 10145 is **NOT ESTABLISHED**. A
same-vintage 10145 fidelity gate is required before the composed number is trusted.

### (f) Dormancy on the union — **QUANTIFIABLE, and possibly a *benefit* → precondition (§6.3)**
10145 (151d) and 13301 (36d) are dormancy-disqualified **standalone**
(`dormancy_handling_design.md:145,139`), but in a shared account their idle gaps are
covered when 9936/other sleeves trade. The **union** max-gap may be ≤ 30 even though two
members individually fail — a genuine diversification benefit the joint book may earn.
This MUST be computed on the union of emitted opens; if union max-gap > 30 the book is
undeployable → fourth sentence.

---

## 5. Vintage / composition confound summary table

| confound | class | containment | if it fails |
|---|---|---|---|
| a. archived-vintage 0.641 basis | quantifiable | compose both arms from joint-run fresh streams | interpret vs 0.641 forbidden |
| b. 13301 timer-infidelity | disqualifying(headline) | run deployable timer-safe book | 4th sentence |
| c. 2018-07 truncation | tolerable | recompute both baselines same window | absolute levels window-conditioned |
| d. seasonal clustering | quantifiable | conservative ESS deflator for CI | — |
| e. 10145 satellite fidelity | quantifiable | same-vintage 10145 fidelity gate | 4th sentence |
| f. union dormancy | quantifiable | compute on union of opens | 4th sentence if >30d |

---

## 6. Preconditions — gates that MUST pass before the P(pass) verdict is trusted

These run first. Any FAIL routes to the **fourth sentence** (§7), not to a tuned retry.

1. **Vintage isolation resolved or bounded.** The governed f0301ecf^ vs f0301ecf staged-
   EX5 probe pair (currently DEFERRED behind the USDJPY lock) either identifies the causal
   commit or bounds the drift. Until then, the composed number is reported **only** as
   fresh-vintage-internal (both arms same vintage) and **never** compared to the archived
   0.641/0.487.
2. **Satellite fidelity gates.** For every satellite actually in the run, a same-vintage
   standalone vs joint-slot replay via `compare_joint_replay.py`. 10145 must reach an
   agreed match threshold; 13301, if present, is expected to FAIL (per-tick) and its
   presence therefore forces the deployable-book variant (timer-safe only).
3. **Union dormancy admissibility.** Max idle gap on the union of all emitted opens over
   2018-07-02..2025-12-31 must be ≤ 30 (open-only clock). Report the margin.
4. **Sizing mirror.** Confirm the sim applies ≤ 1 %/sleeve, matching `QM_Common.mqh:182`.

All four must be committed evidence (file/query), not inference — per the standing
evidence rule.

---

## 7. The verdict — three sentences, thresholds fixed now (Challenge Q5)

OWNER receives **exactly one** of the following. Decided on the **PRIMARY** (first-passage,
1×) KPI, paired difference `Δ = P(pass|B) − P(pass|R)` on the shared start set, with the
conservative-deflator 95 % interval, plus the mechanism metric (7b). Thresholds are fixed
before scoring.

**(A) "The composed book makes passing MORE likely."** — requires **all three**:
   - i. paired point estimate **Δ ≥ +10 pp**, AND
   - ii. paired conservative 95 % **lower bound > 0** (i.e. the difference clears zero at
     ESS ≈ 9–14, not merely at ESS 25), AND
   - iii. **mechanism agrees**: the paired FUND_SCORE / speed difference on the fresh
     joint-emitted streams is positive with its own bootstrap LB > 0.
   Given §1, (A-ii) is the hard bar and is reachable only if the true effect is ≥ ~20 pp.

**(B) "The composed book does NOT make passing more likely (no better, possibly worse)."**
   — any of:
   - paired point estimate **Δ ≤ 0**, OR
   - the deployable (timer-safe, union-dormancy-legal) book's point estimate ≤ Arm R, OR
   - mechanism metric (7b) negative with LB < 0.

**(C) "Indistinguishable at this sample size — the book neither clearly helps nor clearly
   hurts."** — the **default / expected** outcome: `0 < Δ` but the conservative 95 %
   interval spans zero (LB ≤ 0), i.e. a positive point estimate we **cannot** certify.
   Reported with the honest sentence: *"point estimate +X pp, 95 % band [L, U] spanning
   zero; the measurement is underpowered to distinguish the book from the runner at this
   horizon."*

**(D) Fourth outcome — "Not answerable from this run; the book measured is not the book
   that can be deployed."** — forced by any §6 precondition failure (10145 fidelity fail,
   union dormancy > 30, 13301 retained and undeployable). This is not a failure of the
   analysis; it is the analysis correctly refusing to launder an undeployable book's
   number into a deployment decision.

### 7b. Mechanism metric — mandatory companion, not optional
Because the binary paired test is near-degenerate at ESS ~12 (§1), the Answer agent MUST
also report the **continuous** paired difference in FUND_SCORE and in speed
(= (%/yr)/DD%, sizing-invariant; `GOAL_FTMO_PHASE1_P080.md:47-51`) between arms on the
fresh joint-emitted streams. If the binary test lands in (C) but the mechanism metric is
positive with LB > 0, the honest sentence appended to (C) is: *"the book adds
return-per-drawdown but not enough to move the pass rate detectably at this horizon."*
The mechanism metric never overrides (A)/(B) but disambiguates (C).

---

## 8. What this document does and does not do

**Does.** Fixes the KPI (first-passage primary, 1× sizing), the pairing (both arms from
one joint run's emitted streams, truncated common window, shared start set), the
confound gates, and the verdict thresholds — all before any scoring, so nothing is chosen
after seeing results.

**Does not.** Run any backtest, reserve any terminal, queue any work item, touch T5 or
T_Live, or mutate any state. No `terminal64.exe` was started. This is a desk artifact over
committed evidence.

**Honest prior, restated.** Every independent line — the pool being 1–2 orders of
magnitude short of challenge-grade edge, single-vs-shared already indistinguishable, the
+13 pp point estimate sitting inside its own confidence band — points to outcome **(C)**.
The value of running the measurement is that (i) it costs one paired run, (ii) the
mechanism metric can still resolve *direction*, and (iii) a preregistered (C) is a real,
defensible answer to OWNER's question: *"we measured it properly; the book helps a little
but not measurably, and at 1× — the only sizing we can deploy — the runner alone is
already the bulk of the result."*

## Evidence index (all committed)

- Runner fidelity 1.000000, window truncation, fresh-vs-archive 0.835463:
  `docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md:50-52,69-72`
- Runner invariance (F3), 10145 binding (F4), 13301 timer-risk & rank-17 alt:
  `docs/ops/evidence/2026-07-27_20181_repair.md:14-27,29-41,51-65`
- Composition table, runner 0.487 / rank-1 0.641 / rank-17 0.527, ESS ~30 IS/20 OOS:
  `docs/ops/evidence/2026-07-27_runner_satellite_composition.md:13,15,19,35`
- First-passage KPI, no-deadline rule, leverage inversion, 1× clamp near-optimal,
  runner 75.3 % vs 3-book 88.3 %, ESS ~12 / ±18 pp:
  `docs/ops/evidence/2026-07-27_ftmo_first_passage_measurement.md:14-41,85-110,122,131,147-150`
- ESS deflator table, 35.7 % / 44 % breach / med 33d, conservative LB ~5–11 %:
  `docs/ops/evidence/2026-07-27_single_account_adversarial_review.md:33-40,184-206,230-255`
- Dormancy per-sleeve gaps (9936 27d, 10145 151d, 13301 36d), open-only clock, OWNER-fixed:
  `docs/ops/evidence/2026-07-27_dormancy_handling_design.md:12-24,138-145`
- Vintage void-pair caution (0.914741 cross-program/cross-vintage):
  `docs/ops/evidence/2026-07-27_multisym_runs_adversarial_review.md:29-74`
- 1× cap wiring: `framework/include/QM/QM_Common.mqh:179-182`
- Deadline constants (secondary KPI): `tools/strategy_farm/portfolio/challenge_book_60d.py` (D1=60,D2=30)
- Pool-is-short prior, speed metric: `docs/research/GOAL_FTMO_PHASE1_P080.md:47-51,63-65,127-132`
