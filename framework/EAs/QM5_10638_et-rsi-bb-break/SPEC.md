# QM5_10638_et-rsi-bb-break - Strategy Spec

**EA ID:** QM5_10638
**Slug:** et-rsi-bb-break
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. A long setup exists when the prior day's low is above EMA(50) and RSI(8) closes below a 20-period, 2.0-deviation Bollinger lower band calculated on the RSI series; the next D1 session places a buy stop above the prior day's high unless the session opened above that high. Shorts mirror the rule below EMA(50), using RSI above its upper RSI Bollinger Band and a sell stop below the prior day's low unless the session opened below that low. Initial stop distance is 1.5 ATR(14), and after price touches +1.0 ATR from entry the EA moves risk to breakeven and trails by the prior 3 completed bars; any remaining position exits after 20 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 50 | 1+ | D1 trend filter EMA period. |
| strategy_rsi_period | 8 | 1+ | RSI period used for the signal. |
| strategy_rsi_bb_period | 20 | 2+ | Lookback for Bollinger Bands on the RSI series. |
| strategy_rsi_bb_deviation | 2.0 | >0 | Standard deviation multiplier for RSI Bollinger Bands. |
| strategy_atr_period | 14 | 1+ | ATR period for stop, target trigger, and volatility filter. |
| strategy_atr_stop_mult | 1.5 | >0 | Initial stop distance in ATR multiples. |
| strategy_atr_target_mult | 1.0 | >0 | First target trigger distance in ATR multiples. |
| strategy_atr_median_lookback | 20 | 1+ | ATR median lookback for the dead-range filter. |
| strategy_trail_lookback | 3 | 1+ | Prior completed bars used for structure trailing. |
| strategy_max_hold_bars | 20 | 1+ | D1 bars after which the time stop exits. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol matching the card's SPY/SPX thesis; backtest-only T6 caveat applies.
- NDX.DWX - liquid US large-cap technology comparator available in the DWX matrix.
- WS30.DWX - liquid US large-cap Dow comparator available in the DWX matrix.

**Explicitly NOT for:**
- Non-index single-stock symbols - the source says the setup worked better on ETFs than individual stocks.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Several trading days, capped at 20 D1 bars |
| Expected drawdown profile | Sparse swing breakout losses limited by ATR stop and breakeven/trailing after first target |
| Regime preference | Trend-aligned volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** D:\QM\strategy_farm\artifacts\cards_approved\QM5_10638_et-rsi-bb-break.md and Elite Trader thread "Trading Strategy" dated 2003-10-17
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10638_et-rsi-bb-break.md`

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
| v1 | 2026-06-13 | Initial build from card | a3bb0b44-48b3-42f6-afa7-79e0dcef1418 |
