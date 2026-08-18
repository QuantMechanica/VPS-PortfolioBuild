---
card_schema_version: 2
type: strategy
strategy_id: BIANCHI-MOMREV-2015_XTI_XNG_S04
variant_id: BIANCHI-MOMREV-2015_XTI_XNG_S04
source_id: BIANCHI-XTIXNG-REV18-2026
ea_id: QM5_41056
slug: energy-rev18
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41056_energy-rev18_card.md
execution_contract_status: APPROVED
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
g0_decision: decisions/2026-08-18_qm5_41056_energy_rev18_g0.md
source_approval: decisions/2026-08-18_xtixng_18m_reversal_source_approval.md
source_author: "Robert J. Bianchi; Michael E. Drew; John Hua Fan"
source_authors: "Robert J. Bianchi; Michael E. Drew; John Hua Fan"
source_citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015). Combining Momentum with Reversal in Commodity Futures. Journal of Banking & Finance 59, 423-444. DOI 10.1016/j.jbankfin.2015.07.006."
source_citations:
  - type: peer_reviewed_paper
    citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015). Combining Momentum with Reversal in Commodity Futures. Journal of Banking & Finance 59, 423-444."
    location: "Complete 59-page accepted manuscript; DOI https://doi.org/10.1016/j.jbankfin.2015.07.006; complete-read record strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md; bounded carrier packet strategy-seeds/sources/BIANCHI-XTIXNG-REV18-2026/source.md"
    quality_tier: A
    role: long_horizon_commodity_reversal_and_energy_constituent_lineage
strategy_mechanic: synchronized-energy-pure-18m-cross-sectional-reversal-monthly-basket
sources:
  - "[[sources/BIANCHI-XTIXNG-REV18-2026]]"
concepts:
  - "[[concepts/commodity-long-horizon-reversal]]"
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/monthly-basket-renewal]]"
indicators:
  - "[[indicators/completed-month-return-rank]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, cross-sectional-reversal, relative-value, symmetric-long-short, two-leg-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41056_ENERGY_REV18_D1
symbol: QM5_41056_ENERGY_REV18_D1
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410560000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 11-12 completed paired packages per full post-warm-up year when synchronized 18-month ranks are not tied; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_HISTORY_AND_BASKET_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify a pure completed-18-month XTI/XNG reversal basket outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy-session labels, strictly pre-decision synchronized endpoints, loser-long/winner-short direction, absence of the sibling 12-month state, atomic package lifecycle, durable monthly attempt, and fixed aggregate risk. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_energy_carrier, first_month_bar_clock, uniform_energy_label_normalization, synchronized_completed_month_endpoints, no_current_month_price, pure_18m_reversal, no_12m_state, inclusive_tie_band, basket_atomicity, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stops_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses a named-author peer-reviewed Journal of Banking & Finance paper with DOI, complete-read evidence, explicit WTI and natural-gas membership, and explicit disclosure that the pure two-energy carrier is a QM translation; R2 locks synchronized endpoints, 18-month horizon, reversal map, tie, attempt, aggregate risk, hard stops, compensation, and lifecycle; R3 uses registered native XTI/XNG D1 with energy-label and logical-basket risks explicit; R4 uses deterministic timestamps, completed prices, logarithms, comparisons, and execution arithmetic without trained logic, banned signal indicators, or an external feed; canonical dedup found no exact identity and manual family review separated the pure 18-month state from the 12/18 disagreement, momentum, short-spread, weekday, and standalone XNG systems."
---

# QM5_41056 XTI/XNG Pure 18-Month Cross-Sectional Reversal

## Hypothesis

Long-horizon relative commodity moves can overextend and reverse. On the first
tradable D1 bar of each broker month, buy the weaker of WTI crude oil and
natural gas over the prior eighteen completed months and short the stronger
energy leg, then hold the paired package until the next month boundary.

