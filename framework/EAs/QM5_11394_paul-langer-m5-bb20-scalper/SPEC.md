# QM5_11394_paul-langer-m5-bb20-scalper — Strategy Spec

**EA ID:** QM5_11394
**Slug:** `paul-langer-m5-bb20-scalper`
**Source:** `4852552c-8446-5986-ac32-e63fd176f84a` (Paul Langer, "The Black Book of Forex Trading", 2015)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

M5 Bollinger Band(20, 2) mean-reversion scalp, traded only during the London and
New York opening windows. On each closed M5 bar the EA reads the prior bar
(shift 2) and the just-closed bar (shift 1). A SHORT setup occurs when the prior
bar closed ABOVE the upper band and the just-closed (re-entry) bar closed back
INSIDE the band; a LONG setup is the mirror on the lower band. The re-entry
candle is the single trigger EVENT. On a SHORT the EA places a SELL STOP at the
signal candle's Low minus a 5-pip buffer (SL = signal High + 5 pips); on a LONG a
BUY STOP at the signal candle's High plus 5 pips (SL = signal Low − 5 pips). The
pending order is valid for one bar only (expires after one M5 period) and any
un-triggered pending from the previous bar is removed before a new one is placed.
Take profit is a fixed 20 pips; the stop distance is capped at 25 pips; SL is
moved to break-even once the trade is +10 pips. One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 14-30 | Bollinger Band period |
| `strategy_bb_deviation` | 2.0 | 1.5-2.5 | Bollinger Band std-dev multiplier |
| `strategy_tp_pips` | 20 | 10-30 | Fixed take-profit distance (pips) |
| `strategy_sl_buffer_pips` | 5 | 2-10 | Entry/SL buffer beyond signal-candle extreme (pips) |
| `strategy_sl_max_pips` | 25 | 15-40 | P2 cap on stop distance (pips) |
| `strategy_be_trigger_pips` | 10 | 0-20 | Move SL to break-even at +this profit (pips); 0 disables |
| `strategy_london_start_utc` | 8 | 0-23 | London window start hour (UTC, inclusive) |
| `strategy_london_end_utc` | 12 | 0-23 | London window end hour (UTC, exclusive) |
| `strategy_ny_start_utc` | 13 | 0-23 | NY window start hour (UTC, inclusive) |
| `strategy_ny_end_utc` | 17 | 0-23 | NY window end hour (UTC, exclusive) |
| `strategy_spread_cap_pips` | 15.0 | 5-30 | Block only a genuinely wide spread > this (pips); fail-open on zero |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deepest liquidity at London/NY opens; tight BB mean-reversion behaviour.
- `GBPUSD.DWX` — high intraday range at London open; classic scalp pair.
- `USDJPY.DWX` — liquid through both sessions; pip-scaled SL/TP handled via QM_StopRules.

**Explicitly NOT for:**
- Index/commodity CFDs — the BB(20,2) re-entry scalp and 20-pip TP are calibrated for FX majors, not index volatility.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~500` |
| Typical hold time | `minutes (intraday scalp, 20-pip target)` |
| Expected drawdown profile | `shallow, frequent small wins/losses; clusters in choppy sessions` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `4852552c-8446-5986-ac32-e63fd176f84a`
**Source type:** `book`
**Pointer:** Paul Langer, "The Black Book of Forex Trading" (Alura Publishing, 2015), Scalping Strategy
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11394_paul-langer-m5-bb20-scalper.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
