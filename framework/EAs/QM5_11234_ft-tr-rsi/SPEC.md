# QM5_11234_ft-tr-rsi - Strategy Spec

**EA ID:** QM5_11234
**Slug:** ft-tr-rsi
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

Long on H1 when the last closed bar is above EMA(200), RSI(16) crosses back above 35 from below, close is above the lower Bollinger Band, the candle closes bullish, tick volume is above 80% of its 20-bar average, and OBV is above its 20-period EMA. The EA exits on the source TrendRider long rules: RSI(16) above 78, EMA(9) crossing below EMA(16) with negative MACD histogram and RSI above 50, breakdowns below EMA(200) thresholds, or the card's 2h/4h/8h/16h/24h time exits. Stop distance is the tighter of the source 6% stop and 3.0x ATR(14), with a 3% trailing stop after +5% profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 9 | 2-100 | Fast EMA used in the EMA(9)/EMA(16) exit cross. |
| `strategy_ema_pullback` | 16 | 2-100 | Slow EMA used in the EMA cross exit. |
| `strategy_ema_trend_slow` | 200 | 20-400 | Trend EMA that price must close above for entry and uses for breakdown exits. |
| `strategy_rsi_period` | 16 | 2-100 | RSI period for entry and exit checks. |
| `strategy_rsi_bounce_level` | 35.0 | 1.0-99.0 | Oversold bounce threshold; RSI must cross up through this level. |
| `strategy_rsi_overbought` | 78.0 | 1.0-99.0 | Source overbought exit threshold. |
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band period for the lower-band entry filter. |
| `strategy_bb_deviation` | 2.0 | 0.1-5.0 | Bollinger Band deviation multiplier. |
| `strategy_volume_factor` | 0.80 | 0.0-5.0 | Minimum current tick-volume ratio versus its 20-bar average. |
| `strategy_volume_lookback` | 20 | 2-200 | Number of closed bars used for average tick volume. |
| `strategy_obv_ema_period` | 20 | 2-100 | OBV EMA period. |
| `strategy_obv_warmup_bars` | 220 | 50-500 | Closed bars used to seed OBV and its EMA. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the V5 emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 0.1-20.0 | ATR multiple used in the V5 emergency stop. |
| `strategy_source_stop_pct` | 6.0 | 0.1-50.0 | Source fixed stop loss in percent. |
| `strategy_trail_start_pct` | 5.0 | 0.1-100.0 | Profit threshold before source trailing activates. |
| `strategy_trail_pct` | 3.0 | 0.1-50.0 | Distance of the source trailing stop in percent. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX OHLC and tick-volume history.
- `GBPUSD.DWX` - card-listed liquid FX major with DWX OHLC and tick-volume history.
- `XAUUSD.DWX` - card-listed liquid gold market with DWX OHLC and tick-volume history.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - card-listed Nasdaq 100 index with DWX OHLC and tick-volume history.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | Intraday to one day; forced exit at 24h with interim time/loss exits at 2h, 4h, 8h, and 16h. |
| Expected drawdown profile | Mean-reversion pullbacks inside an EMA(200) uptrend; losses bounded by the tighter of 6% or 3.0x ATR(14). |
| Regime preference | Mean-reversion bounce inside an uptrend. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy repository
**Pointer:** `user_data/strategies/TrendRiderStrategy.py`, strategy title `TrendRider Strategy`, repository `freqtrade/freqtrade-strategies`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11234_ft-tr-rsi.md`

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
| v1 | 2026-06-08 | Initial build from card | 85a44fa3-8d73-4a35-8ecd-904b3c991905 |