Opposite legs reduce one source of common energy direction, but the package is
not proven dollar-, beta-, volatility-, factor-, market-, or portfolio-neutral.
This is a falsifiable new energy carrier; Q02 must establish density and
economics, and Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The complete-read record is
`strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`; the approved bounded
carrier packet is
`strategy-seeds/sources/BIANCHI-XTIXNG-REV18-2026/source.md`, authorized in
`decisions/2026-08-18_xtixng_18m_reversal_source_approval.md` at commit
`72bf6148c`.

Bianchi, Drew, and Fan document long-horizon reversal of commodity momentum
profits and use an overlapping 18-month reversal rank in a broad double-sort
portfolio. WTI crude oil and natural gas are explicit constituents. The paper
does not test a pure two-energy rank, continuous CFDs, equal stop-risk legs,
QM hard stops, legging repair, or this portfolio. No source return,
significance, cost, density, drawdown, neutrality, or correlation result
transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,543 EA-registry rows and 625
root-card files and found no exact identity. Manual family review fixes the
load-bearing differences:

- `QM5_13120_energy-momrev` requires disagreement between a 12-month momentum
  rank and the 18-month reversal rank. This card never reads the 12-month
  state and trades every valid non-tied 18-month rank, including agreement
  months where the sibling is flat.
- `QM5_20202_xauxag-rev18` isolates the same source information object on the
  XAU/XAG metals carrier; this card uses XTI/XNG physical-energy and basis
  exposure.
- `QM5_12733_xti-xng-xmom` follows a shorter relative winner; this card fades
  the completed 18-month winner.
- `QM5_12840_xti-xng-rspread` fades a short-window standardized return spread;
  this card has no ratio, residual, mean, standard deviation, or thresholded
  spread level.
- Weekday, event, carry, same-calendar, inventory, and maximum-return energy
  cards use different state variables or clocks.
- `QM5_12567_cum-rsi2-commodity` is a standalone daily long-only XNG
  oscillator pullback.

Verdict:
`CLEAN_XTI_XNG_PURE_SYNCHRONIZED_18_MONTH_REVERSAL_MONTHLY_BASKET_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Logical basket: `QM5_41056_ENERGY_REV18_D1`.
- Host/slot 0: exact `XTIUSD.DWX`, D1, magic `410560000`.
- Companion/slot 1: exact `XNGUSD.DWX`, D1, magic `410560001`.
- Decision: first genuine host D1 bar after a broker-calendar month change.
- Session labels: accept native same-day labels or one uniform `+1` calendar-
  day energy offset; apply the same convention to both legs and all endpoints.
- Formation: synchronized completed month-end closes immediately before the
  decision-month boundary and exactly 18 completed months earlier.
- Endpoint freshness: each selected close must be positive, strictly before
  its boundary, and no more than ten calendar days earlier.
- Ordinary exit: first genuine host D1 bar in the next broker month.
- Expected cadence: approximately eleven to twelve packages/year after
  warm-up.

For each leg `i` at decision boundary `t`:

```text
r_i = ln(completed_close_i[t] / completed_close_i[t-18 months])

