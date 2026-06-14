# QM5_1066_carver-ewmac-trend - Strategy Spec

**EA ID:** QM5_1066
**Slug:** carver-ewmac-trend
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a (see `sources/rob-carver-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

On each closed D1 bar, the EA compares a fast EMA of close to a slow EMA of close and divides that difference by an EWMA standard deviation of daily close-to-close changes. The result is multiplied by the Rob Carver EWMAC forecast scalar for the selected fast/slow pair and capped to +/-20. A long entry is opened when the capped forecast is above +2, and a short entry is opened when it is below -2. Longs close when the forecast falls below 0, shorts close when it rises above 0, with a 2.5 x ATR(20) emergency stop on every entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ewmac_fast` | 16 | 2-64 tested pairs | Fast EMA lookback for the EWMAC forecast. |
| `strategy_ewmac_slow` | 64 | 8-256 tested pairs | Slow EMA lookback for the EWMAC forecast. |
| `strategy_vol_span` | 25 | >1 | EWMA span for daily close-to-close volatility normalisation. |
| `strategy_entry_forecast` | 2.0 | 0-20 | Absolute forecast threshold required to open a new position. |
| `strategy_exit_long_forecast` | 0.0 | -20-20 | Forecast level below which a long position closes. |
| `strategy_exit_short_forecast` | 0.0 | -20-20 | Forecast level above which a short position closes. |
| `strategy_forecast_cap` | 20.0 | >0 | Absolute cap applied to the scaled forecast. |
| `strategy_atr_period` | 20 | >1 | ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple used for the emergency stop. |
| `strategy_spread_filter` | true | true/false | Enables the card spread cap for new entries. |
| `strategy_spread_days` | 20 | >0 | D1 spread sample length for the spread median. |
| `strategy_spread_mult` | 2.0 | >0 | Current spread must be no more than this multiple of the median spread. |
| `strategy_index_start_hour` | 8 | 0-23 | Broker-hour start for index CFD new entries. |
| `strategy_index_end_hour` | 22 | 0-23 | Broker-hour end for index CFD new entries. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX pair using only daily close data.
- `GBPUSD.DWX` - liquid FX pair using only daily close data.
- `USDJPY.DWX` - liquid FX pair using only daily close data.
- `AUDUSD.DWX` - liquid FX pair using only daily close data.
- `GDAXI.DWX` - DAX index CFD equivalent for the card's `GER40.DWX` P2 target.
- `NDX.DWX` - liquid US index CFD using only daily close data.
- `WS30.DWX` - liquid US index CFD using only daily close data.
- `XAUUSD.DWX` - liquid metal CFD using only daily close data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers verified DWX symbols.

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
| Typical hold time | Days to weeks, until forecast crosses back through zero. |
| Expected drawdown profile | Trend-following drawdowns during sideways or choppy regimes. |
| Regime preference | Trend |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog and linked code
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
