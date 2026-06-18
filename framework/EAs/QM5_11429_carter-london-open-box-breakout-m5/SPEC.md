# QM5_11429_carter-london-open-box-breakout-m5 — Strategy Spec

**EA ID:** QM5_11429
**Slug:** `carter-london-open-box-breakout-m5`
**Source:** `ec63ff86-b6dd-522b-ac8e-d90de82e2dee` (see `strategy-seeds/sources/ec63ff86-b6dd-522b-ac8e-d90de82e2dee/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The hour before the London open (07:00-08:00 ET) builds a range "box": its high is
the max High and its low the min Low of the twelve M5 bars in that window. In the
60-minute window after the box closes (08:00-09:00 ET), a breakout fires on the
close of an M5 bar — long when the bar closes above `box_high + 0.20*box_height`,
short when it closes below `box_low - 0.20*box_height`. Entry is a market order on
that breakout bar. Stop loss sits on the opposite box side (plus a 1-pip buffer,
capped at 60 pips); take profit is `4.0 * box_height` measured from the broken box
boundary. Any position still open at 10:00 ET is closed by a time stop. One trade
per session, no re-entry. All session windows are derived from each bar's broker-time
open timestamp converted to ET (US-DST aware via `QM_BrokerToUTC` + `QM_IsUSDSTUTC`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `box_start_et_hour` | 7 | 0-23 | ET hour the box window opens (1h before London open) |
| `box_end_et_hour` | 8 | 0-23 | ET hour the box closes / London open |
| `signal_end_et_hour` | 9 | 0-23 | ET hour the breakout window closes |
| `time_stop_et_hour` | 10 | 0-23 | ET hour an open position is force-closed |
| `box_lookback_bars` | 12 | 6-24 | M5 bars in the 60-min box window (scan bound) |
| `box_min_pips` | 5.0 | 1-50 | Minimum box height to accept (degenerate-box filter) |
| `entry_buffer_frac` | 0.20 | 0.05-0.50 | Breakout buffer beyond box edge, fraction of box height |
| `tp_box_mult` | 4.0 | 1.0-6.0 | Take profit as a multiple of box height from boundary |
| `sl_buffer_pips` | 1.0 | 0-10 | SL buffer beyond opposite box side, pips |
| `sl_cap_pips` | 60.0 | 10-150 | SL distance cap from boundary for wide boxes, pips |
| `max_spread_pips` | 15.0 | 1-50 | Wide-spread block cap (fails OPEN on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — Carter primary; high-volatility London-open mover, large boxes.
- `GBPUSD.DWX` — Carter primary; cable is most active at the London open.
- `EURUSD.DWX` — deepest-liquidity major; clean London-open range expansion.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — the edge is the FX London-open liquidity surge; an
  ET-anchored London box on a US-index or DAX symbol builds in the wrong hours.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` (box built from M5 OHLC only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~120` |
| Typical hold time | `minutes to a few hours (intraday; force-closed by 10:00 ET)` |
| Expected drawdown profile | `clustered losing streaks during low-volatility / choppy London opens` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `low (4:1 reward-to-risk by design)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ec63ff86-b6dd-522b-ac8e-d90de82e2dee`
**Source type:** `book`
**Pointer:** `strategy-seeds/sources/ec63ff86-b6dd-522b-ac8e-d90de82e2dee/` — John Carter, "20 Strategies for the 5-Minute Timeframe"
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11429_carter-london-open-box-breakout-m5.md`

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
