# QM5_1066_carver-ewmac-trend - Strategy Spec

**EA ID:** QM5_1066
**Slug:** carver-ewmac-trend
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a (see `sources/rob-carver-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades a daily trend signal based on a fast EMA and slow EMA of the close. On each closed D1 bar it forms a forecast from the EMA difference divided by a volatility estimate, scales it, and caps it to a maximum absolute forecast. It opens long above the positive entry threshold and short below the negative entry threshold. It closes longs when the forecast falls below zero and closes shorts when the forecast rises above zero; the framework handles the emergency ATR stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema` | 16 | 1-512 | Fast EMA lookback from the card's first-build variant. |
| `strategy_slow_ema` | 64 | 2-1024 | Slow EMA lookback from the card's first-build variant. |
| `strategy_vol_span` | 25 | 2-256 | Volatility smoothing span used for forecast normalisation. |
| `strategy_forecast_scalar` | 3.75 | >0 | Fixed forecast scalar for the EWMAC forecast. |
| `strategy_forecast_cap` | 20.0 | >0 | Absolute forecast cap. |
| `strategy_entry_forecast` | 2.0 | >0 | Entry threshold for long and short target positions. |
| `strategy_exit_long` | 0.0 | any | Close a long when forecast is below this value. |
| `strategy_exit_short` | 0.0 | any | Close a short when forecast is above this value. |
| `strategy_atr_period` | 20 | 1-256 | ATR lookback for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiplier for the emergency stop distance. |
| `strategy_spread_days` | 20 | 0-64 | D1 spread sample count for the median-spread entry filter. |
| `strategy_spread_mult` | 2.0 | >0 | Maximum current spread as a multiple of median spread. |
| `strategy_index_start_hour` | 8 | 0-23 | Broker-hour start for index CFD entries. |
| `strategy_index_end_hour` | 21 | 0-23 | Broker-hour end for index CFD entries. |
| `strategy_nonindex_min_hour` | 1 | 0-23 | Earliest broker hour for FX and metal rebalancing after rollover. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX pair from the card's portable DWX basket.
- `GBPUSD.DWX` - liquid FX pair from the card's portable DWX basket.
- `USDJPY.DWX` - liquid FX pair from the card's portable DWX basket.
- `AUDUSD.DWX` - liquid FX pair from the card's portable DWX basket.
- `GDAXI.DWX` - DWX matrix DAX symbol used for the card's GER40 index exposure.
- `NDX.DWX` - Nasdaq 100 index CFD from the card's portable DWX basket.
- `WS30.DWX` - Dow 30 index CFD from the card's portable DWX basket.
- `XAUUSD.DWX` - DWX metal symbol used for the card's XAUUSD exposure.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | days to weeks, with daily closed-bar reassessment |
| Expected drawdown profile | Trend-following drawdowns during choppy or mean-reverting regimes |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog plus linked code
**Pointer:** https://qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html and `artifacts/cards_approved/QM5_1066_carver-ewmac-trend.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1066_carver-ewmac-trend.md`

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
| v1 | 2026-06-14 | Initial build from card | 53e681e1-20f6-4b56-9785-562c68f29133 |
