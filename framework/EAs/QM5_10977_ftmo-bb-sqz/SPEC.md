# QM5_10977_ftmo-bb-sqz - Strategy Spec

**EA ID:** QM5_10977
**Slug:** `ftmo-bb-sqz`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a Bollinger Band squeeze breakout on closed H1 bars. It calculates Bollinger Bands from typical price with SMA(20) and 2.0 standard deviations, then treats a bar as squeezed when band width is in the lowest 20th percentile of the prior 120 H1 widths. If a squeeze occurred within the last 6 H1 bars, the EA enters long when the last closed candle closes above the upper band and above the SMA(20), or enters short when it closes below the lower band and below the SMA(20).

The breakout candle is skipped when its high-low range is greater than 2.5 x ATR(14), and the EA also skips unusually wide spreads above 1.5 x the 20-bar median spread while allowing `.DWX` zero modeled spread. Long stops are placed at the lower band minus 0.25 x ATR(14); short stops are placed at the upper band plus 0.25 x ATR(14). Take-profit is 2.5R, stop is moved to breakeven after 1.2R touch, and discretionary exits occur on a close back across SMA(20) or after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger period for SMA and bands |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger standard-deviation multiple |
| `strategy_squeeze_lookback` | 120 | 60-240 | Historical band-width percentile window |
| `strategy_squeeze_percentile` | 20.0 | 5.0-40.0 | Low-percentile threshold for squeeze |
| `strategy_squeeze_recent_bars` | 6 | 1-20 | Lookback for a recent squeeze before breakout |
| `strategy_atr_period` | 14 | 7-28 | ATR period for range filter and stop buffer |
| `strategy_max_range_atr_mult` | 2.5 | 1.0-5.0 | Skip breakout candle if range exceeds this ATR multiple |
| `strategy_stop_atr_buffer_mult` | 0.25 | 0.0-1.0 | ATR buffer beyond the opposite band for stop placement |
| `strategy_take_profit_rr` | 2.5 | 1.0-5.0 | Primary take-profit in R multiples |
| `strategy_breakeven_trigger_rr` | 1.2 | 0.5-3.0 | Move stop to breakeven after this R multiple is touched |
| `strategy_time_exit_bars` | 36 | 12-120 | Maximum holding time in H1 bars |
| `strategy_spread_median_bars` | 20 | 5-60 | Median-spread lookback in bars |
| `strategy_spread_median_mult` | 1.5 | 1.0-5.0 | Maximum current spread versus median spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the card's R3 portable basket.
- `GBPUSD.DWX` - liquid major FX pair from the card's R3 portable basket.
- `USDJPY.DWX` - liquid major FX pair from the card's R3 portable basket.
- `XAUUSD.DWX` - liquid metal symbol from the card's R3 portable basket.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - the card defines an FX/metals basket, not an equity-index basket.

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
| Trades / year / symbol | `36` |
| Typical hold time | `hours to a few days, capped at 36 H1 bars` |
| Expected drawdown profile | `failed-breakout losses with occasional 2.5R trend-continuation wins` |
| Regime preference | `volatility-expansion / breakout` |
| Win rate target (qualitative) | `low to medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** https://ftmo.com/en/blog/technical-analysis-bollinger-bands-as-a-combination-of-trend-and-volatility/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10977_ftmo-bb-sqz.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 50d9634a-7832-434a-96e0-f56a13afe1ac |
