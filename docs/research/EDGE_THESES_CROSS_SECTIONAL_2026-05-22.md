# Edge Theses — Direction 1: Cross-Sectional Relative-Value FX

Date: 2026-05-22
Status: SCREENED — Direction 1 of the Edge Lab
Author: Claude (T1–T4, screen); breadth contributions T5–T6 by Gemini
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

## Breadth expansion (Gemini, screened by Claude)

Added by Gemini's breadth pass (router task `cdfb768f`). Claude screen verdict
appended to each.

### T5 — Bond-Yield Convergence (Real Carry)

- **Structural cause:** sovereign bond yield spreads are the primary driver of
  medium-term FX value. Spot FX often lags the 2-year yield spread due to local
  liquidity constraints or central-bank jawboning.
- **Price signature:** rank the 8 currencies by the rolling 12-month z-score of
  their 2-year government bond yield relative to the G10 average. Long the top
  underperformer (spot below what the yield spread implies), short the top
  overperformer. Weekly rebalance.
- **Persistence:** structural lead-lag between fixed income and FX; high
  capital requirement for bond arbitrage keeps the FX convergence leg
  persistent.
- **Falsification:** if it does not outperform a buy-and-hold "basket of bonds"
  in non-crisis periods, the FX convergence edge is non-existent.
- **Q08 / Q11 risk:** yield spreads can decouple violently in a liquidity
  crisis (March 2020); mitigation: realized-vol gate.
- **FTMO fit:** swing horizon (D1), mean-reverting character mutes tail risk.
- **Claude screen — DEFERRED:** requires sovereign 2-year yield series for 8
  currencies. The farm holds FX / metals / energy / index *price* data, not
  bond yields. A data-feasibility check (charter "data feasibility") must clear
  before any build — without yield data this thesis is not testable here.

### T6 — Central-bank "expectations gap" reversion

- **Structural cause:** markets price in rate moves through the cross-section
  before they happen; once the move/guidance lands, the currency often reverts
  as the expectations gap closes ("buy the rumour, sell the fact").
- **Price signature:** identify the currency with the highest trailing 30-day
  cross-sectional strength ahead of its scheduled central-bank meeting; if the
  result matches consensus, enter a cross-sectional short against that gainer.
  Hold 5–10 days.
- **Persistence:** behavioural bias of over-anticipating policy shifts.
- **Falsification:** if the reversion signal has a <55% win rate over 5 years
  of CB events, the "priced-in" thesis is invalid.
- **Q08 / Q11 risk:** trades the aftermath of news — news-blackout-safe
  execution mandatory (no entry until the blackout expires).
- **FTMO fit:** decent; requires disciplined risk-on/off gating.
- **Claude screen — RECLASSIFIED to Direction 2:** the signal triggers off
  scheduled central-bank meetings, so it is an event-conditioned strategy, not
  a pure cross-sectional rank. Carry it into the Direction 2 (event-conditioned)
  thesis batch; not a Direction 1 build.

---

## Screen summary & build order

T1–T4 carry a real structural cause and fit the FTMO design box. They are
deliberately **complementary** — momentum (T1), filtered carry (T2), reversion
(T3), risk-rotation (T4) have low mutual correlation, which is the
diversification mission.

Build order: **T1 → T2** first (flagship + the Q08-survival test), then
**T3 → T4** as the diversifying legs. Each as a 2–3 variant family per the
charter.

Breadth: **T5 deferred** pending a bond-yield data-feasibility check; **T6
moved to Direction 2** (event-conditioned).

Discarded without build:

- Naked carry — fails Q08 by construction; only the filtered T2 form proceeds.
- Pure PPP / value cross-section — horizon too slow for swing, weak
  signal-to-noise at our data length.
