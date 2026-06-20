# QM5_11481_carter-t-ny-open-box-m5 - Strategy Spec

**EA ID:** QM5_11481
**Slug:** carter-t-ny-open-box-m5
**Source:** b3b11449-1e72-5140-917b-c35b6253f1e7 (see `sources/carter-thomas-20-forex-m5`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a New York open breakout box on M5 FX symbols. At the M5 bar whose open time is 13:00 UTC, it reads a fixed 12-bar Carter box using the card formula equivalent to `iHighest/iLowest(PERIOD_M5, 12, 12)`, then places a BUYSTOP above the box and a SELLSTOP below the box. The breakout trigger is the box edge plus or minus 20% of box height, the stop loss is the opposite box edge, and the take profit is 4.0 box heights from the trigger. Unfilled stop orders expire after 60 minutes, the opposite stop is cancelled after one side fills, and an open position is closed at market after 120 minutes if TP or SL has not closed it first.

---

## 2. Parameters

Table of every input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_box_bars` | 12 | 1-48 | Number of M5 bars in the Carter opening box. |
| `strategy_box_start_shift` | 12 | 1-288 | First historical M5 shift used for the box, matching the card's literal `start=12` formula. |
| `strategy_breakout_fraction` | 0.20 | 0.05-0.50 | Fraction of box height added beyond the box edge for stop-entry triggers. |
| `strategy_tp_box_mult` | 4.0 | 1.0-8.0 | Take-profit distance in multiples of box height from the trigger price. |
| `strategy_order_valid_minutes` | 60 | 5-180 | Maximum time an unfilled stop order remains valid. |
| `strategy_position_time_stop_minutes` | 120 | 15-360 | Maximum hold time before market exit if TP/SL has not fired. |
| `strategy_box_max_pips` | 60 | 1-300 | Skip the session when the measured box height exceeds this pip cap. |
| `strategy_spread_cap_pips` | 15 | 1-100 | Skip entry when modeled spread is genuinely wider than this cap. Zero spread is allowed. |
| `strategy_ny_open_utc_hour` | 13 | 0-23 | UTC hour of the NY-open box placement bar. |
| `strategy_ny_open_utc_minute` | 0 | 0-59 | UTC minute of the NY-open box placement bar. |
| `strategy_skip_friday_entries` | true | true/false | Blocks new Friday entries while leaving existing trade management to the framework. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - card-listed M5 FX symbol with direct DWX availability.
- `GBPUSD.DWX` - card-listed M5 FX symbol with direct DWX availability.
- `EURUSD.DWX` - card-listed M5 FX symbol with direct DWX availability.
- `USDJPY.DWX` - card-listed M5 FX symbol with direct DWX availability.
- `AUDUSD.DWX` - card-listed M5 FX symbol with direct DWX availability.

**Explicitly NOT for:**
- Non-FX index, metal, energy, and equity symbols - the card specifies an M5 FX NY-open breakout basket, not a cross-asset basket.
- FX symbols outside the registered list - they were not named in the R3 PASS section for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Stop orders valid for 60 minutes; filled trades time-stop after 120 minutes. |
| Expected drawdown profile | Breakout profile with clustered losses during false NY-open breaks. |
| Regime preference | NY-open volatility expansion and directional breakout. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b3b11449-1e72-5140-917b-c35b6253f1e7
**Source type:** self-published named-author trading system collection
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), System #7 (thomascarterbook.blogspot.com, 2014)
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11481_carter-t-ny-open-box-m5.md`

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
| v1 | 2026-06-20 | Initial build from card | b93d37ea-b6fd-4f7d-8f30-5e8c9b302026 |
