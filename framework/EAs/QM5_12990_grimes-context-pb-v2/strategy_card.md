---
ea_id: QM5_12990
slug: grimes-context-pb-v2
strategy_id: EXIT-SURGERY-FAB16F34-2026-07-03
type: strategy
source_id: fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
source_citation: "Adam H. Grimes, Context in Pullbacks: What Should Happen?, 2023-11-29, https://www.adamhgrimes.com/context-in-pullbacks-what-should-happen/"
parent_ea: QM5_10939
target_symbols: [GBPUSD.DWX]
period: H4
expected_trade_frequency: "GBPUSD H4 contextual pullback; approximately 10 trades/year in the current 2017-2025 reconstruction."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-13
g0_approval_reasoning: "OWNER-authorized exit-surgery challenger of QM5_10939. Only the breakeven trigger (1.0R to 1.5R) and H4 time exit (18 to 36 bars) change; entries, initial stop, target and news behavior remain source-identical. Pipeline evidence, not this approval, determines deploy eligibility."
---

# Grimes Contextual Pullback Continuation v2 - GBPUSD H4

## Source And Lineage

The underlying source is Adam H. Grimes, "Context in Pullbacks: What Should
Happen?" The approved parent is `QM5_10939_grimes-context-pb`. This card records
the separate GBPUSD exit-surgery challenger proposed in
`docs/ops/evidence/D2C_13SLEEVE_EXIT_SURGERY_AUDIT_2026-07-03.md` and verified
in `docs/ops/evidence/872618f1_challenger_swap_12990_2026-07-03.md`.

## Mechanics

### Entry

- Evaluate GBPUSD on H4 with D1 trend context.
- Long: D1 close above EMA(50), EMA(20) above EMA(50), and D1 ADX(14) at
  least 16.
- Require a surprise leg within 12 H4 bars that spans at least 2.5 ATR(20)
  and closes beyond the prior 30-bar high.
- Require a controlled 25%-55% pullback over 3-10 bars that holds H4 EMA(20)
  and contains no bar larger than 1.5 ATR.
- Enter after an H4 close above the pullback's three-bar high. Shorts mirror
  the rules in a D1 downtrend.

### Exit And Stop

- Initial stop: pullback extreme plus a 0.25 ATR buffer; reject a stop wider
  than 2.25 ATR.
- Target: 2.0R.
- Move the stop to breakeven at **1.5R**. Parent `10939` used 1.0R.
- Exit on an adverse H4 close beyond the surprise leg's 61.8% retracement.
- Time exit after **36 H4 bars (144 hours)**. Parent `10939` used 18 bars.

All entry logic, initial-stop logic, target, one-position constraint, climax
filter, spread filter, news behavior, and Friday behavior remain unchanged from
the parent. Source-diff evidence confirms the two intended parameter changes.

## Scope

- Symbol: `GBPUSD.DWX` only.
- Timeframe: `H4` with D1 context.
- Magic slot: registry slot 1.
- Backtest risk: `RISK_FIXED=1000`.
- This card approval authorizes testing the variant. It does not waive Q02-Q10,
  FTMO cost, floating-MAE, governor, or deploy-manifest gates.

## R1-R4

| Gate | Status | Rationale |
|---|---|---|
| R1 | PASS | Named source and approved parent strategy are recorded. |
| R2 | PASS | Entry, stop, target, BE and time-exit rules are deterministic. |
| R3 | PASS | GBPUSD.DWX H4/D1 data are present in the MT5 research matrix. |
| R4 | PASS | Fixed rules only; no ML, grid, martingale, or adaptive sizing. |

## Pipeline Status

G0 is approved for the challenger build. Existing portfolio and FTMO research
results remain research evidence; current-binary requalification is required
before deployment.
