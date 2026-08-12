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
sources:
  - "[[sources/naked-forex-wiley-2012]]"
concepts:
  - "[[concepts/gap-reversal]]"
  - "[[concepts/candlestick-pattern]]"
indicators: []
strategy_type_flags: [daily-price-structure, gap-reversal, symmetric-long-short, atr-target, break-even, pending-entry]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, GBPJPY.DWX]
primary_target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, GBPJPY.DWX]
markets: [forex]
period: D1
timeframes: [D1]
expected_trade_frequency: "Sparse D1 gap-reversal setups; approximately 15-25 entries per year per symbol, with Q02 as the cadence and economics judge."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
created: 2026-05-23
created_by: Research
last_updated: 2026-08-12
expected_pf: 1.2
expected_dd_pct: 18.0
risk_class: medium
ml_required: false
single_symbol_only: true
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [magic_schema, risk_mode_dual, one_position_per_magic_symbol, kill_switch_coverage]
g0_approval_reasoning: "R1 PASS via named authors and Wiley publication; R2 PASS via deterministic completed-bar OHLC rules and fixed exits; R3 PASS on registered DWX D1 FX symbols; R4 PASS with arithmetic-only rules and no ML, grid, martingale, or adaptive sizing. This repository copy schema-normalizes the existing approved farm artifact without changing its mechanics."
---

# Naked Forex Big Belt D1

## Hypothesis

A daily bar that gaps beyond the prior close, opens near one extreme, closes
near the opposite extreme, and forms at a recent price extreme represents an
exhausted opening impulse. A stop entry beyond the reversal bar seeks
confirmation that price continues away from the failed impulse. This is a
falsifiable FX adaptation of the book's Big Belt setup; no source performance
claim transfers to the Darwinex symbols.

## Source Boundary

The approved source is Alex Nekritin and Walter Peters, *Naked Forex* (Wiley,
2012), Chapter 9, "The Big Belt." The source supplies the daily gap-and-reversal
candle structure. The 20-bar extreme proxy, fixed entry offset, 100-pip stop
cap, ATR target, break-even rule, and `.DWX` symbol port are the approved QM
implementation contract and must be judged independently by the pipeline.

## Markets And Timeframe

- Symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, and
  `GBPJPY.DWX`.
- Signal and execution timeframe: D1.
- Signals use completed bars only and may create at most one pending or open
  position per registered magic/symbol.
- The setup is deliberately sparse; absence of enough Q02 trades is a valid
  strategy verdict and does not authorize threshold relaxation.

## Rules

### Bearish setup

On a newly completed D1 bar:

1. The bar opens above the preceding close.
2. Its open is in the top third of its range.
3. Its close is in the bottom third of its range.
4. Its high exceeds every high in the preceding 20 completed bars.
5. Place a sell stop 5 pips below the completed bar's low, expiring after one
   D1 bar.

### Bullish setup

Mirror the bearish rules: the completed bar opens below the preceding close,
opens in the bottom third, closes in the top third, and makes a fresh 20-bar
low. Place a buy stop 5 pips above its high, expiring after one D1 bar.

### Exit and management

- Initial stop: beyond the opposite Big Belt extreme by 5 pips, with the risk
  distance capped at 100 pips.
- Profit target: `2.5 * ATR(14, D1)` from entry.
- Move the stop to entry after a favorable `1.0 * ATR(14, D1)` move; the
  approved baseline adds no break-even buffer.
- Framework Friday close, news, kill-switch, and environment guards remain
  enabled.
- No scale-in, partial close, trailing stop, grid, martingale, or same-signal
  replacement after an entry is filled.

## Risk

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` in every canonical setfile.
- Each symbol uses its active deterministic magic slot: EURUSD 0, GBPUSD 1,
  USDJPY 2, AUDUSD 3, and GBPJPY 4.
- One position or pending order per magic/symbol.
- Stop-based sizing is bounded by the approved 100-pip cap and framework risk
  validation.
- This card authorizes research/backtest packaging only. It does not authorize
  a live setfile, T_Live, AutoTrading, deploy packaging, or portfolio admission.

## Parameters To Test

The Q02 baseline is fixed as follows. Any later sweep remains bounded to the
predeclared axes and cannot rescue a failed baseline.

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

## Framework Alignment

- `no_trade`: completed-D1-bar gate, supported symbol/timeframe, spread and
  framework controls, plus one-position/one-order enforcement.
- `trade_entry`: symmetric Big Belt detection and one-bar stop-order creation.
- `trade_management`: ATR break-even transition and pending-order expiry.
- `trade_close`: broker stop/target plus framework Friday-close and kill-switch
  paths.

## Non-Duplicate Boundary

The strategy is the Big Belt gap-reversal candle from the named source. It is
not a cointegration, carry, RSI, moving-average crossover, generic outside-bar,
or intraday session strategy. Removing the gap condition or substituting a
different candle family crosses the approved identity boundary.

## Kill Criteria

Retire the baseline if Q02 cannot produce the minimum required trade cadence,
if pending-order behavior is non-deterministic, if the fixed-risk contract
cannot be validated, or if the after-cost economics fail. Do not relax the gap
or recent-extreme requirements to manufacture trades.

## Pipeline History

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-05-23 | OWNER-approved source extraction | G0 | APPROVED |
| v1 | 2026-08-12 | repository schema normalization and five-symbol RISK_FIXED packaging | Q01 | PASS |
| v1 | 2026-08-12 | target-only staged enqueue for AUDUSD, EURUSD, and GBPJPY; GBPUSD and USDJPY retained in the deferred sidecar | Q02 | ENQUEUED |
