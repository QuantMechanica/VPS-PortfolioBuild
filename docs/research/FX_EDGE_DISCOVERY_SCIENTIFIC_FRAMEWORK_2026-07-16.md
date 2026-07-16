# A Scientific Framework for Discovering Persistent FX Edges (QM V5)

Author: Claude, 2026-07-16. Purpose: replace pattern-mining with a first-principles, statistically
honest program for finding edges that survive **out-of-sample AND costs**. Pass 1 = theory + our
empirics; Pass 2 folds in the parallel literature surveys (carry/momentum/flow; DSR/PBO methodology).

---

## Part I — The null hypothesis is brutal (and quantifiable)

FX majors are among the most liquid, arbitraged markets on earth. The correct prior is the
**martingale**: log-price ≈ random walk, one-step returns ≈ unpredictable. Any backtested edge must
beat three quantitative hurdles simultaneously.

### I.1 Selection bias — the killer for a strategy farm
If we test **N** independent zero-edge strategies, the *best* one's in-sample Sharpe is not ~0 — it is
the maximum of N noise draws. For iid standard-normal test statistics,

    E[max of N] ≈ √(2 ln N) − (ln ln N + ln 4π) / (2√(2 ln N)).

Concretely (leading term):

| N trials | best random Sharpe (σ above 0) |
|---|---|
| 100 | ≈ 3.0 |
| 1,000 | ≈ 3.7 |
| 10,000 | ≈ 4.3 |

**We run thousands of trials.** So a raw in-sample Sharpe of 3–4 is *the expected noise ceiling*, not
evidence. This single fact invalidates naive "best backtest wins" — and is exactly why the farm needs
DSR/PBO (Part II). It also means: **every extra trial raises the bar** the survivor must clear.

### I.2 Sharpe estimation error
Even for one strategy, the Sharpe estimate is noisy. Under Lo (2002), for T return observations with
skew γ3 and kurtosis γ4,

    SE(SR̂) ≈ √( (1 − γ3·SR + (γ4−1)/4·SR²) / T ).

