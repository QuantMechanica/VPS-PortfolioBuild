# QM5_11236_ft-tr-bb — Strategy Spec

**EA ID:** QM5_11236
**Slug:** `ft-tr-bb`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (Freqtrade TrendRiderStrategy, entry tag `bb_bounce`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only Bollinger lower-band bounce on H1. On the just-closed bar the EA goes
long when the close tags the lower Bollinger band (close <= BB_lower(20, 2.0) ×
1.005), the candle is bullish (close > open), RSI(16) < 45, ADX(14) > 18, and
tick-volume is active (vol[1] > 0 and vol[1] / EMA(20)-of-volume > 0.7). The
source strategy's BTC and fear-greed cross-asset filters are neutralized for the
single-symbol DWX port (no such feed exists in the tester).

Exit on any of the source TrendRider long-exit conditions: RSI(16) > 78; EMA(9)
crossing below EMA(16) with MACD histogram < 0 and RSI > 50; close crossing
below EMA(200)×0.99; or close < EMA(200)×0.995 with RSI > 72 and a falling MACD
histogram. Custom time/loss exits also apply: held >2h and profit < −1.5%, >4h
and < 0%, >8h and < 0.5%, >16h and < 1.0%, or >24h regardless. Protective stop
is the tighter of the source −6% stop and 3×ATR(14); a 3%-of-price trailing stop
ratchets up once unrealized profit reaches +5%.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger period |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger deviation (mandatory arg) |
| `strategy_bb_touch_slack` | 0.005 | 0.0-0.02 | close <= lower × (1+slack) tolerance |
| `strategy_rsi_period` | 16 | 5-30 | RSI lookback |
| `strategy_rsi_entry_max` | 45.0 | 30-55 | Entry: RSI below this |
| `strategy_rsi_exit_high` | 78.0 | 65-90 | Exit: RSI above this |
| `strategy_adx_period` | 14 | 7-30 | ADX lookback |
| `strategy_adx_min` | 18.0 | 10-35 | Entry: ADX above this |
| `strategy_vol_ema_period` | 20 | 5-50 | EMA period for volume baseline |
| `strategy_vol_ratio_min` | 0.7 | 0.3-1.5 | Entry: vol / EMA(vol) above this |
| `strategy_ema_fast_period` | 9 | 3-30 | Exit EMA fast |
| `strategy_ema_slow_period` | 16 | 5-50 | Exit EMA slow |
| `strategy_ema_trend_period` | 200 | 100-300 | Trend EMA for breakdown exits |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal |
| `strategy_atr_period` | 14 | 7-30 | ATR period (emergency stop) |
| `strategy_atr_stop_mult` | 3.0 | 1.5-5.0 | Emergency stop = mult × ATR |
| `strategy_source_stop_pct` | 6.0 | 2.0-10.0 | Source fixed stop, percent |
| `strategy_trail_activate_pct` | 5.0 | 1.0-15.0 | Trailing activates at +this % |
| `strategy_trail_distance_pct` | 3.0 | 1.0-10.0 | Trailing distance, percent of price |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX; band-bounce mean reversion works in ranging FX.
- `GBPUSD.DWX` — liquid major FX; similar mean-reversion regime.
- `XAUUSD.DWX` — gold; high-volatility instrument where band touches are frequent.
- `GDAXI.DWX` — DAX 40; PORTED from card's `GER40.DWX` (not in DWX matrix; GER40→GDAXI per build porting rule).
- `NDX.DWX` — Nasdaq 100; trending index with periodic lower-band pullbacks.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; replaced by `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~35` |
| Typical hold time | `hours (time exits at 2h–24h)` |
| Expected drawdown profile | `moderate; bounded by tighter of -6% / 3×ATR stop` |
| Regime preference | `mean-revert (band bounce) within a trending/active filter` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `forum` (Freqtrade community strategies repository)
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/TrendRiderStrategy.py` (commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, entry tag `bb_bounce`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11236_ft-tr-bb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor build (registry/compile = central step) |
