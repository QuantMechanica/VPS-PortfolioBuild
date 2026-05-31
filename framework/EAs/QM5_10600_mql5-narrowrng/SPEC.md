# QM5_10600_mql5-narrowrng - Strategy Spec

**EA ID:** QM5_10600
**Slug:** mql5-narrowrng
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

On each completed H4 bar, the EA measures the high-low width of the latest `Bars in Range` bar block and compares it with prior blocks over the `Check Period`. If the latest block is the narrowest range, the EA cancels any old unfilled bracket and places a Buy Stop above the range high and a Sell Stop below the range low, offset by `Order Indent from High / Low`. The stop loss sits at the opposite range boundary, with a 2 ATR fallback if the boundary would be invalid, and the take profit is a fixed multiple of the detected range. While a position is open, new range signals are ignored and the opposite pending order is removed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 expected | Base timeframe from the source test. |
| `strategy_bars_in_range` | `7` | `1+` | Number of closed bars used to define the candidate range. |
| `strategy_check_period` | `20` | `1+` | Number of prior candidate ranges checked for narrowest status. |
| `strategy_order_indent_points` | `10` | `0+` | Stop-order offset beyond the range high/low in points. |
| `strategy_tp_range_mult` | `1.0` | `>0` | Take-profit distance as a multiple of the range width. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic fallback stop distance. |
| `strategy_catastrophic_atr_mult` | `2.0` | `>0` | Fallback stop distance multiplier when opposite boundary is invalid. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread cap; `0` disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source test used EURUSD H4 and the pair is in the DWX matrix.
- `GBPUSD.DWX` - liquid FX major suitable for H4 range-breakout behaviour.
- `USDJPY.DWX` - liquid FX major suitable for H4 range-breakout behaviour.
- `XAUUSD.DWX` - liquid metal CFD named by the approved portable basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they cannot be registered for DWX backtests.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday to several H4 bars, depending on bracket trigger and SL/TP hit. |
| Expected drawdown profile | Breakout systems can cluster losses during range-bound chop. |
| Regime preference | Volatility expansion / breakout after compression. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase expert page
**Pointer:** https://www.mql5.com/en/code/1598
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10600_mql5-narrowrng.md`

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
| v1 | 2026-05-31 | Initial build from card | 2bbe1795-222b-4c67-a934-dbab851bd20d |
