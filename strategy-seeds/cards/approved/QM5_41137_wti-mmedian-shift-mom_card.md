---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MMEDIAN-SHIFT-MOM-2026_S01
variant_id: MOP-WTI-MMEDIAN-SHIFT-MOM-2026_S01
source_id: MOP-WTI-MMEDIAN-SHIFT-MOM-2026
ea_id: QM5_41137
slug: wti-mmedian-shift-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41137_wti-mmedian-shift-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-24
created_by: Research+Development
last_updated: 2026-08-24
g0_status: APPROVED
g0_decision: decisions/2026-08-24_qm5_41137_wti_monthly_median_location_shift_momentum_g0.md
source_approval: decisions/2026-08-24_wti_monthly_median_location_shift_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-MMEDIAN-SHIFT-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_price_monthly_continuation_and_monthly_clock
strategy_mechanic: normalized-month-boundary-wti-two-consecutive-completed-calendar-month-daily-log-price-level-samples-independent-ordinary-medians-strict-location-shift-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MMEDIAN-SHIFT-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-robust-price-location]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/two-completed-month-daily-log-price-median-shift]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-median-location-shift, robust-price-location, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411370000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after exact adjacent months, median arithmetic, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_MEDIAN_LOCATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI two-completed-month median-location continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact adjacent months, 17-23 closes per month, positive log-price construction, independent full sorts, ordinary odd/even medians, strict newest-versus-parent direction, one consumed attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, two_consecutive_completed_calendar_months, bounded_month_session_counts, positive_finite_closes, no_current_month_leakage, independent_log_price_samples, full_sample_ascending_sorts, ordinary_odd_even_medians, strict_median_shift, equality_flat, continuation_side, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-24; R1 peer-reviewed complete-read WTI own-return momentum source with the two-sample median-location translation disclosed; R2 exact clock/labels/adjacent months/log prices/sorts/medians/direction/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic structural arithmetic without a trained or banned signal; canonical pre-allocation dedup CLEAN and manual family review separates endpoint momentum, range migration, within-month daily-return median, twelve-month median return, historical seasonality, the contrarian XAU/XAG median-shift basket, and certified XNG RSI logic."
---

# QM5_41137 WTI Two-Completed-Month Median-Location Shift Momentum

## Hypothesis

WTI adjusts to production, transport, refining, inventory, hedging, and demand
shocks through persistent physical-energy regimes. A single month-end print
can overstate or understate the price location occupied during a month.
Following a strict shift between the ordinary medians of all daily log-price
levels in two consecutive completed months tests whether robust WTI price-
location migration persists through the next month.

This is direct crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG carriers. A different instrument and mechanic do not prove profitability
or low realized correlation. Q02 owns density and baseline economics;
unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The approved source of record is
`strategy-seeds/sources/MOP-WTI-MMEDIAN-SHIFT-MOM-2026/source.md`, SHA-256
`A53AB707037B46005D8F9AA37810B0284CA1DEE2F6453C4D34C07D26B56EC090`,
authorized before extraction by
`decisions/2026-08-24_wti_monthly_median_location_shift_momentum_source_approval.md`
at commit `6ebf566fb` and committed as a bounded packet at `3772df384`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, a symmetric long/short mapping, a pooled commodity `k=1,h=1`
implementation, and explicit WTI membership. They do not test two within-
month daily log-price distributions, ordinary sample medians, strict
continuation after their location shift, a Darwinex CFD, fixed-dollar ATR
risk, or the QM portfolio. Those are declared QM interpretations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, neutrality, or portfolio-
correlation statistic transfers.

## Non-duplicate decision

The canonical checker returned `CLEAN` after binding 4,636 registry rows,
1,304 repository cards, and 45 current Strategy Wiki nodes. Evidence is
`artifacts/qm5_wti_mmedian_shift_mom_preallocation_dedup_20260824.json`.

Manual review fixes the load-bearing differences:

- `QM5_20187_wti-tsmom1m` uses only two month-end closes. This card uses every
  accepted daily close in two full months and no endpoint-return gate.
- `QM5_41102_wti-mrange-migrate-mom` requires migration of both aggregate
  highs and lows. This card ignores highs/lows and compares close medians.
- `QM5_41133_wti-mdaily-median-mom` takes the median of daily returns inside
  one month. This card computes no daily return and compares log-price-level
  medians in two separate months.
