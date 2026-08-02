---
strategy_id: 6e967762-b26d-59a3-b076-35c17f2e7c36-TUE-OFF-20260731
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
ea_id: QM5_20188
slug: ff-rb-tue-off
type: strategy
variant_of: QM5_9936
created: 2026-07-31
created_by: OWNER+Codex
last_updated: 2026-07-31
source_citation: "Knodlz, Range Breakout System, ForexFactory, 2024, https://www.forexfactory.com/thread/1299658-range-breakout-system; Tuesday-off enhancement selected in docs/ops/evidence/2026-07-27_9936_drawdown_diagnosis.md."
target_symbols: [USDJPY.DWX, GBPUSD.DWX, NDX.DWX]
primary_target_symbols: [USDJPY.DWX]
period: H1
timeframes: [H1]
expected_trade_frequency: "Daily fixed-window range breakout excluding Tuesday entries; approximately 112 trades/year/symbol after the frozen weekday guard and existing filters."
expected_trades_per_year_per_symbol: 112
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
strategy_type_flags: [session-range-breakout, pending-stop-breakout, weekday-guard, intraday-flat, atr-range-filter]
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [variant-identity, no-lookahead-weekday, risk-mode, friday-close, news-blackout, oos-freeze]
g0_approval_reasoning: "OWNER 2026-07-31 best-EA mission; R1 inherits approved Knodlz lineage plus durable 1,252-trade diagnosis; R2 single frozen pre-entry weekday guard with unchanged mechanical parent; R3 registered USDJPY/GBPUSD/NDX DWX H1; R4 deterministic no ML/grid/martingale and frozen OOS."
expected_pf: 1.25
expected_dd_pct: 20.0
---

# QM5_20188 FF Range Breakout — Tuesday Off

## Hypothesis and source

This is one isolated enhancement of the approved `QM5_9936` ForexFactory
GMT+3 H1 range breakout. It retains the parent strategy's source mechanics and
changes only the entry calendar: it does not place new pending orders on
Tuesday in the strategy's GMT+3 clock.

The change was selected before this EA existed from the parent's 1,252 closed
Q08 trades. Tuesday was the only weekday with a negative aggregate result:
214 trades, -11.00R, mean -0.051R/trade, and a 55.6% loss rate. Monday,
Wednesday, Thursday, and Friday were positive. The durable diagnosis is
`docs/ops/evidence/2026-07-27_9936_drawdown_diagnosis.md`. This is a candidate
regime effect, not a performance claim; the frozen out-of-sample test below is
authoritative.

## Market, timeframe, and identity

- Primary target symbol: `USDJPY.DWX`, H1, magic slot 0.
- Cross-sectional falsification symbols: `GBPUSD.DWX` slot 1 and `NDX.DWX`
  slot 2, both H1, with the identical Tuesday rule and no symbol-specific
  weekday selection.
- EA identity: `QM5_20188`, slug `ff-rb-tue-off`.
- Intraday-flat: all positions close no later than 20:00 GMT+3.

## Entry rules

1. Convert broker time to UTC through the framework and then to fixed GMT+3.
2. If the GMT+3 weekday is Tuesday, mark the day consumed and place no orders.
3. Otherwise build the completed 01:00-06:00 GMT+3 H1 range.
4. At 06:00 GMT+3 place one buy stop at the range high and one sell stop at
   the range low, each with its initial stop on the opposite range boundary.
5. Skip the day if range height is below `0.4 * ATR(14,H1)` or above
   `2.5 * ATR(14,H1)`.
6. Delete both untriggered orders at 13:00 GMT+3 and cancel the opposite order
   after one side triggers.
7. Keep the parent's central high-impact news guard and one-position-per-magic
   contract.

Tuesday is determined from information available before entry. No future
close time, PnL, volatility label, or trade outcome is consulted.

## Exit and trade management rules

- No fixed take profit.
- Close at the earlier of 20:00 GMT+3, an opposite-range-side touch, or the
  broker stop.
- After at least +1R, trail to the prior two completed H1 lows for longs or
  highs for shorts exactly as in the parent.
- No scale-in, averaging, grid, martingale, partial close, or adaptive rule.

## Stop and risk

- Initial stop loss is the opposite boundary of the completed session range.
- A range above `2.5 * ATR(14,H1)` is rejected, preserving the parent's hard
  stop-distance cap.
- Backtest sizing is fixed: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No live setfile or deployment is authorized by this card.

## Frozen parameters

| parameter | value |
|---|---:|
| `strategy_range_start_hour_gmt3` | 1 |
| `strategy_range_end_hour_gmt3` | 6 |
| `strategy_order_cancel_hour_gmt3` | 13 |
| `strategy_session_close_hour_gmt3` | 20 |
| `strategy_atr_period` | 14 |
| `strategy_min_range_atr_mult` | 0.4 |
| `strategy_max_range_atr_mult` | 2.5 |
| `strategy_trail_trigger_r` | 1.0 |
| `strategy_range_scan_bars` | 36 |
| `strategy_skip_tuesday` | true |

No parameter sweep is authorized for the first comparison.

## Frozen validation protocol

- Selection window: 2017-01-01 through 2021-12-31. This window justified the
  Tuesday choice and may not be used for another parameter decision.
- Decision window: 2022-01-01 through 2025-12-31, untouched by implementation
  choices. T5 must run the parent and variant on identical data, costs, model,
  and setfile values except EA identity and `strategy_skip_tuesday`.
- Full-history window: 2017-01-01 through 2025-12-31 for pipeline continuity.
- The variant wins only if its decision-window FUND_SCORE is greater than the
  parent's, net profit remains positive, PF remains above 1.0, and the normal
  independent pipeline gates pass. Otherwise it is retired; no rescue filter
  or second weekday choice is allowed.
- GBPUSD and NDX are falsification checks. Their weekday is not re-selected;
  failure there is recorded rather than tuned away.

## Framework alignment

- no_trade: framework kill switch, news, Friday close, symbol/identity guards.
- trade_entry: parent range/order logic plus the pre-entry GMT+3 Tuesday guard.
- trade_management: unchanged parent +1R prior-two-H1-bar trail.
- trade_close: unchanged parent time, opposite-boundary, and broker-stop exits.

## Safety boundary

Authorization covers the separate card/ID/magic rows, one V5 EA build, strict
compile, non-live T5 comparison, and subsequent non-live gates if earned. It
does not modify `QM5_9936`, T_Live, AutoTrading, live setfiles, deploy manifests,
portfolio admission, or any gate threshold.
