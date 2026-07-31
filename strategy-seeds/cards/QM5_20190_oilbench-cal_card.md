---
card_schema_version: 2
ea_id: QM5_20190
slug: oilbench-cal
type: strategy
strategy_id: KELOHARJU-GK-OILBENCH-CAL-2026_S01
variant_id: KELOHARJU-GK-OILBENCH-CAL-2026_S01
source_id: KELOHARJU-GK-OILBENCH-CAL-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20190_oilbench-cal_card.md
execution_contract_status: DRAFT
created: 2026-08-01
created_by: Research+Development
last_updated: 2026-08-01
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Anna Gorska; Monika Krawiec"
strategy_mechanic: monthly-synchronized-wti-brent-same-calendar-historical-relative-return-rank-two-leg-basket
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Journal of Finance 71(4), 1557-1590; Gorska and Krawiec (2015), Problems of World Agriculture 15(4), 62-70."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction in the complete 57-page NBER version; DOI https://doi.org/10.1111/jofi.12398; governed packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: primary_method
  - type: peer_reviewed_paper
    citation: "Gorska, A., and Krawiec, M. (2015). Calendar Effects in the Market of Crude Oil. Problems of World Agriculture 15(4), 62-70."
    location: "WTI and Brent calendar study; DOI https://doi.org/10.22630/PRS.2015.15.4.54; governed packet strategy-seeds/sources/GORSKA-KRAWIEC-WTI-CAL-2015/source.md"
    quality_tier: B
    role: target_market_evidence
  - type: exchange_and_agency_reference
    citation: "CME Group WTI-Brent Financial Futures; ICE Brent/WTI Futures Spread; U.S. EIA Brent-WTI spread analysis."
    location: "Governed packet strategy-seeds/sources/CME-WTI-BRENT-SPREAD-2026/source.md"
    quality_tier: A
    role: spread_structure
sources:
  - "[[sources/KELOHARJU-GK-OILBENCH-CAL-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/crude-benchmark-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: false
logical_symbol: QM5_20190_WTI_BRENT_CAL_D1
symbol: QM5_20190_WTI_BRENT_CAL_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One two-leg package per broker month after at least five synchronized same-calendar observations; approximately 12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: FAIL
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: INFRA_FAIL
q02_work_item_id: ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c
q02_observed_verdict: ZERO_TRADES
q02_recovery_classification: SETUP_DATA_MISSING
q02_recovery_evidence: docs/ops/evidence/2026-08-01_qm5_20190_zero_trades_setup_investigation.md
post_q02_blocker: "XBRUSD.DWX is absent from the DXZ symbol matrix, history-range registry, and tester symbol universe; no same-lineage rerun is valid until an OWNER-authorized tradable Brent route, history, and cost contract exist."
review_focus: "Falsify a recurring WTI-versus-Brent calendar-risk-premium spread that adds regional crude-benchmark exposure rather than another index, metal, or XNG directional carrier; profitability, neutrality, and decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, regional_basis_break, narrow_cross_section, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission 2026-08-01: R1 peer-reviewed same-calendar method plus target-market and exchange/agency spread evidence; R2 locked synchronized calendar estimator, relative rank, shared risk, stops, attempt state, monthly exit, and repair; R3 was initially inferred from local XTI/XBR builds but Q02 subsequently invalidated the XBR route and blocks further testing; R4 native deterministic arithmetic only. Deterministic dedup CLEAN and nearest WTI/Brent systems manually distinct."
---

# QM5_20190 WTI/Brent Same-Calendar Relative Seasonality

## Hypothesis

Recurring refinery demand, transport constraints, regional inventories,
hedging, and benchmark-specific capital flows can make WTI-versus-Brent
relative returns differ by calendar month. On each new month, the strategy
estimates that relative calendar state from synchronized observations in the
same month of prior years, buys the historically stronger crude benchmark,
and shorts the weaker benchmark.

The opposite legs aim to reduce common outright-oil and USD direction while
retaining regional benchmark seasonality. That construction is
market-neutral in direction only; it is not proof of dollar, beta,
volatility, or portfolio neutrality. Q02 and the unchanged downstream gates
must establish density, economics, execution quality, and realized book
correlation.

## Source Traceability

The canonical composite packet is
`strategy-seeds/sources/KELOHARJU-GK-OILBENCH-CAL-2026/source.md`.
Keloharju, Linnainmaa, and Nyberg supply the recurring same-calendar
cross-sectional commodity-return construction and five-observation minimum.
Gorska and Krawiec supply peer-reviewed calendar evidence on the two target
crude benchmarks. CME, ICE, and EIA establish Brent/WTI as a standard traded
and economically meaningful energy spread.

