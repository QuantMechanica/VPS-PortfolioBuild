# QM5_11031_atc-ohlc-pend - Strategy Spec

**EA ID:** QM5_11031
**Slug:** `atc-ohlc-pend`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On each D1 closed-bar cadence evaluation, the EA reads the previous completed D1 bar's open, high, low, and close. If current price is above the prior close, it arms a buy stop above the prior high by an ATR buffer; if current price is below the prior close, it arms a sell stop below the prior low by an ATR buffer. Optional secondary limit entries use the prior low for long pullback entries and the prior high for short pullback entries when the primary stop level is not valid for the current quote. Stops and targets are fixed ATR distances, stale pending orders are removed at the next cadence evaluation, and an open position moves to breakeven after ATR-based profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_eval_cadence_bars` | 2 | 1-10 | Number of closed D1 bars between entry evaluations. |
| `strategy_atr_period` | 14 | 2-100 | D1 ATR period used for entry buffer, stop, target, and breakeven. |
| `strategy_entry_buffer_atr` | 0.05 | 0.0-1.0 | ATR multiple added beyond prior high or low for stop entries. |
| `strategy_sl_atr_mult` | 0.75 | 0.1-5.0 | Stop-loss distance from pending entry price. |
| `strategy_tp_atr_mult` | 1.5 | 0.1-10.0 | Take-profit distance from pending entry price. |
| `strategy_breakeven_atr` | 1.0 | 0.1-5.0 | Profit threshold before SL is moved to entry. |
| `strategy_range_filter_bars` | 60 | 0-200 | Median D1 range lookback; 0 or 1 disables the range filter. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Blocks only genuinely wide positive spreads above this share of stop distance. |
| `strategy_enable_secondary_limits` | true | true/false | Enables optional prior-low/prior-high limit triggers from the card. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card-listed FX pair with D1 OHLC data in the DWX matrix.
- `USDCHF.DWX` - card-listed FX pair with D1 OHLC data in the DWX matrix.
- `EURJPY.DWX` - card-listed FX pair with D1 OHLC data in the DWX matrix.
- `EURUSD.DWX` - card-listed FX pair with D1 OHLC data in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest path requires canonical `.DWX` names.
- Index-only symbols - this card is an FX previous-OHLC pending-order strategy.

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
| Trades / year / symbol | 55 |
| Typical hold time | Multiple D1 bars; pending orders evaluate every two trading days. |
| Expected drawdown profile | Slow D1 pending-order system with fixed ATR-defined loss per trade. |
| Regime preference | Breakout / volatility-expansion around prior-day OHLC levels. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `MQL5 article / interview`
**Pointer:** `https://www.mql5.com/en/articles/563`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11031_atc-ohlc-pend.md`

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
| v1 | 2026-06-18 | Initial build from card | 2e469456-0f57-4548-935a-6648c2c2a831 |