- `QM5_20269_wti-medret-mom` takes a median across twelve monthly returns.
  This card uses two within-month daily close distributions.
- `QM5_41055_wti-med-calendar` compares historical same-calendar-month
  outcomes. This card has no seasonal or year-of-history state.
- `QM5_41104_xauxag-mmedian-shift-rv` forms a two-metal unit-log ratio and
  fades its shift. This card trades one outright WTI leg and follows its
  price-location shift.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback above a slow trend filter.

The WTI carrier, exact two completed consecutive months, daily log-price
samples, independent ordinary medians, strict comparison, continuation side,
consumed month, fixed risk, and next-month exit are jointly load bearing.
Verdict:
`CLEAN_WTI_TWO_COMPLETED_MONTH_DAILY_LOG_PRICE_MEDIAN_LOCATION_SHIFT_MOMENTUM`.

## Market, clock, and state

- Exact host and traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `411370000`.
- Decision: first new D1 bar whose uniformly normalized date belongs to a new
  broker-calendar month, within 180 elapsed minutes of the raw bar open.
- Formation: every valid completed D1 close in the immediately completed
  month and its consecutive parent month; 17-23 sessions per month.
- Direction: strict newest ordinary log-price median minus parent ordinary
  log-price median sign.
- Lifecycle: at most one position and one consumed attempt per decision
  month; hold until the first tick of a later normalized month.

No current-month price is a signal input. The current raw D1 bar exists only
to establish decision clock, label normalization, and grace.

## Energy-label normalization

Use the current raw host D1 bar and broker time to select one label offset for
the entire decision package:

- raw broker date (`0` seconds); or
- exactly one calendar day (`86400` seconds) when the energy D1 label is one
  day behind the broker session date.

Apply that offset to the current bar and every historical bar. Reject mixed,
colliding, weekend-ending, future, non-midnight, or other offset states. The
normalized month key owns attempt persistence and lifecycle.

## Completed-month median-location contract

1. Copy at least 70 completed `XTIUSD.DWX` D1 bars. Exclude index zero and all
   observations belonging to the current normalized month.
2. Select the immediately completed month and its consecutive parent month.
   Require exact calendar adjacency, including December-to-January rollover.
3. Require 17-23 unique, strictly ordered session timestamps and positive
   finite closes in each sample. Reject gaps in month identity, duplicated
   normalized labels, invalid closes, or any current-month leakage.
4. Transform every accepted close independently as `p[d] = log(close[d])`.
   Do not calculate a daily return, aggregate endpoint, range, center across
   both samples, displacement threshold, or fitted coefficient.
5. Sort each monthly log-price sample independently ascending without
   rounding. Preserve exact membership.
6. For odd `n`, select `sorted[n/2]`. For even `n`, use
   `(sorted[n/2-1] + sorted[n/2]) / 2`. Reject nonfinite arithmetic.
7. `median_new > median_old` buys WTI; `median_new < median_old` sells WTI;
   exact equality stays flat. Magnitude does not affect entry or size.

## Rules

All rules are locked for the single baseline. There is no optimization
surface.

### Entry rules

1. Require exact `XTIUSD.DWX`, D1, EA `41137`, slot zero, registered magic,
   backtest risk mode, news axes OFF, Friday close OFF, stress probability
   zero, RNG seed 42, and every strategy default exactly as declared.
2. On a new D1 bar, validate the normalized label and detect the first raw
   decision bar of a new normalized month. A late attachment consumes the
   month flat.
3. Persist the decision month before history, median calculation, news,
   spread, quote, ATR, sizing, margin, or order gates.
4. Reject an existing owned position or same-month entry deal. Never stack,
   scale, or retry.
5. Load and validate the two monthly samples and medians exactly as specified.
6. Require a strict nonzero median shift and entry spread no greater than
   1,500 points.
7. Read frozen completed-bar `ATR(20,D1)`, construct a valid normalized
   `3.5 * ATR` hard stop, and submit one fixed-risk market request in the
   strict shift direction.

### Attempt and restart contract

One terminal global-variable key derived from EA magic stores the greatest
normalized `yyyymm` attempted. The decision month is consumed before any
fallible signal or execution gate. On initialization, reconcile that value
with owned positions and same-magic entry deals. A restart never reopens a
month already consumed, including late, flat, invalid-history, spread, quote,
stop, margin, rejection, stopped, or previously completed outcomes.

