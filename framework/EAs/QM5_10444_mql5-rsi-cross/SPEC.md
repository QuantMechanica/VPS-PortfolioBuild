# QM5_10444_mql5-rsi-cross - Strategy Spec

**EA ID:** QM5_10444
**Slug:** mql5-rsi-cross
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA calculates RSI on closed M15 bars. It opens long when RSI crosses upward through the configured lower level between bar 2 and bar 1, and opens short when RSI crosses downward through the configured upper level between bar 2 and bar 1. If an opposite position is already open, the strategy exit hook closes it on the same opposite RSI level-cross signal before the entry hook can open the new direction. Protective exits are fixed stop loss, optional fixed take profit, optional trailing stop, and the framework Friday-close guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | `1+` | RSI lookback period on the chart timeframe. |
| `strategy_rsi_lower_level` | 30.0 | `0 < lower < upper` | Oversold level that must be crossed upward for a long entry. |
| `strategy_rsi_upper_level` | 70.0 | `lower < upper < 100` | Overbought level that must be crossed downward for a short entry. |
| `strategy_stop_loss_pips` | 30 | `1+` | Fixed stop distance; equals 300 points on 5-digit FX symbols. |
| `strategy_take_profit_pips` | 0 | `0+` | Fixed take-profit distance; `0` disables fixed TP. |
| `strategy_trailing_enabled` | false | `true/false` | Enables framework step trailing when setfiles opt in. |
| `strategy_trailing_trigger_pips` | 30 | `1+` | Profit distance required before trailing can move the stop. |
| `strategy_trailing_step_pips` | 10 | `1+` | Step distance used by the framework trailing helper. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - card-listed FX target with RSI OHLC data available in the DWX matrix.
- `EURUSD.DWX` - card-listed FX target with RSI OHLC data available in the DWX matrix.
- `GBPUSD.DWX` - card-listed FX target with RSI OHLC data available in the DWX matrix.
- `GDAXI.DWX` - registered DAX custom symbol; used as the DWX matrix equivalent for card-listed `GER40.DWX`.
- `XAUUSD.DWX` - card-listed metal CFD target with RSI OHLC data available in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | mean-reversion oscillator-cross conditions |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase strategy
**Pointer:** MQL5 CodeBase, "RSI_Expert - expert for MetaTrader 5", https://www.mql5.com/en/code/21759
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10444_mql5-rsi-cross.md`

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
| v1 | 2026-06-13 | Initial build from card | c6b84d15-0a8e-47ba-a6d4-b10ba7c939e2 |
