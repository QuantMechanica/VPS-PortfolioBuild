# QM5_10708_tv-crypto-ils - Strategy Spec

**EA ID:** QM5_10708
**Slug:** tv-crypto-ils
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades H1 liquidity-sweep reclaims in both directions. It uses EMA(200) for directional bias, then scans the configured recent pivot window for a confirmed pivot low or high that the latest closed bar pierces and reclaims. A long requires close above EMA(200), positive 20-bar linear-regression slope, a sweep below a pivot low, and a bullish candle closing in the upper 40% of its range. A short mirrors this below EMA(200), with negative slope, a sweep above a pivot high, and a bearish candle closing in the lower 40% of its range. Exits are fixed 1.5 ATR(14) stop, 2.0R take profit, framework Friday close, or a 48-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 200 | >= 2 | EMA period for trend bias. |
| strategy_ema_buffer_points | 0 | >= 0 | Optional point buffer around EMA; zero disables the buffer. |
| strategy_pivot_length | 5 | >= 1 | Bars on each side used to confirm a pivot high or low. |
| strategy_pivot_lookback_bars | 80 | >= pivot window | Maximum closed bars scanned for the most recent confirmed pivot. |
| strategy_linreg_period | 20 | >= 2 | Closed-bar period for linear-regression slope alignment. |
| strategy_atr_period | 14 | >= 1 | ATR period used for stop distance. |
| strategy_atr_sl_mult | 1.5 | > 0 | Stop distance as ATR multiple. |
| strategy_rr_target | 2.0 | > 0 | Take-profit reward/risk multiple. |
| strategy_max_stop_atr_mult | 3.5 | > 0 | Rejects trades whose stop distance exceeds this ATR multiple. |
| strategy_max_spread_stop_frac | 0.15 | > 0 | Rejects trades when spread exceeds this fraction of stop distance. |
| strategy_reversal_close_frac | 0.40 | 0-1 | Long closes must be in upper fraction of range; shorts in lower fraction. |
| strategy_time_stop_bars | 48 | >= 0 | Closes open positions after this many H1 bars; zero disables time stop. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq index CFD matches the card's DWX index port.
- GDAXI.DWX - DAX custom symbol available in matrix; used for card-stated GER40 exposure.
- XAUUSD.DWX - Gold CFD matches the card's metal port.
- EURUSD.DWX - Major FX pair named by the card and available in the matrix.
- GBPUSD.DWX - Major FX pair named by the card and available in the matrix.

**Explicitly NOT for:**
- GER40.DWX - not present in the matrix; use GDAXI.DWX for DAX exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday to two trading days; hard time stop after 48 H1 bars. |
| Expected drawdown profile | Stop-run reversal strategy with fixed 1.5 ATR risk and 2R target. |
| Regime preference | Trend-following reversal confirmation after liquidity sweeps. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script "Crypto Institutional Liquidity Sweep Strategy", author handle "Danish7421", published 2026-02-04, https://www.tradingview.com/script/ZhJzjmAk-Crypto-Institutional-Liquidity-Sweep-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10708_tv-crypto-ils.md`

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
| v1 | 2026-06-14 | Initial build from card | 2e80a243-17c5-4ef0-a6d3-6faaf4b5d8a5 |