### Exit rules

Exit precedence is:

1. framework kill switch;
2. broker hard stop;
3. malformed exposure repair, including duplicates, wrong symbol, wrong
   magic, or missing/invalid stop;
4. first tick whose normalized month differs from the position-open month;
5. forty-calendar-day stale repair.

There is no target, trailing stop, break-even move, partial close, current-
month signal exit, opposite-signal exit, or Friday flattening.

### Filters and trade management

- No news dependency: temporal mode OFF, compliance profile NONE, legacy mode
  OFF, stale ceiling 336 hours, minimum-impact token `high` locked but inert.
- Friday close disabled to preserve the monthly ownership contract.
- Framework kill switch remains active. Session and holiday framework state
  must not introduce a card-undeclared entry rule.
- Spread and quote checks are entry-only. Lifecycle repair and later-month
  close run on every tick before entry-only gates.
- At most one owned position. Any malformed state closes fail-safe rather than
  becoming a second hypothesis.

## Parameters to test

Single baseline only:

| Input | Locked value | Purpose |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | raw first-bar execution window |
| `strategy_history_bars_d1` | 70 | bounded two-month history buffer |
| `strategy_min_month_sessions` | 17 | minimum per-month sample count |
| `strategy_max_month_sessions` | 23 | maximum per-month sample count |
| `strategy_atr_period_d1` | 20 | completed-bar hard-stop range |
| `strategy_atr_sl_mult` | 3.5 | frozen stop multiple |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost ceiling |
| `strategy_deviation_points` | 20 | market-request deviation |

Changing a sample bound, calendar rule, log transform, median formula,
comparison, side, risk, or lifecycle creates a new hypothesis and requires a
new source/G0 decision. No in-place rescue is authorized.

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- One slot-zero WTI position maximum; no aggregate with any other EA.
- Initial stop: normalized market-side `3.5 * ATR(20,D1)` from completed bar
  one, frozen for the trade.
- No take-profit. No scale-in, pyramid, martingale, grid, averaging, partial
  close, trail, or break-even adjustment.
- A valid stop and finite entry quote are mandatory. Risk sizing uses the V5
  helper and registered magic `411370000`; no manual lot formula.
- `expected_pf` and `expected_dd_pct` are admission placeholders, not source
  evidence or performance claims.

## Framework alignment

- no_trade: exact symbol, period, EA, slot, risk mode, news, Friday, stress,
  RNG, and locked parameter validation.
- trade_entry: normalized month clock, durable attempt, exact adjacent-month
  samples, positive log prices, independent sort and medians, strict shift,
  spread, quote, ATR stop, and one fixed-risk request.
- trade_management: malformed-position repair, later-normalized-month exit,
  and forty-day stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.
- runtime dependencies: exact `XTIUSD.DWX` D1 history, broker clock, quotes,
  symbol metadata, ATR, positions, deals, and terminal globals only.

## Safety and claim boundary

Create exactly one D1 backtest setfile with `RISK_FIXED=1000`. No live, demo,
shadow, stress, or optimization setfile is authorized. No manual backtest,
terminal control, `T_Live`, AutoTrading, deploy/T_Live manifest, portfolio-
gate edit, portfolio admission, correlation waiver, or decorrelation claim is
authorized.

Q02 must retire at zero trades, below five completed positions in any full
post-warm-up year, with nonpositive governed economics, or on any label,
month, sample, log-price, sort, median, side, attempt, risk, lifecycle, or
determinism defect. Q09 alone may judge realized portfolio correlation.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-24 | approved source extraction | G0-approved card; QM5_41137 and magic pending governed allocation |

## Phase log

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-08-24 | APPROVED | decisions/2026-08-24_wti_monthly_median_location_shift_momentum_source_approval.md |
| G0 Research Intake | 2026-08-24 | APPROVED | decisions/2026-08-24_qm5_41137_wti_monthly_median_location_shift_momentum_g0.md |
| Q01 Build/Compile | pending | PENDING | branch-only build required |
| Q02 Baseline | pending | NOT_QUEUED | paced non-live enqueue only after Q01 PASS and CPU availability |