For iid normal this reduces to √((1 + SR²/2)/T). Implication: to distinguish a *true* SR = 0.5 from 0
at 95% you need T on the order of ~30–60 *independent* periods. Low-frequency strategies are
data-starved by construction — which is why our Q08 LOW_SAMPLE flags fire on D1 swing sleeves (and why
OWNER's 6-trades/yr admissibility is a statement about *tolerating* that estimation error, not ignoring it).

### I.3 The cost hurdle (why FX high-frequency is a trap)
Let gross per-trade edge = e (in return units), cost per round-trip = c, trades per year = f, per-trade
return vol = σ_t. Then

    net annual μ  = f · (e − c),
    net Sharpe   ≈ √f · (e − c) / σ_t.

Two consequences: (1) if e < c the strategy is net-negative **no matter how good the win rate looks
gross** — this is precisely how ICT-FVG_CE (89 gross trades, PF ~1.04) and most retail scalps die on
FX where c ≈ $45/round-trip. (2) Frequency multiplies Sharpe **only when e − c is robustly positive**;
otherwise frequency multiplies the *loss*. Corollary: on FX, **prefer low-frequency structural edges**
where c is a small fraction of e — which is exactly the shape of our survivors.

---

## Part II — The correct statistics for a farm (DSR / PBO)

The remedy for I.1–I.2 is to deflate for the number of trials and test out-of-sample rank stability.

### II.1 Deflated Sharpe Ratio (Bailey & López de Prado 2014)
Given N trials with observed trial-Sharpe variance V, the expected maximum Sharpe under the null is

    SR0 ≈ √V · [ (1 − γ)·Z⁻¹(1 − 1/N) + γ·Z⁻¹(1 − 1/(N·e)) ],   γ = Euler–Mascheroni ≈ 0.5772,

and the deflated statistic is

    DSR = Z( (SR̂ − SR0)·√(T−1) / √(1 − γ3·SR̂ + (γ4−1)/4·SR̂²) ),

where Z is the standard-normal CDF. DSR is read as **P(true SR > 0)** after accounting for trials,
track length, and non-normality. A candidate should clear DSR ≥ ~0.95. **SR0 grows with N** → the farm's
acceptance bar must scale with how many configs a family tried. This is the formalization of "the more
we search, the more we must demand."

### II.2 PBO via CSCV
Split the sample into S even blocks, form all C(S, S/2) train/test partitions, pick the in-sample-best
config each time, and record its *out-of-sample rank*. **PBO = fraction of partitions where the IS-best
lands below the OOS median.** PBO > 0.5 means selection is overfit. This is our Q08.7 gate; its INVALIDs
in the requal cohort are a tooling defect (degenerate baseline), not high PBO — see the Q08 root-cause doc.

### II.3 Minimum Track Record Length
To assert SR > SR0 at confidence 1−α,

    MinTRL = 1 + [ 1 − γ3·SR + (γ4−1)/4·SR² ] · ( Z_α / (SR − SR0) )².

For small (SR − SR0) this explodes — a quantitative statement of "low-edge strategies are unprovable
in finite data." Design implication: **hunt for larger, structural effect sizes, not marginal ones.**

---

## Part III — Where PERSISTENT edges actually live (arbitrage-limits taxonomy)

An efficient market removes free edges, so a *persistent* edge must have a reason arbitrage does **not**
close it. Every candidate must name its reason. The families:

1. **Risk premia (compensated, not free).** Carry / forward-premium: long high-yield, short low-yield.
   Survives because it pays for **crash risk** (currencies unwind violently). Mechanizable on D1 from
   rate differentials; must be regime-filtered (kill in risk-off). Sharpe historically ~0.5–0.8 gross,
   fat left tail. *This is a risk premium, not an anomaly — the most robust family.*
2. **Microstructure / flow.** Real-money flows create predictable, recurring pressure:
   - **Calendar flows** — Japanese *Gotobi/Nakane* days (5,10,15,20,25,30: exporters buy USDJPY at the
     ~09:55 Tokyo fix). **This IS our sleeve 12969.** Real mechanism, low freq, low cost.
   - **Month-end / fixing rebalancing** (WMR 4pm London): index/hedge rebalancing forces FX flow;
     predictable direction from the month's equity/bond move.
   - **Options expiry / barriers**: pinning and defended levels near large strikes.
   Survives because the flow is **non-discretionary and price-insensitive** (it must transact).
3. **Cross-sectional relative value / cointegration.** Related pairs share drivers (AUDUSD~NZDUSD via
   commodities; EUR~GBP via Europe). Divergences mean-revert. **This is our one clean FX survivor** and the
   multicurrency-basket work-item (10717). Survives because the arb is **capital-intensive and carries
   divergence risk** (limits to arbitrage, Shleifer–Vishny).
4. **Event-driven.** Scheduled macro (NFP/CPI/central banks): predictable vol and positioning unwinds.
   Directional edge is thin and infra-hungry; treat as a *filter/vol* input, not a standalone directional bet.
5. **Session / time-of-day structure.** Real, but overwhelmingly a **volatility** structure, not a
   **directional** one. This is the theoretical reason ICT/retail-TA session models fail: they read a
   directional edge into what is only a vol/liquidity pattern.

**Meta-principle:** if a candidate cannot name a risk premium, a non-discretionary flow, or a
capital/limits-to-arbitrage reason, its prior of being real ≈ the I.1 noise ceiling. Chart shapes
(ICT FVG, Wyckoff springs, harmonic patterns) name none → correctly near-zero survival.

---

## Part IV — Our own funnel already confirms the theory

Empirical validation from the QM funnel (this is the strongest evidence we have):

| Outcome | Strategy | Taxonomy class | Verdict |
|---|---|---|---|
| **SURVIVES** | 12969 Gotobi/Nakane USDJPY | calendar flow (III.2) | real mechanism |
| **SURVIVES** | AUDUSD~NZDUSD cointegration | cross-sectional RV (III.3) | "the one survivor" |
| **SURVIVES** | Balke range-breakout DE40 (→Q07) | index intraday liquidity structure | first to clear Q05 DD |
| **DIES** | ICT icy-tea core + variants | session/chart pattern (III.5) | pooled PF 0.89, no edge |
| **DIES** | Wyckoff spring / ICT first-swing / Silver Bullet | chart pattern | contra-indicator or none |
| **DIES** | FX high-freq generally | cost hurdle (I.3) | e < c |

The pattern is unambiguous: **survivors are structural (flow / RV / microstructure), deaths are
chart-pattern or cost-killed.** ~88% die at Q04 — correctly. Our own data reproduces the taxonomy.

---

## Part V — The portfolio math: orthogonality beats standalone Sharpe

The book's objective is **portfolio** Sharpe, not sleeve Sharpe. Marginal contribution of sleeve i:

    ∂SR_p / ∂w_i  ∝  μ_i − SR_p · (Σ w)_i / σ_p.

A **low-correlation** sleeve has small (Σw)_i, so it improves the portfolio even with modest μ_i. The
diversification ratio DR = (Σ w_i σ_i) / σ_p is maximized by low pairwise correlation. This is the math
behind our 65%-diversification prioritization and the requal's ≤0.30 locked-window correlation gate:
**a mediocre orthogonal sleeve is worth more than a great correlated one.** It is also why "beat FX"
should mean *assemble many small independent structural edges*, not find one big directional signal.

---

## Part VI — The concrete research program (ranked by expected value)

1. **Systematically mine the surviving structural families** instead of chart patterns:
   - **Calendar/flow expansion** beyond 12969: month-end WMR-fix rebalancing, quarter-end, Gotobi across
     JPY crosses, options-expiry pinning. Low freq, low cost, named mechanism.
   - **Cross-sectional / cointegration baskets** (extend 10717): commodity-currency, European, and
     dollar-bloc clusters; rank-based relative value.
   - **Carry with a risk-off regime filter** (VIX/rate-vol/drawdown switch). A risk-premium anchor the
     book currently lacks.
2. **Institute the N-trials-scaled DSR gate** (Part II.1) as an explicit family-level acceptance layer on
   top of Q08, so the farm cannot promote the I.1 noise ceiling. Route the formula into the gate calc.
3. **Cost-first, low-frequency bias** in design (Part I.3): reject any FX idea whose per-trade gross edge
   does not clear cost by a robust margin *before* MT5 time is spent.
4. **Kill the retail-TA lane's priors.** ICT continues only under explicit OWNER direction (the Codex
   deep-dive), with a low prior; do not open new chart-pattern families without a named arbitrage-limit.
