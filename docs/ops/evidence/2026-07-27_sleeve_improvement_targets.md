# Sleeve Improvement Target Brief — single FTMO account, 60/30 KPI

Date: 2026-07-27
Author: Claude
Status: working document for the factory (what to build/optimise next)

## 0. Requirement (OWNER, 2026-07-27, binding)

One account at a time. Keep the KPI: pass FTMO **Phase 1 (+10%, ≤60 calendar days)**
then **Phase 2 (+5%, ≤30 calendar days)**. Improve the book, not the deadline. The
single binding requirement for a lead sleeve is therefore:

> a sleeve that **alone** reaches +10% within 60 calendar days at **≤5x** risk, with
> **high probability**, **without** breaching −5% daily / −10% total, and **never**
> going 30 calendar days without a trade.

The 5x ceiling is `QM_FrameworkSetRiskCapPct` (QM_Common.mqh:315, OWNER-ratified
2026-07-05) — cited, never changed. The 30-day dormancy block is OWNER-confirmed and
treated as fixed here; its official FTMO scope is unresolved
(`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md` §B, questions 6–9).

## 1. Method / provenance

All figures below come from the existing scorer
`tools/strategy_farm/portfolio/challenge_book_60d.py` (the phase engine `phase()`
lines 191–231, the gate/pool filter lines 112–166, the 60/40 IS→OOS split lines
276–283). The single-account ranked table, the Phase-1 isolation, the dormancy/gap
measurement and the discriminating statistics are produced by
`tools/strategy_farm/portfolio/sleeve_improvement_targets.py`, which **imports** that
module (no reimplementation of the engine) and adds only reporting. Rerun:

```
cd C:/QM/repo/tools/strategy_farm/portfolio && python sleeve_improvement_targets.py
```

Pool: **15 gate-clean sleeves** (Q02–Q08 clean, entry_time coverage ≥99%, ≥250
trading days), window **2017-10-09 … 2025-12-30 (2111 trading days)**, selection
2017-10-09…2022-09-15, scoring 2022-09-15…2025-12-30. **Leverage is chosen IN-SAMPLE;
every P and breach figure below is OUT-OF-SAMPLE.** "1x" = the sleeve's native
RISK_FIXED sizing, which is ≈1% risk per trade (the framework default cap,
QM_Common.mqh:179-182). Multi-day sleeves are charged their full adverse excursion on
every open day (the pessimistic bound, challenge_book_60d.py:181-188).

## 2. Ranked table — every gate-clean sleeve vs. the single-account requirement

`P(P1≤60d)` and `P(fund)` are OOS at the funded-optimal leverage. `breach` is the OOS
share of starts blown up (−5% daily or −10% total). `maxgap_d` is the largest gap in
calendar days between consecutive active days. `dq30` = the sleeve has demonstrated a
>30-day trade gap and therefore violates the "never 30 days without a trade" clause —
a disqualifier on the letter of the requirement even where the OOS sample happened not
to realise a block. `med60`, `|wDay|`, `wDD_p90` are 1x, in % of account (§4).
`FUND_SCORE` (§4) is the requirement-derived one-number feasibility gate; ≥1.0 = passes
+10%/60d at a leverage that never breaches.

