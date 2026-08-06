---
card_schema_version: 2
type: strategy
strategy_id: CME-MEHLITZ-XAUXAG-VRSPREAD-2026_S01
variant_id: CME-MEHLITZ-XAUXAG-VRSPREAD-2026_S01
source_id: CME-MEHLITZ-XAUXAG-VRSPREAD-2026
ea_id: QM5_20249
slug: xauxag-vr-spread
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20249_xauxag-vr-spread_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Julia S. Mehlitz; Benjamin R. Auer; CME Group"
source_citation: "Mehlitz and Auer (2024), The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Mehlitz, J. S., and Auer, B. R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "DOI https://doi.org/10.1080/1351847X.2023.2220118; complete open precursor Chapter 3 pp. 51-74 and Appendix C pp. 110-113; governed packet strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md"
    quality_tier: A
    role: primary_variance_ratio_memory_state
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.html; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: primary_relative_value_carrier
strategy_mechanic: monthly-synchronized-xau-xag-relative-return-q2-robust-variance-ratio-memory-continuation-reversal-basket
sources:
  - "[[sources/CME-MEHLITZ-XAUXAG-VRSPREAD-2026]]"
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/memory-enhanced-momentum]]"
  - "[[concepts/variance-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, memory-regime, momentum-reversal, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20249_XAU_XAG_VRSPREAD_D1
symbol: QM5_20249_XAU_XAG_VRSPREAD_D1
symbol_slot: 0
magic: 202490000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 6-10 completed monthly XAU/XAG packages/year after thirty-three synchronized completed month ends; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a monthly two-leg precious-metals relative-memory stream whose common-direction exposure and state variable differ from outright XAU and the certified QM5_12567 XNG oscillator; Q09 alone may establish realized portfolio decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, relative_return_orientation, robust_variance_ratio, fixed_significance_threshold, memory_direction_matrix, aggregate_fixed_risk, restart_attempt_state, friday_close_exception, magic_schema, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20249_xauxag_vr_spread_g0.md: tier-A peer-reviewed complete-read memory source with explicit gold/silver membership plus tier-B exchange spread lineage; locked thirty-three synchronized month ends, 32 relative log returns, q=2 robust variance-ratio statistic, two-sided 10% significance boundary, latest relative-return direction, persistence-follow/anti-persistence-reverse mapping, opposite two-leg package, persisted monthly attempt, aggregate fixed risk, ATR stops, rollover, and stale exit; registered XAU/XAG D1 history; deterministic native arithmetic only. Dedup scanned 4,306 registry rows and 423 cards with no exact or fuzzy match; manual mechanic review is clean. The relative-series conjunction is a QM hypothesis and no source efficacy or neutrality transfers."
---

# QM5_20249 XAU/XAG Variance-Ratio Spread

## Hypothesis

Gold and silver share a precious-metals component but respond differently to
safe-haven, monetary, industrial, and business-cycle shocks. Their relative
monthly return may therefore alternate between persistent and anti-persistent
states. A two-leg basket that follows the latest gold-minus-silver return only
when a robust variance-ratio test identifies persistence, reverses it when the
test identifies anti-persistence, and otherwise stays flat tests a structural
relative-memory edge while suppressing some outright precious-metal direction.