5. **Every new card must pre-register** thesis + arbitrage-limit + falsification (already a card field —
   enforce it as a gate, not a formality).

Expected effect: the farm's throughput shifts from mining noise (high N, low yield, Q04 graveyard) to
testing a *small number of high-prior structural hypotheses* — raising the survival rate and, via Part V,
compounding independent edges into a book that can actually beat FX after costs.

---

---

## Part VII — Pass 2: literature-grounded FX-family ranking (cited)

Two parallel surveys (peer-reviewed FX predictability; DSR/PBO methodology) corroborate and sharpen the
above. FX families ranked by (persistence × mechanizability × survives ~$45/4.5-pip round-trip):

| Rank | Family | Verdict for our stack |
|---|---|---|
| 1 | **Carry / dollar-carry** (Lustig-Roussanov-Verdelhan; Menkhoff 2012a) | **BUILD** — defended risk premium (loads on global FX vol; crash tail). Gross SR 0.5–0.9, decayed post-2008 but alive. Low turnover clears cost. Gap: needs a rate-differential table (no native MT5 feed; swap deferred in our stack). |
| 2 | **Month/quarter-end rebalancing** (Melvin-Prins 2015) | **BUILD (card drafted)** — public but *structurally sticky* mandate flow; prior-month equity return → month-end USD strength. ~12–24 tr/yr → most cost-friendly directional calendar edge. |
| 3 | FX value (real-ER; Menkhoff 2017) | Overlay with carry, not standalone — needs external real-ER/PPP data. |
| 4 | Cointegration RV (AUDUSD~NZDUSD only) | Cautious — our one survivor, but regime-fragile (≈4σ in 2 sessions, COVID) + 2-leg cost. One justified pair, hard stop. |
| 5 | FX momentum (Menkhoff 2012b) | **Thin** — ~50% post-publication decay; SR 0.66 IS → 0.06 net-of-cost; juice trapped in expensive EM. |
| 6 | **Gotobi USDJPY (our 12969!)** | ⚠️ borderline vs the ~6–7-pip JPY hurdle — literature flags marginal/leaking. **Re-check 12969's net cost-cushion.** |
| DEAD | Order-flow (Evans-Lyons), WMR-fix scalp (killed by 2015 reform), options-barrier | Uncapturable/dead retail — **stop spending build cycles here.** |
| Filter-only | Session / time-of-day | **Volatility, not direction** — free timing/sizing layer, never a signal. This is the theoretical reason ICT/retail-TA session models fail (Part III.5). |

## Part VIII — Pass 2: the acceptance protocol (formula-precise, farm-native)

The farm **logs every trial's Sharpe**, so the two quantities the honest statistics need — trial count `N`
and trial-Sharpe variance `V` — are *measured*. Hierarchical protocol, each level deflated **exactly once**:

    trial    → point SR̂ + Lo/Mertens SE:  SE(SR̂)=√((1−γ3·SR̂+(γ4−1)/4·SR̂²)/T)
    (EA,sym) → length gate T≥MinTRL  +  CPCV(purge+embargo) OOS-median SR>0  +  DSR≥0.95
    family   → PBO≤0.10 via CSCV      +  champion DSR≥0.95 vs SR0(N_eff,V)
    book     → fresh portfolio DSR(N_families,V_families)  +  Romano-Wolf set selection

- **DSR** = Z[(SR̂−SR0)√(T−1)/√(1−γ3·SR̂+(γ4−1)/4·SR̂²)], with the chance-max
  **SR0 = √V·((1−γ)·Z⁻¹(1−1/N) + γ·Z⁻¹(1−1/(N·e)))**, γ=0.5772. SR0 grows like √V·√(2 ln N) → **the bar
  rises automatically with search intensity.**
- **★N_eff, not raw N** (biggest calibration point): 1000 near-duplicate configs are not 1000 independent
  bets. Cluster trials by P&L correlation; use `N_eff`=#clusters in SR0, else you over-deflate and reject
  real edge. Report both N and N_eff.
- **PBO via CSCV**: fraction of combinatorial splits where the IS-best lands below the OOS median; PBO>0.5
  = the selection *process* is overfit. (Our Q08.7; its cohort INVALIDs are the degenerate-baseline tooling
  bug, not high PBO.)
- **Portfolio**: never sum per-sleeve Sharpes/DSRs; deflate once more at book level on `N_families`, and use
  **Romano-Wolf stepwise** to admit the *set* of sleeves (controls the chance of even one false admission)
  — which structurally rewards **orthogonal** sleeves (near-duplicates collapse under de-correlation).
- Thresholds: DSR≥0.95 (0.975 live), PBO≤0.10 (0.05 live), net-of-cost Sharpe throughout.

## Part IX — Pass 2: the concrete program (finalized)

1. **BUILD the two survivable families.** (a) **Month/quarter-end rebalancing** — card drafted
   (`CARD_DRAFT_MONTHEND_FX_REBALANCING_2026-07-16.md`), the top directional calendar edge, orthogonal to
   every current sleeve. (b) **Carry / dollar-carry** with a risk-off regime filter — needs a rate table;
   the book's missing risk-premium anchor.
2. **Institute the N_eff-deflated DSR + PBO family gate** on top of Q08 (the farm already logs the inputs).
   This is the single highest-leverage *methodology* upgrade: it stops the funnel from crowning the
   √(2 ln N) noise ceiling and makes every survivor verdict honest.
3. **Re-audit 12969 (Gotobi)** net cost-cushion — the literature flags it borderline vs the JPY hurdle.
4. **Stop build cycles on dead families** (order-flow, fix-scalp, options-barrier) and **de-prioritize
   momentum + retail-TA** (ICT/Wyckoff) — low prior, no named arbitrage-limit.
5. **Enforce the card's `thesis + arbitrage-limit + falsification` as a gate**, not a formality: no MT5 time
   until a candidate names WHY arbitrage leaves its edge open.

Sources (verified via the two surveys): Lustig-Roussanov-Verdelhan 2011/2014; Menkhoff-Sarno-Schmeling-
Schrimpf 2012a/2012b/2017; Melvin-Prins 2015; Evans-Lyons 2002; Ito-Yamada 2017 (fix reform); Bailey &
López de Prado 2012/2014 (PSR/DSR/MinTRL); Bailey-Borwein-LdP-Zhu 2014 (PBO/CSCV); White 2000; Hansen 2005;
Romano-Wolf 2005; López de Prado 2018 (CPCV/purge-embargo); Harvey-Liu-Zhu 2016 (t>3 hurdle).