| # | sleeve | lev | P(P1≤60d) | P(fund 60/30) | breach | maxgap_d | dq30 | multi% | med60 | \|wDay\| | wDD_p90 | FUND_SCORE |
|--:|---|--:|--:|--:|--:|--:|:--:|--:|--:|--:|--:|--:|
| 1 | 9936:USDJPY | 3 | **61.4%** | **35.7%** | 44% | 27 | no | 0% | 3.34 | 1.76 | 8.18 | **0.41** |
| 2 | 13301:GDAXI | 4 | 51.8% | 25.2% | 50% | 36 | **YES** | 0% | 1.83 | 1.85 | 5.09 | 0.36 |
| 3 | 10553:XAUUSD | 3 (3% dstop) | 36.7% | 21.3% | 74% | 6 | no | 45% | 0.97 | 2.88 | 7.46 | 0.13 |
| 4 | 13213:USDJPY | 2 | 43.0% | 20.7% | 37% | 26 | no | 0% | 1.80 | 1.90 | 9.45 | 0.19 |
| 5 | 10848:XAUUSD | 4 | 41.2% | 14.7% | 77% | 11 | no | 40% | 1.17 | 2.03 | 6.75 | 0.17 |
| 6 | 10700:XAUUSD | 2 | 32.9% | 12.5% | 6% | 42 | **YES** | 58% | 1.11 | 2.02 | 4.97 | 0.22 |
| 7 | 10291:SP500 | 5 | 23.1% | 3.2% | 76% | 13 | no | 94% | 0.32 | 1.21 | 3.29 | 0.10 |
| 8 | 11063:USDJPY | 4 | 26.9% | 3.1% | 61% | 39 | **YES** | 28% | 0.88 | 3.05 | 5.33 | 0.14 |
| 9 | 13108:XTIUSD | 5 | 9.5% | 0.4% | 22% | 16 | no | 93% | 0.32 | 1.00 | 2.07 | 0.15 |
| 10 | 10128:XAUUSD | 1 | 0.0% | 0.0% | 0% | 133 | **YES** | 89% | −0.07 | 1.00 | 1.66 | −0.04 |
| 11 | 10145:XAUUSD | 1 | 0.0% | 0.0% | 0% | 147 | **YES** | 92% | 0.33 | 1.00 | 1.51 | 0.16 |
| 12 | 10183:XAUUSD | 5 | 5.3% | 0.0% | 0% | 10 | no | 99% | 0.19 | 1.00 | 0.97 | 0.09 |
| 13 | 12969:USDJPY | 1 | 0.0% | 0.0% | 0% | 35 | **YES** | 99% | 0.19 | 1.01 | 0.77 | 0.09 |
| 14 | 13036:GDAXI | 1 | 0.0% | 0.0% | 0% | 279 | **YES** | 0% | −0.04 | 0.99 | 2.44 | −0.02 |
| 15 | 9403:GDAXI | 3 | 7.0% | 0.0% | 46% | 109 | **YES** | 39% | 0.63 | 3.01 | 5.17 | 0.11 |

