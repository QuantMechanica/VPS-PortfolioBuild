---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026_S01
variant_id: KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026_S01
source_id: KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026
ea_id: QM5_41232
slug: wti-samecal-madcap5
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41232_wti-samecal-madcap5_card.md
execution_contract_status: APPROVED
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41232_wti_same_calendar_madcap5_g0.md
source_approval: decisions/2026-08-30_wti_same_calendar_madcap5_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, The Journal of Finance 71(4), DOI 10.1111/jofi.12398; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
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
  - type: governed_method_packet
    citation: "QuantMechanica governed WTI median/MAD-capped return-location extraction."
    location: "strategy-seeds/sources/MOP-WTI-MADCAP-2026/source.md"
    quality_tier: internal_governed_complete
    role: raw_mad_center_symmetric_three_mad_cap_equal_weight_retention_and_claim_boundary
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI exact-five-year same-calendar MAD-cap extraction."
    location: "strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_calendar_endpoints_five_sample_mad_cap_risk_claim_and_lifecycle
strategy_mechanic: exact-prior-five-year-same-calendar-month-wti-log-returns-odd-median-raw-mad-symmetric-three-mad-clipping-equal-weight-capped-location-sign-monthly-renewal
sources:
  - "[[sources/KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/calendar-month-renewal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/five-sample-mad-capped-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, same-calendar-month, raw-mad-cap, robust-location, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
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
magic: 412320000
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
r1_reasoning: "Two complete-read peer-reviewed trading papers support recurring same-calendar commodity information, explicit WTI membership, own-return direction, and monthly renewal. A governed complete method packet fixes the MAD-cap arithmetic. The exact five-sample WTI conjunction is an untested QM translation."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform D1-label normalization, exact Y-5..Y-1 endpoints, five-return requirement, odd median/MAD indexes, raw scale, fixed cap, inclusive clipping, exact divisor, epsilon side map, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered XTIUSD.DWX D1 history covers the required five-year warm-up and native MT5 state supplies every runtime input. Session labels, rolls, financing, gaps, and futures/CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, sorting, absolute deviations, clipping, comparisons, ATR risk controls, quotes, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior five matching-calendar years; all five mandatory; odd median and raw MAD index 2; no scale normalizer; symmetric inclusive cap at median +/- 3*MAD; retain all five capped values at equal weight; divisor five; strict absolute location above 1e-12; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a direct-WTI recurring-calendar sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized completed endpoints, exact five-year membership, odd median/raw MAD, frozen inclusive cap, retention of all five values, divisor, sign, consumed month, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, uniform_energy_label_normalization, exact_prior_five_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_of_five_sample, chronological_return_orientation, median_index_two, raw_mad_index_two, no_scale_normalizer, symmetric_three_mad_bounds, inclusive_clipping, all_five_values_retained, equal_weights, divisor_five, strict_sign_epsilon, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41232_wti_same_calendar_madcap5_g0.md: R1 passes with two complete peer-reviewed WTI/commodity lineages, a governed complete MAD-cap arithmetic packet, and explicit robust-location/CFD translation risk; R2 locks calendar, endpoints, exact sample, median/MAD, cap, clipping, divisor, side, attempt, risk, stop, spread, and lifecycle; R3 binds the five-year rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found one expected same-calendar family neighbor, and fixed disagreement fixtures prove semantic non-equivalence to mean, trim, Winsor, pseudomedian, shortest-half, trimean, midhinge, and bisquare siblings."
---

# QM5_41232 WTI Same-Calendar Five-Sample MAD-Capped Location

## Hypothesis

WTI production, storage, transport, refining, hedging, and demand pressures can
recur in the same named calendar month. A raw cross-year mean can be controlled
by one oil-shock year, while an ordinary median discards the spacing between
observations. This card tests whether an exact five-year same-calendar signal
is more useful when every return is retained but shocks are clipped at frozen,
sample-specific bounds three raw MADs around the median.

The direct WTI carrier and recurring monthly clock target exposure outside the
certified XAU/SP500/NDX/XNG set. That construction does not prove low
correlation, profitability, or CFD/futures equivalence. Q02 owns activity and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026/source.md`,
SHA-256
`38D7164C0183576137E65E6E100CF658E75DBF7C3329C045E3DBF51DDEDA14AD`.
The durable source approval is
`decisions/2026-08-30_wti_same_calendar_madcap5_source_approval.md`.

Keloharju, Linnainmaa, and Nyberg support recurring same-calendar commodity
information, explicit crude-oil membership, monthly renewal, and a five-year
history floor. Moskowitz, Ooi, and Pedersen support WTI own-return direction
and monthly renewal. The governed `MOP-WTI-MADCAP-2026` packet fixes the
raw-MAD center-and-cap arithmetic. No source tests this exact five-return
single-CFD conjunction.

The five-year sample, single-WTI zero comparison, median/MAD definitions,
three-MAD cap, continuous CFD, fixed risk, ATR stop, spread ceiling, and
lifecycle are pre-result QM mechanizations. No source performance, WTI-only
alpha, cost, drawdown, correlation, or CFD equivalence transfers.

## Formula

At a genuine normalized broker-calendar transition to year `Y`, month `M`,
load the completed WTI log return for calendar month `M` in each exact year
`Y-5..Y-1`. Preserve the original values in chronological year order and sort
only copies:

```text
r[i]   = ln(close(year_i, M) / close(previous_month(year_i, M)))
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]

lower = median - 3 * MAD
upper = median + 3 * MAD

capped[i] = min(upper, max(lower, r[i]))
location  = sum(capped[0..4]) / 5

location > +1e-12 => BUY XTIUSD.DWX
location < -1e-12 => SELL XTIUSD.DWX
otherwise         => consume the month flat
```

All five returns are mandatory. MAD must be positive. Every value and
intermediate must be finite. The raw MAD has no normal-consistency multiplier.
Bounds freeze before inclusive clipping, all five capped observations remain
equally weighted, and the divisor is exactly five. No deletion, order-statistic
replacement, refit, iteration, fallback center, magnitude sizing, or adaptive
runtime parameter is authorized.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_madcap5_preallocation_dedup_20260830.json`,
SHA-256
`8CCFC5CC92A0CAAE750997FC3DE0E1F2C103085666F5CB8115F8069155163F50`,
found no exact identity across 4,731 registry rows, 1,369 cards, and 45 wiki
nodes. Its only fuzzy match is the expected raw-mean family neighbor
`QM5_20099_wti-samecal`.

- `[-0.20,-0.05,+0.01,+0.03,+0.19]` gives this rule `+0.002` and BUY. Raw
  mean, trim, endpoint Winsor, midhinge, shortest-three, inclusive-pair
  pseudomedian, and fixed bisquare siblings SELL; trimean is FLAT.
- `[-0.15,-0.03,0,+0.03,+0.04]` gives this rule `-0.01` and SELL. Median,
  trim, Winsor, trimean, midhinge, and pseudomedian siblings are FLAT;
  shortest-three and bisquare siblings BUY. Sign reflection reverses both
  mappings.
- Existing same-calendar mean, median, trim, Winsor, block-median,
  shortest-half, trimean, midhinge, pseudomedian, and bisquare EAs do not
  create raw-MAD bounds and retain all five clipped values at equal weight.
