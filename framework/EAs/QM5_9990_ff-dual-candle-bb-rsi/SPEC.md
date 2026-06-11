# QM5_9990_ff-dual-candle-bb-rsi - Strategy Spec

**EA ID:** QM5_9990
**Slug:** ff-dual-candle-bb-rsi
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the H4 two-candle inside-bar pattern from the approved ForexFactory card. Candle A is bar 2 and Candle B is bar 1; Candle B must sit fully inside Candle A. A long setup requires Candle A to be bullish, both closes to sit between the Bollinger middle and upper bands, and RSI(14) on bar 1 to be above 50; it places a buy stop at Candle A high plus 1 pip, with stop at Candle A low minus 1 pip and TP at 3R. A short setup mirrors the rule below the Bollinger middle band with RSI below 50; open positions move to breakeven at 1R, trail by 1R after 2R, and close at TP3, Friday close, or an opposite setup.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >= 2 | Bollinger Bands period. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger Bands standard-deviation multiplier. |
| strategy_rsi_period | 14 | >= 2 | RSI period for the side filter. |
| strategy_rsi_midline | 50.0 | 0-100 | RSI threshold; longs require above it and shorts require below it. |
| strategy_atr_stop_period | 14 | >= 2 | ATR period used to reject stops wider than the card maximum. |
| strategy_atr_width_period | 20 | >= 2 | ATR period used for Bollinger width compression filtering. |
| strategy_max_stop_atr_mult | 3.0 | > 0 | Maximum allowed stop distance as a multiple of ATR(14,H4). |
| strategy_min_width_atr_mult | 0.8 | > 0 | Minimum Bollinger width as a multiple of ATR(20,H4). |
| strategy_entry_buffer_pips | 1.0 | > 0 | Entry and stop buffer around Candle A high/low. |
| strategy_tp_rr | 3.0 | > 0 | Full-position target in R multiples. |
| strategy_pending_expiry_bars | 3 | >= 1 | Pending stop order expiry measured in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with DWX H4 OHLC, Bollinger, RSI, and ATR data.
- GBPUSD.DWX - card-listed FX major with DWX H4 OHLC, Bollinger, RSI, and ATR data.
- AUDUSD.DWX - card-listed FX major with DWX H4 OHLC, Bollinger, RSI, and ATR data.
- USDJPY.DWX - card-listed FX major with DWX H4 OHLC, Bollinger, RSI, and ATR data.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved R3 basket is limited to four FX majors.
- FX symbols outside the approved R3 basket - not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 32 |
| Typical hold time | Not stated in frontmatter; mechanically exits at 3R, opposite setup, or Friday close after a pending order may wait up to 3 H4 bars. |
| Expected drawdown profile | Fixed-risk breakout system with one position per magic-symbol and Candle A structural stops capped at 3.0 ATR. |
| Regime preference | H4 volatility-expansion breakout after an inside-bar setup, filtered by Bollinger half-band location and RSI side. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** sak.mandhai, "Dual Candle Strategy", ForexFactory, 2020-06-13, https://www.forexfactory.com/thread/1005994-dual-candle-strategy
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9990_ff-dual-candle-bb-rsi.md`

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
| v1 | 2026-06-11 | Initial build from card | 5f1780f5-a108-499c-9a6e-cc9d60c9a551 |
