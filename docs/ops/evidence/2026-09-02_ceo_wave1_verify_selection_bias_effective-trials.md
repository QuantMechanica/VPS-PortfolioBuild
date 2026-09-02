# Adversarial verification — Portfolio selection-bias finding
## LENS: EFFECTIVE NUMBER OF TRIALS

**Verifier task:** try hard to REFUTE the finding that, after correcting for the true search
size (N=13,398 pairs), *zero* of 24 live sleeves and *zero* of 21 Q11 survivors have a Sharpe
distinguishable from the luckiest-of-noise benchmark (E[max SR]=1.44), and that the modeled
book Sharpe +2.4 is an in-sample selection artifact.

**Mode:** read-only. DB `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`, `PRAGMA busy_timeout=30000`.
Reproduced from the report's own `dsr_results.json` (per-sleeve sr, n, skew g1, kurtosis g2).
Scripts: `verify_effN.py`, `verify_n1.py` (next to this file).

**VERDICT: NOT REFUTED (refuted=false), confidence 0.80.** The core conclusion survives the
effective-N lens. The lens does force two material *calibrations* (headline benchmark number is
inflated; the "indistinguishable from zero" wording overstates), but these do not overturn the
finding. Detail below.

---

## 0. Reproduction check (report's math is correct)

E[max SR] annualized (Bailey–LdP), y=7.474 yr — my recompute matches the report exactly:

| N | SR₀_annual (mine) | report |
|---|---|---|
| 154 | 0.980 | 0.98 |
| 3,001 | 1.301 | 1.30 |
| 13,398 | 1.438 | 1.44 |

The formula, the census (13,398 distinct done Q02 pairs; 3,001 distinct EAs; 297 symbols), and
the per-sleeve DSR are all reproduced. No arithmetic error found.

---

## 1. The decisive computation: at what effective N does the finding break?

The finding has **two** operational tests, and they behave very differently under N-reduction.

### (A) The statistical-significance test (DSR ≥ 0.95) — *N-INVARIANT here*

DSR = Φ((sr − sr₀(N)) / σ̂_SR) uses the López de Prado skew/kurtosis-adjusted estimator SE.
I swept the **maximum DSR across all sleeves** as N shrinks (`verify_n1.py`):

| effective N | max DSR, 24 book sleeves | max DSR, 21 frontier |
|---|---|---|
| 13,398 | 0.356 | 0.147 |
| 1,000 | 0.534 | 0.331 |
| 150 | 0.683 | 0.536 |
| 50 | 0.770 | 0.672 |
| 25 | 0.823 | — |
| 10 | 0.913 | 0.859 |
| **8 (book) / 5 (frontier)** | **~0.94 / 0.92** | first to approach 0.95 |
| 5 | 0.962 (13213) | 0.922 |
| 2 | 0.994 | 0.979 |
| 1 (no correction) | 0.999 | 0.994 |

**To make even ONE sleeve statistically significant (DSR≥0.95) you must drive the effective
number of trials down to ≈ 5–8.** For every N ≥ 10, the significance test is 0/24 and 0/21.
This is the report's headline count, and it is *robust to two orders of magnitude of N-reduction*.

### (B) The point-estimate test (annualized Sharpe > E[max SR]) — *FRAGILE to N*

This is the headline sentence's "E[max SR]=1.44" framing. Point estimates cross:

- Best **book** sleeve 10919/XTIUSD (ann. Sharpe **1.242**) clears E[max SR] once **effective N < 1,654**.
- Best **frontier** sleeve 20086/EURUSD (ann. Sharpe **0.92**) clears once **effective N < 197**.
- Sweep counts of sleeves with ann.Sharpe > SR₀(N):

| N | SR₀_ann | book clearing | frontier clearing |
|---|---|---|---|
| 13,398 | 1.44 | 0/24 | 0/21 |
| 3,001 | 1.30 | 0/24 | 0/21 |
| 1,500 | 1.23 | 1/24 | 0/21 |
| 300 | 1.06 | 1/24 | 0/21 |
| 150 | 0.98 | 4/24 | 1/21 |

The report itself concedes this ("even at N=154 … 4/24 sleeves clear SR₀=0.98"). So the *point
estimate* framing of "zero" depends entirely on effective N staying above ~1,654 (book) / ~197
(frontier).

---

## 2. Is the effective N plausibly ≤ 8? (the only way to void the finding) — NO

The lens asks me to argue N ≪ 13,398. I can, and I do — but it does not reach the ~8 needed.

**(b) Correlation among trials.** The 13,398 pairs come from only **3,001 distinct EAs** tested
on a mean of **4.46 symbols each** (median 4, DB-measured). The 24 book sleeves come from **21
distinct EAs**; the 21 frontier survivors from 21 EAs. So the *maximum-charity* correlation
collapse — treat every symbol-variant of one EA as a single trial — still leaves **≈3,001
independent trials**, not 8. Even collapsing further for near-duplicate strategy cards (the farm
sources from 118 registered `sources`, thousands of cards spanning distinct mechanisms: RSRS,
BB-mean-reversion, breakout, pattern-filter, TV overlays, …), the count of *genuinely distinct
strategy ideas* is clearly in the dozens-to-hundreds. **Effective N ≤ 8 would require the entire
farm to be ~8 strategy families with near-unit cross-correlation — which the EA registry
refutes.** At the smallest defensible N (say 100), max book DSR = 0.716; at N=50, 0.770. Neither
clears 0.95.

