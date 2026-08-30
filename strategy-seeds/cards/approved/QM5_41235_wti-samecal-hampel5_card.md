---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026_S01
variant_id: KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026_S01
source_id: KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026
ea_id: QM5_41235
slug: wti-samecal-hampel5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41235_wti-samecal-hampel5_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41235_wti_same_calendar_hampel5_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_hampel5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Frank R. Hampel; Elvezio M. Ronchetti; Peter J. Rousseeuw; Werner A. Stahel; W. N. Venables; B. D. Ripley"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Frank R. Hampel; Elvezio M. Ronchetti; Peter J. Rousseeuw; Werner A. Stahel; W. N. Venables; B. D. Ripley"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; Hampel et al. (1986), Robust Statistics; Venables and Ripley (2002), Modern Applied Statistics with S; CRAN MASS psi.hampel documentation and source."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read parent packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_crude_oil_membership_and_five_year_floor
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read parent packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_wti_membership_own_return_direction_and_monthly_lifecycle
  - type: canonical_robust_statistics_reference
    citation: "Hampel, F. R., Ronchetti, E. M., Rousseeuw, P. J., and Stahel, W. A. (1986). Robust Statistics: The Approach Based on Influence Functions. Wiley."
    location: "Named Hampel reference in the author-maintained CRAN MASS rlm manual."
    quality_tier: A_method
    role: hampel_redescending_influence_function
  - type: primary_statistical_software_source
    citation: "Venables and Ripley, CRAN MASS rlm/psi.hampel documentation and MASS/R/rlm.R implementation."
    location: "https://stat.ethz.ch/CRAN/web/packages/MASS/MASS.pdf; https://rdrr.io/cran/MASS/src/R/rlm.R; read 2026-08-30"
    quality_tier: A_primary_software
    role: default_2_4_8_constants_piecewise_weights_iwls_and_local_minimum_warning
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar Hampel extraction."
    location: "strategy-seeds/sources/KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_five_sample_hampel_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-odd-median-mad-frozen-scale-hampel-two-four-eight-redescending-thirty-two-update-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/redescending-robust-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/five-sample-hampel-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, hampel-redescending, robust-location, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412350000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "Two complete-read peer-reviewed trading papers support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. A canonical robust-statistics reference plus author-maintained primary software fix the Hampel arithmetic. The exact five-sample fitted WTI conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, median/MAD indexes, frozen scale, exact 2/4/8 boundaries, piecewise weights, 32 updates, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history covers the required five-year warm-up and native MT5 state supplies every runtime input. Session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, sorting, absolute deviations, fixed piecewise reweighting, comparisons, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; odd median and raw MAD index 2; MAD normalizer 1.4826; Hampel boundaries a=2, b=4, c=8; frozen scale; exact boundary inclusions; exactly 32 updates; strict absolute location above 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, odd median/MAD, frozen scale, exact 2/4/8 Hampel boundaries, piecewise weights, exact update count, sign, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, chronological_return_orientation, median_index_two, mad_index_two, mad_normalizer_1_4826, frozen_scale, hampel_a_2, hampel_b_4, hampel_c_8, exact_boundary_inclusion, positive_total_weight, exactly_32_updates, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41235_wti_same_calendar_hampel5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages, canonical robust-statistics and primary-software Hampel records, and explicit robust-location/CFD translation risk; R2 locks calendar, endpoints, exact sample, median/MAD, frozen scale, 2/4/8 boundaries, weights, update count, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found expected same-calendar family neighbors, and a fixed fixture proves opposite direction versus mean, median, bisquare, Gastwirth, and Harrell-Davis siblings."
---

# QM5_41235 WTI Same-Calendar Five-Sample Hampel Location

## Hypothesis

WTI production, storage, transport, refining, hedging, and demand pressures can
recur in the same named calendar month. A raw cross-year mean can be controlled
by one oil shock, while a median discards all distance information and a Huber
score never fully rejects a finite tail. This card tests whether the exact
five-year same-calendar signal is more useful under Hampel's frozen-scale,
piecewise redescending influence function.

