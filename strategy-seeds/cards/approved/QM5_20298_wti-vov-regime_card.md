---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-VOV-2021_XTI_TS_S03
variant_id: HOLLSTEIN-VOV-2021_XTI_TS_S03
source_id: HOLLSTEIN-WTI-VOV-REGIME-2026
ea_id: QM5_20298
slug: wti-vov-regime
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20298_wti-vov-regime_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete-paper evidence strategy-seeds/sources/HOLLSTEIN-VOV-2021/source.md; bounded extraction strategy-seeds/sources/HOLLSTEIN-WTI-VOV-REGIME-2026/source.md"
    quality_tier: A
    role: primary_vov_formula_low_minus_high_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-two-disjoint-252-by-20d-realized-volatility-of-volatility-blocks-self-relative-low-minus-high-regime
sources:
  - "[[sources/HOLLSTEIN-WTI-VOV-REGIME-2026]]"
concepts:
  - "[[concepts/volatility-of-volatility-premium]]"
  - "[[concepts/uncertainty-regime]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/realized-volatility-of-volatility]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-uncertainty-premium, realized-volatility-of-volatility, self-relative-regime, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202980000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve completed monthly WTI positions/year after 543 completed D1 closes; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED_BUILD_PENDING
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright WTI monthly uncertainty premium whose two disjoint own-history realized-VoV blocks differ from paired energy/metal VoV ranks, raw-volatility fades, return trend/reversal, calendar, variance-ratio, event, and XNG RSI logic; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_d1_history, exact_disjoint_block_support, inner_sample_variance, outer_population_variance, self_relative_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, implied_realized_proxy, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20298_wti_vov_regime_g0.md: R1 tier-A peer-reviewed complete-read source with exact VoV transform, robust negative direction, and WTI membership; R2 locked 20-return/252-sample nested estimator over offsets 0 and 271, self-relative low-minus-high direction, consumed month, stop, rollover, and stale guard; R3 registered WTI D1 route; R4 deterministic native arithmetic. No exact identity across 4,363 registry rows and 474 cards; nine expected source-family fuzzy neighbors were manually resolved. Implied-to-realized and cross-sectional-to-time-series transfers plus the parent energy carrier's Q08 failure are explicit kill risks."
---

# QM5_20298 WTI Self-Relative Realized-VoV Regime

## Hypothesis

Uncertainty about WTI risk can itself vary in slow regimes as production,
inventory, transport, refining, hedging, policy, and demand conditions change.
If the source's low-VoV premium has a price-native time-series analogue, WTI
may earn a positive premium when the instability of its rolling realized
volatility falls below its preceding state and a negative premium when that
instability rises above its preceding state.

WTI adds a crude-oil carrier absent from the certified XAU/SP500/NDX/XNG book.
That carrier and signal difference do not prove decorrelation, profitability,
or portfolio suitability. Q02 owns density and economics; unchanged later
gates, especially Q09, own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The source of record is the bounded packet
`strategy-seeds/sources/HOLLSTEIN-WTI-VOV-REGIME-2026/source.md`. Its governed
parent records the complete accepted article and online appendix for
Hollstein, Prokopczuk, and Tharann (2021), a peer-reviewed *Quarterly Journal
of Finance* article. The source defines option-implied VoV from 252 daily
observations, reports a negative high-minus-low commodity relation including
in a two-portfolio robustness split, renews monthly, and includes WTI.

The source does not test realized VoV, two own-history blocks, an outright WTI
rule, a continuous CFD, fixed-dollar risk, ATR stops, or the QM book. The
implied-to-realized proxy and cross-sectional-to-time-series comparison are
material translations. No source return, alpha, significance, WTI-only
effect, drawdown, cost, trade count, CFD equivalence, or correlation transfers.

The source's later subperiod evidence is weaker. The paired price-native
parent `QM5_13146_energy-vov` later failed Q08. Both facts are adverse evidence,
not waivers or reasons to alter this locked falsification.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,363 registry rows and 474 root
cards. It found no exact identity and returned nine expected lexical/source-
family fuzzy matches. Manual review separates them:

- `QM5_13146_energy-vov` ranks concurrent XTI against XNG VoV and manages a
  two-leg package; this candidate compares two disjoint WTI history blocks and
  manages one outright leg.
- `QM5_20236_xauxag-vov-rank` is a paired precious-metal carrier.
- `QM5_13046_xti-vrp-proxy` gates a stretch fade with realized-volatility
  level rather than measuring dispersion along rolling volatility.
- `QM5_20249_xauxag-vr-spread` uses variance ratios, not VoV.
- `QM5_20295_wti-kurt-prem` uses a centered fourth return moment around three,
  not nested rolling-volatility instability or a two-block comparison.
- WTI trend, location, calendar, event, variance-ratio, breakout, and reversal
  builds use other state objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only RSI pullback.

The 20-return inner window, 252 overlapping RV samples in each block, exact
sample/population denominators, division by mean RV, disjoint offsets `0/271`,
self-relative low-minus-high direction, outright WTI topology, and consumed
monthly attempt are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_SOURCE_FAMILY_FUZZY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot 0, intended magic
  `202980000`.
