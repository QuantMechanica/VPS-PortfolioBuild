# QM5_10829_tv-macd200-sr - Strategy Spec

**EA ID:** QM5_10829
**Slug:** `tv-macd200-sr`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA enters long after a closed bar finishes above EMA(200), MACD crosses above its signal line, and the MACD line is still below zero. It enters short after a closed bar finishes below EMA(200), MACD crosses below its signal line, and the MACD line is still above zero. When the support/resistance filter is enabled, the signal bar must touch a recent confirmed pivot support for longs or pivot resistance for shorts within an ATR(14) tolerance. The baseline exit is broker SL/TP only: nearest confirmed swing stop if available, EMA(200) plus a fixed tick buffer otherwise, and a fixed 1.5R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 200 | 150-250 | EMA trend filter length from the card sweep. |
| `strategy_macd_fast` | 12 | 8-16 | Fast MACD EMA length. |
| `strategy_macd_slow` | 26 | 21-32 | Slow MACD EMA length. |
| `strategy_macd_signal` | 9 | 5-9 | MACD signal smoothing length. |
| `strategy_use_sr_filter` | true | true/false | Enables the confirmed pivot support/resistance touch filter. |
| `strategy_pivot_strength` | 5 | 3-8 | Bars on each side used to confirm a pivot. |
| `strategy_sr_max_age_bars` | 50 | 10-100 | Maximum bars back searched for a usable pivot level. |
| `strategy_atr_period` | 14 | fixed | ATR length for pivot touch tolerance. |
| `strategy_atr_touch_mult` | 0.20 | 0.10-0.30 | Pivot touch tolerance as ATR multiple. |
| `strategy_stop_swing_lookback` | 20 | 5-80 | Maximum bars searched for a swing stop before EMA fallback. |
| `strategy_ema_buffer_ticks` | 20 | 1-100 | Fixed tick buffer added around EMA(200) for fallback stops. |
| `strategy_take_profit_rr` | 1.50 | 1.20-2.00 | Reward/risk multiple for take profit. |
| `strategy_max_spread_points` | 0 | 0-1000 | Optional spread ceiling; 0 disables this extra ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major in the card's primary P2 basket.
- `GBPUSD.DWX` - FX major in the card's primary P2 basket.
- `XAUUSD.DWX` - Liquid metal CFD in the card's primary P2 basket.
- `GDAXI.DWX` - Available DAX custom symbol used for the card's unavailable `GER40.DWX` basket member.
- `NDX.DWX` - US large-cap index CFD in the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - Mentioned only as a possible later test target, not part of this card's primary P2 basket.

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
| Trades / year / symbol | `55` |
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | late EMA filters during range transitions and MACD whipsaw around the zero line |
| Regime preference | trend-filtered pullback/momentum |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/FzfWWd0i-MACD-200-EMA-Support-Resistance-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10829_tv-macd200-sr.md`

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
| v1 | 2026-06-06 | Initial build from card | 3281e6c1-f096-43ec-8dbd-8271023e6a16 |
