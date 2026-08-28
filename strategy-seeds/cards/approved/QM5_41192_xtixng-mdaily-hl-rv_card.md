---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-HL-XTIXNG-MDAILY-RV-2026_S01
variant_id: VILLAR-HL-XTIXNG-MDAILY-RV-2026_S01
source_id: VILLAR-HL-XTIXNG-MDAILY-RV-2026
ea_id: QM5_41192
slug: xtixng-mdaily-hl-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41192_xtixng-mdaily-hl-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41192_xtixng_monthly_daily_hodges_lehmann_reversion_g0.md
source_approval: decisions/2026-08-29_xtixng_monthly_daily_hodges_lehmann_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; governed H-L arithmetic and basket-lifecycle packets."
source_citations:
  - type: government_research
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A_government
    role: oil_gas_physical_and_economic_linkage_with_instability
  - type: peer_reviewed_energy_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: adverse_state_dependent_oil_gas_relation_evidence
  - type: governed_method_source
    citation: "QuantMechanica bounded H-L arithmetic and synchronized two-leg lifecycle precedents."
    location: "strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md; strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md"
    quality_tier: internal_governed
    role: inclusive_pairwise_pseudomedian_and_atomic_monthly_basket_contract
strategy_mechanic: synchronized-completed-month-daily-xti-minus-xng-log-returns-inclusive-pairwise-average-pseudomedian-sign-fade-equal-notional-monthly-basket
sources:
  - "[[sources/VILLAR-HL-XTIXNG-MDAILY-RV-2026]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/hodges-lehmann-pseudomedian]]"
  - "[[concepts/market-neutral-style-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/inclusive-pairwise-pseudomedian]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, relative-value, market-neutral-style, hodges-lehmann, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41192_XTI_XNG_MDAILY_HL_RV_D1
symbol: QM5_41192_XTI_XNG_MDAILY_HL_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magics: [411920000, 411920001]
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 10-12 completed XTI/XNG packages per full post-warm-up year; exact-zero and invalid synchronized states consume the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK
r1_reasoning: "Complete U.S. government and peer-reviewed oil/gas relationship evidence with binding instability findings plus complete governed arithmetic and lifecycle precedents; the exact daily-pseudomedian basket remains an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronization, boundary pair, daily relative returns, endpoint identity, inclusive pairs, exact count, sort, odd/even median, sides, attempt, aggregate risk, stops, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX and XNGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, continuous-CFD basis, rolls, financing, and fills remain explicit Q02 risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, sorting, comparisons, ATR risk controls, and execution state; no trained signal, prohibited runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: 45 D1 bars; 17-23 completed-month sessions; inclusive pair cap 276; numerical tolerance 1e-10; 180-minute entry window; ATR(20)*3.5 stops; equal target notionals; 20% realized mismatch ceiling; 40-day stale exit; 1500-point XTI and 3000-point XNG spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a monthly XTI/XNG relative-value basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, completed-month boundary, every relative return, endpoint identity, inclusive self/cross pairs, dynamic count, odd/even median, fade sides, consumed month, aggregate fixed risk, atomic repair, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_energy_carrier, synchronized_d1_timestamps, immediately_completed_month_only, adjacent_older_boundary, all_month_daily_relative_returns, endpoint_identity, inclusive_self_cross_pairs, dynamic_pair_count, exact_odd_even_median, strict_contrarian_sides, monthly_attempt_state, equal_target_notional, aggregate_risk_fixed, frozen_hard_stops, atomic_pair_repair, monthly_renewal, risk_mode_dual, friday_close_disabled, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29: R1 complete government and peer-reviewed oil/gas evidence with governed H-L arithmetic; R2 exact synchronized daily-pseudomedian basket; R3 registered XTI/XNG D1; R4 deterministic native arithmetic only; canonical and manual dedup resolved."
---

# QM5_41192 XTI/XNG Completed-Month Daily Hodges-Lehmann Reversion

## Hypothesis