- Decision: first processed D1 bar after a genuine broker-month transition.
- Formation: exactly 543 completed D1 closes, newest first; newest endpoint
  must predate the decision bar and be at most ten calendar days stale.
- Hold: until the next broker-month transition, bounded by forty days.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five.

For block offset `b`, calculate:

```text
r[b,s,k] = ln(close[b+s+k] / close[b+s+k+1]), k=0..19
rv[b,s]  = sample_std(r[b,s,0..19], denominator 19) * sqrt(252), s=0..251
mean_rv[b] = average(rv[b,0..251])
vov[b] = sqrt(sum((rv[b,s] - mean_rv[b])^2) / 252) / mean_rv[b]

recent offset b=0:     return indices 0..270
preceding offset b=271: return indices 271..541
```

Buy when recent VoV is below preceding VoV by more than `1e-12`; sell when it
is above by more than `1e-12`; consume the month flat on a tie or invalid state.

## Rules

These are the complete baseline rules. There is no parameter sweep, implied-
data fallback, volatility-level substitute, trend/calendar overlay, fitted
threshold, direction flip, or post-result repair.

## 4. Entry Rules

1. Require EA ID 20298, exact `XTIUSD.DWX` D1 host, slot 0, and every locked
   input.
2. Process lifecycle exits before entry-only gates and evaluate only on a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, ATR, sizing, or order checks. No outcome retries that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Load exactly 543 completed rates. Require a completed/fresh endpoint,
   strictly older timestamps by series index, and positive finite closes.
6. Form each of the two disjoint blocks exactly. Require 20 finite log returns
   per RV sample, sample variance denominator 19, 252 positive RV values,
   population dispersion denominator 252, positive mean RV, and finite VoV.
7. Buy when `recent_vov < preceding_vov - 1e-12`; sell when
   `recent_vov > preceding_vov + 1e-12`; a tie consumes the month flat.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, and valid contract metadata.
9. Open at most one market position with one frozen `3.5 * ATR(20,D1)` broker
   hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of each new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop owned state.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the monthly hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA, slot, fixed-risk,
  news/Friday contract, or locked inputs.
- Reject consumed attempts, owned exposure, same-month entry history, wrong
  history count, stale endpoint, non-decreasing chronology, nonpositive close,
  overlapping/wrong block support, invalid return/variance/RV/mean/VoV, tie,
  excessive spread, invalid quote, unavailable ATR, invalid stop, or invalid
  contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read an option or futures chain, inventory release, volume,
  open interest, file, API, analyst forecast, trained output, optimizer result,
  or portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly replacement or after
  forty days.
- Restart recovery combines a terminal-persistent month marker with position
  and deal history; tester initialization clears a future/prior-run marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_rv_window_d1` | 20 | [20] | log returns per RV sample |
| `strategy_vov_samples` | 252 | [252] | RV observations per VoV block |
| `strategy_prior_block_offset` | 271 | [271] | first preceding-block return index |
| `strategy_history_bars_d1` | 543 | [543] | exact completed-close count |
| `strategy_max_endpoint_gap_days` | 10 | [10] | endpoint freshness |
| `strategy_vov_tolerance` | 1e-12 | [1e-12] | symmetric tie boundary |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, offsets, denominators, direction, entry clock, risk, stop, hold,
and no-retry policy are locked. Any change requires a new card and pipeline.

## Author Claims

Hollstein, Prokopczuk, and Tharann define option-implied VoV, report a negative
high-minus-low commodity relation, use monthly renewal, and include WTI. They
do not claim that realized VoV, this two-block WTI rule, a continuous CFD, or
the candidate's diversification objective works.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: implied/realized substitution, broad-sort
to time-series transfer, overlapping RV estimates within blocks, persistent
states, WTI gaps and rolls, CFD basis and financing, two-year warm-up, hard-
stop slippage, and correlation with XNG or risk assets can dominate the
premise. The parent realized-VoV carrier's Q08 failure lowers the prior.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong history count, timestamp orientation, block support, inner or
  outer denominator, mean normalization, overlap between return blocks,
  reversed direction, repeated attempt, hold beyond forty days, missing hard
  stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the estimator, offsets, threshold,
  direction, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, institutional complete-read record, exact transform, robustness caveats, and WTI membership. |
| R2 | PASS | Fixed nested estimator, disjoint blocks, direction, attempt, stop, rollover, and stale guard. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 and native V5 execution state suffice for the disclosed proxy. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; all expected fuzzy neighbors manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap guards.
- trade_entry: month-attempt persistence, exact 543-rate history, two nested
  VoV blocks, self-relative direction, spread/quote/ATR/stop checks, and one
  fixed-risk order.
- trade_management: malformed-state repair, broker-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one paced non-live Q02 handoff. It excludes manual backtests;
live, demo, shadow, stress, or optimization setfiles; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate edits; portfolio admission; and
correlation waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial source-bounded WTI self-relative realized-VoV regime | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20298_wti_vov_regime_g0.md`; bounded source packet |
| Q01 Build Validation | - | PENDING_BUILD | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |
