# QM5_11099_prm-engulf-rev - Strategy Spec

**EA ID:** QM5_11099
**Slug:** prm-engulf-rev
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades two-candle engulfing reversals on completed H4 bars. A long entry requires the prior candle to be bearish, the current candle to be bullish, the current close to engulf the prior open, the prior close to be at or above the current open, and the current body to exceed the prior body. A short entry applies the inverse bearish engulfing geometry. The EA exits on an opposite engulfing signal or after 8 H4 bars, with a 2.0 x ATR(14) catastrophic stop from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_candle_length` | 12 | >= 1 | Pattern Recognition Master candle-length parameter retained from the card baseline. |
| `strategy_engulfing_length` | 10 | >= 1 | Pattern Recognition Master engulfing-length parameter retained from the card baseline. |
| `strategy_atr_period` | 14 | >= 1 | ATR lookback used for the catastrophic stop and volatility floor. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple for the catastrophic stop from entry. |
| `strategy_atr_percentile_lookback` | 252 | > `strategy_atr_period` | Number of completed bars used for the ATR percentile floor. |
| `strategy_atr_percentile_floor` | 20.0 | 0-100 | Minimum ATR percentile required before a signal can trade. |
| `strategy_time_stop_bars` | 8 | >= 1 | Maximum holding time in completed base-timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary forex symbol with DWX OHLC coverage.
- `GBPUSD.DWX` - Card R3 primary forex symbol with DWX OHLC coverage.
- `USDJPY.DWX` - Card R3 primary forex symbol with DWX OHLC coverage.
- `XAUUSD.DWX` - Card R3 primary metal symbol with DWX OHLC coverage.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick-data registration target exists.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 8 H4 bars, about 32 trading hours before the time exit. |
| Expected drawdown profile | Reversal pattern with catastrophic ATR stop; drawdown should cluster during trend continuation against engulfing signals. |
| Regime preference | Candlestick reversal with normal-to-high ATR regime after the 20th-percentile volatility floor. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** public GitHub / MQL5 indicator source
**Pointer:** EarnForex Pattern Recognition Master, `Pattern_Recognition_Master.mq5`, bearish engulfing around lines 610-623 and bullish engulfing around lines 753-766; approved card at `artifacts/cards_approved/QM5_11099_prm-engulf-rev.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11099_prm-engulf-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | af24ab68-2fdd-419d-8288-7fd14e8a29d5 |
