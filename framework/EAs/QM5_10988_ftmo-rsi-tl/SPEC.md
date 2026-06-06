# QM5_10988_ftmo-rsi-tl - Strategy Spec

**EA ID:** QM5_10988
**Slug:** ftmo-rsi-tl
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades RSI(14) trendline breaks on H1. A long entry needs two descending RSI swing highs in the last 30 closed bars, an RSI close above the line through them, and a same-bar or next-bar close above EMA(20). A short entry mirrors this with two ascending RSI swing lows, a close below that line, and a same-bar or next-bar close below EMA(20). Exits are a 2.0R target, the protective stop, an RSI cross back through 50 against the position, or a 36-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | >=2 | RSI period used for swing and exit signals. |
| strategy_ema_period | 20 | >=2 | EMA period used for price confirmation. |
| strategy_atr_period | 14 | >=2 | ATR period used for volatility stop distance. |
| strategy_atr_sl_mult | 1.20 | >0 | ATR multiplier used in the stop comparison. |
| strategy_tp_r_multiple | 2.00 | >0 | Take-profit multiple of initial risk. |
| strategy_rsi_swing_lookback | 30 | >=6 | Closed H1 bars searched for RSI swing trendline points. |
| strategy_rsi_fractal_wing | 2 | >=1 | Bars on each side required to confirm an RSI swing. |
| strategy_stop_lookback | 10 | >=2 | Bars searched for recent structure high or low. |
| strategy_max_hold_bars | 36 | >=1 | Maximum holding time in H1 bars. |
| strategy_neutral_low | 45.0 | 0-100 | Lower bound of RSI neutral zone from the card. |
| strategy_neutral_high | 55.0 | 0-100 | Upper bound of RSI neutral zone from the card. |
| strategy_spread_lookback | 20 | >=3 | Closed bars used for median spread. |
| strategy_spread_median_mult | 1.50 | >0 | Maximum current spread versus 20-bar median spread. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major with DWX data available.
- GBPUSD.DWX - card-listed liquid FX major with DWX data available.
- USDJPY.DWX - card-listed liquid FX major with DWX data available.
- XAUUSD.DWX - card-listed liquid metal with DWX data available.

**Explicitly NOT for:**
- SP500.DWX - not in this card's R3 FX/metals basket.
- GDAXI.DWX - not in this card's R3 FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Up to 36 H1 bars |
| Expected drawdown profile | Fixed 1R risk with a 2R target; losses can cluster in choppy RSI regimes. |
| Regime preference | Momentum reversal / indicator breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** web article
**Pointer:** FTMO Academy, "RSI: Technical Indicator", 2025, https://academy.ftmo.com/lesson/rsi-technical-indicator/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10988_ftmo-rsi-tl.md`

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
| v1 | 2026-06-07 | Initial build from card | 525a7807-e60b-4a81-8911-1baac1b8303b |