This is not a claim of dollar, beta, volatility, factor, or portfolio
neutrality. Q02 must establish density and economics; unchanged downstream
gates own execution robustness and Q09 alone may measure realized overlap with
the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/CME-MEHLITZ-XAUXAG-VRSPREAD-2026/source.md`. Mehlitz
and Auer (2024) provide the `R1-q2` robust variance-ratio test, fixed 32-month
sample, two-sided 10% boundary, latest-return direction, and persistence /
anti-persistence continuation/reversal matrix. Their commodity-futures sample
explicitly contains gold and silver. CME defines and documents the opposing-
leg gold/silver relative-value spread and the metals' overlapping but distinct
economic drivers.

Neither source tests a variance-ratio statistic on gold-minus-silver returns.
That relative-series intersection, continuous CFDs, synchronized broker-month
reconstruction, equal fixed-stop-risk halves, ATR stops, spread caps, legging
repair, and lifecycle controls are transparent QM adaptations. No source
profitability, count, drawdown, hedge ratio, neutrality, or portfolio
correlation statistic is imported.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,306 registry rows and 423 cards
and returned `CLEAN` with no fuzzy hit for the complete identity. Manual review
separates the closest builds:

- `QM5_12577_cme-xauxag-ratio` fades a rolling fixed-beta log-ratio z-score.
- `QM5_12724_cme-xauxag-brk` follows a fixed-beta ratio-channel breakout;
  `QM5_12862_xauxag-rspread` fades a D1 return-spread z-score.
- `QM5_20161_xauxag-ols-rv` and `QM5_13205_xau-xag-qc` trade rolling OLS or
  conditional-quantile disequilibrium.
- `QM5_20194_xauxag-momrev` requires a 12/18-month rank disagreement.
- `QM5_20233` through `QM5_20236` rank skew, signed jumps, expected shortfall,
  or volatility-of-volatility across the two metals.
- `QM5_13134_energy-vr-mom` uses the source memory matrix on outright WTI; it
  has no synchronized two-leg relative-return series or basket lifecycle.

The relative series, 32-return robust `q=2` test, fixed significance boundary,
latest relative direction, continuation/reversal mapping, opposite legs, and
monthly attempt clock are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20249_XAU_XAG_VRSPREAD_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `202490000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `202490001`.
- Decision clock: first processed XAU D1 bar after a genuine broker-month
  transition.
- Formation: 33 synchronized consecutive completed month-end closes per leg,
  defining 32 chronological relative monthly log returns.
- Holding clock: next broker-month boundary, with a 35-calendar-day stale
  guard.
- Expected cadence: 6-10 completed packages/year after warm-up; retire below
  five packages per full post-warm-up year.
- Runtime: native MT5 D1 time/close, ATR, spreads, quotes, positions, deals,
  broker calendar, and contract metadata only.

## Formula

Let `G[t]` and `S[t]` be synchronized completed gold and silver month-end
closes, ordered oldest to newest. Define the 32 chronological relative returns:

```text
r[t]       = ln(G[t+1] / G[t]) - ln(S[t+1] / S[t]), t=0..31
mean       = average(r[0] ... r[31])
SSE        = sum((r[t] - mean)^2), t=0..31
rho_1      = sum((r[t] - mean)(r[t-1] - mean), t=1..31) / SSE
VR(2)      = 1 + rho_1
robust_se  = sqrt(sum((r[t] - mean)^2(r[t-1] - mean)^2, t=1..31) / SSE^2)
z          = (VR(2) - 1) / robust_se
base_dir   = sign(r[31])
```

- If `abs(z) <= 1.64485362695147` or `base_dir == 0`: remain flat.
- If `z > 1.64485362695147`: trade `base_dir` (persistence follows).
- If `z < -1.64485362695147`: trade opposite `base_dir`
  (anti-persistence reverses).
- Positive trade direction: BUY XAU and SELL XAG.
- Negative trade direction: SELL XAU and BUY XAG.
- Invalid, incomplete, nonsynchronized, nonconsecutive, or zero-variance
  history remains flat and fails closed.

## Rules

The following rules are the complete authorized Q02 baseline. Signal
parameters are locked; no horizon, direction, threshold, carrier, or retry
sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `20249`, `XAUUSD.DWX` D1 host, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle and package-repair exits before entry-only gates and
   evaluate only at a genuine broker-month transition.
3. Persist the current broker month as consumed before history, signal,
   spread, quote, news, stop, sizing, or order gates. A flat, rejected, failed,
   stopped, or blocked attempt cannot retry during that month.
4. Reject owned exposure or any same-month entry deal for either registered
   magic.
5. Reconstruct exactly 33 consecutive completed month-end closes for each leg.
   Require identical month keys and timestamps and require the newest endpoint
   to belong to the immediately preceding broker month.
6. Form exactly 32 chronological relative monthly log returns and compute the
   robust `q=2` statistic exactly as specified.
7. Enter only on significant memory and a nonzero latest relative return.
   Follow the latest relative direction under persistence and reverse it under
   anti-persistence.
8. Require XAU and XAG spreads in `[0,1500]` and `[0,3000]` points,
   respectively, executable quotes, completed per-leg `ATR(20,D1)`, valid
   stop geometry, registered magics, and valid volume metadata.
9. Split one package `RISK_FIXED` budget equally between two independently
   ATR-normalized legs. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each;
   there is no take-profit.