None of the sources tests this two-name continuous-CFD rank, equal stop-risk
legs, Darwinex month boundaries, broker costs, or the QM portfolio. No source
profit factor, return, drawdown, trade count, hedge ratio, or portfolio
correlation statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,246 registry rows and 377
cards and returned `CLEAN`. Manual review resolves the closest systems:

- `QM5_12843_wti-brent-spread` fades a rolling spread-level z-score.
- `QM5_12848_wti-brent-brk` follows a spread-level channel breakout.
- `QM5_12860_wti-brent-rshock` fades a short-horizon return shock.
- `QM5_13115_energy-samecal` ranks WTI against natural gas, not Brent.
- `QM5_20099_wti-samecal` and the Brent calendar cards trade one outright
  carrier instead of a relative crude-benchmark package.
- WTI trend, inventory, WPSR, and fixed-month cards do not estimate a
  synchronized historical WTI-minus-Brent calendar score.

The prior-year same-calendar estimator, exact WTI/Brent carrier pair,
opposite directions, and monthly rerank are jointly load-bearing. A recent
z-score, channel, return shock, fixed month map, single carrier, or XNG
substitution is outside this card.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20190_WTI_BRENT_CAL_D1`.
- Host/slot 0: `XTIUSD.DWX`, D1, magic `201900000`.
- Companion/slot 1: `XBRUSD.DWX`, D1, magic `201900001`.
- Decision: first tradable XTI D1 bar of every new broker month.
- Formation: the decision calendar month's return in exactly the ten prior
  years, requiring at least five synchronized paired observations.
- Hold: until the next broker-month boundary, with a 40-calendar-day stale
  guard.
- Expected cadence: approximately 12 completed packages/year; retire below
  five/year after warm-up.

## Rules

The formula, entry, exit, filter, and management rules below are the complete
authorized baseline. Anything not stated is outside this card.

### Formula

At the first tradable D1 bar of decision month `m` in year `Y`, reconstruct
synchronized completed month-end closes for both benchmarks. For every prior
year `y` in `[Y-10, Y-1]` with valid endpoints:

```text
r_WTI[y,m]   = ln(C_WTI[y,m]   / C_WTI[y,m-1])
r_Brent[y,m] = ln(C_Brent[y,m] / C_Brent[y,m-1])
relative_y   = r_WTI[y,m] - r_Brent[y,m]
score        = arithmetic_mean(relative_y)
```

Require at least five paired observations with matching endpoint timestamps.

- `score > 1e-12`: BUY WTI and SELL Brent.
- `score < -1e-12`: SELL WTI and BUY Brent.
- Deadband, missing/nonconsecutive endpoints, timestamp mismatch, nonpositive
  close, or invalid arithmetic: remain flat for the consumed month.

There is no price-level ratio, z-score, regression, oscillator, moving
average, breakout, carry proxy, external series, trained output, or
PnL-adaptive rule.

## 4. Entry Rules

1. Require exact EA ID `20190`, XTI D1 host, slot 0, and every baseline input
   locked to the values below.
2. Evaluate only at a genuine broker-month transition.
3. Persist the current month attempt before history, signal, spread, quote,
   stop, risk, news, or order gates. A flat, blocked, rejected, stopped, or
   partially opened decision cannot retry after restart.
4. Reconstruct bounded completed D1 month endpoints for both legs. Require
   matching month and preceding-month endpoint timestamps for every sample.
5. Calculate the ten-prior-year WTI-minus-Brent relative-return mean and
   require at least five paired samples beyond the fixed deadband.
6. Buy WTI/sell Brent for a positive score; sell WTI/buy Brent for a negative
   score.
7. Require no owned leg, acceptable spreads, valid current quotes, completed
   ATR(20), registered magics, and valid symbol/volume metadata.
8. Split one package `RISK_FIXED` budget equally between the two
   ATR-normalized legs. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each;
   there is no take-profit.
9. Prepare both orders, open XTI then Brent, and retain the package only if
   exactly one correctly directed position exists in each registered slot.
   If either order or final validation fails, flatten every owned leg.

## 5. Exit Rules

1. On the first tradable D1 bar of the next broker month, close both legs
   before considering a replacement package.
2. Close both legs after 40 calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No take-profit, trailing, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XTIUSD.DWX` D1 slot 0.
- Require synchronized month endpoints, ten prior calendar years, and at
  least five paired same-month samples.
- Require nonnegative current spreads no greater than 1,000 points for WTI
  and 1,500 points for Brent.
- Require valid ATR, quotes, volume steps, contract metadata, magic rows,
  attempt state, and package state.