Crude oil and natural gas share production, substitution, drilling, financing,
transport, and LNG links, yet gas also has strong regional and idiosyncratic
drivers. A broad displacement in the daily oil-minus-gas return distribution
within one completed month may therefore partially reverse during the next
month without assuming a permanent price ratio or fitted hedge coefficient.

This card summarizes that completed-month distribution with the exact median
of all inclusive pairwise return averages. It fades only the statistic's sign
with opposite equal-target-notional XTI/XNG legs. The construction is
market-neutral-style, not proof of dollar, beta, volatility, factor, or
portfolio neutrality. Q02 owns density and economics; unchanged Q09 alone
owns realized overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The bounded packet is
`strategy-seeds/sources/VILLAR-HL-XTIXNG-MDAILY-RV-2026/source.md`, SHA-256
`994289DD1D32F02A560DF30E4D93B657CEDF13A09B4E2ECAA59ED45B49A14783`,
authorized by
`decisions/2026-08-29_xtixng_monthly_daily_hodges_lehmann_reversion_source_approval.md`
at commit `9d0b5563b` before extraction.

Villar/Joutz and Ramberg/Parsons supply a related but weak and state-dependent
oil/gas hypothesis plus binding adverse regime evidence. The governed method
packets supply exact inclusive-pair pseudomedian arithmetic and a synchronized
atomic monthly basket lifecycle. No source tests this exact XTI/XNG daily-
relative-return fade, Darwinex continuous CFDs, aggregate fixed-dollar risk,
or the QM book.

No source return, alpha, probability, significance, density, profit factor,
drawdown, transaction cost, hedge ratio, neutrality, CFD equivalence, or
correlation statistic transfers.

## Non-Duplicate Decision

The fail-closed checker scanned 4,691 registry identities, 1,342 cards, and 45
Strategy Wiki nodes. It found no exact identity and surfaced only expected
fuzzy method neighbor `QM5_20276_wti-hl-mom`. Receipt:
`artifacts/qm5_xtixng_mdaily_hl_rv_preallocation_dedup_20260829.json`, SHA-256
`5B26861A4B00C92C2F6479DBCEB4BF7CB6D23506EBF4DBA4C0544FDFBFBE2FD4`.

Manual family review fixes distinct functions:

- `QM5_20276` follows a pseudomedian of twelve disjoint monthly outright-WTI
  returns with one leg. This card fades a pseudomedian of 17-23 adjacent daily
  oil-minus-gas returns with two opposite legs.
- `QM5_41138_xauxag-mdaily-hl-rv` shares the arithmetic family but owns a
  gold/silver path under a precious-metal thesis and different contracts and
  costs. This card owns XTI/XNG energy relative value under oil/gas evidence.
- `QM5_41190_xtixng-mtheilsen-rv` takes all 78 forward time-normalized slopes
  between thirteen monthly ratio levels. This card takes 153-276 inclusive
  pairwise averages of daily relative returns from one completed month.
- XTI/XNG repeated-median, LAD, Mann-Whitney, Wilcoxon, Cox-Stuart, Spearman,
  Pettitt, median-runs, OLS, fixed-ratio, return-spread, calendar, and weekday
  cards use different states, clocks, estimators, or lifecycle rules.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

Verdict:
`CLEAN_XTIXNG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: `XTIUSD.DWX`; companion/traded slot 1: `XNGUSD.DWX`.
- Logical tester symbol: `QM5_41192_XTI_XNG_MDAILY_HL_RV_D1` on XTI host.
- Timeframe: D1; intended magics `411920000` and `411920001`.
- Decision: first synchronized executable D1 tick after a genuine broker-
  month transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: every synchronized daily relative return ending inside the
  immediately completed 17-23-session month plus one older boundary pair.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected cadence: approximately 10-12 packages/year; Q02 must prove at least
  five in every scored full year.

## Formula

Let `s[0]..s[n]` be synchronized completed log-ratio levels in chronological
order, where `s[0]` is the adjacent older boundary and `s[1]..s[n]` end inside
the immediately completed broker month:

```text
s[j] = ln(XTI_close[j]) - ln(XNG_close[j])
r[j] = s[j+1] - s[j], j=0..n-1
require 17 <= n <= 23
require sum(r) == s[n]-s[0] within 1e-10

