---
card_schema_version: 2
ea_id: QM5_20194
slug: xauxag-momrev
type: strategy
strategy_id: BIANCHI-MOMREV-2015_XAU_XAG_S02
variant_id: BIANCHI-MOMREV-2015_XAU_XAG_S02
source_id: BIANCHI-MOMREV-2015
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20194_xauxag-momrev_card.md
execution_contract_status: DRAFT
created: 2026-08-01
created_by: Research+Development
last_updated: 2026-08-01
source_authors: "Robert J. Bianchi; Michael E. Drew; John Hua Fan"
strategy_mechanic: monthly-synchronized-xau-xag-12m-momentum-18m-reversal-disagreement-two-leg-basket
source_citation: "Bianchi, Drew, and Fan (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444."
source_citations:
  - type: peer_reviewed_paper
    citation: "Bianchi, R. J., Drew, M. E., and Fan, J. H. (2015). Combining Momentum with Reversal in Commodity Futures. Journal of Banking & Finance 59, 423-444."
    location: "Sections 3.2 and 4.2-4.7; Tables 4-6 and 10-11; DOI https://doi.org/10.1016/j.jbankfin.2015.07.006; completely reviewed accepted-manuscript packet strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md"
    quality_tier: A
    role: primary
sources:
  - "[[sources/BIANCHI-MOMREV-2015]]"
concepts:
  - "[[concepts/commodity-momentum-reversal]]"
  - "[[concepts/precious-metal-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, cross-sectional-rank, momentum, reversal, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20194_XAU_XAG_MOMREV_D1
symbol: QM5_20194_XAU_XAG_MOMREV_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-9 eligible two-leg packages/year after the 18-month warm-up; Q02 retires below five completed packages/year."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: b8ce6d6b-6b21-43ca-95f3-9f6baa46ed7e
review_focus: "Falsify a relative XAU/XAG 12-month momentum / 18-month reversal-disagreement package whose return driver differs from directional XAU and the existing ratio, convergence, calendar, IVol, and pure-momentum baskets; neutrality and book decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, friday_close_exception, magic_schema, cfd_futures_basis, narrow_cross_section, portfolio_correlation]
g0_approval_reasoning: "OWNER authorization decisions/2026-08-01_qm5_20194_xauxag_momrev_g0.md: R1 peer-reviewed JBF source with a completely reviewed institutional manuscript packet and explicit gold/silver source membership; R2 locked synchronized overlapping 12/18-month opposite-rank gate, monthly lifecycle, aggregate risk, hard stops, and restart-safe attempt; R3 registered XAU/XAG D1 routes; R4 deterministic native arithmetic only. Exact dedup clean; expected energy-momrev source-method fuzzy sibling manually resolved as a different two-metal carrier, and all closer XAU/XAG mechanics use different states."
---

# QM5_20194 XAU/XAG Momentum-Reversal Double Sort

## Hypothesis

Commodity shocks can diffuse at medium horizons while longer-horizon moves
partly reverse. The source combines those states cross-sectionally: buy a
12-month winner only when it is also an 18-month loser, and short the
12-month loser only when it is the 18-month winner. This card translates that
fixed disagreement rule to gold and silver.

The simultaneous opposite legs seek to suppress their common precious-metal
and USD direction while retaining relative momentum/reversal interaction.
That construction is market-neutral in order direction only. It does not
prove dollar, beta, volatility, factor, or portfolio neutrality; Q02 and the
unchanged downstream gates must establish density, economics, execution, and
realized book correlation.

## Source Traceability

The governed packet
`strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md` records a complete
review of Bianchi, Drew, and Fan (2015), *Journal of Banking & Finance* 59.
The paper uses 27 S&P GSCI commodity futures and an independent 26-contract
Dow Jones-UBS universe, including gold and silver. Its preferred construction
first ranks overlapping 12-month returns, then identifies long-horizon
reversal with overlapping 18-month returns, and holds for one month.

The paper trades broad extreme portfolios. It does not test a two-name
XAU/XAG CFD basket, equal stop-risk legs, Darwinex month boundaries, hard
stops, costs, or the QM portfolio. No source profit factor, return, drawdown,
trade count, hedge ratio, or correlation statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation check found no exact slug or strategy-ID
duplicate. Its only fuzzy match was the expected source-method sibling
`QM5_13120_energy-momrev`, which trades XTI/XNG. Manual semantic review
resolves the registered XAU/XAG neighbors:

- `QM5_20050_xauxag-xmom12`, `QM5_20057_xauxag-xmom1`, and
  `QM5_20184_xauxag-xmom3` always rank one formation horizon; this card trades
  only when locked 12- and 18-month ranks conflict.
- `QM5_20157_xau-xag-ratio` and `QM5_12862_xauxag-rspread` fade standardized
  ratio/return-spread displacement rather than a cross-horizon rank conflict.
- `QM5_20161_xauxag-ols-rv` and `QM5_13205_xau-xag-qc` trade rolling residual
  or conditional-quantile disequilibrium.
- `QM5_20186_xauxag-samecal` and `QM5_20189_xauxag-calmom1` use recurring
  calendar states.
- `QM5_20192_xauxag-ivol` ranks factor-residual volatility and has no return
  disagreement gate.

The exact two-metal carrier, overlapping 12/18-month ranks, strict
disagreement gate, and monthly hold are jointly load-bearing. Substituting
XTI/XNG recreates the source-method sibling; removing either horizon recreates
a pure-momentum family.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20194_XAU_XAG_MOMREV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `201940000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `201940001`.
- Decision: first tradable XAU D1 bar after a genuine broker-month change.
- Formation: synchronized completed month-end closes at now, 12 months back,
  and 18 months back for both legs.
- Hold: next broker-month boundary, with a 35-calendar-day stale guard.
- Expected cadence: approximately 5-9 completed packages/year; retire below
  five/year after warm-up.

## Rules

The following formula, entry, exit, filters, and management rules are the
complete authorized baseline. Anything not stated is outside this card.

### Formula

At month transition `t`, let `C_i(t)` be the last positive completed D1 close
strictly before that broker-month boundary for leg `i`:

```text
mom_i = ln(C_i(t) / C_i(t-12 months))
rev_i = ln(C_i(t) / C_i(t-18 months))
```

- `mom_XAU > mom_XAG` and `rev_XAU < rev_XAG`: BUY XAU, SELL XAG.
- `mom_XAU < mom_XAG` and `rev_XAU > rev_XAG`: SELL XAU, BUY XAG.
- Same rank, a tie within `1e-12`, stale/nonordered endpoints, timestamp
  mismatch, nonpositive close, or invalid arithmetic: remain flat for the
  consumed month.

There is no ratio, z-score, regression, oscillator, moving average, breakout,
carry proxy, external series, trained output, or PnL-adaptive rule.

## 4. Entry Rules

1. Require exact EA ID `20194`, XAU D1 host, magic slot 0, and every baseline
   input locked to the declared value.
2. Evaluate only after a genuine broker-month transition.
3. Persist and consume the current broker month before history, signal,
   spread, quote, stop, news, or order gates. A flat, blocked, rejected,
   stopped, or partially opened decision cannot retry after restart.
4. Reconstruct synchronized completed month-end endpoints for both legs at
   the current, 12-month, and 18-month boundaries. Require each endpoint to
   precede its boundary by no more than ten calendar days and require matching
   boundary keys across legs.
5. Compute the four log returns and require strict rank disagreement at the
   two horizons beyond the fixed `1e-12` tie tolerance.
6. Buy the 12-month winner / 18-month loser and sell the opposite metal.
7. Require no owned leg, acceptable spreads, valid executable quotes,
   completed ATR(20), registered magics, and valid symbol/volume metadata.
8. Split one package `RISK_FIXED` budget equally between two independently
   ATR-normalized legs. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each;
   there is no take-profit.
9. Open XAU then XAG. Keep the package only if exactly one correctly directed
   position exists in each registered slot. If either order or final package
   validation fails, flatten every owned leg immediately.

## 5. Exit Rules

1. On the first tradable D1 bar of the next broker month, close both legs
   before considering a replacement package.
2. Close both legs after 35 elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No take-profit, trailing, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or when the 12/18 horizons are
  not exact.
- Require synchronized, ordered, fresh completed month endpoints on both
  legs; no current open D1 bar may enter the signal.
- Require nonnegative current spreads no greater than 1,500 points for XAU
  and 3,000 points for XAG.
- Require valid ATR, quotes, volume steps, contract metadata, registered
  magics, attempt state, and package state.
- Q02 freezes both news axes and legacy news mode OFF. No external calendar,
  file, futures chain, inventory, volume, open interest, or API is read.

## 7. Trade Management Rules

- The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
  slot 1. One shared fixed budget is split equally across the legs.
- Package composition and hard stops are checked every tick; invalid or
  partial state is flattened.
- Close-before-renew runs at every month boundary. A consumed month cannot
  retry after a stop or repair.
- Restart recovery combines a terminal-persistent month marker with position
  and deal history; future-dated tester state is cleared during initialization.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_momentum_months` | 12 | [12] | source first-sort horizon |
