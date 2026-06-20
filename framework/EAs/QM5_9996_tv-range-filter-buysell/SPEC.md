# QM5_9996_tv-range-filter-buysell — Strategy Spec

**EA ID:** QM5_9996
**Slug:** tv-range-filter-buysell
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a closed-bar smoothed range filter on M30. It computes an EMA of absolute close-to-close change over `strategy_range_period`, smooths that value again over `2 * period - 1`, multiplies it by `strategy_range_multiplier`, and advances a stepped filter line only when the closed price moves outside that range. A long signal fires on the first closed bar where close is above a rising filter; a short signal fires on the first closed bar where close is below a falling filter. If the opposite signal appears while a position is open, the EA closes the current position and opens the reverse side on the same entry cycle.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_period` | 100 | 50-200 planned P3 sweep | Sampling period for the absolute-change EMA. |
| `strategy_range_multiplier` | 3.0 | 2.0-4.0 planned P3 sweep | Multiplier applied to the double-smoothed range. |
| `strategy_sl_smoothed_mult` | 1.0 | 1.0-2.0 planned P3 sweep | Initial stop distance in smoothed-range units when ATR SL is disabled. |
| `strategy_use_atr_sl` | false | false/true | Switches the initial stop from smoothed range to ATR. |
| `strategy_atr_period` | 14 | 14 fixed by card | ATR period for alternate stop and optional take-profit. |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.0 planned P3 sweep | ATR stop multiplier when ATR SL is enabled. |
| `strategy_tp_atr_mult` | 0.0 | 0.0, 2.0-4.0 planned P3 sweep | Optional ATR take-profit; `0.0` means off. |
| `strategy_max_hold_bars` | 0 | 0 or 96 planned P3 sweep | Optional maximum holding period in M30 bars; `0` means off. |
| `strategy_spread_sl_fraction` | 0.25 | 0.0-1.0 | Skip entry when modeled spread exceeds this fraction of initial SL distance. |
| `strategy_ma_gate_enabled` | false | false/true | Optional EMA trend gate from community forks. |
| `strategy_ma_period` | 200 | 200 fixed by card | EMA period for the optional trend gate. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card names EURUSD as a portable FX target.
- `GBPUSD.DWX` — card names GBPUSD as a portable FX target.
- `USDJPY.DWX` — card names USDJPY as a portable FX target.
- `XAUUSD.DWX` — card names gold as a portable commodity target.
- `XTIUSD.DWX` — card names crude oil as a portable commodity target.
- `NDX.DWX` — card names Nasdaq 100 as a portable index target.
- `WS30.DWX` — card names Dow 30 as a portable index target.
- `SP500.DWX` — card allows S&P 500 as supplementary backtest coverage; live promotion requires a tradable parallel index.

**Explicitly NOT for:**
- Non-DWX symbols — research and backtest artifacts must use canonical `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Roughly 1-2 trading days between flips; optional cap at 96 M30 bars. |
| Expected drawdown profile | Bounded by initial smoothed-range or ATR stop; trend reversals can whipsaw in chop. |
| Regime preference | Trend-following volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView community Pine script
**Pointer:** https://www.tradingview.com/script/lut7sBgG-Range-Filter-DW/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9996_tv-range-filter-buysell.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | 28880e57-351d-473f-bbdc-8cc429c07576 |
