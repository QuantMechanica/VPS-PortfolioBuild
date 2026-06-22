# QM5_11315_tc-m5-8-triple-bb50-rsi3-stoch - Strategy Spec

**EA ID:** QM5_11315
**Slug:** `tc-m5-8-triple-bb50-rsi3-stoch`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades a 5-minute mean-reversion setup around three Bollinger Bands on SMA(50). A long setup requires the prior touch bar to reach or close below the BB(50,2) lower band with RSI(3) below 20 and Stochastic(6,3,3) below 20, then the confirmation bar must close back above the lower BB(50,2), with RSI back above 20 and Stochastic in an upward state near or above 40. A short setup mirrors this at the upper BB(50,2), with RSI above 80 and Stochastic above 80 on the touch bar, then a close back below the upper band with RSI below 80 and Stochastic in a downward state near or below 60. Take profit is the SMA(50) middle band; stop loss is the BB(50,3) band on the entry side, falling back to BB(50,4) if the confirmation candle already extends beyond BB(50,3), capped to 25 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 50 | 20-100 | Bollinger middle SMA period from the card and P3 sweep note. |
| `strategy_bb_dev_red` | 2.0 | 1.5-2.0 | Trade band deviation. |
| `strategy_bb_dev_yellow` | 3.0 | 2.0-3.0 | First stop band deviation. |
| `strategy_bb_dev_orange` | 4.0 | 3.0-4.0 | Fallback stop band deviation. |
| `strategy_rsi_period` | 3 | 2-14 | RSI exhaustion and recovery period. |
| `strategy_rsi_oversold` | 20.0 | 5-40 | Long-side RSI exhaustion threshold. |
| `strategy_rsi_overbought` | 80.0 | 60-95 | Short-side RSI exhaustion threshold. |
| `strategy_stoch_k` | 6 | 3-14 | Stochastic K period. |
| `strategy_stoch_d` | 3 | 1-7 | Stochastic D period. |
| `strategy_stoch_slow` | 3 | 1-7 | Stochastic slowing. |
| `strategy_stoch_oversold` | 20.0 | 5-40 | Long-side Stochastic exhaustion threshold. |
| `strategy_stoch_overbought` | 80.0 | 60-95 | Short-side Stochastic exhaustion threshold. |
| `strategy_stoch_long_confirm` | 40.0 | 20-60 | Long confirmation level for Stochastic. |
| `strategy_stoch_short_confirm` | 60.0 | 40-80 | Short confirmation level for Stochastic. |
| `strategy_sl_max_pips` | 25 | 5-50 | Maximum stop distance in pips for P2. |
| `strategy_width_spread_mult` | 1.5 | 0.5-5.0 | Skip dead-band conditions when BB(50,2) width is too small versus spread. |
| `strategy_spread_cap_pips` | 15.0 | 1-50 | Block only genuinely wide modeled spreads. |
| `strategy_session_start_gmt` | 13 | 0-23 | Start of London plus NY trading window in GMT/UTC hour. |
| `strategy_session_end_gmt` | 22 | 0-23 | End of London plus NY trading window in GMT/UTC hour. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-stated liquid FX major with M5 Darwinex data.
- `GBPUSD.DWX` - Card-stated liquid FX major with M5 Darwinex data.
- `USDJPY.DWX` - Card-stated liquid FX major with M5 Darwinex data.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - The card is an FX M5 system and does not call for index CFDs.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX` - Metals and energy are outside the card's stated FX instrument scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `140` |
| Typical hold time | Intraday, usually minutes to a few hours toward SMA(50) mean reversion |
| Expected drawdown profile | Short stops capped at 25 pips; losses cluster during strong directional breakouts |
| Regime preference | Mean-revert / oscillator reversal |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** book / PDF
**Pointer:** `Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), 5 Min Trading System #8`, local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11315_tc-m5-8-triple-bb50-rsi3-stoch.md`

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
| v1 | 2026-06-23 | Initial build from card | 80951b20-b5f6-4d7f-a62f-7b9ebc8312a8 |
