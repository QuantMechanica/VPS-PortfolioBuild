---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026_S01
variant_id: KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026_S01
source_id: KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026
ea_id: QM5_41233
slug: wti-samecal-gast5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41233_wti-samecal-gast5_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41233_wti_same_calendar_gastwirth5_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_gastwirth5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Joseph L. Gastwirth"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Joseph L. Gastwirth"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; Gastwirth (1966), On Robust Procedures, JASA 61(316), DOI 10.1080/01621459.1966.10482185; GNU Scientific Library 2.8 Statistics documentation."
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
  - type: peer_reviewed_statistics_paper
    citation: "Gastwirth, J. L. (1966). On Robust Procedures. Journal of the American Statistical Association 61(316), 929-948."
    location: "DOI 10.1080/01621459.1966.10482185"
    quality_tier: A
    role: named_robust_location_procedure_lineage
  - type: official_numerical_documentation
    citation: "GNU Scientific Library 2.8, Statistics: Median and Percentiles; Gastwirth Estimator."
    location: "https://www.gnu.org/software/gsl/doc/html/statistics.html; completely read 2026-08-30"
    quality_tier: official_implementation_documentation
    role: exact_linear_quantile_interpolation_and_gastwirth_weights
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar Gastwirth extraction."
    location: "strategy-seeds/sources/KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_five_sample_quantiles_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-gsl-linear-one-third-half-two-third-quantiles-gastwirth-three-tenths-four-tenths-three-tenths-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/gastwirth-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, gastwirth-location, robust-location, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
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
magic: 412330000
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
r1_reasoning: "Two complete-read peer-reviewed trading papers support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. A named JASA source plus official GNU documentation fix the robust location and numerical convention. The exact five-sample WTI conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, sort, GSL one-third/half/two-third interpolation, 0.3/0.4/0.3 aggregation, simplified invariant, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered XTIUSD.DWX D1 history covers the required five-year warm-up and native MT5 state supplies every runtime input. Session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, sorting, fixed linear interpolation, weighted sums, comparisons, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; ascending sort; GSL linear quantiles at 1/3, 1/2, 2/3; Gastwirth weights 0.3, 0.4, 0.3; simplified 0.2, 0.6, 0.2 invariant within 1e-12; strict absolute location above 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED_CAPACITY_CHECK_PENDING
force_build: true
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, ascending order, GSL quantile interpolation, Gastwirth aggregation and invariant, sign, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, chronological_return_orientation, ascending_sort, gsl_linear_quantile_type, one_third_quantile, median_quantile, two_thirds_quantile, gastwirth_weights, simplified_invariant, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41233_wti_same_calendar_gastwirth5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages, a named JASA robust-procedures source, official GNU numerical documentation, and explicit estimator/CFD translation risk; R2 locks calendar, endpoints, exact sample, sort, quantiles, weights, invariant, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found one expected same-calendar family neighbor, and fixed disagreement fixtures prove semantic non-equivalence to mean, median, trim, Winsor, trimean, midhinge, and MAD-cap siblings."
---

# QM5_41233 WTI Same-Calendar Five-Sample Gastwirth Location

## Hypothesis

WTI production, storage, transport, refining, hedging, and demand pressures can
recur in the same named calendar month. A raw cross-year mean can be controlled
by one oil-shock year, while a median discards useful spacing around the
center. This card tests whether an exact five-year same-calendar signal is more
useful when estimated by Gastwirth's fixed robust combination of the one-third,
median, and two-third sample quantiles.

