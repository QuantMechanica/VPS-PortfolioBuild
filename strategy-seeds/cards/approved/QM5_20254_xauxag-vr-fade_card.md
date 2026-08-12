---
card_schema_version: 2
type: strategy
strategy_id: CME-MEHLITZ-XAUXAG-VRFADE-2026_S01
variant_id: CME-MEHLITZ-XAUXAG-VRFADE-2026_S01
source_id: CME-MEHLITZ-XAUXAG-VRFADE-2026
ea_id: QM5_20254
slug: xauxag-vr-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20254_xauxag-vr-fade_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Julia S. Mehlitz; Benjamin R. Auer; Karsten Schweikert; CME Group"
source_citation: "Mehlitz and Auer (2024), The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118; Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Mehlitz, J. S., and Auer, B. R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "Sections 3.3.1-3.3.2 and Appendix C; DOI https://doi.org/10.1080/1351847X.2023.2220118; complete open precursor review in strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md"
    quality_tier: A
    role: primary_anti_persistence_state
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.11.010; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.html; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: primary_relative_value_carrier
strategy_mechanic: daily-gold-silver-log-ratio-zscore-fade-gated-by-monthly-q2-robust-relative-return-antipersistence
sources:
  - "[[sources/CME-MEHLITZ-XAUXAG-VRFADE-2026]]"
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
  - "[[sources/SCHWEIKERT-XAUXAG-RATIO-2026]]"
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/variance-ratio]]"
  - "[[concepts/conditional-mean-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/log-price-ratio-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, conditional-mean-reversion, anti-persistence, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20254_XAU_XAG_VRFADE_D1
symbol: QM5_20254_XAU_XAG_VRFADE_D1
symbol_slot: 0
magic: 202540000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated five to nine completed XAU/XAG packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
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
q02_work_item_id: "3919c4ce-0843-4ad4-9110-b5a0eb278895"
review_focus: "Falsify a conditional XAU/XAG ratio-convergence stream that suppresses some outright metal direction and only enters under statistically significant relative-return anti-persistence; Q09 alone may establish realized decorrelation from the certified XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, ratio_orientation, robust_variance_ratio, fixed_significance_threshold, antipersistence_only_gate, aggregate_fixed_risk, restart_attempt_state, friday_close_exception, magic_schema, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20254_xauxag_vr_fade_g0.md: tier-A peer-reviewed complete-read memory lineage, tier-A state-dependent gold/silver relation, and tier-B exchange carrier; locked 33 synchronized month ends, 32 relative log returns, q=2 robust statistic, negative two-sided 10% boundary, 60 completed D1 ratios, fixed fade/convergence bands, aggregate fixed risk, ATR stops, rollover, and stale exit; native deterministic arithmetic only. Dedup scanned 4,311 registry rows and 428 cards with no exact or fuzzy hit; manual review distinguishes all ratio, residual, memory-direction, rank, and calendar neighbors. No source efficacy, neutrality, or decorrelation transfers."
---

# QM5_20254 XAU/XAG Anti-Persistent Ratio Fade

## Hypothesis

Gold and silver share a source-supported but state-dependent long-run relation.
An extreme completed-D1 log-price-ratio displacement may be more likely to
converge when the recent monthly gold-minus-silver return process is
statistically anti-persistent. An opposite-leg package tests that conditional
relative-value path while suppressing some outright precious-metal direction.

This is a falsifiable source intersection, not a profitability, neutrality, or
decorrelation claim. Q02 owns density and baseline economics. Unchanged later
gates own execution robustness, and Q09 alone may measure book overlap.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/CME-MEHLITZ-XAUXAG-VRFADE-2026/source.md`. Mehlitz and
Auer supply the 32-return heteroskedasticity-robust `q=2` memory test, fixed
two-sided 10% boundary, and interpretation of a significant negative state as
anti-persistence. Their source universe explicitly contains gold and silver.
Schweikert supports a nonlinear, state-dependent gold/silver relation. CME
defines the price ratio and opposing-leg spread carrier.

None of the sources tests the exact conjunction, Darwinex continuous CFDs, a
60-D1 ratio normalization, the bands, aggregate fixed risk, ATR stops, spread
caps, attempt ledger, or lifecycle. No source PF, return, Sharpe, drawdown,
count, hedge ratio, neutrality, or portfolio-correlation statistic transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker found no exact collision or fuzzy
match across 4,311 registry rows and 428 cards. Manual review fixes the
boundary:

- `QM5_20157_xau-xag-ratio` fades ratio displacement unconditionally and has
  no variance-ratio estimator or significance gate.
- `QM5_20161_xauxag-ols-rv`, `QM5_13205_xau-xag-qc`, and
  `QM5_20012_xauxag-cmtar` use OLS, conditional-quantile, or fixed asymmetric
  residuals, not a raw ratio state gated by relative-return anti-persistence.
- `QM5_20249_xauxag-vr-spread` trades the latest relative monthly-return
  direction under both significant memory signs. This card uses only a
  significant negative memory state, derives direction from a completed-D1
  ratio-level displacement, can enter later within the gated month, and exits
  on ratio convergence.
- Existing breakout, momentum, calendar, skew, jump, tail-risk, and volatility
  rank baskets neither combine these states nor use this lifecycle.

The anti-persistence-only gate, ratio-level displacement, fade map, convergence
exit, and one-attempt-per-month package are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20254_XAU_XAG_VRFADE_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `202540000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `202540001`.
- Decision clock: every new XAU D1 bar, using completed synchronized data only.
- Memory formation: 33 consecutive synchronized completed month ends,
  defining 32 chronological relative monthly log returns.