r_xti < r_xng - 1e-12 => BUY XTI, SELL XNG
r_xti > r_xng + 1e-12 => SELL XTI, BUY XNG
otherwise              => consume month flat
```

All signal endpoints precede the decision month. Current-month open, high,
low, close, volume, or tick price is forbidden from the signal. Signal
magnitude never changes size.

## Rules

These entry, exit, filter, management, and risk rules are the complete frozen
baseline. There is no parameter sweep or standalone-leg test.

## 4. Entry Rules

1. Evaluate only on a new host D1 bar while attached to exact `XTIUSD.DWX`,
   D1, EA ID 41056, slot 0, with registered XNG companion and locked framework
   inputs.
2. Process malformed, orphaned, and stale owned exposure before entry-only
   gates. Close a prior-month package before considering renewal.
3. Accept only native same-day D1 labels or one uniform `+1` calendar-day
   offset, require normalized current host date to match broker date, and use
   the same offset for both legs and every historical endpoint.
4. Evaluate only on the first genuine D1 bar of a new broker month. A mid-
   month first attachment consumes no historical opportunity and remains flat
   until the next genuine boundary.
5. Derive the attempt key from broker `yyyymm` and persist it before history,
   signal, news, spread, quote, ATR, sizing, or order gates. A restart,
   rejection, block, rollback, or hard stop cannot retry the month.
6. Select synchronized, strictly pre-boundary completed closes for XTI and XNG
   at the current decision boundary and the boundary exactly 18 completed
   months earlier. Require strict ordering, positive finite prices, and a
   maximum ten-calendar-day gap before each target boundary.
7. Compute the two log returns and apply the strict reversal rank. Buy the
   lower return and sell the higher return. The inclusive `1e-12` tie band
   consumes the month flat. Never compute or emulate a 12-month rank.
8. Require valid quotes, symbol metadata, volumes, registered magics, and
   genuinely positive spreads no greater than 1,500 XTI points and 3,000 XNG
   points. Modeled zero `.DWX` spread is valid.
9. Split one aggregate package `RISK_FIXED` budget equally by stop risk.
   Attach a frozen `3.5 * ATR(20,D1)` hard stop to each leg; no take-profit.
   Validate both requests before sending the first order.
10. Confirm the first order before submitting the second. On second-leg
    failure or invalid composition, immediately close all owned exposure and
    consume the month.

## 5. Exit Rules

1. Broker hard stops and the framework kill switch remain authoritative for
   both registered magics.
2. Any orphan, duplicate, same-direction, wrong-symbol, wrong-magic,
   missing-stop, invalid-volume, or otherwise malformed package closes all
   owned exposure immediately.
3. Close both legs on the first genuine host D1 bar in a later broker month,
   before considering renewal.
4. Close both legs after 35 elapsed calendar days as a survivor repair.
5. Framework Friday close is disabled for the monthly holding identity.
6. No target, intramonth signal reversal, trail, break-even move, partial
   close, discretionary exit, or intentional standalone leg is authorized.

## 6. Filters (No-Trade Module)

- Exact host/timeframe/slot, locked-input, uniform-label, new-month, attempt,
  synchronized-history, endpoint, logarithm, tie, spread, quote, ATR, volume,
  magic, and package gates all fail closed.
- Both news axes and legacy news mode are OFF for Q02. Lifecycle repair and
  exits are never delayed by entry-only gates.
- No 12-month state, futures chain, roll series, inventory, weather, volume,
  open interest, COT, carry, calendar file, API, CSV, optimizer artifact,
  trained output, ratio, residual, or manual signal is read at runtime.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Exactly two opposite legs, one per registered magic, form a healthy package.
- Position/deal history plus a persisted terminal marker enforce one consumed
  attempt per broker month across restarts.
- Manage both magics on every host tick, including kill-switch response,
  malformed/orphan repair, later-month close, and stale close.
- Freeze original hard stops; never widen, trail, or remove them.
- Do not retry, scale in, pyramid, grid, martingale, partially close, place
  pending orders, or retain one leg deliberately.

## Risk

- Backtest only: one logical package setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Each leg receives half the package risk through its own completed-bar
  `ATR(20,D1) * 3.5` frozen hard stop.
- No target and no signal-magnitude sizing.
- Equal stop-risk halves do not establish dollar, beta, volatility, factor,
  market, or portfolio neutrality.
- Major risks are two-name concentration, persistent relative energy trends,
  CFD/futures basis and financing, energy-session labels, gaps, legging,
  volume rounding, and source decay.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_reversal_months` | 18 | completed-month reversal horizon |
| `strategy_history_bars` | 520 | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | endpoint freshness cap |
| `strategy_signal_epsilon` | 1e-12 | inclusive return-rank tie band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | stale package repair |
| `strategy_xti_max_spread_pts` | 1500 | XTI entry cost guard |
| `strategy_xng_max_spread_pts` | 3000 | XNG entry cost guard |
| `strategy_deviation_points` | 20 | paired market-order deviation |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No horizon, endpoint, direction, carrier, tie, stop, hold, or filter sweep is
authorized.

