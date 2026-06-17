# QM5_10974_ftmo-obv-brk - Strategy Spec

**EA ID:** QM5_10974
**Slug:** `ftmo-obv-brk`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO blog: On Balance Volume)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H1 price breakouts that are confirmed by On Balance Volume (OBV).
On each closed bar it builds a 40-bar price range and a parallel 40-bar OBV
range from the bars before the breakout bar. A long entry requires the closed
price to break above the range high by at least 0.20 x ATR(14), OBV to have
broken above its own range on the same bar or one bar earlier, and price to be
above EMA(100). Shorts mirror the rule below the range low with price below
EMA(100). Range quality filters reject very tight ranges, very wide ranges, and
oversized breakout candles. The stop is the farther of the range midpoint and
the breakout candle extreme plus a 0.25 x ATR buffer. The take-profit is 2.0R,
the stop trails to EMA(20) after 1.5R is reached, and discretionary exits occur
when OBV closes back inside the pre-breakout OBV range for two closed bars or
after 30 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_lookback` | 40 | 10-100 | Bars in the price and OBV breakout range |
| `strategy_atr_period` | 14 | 5-50 | ATR period for breakout buffer, filters, and stop buffer |
| `strategy_trend_ema_period` | 100 | 20-300 | EMA trend filter period |
| `strategy_trail_ema_period` | 20 | 5-100 | EMA used to trail the stop after 1.5R |
| `strategy_breakout_atr_mult` | 0.20 | 0.0-1.0 | Required breakout distance beyond the range edge, in ATR |
| `strategy_stop_atr_buffer` | 0.25 | 0.0-1.0 | ATR buffer beyond the breakout candle extreme |
| `strategy_take_rr` | 2.0 | 0.5-5.0 | Take-profit as an R multiple |
| `strategy_trail_trigger_r` | 1.5 | 0.5-3.0 | R multiple that arms EMA trailing |
| `strategy_range_min_atr` | 1.2 | 0.0-3.0 | Skip if range height is below this ATR multiple |
| `strategy_range_max_atr` | 5.0 | 2.0-10.0 | Skip if range height is above this ATR multiple |
| `strategy_candle_max_atr` | 2.2 | 1.0-5.0 | Skip if breakout candle range is above this ATR multiple |
| `strategy_obv_confirm_bars` | 2 | 1-5 | OBV breakout may occur on the breakout bar or this many bars back |
| `strategy_obv_exit_bars` | 2 | 1-5 | Consecutive OBV-back-inside bars needed for exit |
| `strategy_max_hold_bars` | 30 | 5-200 | Time exit after this many H1 bars |
| `strategy_max_spread_atr` | 0.15 | 0.0-1.0 | Skip only if positive modeled spread exceeds this ATR fraction |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with tick volume available for OBV.
- `GBPUSD.DWX` - FX major with tick volume available for OBV.
- `XAUUSD.DWX` - liquid metal CFD with H1 breakout behaviour and tick volume.
- `NDX.DWX` - liquid index CFD with H1 momentum breakouts and tick volume.

**Explicitly NOT for:**
- `SP500.DWX` - not listed in this card's R3 basket.

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
| Trades / year / symbol | `48` |
| Typical hold time | `hours to a few days, capped at 30 H1 bars` |
| Expected drawdown profile | `clustered breakout-failure losses during range chop` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `low-medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** FTMO, "Technical analysis - On Balance Volume relies on volumes", 2023, https://ftmo.com/en/blog/technical-analysis-on-balance-volume-relies-on-volumes/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10974_ftmo-obv-brk.md`

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
| v1 | 2026-06-18 | Initial build from card | 643608d4-12e1-46a2-af80-08f3b7dc45db |
