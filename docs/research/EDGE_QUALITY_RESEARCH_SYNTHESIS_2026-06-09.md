# Edge-Quality Research Synthesis — the honest anomaly landscape

**Author:** Claude · **Date:** 2026-06-09 · **Status:** strategic brief (Phase 2 of the
Edge-Quality Initiative) · **Pairs with:** `EDGE_QUALITY_SURVIVOR_FORENSICS_2026-06-09.md`

## Method

Adversarially-verified deep research (108 agents, 26 top-tier sources, 117 claims extracted,
25 verified by 3-vote refutation panels, **9 of 25 killed**). Question: the most robust,
academically-validated, **near-zero-parameter** edges tradeable on our universe (FX majors,
gold, equity-index CFDs), with an honest decay/crowding assessment. Sources were uniformly
top-tier (J. Finance, JFE, NY Fed, NBER) — no blog-grade evidence underpins any kept claim.

## The headline finding (uncomfortable but important)

**The famous near-zero-parameter anomalies are mostly tapped out for our universe.** Every
flagship candidate failed at least one of: *already decayed*, *not replicable on our narrow
instruments*, or *statistically contested*. This is not a research failure — it is the
**structural reason our yield is ~1 survivor per 700 EAs.** Liquid, near-parameter-free free
lunches are rare and crowded; the pipeline is correctly refusing to pass curve-fits, and
genuine persistent edges are scarce. We should **recalibrate expectations accordingly** — do
not expect a flood of survivors from "better research"; expect a trickle, and treat each real
one as precious.

## Candidate-by-candidate verdict

| Edge | Verdict | Why |
|---|---|---|
| **FOMC even-week premium** (Cieslak-Morse-V-J, JoF 2019) | Historical pattern **solid**, forward-tradability **shaky** | The clean "long even / flat odd" *trading rule*, the 3-sub-period OOS robustness, and the exact structural cause were all **refuted (1-2)** in adversarial voting; ~50% post-publication decay. **We already have it** (QM5_10260 → Q08 FAIL_HARD). |
| **Carry (FX)** (Koijen-Moskowitz-Pedersen-Vrugt, JFE 2018) | Measurable, but **weak on our universe** | The 0.6–0.9 / 1.5 Sharpe is **gross + cross-asset**. On 4 FX majors it collapses toward a USDJPY/EURUSD rate-differential bet — too few legs to diversify, plus crash skew. |
| **Currency momentum** (Menkhoff et al., JFE 2012) | **Low priority** | The ~10% spread lives in high-idio-vol, illiquid, high-country-risk currencies (limits-to-arbitrage). FX majors sit in the low-return bucket; post-2010 OOS deteriorating. |
| **Time-series momentum** (Moskowitz-Ooi-Pedersen 2012) | **Contested — yellow flag** | Huang et al. (2020): correct bootstrap shows pooled t=4.34 is **insignificant**; TSM ≈ a no-predictability long-bias strategy. **We already have it** (QM5_1056 → died Q08). |
| **Pre-FOMC announcement drift** (Lucca-Moench 2015) | **Dead — do NOT build** | 49bp/24h pre-2015 → ~9bp insignificant post-2015 (Kurov-Wolfe-Gilbert 2021). Largely arbitraged. |
| **Overnight S&P 2–3pm ET drift** (NY Fed SR917) | **Failed verification** | Refuted 1-2; excluded. |

## The pivotal finding: the cards already exist — we just haven't BUILT them

Cross-checking the research families against the card reservoir overturns the premise that we
need *new* research. **Every near-zero-parameter structural family is already carded** — and
the best ones are **sitting UNBUILT in the 668-card backlog** while the funnel spent 717 builds
on (mostly generic) other cards:

| Research family | Verdict | Existing cards | Build status |
|---|---|---|---|
| **Turn-of-month** (flow-driven) | defensible — worth testing | QM5_1049, 10763, 10888, 10892, 11371 | **ALL UNBUILT** |
| FOMC-cycle | have it; forward shaky | 10260 (tested→Q08 FAIL_HARD), 10768, 1094, 10891 | 3/4 UNBUILT |
| Carry | weak on our universe | 10027, 1067, 1091, 1095, 10865, 10884 … (12+) | mostly UNBUILT |
| Seasonal / weekend | un-adjudicated | 1047, 10765 (gold), 1085, 1158, 10013 | mostly UNBUILT |
| **Overnight / pre-FOMC** | **research = DEAD** | 10020, 10324, 1130, 1146, 10891 | mixed |
| **TSM** | **research = contested** | 1056 (died), 10145, 1126 | mixed |