## Data Requirements

- Registered native `XTIUSD.DWX` and `XNGUSD.DWX` D1 OHLC/timestamps.
- Broker time, current quotes, symbol contract properties, positions, deal
  history, and terminal global variables.
- No continuous-futures file, roll map, futures curve, inventory, weather,
  volume, open interest, COT, event calendar, API, CSV, optimizer artifact,
  trained output, or manual signal input.

## Source-Defined Rules

The source supports a long-horizon commodity-reversal lineage, an overlapping
18-month reversal information object, and WTI/natural gas as constituents of
its broad universe. It does not define this pure two-name energy carrier,
fixed-risk sizing, stops, CFD implementation, or execution lifecycle.

## QM Interpretations

QM fixes the pure two-energy carrier, uniform session-label convention,
synchronized month-end endpoints, inclusive epsilon, loser-long/winner-short
map, durable attempt, aggregate fixed risk, equal stop-risk halves, ATR stops,
spread caps, compensation, monthly renewal, and stale repair. These are pre-
result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, registered magic resolver,
fixed-risk mode, position/deal state, and close helpers remain authoritative.
Both news axes and framework Friday close are OFF. This non-live card creates
no live mapping, deployment manifest, portfolio-gate mutation, or promotion
entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stops remain authoritative.
2. Malformed, duplicate, same-direction, or orphan exposure is flattened.
3. The first observed host D1 boundary in a later broker month closes both
   legs before renewal.
4. The 35-day close repairs only a survivor.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and terminal-global attempt
state. It has no external feed, fitted artifact, trained output, optimizer
artifact, or manual signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed packages
per full post-warm-up year, nonpositive governed economics, wrong or stale
endpoints, current-month leakage, inconsistent session labels, a hidden
12-month or spread-level gate, wrong reversal direction, duplicate attempt,
standalone/orphan persistence, nondeterminism, invalid risk mode, or unusable
synchronized history. Any change to carrier, horizon, endpoint, direction,
tie, risk split, stop, or hold creates a new identity. Q09 alone may establish
realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, boundary, attempt, synchronized endpoints, rank, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed/orphan, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| monthly renewal and survivor repair | Trade Close | strategy lifecycle helper; Friday close disabled |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed packages per full post-
warm-up year; zero trades; nonpositive governed economics; wrong or stale
month endpoints; current-month leakage; inconsistent label normalization;
wrong rank or direction; hidden 12-month state; retry; one-leg persistence;
missing stop; wrong monthly lifecycle; nondeterminism; or registry/risk
mismatch.

No weak result may be rescued by changing horizon, direction, carrier, tie,
adding momentum, z-score, ratio, weekday, event, seasonality, inventory,
carry, volume, volatility, or price-action filters, or extending the hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label conventions select only a genuine normalized
   month boundary, apply identically to both legs, and choose synchronized
   completed endpoints strictly before the decision month;
2. the exact 18-month log returns, inclusive tie band, and loser-long/winner-
   short directions are correct, with no 12-month state or current-month
   OHLC/volume/tick input;
3. persisted `yyyymm` attempts prevent same-month retry after every downstream
   failure and restart;
4. aggregate fixed-risk sizing splits valid completed-bar ATR stop risk
   equally and validates both requests before entry;
5. second-leg failure compensation, malformed/orphan repair, next-month close,
   stale guard, and disabled Friday close remain reachable; and
6. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial pure 18-month XTI/XNG reversal card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-18 | APPROVED | `decisions/2026-08-18_qm5_41056_energy_rev18_g0.md` |
| Q01 Build Validation | - | PENDING | `framework/EAs/QM5_41056_energy-rev18/` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | logical basket only |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one logical D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
the tester and CPU ceilings. It does not authorize a manual backtest, tester
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation or neutrality claim, or correlation waiver.
