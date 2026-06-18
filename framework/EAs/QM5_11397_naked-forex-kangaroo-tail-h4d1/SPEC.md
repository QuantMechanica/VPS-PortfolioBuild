# QM5_11397_naked-forex-kangaroo-tail-h4d1 — Strategy Spec

**EA ID:** QM5_11397
**Slug:** `naked-forex-kangaroo-tail-h4d1`
**Source:** `94a3a139-a123-57c2-ae40-b5513532e244` (see `strategy-seeds/sources/94a3a139-a123-57c2-ae40-b5513532e244/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Trades the "Kangaroo Tail" single-bar pin-bar reversal from Naked Forex (Ch.8).
The signal is evaluated on the just-closed bar (shift 1). A bullish kangaroo
tail goes LONG when: the lower tail is at least 60% of the bar range, both open
and close sit in the top third of the range, the body lies entirely within the
prior bar's high/low range, and the bar's low pierces the lowest low of the
preceding 20 bars (an N-bar-extreme context proxy that replaces visual support
zones). The bearish mirror goes SHORT on a long upper tail piercing a 20-bar
high. Entry is a market order on the bar after the completed pin; the stop is 5
pips beyond the tail extreme (capped at 60 pips), the take-profit is 2× ATR(14)
from entry, and the position is moved to break-even once price advances 1× ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tail_min_ratio` | 0.60 | 0.50-0.70 | Min tail length as a fraction of the bar range |
| `strategy_ctx_lookback` | 20 | 10-30 | N-bar extreme window for the context (S/R proxy) filter |
| `strategy_sl_buffer_pips` | 5 | 2-15 | Stop distance beyond the tail extreme, in pips |
| `strategy_sl_cap_pips` | 60 | 30-100 | P2 cap on total stop distance, in pips |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the take-profit distance |
| `strategy_tp_atr_mult` | 2.0 | 1.5-2.5 | Take-profit distance as a multiple of ATR |
| `strategy_be_trigger_atr` | 1.0 | 0.5-2.0 | Move to break-even once price advances this × ATR |
| `strategy_spread_cap_pips` | 20.0 | 5-40 | Block entry only if spread exceeds this many pips (fail-open on zero) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, deep liquidity, clean H4/D1 candles for pin-bar geometry.
- `GBPUSD.DWX` — major FX pair, higher volatility favours pronounced kangaroo tails.
- `USDJPY.DWX` — major FX pair, JPY pip-scaling handled by the framework pip-factor.
- `AUDUSD.DWX` — major FX pair, range-prone behaviour suits mean-reversion pin bars.

**Explicitly NOT for:**
- Index/metal CFDs (NDX.DWX, WS30.DWX, XAUUSD.DWX) — card is a forex pin-bar pattern; thresholds are calibrated to FX ranges.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` (primary); `D1` variant per card |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `clustered losses in trending regimes when reversals fail` |
| Regime preference | `mean-revert (reversal at extremes)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `94a3a139-a123-57c2-ae40-b5513532e244`
**Source type:** `book`
**Pointer:** Alex Nekritin & Walter Peters, *Naked Forex* (Wiley 2012), Ch.8 — Kangaroo Tails
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11397_naked-forex-kangaroo-tail-h4d1.md`

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
