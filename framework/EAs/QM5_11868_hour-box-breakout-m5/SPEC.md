# QM5_11868_hour-box-breakout-m5 — Strategy Spec

**EA ID:** QM5_11868
**Slug:** hour-box-breakout-m5
**Source:** 7eb3773b-4c7d-5f72-9c2a-99773154821f (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Each M5 trading day, the EA measures the high and low of the one-hour box before the card's 08:00 EST reference point. At the box close it places a buy stop 20% of the box height above the box high and a sell stop 20% of the box height below the box low. The first filled breakout is traded; the opposite pending order is removed after a fill or after the one-hour signal window expires. Take profit is 4x box height from entry, stop loss is the opposite box boundary, and the stop trails by one box height after price moves at least one box height in favour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_box_start_hour_utc` | 12 | 0-23 | Non-US-DST UTC hour where the 60-minute box starts. |
| `strategy_box_end_hour_utc` | 13 | 0-23 | Non-US-DST UTC hour where the box closes and orders are placed. |
| `strategy_box_start_hour_utc_us_dst` | 14 | 0-23 | US-DST UTC hour where the 60-minute box starts, per card frontmatter. |
| `strategy_box_end_hour_utc_us_dst` | 15 | 0-23 | US-DST UTC hour where the box closes and orders are placed, per card frontmatter. |
| `strategy_box_minutes` | 60 | 5-240 | Number of M5 minutes used to compute the box high and low. |
| `strategy_breakout_entry_pct` | 0.20 | 0.01-1.00 | Entry offset as a fraction of box height beyond the box boundary. |
| `strategy_tp_box_multiples` | 4.0 | 0.1-10.0 | Take-profit distance in multiples of box height. |
| `strategy_signal_window_minutes` | 60 | 1-240 | Pending-order lifetime after the box closes. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap in points; 0 disables the cap. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — card-stated forex target and present in `dwx_symbol_matrix.csv`.
- `GBPUSD.DWX` — card-stated forex target and present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Index, commodity, and non-GBP forex symbols — not named by the approved card for this time-box breakout.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework OnTick gate before entry) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 80 |
| Typical hold time | minutes to a few hours; pending orders expire after 1 hour |
| Expected drawdown profile | breakout strategy with clustered losses during false-breakout sessions |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | low to medium, offset by 4x box-height target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7eb3773b-4c7d-5f72-9c2a-99773154821f
**Source type:** book
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), 2014. URL: local PDF archive
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11868_hour-box-breakout-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 76a0bb01-8660-4f1f-ad27-5d29e43dcc9f |
