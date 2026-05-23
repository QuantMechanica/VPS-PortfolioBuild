# Edge Theses — Breadth Expansion (Directions 2, 3, 4)

Date: 2026-05-22
Status: DRAFT — Breadth pass for Edge Lab
Author: Gemini (Task 6442391b / e73db9a4)
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

This document expands the Edge Lab thesis bank beyond the initial Direction 1
(Cross-sectional FX) into Directions 2 (Event-conditioned), 3 (Calendar/Seasonal),
and 4 (SMC/Microstructure).

---

## Direction 2: Event-Conditioned (Expansion)

### T12 — Inflation (CPI) Surprise Drift

- **Structural cause:** Central banks react to inflation surprises to maintain
  price stability mandates. Market participants take hours or days to fully
  reprice the terminal rate path and adjust institutional portfolios.
- **Price signature:** On a "major" CPI release (USD, EUR, GBP), identify the
  surprise (Actual - Consensus). If the surprise exceeds 0.2% (absolute), enter
  a cross-sectional trade in the direction of the surprise AFTER the mandatory
  2-hour news blackout. Hold for 48 hours.
- **Persistence:** Institutional "friction" — large portfolios cannot rotate
  instantly without massive slippage; they execute over several sessions,
  creating the drift.
- **Falsification:** If the "drift" direction is no better than 50% win rate
  across a 5-year backtest of surprises, the "slow diffusion" thesis is false.
- **Q08 / Q11 risk:** High. Trades around news. Mandatory news-blackout compliance
  is the primary filter.
- **FTMO fit:** Strong, provided the blackout exit is disciplined.
- **Source:** "Inflation Surprises and the FX Market" (Standard macro-quant theme).

---

## Direction 3: Calendar / Seasonal Flow

### T13 — Month-End FX Rebalancing (Equity-Hedge Flow)

- **Structural cause:** International equity managers hedge their currency
  exposure. As stock markets in different regions diverge in performance during
  a month, managers must buy/sell FX at month-end to bring their hedge ratios
  back to mandate (e.g., if US stocks rally vs EU, managers must sell USD).
- **Price signature:** Compute the "rebalancing signal" = (MTD Return of S&P500)
  - (MTD Return of Stoxx 600). If signal > 0, sell USD/buy EUR. Execute in the
  final 2 trading days of the month; exit at the first London open of the new month.
- **Persistence:** Regulatory and mandate-driven institutional flow that occurs
  regardless of price; "price-insensitive flow".
- **Falsification:** If the signal direction is net-unprofitable over 60
  month-end cycles, the flow is either too small to trade or fully front-run.
- **Q08 / Q11 risk:** Low. Predictable calendar window.
- **FTMO fit:** Excellent. Swing horizon, low frequency, high conviction.
- **Source:** "FX Rebalancing" (Krohn and Sushko, 2022; BIS Papers).

### T14 — London Close "Fix" Liquidity Reversion

- **Structural cause:** The 4 PM London Fix is the benchmark for trillions in
  corporate and institutional flow. Banks executing large "at-best" orders often
  push price significantly past equilibrium in the minutes before the Fix.
- **Price signature:** Identify pairs that move >1.5 ATR(M15) in the 60 minutes
  leading up to 16:00 London time. Enter a reversion trade (against the move)
  at 16:30 London time, targeting 50% retracement. Hold until NY close.
- **Persistence:** Post-fix liquidity vacuum. Major participants exit after
  the fix, leaving a "thin" market prone to mean-reversion of the fix-driven
  imbalance.
- **Falsification:** If net-of-spread expectancy is ≤0, the "liquidity vacuum"
  is not deep enough to compensate for transaction costs.
- **Q08 / Q11 risk:** Low. Occurs daily, outside major release spikes.
- **FTMO fit:** Scalping/Intraday (M15). Requires tight spread broker.

---

## Direction 4: SMC / Microstructure (Mechanical)

### T15 — Liquidity Sweep + Fair Value Gap (FVG) Retest

- **Structural cause:** "Smart Money" (Institutional desks) requires liquidity
  to fill large orders. They frequently "sweep" the stops above/below visible
  swing points. The resulting aggressive move creates a "price imbalance" or
  Fair Value Gap (FVG) where price was not efficiently matched.
- **Price signature:** (1) Price breaks a previous 24-hour High/Low (Sweep) and
  immediately closes back inside. (2) Reversal move creates an FVG (gap between
  Candle 1 High and Candle 3 Low in a 3-candle sequence). (3) Enter Limit Order
  on the retest of the FVG.
- **Persistence:** Structural necessity of liquidity sourcing in a decentralized
  market.
- **Falsification:** If a "random sweep" of a random price level performs as
  well as a "structured sweep", the SMC thesis is merely pattern-matching noise.
- **Q08 / Q11 risk:** Moderate. High frequency. Requires strict news blackout.
- **FTMO fit:** Swing/Scalp. High R:R potential fits the 10% total DD constraint.
- **Source:** Mechanical SMC community standards (Inner Circle Trader concepts, mechanized).

---

## Verification & Build Recommendations

- **T12 (CPI)** and **T13 (Month-End)** are the highest conviction for Edge Lab.
  They have the strongest "structural causes" (Central Bank policy and institutional
  mandates).
- **T14 (London Close)** and **T15 (SMC)** are more technical/microstructure
  based and should be treated as "diversifiers" once the macro-theses are built.
- Recommended Build Order: **T13 → T12 → T15 → T14**.
