---
ea_id: QM5_12791
slug: monday-range-breakout
type: strategy
source_id: sm-mining-sm007-monday-range-2026
sources:
  - "[[sources/calendar-anomaly-monday-range]]"
  - "[[sources/sm-strategy-mining-campaign]]"
concepts:
  - "[[concepts/calendar-anomaly]]"
  - "[[concepts/range-breakout]]"
  - "[[concepts/weekly-seasonality]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Weekly range-breakout calendar effect (Monday's D1 range as the week's reference box). Mined + walk-forward-validated in OWNER's SM campaign (SM_007, USDJPY): gross PF 1.45, positive holdout (1.24). R1-R4 waived for discovery."
r2_mechanical: PASS
r2_reasoning: "Deterministic: break of Monday D1 high/low + 5pip buffer during Tue-Thu 8-18 EET, range gated 30-150 pips; SL = opposite range side (or ATR); TP 1.5R; BE@1R; max 2/week; Friday close. Source teardown = CLEAN (single position, hard SL, ticket-tracked BE, no recovery)."
r3_data_available: PASS
r3_reasoning: "USDJPY.DWX H1 entry / D1 range; ATR only; no external data."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no martingale/grid, single bounded position, hard SL, BE never widens. Can hold overnight -> swap injected at Q08."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 33
expected_pf: 1.40
expected_dd_pct: 12
last_updated: 2026-06-29
g0_approval_reasoning: "G0 2026-06-29 Claude. 2nd firm pick of OWNER's SM mining campaign (Dropbox audit). MOST cost-robust accepted strategy: net PF ~1.40 @ $10/lot (wide range-stop -> ~1.7 lots/trade -> keeps ~97% of edge); positive OOS (HO 1.24). Breakout edge-type (our highest historical accept-rate) + USDJPY adds symbol diversification away from the GBP cluster. New calendar/seasonality edge class, decorrelated to the book. FX = high-commission but low cadence + wide range-stop = cost-viable. Decisive gate: Q04 net-of-cost + Q08."
---

# Monday Range Breakout (SM_007 -> V5 port)

## Purpose
Port the most cost-robust accepted strategy from OWNER's SM mining campaign: a weekly
range-breakout calendar effect. A clean, cost-tolerant, decorrelated low-freq diversifier.

## Source
`Dropbox/FTMO March 2026/SM_Portfolio_Deploy/Experts/FTMO_SM_007_MondayRange.mq5` (read in full,
verified clean). USDJPY: gross PF 1.45 / 199 trades, holdout PF 1.24.

## Strategy (build spec)
- **Reference box:** Monday's D1 high/low.
- **Entry:** break of Monday high + 5pip (LONG) / Monday low - 5pip (SHORT), during Tue-Thu
  08:00-18:00 EET. Gate: Monday range must be 30-150 pips (skip too-tight / too-wide weeks).
- **Stop:** hard SL = opposite side of the Monday range + 10pip (or ATR-based).
- **Target:** TP = 1.5 x R; move to breakeven at 1R.
- **Limits:** max 2 trades/week; Friday close. ~33 trades/yr. One position, single magic.

## V5 conventions
RISK_FIXED backtest / RISK_PERCENT live (add the switch); QM_KillSwitch (3% daily breaker);
QM_NewsFilter (DL-080) fail-closed; magic = ea_id*10000+slot; QM_RiskSizer/QM_Logger; closed-bar;
chart symbol. Inject commission + swap (can hold overnight).

## Instruments
USDJPY lead (mined+validated). Optional: GBPUSD/EURUSD/AUDUSD (the box-breakout calendar effect is
FX-broad). FX high-commission but low cadence + wide range-stop = cost-viable.

## Acceptance
Q02 + trade floor -> Q04 net-of-cost walk-forward -> Q08. Realistic net PF ~1.4. Value = a
decorrelated calendar/breakout edge class for the book; anti-correlation check at portfolio admission
(should be low-corr to Turnaround-Tuesday 12788 and to the trend/MR sleeves).
