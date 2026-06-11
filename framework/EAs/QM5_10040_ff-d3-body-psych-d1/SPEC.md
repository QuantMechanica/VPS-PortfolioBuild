# QM5_10040_ff-d3-body-psych-d1 - Strategy Spec

**EA ID:** QM5_10040
**Slug:** `ff-d3-body-psych-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades on closed D1 candles. It enters long when the most recent closed candle has a body larger than each of the two prior bodies, the previous candle was bearish, and the latest close is above the previous close. It enters short on the mirrored condition with a bullish previous candle and a latest close below the previous close. Take profit is the next 50/00 psychological level in the trade direction, stop loss is the nearest prior 50/00 level behind entry, and both are pushed one more level away if closer than 0.5 ATR(14). Any open trade is closed after one D1 candle if neither TP nor SL has been hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1+ | D1 ATR period for minimum TP/SL distance. |
| `strategy_psych_step_pips` | 50 | 1+ | Price grid spacing for 50/00 psychological levels. |
| `strategy_min_atr_fraction` | 0.5 | >0 | Minimum TP and SL distance as a fraction of ATR. |
| `strategy_min_tp_spread_mult` | 1.5 | 0+ | Skip entries when TP distance is less than this multiple of current spread. |
| `strategy_max_hold_days` | 1 | 1+ | Time stop in calendar days after entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 standard DWX D1 FX symbol for this body-expansion setup.
- `GBPUSD.DWX` - card R3 standard DWX D1 FX symbol for this body-expansion setup.
- `USDJPY.DWX` - card R3 standard DWX D1 FX symbol for this body-expansion setup.
- `EURJPY.DWX` - card R3 standard DWX D1 FX symbol for this body-expansion setup.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - the card defines a four-pair FX basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | one D1 candle or less |
| Expected drawdown profile | fixed-risk daily FX setup with single-position exposure per symbol |
| Regime preference | volatility-expansion / candle-body expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/245777-a-simple-strategy-with-no-indicators`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10040_ff-d3-body-psych-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | de947e68-3932-4dfb-bf1f-e104fbc1c1c6 |
