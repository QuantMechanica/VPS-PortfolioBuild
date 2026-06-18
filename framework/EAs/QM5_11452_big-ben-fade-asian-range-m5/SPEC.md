# QM5_11452_big-ben-fade-asian-range-m5 — Strategy Spec

**EA ID:** QM5_11452
**Slug:** `big-ben-fade-asian-range-m5`
**Source:** `13c7b215-7691-51e6-9d93-c51116b3c98d` (see `strategy-seeds/sources/13c7b215-7691-51e6-9d93-c51116b3c98d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The "Big Ben" fade trades the failed breakout of the Asian range at the London
open on M5. The Asian range is the high/low of all bars in 00:00–07:00 GMT. In
the pre-London hour (07:00–08:00 GMT) price often "fakes out" — a bar breaks
below the Asian low (minus a 3-pip probe buffer) or above the Asian high — and
then snaps back. In the London fade window (08:00–09:00 GMT) the first M5 bar
that CLOSES back inside the Asian range confirms the fake: enter a fade in the
opposite direction of the probe (BUY after a false breakdown, SELL after a false
breakout), targeting the Asian-range midpoint. If both sides probe in one
session the signal is ambiguous and the day is skipped. Stop loss sits beyond
the swept Asian boundary by 10 pips (hard-capped at 25 pips); any open position
is flat-closed at the 09:00 GMT time stop. All session windows are derived from
the closed-bar timestamp converted from broker time to UTC (`QM_BrokerToUTC`),
so the GMT windows stay correct across US-DST transitions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_asian_start_hour` | 0 | 0-23 | Asian range start (GMT hour, inclusive) |
| `strategy_asian_end_hour` | 7 | 0-23 | Asian range end / probe start (GMT hour, exclusive) |
| `strategy_london_open_hour` | 8 | 0-23 | London open / fade window start (GMT hour) |
| `strategy_time_stop_hour` | 9 | 0-23 | Force-close hour (GMT hour, >= => exit) |
| `strategy_probe_pips` | 3.0 | 1-10 | Probe must extend this far beyond the Asian range |
| `strategy_range_min_pips` | 15.0 | 5-40 | Asian range minimum width (pips) |
| `strategy_range_max_pips` | 70.0 | 40-150 | Asian range maximum width (pips) |
| `strategy_sl_buffer_pips` | 10.0 | 5-20 | SL beyond the swept Asian boundary (pips) |
| `strategy_sl_cap_pips` | 25 | 15-40 | SL distance hard cap (pips) |
| `strategy_tp_min_pips` | 10.0 | 5-25 | Floor TP at least this far from entry (pips) |
| `strategy_spread_pct_of_stop` | 25.0 | 10-50 | Skip only if spread > this % of stop distance |
| `strategy_spread_cap_pips` | 15.0 | 5-30 | Absolute spread cap (pips); card spread cap |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid pair; cleanest London-open behaviour around the Asian range.
- `GBPUSD.DWX` — high London-session participation; the original "Big Ben" pair.
- `USDJPY.DWX` — active Asian session forms a well-defined range to fade at London.
- `AUDUSD.DWX` — Asian-session driven; range well-formed before London.
- `USDCAD.DWX` — liquid USD pair; London-open mean reversion of the Asian range.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the Asian/London FX session structure this
  strategy exploits does not apply.

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
| Trades / year / symbol | `~220` |
| Typical hold time | `minutes to ~1 hour (intraday; flat by 09:00 GMT)` |
| Expected drawdown profile | `small per-trade risk (SL capped 25 pips); clustered losing streaks in trending London opens` |
| Regime preference | `mean-revert / failed-breakout fade` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `13c7b215-7691-51e6-9d93-c51116b3c98d`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/13c7b215-7691-51e6-9d93-c51116b3c98d/` (local PDF `450251566-Big-Ben-Breakout-Strategy-pdf.pdf`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11452_big-ben-fade-asian-range-m5.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor worktree |