The direct WTI carrier and recurring monthly clock target exposure outside the
certified XAU/SP500/NDX/XNG set. That construction does not prove low
correlation, profitability, or CFD/futures equivalence. Q02 owns activity and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026/source.md`,
SHA-256
`D5A6186CDD5944B62B7B364F6A6C326888ED5F8BC3B3EE3F9007C0B408B28692`.
The durable source approval is
`decisions/2026-08-30_wti_same_calendar_gastwirth5_source_approval.md`,
committed as `04322a80a`; the bounded extraction was committed as `9608e3422`.

Keloharju, Linnainmaa, and Nyberg support recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen support WTI own-return direction
and monthly renewal. Gastwirth supplies the named robust-procedure lineage,
while official GNU Scientific Library documentation fixes the estimator and
finite-sample quantile interpolation. No source tests this exact five-return
single-CFD conjunction.

The five-year sample, single-WTI zero comparison, GSL interpolation choice,
continuous CFD, fixed risk, ATR stop, spread ceiling, and lifecycle are
pre-result QM mechanizations. No source performance, WTI-only alpha, cost,
drawdown, correlation, or CFD equivalence transfers.

## Formula

At a genuine normalized broker-calendar transition to year `Y`, month `M`,
load the completed WTI log return for calendar month `M` in each exact year
`Y-5..Y-1`. Sort only a copy as `s[0] <= ... <= s[4]`.

For each `f` in `{1/3, 1/2, 2/3}`, use the exact GSL interpolation:

```text
h     = (5 - 1) * f
i     = floor(h)
delta = h - i
Q(f)  = (1 - delta) * s[i] + delta * s[i+1]

Q(1/3) = (2*s[1] + s[2]) / 3
Q(1/2) = s[2]
Q(2/3) = (s[2] + 2*s[3]) / 3

location = 0.3*Q(1/3) + 0.4*Q(1/2) + 0.3*Q(2/3)
invariant = 0.2*s[1] + 0.6*s[2] + 0.2*s[3]

location > +1e-12 => BUY XTIUSD.DWX
location < -1e-12 => SELL XTIUSD.DWX
otherwise         => consume the month flat
```

All five returns are mandatory and every intermediate must be finite. The
direct computation and simplified invariant must agree within `1e-12`. No
alternate quantile type, endpoint fallback, shorter sample, refit, iteration,
scale estimate, magnitude sizing, or adaptive runtime parameter is authorized.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_gast5_preallocation_dedup_20260830.json`, SHA-256
`C9ADEE43102AC02EDE2BFCD5891EA639A115D59658DF730B9F1A899F0B120F17`,
found no exact identity across 4,732 registry rows, 1,370 cards, and 45 wiki
nodes. Its only fuzzy match is the expected raw-mean family neighbor
`QM5_20099_wti-samecal`.

- `[-0.30,-0.28,+0.02,+0.24,+0.26]` gives this rule `+0.004` and BUY. Raw
  mean, middle-three trim, and inactive MAD-cap siblings SELL; trimean is FLAT.
- `[-0.20,-0.15,+0.04,+0.05,+0.06]` gives this rule `+0.004` and BUY. The
  equal-weight trim is `-0.02`, trimean `-0.005`, midhinge `-0.05`, and
  endpoint-Winsor mean `-0.032`; those siblings SELL.
- `[-0.25,-0.20,+0.01,+0.04,+0.05]` gives this rule `-0.026` and SELL while
  the ordinary median BUYs. Sign reflection reverses every strict mapping.