- Ratio formation: 60 synchronized completed D1 log-price ratios.
- Lifecycle: at most one consumed entry attempt per broker month; close at
  convergence or the next broker-month transition, with a 35-day stale guard.
- Expected cadence: 5-9 completed packages/year after warm-up; retire below
  five packages per full post-warm-up year.

## Formula

Let `G[t]` and `S[t]` be synchronized completed gold and silver month-end
closes ordered oldest to newest. Define 32 relative returns:

```text
r[t]  = ln(G[t+1] / G[t]) - ln(S[t+1] / S[t]), t=0..31
d[t]  = r[t] - mean(r)
SSE   = sum(d[t]^2)
rho1  = sum(d[t] * d[t-1], t=1..31) / SSE
VR(2) = 1 + rho1
se    = sqrt(sum(d[t]^2 * d[t-1]^2, t=1..31) / SSE^2)
z_vr  = (VR(2) - 1) / se
```

Require `z_vr < -1.64485362695147`. Insignificant or positive memory is flat.

For the latest 60 synchronized completed D1 closes, define
`x[j]=ln(G[j])-ln(S[j])`, its sample mean and sample standard deviation, then
`z_ratio=(x_latest-mean(x))/sd(x)`.

- `z_ratio > +1.5`: SELL XAU and BUY XAG.
- `z_ratio < -1.5`: BUY XAU and SELL XAG.
- otherwise: remain flat without consuming the month's attempt.
- Once open, `abs(z_ratio)<=0.25` is convergence and closes both legs.

## Rules

The following rules are the complete authorized Q02 baseline. There is no
signal-parameter sweep.

## 4. Entry Rules

1. Require exact EA ID `20254`, `XAUUSD.DWX` D1 host, magic slot 0, and every
   baseline input locked to its declared value.
2. Evaluate only on a new host D1 bar and use completed bars only.
3. Reject existing owned exposure or any entry deal/consumed attempt already
   recorded in the current broker month.
4. Reconstruct exactly 33 consecutive synchronized completed month-end closes
   per leg. Require identical month keys and timestamps and require the newest
   endpoint to belong to the immediately preceding broker month.
5. Form exactly 32 chronological relative monthly log returns and require the
   robust `q=2` statistic to be strictly below `-1.64485362695147`.
6. Reconstruct exactly 60 synchronized completed D1 closes per leg and compute
   the log-ratio z-score with sample standard deviation.
7. Enter only beyond the fixed `+/-1.5` bands in the fade direction. Persist
   the current month as consumed after signal qualification but before news,
   spread, quote, stop, sizing, or order gates. A rejected, failed, stopped, or
   partially opened signal cannot retry in that month.
8. Require XAU and XAG spreads in `[0,1500]` and `[0,3000]` points,
   respectively, executable quotes, completed per-leg `ATR(20,D1)`, valid stop
   geometry, registered magics, and valid volume metadata.
9. Split one package `RISK_FIXED` budget equally between two independently
   ATR-normalized legs. Attach a frozen `3.5*ATR(20,D1)` hard stop to each;
   there is no take-profit.
10. Open XAU then XAG. Keep the package only if exactly one correctly directed
    position exists in each registered slot. On order or validation failure,
    flatten every owned leg immediately.

## 5. Exit Rules

1. On each new D1 bar, close both legs when a valid completed-D1 ratio state
   satisfies `abs(z_ratio)<=0.25`.
2. Close both legs on the first processed XAU D1 bar of the next broker month.
3. Close both legs after 35 elapsed calendar days as a stale guard.
4. Immediately flatten an orphan, duplicate, same-direction, wrong-symbol,
   wrong-magic, or missing-stop package.
