# QM5_9928_ff-d1-elasticity-m15 - Strategy Spec

**EA ID:** QM5_9928
**Slug:** ff-d1-elasticity-m15
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved ForexFactory trading-systems source)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M15 pullback reversals when the M15 stochastic is stretched away from the H4 stochastic and then turns back from an extreme. A long requires positive H4 stochastic slope, M15 %K at least 35 points below H4 %K, and either a cross back above 20 or an 8-point two-bar turn upward; a short mirrors those rules above 80. Price must also confirm with a recent 20-bar swing sweep and higher/lower follow-through close, or a 45%-62% retracement of the prior H1 impulse leg. Exits occur at a 1.5R target, an opposite stochastic extreme, a 24-bar M15 time stop, or framework Friday close; after 1R the EA moves to breakeven and trails by 1 ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_stoch_k_period | 14 | 2-100 | Stochastic %K period used on M15, M30, H1, and H4. |
| strategy_stoch_d_period | 3 | 1-50 | Stochastic %D period. |
| strategy_stoch_slowing | 3 | 1-50 | Stochastic slowing value. |
| strategy_elasticity_points | 35.0 | 0-100 | Minimum M15-vs-H4 stochastic distance. |
| strategy_turn_points | 8.0 | 0-100 | Minimum two-bar stochastic turn when no threshold cross occurs. |
| strategy_oversold | 20.0 | 0-50 | Bullish stochastic recovery threshold. |
| strategy_overbought | 80.0 | 50-100 | Bearish stochastic recovery threshold. |
| strategy_h4_slope_bars | 3 | 1-20 | Number of closed H4 bars used for H4 slope. |
| strategy_h4_flat_low | 45.0 | 0-100 | Lower bound of the flat H4 no-trade zone. |
| strategy_h4_flat_high | 55.0 | 0-100 | Upper bound of the flat H4 no-trade zone. |
| strategy_h4_flat_slope_points | 3.0 | 0-100 | Maximum absolute H4 slope treated as flat. |
| strategy_swing_lookback | 20 | 2-200 | M15 swing high/low lookback for sweep confirmation. |
| strategy_sweep_window | 8 | 2-50 | Most recent M15 bars searched for a sweep. |
| strategy_h1_impulse_lookback | 24 | 3-200 | H1 bars used to define the prior impulse leg. |
| strategy_retrace_min_pct | 45.0 | 0-100 | Minimum H1 impulse retracement percentage. |
| strategy_retrace_max_pct | 62.0 | 0-100 | Maximum H1 impulse retracement percentage and SL anchor. |
| strategy_atr_period | 14 | 1-100 | ATR period for SL buffer and trailing. |
| strategy_sl_atr_buffer | 0.35 | 0.01-10 | ATR buffer beyond sweep or retracement anchor. |
| strategy_tp_rr | 1.5 | 0.1-10 | Initial take-profit multiple of initial risk. |
| strategy_max_hold_bars | 24 | 1-500 | M15 bars before time-stop exit. |
| strategy_trail_atr_mult | 1.0 | 0.1-10 | ATR trailing multiplier after 1R. |
| strategy_be_buffer_pips | 0 | 0-100 | Breakeven stop buffer in pips after 1R. |
| strategy_max_spread_points | 0 | 0-10000 | Optional spread cap; 0 disables the added spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX pair with native DWX data.
- GBPUSD.DWX - Card-listed major FX pair with native DWX data.
- USDJPY.DWX - Card-listed major FX pair with native DWX data.
- XAUUSD.DWX - Card-listed liquid metal symbol with native DWX data.

**Explicitly NOT for:**
- SP500.DWX - The card is an FX/metals stochastic elasticity strategy, not an equity-index sleeve.
- NDX.DWX - Not listed by the card's R3 portable basket.
- WS30.DWX - Not listed by the card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | M30, H1, and H4 stochastic; H1 impulse leg |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 24 M15 bars, usually shorter on 1.5R or stochastic extreme |
| Expected drawdown profile | Medium; ATR-buffered reversal entries after sweeps and pullbacks |
| Regime preference | Pullback-reversal after stochastic elasticity and local liquidity sweeps |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/post/15602401 and https://www.forexfactory.com/thread/post/15512747
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9928_ff-d1-elasticity-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 180fb8fb-e463-4cf5-afba-0f0ca7816316 |
