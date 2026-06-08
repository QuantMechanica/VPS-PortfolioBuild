# QM5_11232_ft-tr-pullback - Strategy Spec

**EA ID:** QM5_11232
**Slug:** `ft-tr-pullback`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

Long when the H1 close is above EMA(200), EMA(50) is above EMA(200), and the last closed bar pulls back to EMA(16) while closing bullish above EMA(16). The entry also requires RSI(16) between 30 and 65, ADX(14) above 18, +DI above -DI, tick volume above 70% of its 20-bar average, and OBV above its 20-period EMA. Exit when the source RSI, EMA/MACD, EMA(200) breakdown, or time/loss rules trigger; stop distance is the tighter of the source 6% stop and 3.0x ATR(14), with a 3% trailing stop after +5% profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 9 | 2-50 | Fast EMA used in the EMA(9) below EMA(16) exit. |
| `strategy_ema_pullback` | 16 | 2-100 | Pullback EMA used for entry support and exit cross. |
| `strategy_ema_trend_fast` | 50 | 10-250 | Fast trend EMA for the bull regime check. |
| `strategy_ema_trend_slow` | 200 | 50-400 | Slow trend EMA for bull regime and breakdown exits. |
| `strategy_rsi_period` | 16 | 2-50 | RSI period for entry and exits. |
| `strategy_rsi_min` | 30.0 | 1-50 | Lower RSI bound for pullback entry. |
| `strategy_rsi_max` | 65.0 | 50-99 | Upper RSI bound for pullback entry. |
| `strategy_adx_period` | 14 | 2-50 | ADX and DI period. |
| `strategy_adx_min` | 18.0 | 1-60 | Minimum ADX for entry. |
| `strategy_volume_factor` | 0.70 | 0.1-3.0 | Last closed bar tick volume must exceed this fraction of average volume. |
| `strategy_volume_lookback` | 20 | 2-100 | Tick-volume average lookback. |
| `strategy_obv_ema_period` | 20 | 2-100 | OBV EMA period. |
| `strategy_obv_warmup_bars` | 220 | 50-500 | Closed bars used to seed OBV and its EMA. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 0.5-10.0 | ATR multiple used in the emergency stop. |
| `strategy_source_stop_pct` | 6.0 | 0.5-20.0 | Source fixed stop percentage. |
| `strategy_trail_start_pct` | 5.0 | 0.5-20.0 | Profit threshold that activates trailing. |
| `strategy_trail_pct` | 3.0 | 0.5-20.0 | Trailing stop distance as percent below bid. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with DWX OHLC and tick-volume support.
- `GBPUSD.DWX` - FX major with DWX OHLC and tick-volume support.
- `XAUUSD.DWX` - Liquid metal symbol with DWX OHLC and tick-volume support.
- `GDAXI.DWX` - Verified DAX matrix symbol used for the card's `GER40.DWX` exposure.
- `NDX.DWX` - Liquid index symbol with DWX OHLC and tick-volume support.

**Explicitly NOT for:**
- `GER40.DWX` - Card symbol is not present in `dwx_symbol_matrix.csv`; DAX exposure is ported to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `2h to 24h by source time-exit ladder` |
| Expected drawdown profile | `Fixed-risk pullback trend system with ATR emergency stop and source trailing stop` |
| Regime preference | `trend-following pullback` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/TrendRiderStrategy.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11232_ft-tr-pullback.md`

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
| v1 | 2026-06-08 | Initial build from card | 90f443a1-5a61-430d-b39b-b6277523e23f |
