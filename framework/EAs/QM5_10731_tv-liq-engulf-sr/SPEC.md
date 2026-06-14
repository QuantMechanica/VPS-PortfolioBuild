# QM5_10731_tv-liq-engulf-sr - Strategy Spec

**EA ID:** QM5_10731
**Slug:** tv-liq-engulf-sr
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a reversal after price touches an older liquidity level and the same or next closed M15 candle confirms with an engulfing candle. A long signal requires a touch of the lower liquidity level and a bullish engulfing close above the prior bearish candle high; a short signal mirrors this at the upper liquidity level with a bearish engulfing close below the prior bullish candle low. Stop loss is placed beyond the setup extreme by 0.1 ATR(14), take profit is 1.5R, and open positions can exit early on an opposite valid liquidity-engulfing signal or after 24 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_liquidity_lookback | 20 | 1+ | Closed bars used to define older upper and lower liquidity levels. |
| strategy_min_liquidity_age | 3 | 1+ | Most recent bars excluded so the touched liquidity level is older than 3 bars. |
| strategy_atr_period | 14 | 1+ | ATR period used for the stop-loss buffer. |
| strategy_sl_atr_buffer | 0.10 | 0+ | ATR multiple added beyond the setup high or low for stop placement. |
| strategy_tp_r_multiple | 1.50 | 0+ | Take-profit distance as a multiple of initial risk. |
| strategy_enable_time_exit | true | true/false | Enables the optional max-hold exit. |
| strategy_time_exit_bars | 24 | 1+ | Maximum hold duration in M15 bars when time exit is enabled. |
| strategy_max_spread_points | 0 | 0+ | Optional spread block in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-approved liquid FX major with DWX OHLC coverage for pivot and engulfing rules.
- GBPUSD.DWX - Card-approved liquid FX major with DWX OHLC coverage for pivot and engulfing rules.
- XAUUSD.DWX - Card-approved liquid metal symbol with DWX OHLC coverage for pivot and engulfing rules.
- NDX.DWX - Card-approved liquid index CFD with DWX OHLC coverage for pivot and engulfing rules.

**Explicitly NOT for:**
- Symbols outside the registered basket - no card approval or magic registration for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Up to 24 M15 bars, about 6 hours, unless SL/TP/opposite signal fires first |
| Expected drawdown profile | Fixed-risk reversal trades with stop beyond the liquidity sweep extreme |
| Regime preference | Liquidity-sweep reversal / mean reversion after failed breaks |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/xnV1EEYr-Liquidity-Engulfment-Strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10731_tv-liq-engulf-sr.md`

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
| v1 | 2026-06-14 | Initial build from card | db9a08b2-3e73-4a4e-aa4f-80b790505c07 |