Headline: the best single account is **9936:USDJPY @3x — P(P1≤60d) 61.4%, P(fund 60/30)
35.7%**, at the cost of a **44% breach share** (49% over all starts, per
challenge_book_60d.py's own per-sleeve line). **No sleeve satisfies the requirement as
written** (high probability *and* no breach): FUND_SCORE tops out at 0.41. The 36%
figure OWNER was quoted is bought by tolerating a ~½ blow-up rate.

## 3. What separates the good sleeves from the rest (the key output)

Spearman rank-correlation of each per-sleeve statistic with OOS P(fund), n=15:

| statistic | ρ with P(fund) | reading |
|---|--:|---|
| **median 60-day return @1x (drift)** | **+0.876** | **the discriminator** |
| max drawdown @1x (whole history) | +0.832 | good sleeves draw down *more* |
| annualised return @1x (drift) | +0.811 | same signal as med60 |
| p90 60-day window drawdown @1x | +0.789 | risk rides with drift |
| FUND_SCORE (§4) | +0.775 | the requirement, one number |
| trades/yr | +0.590 | helps, not decisive |
| avg win size @1x | +0.588 | helps, not decisive |
| expectancy per trade @1x | +0.489 | weak alone |
| **win rate** | **−0.306** | **higher win rate is mildly *bad*** |
| **leverage headroom L_permit** | **−0.792** | **"safe" = "too slow"** |

Group medians (good = P(fund)≥10%, n=6 · bad = P(fund)<3%, n=7):

| statistic | GOOD median | BAD median | clean split? |
|---|--:|--:|:--:|
| median 60-day return @1x | **1.49%** | **0.19%** | yes, ~0.80% |
| annualised return @1x | **9.7%** | **1.3%** | yes, ~4.65% |
| max drawdown @1x | 20.7% | 6.3% | yes, ~11.6% |
| worst single day @1x | −1.96% | −1.00% | overlap |
| win rate | 0.48 | **0.53** | inverted |
| trades/yr | 158 | 50 | overlap |
| expectancy/trade @1x | 0.105% | 0.022% | overlap |

**The single discriminating statistic is directional drift per unit time — median
60-calendar-day return at 1x (ρ = +0.876).** Good sleeves drift 1.0–3.3% per 60 days
at 1x; the rest drift 0.2–0.6%. Everything the factory might instinctively breed for is
either irrelevant or backwards here:

- **Win rate is inverted (ρ −0.31).** The bad group wins *more often* (median 53% vs
  48%) — they are high-hit-rate, tiny-edge plodders (12969:USDJPY wins 63% and is
  dead-last useful). A high win rate is not the target.
- **Low drawdown is a trap (ρ +0.83 the *wrong* way).** The safe sleeves (maxDD 1.5–9%)
  cannot move +10% in 60 days at any legal leverage; their calm is the signature of a
  strategy too timid to sprint. `L_permit` — how much leverage the caps *allow* — is
  **negatively** predictive (ρ −0.79): the sleeves with the most room to lever are the
  ones with nothing worth levering.

**Why even the good ones fall short — the leverage tension.** For all 15 sleeves the
binding constraint is `drift`: the leverage `L_target = 10/med60` needed to reach +10%
at the median 60-day window **exceeds** the leverage `L_permit = min(5, 5/|wDay|,
10/wDD_p90)` the caps permit. For the drift-carrying sleeves the binding cap is the
**p90 60-day-window drawdown** (a losing streak), not any single day:

- 9936 must be levered ~3.0x to hit target, but a no-breach path allows only ~1.2x
  (its p90 60-day drawdown is 8.18% at 1x → 3x = ~25%, far past −10%). So 3x reaches
  target 61% of the time and blows up 44% of the time. That gap *is* the 36% ceiling.

## 4. The concrete target — one number the factory selects on

Derived directly from the requirement (reach +10% in 60d at L≤5x with the worst day
inside −5% and the p90 60-day window drawdown inside −10%), it reduces to a single
inequality on quantities computable from any Q08 trade stream, **no new backtest**:

> **FUND_SCORE = med60_1x / max( 2.0 , 2·|wDay_1x| , wDD_p90_1x )  ≥  1.0**

where, at the sleeve's native (~1% / trade) sizing:
- **med60_1x** = median of rolling **60-calendar-day** summed net ÷ account (the sprint
  drift);
- **|wDay_1x|** = magnitude of the worst single **day's** summed net ÷ account;
- **wDD_p90_1x** = 90th-percentile peak-to-trough drawdown **inside** a 60-day window;
- the `2.0` floor is the 5x ceiling (10%/5); `2·|wDay|` is the −5% daily cap; `wDD_p90`
  is the −10% total cap.

FUND_SCORE ≥ 1.0 means a leverage ≤5x exists at which the **median** 60-day window
already reaches +10% while the worst day stays inside −5% and the path inside −10%.
The term in the denominator that is largest tells the factory **which lever to pull**.

Current pool: **max FUND_SCORE = 0.41 (9936)**; the binding term for every
drift-carrying sleeve is **wDD_p90** (the loss-streak depth), not the single-day loss.
Interpreted plainly, the target is:

> **the median 60-day GAIN must be at least as large as the 90th-percentile 60-day
> DRAWDOWN, both at 1x.** 9936 is at 3.34 vs 8.18 — the drawdown it must survive is
> ~2.4× the gain it produces. The factory must flip that ratio.

Selection use: compute FUND_SCORE on each new/rebuilt sleeve's Q08 stream; gate at
≥1.0 for a lead single-account candidate, and rank by it below that. It is a superset
signal — its numerator is the empirical discriminator (drift, ρ 0.88) and its
denominator is the cap the current pool actually hits.

## 5. Which EXISTING sleeves to optimise, and in which direction

Grounded in measured statistics (§2/§4), not logic (logic guesses are labelled
SPECULATIVE). All three cap-safety terms improve P *and* cut breach at once.

1. **9936:USDJPY — the lead. Optimise for drawdown-streak depth.** Best FUND_SCORE
   (0.41), best drift (med60 3.34), intraday-flat (0% multi-day → clean for all FTMO
   phases), gap 27d (< 30, dormancy-safe). Binding term: wDD_p90 = 8.18% vs a gain of
   3.34%. **Direction: cut the p90 60-day window drawdown roughly in half without
   cutting the win side.** In measured terms, target wDD_p90 ≤ ~3.3% and |wDay| ≤ ~1.6%
   while holding med60 ≈ 3.3%; that alone lifts FUND_SCORE from 0.41 to ~1.0 and lets 3x
   run without the 44% breach. SPECULATIVE (logic unknown to me): a per-day loss cap or
   max-consecutive-loss guard that truncates only the worst tail days — the docstring
   (QM_PropFirm.mqh:30-45) warns a naive daily halt that drops trade P&L *hurt* the
   campaign, so any stop must realise the loss, not delete the trade.

2. **13213:USDJPY — same edge family, same direction.** Drift 1.80, intraday, gap 26d
   (safe). Binding wDD_p90 = 9.45% (the highest streak risk in the pool). Direction:
   cut streak drawdown; secondarily raise drift. NOTE: both 9936 and 13213 are USDJPY —
   likely the **same underlying edge**; treat 13213 as a fallback/variant of 9936, not
   an independent second bet (also relevant to FTMO's correlated-exposure and $400k
   per-strategy cap, `2026-07-27_ftmo_phase2_and_funded_rules.md` §18).

3. **13301:GDAXI — 2nd-best score, but fix dormancy first.** FUND_SCORE 0.36, the
   **lowest window drawdown of the drift-carriers** (5.09) and intraday-flat — the
   cleanest risk shape available. Blocker: **maxgap 36d > 30 → dq30, disqualified on
   the dormancy clause.** Direction: force a minimum trade cadence (lower the signal
   threshold / add a fallback entry) to close the >30-day gap; if that holds drift, it
   becomes the strongest non-USDJPY candidate. SPECULATIVE on how its entries gate.

4. **XAU multi-day sleeves (10553, 10848, 10700) — lower priority.** They carry 45/40/58%
   multi-day (weekend) exposure: allowed in Challenge/Verification but incompatible with
   a Standard **Funded** account's weekend-close rule (QM_PropFirm.mqh:266-308 logs this;
   rules §19). 10700 also fails dormancy (gap 42d). Their drift is low (med60 ≤ 1.17) and
   fixing it needs a bigger edge change than a risk-shape tweak. Park behind 1–3.

