---
strategy_id: BIANCHI-MOMREV-2015_XAU_XAG_S03
source_id: BIANCHI-MOMREV-2015
ea_id: QM5_20202
slug: xauxag-rev18
type: strategy
status: APPROVED
g0_status: APPROVED
created: 2026-08-02
created_by: Research+Development
last_updated: 2026-08-02
execution_contract_ref: strategy-seeds/cards/approved/QM5_20202_xauxag-rev18_card.md
strategy_mechanic: monthly-synchronized-xau-xag-18m-cross-sectional-reversal-two-leg-basket
source_citation: "Bianchi, Drew, and Fan (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444, DOI 10.1016/j.jbankfin.2015.07.006."
source_citations:
  - type: peer_reviewed_paper
    citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015). Combining Momentum with Reversal in Commodity Futures. Journal of Banking & Finance 59, 423-444."
    location: "Complete 59-page accepted manuscript; methodology, post-formation reversal analysis, tables, robustness, appendix, and conclusion; DOI https://doi.org/10.1016/j.jbankfin.2015.07.006; governed packet strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md"
    quality_tier: A
    role: primary
sources:
  - "[[sources/BIANCHI-MOMREV-2015]]"
concepts:
  - "[[concepts/commodity-long-horizon-reversal]]"
  - "[[concepts/precious-metals-relative-value]]"
indicators:
  - "[[indicators/completed-month-return-rank]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, cross-sectional-reversal, relative-value, symmetric-long-short, two-leg-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
period: D1
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20202_XAU_XAG_REV18_D1
expected_trade_frequency: "One paired package per broker month after the 18-month warm-up when the synchronized ranks are not tied; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify a narrow XAU/XAG 18-month cross-sectional reversal carrier whose state differs from directional XAU, short-window ratio/OLS convergence, pure momentum, and the 12/18 disagreement basket; no neutrality or book-correlation claim is imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, relative_value_neutrality, low_frequency, risk_mode_dual, restart_attempt_state, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "OWNER authorization decisions/2026-08-02_qm5_20202_xauxag_rev18_g0.md: R1 PASS peer-reviewed JBF source with a completely reviewed institutional manuscript and explicit gold/silver membership; R2 PASS locked synchronized 18-completed-month reversal rank, monthly lifecycle, aggregate fixed risk, hard stops, and restart-safe attempt; R3 PASS registered XAU/XAG D1 routes; R4 PASS deterministic native arithmetic only. Exact dedup clean; fuzzy siblings manually resolved by horizon and state."
---

# QM5_20202 XAU/XAG 18-Month Cross-Sectional Reversal

## Hypothesis

Commodity momentum can overextend and reverse over long horizons. At each
broker-month boundary, buy the weaker of gold and silver over the prior
eighteen completed months and short the stronger metal, then hold the paired
package for one month. Opposite legs reduce common precious-metal direction,
but dollar, beta, factor, market, and portfolio neutrality are not assumed.

This is a falsifiable narrow-carrier hypothesis. Q02 must establish trade
density and economics; unchanged downstream gates alone may measure realized
correlation and decide portfolio eligibility.

## Source Traceability And Claim Boundary

The governed packet `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`
records a complete review of Bianchi, Drew, and Fan (2015). The paper ranks a
broad commodity-futures cross-section and documents reversal of momentum
profits from 12 to 30 months after formation; its preferred double sort uses
an overlapping 18-month reversal rank. Gold and silver are explicit source
constituents.

S03 isolates the 18-month reversal information object on two Darwinex CFDs.
The paper does not test a two-name rank, CFD prices, equal stop-risk legs, QM
hard stops, legging controls, or this portfolio. No source return, alpha,
Sharpe ratio, drawdown, correlation, or transaction-cost result is imported.

## Non-Duplicate Decision

`research_dedup_check.py` returned no exact slug or strategy-ID duplicate and
three fuzzy matches requiring manual review:

- `QM5_20157_xau-xag-ratio` uses a 60-D1 standardized log-price ratio with
  threshold entry and mean exit; S03 ranks completed 18-month returns monthly.
- `QM5_20161_xauxag-ols-rv` uses a rolling 120-D1 OLS residual and adaptive
  hedge coefficient; S03 has no regression or z-score.
- `QM5_20194_xauxag-momrev` opens only when 12- and 18-month ranks disagree.
  S03 never reads a 12-month rank and trades every non-tied 18-month state,
  including the rank-agreement months where S02 is flat.
- XAU/XAG 1-, 3-, and 12-month cross-sectional-momentum baskets buy the recent
  winner; S03 fades the long-horizon winner.

The 18-month rank, reversal direction, monthly clock, exact carrier, and
paired lifecycle are jointly load-bearing. Changing any creates a new card.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20202_XAU_XAG_REV18_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1.
- Companion/slot 1: `XAGUSD.DWX`, D1.
- Decision: first genuine host D1 bar after a broker-calendar month change.
- Formation: synchronized completed month-end closes at the decision boundary
  and exactly 18 months earlier, with at most a ten-calendar-day endpoint gap.
- Expected cadence: approximately twelve paired packages/year after warm-up.
- Runtime: native MT5 D1 prices, ATR, spread, symbol metadata, broker calendar,
  positions, deals, and framework state only.

## Formula

For each leg `i` at month boundary `t`:

```text
rev18_i = ln(completed_close_i[t] / completed_close_i[t-18 months])
```

- `rev18_XAU < rev18_XAG`: BUY XAU and SELL XAG.
- `rev18_XAU > rev18_XAG`: SELL XAU and BUY XAG.
- Absolute difference at or below `1e-10`, invalid endpoints, or stale
  synchronization: remain flat and consume the month.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
frozen baseline. There is no parameter sweep or standalone-leg test.

## 4. Entry Rules

1. Require the exact XAU D1 host, slot 0, registered XAG companion, and locked
   strategy/framework inputs.
2. Evaluate only on the first genuine D1 bar of a new broker month, after
   lifecycle exits have run.
3. Persist the monthly attempt before history, signal, news, spread, sizing,
   or order gates. A restart, rejection, block, rollback, or stop cannot retry.
4. Require synchronized valid positive closes at the completed current and
   18-month boundaries for both legs. An endpoint more than ten days before
   its target boundary fails closed.
5. Compute both log returns and the strict reversal rank. Ties remain flat.
6. Buy the 18-month loser and sell the winner.
7. Require valid quotes, ATR, symbol metadata, volumes, magics, and spreads no
   greater than 1,500 XAU points and 3,000 XAG points.
8. Split one package `RISK_FIXED` budget equally by stop risk. Attach one
   frozen `3.5 * ATR(20,D1)` hard stop to each leg; no take-profit.
9. Confirm the first order before submitting the second. On second-leg
   failure, immediately close the first and consume the month.

## 5. Exit Rules

1. Broker hard stop on either leg remains authoritative.
2. Any orphan, duplicate, same-direction, foreign-magic, or otherwise
   malformed package closes all owned exposure immediately.
3. Close both legs on the first genuine D1 bar of the next broker month before
   considering renewal.
4. Close both legs after 35 elapsed calendar days as a stale guard.
5. Framework kill-switch close remains authoritative for both magics.
6. No target, signal-reversal exit inside the month, trail, break-even move,
   partial close, discretionary exit, or weekend flatten is authorized.

## 6. Filters (No-Trade Module)

- Fail closed on wrong host/timeframe/slot, unlocked inputs, missing or stale
  synchronized history, non-positive prices, invalid logarithm, invalid ATR,
  quote/volume/magic failure, excessive spread, existing package, or consumed
  monthly attempt.
- Both news axes and legacy news mode are OFF for Q02. Lifecycle exits are
  never delayed by entry-only gates.
- Friday close is OFF because the source holding interval is one month.
- No futures chain, swap/carry series, inventory, calendar file, API,
  discretionary input, or trained output is read at runtime.

## 7. Trade Management Rules

- Exactly two opposite legs, one per registered magic, form a healthy package.
- Position/deal history plus a persisted terminal marker enforce one consumed
  attempt per broker month across restarts.
- Manage both magics on every host tick, including foreign-leg kill-switch,
  orphan repair, month exit, and stale exit.
- No independent leg, pending-order lifecycle, retry, scale-in, pyramid,
  partial close, grid, martingale, adaptive fit, or external runtime signal.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_reversal_months` | 18 | [18] | source reversal horizon |
| `strategy_history_bars` | 520 | [520] | bounded D1 retrieval buffer |
| `strategy_max_boundary_gap_days` | 10 | [10] | endpoint freshness cap |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard stop |
| `strategy_max_hold_days` | 35 | [35] | stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread cap |
| `strategy_deviation_points` | 20 | [20] | paired-order deviation |

## Author Claims

The paper supports a long-horizon commodity reversal lineage and an 18-month
reversal rank inside a broad double sort. It does not claim that this two-CFD
pure-reversal carrier is profitable or neutral.

## Risk

Q02 uses one logical package setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Equal stop-risk halves do not
create dollar, beta, volatility, factor, or market neutrality. Major risks are
two-name concentration, persistent relative trends, metal co-movement, CFD
basis and financing, gaps, legging, volume rounding, and source decay.

## Kill Criteria

Retire below five completed packages/year or on nonpositive Q02 economics.
Fail on a wrong direction/horizon, stale endpoint admission, duplicate monthly
entry, standalone/orphan leg, unclosed malformed package, nondeterminism,
risk-mode mismatch, or any governed PF/DD breach. Do not rescue a failure by
changing the horizon, adding a z-score or momentum confirmation, introducing
a threshold, retuning stops, or testing either leg alone.

## Strategy Allowability Check

- [x] R1: peer-reviewed primary paper, DOI, institutional manuscript, and
  complete durable review with explicit gold/silver source membership.
- [x] R2: fixed synchronized 18-month rank, reversal direction, monthly
  attempt/lifecycle, paired fixed risk, hard stops, and atomic repair.
- [x] R3: registered native XAUUSD.DWX and XAGUSD.DWX D1 routes.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic only; no
  prohibited model, external runtime feed, grid, martingale, or pyramiding.
- [x] Expected package cadence exceeds the five-per-year Q02 floor.
- [x] Exact dedup clean; fuzzy source/carrier siblings manually resolved.

## Framework Alignment

- no_trade: exact host/timeframe/slot, locked-input, synchronized-history,
  endpoint, spread, ATR, volume, magic, package, and attempt guards.
- trade_entry: completed 18-month rank, reversed winner/loser directions,
  equal stop-risk sizing, paired orders, hard stops, and rollback.
- trade_management: every-tick package integrity, foreign-magic ownership,
  next-month close, stale close, and restart-safe state.
- trade_close: framework close helper for both legs plus broker hard stops.

## Safety Boundary

No live/demo/shadow setfile, AutoTrading action, `T_Live` mutation, deploy or
T_Live manifest, portfolio admission, portfolio-gate edit, KPI claim,
correlation waiver, or certification is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-02 | initial source-backed XAU/XAG 18-month reversal card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-02 | APPROVED; R1-R4 PASS | `decisions/2026-08-02_qm5_20202_xauxag_rev18_g0.md` |
| Q01 Build Validation | - | PENDING | `framework/EAs/QM5_20202_xauxag-rev18/` |
| Q02 Baseline Screening | - | NOT_QUEUED | logical basket only |
