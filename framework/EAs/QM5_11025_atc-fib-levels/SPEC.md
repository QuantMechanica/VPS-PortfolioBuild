# QM5_11025_atc-fib-levels - Strategy Spec

**EA ID:** QM5_11025
**Slug:** atc-fib-levels
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars and finds the most recent confirmed swing high and swing low using a fixed fractal-style window. It builds Fibonacci levels at 38.2%, 50%, 61.8%, 100%, and 161.8% between the active swing low and high. It enters on either a close that breaks a nearby Fibonacci level by an ATR buffer, or on a bar that tests a Fibonacci level and closes back through it. The stop is one ATR beyond the signal level, and the target is the closer of 1.5R or the next Fibonacci level in the trade direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_lookback` | 24 | 12-48 tested | H1 bars searched for the active swing high and low. |
| `strategy_swing_confirmation` | 3 | 2-5 tested | Bars required on both sides to confirm a swing point. |
| `strategy_atr_period` | 14 | fixed by card | ATR period used for break buffer, range filter, and stop distance. |
| `strategy_break_buffer_atr` | 0.10 | 0.05-0.20 tested | ATR multiple required beyond a Fibonacci level for breakthrough entries. |
| `strategy_min_range_atr` | 1.50 | fixed by card | Minimum swing range as a multiple of ATR. |
| `strategy_sl_atr_mult` | 1.00 | 0.75-1.50 tested | ATR multiple placed beyond the entry Fibonacci level for stop loss. |
| `strategy_tp_rr` | 1.50 | 1.0-2.0 tested | Baseline R multiple used when it is closer than the next Fibonacci level. |
| `strategy_mode` | `FIB_MODE_BOTH` | breakthrough / rejection / both | Selects breakthrough entries, rejection entries, or both. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX major, suitable for H1 swing and Fibonacci level tests.
- `GBPUSD.DWX` - card-listed DWX FX major, suitable for H1 swing and Fibonacci level tests.
- `USDJPY.DWX` - card-listed DWX FX major, suitable for H1 swing and Fibonacci level tests.
- `XAUUSD.DWX` - card-listed DWX metal CFD, suitable for H1 swing and Fibonacci level tests.

**Explicitly NOT for:**
- Non-DWX symbols - outside the V5 research/backtest naming convention.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Not specified in card frontmatter; expected hours to days from H1 SL/TP and opposite-signal exits. |
| Expected drawdown profile | Whipsaw-prone around Fibonacci levels when local highs/lows are inaccurate. |
| Regime preference | Breakout and mean-reversion around local swing Fibonacci levels. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article interview
**Pointer:** Li Fang, Interview with Li Fang (ATC 2011), MQL5 Articles, 2011-12-16
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11025_atc-fib-levels.md`

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
| v1 | 2026-06-07 | Initial build from card | 3ff8ceb6-2e34-42bd-83b4-0a26e1dd10ac |
