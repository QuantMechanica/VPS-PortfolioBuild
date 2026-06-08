# QM5_11237_ft-tr-macd - Strategy Spec

**EA ID:** QM5_11237
**Slug:** ft-tr-macd
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only H1 MACD reversals from the Freqtrade TrendRider `macd_reversal` tag. It enters when the MACD histogram crosses above zero while price is above EMA(50) and EMA(200), RSI(16) is between 40 and 60, ADX(14) is above 15, and tick volume is above 0.8 times its EMA(20). It exits on the source RSI, EMA/MACD, EMA200-loss, MACD-falling, time/loss, and 24-hour max-hold rules. The source BTC and fear-greed filters are neutralized for this DWX port.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 only | Source timeframe for all strategy reads. |
| `strategy_macd_fast` | 12 | >0 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | >fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | >0 | MACD signal period. |
| `strategy_ema_filter_fast` | 50 | >0 | Fast trend-filter EMA. |
| `strategy_ema_filter_slow` | 200 | >0 | Slow trend-filter EMA and exit baseline. |
| `strategy_ema_exit_fast` | 9 | >0 | Fast EMA used for source exit cross. |
| `strategy_ema_exit_slow` | 16 | >0 | Slow EMA used for source exit cross. |
| `strategy_rsi_period` | 16 | >0 | RSI lookback. |
| `strategy_rsi_entry_low` | 40.0 | 0-100 | Lower RSI entry bound. |
| `strategy_rsi_entry_high` | 60.0 | 0-100 | Upper RSI entry bound. |
| `strategy_rsi_exit_high` | 78.0 | 0-100 | High-RSI source exit threshold. |
| `strategy_adx_period` | 14 | >0 | ADX lookback. |
| `strategy_adx_entry_min` | 15.0 | >=0 | Minimum ADX for entry. |
| `strategy_volume_ema_period` | 20 | >1 | EMA period for closed-bar tick volume. |
| `strategy_volume_ratio_min` | 0.80 | >0 | Minimum tick-volume / volume-EMA ratio. |
| `strategy_atr_period` | 14 | >0 | ATR lookback for V5 emergency stop. |
| `strategy_source_stop_pct` | 6.0 | >0 | Source fixed stop distance in percent. |
| `strategy_atr_stop_mult` | 3.0 | >0 | ATR multiplier for V5 emergency stop cap. |
| `strategy_trail_start_pct` | 5.0 | >=0 | Profit percent required before trailing activates. |
| `strategy_trail_distance_pct` | 3.0 | >0 | Percent trailing distance after activation. |
| `strategy_trail_step_points` | 10 | >=0 | Minimum SL improvement in points before modifying. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid DWX forex major with H1 OHLC and tick volume.
- `GBPUSD.DWX` - card target; liquid DWX forex major with H1 OHLC and tick volume.
- `XAUUSD.DWX` - card target; liquid DWX metal with H1 OHLC and tick volume.
- `GDAXI.DWX` - matrix-available DAX equivalent for card-stated `GER40.DWX`.
- `NDX.DWX` - card target; liquid DWX US index with H1 OHLC and tick volume.

**Explicitly NOT for:**
- `GER40.DWX` - named by the card but absent from `dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.

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
| Trades / year / symbol | 28 |
| Typical hold time | 2 to 24 hours; hard exit after 24 hours |
| Expected drawdown profile | Momentum reversal with fixed 6% source stop capped by 3.0 x ATR(14). |
| Regime preference | Momentum reversal inside an uptrend filter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** `freqtrade/freqtrade-strategies/user_data/strategies/TrendRiderStrategy.py`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, entry tag `macd_reversal`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11237_ft-tr-macd.md`

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
| v1 | 2026-06-08 | Initial build from card | 777d69c7-53b9-4a5d-b8d9-14941b54c75b |
