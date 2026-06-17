# QM5_11043_atc-d1-correct — Strategy Spec

**EA ID:** QM5_11043
**Slug:** `atc-d1-correct`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Prior-day high/low correction (mean reversion), evaluated on completed H1 bars. At
each new H1 bar the EA reads the previous D1 high, low, range and midpoint. A LONG
fires when the last closed H1 bar's low pierced below the prior-D1 low by at least
`level_buffer_pips` AND that bar closed back above the prior-D1 low; a SHORT fires
on the mirror condition at the prior-D1 high. Entry is at the next bar's market
open. The take-profit is the midpoint of the previous D1 range. The stop sits below
the piercing bar's low (long) / above its high (short) by `sl_buffer_pips`, with the
stop DISTANCE capped to `sl_atr_cap_mult * ATR(14,H1)` and a hard emergency ceiling
of `sl_atr_emergency_mult * ATR(14,H1)`. Positions also exit when an opposite
correction setup triggers, or at end of the broker session window (time exit). Days
whose prior-D1 range is below `ATR(20,D1) * range_floor_mult` are skipped; at most
one trade per side per symbol per broker day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_level_buffer_pips` | 5 | 0-20 | Min pierce beyond the prior-D1 level (pips) |
| `strategy_sl_buffer_pips` | 10 | 5-20 | SL buffer beyond the piercing-bar extreme (pips) |
| `strategy_atr_period_h1` | 14 | 5-30 | ATR period on H1 for SL caps |
| `strategy_sl_atr_cap_mult` | 1.5 | 1.0-2.0 | Stop distance capped to mult × ATR(14,H1) |
| `strategy_sl_atr_emergency_mult` | 2.0 | 1.5-3.0 | Hard emergency max stop distance = mult × ATR |
| `strategy_atr_period_d1` | 20 | 10-30 | ATR period on D1 for the range-regime filter |
| `strategy_range_floor_mult` | 0.5 | 0.3-1.0 | Skip the day if prior-D1 range < ATR(20,D1) × mult |
| `strategy_session_start_hour` | 6 | 0-23 | Broker-hour: first hour trading allowed |
| `strategy_session_end_hour` | 20 | 0-23 | Broker-hour: trading/holding ends (flat after) |
| `strategy_spread_pct_of_stop` | 25.0 | 5-50 | Skip if spread > this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — card's historical primary pair; liquid, clear prior-day levels.
- `EURUSD.DWX` — most liquid FX major; tight ranges suit level-rejection reversion.
- `EURJPY.DWX` — JPY cross with clean daily structure; pip-scaling handled via `QM_StopRulesPipsToPriceDistance`.
- `USDJPY.DWX` — major JPY pair; complements the EURJPY cross for diversification.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the strategy is calibrated to FX-major prior-day ranges and pip scaling; index volatility profile differs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | prior-D1 high/low/range + ATR(20,D1) (PERIOD_D1 closed-bar reads) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` (card range 35-90) |
| Typical hold time | `intraday — hours, flat by session end` |
| Expected drawdown profile | `bounded by fixed risk, ATR-capped SL, daily trade cap, time exit; hurt by trend days that keep extending` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum` (MQL5 Articles interview)
**Pointer:** `https://www.mql5.com/en/articles/556`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11043_atc-d1-correct.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
