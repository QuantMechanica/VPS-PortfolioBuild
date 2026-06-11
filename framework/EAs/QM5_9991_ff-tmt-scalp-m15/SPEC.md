# QM5_9991_ff-tmt-scalp-m15 - Strategy Spec

**EA ID:** QM5_9991
**Slug:** `ff-tmt-scalp-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the ForexFactory TMT scalping reduction on M15. A long signal requires the current D1 candle to be green, EMA(7) above EMA(20), RSI(14) above 50, at least one recent pullback bar overlapping the EMA band, and the last closed M15 bar closing above the descending trendline drawn through the two most recent swing highs by at least 0.1 ATR(14). A short signal mirrors the same rules with a red D1 candle, EMA(7) below EMA(20), RSI(14) below 50, and a close below the ascending swing-low trendline. Entries are market orders on the next bar with a 10 pip stop, 15 pip target, opposite-signal exit, and 12-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 7 | 1-100 | Fast EMA period from the TMT card. |
| `strategy_ema_slow_period` | 20 | 2-200 | Slow EMA period from the TMT card. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period used as the deterministic color proxy. |
| `strategy_rsi_midline` | 50.0 | 1.0-99.0 | Longs require RSI above this value; shorts require RSI below it. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for breakout buffer sizing. |
| `strategy_break_atr_mult` | 0.10 | 0.0-2.0 | Breakout close must exceed the trendline by this ATR multiple. |
| `strategy_swing_lookback_bars` | 48 | 8-200 | M15 bars searched for the two newest swing anchors. |
| `strategy_fractal_side_bars` | 2 | 1-10 | Bars required on each side of a swing high or low. |
| `strategy_pullback_bars` | 6 | 1-50 | Recent bars checked for an EMA-band pullback. |
| `strategy_stop_pips` | 10 | 1-100 | Fixed initial stop in pips. |
| `strategy_take_profit_pips` | 15 | 1-200 | Fixed take profit in pips. |
| `strategy_time_stop_bars` | 12 | 1-200 | M15 bars after which an open trade is closed. |
| `strategy_session_start_utc` | 7 | 0-23 | UTC session start hour. |
| `strategy_session_end_utc` | 20 | 0-23 | UTC session end hour. |
| `strategy_max_spread_pips` | 1.5 | 0.1-20.0 | Maximum allowed current spread in pips. |
| `strategy_max_spread_stop_pct` | 15.0 | 1.0-100.0 | Maximum spread as a percent of the fixed stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX data available.
- `GBPUSD.DWX` - card-listed FX major with DWX data available.
- `USDJPY.DWX` - card-listed FX major with DWX data available.

**Explicitly NOT for:**
- Equity index `.DWX` symbols - the approved card is specific to FX majors and M15/D1 FX OHLC behavior.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` current candle color |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `110` |
| Typical hold time | `Up to 12 M15 bars, about 3 hours maximum` |
| Expected drawdown profile | `Scalping system with fixed 10 pip risk per trade and framework fixed-risk sizing` |
| Regime preference | `M15 trendline breakout after EMA-band pullback in London/US hours` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/577639-tmt-scalping-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9991_ff-tmt-scalp-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | f8d38786-fd01-4176-a4ba-9ea4a138ddd2 |