**So the lever is not "better research input" — it is "evidence-guided PRIORITIZATION of the
input we already have."** We don't lack good structural ideas; we lack a triage that builds the
defensible ones first and stops wasting cycles on the research-dead ones.

## Recommendation — triage the reservoir, don't add to it

1. **Recalibrate the mission math.** At ~1 survivor/700 with the famous edges tapped, ≥5
   anticorrelated survivors is a long grind. The honest lever is **fewer, higher-quality,
   structurally-distinct, evidence-prioritized attempts** — not volume, and not more cards.
2. **Force-forward the defensible, UNBUILT, near-zero-parameter structural cards** so they get
   tested next instead of languishing — top of the list: the **turn-of-month cohort**
   (QM5_1049 mcconnell-turn-of-month is the cleanest, flow-driven, never built), plus the
   un-adjudicated seasonal/calendar sleeves (gold-monthly-seasonal, sell-in-May, weekend). These
   are diverse from our one NDX-momentum candidate and from each other.
3. **Deprioritize / stop building the research-dead families** — pre-FOMC drift, overnight S&P
   drift, TSM-on-our-universe, currency-momentum-on-majors. Building these burns throughput on
   edges the literature says are gone/contested.
4. **Commission a focused follow-up research sweep** ONLY on the genuinely un-adjudicated flow
   families (turn-of-month confirmation, OPEX/triple-witching, Treasury-auction cycle, gold
   real-rate) — that is where a *fresh* near-zero-param edge could still hide. The famous-anomaly
   well is now mapped as mostly dry; do not re-research it.

> Net: producing new cards here would only **duplicate** a rich existing reservoir. The value
> this initiative delivers is the **evidence-based triage** above — which existing cards to build
> first, and which to stop building.

## ★ The systemic root cause: build-priority buries low-frequency structural edges

Investigating *why* the turn-of-month / FOMC / seasonal cards are all unbuilt surfaced the real
mechanism — and it is a **self-defeating bias in the build-priority itself**, not bad luck:

- `strategy_priority.metrics_component` weights **frequency at 0.5** of the expected-metrics
  signal, tuned so `expected_trades_per_year_per_symbol` ≥200 → 1.0, 100 → 0.5, 50 → 0.25
  (OWNER 2026-06-03: pull high-frequency cards forward to clear Q08's absolute 50/100/200 trade
  thresholds).
- But the **most-survivable edge class** — near-zero-parameter structural calendar/seasonal/macro
  edges (turn-of-month ≈12 trades/yr, FOMC-cycle, sell-in-May) — is **intrinsically
  low-frequency**. They score ≈0 on the frequency sub-signal → low metrics → low build priority →
  **they never get built**, while higher-frequency (often generic, overfit-prone) cards build
  first.

**The pipeline is fighting itself:** the build-priority optimizes for Q08-clearing *frequency*,
but the forensics show the edges that actually *survive* Q08/Q04 are the low-frequency structural
ones. The frequency bias systematically buries exactly the cards we most want tested. (Note:
DL-070 already relaxed Q08's *thresholds* for swing/low-freq EAs — but that fix is downstream;
these cards never reach Q08 because the *build* priority filters them out first.)

A per-card metric tweak cannot fix this (frequency is 50% of the metrics weight and dominates;
conservative `expected_pf` estimates actually *lower* a card's score below the unpopulated
neutral). The fix is systemic — one of:
1. a **dedicated low-frequency / structural-edge build track** that bypasses the frequency bias
   (analogous to DL-070's swing track at Q08), or
2. **reduce the frequency weight** in `metrics_component` (it over-rewards trade count as a proxy
   for robustness, which the data contradicts), or
3. OWNER explicitly **force-forwards a curated batch** of the defensible low-freq structural cards
   (turn-of-month, sell-in-May, weekend, gold-seasonal, the un-built FOMC variants) past the
   priority queue for a dedicated test cohort.

This is the highest-leverage, lowest-cost action available: it does not require new research or new
cards — only letting the structurally-robust cards we already have actually reach the factory.

## Sources (top-tier, kept claims)
Cieslak-Morse-Vissing-Jorgensen (JoF 2019); Kroencke-Schmeling-Schrimpf (JME 2021);
Koijen-Moskowitz-Pedersen-Vrugt (JFE 2018); Menkhoff-Sarno-Schmeling-Schrimpf (JFE 2012);
Moskowitz-Ooi-Pedersen (JFE 2012) vs Huang-Li-Wang-Zhou (JFE 2020); Lucca-Moench (JoF 2015)
vs Kurov-Wolfe-Gilbert (Fin. Res. Letters 2021); Erb-Harvey "Golden Dilemma". Full claim-level
evidence + vote tallies in the run transcript (`wunkn9s33`).
