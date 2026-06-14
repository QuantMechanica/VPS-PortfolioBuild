# QM5_10814_tv-tetrad-bb - Strategy Spec

**EA ID:** QM5_10814
**Slug:** tv-tetrad-bb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades confirmed-bar Bollinger Band breakouts in the direction of a long moving-average filter. It buys when the last closed bar closes above the upper Bollinger Band after the prior bar was not above it, and that close is above SMA(200). It sells on the symmetric lower-band break when the close is below SMA(200). Positions exit when price closes back through the Bollinger middle band, breaks the opposite band, reaches the ATR stop, or exceeds the H1/H4 max-bar hold limit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_bb_period | 20 | 2+ | Bollinger Band lookback length |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band standard-deviation multiplier |
| strategy_sma_period | 200 | 2+ | Trend-filter SMA length |
| strategy_atr_period | 14 | 1+ | ATR lookback for initial stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for initial stop |
| strategy_middle_exit | true | true/false | Enable close-through-middle-band exit |
| strategy_max_bars_exit | true | true/false | Enable optional V5 max-bars exit |
| strategy_max_hold_bars_h1 | 96 | 1+ | H1 maximum holding period in bars |
| strategy_max_hold_bars_h4 | 60 | 1+ | H4 maximum holding period in bars |
| strategy_max_spread_points | 0 | 0+ | Optional hard spread cap in points; 0 disables this cap |
| strategy_max_spread_atr_pct | 0.10 | 0+ | Blocks entries when spread exceeds this share of ATR |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major liquid FX pair with continuous DWX OHLC history
- GBPUSD.DWX - major liquid FX pair with continuous DWX OHLC history
- USDJPY.DWX - major liquid FX pair with continuous DWX OHLC history
- XAUUSD.DWX - canonical DWX gold symbol for the card's XAUUSD basket member
- GDAXI.DWX - canonical DWX DAX symbol used for the card's GER40.DWX basket member
- NDX.DWX - liquid US large-cap index CFD for breakout testing
- WS30.DWX - liquid US large-cap index CFD for breakout testing

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX instead

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 and H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Hours to several days, capped at 96 H1 bars or 60 H4 bars |
| Expected drawdown profile | Choppy sideways ranges can produce repeated false breakouts |
| Regime preference | Volatility-expansion breakout with trend alignment |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView strategy page
**Pointer:** TradingView script `Tetrad - Elektro Community v1.0`, author handle `Elektro_Community`, strategy page visible on 2026-05-22
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10814_tv-tetrad-bb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-14 | Initial build from card | 34332697-e1e4-452d-9f89-bfb252c31312 |
