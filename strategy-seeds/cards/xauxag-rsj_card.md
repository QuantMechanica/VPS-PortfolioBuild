---
card_schema_version: 2
ea_id: QM5_20234
slug: xauxag-rsj
type: strategy
strategy_id: KISS-RSJ-2025_XAU_XAG_S02
variant_id: KISS-RSJ-2025_XAU_XAG_S02
source_id: KISS-RSJ-2025
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20234_xauxag-rsj_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
source_authors: "Tamas Kiss; Igor Ferreira Batista Martins"
strategy_mechanic: monthly-xau-xag-prior-complete-month-relative-signed-jump-low-minus-high-rank
source_citation: "Kiss, Tamas, and Ferreira Batista Martins, Igor (2025), Good Volatility, Bad Volatility and the Cross Section of Commodity Returns, Finance Research Letters 86 Part D, article 108656, DOI 10.1016/j.frl.2025.108656."
source_citations:
  - type: peer_reviewed_paper
    citation: "Kiss, Tamas, and Ferreira Batista Martins, Igor (2025). Good Volatility, Bad Volatility and the Cross Section of Commodity Returns. Finance Research Letters 86 Part D, article 108656."
    location: "Complete 12-page open publication; Sections 2-5, Equations 1-4, Tables 1-5, Appendices A-B; DOI https://doi.org/10.1016/j.frl.2025.108656; governed packet strategy-seeds/sources/KISS-RSJ-2025/source.md"
    quality_tier: A
    role: primary_method
sources:
  - "[[sources/KISS-RSJ-2025]]"
concepts:
  - "[[concepts/relative-signed-jump-premium]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/realized-semivariance]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, realized-semivariance, relative-signed-jump, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20234_XAU_XAG_RSJ_D1
symbol: QM5_20234_XAU_XAG_RSJ_D1
symbol_slot: 0
magic: 202340000
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One monthly XAU/XAG package after at least 15 synchronized returns in the immediately preceding complete broker month; approximately 12 completed packages/year before Q02 validation."
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
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a monthly relative precious-metal signed-semivariance premium rather than outright XAU direction: long lower RSJ and short higher RSJ with one shared fixed-risk package; Q09 alone may establish book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, completed_month_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, adverse_parent_carrier, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-06 commodity/energy sleeve mission: R1 complete peer-reviewed FRL source and durable governed packet; R2 locked prior-complete-month normalized signed semivariance, lower-RSJ-long/higher-RSJ-short rank, shared fixed risk, hard stops, consumed attempt, renewal, and orphan repair; R3 registered native XAU/XAG D1 histories; R4 deterministic native arithmetic only. Deterministic dedup found no exact identity and three fuzzy neighbors; manual carrier and metal-family review is clean. The negative energy-carrier baseline and Q04 failure are disclosed and no efficacy transfers."
---

# QM5_20234 XAU/XAG Relative-Signed-Jump Rank

## Hypothesis

Commodity producers and consumers can hedge gains and losses asymmetrically,
so the balance between upside and downside realized semivariance may affect
subsequent futures risk premia. A monthly package that buys the lower-RSJ of
gold and silver and shorts the higher-RSJ metal tests that structural premium
while reducing common precious-metal direction relative to outright XAU.

Opposite legs and equal fixed-risk halves do not prove dollar, beta,
volatility, market, or portfolio neutrality. Q02 must establish density and
economics. The unchanged Q09 gate alone may measure realized overlap with the
certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The governed packet is `strategy-seeds/sources/KISS-RSJ-2025/source.md`.
Kiss and Ferreira Batista Martins (2025) calculate upside and downside
realized semivariance from daily commodity-futures returns, normalize their
difference into RSJ, rank a broad commodity cross-section monthly, buy low
RSJ, short high RSJ, and hold for one month.

The source does not test this two-metal Darwinex CFD carrier, synchronized
broker-day reconstruction, equal fixed-risk halves, ATR stops, legging,
financing, or the QM portfolio. The existing XTI/XNG carrier recorded negative
baseline economics and later failed Q04 walk-forward stability. Those adverse
facts are disclosure, not a direction change, rescue, or performance prior for
this carrier. No source or sibling-carrier performance transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,291 registry rows and 407
canonical cards. It found no exact identity and three fuzzy matches. Manual
review fixes the boundary:

- `QM5_13129_energy-rsj` preserves the same estimator and direction but trades
  XTI/XNG. This card is the predeclared XAU/XAG carrier falsification and does
  not alter the source rule after the energy result.
- `QM5_12724_cme-xauxag-brk` is a ratio/channel breakout;
  `QM5_20202_xauxag-rev18` is 18-month return reversal. Neither separates
  positive and negative squared daily returns.
- XAU/XAG ratio and OLS convergence, quantile-envelope, calendar, return-shock,
  relative-momentum, skewness, idiosyncratic-volatility, and momentum/IVol
  builds use different information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a paired monthly semivariance rank.

The immediately preceding complete month, synchronized simple daily returns,
normalized upside-minus-downside semivariance, lower-RSJ long/higher-RSJ short
direction, and monthly XAU/XAG lifecycle are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20234_XAU_XAG_RSJ_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `202340000`.
- Traded slot 1: `XAGUSD.DWX`, D1, magic `202340001`.
- Decision: first tradable XAU D1 bar of each broker-calendar month.
- Formation: common completed D1 closes whose ending timestamps fall inside
  the immediately preceding complete broker month; current month excluded.
- Hold: next broker-month transition, with a 35-calendar-day stale guard.
- Expected cadence: approximately 12 paired packages/year; retire below five
  completed packages per full post-warm-up year.

## Rules

For each synchronized return date `d` and metal `i`, calculate simple return
`r_i,d`. Then calculate:

`RV+_i = sum(r_i,d^2 when r_i,d > 0)`

`RV-_i = sum(r_i,d^2 when r_i,d < 0)`

`RSJ_i = (RV+_i - RV-_i) / (RV+_i + RV-_i)`

- `RSJ_XAU < RSJ_XAG`: BUY XAU and SELL XAG.
- `RSJ_XAU > RSJ_XAG`: SELL XAU and BUY XAG.
- Difference within `1e-12`, fewer than 15 synchronized returns, nonpositive
  total variance, or invalid history: consume the month and stay flat.

No price ratio, OLS beta, momentum, calendar direction, skewness, adaptive
threshold, or single-leg fallback enters the signal.

## 4. Entry Rules

1. Require exact EA ID `20234`, XAU host D1, slot 0, and the frozen input
   contract below.
2. Process lifecycle exits before entry gates and evaluate only on a genuine
   broker-month transition.
3. Persist the month attempt before history, signal, spread, quote, news,
   sizing, or order gates; same-month deal history is a second no-retry guard.
4. Require no owned leg and reconstruct at least 15 synchronized prior-month
   simple returns for both metals.
5. Require positive total variance for both legs and select opposite
   directions using the strict lower-RSJ-versus-higher-RSJ rank.
6. Require both spreads within caps, valid quotes, completed `ATR(20,D1)`,
   symbol metadata, fixed-risk mode, and frozen news gates.
7. Split one `RISK_FIXED` package budget equally across the legs and place a
   frozen `3.5 * ATR(20,D1)` server-side hard stop on each leg.
8. If the second order fails, immediately flatten the first leg. No one-leg
   strategy position is authorized.

## 5. Exit Rules

1. Close both legs on the first tradable XAU D1 bar of the next broker month
   before considering a replacement package.
2. Close the package after 35 calendar days as a stale guard.
3. Flatten an orphan, duplicate leg, same-side pair, wrong symbol, or wrong
   magic immediately.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled to preserve the source's one-month hold.
6. No intramonth rank flip, target, trail, break-even, partial close, scale-in,
   hedge overlay, grid, martingale, pyramid, or discretionary exit exists.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host, timeframe, EA ID, slots, symbols, and
  frozen parameter contract.
- Reject malformed formation bounds, missing synchronized observations,
  nonpositive closes or total variance, nonfinite RSJ, a numerical tie,
  invalid ATR/quote/lot metadata, excessive spread, consumed attempt,
  same-month deal, or an existing owned leg.
- Q02 freezes both news axes and legacy news mode OFF. Runtime reads no
  external file, API, futures chain, volume, open interest, option surface,
  forecast, or trained output.

## 7. Trade Management Rules

- Exactly one logical two-leg package and one consumed attempt per broker
  month.
- Close before renewal, on stale age, invalid composition, orphaning, hard
  stop, or framework safety action.
- Terminal-global attempt state plus owned deal history survives restart and
  prevents same-month re-entry after a rejected or stopped package.
- No averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fitting, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_months` | 1 | [1] | source-defined complete-month formation |
| `strategy_history_bars` | 80 | [80] | bounded D1 reconstruction buffer |
| `strategy_min_return_observations` | 15 | [15] | synchronized data-sufficiency floor |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket-order deviation |

Changing the formation, estimator, rank direction, carrier, package sizing,
hold, stop, or retry policy requires a new card and full pipeline run.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete package. Each leg receives one half of
the fixed stop-risk budget. `RISK_FIXED` is a stop-normalized loss budget, not
fixed notional exposure. No live-risk mode is authorized.

Primary risks are the 36-future-to-two-CFD narrowing, single-month estimator
noise, adverse sibling-carrier evidence, gold/silver regime change, residual
common-metal beta, unequal notionals, futures-to-CFD basis, gaps, financing,
legging, and later portfolio correlation. Retire below five packages/year or
on nonpositive governed economics, wrong rank direction, current-month
leakage, duplicate entry, restart nondeterminism, missing stop, broken basket
accounting, risk mismatch, or later correlation rejection. No rescue or
waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: named-author peer-reviewed FRL paper with DOI and durable
  complete-read repository evidence; no metal-specific source result claimed.
- [x] R2 mechanical: fixed completed-month signed semivariance, strict rank,
  monthly renewal, attempt state, package repair, hard stops, and stale exit.
- [x] R3 testable: registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 data.
- [x] R4 compliant: deterministic native arithmetic only; no trained output,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramiding.
- [x] No exact identity; same-source energy carrier and metal-family fuzzy
  neighbors are manually resolved, with adverse sibling evidence disclosed.

## Framework Alignment

- no_trade: exact host/slots, frozen inputs, synchronized completed-month
  history, arithmetic, spread, attempt, package, and framework gates.
- trade_entry: normalized RSJ rank, opposite paired orders, equal fixed-risk
  halves, frozen ATR stops, and second-leg rollback.
- trade_management: next-month renewal, stale close, composition validation,
  and orphan cleanup.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
logical-basket `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It
does not authorize a manual backtest; live, demo, or shadow setfiles;
AutoTrading; `T_Live`; a deploy or T_Live manifest; portfolio admission; a
portfolio-gate change; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial XAU/XAG RSJ carrier card | Q01 | PASS |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20234_xauxag_rsj_g0.md` |
| Q01 Compile / Static Validation | 2026-08-06 | PASS | `framework/build/compile/20260805_233838/QM5_20234_xauxag-rsj.compile.log`; `D:/QM/reports/framework/21/build_check_20260805_233838.json` (0 errors, 0 warnings, 0 gate failures) |
| Q02 Baseline Screening | 2026-08-06 | NOT ENQUEUED — CPU CEILING | targeted dry run selected one priority item; apply withheld because 10 factory terminals were active against the ceiling of 7 |