## 6. What NEW strategy to look for (mechanical spec, derived — not asserted)

Derived from §1's requirement and the arithmetic that 9936 nearly satisfies. Stated at
the framework's native ~1%/trade ("1x") sizing.

- **Holding period: intraday-flat, closed same session, no weekend holds.** The only
  two sleeves with the right risk shape (9936, 13213) are 0% multi-day; multi-day holds
  incur the pessimistic full-MAE-per-day charge and break the FTMO Funded weekend rule.
- **Trade frequency: ≈12–15 trades/month (~150/yr).** Derivation: (a) high frequency is
  what smooths the 60-day window drawdown (law of large numbers) — the exact property
  the pool lacks; (b) it guarantees the 4-trading-day minimum per phase and keeps the
  max inter-trade gap well under 30 days. This matches 9936 (152/yr) — frequency is not
  the missing ingredient, smoothness is.
- **Return per trade: ≈0.13% of account expectancy at 1x.** Derivation: to reach +10% at
  3x over ~26 trades in 60 days needs per-trade $ expectancy of 10%/(3·26) ≈ 0.13% at 1x.
  9936 already sits at 0.131%. **The target is not more edge per trade — it is the same
  edge delivered more smoothly.**
- **The binding new property: p90 60-day-window drawdown ≤ median 60-day gain, at 1x
  (FUND_SCORE ≥ 1).** Concretely: **med60 ≈ 3.5% with wDD_p90 ≤ 3.5% and worst day ≤
  1.6% at 1x.** Then 3x reaches +10% at the median window with the worst day at
  ~−4.8% (inside −5%) and the path inside −10%. That is a loss-streak depth roughly
  **one-third of 9936's** while holding its drift. The whole search is: *9936's return
  engine on a two-to-three-times smoother equity curve.*

Selection gate for candidates from either route (optimised or new): FUND_SCORE ≥ 1.0
computed on the Q08 stream, intraday-flat, max inter-trade gap < 30d. Rank survivors by
FUND_SCORE; confirm the winner by rerunning `challenge_book_60d.py` (single-account row)
for the true first-passage P(P1≤60d) and P(fund), which must clear OWNER's "high
probability" bar — target P(P1≤60d) ≥ 0.80 with breach share in the low teens, versus
today's 61% / 44%.

## 7. Status / evidence / risks / next step

- **Status:** brief complete; single-account KPI quantified at 35.7% (9936@3x, 44–49%
  breach); no sleeve meets the no-breach requirement (max FUND_SCORE 0.41).
- **Evidence:**
  `tools/strategy_farm/portfolio/challenge_book_60d.py` (engine),
  `tools/strategy_farm/portfolio/sleeve_improvement_targets.py` (this brief's tables,
  reproducible),
  `docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md` (rules),
  `framework/include/QM/QM_PropFirm.mqh` (phase selector + weekend/flatten behaviour).
- **Risks / caveats:** FUND_SCORE uses whole-history worst-day and p90-window drawdown
  as a no-breach feasibility floor — it is intentionally conservative and does not model
  first-passage/flatten (which is why the model's P(P1) exceeds the median-window
  reading); use it to *filter and rank*, then confirm with the full scorer. The 30-day
  dormancy disqualifier rests on an OWNER premise, not a published FTMO rule. USDJPY
  sleeves 9936/13213 are probably one edge, not two.
- **Recommended next step:** point the factory at **route 1 (drawdown-streak surgery on
  9936:USDJPY)** and **route 3 (dormancy-cadence fix on 13301:GDAXI)** as the two
  concrete optimisation work-items, and add **FUND_SCORE ≥ 1.0 (intraday, gap<30d)** as
  the admission filter for new density-motor sourcing. Re-score with
  `challenge_book_60d.py` after each rebuild.
