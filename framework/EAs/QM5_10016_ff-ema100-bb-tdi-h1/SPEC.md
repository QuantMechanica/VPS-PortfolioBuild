# QM5_10016_ff-ema100-bb-tdi-h1 - Strategy Spec

**EA ID:** QM5_10016
**Slug:** ff-ema100-bb-tdi-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 pullbacks in the direction of EMA(100). A long setup requires the last closed bar to close above EMA(100), pull back to the Bollinger middle band or near EMA(100), show an RSI(7)-based TDI proxy bullish cross, and pass a Bollinger-bandwidth anti-chop filter. Shorts mirror the same rules below EMA(100). Exits are broker TP at the opposite Bollinger band, broker SL from the card stop rule, early close on an opposite TDI proxy cross, or a 20-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 100 | 20-300 | EMA trend filter period. |
| `strategy_bb_period` | 20 | 10-100 | Bollinger Bands lookback period. |
| `strategy_bb_deviation` | 2.0 | 1.0-3.5 | Bollinger Bands standard deviation multiplier. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for pullback tolerance and XAU stop sizing. |
| `strategy_tdi_rsi_period` | 7 | 2-30 | RSI period used by the deterministic TDI proxy. |
| `strategy_tdi_green_sma` | 2 | 1-10 | Short SMA length over RSI values for the TDI green proxy line. |
| `strategy_tdi_red_sma` | 7 | 2-20 | Longer SMA length over RSI values for the TDI red proxy line. |
| `strategy_bandwidth_lookback` | 100 | 25-250 | History used to compute the Bollinger-bandwidth percentile filter. |
| `strategy_bandwidth_percentile` | 25.0 | 0-100 | Minimum bandwidth percentile threshold; current width must be above it. |
| `strategy_ema_cross_lookback` | 20 | 5-100 | Bars counted for EMA100 close-side crossings. |
| `strategy_max_ema_crosses` | 3 | 0-10 | Maximum EMA crossings allowed before skipping a setup. |
| `strategy_swing_lookback` | 5 | 2-20 | Previous swing-high or swing-low window for FX stop placement. |
| `strategy_ema_sl_buffer_pips` | 5.0 | 0-20 | EMA buffer used in the structural FX stop rule. |
| `strategy_fx_min_stop_pips` | 20.0 | 1-100 | Minimum FX stop distance from the card. |
| `strategy_fx_max_stop_pips` | 30.0 | 1-150 | Maximum FX stop distance from the card. |
| `strategy_xau_atr_sl_mult` | 0.8 | 0.1-5.0 | XAUUSD stop distance as ATR multiple. |
| `strategy_time_stop_bars` | 20 | 1-200 | Maximum position hold in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX symbol with DWX H1 data.
- `GBPUSD.DWX` - card-listed major FX symbol with DWX H1 data.
- `AUDJPY.DWX` - card-listed FX cross with DWX H1 data.
- `XAUUSD.DWX` - card-listed metal symbol with DWX H1 data and ATR stop analog.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest boundary requires `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom tick evidence for this build.

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
| Trades / year / symbol | `45` |
| Typical hold time | Up to 20 H1 bars by card time stop. |
| Expected drawdown profile | Fixed-risk pullback trades with one active position per symbol/magic. |
| Regime preference | EMA100 trend pullbacks with enough Bollinger-bandwidth to avoid chop. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/post/9159848
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10016_ff-ema100-bb-tdi-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | efaabed0-b51f-42be-bbfd-479edb0633d7 |
