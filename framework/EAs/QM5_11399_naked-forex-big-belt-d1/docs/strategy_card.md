---
ea_id: QM5_11399
slug: naked-forex-big-belt-d1
type: strategy
source_id: 94a3a139-a123-57c2-ae40-b5513532e244
source_citation: "Alex Nekritin and Walter Peters, Naked Forex (Wiley, 2012), Chapter 9, The Big Belt."
source_citations:
  - type: book
    citation: "Nekritin, Alex, and Walter Peters. Naked Forex. Wiley, 2012."
    location: "Chapter 9, The Big Belt"
    quality_tier: A
    role: primary
indicators: []
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, GBPJPY.DWX]
markets: [forex]
period: D1
timeframes: [D1]
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-08-12
ml_required: false
g0_approval_reasoning: "R1 PASS via named authors and Wiley publication; R2 PASS via deterministic completed-bar OHLC rules and fixed exits; R3 PASS on registered DWX D1 FX symbols; R4 PASS with arithmetic-only rules and no ML, grid, martingale, or adaptive sizing. Schema-normalized build-time mirror of the existing approved farm artifact."
---

# Naked Forex Big Belt D1 — build-time card mirror

Canonical repository card:
`strategy-seeds/cards/naked-forex-big-belt-d1_card.md`.

## Hypothesis

A completed daily bar that gaps beyond the prior close, opens near one
extreme, closes near the opposite extreme, and forms at a recent price extreme
represents an exhausted opening impulse. A stop entry beyond that bar tests
whether price continues away from the failed impulse. This FX port receives no
performance claim from the source.

## Rules

- Bearish: completed D1 bar opens above the prior close, opens in its top
  third, closes in its bottom third, and makes a new 20-bar high; place a sell
  stop 5 pips below its low.
- Bullish: mirror the rule at a new 20-bar low; place a buy stop 5 pips above
  its high.
- Pending orders expire after one completed D1 bar.
- Initial stop is 5 pips beyond the opposite candle extreme, with risk
  distance capped at 100 pips.
- Target is `2.5 * ATR(14, D1)`; move the stop to entry after a favorable
  `1.0 * ATR(14, D1)` move.
- Framework Friday close, news, kill-switch, and environment guards remain
  enabled.
- No grid, martingale, scaling, partial close, trailing stop, or adaptive
  parameter logic.

## Risk

- Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Active slots are EURUSD 0, GBPUSD 1, USDJPY 2, AUDUSD 3, and GBPJPY 4.
- One position or pending order per registered magic/symbol.
- This card authorizes research/backtest packaging only; no live setfile,
  T_Live, AutoTrading, deployment, or portfolio admission is authorized.

## Parameters To Test

| Parameter | Baseline | Bounded sweep |
|---|---:|---|
| `strategy_extreme_lookback_bars` | 20 | 10, 20, 30 |
| `strategy_atr_period` | 14 | fixed |
| `strategy_atr_tp_mult` | 2.5 | 2.0, 2.5, 3.0 |
| `strategy_entry_offset_pips` | 5 | fixed |
| `strategy_sl_cap_pips` | 100 | fixed |
| `strategy_spread_cap_pips` | 30 | fixed |
| `strategy_be_buffer_pips` | 0 | fixed |
| `strategy_order_expiration_bars` | 1 | fixed |

## Kill Criteria

Retire the baseline on insufficient Q02 cadence, non-deterministic pending
order behavior, fixed-risk validation failure, or failed after-cost economics.
Do not relax the gap or recent-extreme rules to manufacture trades.

## Pipeline History

| date | phase | verdict | evidence |
|---|---|---|---|
| 2026-08-12 | Q01 | PASS | Strict compile and scoped strict build check passed with zero errors or warnings. |
| 2026-08-12 | Q02 | ENQUEUED | AUDUSD, EURUSD, and GBPJPY were enqueued target-only; GBPUSD and USDJPY remain durably deferred. |
