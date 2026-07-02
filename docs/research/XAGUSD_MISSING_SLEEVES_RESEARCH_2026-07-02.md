# XAGUSD Missing Sleeve Research — 2026-07-02

**Task:** 44ae5229 — R2 silver: XAGUSD solo mechanical edges (class fully absent from book)  
**Agent:** Claude  
**Date:** 2026-07-02

## Objective

Identify solo `XAGUSD.DWX` mechanical edges beyond the Donchian-55/ADX trend
(Idea #1 already drafted). Must be style-orthogonal to the MR-heavy book
(`QM5_12567_cum-rsi2-commodity`). Focus areas per task payload: silver-specific
volatility regimes, London fix behavior, industrial-demand momentum windows,
gold-lead/lag timing (as filter, not spread).

## Existing XAG Coverage (pre-task)

| ID | Slug | Style | Notes |
|---|---|---|---|
| 12568 | ichimoku-jpy-xag-trend | D1 trend | Multi-symbol basket, Ichimoku cross |
| 12577 | cme-xauxag-ratio | spread | XAU/XAG ratio — NOT solo |
| 12862 | xauxag-rspread | spread | XAU/XAG relative spread — NOT solo |

Solo XAGUSD strategies: effectively just 12568 (Ichimoku basket). The class is
nearly empty — all three new cards fill structurally distinct niches.

## Deliverables

Three strategy cards filed in `D:/QM/strategy_farm/artifacts/cards_review/`:

### QM5_12875 — Silver Q4 Industrial Demand Seasonal Long
- **File:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_12875_xag-q4-industrial-season.md`
- **Source:** The Silver Institute / Metals Focus, World Silver Survey 2024 (annual
  institutional publication documenting Q3-Q4 electronics/photovoltaic demand
  concentration); supplementary: Gorton & Rouwenhorst (2006) FAJ commodity seasonal
  risk premia.
- **Mechanic:** Long-only, active September 1–November 30. Entry when prior D1 close
  above SMA(40) AND SMA slope positive (SMA rising). ATR stop, SMA level exit,
  SMA slope exit, Dec 1 calendar exit.
- **Trades/yr:** ~2–5. **Style:** calendar/seasonal trend.
- **Ortho:** Q4 industrial demand is a silver-specific structural driver absent
  from gold/FX seasonal cards. No RSI. SMA slope requirement avoids entering
  counter-trend during bearish Q4 regimes.

### QM5_12876 — Silver Gold-Lead Momentum Entry
- **File:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_12876_xag-goldlead-mom.md`
- **Source:** Sjaastad & Scacciavillani (1996). The price of gold and the exchange
  rate. JIMF 15(6), 879-897; supplementary: Erb & Harvey (2006) FAJ commodity
  co-movement.
- **Mechanic:** Solo `XAGUSD.DWX` position only. Use XAUUSD D1 5-bar momentum
  (close[1]/close[6] - 1) as a directional filter: long XAGUSD if gold momentum
  > +threshold AND XAGUSD close > SMA; short XAGUSD if gold momentum < -threshold
  AND XAGUSD close < SMA. XAUUSD is indicator-only (no XAUUSD trade opened).
  ATR stop, SMA exit, max-hold exit.
- **Trades/yr:** ~15–25. **Style:** cross-asset directional filter.
- **Ortho:** Not a spread (only one position, XAGUSD). Gold used as a read-only
  indicator, consistent with V5 framework multi-timeframe indicator access.
  Momentum-directional, not RSI-based MR.

### QM5_12877 — Silver London Fix Window Reversion (H1)
- **File:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_12877_xag-london-fix-rev.md`
- **Source:** Caminschi & Heaney (2014). Fixing a Leaky Fixing: Short-Term Market
  Reactions to the London PM Gold Price Fixing. Journal of Futures Markets, 34(11),
  1109-1143; supplementary: LBMA, LBMA Silver Price documentation.
- **Mechanic:** H1 period. During London morning session (broker hours 08:00–14:00),
  if the H1 open deviates from the prior D1 close by more than `gap_atr` × ATR,
  enter counter-gap (fade the deviation). ATR stop, gap-fill exit, session-end exit,
  max-hold bars exit.
- **Trades/yr:** ~15–30. **Style:** event-conditioned H1 mean reversion (London fix
  window timing, not RSI).
- **Ortho:** H1 timeframe (vs D1 for 12567), session-specific, event-conditioned.
  Gap-fade on session open is structurally different from RSI2 oscillator pullback.
  No calendar trigger, no spreads.

## Gap Coverage

| Task requirement | Card delivered | Notes |
|---|---|---|
| Industrial-demand momentum windows | QM5_12875 | Q4 solar/electronics seasonal long |
| Gold-lead/lag timing as filter | QM5_12876 | Solo XAGUSD, XAUUSD = indicator only |
| London fix behavior | QM5_12877 | H1 London session gap reversion |
| Silver volatility regimes | (covered by Donchian-55/ADX, Idea #1 + 12568 Ichimoku) | Volatility regime = trend + breakout, covered by existing |

The Donchian-55/ADX idea (pre-drafted as Idea #1) covers a pure trend-following
approach. The three new cards here complement it across three different mechanisms:
seasonal calendar, cross-asset filter, and event-conditioned session reversion.

## Non-Duplication

Each new card is distinct from 12568 (Ichimoku basket), 12577/12862 (spreads),
and 12567 (RSI2 commodity MR). No overlap between the three new cards either:
12875 = D1 calendar long, 12876 = D1 cross-asset filter, 12877 = H1 session gap fade.

## R1–R4 Summary

| Card | R1 | R2 | R3 | R4 |
|---|---|---|---|---|
| 12875 | PASS (Silver Institute WSS + FAJ) | PASS (deterministic) | PASS (XAGUSD.DWX) | PASS (no ML) |
| 12876 | PASS (JIMF + FAJ peer-reviewed) | PASS (deterministic) | PASS (XAGUSD.DWX) | PASS (no ML, XAU indicator only) |
| 12877 | PASS (JFM peer-reviewed + LBMA) | PASS (deterministic) | PASS (XAGUSD.DWX H1) | PASS (no ML, no runtime fix feed) |