- Existing same-calendar mean, median, trim, endpoint Winsor, block median,
  shortest-half, trimean, midhinge, pseudomedian, Huber, bisquare, and MAD-cap
  EAs do not combine GSL one-third/half/two-third quantiles with fixed
  `0.3/0.4/0.3` aggregation.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_GSL_GASTWIRTH_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX` only, D1, symbol slot 0.
- Decision cadence: first executable D1 tick after a genuine normalized broker
  month transition.
- Formation: exact completed matching calendar month in `Y-5..Y-1`.
- Hold: until the next normalized broker-month boundary; 40 elapsed calendar
  days is survivor repair only.
- Expected frequency: approximately 10-12 completed positions per full
  post-warm-up year; fewer than five in any full scored year is a Q02 kill.

## Rules

### 1. Calendar And History

1. Accept only exact chart identity `XTIUSD.DWX`, D1, `qm_ea_id=41233`, and
   slot offset zero.
2. Normalize the copied D1 buffer under one uniform convention: native labels
   when at least two broker months are present, otherwise the tested `+1`
   energy-label rule. Mixed endpoint repair is forbidden.
3. Require the normalized current D1 date to equal broker date. Detect a
   genuine new `(year,month)` key and do not treat EA attachment mid-month as
   a transition.
4. Persist current `yyyymm` before history, signal, news, quote, spread, ATR,
   sizing, or submission. Never retry the month.
5. For every exact year `Y-5..Y-1`, require the last D1 close of month `M`, the
   last close of its immediately preceding calendar month, and a later D1 bar
   confirming completion. Missing or invalid history consumes the month flat.

### 2. Entry Rules

1. Close malformed owned exposure and the previous monthly package before any
   entry-only gate.
2. Compute exactly five finite log returns and sort a copy ascending.
3. Compute GSL linear `Q(1/3)`, `Q(1/2)`, and `Q(2/3)`, then the exact
   `0.3/0.4/0.3` Gastwirth sum. Verify the simplified `0.2/0.6/0.2` central
   order-statistic invariant within `1e-12`.
4. A location strictly above `+1e-12` requests BUY. A location strictly below
   `-1e-12` requests SELL. The inclusive band stays flat.
5. Reject nonpositive quotes, negative/crossed spread, and a genuinely positive
   spread above 1,500 points. Zero modeled `.DWX` spread is allowed.
6. Require completed-bar `ATR(20,D1)>0`; attach one frozen hard stop exactly
   `3.5*ATR` from the selected executable quote and no take-profit.
7. Size through the framework using the one-package `RISK_FIXED=1000` budget.
   Open at most one exact-symbol, exact-magic position and do not retry a failed
   submission.

### 3. Exit Rules

1. At the first later genuine normalized broker-month boundary, close the owned
   package before considering a replacement entry.
2. Close any survivor after 40 elapsed calendar days from owned-position open
   time. This is a repair, not the normal hold.
3. Close duplicate owned exposure and any wrong-symbol, invalid-side,
   wrong-magic, or stopless owned state immediately.
4. Otherwise preserve the original broker hard stop and return no discretionary
   signal exit. Do not trail, break even, partially close, or reverse intramonth.

### 4. Filters (No-Trade Module)

- Enforce exact EA ID, symbol, timeframe, slot, fixed-risk mode, finite locked
  inputs, both current news axes OFF, legacy news OFF, and Friday close OFF.
- Framework kill switch, disconnect, and execution safety remain active.
- History, signal, quote, spread, ATR, and sizing failures consume the already
  persisted monthly attempt; they never create a retry.

### 5. Trade Management Rules

- Maintain zero or one exact-symbol, exact-magic position.
- Preserve the broker hard stop and validate owned state on every management
  pass, including through news windows.
- No target, trail, break-even, scale-in, partial exit, grid, martingale,
  pyramid, portfolio input, external file, or runtime API.

## Parameters To Test

Q02 receives one locked baseline and no optimization surface:

| Input | Value | Contract |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_gastwirth_lower_weight` | 0.3 | one-third quantile weight |
| `strategy_gastwirth_median_weight` | 0.4 | median quantile weight |
| `strategy_gastwirth_upper_weight` | 0.3 | two-third quantile weight |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band and invariant tolerance |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Changing the sample, quantile convention, weights, sign, carrier, stop, hold,
spread, or attempt logic creates a different hypothesis and is not a rescue.

## Risk

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each entry has one frozen `3.5*ATR(20,D1)` broker hard
stop and no target. Both news axes and legacy mode are OFF; Friday close is OFF
because the structural monthly hold spans weekends.

The strategy can lose the complete fixed package budget on gaps or slippage,
and continuous-CFD roll/financing behavior can invalidate the futures-derived
hypothesis. No portfolio or correlation claim is approved.

