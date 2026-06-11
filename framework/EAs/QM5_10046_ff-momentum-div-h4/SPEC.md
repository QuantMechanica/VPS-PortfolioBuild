# QM5_10046_ff-momentum-div-h4 - Strategy Spec

**EA ID:** QM5_10046
**Slug:** ff-momentum-div-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates closed H4 bars and looks for divergence between price swings and Momentum(28). A short setup requires price to print a higher 3-left/3-right swing high while Momentum(28) prints a lower swing high 8-28 bars apart, then enters when Momentum breaks below point F. A long setup mirrors this with lower price swing lows, higher Momentum swing lows, and a break above point F. The stop is placed at point C with a spread buffer, the take profit is 2R, the stop moves to breakeven at 1R, and opposite divergence closes an open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_period` | 28 | >=1 | Momentum lookback on close. |
| `strategy_fractal_left` | 3 | >=1 | Older-side bars required for swing pivot confirmation. |
| `strategy_fractal_right` | 3 | >=1 | Newer-side bars required for swing pivot confirmation. |
| `strategy_divergence_min_bars` | 8 | >=1 | Minimum bar distance between divergence pivots. |
| `strategy_divergence_max_bars` | 28 | >= min | Maximum bar distance between divergence pivots. |
| `strategy_atr_period` | 14 | >=1 | ATR period for stop-distance filter. |
| `strategy_min_stop_atr_mult` | 0.5 | >0 | Minimum allowed stop distance as ATR multiple. |
| `strategy_max_stop_atr_mult` | 4.0 | >= min | Maximum allowed stop distance as ATR multiple. |
| `strategy_take_profit_rr` | 2.0 | >0 | Final take-profit multiple of initial risk. |
| `strategy_extra_buffer_points` | 0.0 | >=0 | Optional extra points added to the live spread buffer at point C. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX forex symbol with H4 history.
- `GBPUSD.DWX` - Card-listed DWX forex symbol with H4 history.
- `USDJPY.DWX` - Card-listed DWX forex symbol with H4 history.
- `XAUUSD.DWX` - Card-listed DWX metals symbol with H4 history.

**Explicitly NOT for:**
- Non-DWX symbols - Build and pipeline artifacts must use the registered `.DWX` symbol names.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - The card's R3 basket is already fully portable.

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
| Trades / year / symbol | 24 |
| Typical hold time | H4/D1 divergence windows of 8-28 bars; position exits at 2R, breakeven stop, Friday close, or opposite divergence |
| Expected drawdown profile | Reversal strategy with ATR-filtered point-C stops and fixed 2R final target |
| Regime preference | Momentum-reversal divergence after visible swing exhaustion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/423512-best-trading-system-only-momentum
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10046_ff-momentum-div-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 529592ee-729a-4d48-ac53-ae4414ed2e74 |