k = 0
for i = 0..n-1:
  for j = i..n-1:
    w[k] = (r[i] + r[j]) / 2
    k += 1

m = n*(n+1)/2
require k == m and 153 <= m <= 276
sorted = ascending(w)
hl = sorted[m/2]                         when m is odd
hl = (sorted[m/2-1] + sorted[m/2]) / 2  when m is even

hl > 0: SELL XTI / BUY XNG
hl < 0: BUY XTI / SELL XNG
hl == 0 or invalid: consume month FLAT
```

Statistic magnitude never changes risk. The endpoint displacement is an
identity diagnostic only and never confirms or vetoes direction.

## Rules

These rules are the complete baseline. No endpoint-sign agreement, fixed
ratio, OLS, regression coefficient, z-score, slope, sign count, block vote,
sequence filter, season, event, inventory, curve, volume, optimizer artifact,
or external-data gate is authorized.

## 4. Entry Rules

1. Require exact EA ID `41192`, host `XTIUSD.DWX`, companion `XNGUSD.DWX`, D1,
   slots 0/1, and every baseline input locked to its declared value.
2. Process lifecycle repair before entry-only gates. Evaluate only at a
   genuine broker-month transition no later than 180 elapsed minutes after
   the raw host D1 bar open, with matching raw companion D1 bar time.
3. Persist current `yyyymm` as consumed before history, signal, news, spread,
   quote, ATR, sizing, margin, or order checks. No flat, rejected, failed,
   stopped, partial, or blocked outcome retries that month.
4. Reject owned exposure or any same-month entry deal for either magic.
5. Copy exactly 45 completed D1 bars per leg. Require exact timestamp matches.
   The newest completed pair must belong to the immediately prior month.
6. Select every pair in that completed month, require 17-23 unique timestamps,
   and require one adjacent older pair from the immediately preceding month.
   Reject current-month, missing, duplicate, nonchronological, or unmatched
   endpoints.
7. Reverse into chronological order, require positive finite closes, compute
   oil-minus-gas log ratios and every adjacent relative return ending inside
   the completed month, and verify endpoint identity within `1e-10`.
8. Enumerate every inclusive pair exactly once. Require every self-pair to
   reproduce its source return, exact dynamic count `n(n+1)/2`, finite values,
   ascending sort, and exact odd/even central indexes.
9. Fade the strict finite pseudomedian sign. Exact zero or invalid state
   consumes the month flat; raw displacement and magnitude never gate or size.
10. Require both spreads in bounds, executable quotes, completed
    `ATR(20,D1)`, valid symbol metadata, fixed-risk sizing, and realized target
    absolute-notional mismatch no greater than 20%.
11. Split aggregate fixed stop-risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no targets.
12. Submit XTI first and XNG second. Keep only one correctly directed,
    correctly registered, stop-protected position in each slot; otherwise
    flatten every owned leg immediately without retry.

## 5. Exit Rules

1. Close both legs on the first processed tick in every later broker month
   before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close every owned leg immediately if the package is orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, wrong-direction, missing a stop, or
   outside the 20% notional-mismatch tolerance.
4. Broker hard stops and framework kill switch remain authoritative.
5. Friday close is disabled because the approved hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, timeframe, EA ID, slots, fixed-risk,
  news/Friday contract, or locked strategy inputs.
- Reject consumed attempt, owned exposure, same-month entry history,
  malformed synchronization, wrong month boundary, current-month leakage,
  nonpositive/nonfinite close, invalid log ratio/return/identity/pair/median,
  wrong count, exact-zero statistic, excessive spread, invalid quote,
  unavailable ATR, invalid stop/volume, or notional mismatch.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  runs before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, forecast, trained output, optimizer result, portfolio
  state, live manifest, or prior pipeline result.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve original hard stops; close before monthly renewal or after forty
  days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- Lifecycle repair flattens every owned leg before any new entry logic when
  package validity fails.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xng_symbol` | XNGUSD.DWX | [XNGUSD.DWX] | exact companion and traded slot 1 |
| `strategy_history_bars_d1` | 45 | [45] | bounded completed-month reconstruction |
| `strategy_min_month_sessions` | 17 | [17] | exact lower observation bound |
| `strategy_max_month_sessions` | 23 | [23] | exact upper observation bound |
| `strategy_entry_grace_minutes` | 180 | [180] | maximum elapsed time after raw new-month host bar open |
| `strategy_max_pair_count` | 276 | [276] | exact storage cap for 23 inclusive pairs |
| `strategy_numerical_tolerance` | 1e-10 | [1e-10] | endpoint and self-pair identity tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator per leg |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_pct` | 20.0 | [20.0] | realized package-balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_xti_max_spread_points` | 1500 | [1500] | XTI entry spread ceiling |
| `strategy_xng_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Every value is a locked singleton. Changing the carrier, month, observation
bounds, pair convention, median, direction, clock, risk, stop, balance, hold,
spread, order sequence, or retry policy requires a new card and full pipeline
run.

## Author Claims

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
alongside weak, unstable, regime-dependent pricing and large gas-specific
variation. The governed method sources document exact pairwise-pseudomedian
and basket-lifecycle arithmetic. They do not claim that this rule works, that
the estimator is superior, that continuous CFDs reproduce their data, or that
the package diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Risk is high: both legs
can gap, oil and gas can structurally decouple, daily calendars can diverge,
volume rounding can create imbalance, and spreads and financing can dominate
a low-frequency edge. Equal target notionals are market-neutral-style, not
proof of market or portfolio neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on wrong synchronization, month order, current-month leakage, boundary
  omission, log-ratio orientation, return omission/duplication, endpoint
  identity, pair omission/duplication, wrong self-pair, count, sort, central
  indexes, median, sides, retry, non-atomic package, risk-mode breach, stop
  defect, hold beyond forty days, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing observation bounds, estimator, direction,
  carrier, risk, stop, balance tolerance, hold, spread cap, retry policy, or
  order sequence.

## Strategy Allowability Check

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK | Complete government and peer-reviewed oil/gas evidence with adverse regime findings plus complete governed method packets; exact daily pseudomedian translation risk remains explicit. |
| R2 | PASS | Fixed timestamps, month, boundary, returns, endpoint identity, inclusive pairs, dynamic count, sort, exact median, direction, attempt, aggregate risk, atomicity, and exits. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered XTIUSD.DWX and XNGUSD.DWX D1 histories plus native MT5 state supply every field; synchronization and continuous-CFD basis remain test risks. |
| R4 | PASS | Deterministic logarithms, finite pairwise arithmetic, sorting, calendar, and ATR risk controls; no trained model, prohibited signal, external feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact XTI/XNG/D1/EA/slots, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized completed-month
  reconstruction, exact pseudomedian, spread/quote/ATR/stop checks,
  equal-notional sizing, and atomic two-order package validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five packages per full post-warm-up
year, or nonpositive governed economics. Any current-month leakage, missing or
duplicate timestamp, boundary, return, pair, wrong ratio, count, sort, median,
side, retry, package, risk, stop, or determinism is an implementation failure,
not a tunable result.

Any change to carrier, observation bounds, synchronization, pair enumeration,
sort, median definition, direction, stop, spread caps, atomic sequence,
attempt lifecycle, symbol, timeframe, news/Friday mode, or risk mode requires
a new binary and full pipeline requalification. Realized diversification may
only be assessed at unchanged Q09; correlation failure receives no waiver.

## Safety Boundary

This card authorizes only governed magic allocation, one branch build, strict
compile/Q01, three D1 `RISK_FIXED` backtest setfiles (two registered legs and
one logical basket), and one paced non-live logical Q02 enqueue if CPU capacity
permits. It does not authorize a manual backtest; live, demo, shadow, stress,
or optimization setfile; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate mutation; portfolio admission; component-leg Q02 row; or
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-29 | initial XTI/XNG completed-month daily H-L reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-29 | APPROVED; R1-R4 PASS | `decisions/2026-08-29_qm5_41192_xtixng_monthly_daily_hodges_lehmann_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