**(a) OOS gates as independent validation.** The strongest structural argument: Q04 walk-forward,
Q06 stress, Q07 multi-seed, Q08 PBO run *after* Q02 selection, so a survivor is not "the max of
13,398 in-sample draws." I tested the premise on the DB.

- Funnel (distinct pairs, done): Q02 13,398 → Q04 6,840 → Q05 684 → Q06 344 → Q07 286 → Q08 236 → Q11 22.
- **Q04 OOS pass rate** (genuine, non-INFRA evaluations): **681 / 5,747 = 11.85 %** (brief's 9.4 %
  on strict PASS-only). Of Q04-evaluated pairs, 5,743/5,747 were Q02-PASS — so Q02→Q04 is indeed
  the selection→OOS-validation step.
- **Is 11.85 % above the pure-noise base rate under Q04's criteria?** Q04 adds *commission* and
  requires walk-forward OOS robustness — both push a zero-edge strategy toward failure (mean
  reversion + cost drag). A plausible noise base rate under such a criterion sits in the ~5–20 %
  range, so **11.85 % is not clearly above noise** — it is consistent with the funnel selecting
  luck, not signal.
- The downstream gates that *would* add independent validation are weak filters: **Q06 stress
  pass 92.2 %, Q07 multi-seed pass 80.9 %** (DB-measured). High pass-rate ⇒ little
  effective-N reduction. Only Q04 (11.8 %) and Q08 (20.5 %) bite, and Q04's rate is
  noise-plausible.
- **The ultimate OOS test — live trading since 2026-07-19 — realized ≈ −3.25 Sharpe** (report;
  brief corroborates DD 2.62 %, equity 99,205 < HWM 101,871). That is the definitive
  out-of-sample verdict, and it is *consistent with the finding* (regression to ≈0/negative),
  not with "OOS validated real edge."

So even granting OOS some filtering power, it cannot collapse effective N to single digits, and
the live result argues it did not filter real edge at all. **Part (a) does not refute; it
corroborates.**

**Most-charitable limit (effective N = 1, i.e. OOS fully validates each survivor, zero selection
penalty):** even here only **12/24 book sleeves** and **5/21 frontier** are individually
significant (raw t = sr·√n > 1.645); 5/24 and 1/21 at t>2.326. And the live book still realized
−3.25. So the "the +2.4 is real, diversified edge" refutation fails *on its own terms* — you have
to believe both N≈1 *and* that a book of 12 marginally-significant, live-losing sleeves is edge.

---

## 3. Where the lens legitimately bites (calibration, not refutation)

1. **Headline number is inflated.** E[max SR]=1.44 is computed at N=13,398, defensibly an upper
   bound. At a plausible effective N of a few hundred to a few thousand (after correlation + any
   OOS pre-filtering), **E[max SR]_annual ≈ 1.06–1.30**. The report's own limitations section
   concedes effective N < 13,398; the headline sentence should carry that band, not the single
   inflated 1.44.

2. **"No component's edge is distinguishable from zero" (report §5.1) overstates.** Before the
   multiplicity correction, **12/24 book sleeves have individually-significant positive Sharpe
   (t>1.645)**. The correct statement is "not significant *after* multiplicity correction." The
   entire case rests on the correction — which is exactly what this lens probes — and the
   correction holds (effective N is certainly ≥ dozens, far above the ~8 that would void it).

3. **Point-estimate "zero" is N-sensitive.** On the annualized point-estimate basis the count is
   0/24 only for effective N ≳ 1,654; at N≈150–300 it is 1–4. The *significance* count (0/24,
   0/21) is what is robust.

None of these change the substantive conclusion — no survivor is significant after any defensible
correction; +2.4 is a diversification/selection artifact of individually-insignificant edges; the
pipeline has no portfolio-level deflation gate (Q08 8.2 trivial-passes 141/166 rows); the live
−3.25 corroborates. All five recommended actions stand.

---

## 4. Verdict

**refuted = false, confidence 0.80.** The effective-number-of-trials lens is the report's most
exposed flank (its N=13,398 is inflated and its "zero on point estimate" framing is fragile), but
it cannot rescue the survivors. The load-bearing claim — 0/24 and 0/21 sleeves are statistically
distinguishable from noise-luck after correcting for search multiplicity — requires an
indefensibly tiny effective N (≤ ~8 book, ≤ ~5 frontier) to overturn, and the trial pool (3,001
distinct EAs, 297 symbols, 118 sources) plus the OOS pass-rate evidence and the live −3.25 all
put the defensible effective N in the hundreds-to-thousands. At every N in that range the
significance test is 0/24, 0/21.

**What would change the verdict:** (i) credible evidence that the effective number of
*independent* strategy trials is ≤ ~8 (near-unit cross-correlation across essentially all cards)
— then 13213/USDJPY or 10919/XTIUSD reaches DSR≥0.95 and "zero distinguishable" flips; or (ii) a
rigorously simulated Q04 noise base rate far below 11.8 % (e.g. ~2 %) *combined with* live OOS
turning durably positive — which would establish OOS as real validation and shrink the effective
penalty. Neither is supported by the current evidence; (ii) is contradicted by the live −3.25.