## Runtime Data Dependencies

Only registered `XTIUSD.DWX` D1 OHLC/timestamps, broker time, quotes, spread,
ATR, symbol metadata, positions, deals, and framework/terminal state are
allowed. No futures curve, inventory, storage, volume, open interest, COT,
news file, external API, trained state, prior pipeline result, or portfolio
state may enter the signal.

## Framework Execution Overrides

- Framework Friday flattening: disabled.
- News temporal/compliance axes and legacy mode: locked OFF.
- Entry cadence: strategy-owned persistent normalized month attempt because
  one-time calendar history reconstruction must survive restart without retry.
- Position management and malformed-state repair remain active through news
  and other entry-only gates.

## Exit Precedence

1. Framework kill switch and hard safety.
2. Malformed or duplicate owned-state repair.
3. Later normalized broker-month boundary.
4. Forty-day survivor repair.
5. Broker hard stop.
6. Otherwise hold; no discretionary signal exit.

## Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact identity, host, risk, modes, and inputs | `Strategy_NoTradeFilter` |
| normalized month and completed endpoints | calendar and endpoint helpers |
| exact sample, sort, GSL quantiles, Gastwirth sum, invariant | signal helpers called by `Strategy_EntrySignal` |
| durable attempt before fallible gates | decision preparation helper |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_ManageOpenPosition` helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| news mode assertion | `Strategy_NewsFilterHook` |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, endpoint completion, exact
years, sort, GSL interpolation, weights, simplified invariant, epsilon,
disagreement fixtures, durable attempts, spread boundaries, lifecycle,
registry resolution, card identity, sole setfile, static guardrails, and strict
zero-error/zero-warning compilation.

## Reputable-Source Gate Findings

| Gate | Verdict | Finding |
|---|---|---|
| R1 | PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK | Two complete peer-reviewed trading lineages, a named JASA robust-procedures paper, and official GNU numerical documentation; exact conjunction untested. |
| R2 | PASS | Calendar, endpoints, sample, sort, quantiles, weights, invariant, side, attempt, risk, and lifecycle locked. |
| R3 | PASS_WITH_FIVE_YEAR_WARMUP_AND_CFD_BASIS_RISK | Registered WTI D1 and native MT5 state suffice; roll, financing, label, gap, and basis risks bind. |
| R4 | PASS | Deterministic native arithmetic and execution state only; no ML, banned indicator, or external runtime feed. |

## Falsification And Requalification

Q02 retires this card on zero positions, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, bad endpoint
normalization, missing exact year, wrong quantile type, wrong weights, failed
invariant, current-month leakage, wrong side, retry, missing stop, lifecycle
defect, nondeterminism, or invalid risk mode. No after-result change to the
statistic or contract is permitted.

Only unchanged Q09 may determine realized correlation or portfolio value.

## Change History

| Version | Date | Reason | Status |
|---|---|---|---|
| v1 | 2026-08-30 | initial WTI exact-five-year same-calendar Gastwirth card | G0 APPROVED; Q01 pending |

## Approvals

- Source: `APPROVED_SOURCE` under the explicit OWNER mission, committed before
  extraction as `04322a80a`.
- G0: `APPROVED` by
  `decisions/2026-08-30_qm5_41233_wti_same_calendar_gastwirth5_g0.md`.
- Q01: pending deterministic magic allocation, implementation, lint,
  independent fixtures, build check, and strict compile.
- Q02: one paced non-live enqueue permitted only below capacity ceilings.

## Safety Boundary

This is a branch-only non-live build contract. It authorizes one `RISK_FIXED`
D1 backtest preset and one paced Q02 enqueue after Q01 and capacity checks. It
creates no live, demo, shadow, stress, or optimization preset; does not change
`T_Live`, a deploy manifest, the portfolio gate, admission, or a correlation
decision; and never toggles AutoTrading.