The direct WTI carrier and recurring monthly clock target exposure outside the
certified XAU/SP500/NDX/XNG set. That construction does not prove low
correlation, profitability, or CFD/futures equivalence. Q02 owns activity and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026/source.md`,
SHA-256
`06E612479CA3D5DB44EFA3638C3AD81CBD8BBC6C50A3653751348ABB0D12DE37`,
committed as `e582e23ff`. Candidate-specific source approval is
`decisions/2026-08-30_wti_same_calendar_hampel5_source_approval.md`, SHA-256
`B50A98B25408A5FD6309DE7D6502650D4F3F9CE1CBC51B474EA4AEF8F109D02C`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen supply explicit WTI membership,
own-return direction, and monthly renewal. Hampel et al. and the maintained
CRAN `MASS` records fix a reproducible redescending weight convention. None
tests this exact five-sample seasonal conjunction, continuous CFD, or
execution contract.

No source or sibling return, alpha, significance, profit factor, drawdown,
trade count, cost, WTI-only result, CFD equivalence, or correlation statistic
transfers. The robust statistic, epsilon, fixed risk, stop, spread, and
lifecycle are pre-result QM falsification choices.

## Formula

At broker-month decision `(Y,M)`, reconstruct the completed log return for
calendar month `M` in each exact year `Y-5..Y-1`. Keep original returns in
chronological order and sort only copies:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]
scale  = 1.4826 * MAD

mu[0] = median
for j = 0..31:
  u[i] = (r[i] - mu[j]) / scale
  U[i] = abs(u[i])

  w[i] = 1                                  if U[i] <= 2
         2/U[i]                             if 2 < U[i] <= 4
         2*(8-U[i])/(4*U[i])                if 4 < U[i] < 8
         0                                  if U[i] >= 8

  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])

mu[32] > +1e-12 => BUY XTIUSD.DWX
mu[32] < -1e-12 => SELL XTIUSD.DWX
otherwise        => FLAT
```

Reject nonpositive or nonfinite MAD, scale, weight sum, or intermediate
location. Freeze scale before the first update and execute all 32 updates.
`U=2` has weight one, `U=4` has weight one half, and `U=8` has weight zero.
No early stop, alternate start, observation replacement, return deletion,
fallback center, scale refit, magnitude sizing, or alternate location is
authorized.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_hampel5_preallocation_dedup_20260830.json`,
SHA-256
`21A13A996AC51D7DF59C019A5333463D71A6F9FE68CFE7CADB8AD517088E6AD9`,
found no exact identity across 4,734 registry identities, 1,372 cards, and 45
Strategy Wiki nodes. It returned expected same-calendar fuzzy neighbors.

- `[-0.050,-0.005,+0.002,+0.005,+0.080]` makes this card sell from final
  Hampel location approximately `-0.00580512`.
- On the same fixture, the raw mean, ordinary median, five-sample bisquare,
  Gastwirth, Harrell-Davis, trimmed-mean, Winsorized-mean, and trimean
  locations are positive and buy; the midhinge is flat.
- Sign reflection reverses each strict mapping.
- `QM5_41204_wti-samecal-huber10` requires ten years and retains positive
  finite-tail influence. This card requires five and reaches exact zero tail
  weight under fixed `2/4/8` boundaries.
- `QM5_41231_wti-samecal-bisquare5` uses a smooth squared compact-support
  curve. Hampel's unit, plateau-decay, linear-redescending, and zero regions
  produce the opposite fixture side.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_HAMPEL_248_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, intended magic
  `412350000`.
- Decision clock: first executable host tick after a genuine normalized
  broker-month transition.
- Formation: exact matching month in `Y-5..Y-1`; all five returns mandatory.
- Hold: next genuine broker-month boundary; 40 days is survivor repair only.
- Expected cadence after warm-up: approximately ten to twelve positions/year;
  Q02 retires below five in any full scored year.
- Runtime: native D1 history and MT5 execution state only.

## Rules

The following sections are the complete locked baseline. There is no
optimization surface and no result-conditioned alternative.

## 4. Entry Rules

1. Require exact EA ID `41235`, exact `XTIUSD.DWX` D1 host, slot 0,
   registered magic, locked inputs, fixed-risk mode, both current news axes
   OFF, legacy news OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Accept one uniform native or `+1` energy D1-label convention. Require the
   normalized current host D1 date to equal broker date and apply the same
   offset to every historical endpoint.
4. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry after any outcome.
5. Reconstruct calendar month `M` in exact years `Y-5..Y-1`. Require strict
   adjacent-month completed endpoints, confirming following bars, positive
   finite closes, and all five returns. No substitute year is allowed.
6. Sort a copy of exactly five returns and read median index `2`. Sort their
   five absolute deviations from that median and read raw MAD index `2`.
   Reject nonpositive or nonfinite MAD.
7. Freeze `scale=1.4826*MAD`. Starting at the median, execute exactly 32
   updates over the original five returns using the locked `2/4/8` Hampel
   weights and exact boundary inclusions. Reject a nonpositive or nonfinite
   total weight or location at any update.
8. Buy above `+1e-12`, sell below `-1e-12`, and consume flat inside the
   inclusive epsilon band. Magnitude never changes risk.
9. Require no owned exposure or same-month entry deal, a finite non-crossed
   quote, spread in `[0,1500]` points, completed ATR(20,D1), normalized stop,
   valid volume metadata, and sufficient margin.
10. Apply exactly `RISK_FIXED=1000`, attach a frozen
    `3.5 * ATR(20,D1)` broker stop, and use no target.
11. Open at most one WTI position. Any submission or final-composition defect
    is repaired by closing every owned position.

## 5. Exit Rules

1. At the first processed host D1 bar of the next normalized broker month,
   close the old position before evaluating a replacement.
2. Close after 40 elapsed calendar days as final survivor repair.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time owned exposure.
4. The broker hard stop, framework kill switch, and framework close helper
   remain authoritative.
5. Friday close is disabled because the structural monthly hold spans
   weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

## 6. Filters (No-Trade Module)

- Wrong host, period, EA ID, slot, risk mode, locked input, label convention,
  endpoint, exact-year sample, median, MAD, scale, boundary, weight, update
  count, epsilon, quote, spread, ATR, sizing, margin, or order state consumes
  the persisted month.
- Both current news axes and legacy news are OFF; no external calendar or feed
  is consulted. Lifecycle repair is never delayed by entry gates.
- Current-month OHLC/volume, contiguous recent momentum, fixed-month
  direction, curve, storage, inventory, event, or portfolio state may not
  enter.

## 7. Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Malformed, cross-month, and stale repair runs before entry-only gates and
  remains retryable until owned exposure is flat.
- Maintain at most one exact-symbol, exact-magic WTI position; never manage a
  manual or another EA's trade.
- The entry hard stop never moves. Signal changes do not alter an open
  position inside the month.
- Persist the consumed-month ledger in terminal-global state so restart
  cannot create a second attempt. Tester initialization clears stale
  prior-run state.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_mad_normalizer` | 1.4826 | frozen raw-MAD scale |
| `strategy_hampel_a` | 2.0 | unit-weight boundary |
| `strategy_hampel_b` | 4.0 | plateau/decline boundary |
| `strategy_hampel_c` | 8.0 | zero-weight boundary |
| `strategy_hampel_steps` | 32 | exact re-centering count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No endpoint, sample, statistic, constant, boundary, update, epsilon,
direction, stop, hold, spread, or lifecycle sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen broker hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop distance, tick value, tick size, volume step, minimum
  volume, lot, margin, or quote consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Runtime Data Dependencies

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, symbol quotes and
properties, positions, deals, and terminal-global attempt state only. No
contract chain, curve, inventory, storage, volume, open interest, event feed,
API, CSV, optimizer artifact, trained output, or manual signal input.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, fixed-risk sizing, magic resolution, MAE tracking,
  and owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch or close-only instruction.
2. Duplicate, wrong-symbol, wrong-side, stopless, or invalid-metadata repair.
3. Per-position broker hard stop.
4. New normalized broker-month exit.
5. Forty-day survivor repair.
6. New entry only when flat and the current month is not already consumed.

## Framework Alignment

| Card rule | V5 module | Required implementation |
|---|---|---|
| exact host, D1, EA, slot, risk and locked contract | no_trade | fail closed before signal entry |
| normalized month clock and persistent attempt | no_trade / trade_entry | consume once before fallible gates |
| exact-year endpoint reconstruction | trade_entry | bounded completed D1 history only |
| median/MAD and fixed-step Hampel location | trade_entry | deterministic native arithmetic |
| fixed-risk sizing and frozen stop | trade_entry | framework sizing and market request |
| malformed, month, and stale exits | management / close | close owned position only |
| no target, trail, partial, or intramonth signal exit | management | no optional management path |
| news and Friday overrides | no_trade / close | all news OFF; Friday close OFF |

## Reputable-Source Gate Findings

- R1: `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS`; five-year warm-up, session-label, and continuous-futures/CFD
  basis risks remain binding Q02 falsification items.
- R4: `PASS`; structural native arithmetic only.

## Falsification And Requalification

Retire or fail on wrong calendar endpoints, current-month leakage, missing
exact years, incorrect return orientation, median/MAD/scale defect, mutable
scale, wrong `2/4/8` boundary inclusion, wrong weight, update count other than
32, zero-weight fallback, wrong sign, fewer than five positions in any full
post-warm-up scored year, nonpositive governed economics, repeated attempts,
missing stop, wrong lifecycle, invalid fixed risk, or nondeterminism. No
post-result change to the sample, statistic, constants, direction, carrier,
stop, spread, hold, or retry policy is allowed.

Passing Q02 would establish only executable baseline evidence. It would not
establish certification, source replication, futures/CFD equivalence,
profitability outside the tested window, or portfolio diversification. Q09
alone may test realized overlap with the existing book.

## Change History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial WTI same-calendar five-sample Hampel card | G0 | APPROVED; build pending |

## Approvals

| Gate | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-30 | APPROVED_SOURCE | `decisions/2026-08-30_wti_same_calendar_hampel5_source_approval.md` |
| G0 Research Intake | 2026-08-30 | APPROVED | `decisions/2026-08-30_qm5_41235_wti_same_calendar_hampel5_g0.md` |
| Q01 Static / Compile | 2026-08-30 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline | 2026-08-30 | NOT_ENQUEUED_Q01_PENDING | compile and governed CPU check pending |

## Safety Boundary

This card authorizes one branch-only non-live V5 build, strict compile/Q01,
one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue subject to the CPU
ceiling. It does not authorize a manual tester run, live/demo/shadow/stress/
optimization presets, AutoTrading, `T_Live`, deploy or T_Live manifests,
portfolio-gate edits, portfolio admission, decorrelation claims, or
correlation waivers.