- `QM5_20282_wti-madcap-mom` applies the method family to twelve adjacent
  recent months. This card samples one named month across five exact years;
  its seasonal information object is not a contiguous-horizon parameter port.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_RAW_MAD_CAPPED_EQUAL_WEIGHT_LOCATION_SIGN_MONTHLY_SLEEVE`.

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

1. Accept only the exact chart identity `XTIUSD.DWX`, D1, `qm_ea_id=41232`,
   and slot offset zero.
2. Normalize the copied D1 buffer under one uniform convention: native labels
   when at least two broker months are present, otherwise the tested `+1`
   energy-label rule. Mixed endpoint repair is forbidden.
3. Require the normalized current D1 date to equal broker date. Detect a
   genuine new `(year,month)` key and do not treat EA attachment mid-month as a
   transition.
4. Persist the current `yyyymm` attempt before history, signal, news, quote,
   spread, ATR, sizing, or submission. Never retry the month.
5. For every exact year `Y-5..Y-1`, require the last D1 close of month `M`, the
   last close of its immediately preceding calendar month, and a later D1 bar
   confirming completion. Missing or invalid history consumes the month flat.

### 2. Entry Rules

1. Close malformed owned exposure and the previous monthly package before any
   entry-only gate.
2. Compute exactly five finite log returns, odd median index 2, five absolute
   deviations, and raw-MAD index 2. Reject nonpositive MAD.
3. Freeze `lower=median-3*MAD` and `upper=median+3*MAD`; clip each original
   return inclusively; sum exactly five finite capped values and divide by five.
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
4. Otherwise keep the original broker hard stop and return no discretionary
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
| `strategy_mad_cap_mult` | 3.0 | raw-MAD symmetric cap |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Changing the sample, MAD convention, cap, divisor, sign, carrier, stop, hold,
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
| exact sample, odd median/MAD, frozen cap, clipped mean | signal helpers called by `Strategy_EntrySignal` |
| durable attempt before fallible gates | decision preparation helper |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_ManageOpenPosition` helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| news mode assertion | `Strategy_NewsFilterHook` |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, endpoint completion, exact
years, median/MAD indexes, raw scale, frozen three-MAD bounds, inclusive
clipping, retention of all five values, exact divisor, epsilon, disagreement
fixtures, durable attempts, spread boundaries, lifecycle, registry resolution,
card identity, sole setfile, static guardrails, and strict zero-error/zero-warning
compilation.

## Reputable-Source Gate Findings

| Gate | Verdict | Finding |
|---|---|---|
| R1 | PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK | Two complete peer-reviewed trading lineages plus a governed exact MAD-cap method packet; exact conjunction untested. |
| R2 | PASS | Calendar, endpoints, sample, median/MAD, cap, clipping, divisor, side, attempt, risk, and lifecycle locked. |
| R3 | PASS_WITH_FIVE_YEAR_WARMUP_AND_CFD_BASIS_RISK | Registered WTI D1 and native MT5 state suffice; roll, financing, label, gap, and basis risks bind. |
| R4 | PASS | Deterministic native arithmetic and execution state only; no ML, banned indicator, or external runtime feed. |

## Falsification And Requalification

Q02 retires this card on zero positions, fewer than five completed positions in
any full post-warm-up year, nonpositive governed economics, bad endpoint
normalization, missing exact year, nonpositive MAD, wrong raw scale/bounds,
exclusive clipping, dropped observation, wrong divisor, current-month leakage,
wrong side, retry, missing stop, lifecycle defect, nondeterminism, or invalid
risk mode. No after-result change to the statistic or contract is permitted.

Only unchanged Q09 may determine realized correlation or portfolio value.

## Change History

| Version | Date | Reason | Status |
|---|---|---|---|
| v1 | 2026-08-30 | initial WTI exact-five-year same-calendar MAD-cap card | G0 APPROVED; Q01 pending |
| v2 | 2026-08-30 | exact V5 build, fixed-risk preset, independent fixtures, and governed strict compile | Q01 PASS; Q02 not enqueued because the five-sample CPU maximum exceeded the 97% ceiling |

## Approvals

- Source: `APPROVED_SOURCE` under the explicit OWNER mission.
- G0: `APPROVED` by
  `decisions/2026-08-30_qm5_41232_wti_same_calendar_madcap5_g0.md`.
- Q01: `PASS`; governed compile work item
  `538ed871-29a2-45d9-86df-4f372a0555b4`, build check PASS, compiler
  0 errors/0 warnings, one canonical setfile, EX5 SHA-256
  `f8317c897377573597a65e47c1a6d5c675d9586ccc0a6e4611d075ad5411101e`.
- Q02: `NOT_ENQUEUED_CPU_CEILING`; the 2026-08-30T17:53:04Z five-sample
  reading averaged 93.67% and reached 99.22%, above the hard 97% maximum.

## Safety Boundary

This is a branch-only non-live build contract. It authorizes one `RISK_FIXED`
D1 backtest preset and one paced Q02 enqueue after Q01 and capacity checks. It
creates no live, demo, shadow, stress, or optimization preset; does not change
`T_Live`, a deploy manifest, the portfolio gate, admission, or a correlation
decision; and never toggles AutoTrading.