- Q02 freezes both news axes OFF. No external calendar or data file is read.

## 7. Trade Management Rules

- The EA may own exactly two opposite-direction positions: WTI slot 0 and
  Brent slot 1. One shared fixed budget is split across the legs.
- Package composition and hard stops are checked every tick; an orphan,
  duplicate, same-direction, wrong-symbol, or wrong-magic state is flattened.
- A position is closed at the next month boundary or after the 40-day stale
  guard, and a consumed month cannot retry after a stop or repair.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded same-calendar estimator |
| `strategy_min_history_years` | 5 | [5] | paired seasonal sample floor |
| `strategy_history_bars` | 3000 | [3000] | bounded D1 retrieval buffer |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale package guard |
| `strategy_xti_max_spread_pts` | 1000 | [1000] | WTI entry spread cap |
| `strategy_xbr_max_spread_pts` | 1500 | [1500] | Brent entry spread cap |
| `strategy_deviation_points` | 20 | [20] | order deviation |

There is no baseline sweep. The estimator, carrier pair, and holding clock are
locked before Q02.

## Risk And Test Contract

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both legs share that one budget equally after
independent ATR normalization. Q02 evaluates the logical basket, not two
standalone symbol results.

Retire on fewer than five completed packages/year, nonpositive governed
economics, nondeterminism, mismatched endpoints, repeated monthly attempts,
orphan persistence, aggregate-risk breach, wrong magic/direction, or a later
correlation rejection. Financing, legging, lot granularity, CFD basis,
regional benchmark breaks, common crude beta, gaps, and narrow breadth are
binding risks.

## Strategy Allowability Check

- [x] R1: peer-reviewed same-calendar method and target-benchmark calendar
  evidence, with exchange and agency support for the spread structure.
- [x] R2: fixed synchronized estimator, relative rank, direction, shared
  risk, stops, attempt state, monthly exit, and repair rules.
- [ ] R3: FAIL after Q02. `XTIUSD.DWX` is established, but `XBRUSD.DWX` is
  absent from the DXZ symbol matrix, history-range registry, and T9 tester
  universe. Local legacy builds did not prove an executable Brent route.
- [x] R4: deterministic native price/calendar arithmetic only; no banned
  indicator, trained model, external runtime feed, grid, martingale, or
  pyramiding.
- [x] Dedup: deterministic verdict `CLEAN`; three WTI/Brent spread families
  and the XTI/XNG same-calendar sibling were manually resolved.

## Post-Q02 Setup Block

Work item `ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c` produced a valid Model 4
report with zero trades, but the tester log records `symbol XBRUSD.DWX does
not exist` and basket warm-up loaded one of two symbols. The run is classified
`SETUP_DATA_MISSING`, not a strategy-economic result. No entry or order-path
event was observable.

No same-lineage repair or rerun was applied. A valid recovery requires an
OWNER-authorized, venue-tradable Brent route with validated history and costs;
changing to an XTI-only or different-carrier mechanic requires a new approved
card variant.

## Framework Alignment

- No-trade: exact host/timeframe/slot, locked inputs, history synchronization,
  spread, symbol, magic, package, and attempt guards.
- Trade entry: monthly relative-calendar rank, opposite two-leg orders,
  shared fixed-risk sizing, hard stops, and atomic repair.
- Trade management: package validation, next-month close, stale close, and
  orphan cleanup.
- Trade close: framework close helper plus broker hard stops and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, one basket manifest, and one paced Q02 enqueue.
It does not authorize a live setfile, AutoTrading, `T_Live` access, a deploy
or T_Live manifest, portfolio admission, a portfolio-gate change, or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-01 | initial WTI/Brent same-calendar relative basket | G0 | APPROVED |
| v1-q02 | 2026-08-01 | strict build recorded and logical basket enqueued | Q02 | QUEUED |
| v1-q02-result | 2026-08-01 | zero-trade run stopped at missing Brent setup layer | Q02 | INFRA_FAIL / SETUP_DATA_MISSING |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-01 | APPROVED at intake; R3 later invalidated | this card, governed source packet, and Q02 setup evidence |
| Q01 Build Validation | 2026-08-01 | PASS | `D:/QM/reports/framework/21/build_check_20260731_233323.json`; strict compile `D:/QM/reports/compile/20260731_233639/summary.csv` |
| Q02 Baseline Screening | 2026-08-01 | INFRA_FAIL (`ZERO_TRADES` observed) | `D:/QM/reports/work_items/ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c/QM5_20190/20260731_233806/summary.json`; recovery record `docs/ops/evidence/2026-08-01_qm5_20190_zero_trades_setup_investigation.md` |
