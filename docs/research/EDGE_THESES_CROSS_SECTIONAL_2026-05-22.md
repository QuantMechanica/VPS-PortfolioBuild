# Edge Theses — Direction 1: Cross-Sectional Relative-Value FX

Date: 2026-05-22
Status: SCREENED — Direction 1 of the Edge Lab
Author: Claude / Gemini (expansion)
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

Universe: the liquid FX majors / crosses already in the farm (~28 pairs, 8
currencies: USD EUR GBP JPY CHF AUD NZD CAD). Cross-sectional = at each
rebalance, rank the universe by a signal and trade the spread between the top
and bottom ranks. The edge is **relative**, which mutes directional drawdown —
the reason this direction is the most FTMO-friendly and goes first.

---

## T1 — Cross-sectional FX momentum (relative-strength rotation)

- **Structural cause:** information about a currency's fundamentals diffuses
  slowly into price; investors under-react. Currencies strong over the past
  1–3 months tend to continue.
- **Price signature:** each week, rank the 8 currencies by trailing 1–3 month
  return (currency strength = mean return vs all others). Long the top 2, short
  the bottom 2 via the cleanest pairs. D1 bars, weekly rebalance.
- **Persistence:** documented (Menkhoff/Sarno/Schmeling/Schrimpf 2012);
  survives because it is compensation for crash risk and slow capital
  reallocation — not a free lunch.
- **Falsification:** if a long-bottom / short-top inversion is not
  significantly worse than the strategy, there is no momentum — only basket
  beta.
- **Q08 / Q11 risk:** momentum crashes at sharp regime turns (March 2020);
  needs a vol / turn filter. News-blackout-safe at D1 weekly cadence.
- **FTMO fit:** market-neutral-ish, smoother equity. Strong.
- **Verdict: BUILD — flagship of Direction 1.**

## T2 — Regime-filtered carry

- **Structural cause:** high-yield currencies pay a risk premium for bearing
  crash risk (carry).
- **Price signature:** rank by interest-rate-differential proxy; long
  high-yield, short low-yield — but only when a realized-vol / risk-on filter
  is green; flat otherwise.
- **Persistence:** the premium is real; the naked version fails Q08 because
  carry crashes in crises. **The filter is the thesis** — it attacks the known
  Q08 killer head-on.
- **Falsification:** if filtered carry's crisis-slice DD is not materially
  better than naked carry, the filter adds nothing → kill.
- **Q08 / Q11 risk:** the whole design is about surviving Q08. News-safe at
  swing horizon.
- **FTMO fit:** good IF the filter genuinely caps the left tail; without it,
  naked carry breaches the 10% total-DD box.
- **Verdict: BUILD — but the filter is on trial, not carry.**

## T3 — Cross-sectional short-horizon mean-reversion

- **Structural cause:** over a few days, currencies that overshoot the basket
  on liquidity / flow noise revert; over-reaction at short horizon.
- **Price signature:** rank by 3–5 day return residual vs the basket; long the
  biggest underperformer, short the biggest outperformer; hold 2–5 days.
- **Persistence:** a liquidity-provision premium; weaker and more
  cost-sensitive than momentum — spread / commission can eat it.
- **Falsification:** if net-of-cost expectancy is ≤0 at realistic FTMO spreads,
  kill. Cost realism is the gate here.
- **Q08 / Q11 risk:** mean-reversion catches falling knives in trending
  crises; needs a trend / vol veto.
- **FTMO fit:** decent, but cost-fragile. Complements T1 (different horizon,
  low correlation).
- **Verdict: BUILD as the third leg — explicitly to diversify T1.**

## T4 — Risk-regime safe-haven rotation

- **Structural cause:** in risk-off, capital flees to JPY / CHF / USD
  regardless of yield; risk sentiment dominates the cross-section.
- **Price signature:** a risk-off signal (vol expansion, equity-proxy
  weakness) rotates the book long JPY/CHF/USD strength vs AUD/NZD/CAD; flat or
  mild-momentum in risk-on.
- **Persistence:** structural — safe-haven demand is behavioural and
  persistent; not arbitraged because it is a hedge, not a profit machine.
- **Falsification:** if it does not produce positive PnL precisely in the Q08
  crisis slices, it has no reason to exist.
- **Q08 / Q11 risk:** this is the one thesis that should *win* Q08 — a natural
  portfolio hedge against T1 / T2.
- **FTMO fit:** good; low DD in exactly the periods the others bleed.
- **Verdict: BUILD — lower priority, high portfolio value as a hedge leg.**

---

## T5 — Bond-Yield Convergence (Real Carry)

- **Structural cause:** Sovereign bond yield spreads are the primary driver of medium-term FX value. Spot FX often lags the 2-year yield spread due to local liquidity constraints or central bank jawboning.
- **Price signature:** Rank the 8 currencies by the rolling 12-month z-score of their 2-year government bond yield relative to the G10 average. Long the top underperformer (where spot is lower than the yield spread implies), short the top overperformer. Rebalance weekly.
- **Persistence:** Structural lead-lag relationship between fixed income and FX. High capital requirement for bond arbitrage keeps the FX convergence leg persistent.
- **Falsification:** If the strategy does not outperform a simple "Basket of Bonds" buy-and-hold during non-crisis periods, the FX convergence edge is non-existent.
- **Q08 / Q11 risk:** Yield spreads can decouple violently in a liquidity crisis (March 2020). Mitigation: realized vol gate.
- **FTMO fit:** Strong. Swing horizon (D1), mean-reverting character mutes tail risk.

## T6 — Central Bank "Expectations Gap" Reversion

- **Structural cause:** Markets "price in" rate hikes through the cross-section before they happen. Once the hike occurs (or the guidance is issued), the currency often reverts as the "expectations gap" closes (Buy the rumor, sell the fact).
- **Price signature:** Identify the currency with the highest trailing 30-day cross-sectional strength *ahead* of its scheduled Central Bank meeting. If the meeting result (rate/guidance) matches consensus, enter a cross-sectional short against the strongest gainer of the prior month. Hold 5–10 days.
- **Persistence:** Behavioral bias of over-anticipating policy shifts.
- **Falsification:** If the reversion signal has a <55% win rate over 5 years of CB events, the "priced-in" thesis is invalid.
- **Q08 / Q11 risk:** High Q11 risk. This strategy trades the *aftermath* of news, but news-blackout-safe execution is mandatory (no entry until blackout expires).
- **FTMO fit:** Decent. Scalping/Swing horizon. Requires disciplined risk-on/off gating.
