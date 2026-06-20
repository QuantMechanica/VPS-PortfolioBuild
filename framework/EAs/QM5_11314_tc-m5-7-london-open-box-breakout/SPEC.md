# QM5_11314_tc-m5-7-london-open-box-breakout — Strategy Spec

**EA ID:** QM5_11314
**Slug:** `tc-m5-7-london-open-box-breakout`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

A previous-hour opening-range (box) breakout on M5. At the session start (the
card anchors this to 08:00 New York time = 13:00 GMT), the EA builds a box from
the prior hour's M5 bars: `box_high` = highest high, `box_low` = lowest low,
`box_height = box_high - box_low`. The card equates the session with fixed
13:00-14:00 GMT and gives broker-hour examples for that GMT anchor, so the EA
converts broker time to UTC via `QM_BrokerToUTC` and uses 13:00 UTC as the
session start.

A LONG fires when a closed M5 bar CLOSES above `box_high + 0.20 × box_height`;
a SHORT fires when a closed M5 bar CLOSES below `box_low - 0.20 × box_height`.
The breakout close is the single EVENT (not an intrabar range touch — robust on
gapless .DWX CFDs). The signal is valid only inside the 1-hour session window
and at most one trade fires per session. Stop-loss is the opposite side of the
box (LONG SL = box_low, SHORT SL = box_high); take-profit is `box_high + 4.00 ×
box_height` (LONG) / `box_low - 4.00 × box_height` (SHORT). Once price is 1×
box_height in profit, the stop trails 1× box_height behind price. Sessions whose
box height is > 80 pips or < 5 pips are skipped, and spread only blocks when it
is genuinely wider than the card's 20-pip cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_utc_hour` | 13 | 0-23 | UTC hour at which the box "fires" (card: 13:00 GMT) |
| `strategy_box_hours` | 1 | 1-3 | Box = this many hours immediately before session start |
| `strategy_session_window_hours` | 1 | 1-3 | Signal valid for this many hours after session start |
| `strategy_breakout_threshold` | 0.20 | 0.05-0.50 | Breakout level = this × box_height beyond the box edge |
| `strategy_tp_mult` | 4.00 | 1.0-6.0 | TP = this × box_height beyond the box edge |
| `strategy_max_box_pips` | 80.0 | 20-150 | Skip session if box height > this many pips |
| `strategy_min_box_pips` | 5.0 | 1-30 | Skip session if box height < this many pips |
| `strategy_trail_activate_mult` | 1.00 | 0.5-3.0 | Begin trailing once +this × box_height in profit |
| `strategy_trail_distance_mult` | 1.00 | 0.5-3.0 | Trail SL by this × box_height behind price |
| `strategy_spread_cap_pips` | 20.0 | 1-100 | Skip if spread > this many pips (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — card primary; volatile GBP pair the original system prefers for the London/NY-morning box.
- `GBPJPY.DWX` — card secondary; high-volatility GBP cross, large clean box ranges.
- `EURUSD.DWX` — card P2 expansion; most liquid major, baseline diversification across the breakout window.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the card's pip-scaled box-height filter and the NY-morning FX session anchor are specific to liquid FX majors/crosses.

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
| Trades / year / symbol | `~120` |
| Typical hold time | `minutes to a few hours (intraday; closes within the session/day)` |
| Expected drawdown profile | `frequent small losers (box-low stop), occasional large 4R winners` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `low` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #7 (local Dropbox PDF archive)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11314_tc-m5-7-london-open-box-breakout.md`

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
| v1 | 2026-06-20 | Initial build from card | b294af01-0b88-4066-b5a3-f98d72ba7fd5 |
