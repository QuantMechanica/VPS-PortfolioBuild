---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026_S01
variant_id: VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026_S01
source_id: VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026
ea_id: QM5_41179
slug: xtixng-mcoxstuart-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41179_xtixng-mcoxstuart-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41179_xtixng_monthly_cox_stuart_paired_sign_reversion_g0.md
source_approval: decisions/2026-08-27_xtixng_monthly_cox_stuart_paired_sign_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; D. R. Cox; Alan Stuart; NIST"
strategy_mechanic: monthly-xtixng-fourteen-synchronized-completed-month-end-oil-minus-gas-log-ratio-cox-stuart-seven-lag-seven-paired-sign-five-of-seven-contrarian-equal-notional-basket
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, market-neutral-style, relative-value, structural-reversion, cox-stuart, paired-sign, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, oil_gas_relative_value]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41179_XTI_XNG_MCOXSTUART_RV_D1
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411790000
period: D1
expected_trade_frequency: "Approximately 5-8 completed XTI/XNG packages per full post-warm-up year."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: 14 synchronized endpoints; seven lag-seven pairs; strict 5-of-7 sign threshold; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, fourteen_consecutive_completed_months, synchronized_month_end_pairs, chronological_ratio_orientation, exact_seven_lag_seven_pairs, strict_no_tie_rule, five_of_seven_contrarian_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
---

# QM5_41179 XTI/XNG Fourteen-Month Cox-Stuart Paired-Sign Reversion

## Hypothesis

Crude oil and natural gas share substitution, production, drilling, finance,
and LNG channels, but gas retains regional storage, transport, weather, and
demand drivers. Rather than assume a fixed price ratio or fit a hedge
coefficient, compare seven disjoint older/newer synchronized month-end ratio
pairs. When at least five signs agree, fade that broad relative displacement.

The equal-target-notional opposite legs are intended to reduce common outright
energy direction and produce a stream different from the directional
XAU/SP500/NDX/XNG book. They do not prove neutrality or decorrelation. Q09
alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The durable approved source is
`strategy-seeds/sources/VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026/source.md`,
SHA-256 `A8D709E17729474ACF1FA220D0FA0C73FD8DC8F2A555C740DBEC8BFE8061BF38`,
committed as `184c3536b` before card extraction,
authorized by
`decisions/2026-08-27_xtixng_monthly_cox_stuart_paired_sign_reversion_source_approval.md`.
It binds complete government and peer-reviewed oil/gas reads, adverse evidence,
the named Cox-Stuart record, and the complete official NIST algorithm. The
exact 5-of-7 contrarian CFD basket is an untested QM hypothesis. No source
return, significance, cost, hedge ratio, neutrality, or correlation transfers.

## Non-Duplicate Decision

Canonical evidence
`artifacts/qm5_xtixng_mcoxstuart_rv_preallocation_dedup_20260827.json` is
`CLEAN` across 4,678 registry identities, 1,329 cards, and 45 Wiki nodes.
Functional review separates this from outright WTI Cox-Stuart (`QM5_41167`),
metal Cox-Stuart (`QM5_41168`), XTI/XNG Pettitt (`QM5_41175`), XTI/XNG
Mann-Whitney (`QM5_41178`), and the two-day long-only XNG oscillator
(`QM5_12567`). The exact discriminating vectors are locked in the source.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Companion/traded slot 1: `XNGUSD.DWX`, D1.
- Decision: first synchronized executable tick of each genuine new broker
  month, within 180 minutes of the raw host D1 bar open.
- Formation: fourteen immediately prior consecutive synchronized completed
  month ends; current month excluded.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Pre-result cadence: five to eight completed packages per full post-warm-up
  year; Q02 retires below five.

## Formula

For chronological synchronized month-end pairs `i=0..13`:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i])
d[i] = s[i+7] - s[i], i=0..6
require every d[i] finite and nonzero
positive = count(d[i] > 0)
negative = count(d[i] < 0)
require positive + negative = 7