| `strategy_reversal_months` | 18 | [18] | source second-sort horizon |
| `strategy_history_bars` | 520 | [520] | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | [10] | completed boundary freshness |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread cap |
| `strategy_deviation_points` | 20 | [20] | order deviation |

There is no baseline sweep. The source horizons, overlapping formation,
strict disagreement gate, carrier pair, and holding clock are locked before
Q02.

## Risk And Test Contract

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both legs share that single budget equally after
independent ATR normalization. Q02 evaluates the logical basket, never two
standalone symbol results.

Retire on fewer than five completed packages/year, zero trades, nonpositive
governed economics, nondeterminism, endpoint mismatch, repeated monthly
attempts, orphan persistence, aggregate-risk breach, wrong magic/direction,
or later correlation rejection. Financing, legging, lot granularity, CFD
basis, common precious-metal/US-dollar exposure, industrial silver beta,
gaps, narrow breadth, and disagreement sparsity are binding risks.

## Strategy Allowability Check

- [x] R1: peer-reviewed *Journal of Banking & Finance* source with DOI and a
  completely reviewed institutional accepted-manuscript packet; gold and
  silver are explicit source-universe contracts.
- [x] R2: fixed synchronized overlapping 12/18-month ranks, direction, shared
  risk, stops, attempt state, monthly exit, and atomic repair.
- [x] R3: registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes with established
  logical-basket tester support.
- [x] R4: deterministic native price/calendar arithmetic only; no banned
  indicator, ML, external runtime feed, grid, martingale, or pyramiding.
- [x] Dedup: no exact match; the XTI/XNG source-method sibling and all closer
  XAU/XAG systems are manually separated by carrier and state variable.

## Framework Alignment

- No-trade: exact host/timeframe/slot, locked horizons, endpoint
  synchronization, spread, symbol, magic, package, and attempt guards.
- Trade entry: monthly 12/18 rank disagreement, opposite two-leg orders,
  shared fixed-risk sizing, hard stops, and atomic repair.
- Trade management: package validation, next-month close, stale close, and
  orphan cleanup.
- Trade close: framework close helper plus broker hard stops and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, one logical basket manifest, and one paced Q02
enqueue. It does not authorize a live setfile, AutoTrading, `T_Live`, a deploy
or T_Live manifest, portfolio admission, a portfolio-gate change, portfolio
KPIs, a correlation waiver, or a manual tester launch.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-01 | initial XAU/XAG 12/18 momentum-reversal carrier | G0 | APPROVED |
| v1-build | 2026-08-01 | registry-clean implementation and strict compile | Q01 | PASS |
| v1-q02 | 2026-08-01 | logical basket handed to the paced fleet | Q02 | ENQUEUED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-01 | APPROVED | OWNER decision, governed source packet, and this card |
| Q01 Build Validation | 2026-08-01 | PASS: 0 errors, 0 warnings, all static checks PASS | `D:/QM/reports/compile/20260801_102443/summary.csv`; `D:/QM/reports/framework/21/build_check_20260801_102502.json` |
| Q02 Baseline Screening | 2026-08-01 | ENQUEUED; no result claimed | work item `b8ce6d6b-6b21-43ca-95f3-9f6baa46ed7e`, pending/attempt 0/unclaimed at confirmation |