5. Broker hard stops and the framework kill switch remain authoritative.
6. Friday close is disabled because a valid package may span a weekend.
7. No intramonth reversal, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or on unlocked inputs.
- Require synchronized, ordered, consecutive, positive completed endpoints;
  valid logarithms, nonzero monthly variance and robust standard error; a
  significant negative memory state; nonzero D1 ratio variance; registered
  magics; valid package and attempt state; acceptable spreads; executable
  quotes; ATR; stops; and volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and orphan repair run before entry-only gates.
- Runtime may not read a futures curve, external file/API, analyst input,
  volume, open interest, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
  slot 1. One shared fixed budget is split equally by hard-stop risk.
- Package composition and hard stops are checked every tick; invalid or
  partial state is flattened.
- Convergence and month-transition exits run on new D1 bars. A consumed month
  cannot retry after a stop, convergence exit, or repair.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; future-dated tester state is cleared at init.
- No randomness, adaptive fit, external state, partial close, scale-in, or
  pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_vr_window_months` | 32 | [32] | robust relative-memory sample |
| `strategy_vr_q` | 2 | [2] | published short-memory order |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] | published two-sided 10% boundary |
| `strategy_ratio_lookback_d1` | 60 | [60] | completed-D1 ratio normalization |
| `strategy_ratio_entry_z` | 1.5 | [1.5] | fixed displacement band |
| `strategy_ratio_exit_z` | 0.25 | [0.25] | fixed convergence band |
| `strategy_history_bars` | 1200 | [1200] | bounded month-end reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | order deviation |

Changing the memory sign, sample, `q`, critical value, ratio definition,
window, bands, directions, carrier, risk split, holding clock, or retry policy
requires a new card and full pipeline run.

## Author Claims

Mehlitz and Auer document significant persistence/anti-persistence
classification for individual commodities. Schweikert documents a
state-dependent gold/silver relation, and CME documents the ratio-spread
carrier. None claims that this combined relative-series gate and ratio fade is
profitable, neutral, frequent enough, or diversifying. Q02 and later gates are
the only strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: narrow two-name
breadth, a 33-month warm-up, significance-gate sparsity, CFD roll/financing,
common USD and precious-metal beta, silver industrial beta, asynchronous
history, legging, hard-stop desynchronization, and lot granularity may dominate
the intended relative-value path.

Opposite direction and equal stop-risk halves do not guarantee dollar, beta,
volatility, factor, or portfolio neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on unsynchronized/nonconsecutive endpoints, wrong relative-return or
  ratio orientation, wrong robust statistic, entry without a significant
  negative memory state, repeated month attempt, same-direction/orphan legs,
  aggregate-risk breach, hold beyond 35 days, missing hard stop, invalid risk
  mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a window, threshold, direction, carrier,
  stop, hold, spread cap, or retry policy.

## Strategy Allowability Check

- [x] R1: tier-A peer-reviewed memory and gold/silver relation records plus a
  tier-B exchange-defined carrier; parent packets were read completely.
- [x] R2: fixed synchronized endpoints, formulas, thresholds, directions,
  package risk, hard stops, attempt state, convergence, rollover, and stale
  exit.
- [x] R3: registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes with established
  logical-basket tester support.
- [x] R4: deterministic logarithm/calendar/statistic/ATR arithmetic; no banned
  signal indicator, ML, external runtime feed, grid, martingale, or pyramid.
- [x] Dedup: deterministic check clean; all material ratio, residual,
  variance-ratio, rank, and calendar neighbors manually resolved.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news/Friday contract, magic,
  and cheap parameter guards.
- trade_entry: monthly anti-persistence gate, daily ratio displacement,
  persisted attempt, spread/quote/ATR/stop checks, two orders, and atomic
  repair.
- trade_management: package validation, completed-D1 convergence,
  next-month close, stale close, and orphan cleanup before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes only research, build, strict compile/Q01, one non-live
logical-basket `RISK_FIXED` setfile, and one paced Q02 handoff. It does not
authorize a manual backtest; live, demo, shadow, stress, or optimization
setfile; AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded XAU/XAG conditional ratio-fade card | G0 | APPROVED |
| v1-q01 | 2026-08-06 | deterministic V5 basket build and strict compile | Q01 | PASS |
| v1-q02 | 2026-08-06 | single paced-fleet baseline handoff | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20254_xauxag_vr_fade_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | `docs/ops/evidence/2026-08-06_qm5_20254_xauxag_vr_fade_q01_q02.md` |
| Q02 Baseline Screening | 2026-08-06 | ENQUEUED; pending, attempt 0 | work item `3919c4ce-0843-4ad4-9110-b5a0eb278895`; same evidence |