SELL XTI / BUY XNG iff positive >= 5
BUY XTI / SELL XNG iff negative >= 5
FLAT otherwise
```

Each endpoint is used exactly once. A zero difference or 4/3 split consumes
the month flat. Magnitude and winning count beyond five do not change risk.

## Rules

- Exact D1 symbols, slots, magics, and fixed-risk inputs are load-bearing.
- Consume normalized broker `yyyymm` before every fallible entry gate.
- Select the latest exactly timestamp-matched close pair in each required
  month; reject gaps, duplicates, current-month points, bad chronology,
  nonpositive/nonfinite prices, or endpoint staleness above ten days.
- Use only pairs `(0,7)` through `(6,13)`. No tie deletion, dynamic threshold,
  alternate pairing, fitted center/scale, endpoint fallback, or magnitude
  weight is permitted.
- Five positive signs mean short ratio; five negative signs mean long ratio.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Process malformed-package repair and prior-month/stale exits before entry.
2. Require the exact EA contract, host/companion, D1, slots, and risk mode.
3. Require a genuine broker-month transition within the 180-minute window.
4. Persist `yyyymm` before history, signal, spread, quote, ATR, sizing, margin,
   or order checks. No reject, flat, partial, stop, failure, or restart retries.
5. Reject owned exposure or same-month entry deal history.
6. Reconstruct fourteen exact synchronized completed-month endpoints.
7. Compute seven fixed signs; any tie or 4/3 split is flat.
8. Require XTI/XNG spreads at or below 1,500/3,000 points, executable quotes,
   ATR(20,D1), valid volumes/stops, and at most 20% realized notional mismatch.
9. Split aggregate stop risk equally, size both legs to equal target absolute
   USD notional, and attach frozen `3.5*ATR(20,D1)` broker hard stops.
10. Submit XTI then XNG. Retain only one correctly directed, registered,
    stop-protected position per slot; otherwise flatten all owned legs.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first tick in a later broker month before renewal.
3. Close after forty elapsed calendar days as stale repair.
4. Flatten immediately if the package is orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or outside the
   20% notional mismatch limit.
5. No target, trail, break-even, partial close, intramonth flip, scale-in,
   Friday exit, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact execution contract or on malformed history,
  timestamp mismatch, invalid prices, pair ties, invalid counts, excessive
  spread, invalid quotes, ATR/volume/stop failure, or notional mismatch.
- Terminal-persistent month state plus deal history prevent restart retries.
- Runtime reads no external file, API, forecast, inventory, futures chain,
  volume, open interest, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- Maintain either zero owned exposure or one valid opposite-leg package.
- Run integrity repair before entry-only gates on every tick.
- Preserve hard stops; close the package before any monthly replacement.
- Restart recovery combines persistent month state, positions, and deal
  history; no restart creates a second attempt.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Aggregate fixed risk is split equally between both legs before sizing.
- Equal target absolute USD notionals; realized mismatch ceiling 20%.
- Each leg has a frozen `3.5*ATR(20,D1)` hard stop and no profit target.
- At most one two-leg package and one consumed attempt per broker month.
- Q02 retires on zero trades, fewer than five packages in any full post-warm-up
  year, nonpositive governed economics, or any mechanical defect.

## Parameters To Test

| Input | Baseline | Locked meaning |
|---|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 14 | completed synchronized month ends |
| `strategy_pair_lag` | 7 | fixed half-sample lag |
| `strategy_min_concordant` | 5 | strict directional sign threshold |
| `strategy_history_bars_d1` | 900 | bounded native history buffer |
| `strategy_entry_window_minutes` | 180 | new-month grace |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint staleness |
| `strategy_atr_period_d1` | 20 | completed-bar stop ATR |
| `strategy_atr_sl_mult` | 3.5 | hard-stop multiple |
| `strategy_notional_ratio` | 1.0 | equal target notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | final package tolerance |
| `strategy_max_hold_days` | 40 | stale repair |
| `strategy_xti_max_spread_points` | 1500 | host spread cap |
| `strategy_xng_max_spread_points` | 3000 | companion spread cap |
| `strategy_deviation_points` | 20 | order deviation |

Q02 baseline is fixed. These are not an optimization grid.

## Framework Alignment

| Card rule | V5 location |
|---|---|
| exact contract, month attempt, synchronized history, sign rule, sizing, atomic entry | `Strategy_EntrySignal` plus EA helpers |
| package integrity and stale repair | `Strategy_ManageOpenPosition` |
| later-month package exit | `Strategy_ExitSignal` plus paired close helper |
| kill/news/session defaults | V5 framework; both news axes and Friday close OFF |
| risk and magic resolution | V5 risk inputs and `QM_Magic` slots 0/1 |

## Out Of Scope And Safety Boundary

No manual backtest, live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deployment manifest, portfolio-gate mutation, portfolio admission,
correlation waiver, external runtime data, or tester control is authorized.
Q02 handoff does not claim profitability, certification, or decorrelation.

## Approval And Kill Criteria

G0 may approve only after the durable source decision, canonical clean dedup,
schema lint, exact deterministic identity allocation, and R1-R4 review. Q01
must produce current strict compile/build-check PASS before one paced logical-
basket Q02 enqueue. Any failure is terminal for this locked variant; no
post-result direction, threshold, sample, carrier, risk, or lifecycle rescue.


