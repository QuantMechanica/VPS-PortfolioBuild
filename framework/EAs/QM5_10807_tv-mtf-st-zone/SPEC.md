# QM5_10807_tv-mtf-st-zone - Strategy Spec

**EA ID:** QM5_10807
**Slug:** tv-mtf-st-zone
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (TradingView script `MTF Supertrend Zones + Perfect Entries`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA evaluates closed M15 bars with H1 and H4 confirmation. A buy zone exists when the closed M15 bar is above EMA(200), EMA(200) is rising over 20 bars, and M15/H1/H4 SuperTrend(10, 3.0) are all bullish; a sell zone is the exact inverse. It enters after the closed bar pulls back to within 0.5 ATR(14) of EMA(200), forms a candle whose real body is at least 60% of its range, and breaks the prior candle high for longs or low for shorts. The initial stop is the farther of the pullback swing extreme over the last 5 closed bars or 1.5 ATR(14), with a 2.0R target; open positions close on an opposite zone, SL, TP, news gate, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_tf` | `PERIOD_CURRENT` | MT5 timeframe enum | Entry timeframe; P2 setfiles run the EA on M15 per the card. |
| `strategy_confirm_tf_1` | `PERIOD_H1` | MT5 timeframe enum | First higher-timeframe SuperTrend confirmation. |
| `strategy_confirm_tf_2` | `PERIOD_H4` | MT5 timeframe enum | Second higher-timeframe SuperTrend confirmation. |
| `strategy_supertrend_period` | `10` | `>=1` | ATR period for each SuperTrend state. |
| `strategy_supertrend_mult` | `3.0` | `>0` | ATR multiplier for each SuperTrend state. |
| `strategy_supertrend_warmup` | `160` | `>= strategy_supertrend_period + 10` | Closed-bar warmup depth for bounded SuperTrend reconstruction. |
| `strategy_ema_period` | `200` | `>=1` | EMA baseline period. |
| `strategy_ema_slope_bars` | `20` | `>=1` | Bars between current and prior EMA values for slope. |
| `strategy_atr_period` | `14` | `>=1` | ATR period for pullback tolerance and stop distance. |
| `strategy_pullback_atr_mult` | `0.5` | `>0` | Maximum distance from EMA(200) for pullback qualification. |
| `strategy_body_threshold` | `0.60` | `0.0-1.0` | Minimum candle body divided by high-low range. |
| `strategy_swing_lookback_bars` | `5` | `>=1` | Pullback swing low/high lookback used for structure stop. |
| `strategy_stop_atr_mult` | `1.5` | `>0` | ATR fallback stop distance. |
| `strategy_target_rr` | `2.0` | `>0` | Fixed reward-to-risk target. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with portable EMA, ATR, SuperTrend, and candle structure data.
- `GBPUSD.DWX` - card-listed FX major with the same OHLC-derived indicator mechanics.
- `USDJPY.DWX` - card-listed FX major with the same MTF trend-pullback mechanics.
- `XAUUSD.DWX` - canonical DWX form of the card's `XAUUSD` gold target.
- `GDAXI.DWX` - available DAX custom symbol used in place of card alias `GER40.DWX`.
- `NDX.DWX` - card-listed US index CFD for liquid trend-continuation testing.
- `WS30.DWX` - card-listed US index CFD for liquid trend-continuation testing.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.
- `XAUUSD` - unsuffixed card alias; registered as `XAUUSD.DWX` per DWX symbol discipline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `M15`, `H1`, `H4` SuperTrend; M15 EMA(200), ATR(14), and candle structure |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Expected trade frequency | `intraday, several trades per month per symbol` |
| Typical hold time | `intraday to multi-session, governed by opposite zone or 2.0R target` |
| Expected drawdown profile | `trend-continuation pullback losses cluster in mixed or reversing regimes` |
| Regime preference | `MTF trend-continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/gVJCLWCr-MTF-Supertrend-Zones-Perfect-Entries/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10807_tv-mtf-st-zone.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3%-0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-14 | Initial build from card | f74962a9-9b88-4e81-b176-bcc76a6970fe |
