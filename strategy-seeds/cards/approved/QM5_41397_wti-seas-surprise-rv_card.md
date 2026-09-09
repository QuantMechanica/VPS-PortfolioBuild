---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-YANG-WTI-SEASSURPRISE-2026_S01
variant_id: KELOHARJU-YANG-WTI-SEASSURPRISE-2026_S01
source_id: KELOHARJU-YANG-WTI-SEASSURPRISE-2026
ea_id: QM5_41397
slug: wti-seas-surprise-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41397_wti-seas-surprise-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41397_wti_seasonal_surprise_reversion_g0.md
source_approval: decisions/2026-09-09_wti_seasonal_surprise_reversion_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Hongbing Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Hongbing Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Yang, Goncu, and Pantelous (2017), Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete governed review strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_information_and_explicit_crude_oil_membership
  - type: academic_trading_paper
    citation: "Yang, H., Goncu, A., and Pantelous, A. A. (2017). Momentum and Reversal in Commodity Futures."
    location: "SSRN 3069253; governed packet strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md"
    quality_tier: B_academic_not_peer_reviewed
    role: broad_fixed_horizon_commodity_reversal_lineage
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI standardized seasonal-surprise reversion extraction."
    location: strategy-seeds/sources/KELOHARJU-YANG-WTI-SEASSURPRISE-2026/source.md
    quality_tier: internal_governed
    role: exact_conjunction_sample_score_risk_and_lifecycle
strategy_mechanic: monthly-wti-just-completed-log-return-minus-up-to-ten-prior-year-same-calendar-mean-divided-by-sample-standard-deviation-strict-half-sigma-contrarian-next-month
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, standardized-surprise, reversion, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413970000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 6-9 completed WTI monthly positions per full post-warm-up year at the locked half-standard-deviation band; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ACADEMIC_SUPPLEMENT_CONJUNCTION_AND_CFD_RISK
r1_reasoning: "Complete peer-reviewed Journal of Finance same-calendar commodity evidence with explicit crude-oil membership plus a governed named-author academic commodity-reversal lineage; the exact standardized WTI residual conjunction is untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, uniform normalized endpoints, realized-sample exclusion, ten-year cap, five-sample floor, arithmetic mean, n-1 sample scale, strict score band, consumed attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime input; warm-up, D1 session labels, rolls, financing, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sums, sample variance, square root, comparisons, ATR risk controls, and execution state; no trained signal, banned signal component, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: prior 10-year same-calendar search cap; minimum 5 observations; arithmetic mean; n-1 sample standard deviation; strict abs(z)>0.50 plus 1e-10 tolerance; 3000 D1 history bars; ATR(20)*3.5 frozen stop; 40-day stale exit; nonnegative modeled spread capped at 1500 points."
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
review_focus: "Falsify a monthly WTI stream that fades only the just-completed return unexplained by recurring same-calendar history. Verify clock, labels, endpoints, realized-sample exclusion, n-1 scale, strict contrarian band, durable attempt, fixed risk, frozen stop, and next-month close. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_month_bar_clock, uniform_energy_label_normalization, just_completed_month_mapping, completed_month_endpoints, no_current_month_price, realized_sample_exclusion, ten_year_search_cap, five_sample_floor, arithmetic_mean, sample_variance_n_minus_one, strict_residual_band, contrarian_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, nonnegative_modeled_spread, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission and decisions/2026-09-09_qm5_41397_wti_seasonal_surprise_reversion_g0.md: R1 passes with complete peer-reviewed same-calendar evidence plus a governed academic reversal supplement and explicit conjunction risk; R2 locks all arithmetic and lifecycle choices; R3 uses registered native WTI D1; R4 uses deterministic native arithmetic only. Canonical dedup found no exact identity and manual review separated three expected carrier/direction fuzzy siblings."
---

# QM5_41397 WTI Monthly Seasonal-Surprise Reversion

## Hypothesis

Crude-oil production, refinery, transport, consumption, and hedging pressures
can recur by calendar month. When the just-completed WTI monthly return is
unusually large after subtracting its own historical expectation for that
same calendar month, the unexpected component may partially reverse during
the next broker month.

This is direct WTI exposure outside the stated XAU/SP500/NDX/XNG book. Its
monthly seasonally adjusted state is neither a raw return sign nor an
upcoming-month seasonal forecast. Structural distinction does not prove low
realized correlation; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/KELOHARJU-YANG-WTI-SEASSURPRISE-2026/source.md`.
Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information and explicit crude-oil membership. Yang, Goncu, and Pantelous
supply broad academic commodity-reversal lineage. Neither establishes this
exact WTI CFD conjunction.

The canonical receipt found no exact identity and three expected fuzzy
neighbors. `QM5_41208` applies this estimator and direction to XNG;
`QM5_41209` applies the WTI estimator with the opposite direction; and
`QM5_41393` changes both carrier and direction. `QM5_20137` uses a raw prior-
month counter-move only as a gate on an upcoming-month seasonal forecast.
`QM5_20054` fades the raw prior-month sign without seasonal subtraction or
scaling. `QM5_12567` uses cumulative RSI and a slow trend.

Verdict:
`DISTINCT_WTI_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_FAMILY_REVIEW`.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XTIUSD.DWX`; D1 only; slot 0.
- Decision: first executable D1 tick after a genuine normalized broker-month
  transition.
- Formation: just-completed month plus its same calendar month in up to ten
  earlier years, excluding the realized observation and requiring five.
- Hold: next broker-month boundary; 40 days is stale repair only.

```text
realized_J    = ln(WTI_end_J / WTI_end_(J-1))
seasonal_mean = sum(prior_same_calendar_returns) / n
seasonal_sd   = sqrt(sum((r-seasonal_mean)^2)/(n-1))
surprise_z    = (realized_J-seasonal_mean)/seasonal_sd

SELL iff surprise_z > +0.50 + 1e-10
BUY  iff surprise_z < -0.50 - 1e-10
FLAT otherwise
```

## Rules

### 4. Entry Rules

1. Require exact EA ID 41397, setfile-bound `XTIUSD.DWX` D1 host, slot zero,
   and fixed-risk mode.
2. Repair malformed exposure and liquidate prior-month exposure before
   entry-only gates. Act only on a genuine normalized month transition.
3. Accept one uniform native or `+1` energy-D1 label convention and apply it
   to every endpoint. No current-month OHLC enters the signal.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or submission. Never retry that month.
5. Reconstruct the exact just-completed month from at most 3,000 completed D1
   bars, then scan the same calendar month over the preceding ten years.
6. Exclude the realized year, skip missing older years without replacement,
   and require at least five finite valid observations.
7. Use arithmetic mean and sample standard deviation with `n-1`; nonpositive
   or nonfinite scale consumes flat.
8. Sell beyond `+0.50+1e-10`; buy below `-0.50-1e-10`; equality and the
   interior band consume flat. Magnitude never changes risk.
9. Require positive finite Bid/Ask, `Ask>=Bid`, spread in `[0,1500]` points,
   completed ATR(20,D1), and valid stop/volume metadata.
10. Submit at most one market position with `RISK_FIXED=1000`, a frozen
    `3.5*ATR` hard stop, and no target.

### 5. Exit Rules

Close on the first processed D1 bar of the next normalized broker month.
Close after 40 elapsed days only as stale repair. Immediately flatten
duplicate, wrong-symbol, wrong-magic, invalid-side, missing-stop, invalid-
volume, or invalid-open-time owned exposure. Broker hard stop and framework
kill switch remain authoritative. No signal flip, target, trail, break-even,
partial close, scale-in, grid, martingale, pyramid, or discretionary exit.

### 6. Filters (No-Trade Module)

Fail closed for wrong host, period, ID, slot, fixed-risk mode, invalid locked
`strategy_*`, consumed month, owned position, same-month entry deal, late
restart, invalid history, insufficient sample, invalid scale, interior score,
bad quote, excess spread, invalid ATR, or invalid sizing. News and Friday
inputs remain framework-governed and are not equality-pinned by source.

### 7. Trade Management Rules

Track MAE first on every tick. Repair malformed, cross-month, and stale owned
exposure before every entry-only gate. Own at most one exact-symbol/exact-
magic position. Never move the entry stop. Persist the consumed-month ledger
in a terminal global variable so restart cannot create another attempt.

## Parameters To Test

No optimization surface is approved. Locked baseline: ten prior years,
minimum five observations, arithmetic mean, `n-1` scale, strict score 0.50,
tolerance `1e-10`, 3,000 D1 history bars, ATR period 20, stop multiple 3.5,
maximum hold 40 days, and maximum spread 1,500 points.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, compounding override, or retry.
- Invalid price, stop, tick value, tick size, volume, margin, or position
  composition consumes the month.

This card creates no live, demo, shadow, stress, or optimization preset.

## Data Requirements

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, quotes, symbol
properties, positions, deals, and terminal-global attempt state only. No
curve, inventory, refinery, storage, volume, open interest, event feed, API,
CSV, optimizer artifact, trained output, or manual signal input.

## Framework Execution Overrides

The backtest setfile uses news temporal OFF, news compliance NONE, legacy
news OFF, and Friday close disabled. The EA does not equality-pin those
framework inputs. Framework kill switch, fixed-risk sizing, magic resolution,
order services, MAE tracking, and owned-position isolation remain mandatory.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host/period, identity, risk mode, locked `strategy_*`; framework controls unpinned | No Trade | `Strategy_NoTradeFilter` |
| month clock, attempt, endpoints, sample, score, contrarian side, spread, ATR | Trade Entry | `Strategy_EntrySignal` and deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` and lifecycle helper |
| monthly renewal and broker hard stop | Trade Close | lifecycle helper; `Strategy_ExitSignal` has no discretionary signal |
| configured news behavior | News hook | framework delegation |

## Kill Criteria

Retire rather than tune on zero trades; fewer than five completed positions in
any full post-warm-up year; nonpositive governed economics; wrong normalized
month, endpoint, exclusion, sample, denominator, scale, score, side, attempt,
risk, stop, spread, lifecycle, or determinism; current-month leakage; retry;
or missing stop.

No weak result may be rescued by adopting unconditional one-month reversal,
forecasting the upcoming month, changing sample or band, selecting months,
changing direction or carrier, adding another filter, or extending the hold.

## Validation Plan

Q01 must prove native and `+1` label behavior, December/January rollover,
realized-sample exclusion, missing-year skipping, five-through-ten sample
arithmetic, strict boundaries, contrarian side, no current-month leakage,
durable no-retry state, zero-spread reachability, fixed-risk frozen stop,
next-month close, stale repair, disabled Friday close, strict compile, schema
lint, magic resolver, setfile, and build checks.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-09 | APPROVED; R1-R4 PASS | source approval, bounded packet, and G0 decision |
| Q01 Build Validation | 2026-09-09 | NOT_BUILT | deterministic magic allocation and build pending |
| Q02 Baseline Screening | 2026-09-09 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes one branch-only non-live build, deterministic slot-zero
magic allocation, strict Q01, one D1 `RISK_FIXED` backtest setfile, and one
paced Q02 enqueue only after prerequisites and a non-binding CPU check. It
does not authorize a manual backtest, live/demo/shadow/stress/optimization
preset, terminal control, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate changes, portfolio admission, or correlation waiver.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-09 | initial WTI standardized seasonal-surprise reversion card | G0 | APPROVED; build pending |

