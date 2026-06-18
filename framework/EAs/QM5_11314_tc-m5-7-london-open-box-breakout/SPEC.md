# QM5_11314_tc-m5-7-london-open-box-breakout — Strategy Spec

**EA ID:** QM5_11314
**Slug:** `tc-m5-7-london-open-box-breakout`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A previous-hour opening-range (box) breakout on M5. At the session start (the
card anchors this to 08:00 New York time = 13:00 GMT), the EA builds a box from
the prior hour's M5 bars (07:00-07:59 NY): `box_high` = highest high, `box_low`
= lowest low, `box_height = box_high - box_low`. The session/box window is
derived purely from the bar TIMESTAMP in broker time (DXZ broker = NY-Close
GMT+2/+3), converted broker→UTC via `QM_BrokerToUTC` and then to NY wall-clock
using the US-DST-aware offset (EDT -4 / EST -5).

A LONG fires when a closed M5 bar CLOSES above `box_high + 0.20 × box_height`;
a SHORT fires when a closed M5 bar CLOSES below `box_low - 0.20 × box_height`.
The breakout close is the single EVENT (not an intrabar range touch — robust on
gapless .DWX CFDs). The signal is valid only inside the 1-hour session window
and at most one trade fires per session. Stop-loss is the opposite side of the
box (LONG SL = box_low, SHORT SL = box_high); take-profit is `box_high + 4.00 ×
box_height` (LONG) / `box_low - 4.00 × box_height` (SHORT). Once price is 1×
box_height in profit, the stop trails 1× box_height behind price. Sessions whose
box height is > 80 pips or < 5 pips are skipped.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_ny_hour` | 8 | 0-23 | NY hour at which the box "fires" (card: 08:00 NY) |
| `strategy_box_hours` | 1 | 1-3 | Box = this many hours immediately before session start |
| `strategy_session_window_hours` | 1 | 1-3 | Signal valid for this many hours after session start |
| `strategy_breakout_threshold` | 0.20 | 0.05-0.50 | Breakout level = this × box_height beyond the box edge |
| `strategy_tp_mult` | 4.00 | 1.0-6.0 | TP = this × box_height beyond the box edge |
| `strategy_max_box_pips` | 80.0 | 20-150 | Skip session if box height > this many pips |
| `strategy_min_box_pips` | 5.0 | 1-30 | Skip session if box height < this many pips |
| `strategy_trail_activate_mult` | 1.00 | 0.5-3.0 | Begin trailing once +this × box_height in profit |
| `strategy_trail_distance_mult` | 1.00 | 0.5-3.0 | Trail SL by this × box_height behind price |
| `strategy_spread_pct_of_box` | 25.0 | 5-100 | Skip if spread > this % of box height (fail-open on zero spread) |

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
| v1 | 2026-06-18 | Initial build from card | broker-time-derived box; central step (resolver/compile/setfile/smoke) deferred |
