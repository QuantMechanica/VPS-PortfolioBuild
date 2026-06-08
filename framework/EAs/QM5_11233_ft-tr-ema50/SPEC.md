# QM5_11233_ft-tr-ema50 - Strategy Spec

**EA ID:** QM5_11233
**Slug:** `ft-tr-ema50`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only H1 EMA50 support bounces from the TrendRider source strategy. It enters when the closed H1 candle is in a bull regime, tests within 1% above EMA50, closes back above EMA50 as a bullish candle, has RSI(16) between 30 and 50, ADX(14) above 20, tick volume above its EMA20, and MACD histogram rising. It exits on RSI(16) above 78, EMA(9) crossing below EMA(16) with bearish MACD confirmation, price breaking below the EMA200 thresholds from the card, the cascading time/loss exits, or the framework Friday close. The stop is the tighter distance of the source 6% stop and 3.0 x ATR(14); the source trailing rule starts after +5% profit and trails by 3%.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 only | Source timeframe used by the card. |
| `strategy_ema_fast_exit` | `9` | 5-15 | Fast EMA for the bearish exit cross. |
| `strategy_ema_slow_exit` | `16` | 15-30 | Slow EMA for the bearish exit cross. |
| `strategy_ema_bounce` | `50` | 20-100 | EMA support line used by the bounce entry. |
| `strategy_ema_regime` | `200` | 100-300 | EMA trend-regime filter and trend-break exits. |
| `strategy_rsi_period` | `16` | 10-20 | RSI period used for entry and exits. |
| `strategy_adx_period` | `14` | 10-30 | ADX period for trend-strength filter. |
| `strategy_atr_period` | `14` | 10-30 | ATR period for emergency stop distance. |
| `strategy_macd_fast` | `12` | 5-20 | MACD fast period. |
| `strategy_macd_slow` | `26` | 20-40 | MACD slow period. |
| `strategy_macd_signal` | `9` | 5-15 | MACD signal period. |
| `strategy_volume_ema` | `20` | 10-50 | EMA period for tick-volume ratio. |
| `strategy_rsi_entry_low` | `30.0` | 20.0-40.0 | Lower RSI entry threshold. |
| `strategy_rsi_entry_high` | `50.0` | 45.0-70.0 | Upper RSI entry threshold. |
| `strategy_rsi_exit_high` | `78.0` | 70.0-90.0 | RSI exit threshold. |
| `strategy_adx_threshold` | `20.0` | 10.0-35.0 | Minimum ADX for entry. |
| `strategy_volume_ratio_min` | `1.0` | 0.5-2.5 | Minimum tick volume divided by EMA20 tick volume. |
| `strategy_bounce_band_pct` | `1.0` | 0.0-3.0 | Allowed low-to-EMA50 touch band. |
| `strategy_source_stop_pct` | `6.0` | 1.0-10.0 | Source fixed stop distance in percent. |
| `strategy_atr_sl_mult` | `3.0` | 1.0-5.0 | ATR emergency stop multiplier. |
| `strategy_trail_start_pct` | `5.0` | 1.0-10.0 | Profit percent where trailing starts. |
| `strategy_trail_distance_pct` | `3.0` | 1.0-8.0 | Percent trailing distance after activation. |
| `strategy_trail_step_points` | `10` | 1-100 | Minimum SL improvement before modifying the trail. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with H1 OHLC, tick volume, EMA, RSI, ADX, MACD, and ATR data.
- `GBPUSD.DWX` - card-listed liquid FX major with the same required H1 inputs.
- `XAUUSD.DWX` - card-listed gold symbol with trend/bounce behavior and the required indicator set.
- `GDAXI.DWX` - DWX matrix DAX symbol used as the available port for card-stated `GER40.DWX`.
- `NDX.DWX` - card-listed US large-cap index proxy with the required H1 inputs.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not in the approved DWX matrix for this card.

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
| Trades / year / symbol | `30` |
| Typical hold time | `2-24 hours` |
| Expected drawdown profile | Fixed-risk trend pullback losses bounded by the tighter of 6% source stop and 3.0 x ATR(14). |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/TrendRiderStrategy.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11233_ft-tr-ema50.md`

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
| v1 | 2026-06-08 | Initial build from card | 60651a2a-836f-4d4c-b478-bec093c7c555 |