10. Open XAU then XAG. Keep the package only if exactly one correctly directed
    position exists in each registered slot. On order or validation failure,
    flatten every owned leg immediately.

## 5. Exit Rules

1. Close both legs on the first processed XAU D1 bar of every new broker month
   before considering replacement risk.
2. Close both legs after 35 elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, same-direction, wrong-symbol,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No intramonth reversal, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or on unlocked inputs.
- Require synchronized, ordered, consecutive, positive completed endpoints;
  valid logarithms, nonzero variance and robust standard error; significant
  memory; nonzero latest relative return; registered magics; valid package and
  attempt state; acceptable spreads; executable quotes; ATR; stops; and volume
  metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and orphan repair run before entry-only gates.
- Runtime may not read a futures curve, external file/API, analyst input,
  volume, open interest, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
  slot 1. One shared fixed budget is split equally by hard-stop risk.
- Package composition and hard stops are checked every tick; an invalid or
  partial package is flattened.
- Close-before-renew runs at every genuine month boundary. A consumed month
  cannot retry after a stop or repair.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; future-dated tester state is cleared at
  initialization.
- No randomness, adaptive fit, external state, partial close, scale-in, or
  pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_vr_window_months` | 32 | [32] | robust relative-memory sample |
| `strategy_vr_q` | 2 | [2] | published short-memory order |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] | published two-sided 10% boundary |
| `strategy_history_bars` | 1200 | [1200] | bounded D1 month-end reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | order deviation |

There is no baseline sweep. The relative-return definition, monthly cadence,
sample, `q`, estimator, significance boundary, continuation/reversal matrix,
carrier pair, risk split, holding clock, and no-retry policy are locked.

## Author Claims

Mehlitz and Auer document the memory-conditioned continuation/reversal matrix
for individual commodities in broad futures portfolios. CME documents the
gold/silver relative-value carrier and its distinct economic drivers. Neither
claims that applying the memory rule to the gold-minus-silver relative series
is profitable, neutral, sufficiently frequent, or diversifying. Q02 and later
gates are the only strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: narrow two-name
breadth, CFD roll and financing, common USD and precious-metals beta, silver's
industrial beta and higher volatility, asynchronous history, legging, hard-
stop desynchronization, lot granularity, and a sparse significance gate may
dominate the intended relative-memory return stream.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on unsynchronized/nonconsecutive endpoints, wrong relative-return
  orientation, wrong robust statistic, wrong direction matrix, repeated month
  attempt, same-direction/orphan legs, aggregate-risk breach, hold beyond 35
  days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizon, `q`, critical value, direction,
  carrier, hedge convention, entry clock, stop, hold, spread cap, or retry
  policy.

## Strategy Allowability Check

- [x] R1: tier-A peer-reviewed complete-read source with explicit gold/silver
  membership plus tier-B exchange evidence for the relative-value carrier.
- [x] R2: fixed synchronized endpoints, relative-return formula, robust `q=2`
  statistic, critical value, direction matrix, package risk, hard stops,
  attempt state, rollover, and stale exit.
- [x] R3: registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes with established
  logical-basket tester support.
- [x] R4: deterministic logarithm/calendar/statistic/ATR arithmetic; no banned
  signal indicator, ML, external runtime feed, grid, martingale, or pyramid.
- [x] Dedup: no exact or fuzzy hit; all material XAU/XAG and variance-ratio
  neighbors manually resolved cleanly.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news/Friday contract, magic,
  and cheap parameter guards.
- trade_entry: monthly attempt persistence, synchronized endpoint
  reconstruction, relative returns, robust memory statistic, direction matrix,
  spread/quote/ATR/stop checks, two orders, and atomic repair.
- trade_management: package validation, next-month close, stale close, and
  orphan cleanup before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes only research, build, strict compile/Q01, and one non-live
paced Q02 handoff. It does not authorize a manual backtest; live, demo, shadow,
stress, or optimization setfile; AutoTrading; `T_Live`; deploy or T_Live
manifest; portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded XAU/XAG relative-memory card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20249_xauxag_vr_spread_g0.md` |
| Q01 Build Validation | 2026-08-06 | NOT_RUN | pending strict compile |
| Q02 Baseline Screening | 2026-08-06 | NOT_ENQUEUED | pending Q01 PASS and paced-fleet capacity |
