---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-XNG-MEDCAL-2026_S01
variant_id: KELOHARJU-XNG-MEDCAL-2026_S01
source_id: KELOHARJU-RETSEAS-2016
ea_id: QM5_41225
slug: xng-medcal
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41225_xng-medcal_card.md
execution_contract_status: DRAFT
created: 2026-08-30
created_by: Research+Development
last_updated: 2026-08-30
g0_status: APPROVED
g0_decision: decisions/2026-08-30_qm5_41225_xng_median_same_calendar_g0.md
source_approval: decisions/2026-08-30_xng_median_same_calendar_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg"
source_citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590. DOI 10.1111/jofi.12398; NBER Working Paper 20815."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read record strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_return_seasonality_and_natural_gas_universe_lineage
strategy_mechanic: prior-ten-year-same-calendar-month-log-return-median-sign-monthly-xng-renewal
sources:
  - "[[sources/KELOHARJU-RETSEAS-2016]]"
concepts:
  - "[[concepts/return-seasonality]]"
  - "[[concepts/robust-order-statistic]]"
  - "[[concepts/natural-gas-seasonality]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/sample-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, calendar-seasonality, same-calendar-month, robust-median, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 412250000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XNG monthly positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_HISTORY_AND_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify an XNG robust same-calendar-month sleeve whose calendar sampling, order statistic, symmetric side map, and monthly lifecycle differ from QM5_12567's cumulative-RSI2 pullback. Verify uniform D1-label normalization, exact historical month endpoints, five-to-ten sample bounds, even/odd median arithmetic, sign-only direction, durable monthly attempt, frozen risk, and absence of current-month leakage. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, first_month_bar_clock, uniform_energy_label_normalization, exact_prior_year_same_calendar_months, completed_month_endpoints, no_current_month_price, five_sample_floor, ten_year_cap, even_odd_median, sign_only_direction, monthly_attempt_state, monthly_renewal, risk_mode_dual, hard_stop_present, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-30 and decisions/2026-08-30_qm5_41225_xng_median_same_calendar_g0.md: R1 uses a named-author peer-reviewed Journal of Finance paper with DOI, complete-read evidence, explicit natural-gas inclusion, and disclosure that the median is a QM robustness translation; R2 locks the month clock, endpoints, sample, median, side, attempt, risk, and lifecycle; R3 uses registered native XNG D1 with warm-up and session-label risks explicit; R4 is deterministic native arithmetic only. Corrected-root canonical dedup found the expected WTI carrier sibling, while manual review separates XNG mean, Huber, sign-score, and cumulative-RSI2 systems with fixed disagreement fixtures."
---

# QM5_41225 XNG Median Same-Calendar Seasonality

## Hypothesis

Natural-gas calendar-month returns may contain recurring information associated
with production, storage, heating/cooling demand, hedging, and capital flows in
the same calendar month of prior years. A bounded sample median should retain
the recurring sign supported by the central historical observations while
preventing one isolated gas-price shock year from controlling the signal.

At the first executable D1 tick after each genuine broker-month transition,
the candidate trades the median sign of five to ten exact prior-year returns
for that calendar month and renews at the next month boundary. This is a
falsifiable XNG calendar-seasonality robustness port. It is not a replication
of the source's diversified futures portfolio or arithmetic-mean rank, and it
is not evidence of standalone profitability, CFD/futures equivalence, or low
correlation with the certified book.

## Source Traceability And Claim Boundary

The bounded packet
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` was completely read
and approved for this extraction in
`decisions/2026-08-30_xng_median_same_calendar_source_approval.md`, committed
as `e17fe575d555b857493d3414a4bd00094978085b` before this card.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar-month return
information, monthly renewal, a five-year history floor, and natural gas
inside the paper's 24-futures commodity panel. The source uses an arithmetic
mean and a cross-sectional portfolio. The ten-year cap, sample median,
absolute-sign single-XNG position, CFD carrier, fixed risk, stop, spread cap,
attempt ledger, and monthly lifecycle are governed QM choices. No source
performance, significance, cost, density, drawdown, neutrality, or
correlation result transfers.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xng_medcal_preallocation_dedup_20260830.json` scanned 4,724
registry identities, 1,362 cards, and 45 Strategy Wiki nodes. It found no
exact identity and one expected fuzzy match, `QM5_41055_wti-medcal`.

- `QM5_41055_wti-medcal` is the same locked order statistic on WTI. This card
  is the OWNER-authorized XNG carrier port and owns only XNG history, magic,
  position, risk, and PnL.
- `QM5_20100_xng-samecal` uses the arithmetic mean. For
  `[+0.01,+0.01,+0.01,+0.01,-0.20]`, that sibling sells while this median
  rule buys.
- `QM5_41205_xng-samecal-huber10` requires all ten observations, a positive
  median/MAD scale, and 32 fixed Huber updates. This card accepts five to ten
  observations and directly uses the ordinary sample median.
- `QM5_41214_xng-samecal-signscore` discards magnitudes and applies a strict
  sample-size-aware abstention band. For
  `[+0.001,-0.20,-0.20,+0.20,+0.20]`, this card buys while that sibling is
  flat.
- `QM5_12567_cum-rsi2-commodity` combines a 200-D1 trend state with a
  cumulative RSI(2) pullback and a short lifecycle. It shares neither this
  information horizon, statistic, side map, nor hold.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAME_CALENDAR_MEDIAN_SIGN_MONTHLY_CARRIER_PORT`.

## Markets, Clock, And Formula

- Host and target: exact `XNGUSD.DWX`, D1, slot 0, magic `412250000`.
- Decision clock: first executable tick of the first available D1 bar in a
  genuine new broker calendar month.
- Session labels: accept only native same-day D1 labels or one uniform `+1`
  calendar-day energy offset. The normalized current D1 date must equal the
  broker date; the same offset applies to every historical endpoint.
- Formation: exact decision calendar month in years `Y-1` through `Y-10`.
- Sample: five to ten valid completed historical returns.
- Ordinary exit: first executable D1 tick in the next broker month.
- Repair exit: 35 elapsed calendar days.
- Expected cadence: approximately 10–12 completed positions/year after
  warm-up.

For decision calendar month `M` in historical year `H`:

```text
pre_close(H,M) = close of the immediately preceding D1 bar, whose normalized
                 date must be in the immediately preceding calendar month
end_close(H,M) = close of the final D1 bar in (H,M), confirmed by a following
                 D1 bar in the immediately following calendar month
r(H,M)         = ln(end_close(H,M) / pre_close(H,M))

collect valid r(Y-k,M), k = 1..10
require 5 <= n <= 10
sort ascending

odd n:  seasonal_state = r[n/2]
even n: seasonal_state = (r[n/2-1] + r[n/2]) / 2

seasonal_state > +1e-12 => BUY XNGUSD.DWX
seasonal_state < -1e-12 => SELL XNGUSD.DWX
otherwise                => consume month flat
```

The adjacent-month checks wrap December and January exactly. Missing,
duplicated, out-of-order, nonpositive, nonfinite, partial, or nonadjacent
endpoints invalidate that year; another year may not replace it.

## Rules

These rules are the complete Q02 baseline. No arithmetic-mean or Huber
fallback, fixed month list, recent-return confirmation, trend, storage,
inventory, event, curve, volume, range, breakout, oscillator, volatility
signal, or external-data filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new exact `XNGUSD.DWX` D1 bar while attached to exact
   `XNGUSD.DWX`, D1, EA ID 41225, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. If owned exposure was opened in an earlier broker `yyyymm`, close it before
   considering the new month. Do not open while owned exposure remains.
4. Accept only a native same-day D1 label or one uniform `+1` calendar-day
   energy offset; require the normalized current D1 date to equal broker date,
   and apply the offset to all history. A mid-month first attachment remains
   flat until the next genuine boundary.
5. Persist the decision-month `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry that month after any
   outcome, including restart or order failure.
6. For exact years `Y-1` through `Y-10`, locate the final normalized D1 bar in
   calendar month `M`. Require the immediate prior bar in the immediately
   preceding month and a confirming next bar in the immediately following
   month. Use only the prior-bar close and final in-month close.
7. Skip an invalid year without substitution. Require five to ten positive,
   finite completed log returns. Current-month OHLC, volume, and tick price
   are forbidden from the signal.
8. Sort valid returns ascending. For odd `n`, select index `n/2`; for even
   `n`, average indexes `n/2-1` and `n/2`. No full-sample mean, weighting,
   winsorization, scale estimate, iteration, interpolation, or fallback exists.
9. Median above `+1e-12` buys XNG; below `-1e-12` sells XNG. The inclusive tie
   band consumes the month flat. Magnitude never changes size.
10. Require completed-bar `ATR(20,D1)`. Attach one normalized frozen hard stop
    at `3.5 * ATR`; use no target.
11. Require a finite non-crossed quote and no genuinely positive spread above
    3,000 points. Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

## 5. Exit Rules

1. At the first observed D1 bar in a later broker `yyyymm`, close owned
   exposure before evaluating that month's signal.
2. Close after 35 elapsed calendar days as final stale repair.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. The frozen broker hard stop and framework kill switch remain authoritative.
5. Framework Friday close is disabled for this monthly identity.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Require exact host, D1, EA 41225, slot 0, registered magic, and locked
  contract inputs.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and the legacy mode are OFF for this native-price baseline.
- Uniform native/`+1` label normalization, genuine month boundary, durable
  attempt, exact endpoint identity, sample floor, median arithmetic, sign
  tolerance, quote, spread, ATR, sizing, and stop geometry must be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own at most one position under magic `412250000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed, later-month, and stale repair on every tick before entry
  logic.
- Persist the last attempted broker `yyyymm` in terminal global state so a
  restart cannot create a second monthly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, margin, or price consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_lookback_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | valid-sample floor |
| `strategy_history_bars_d1` | 3000 | bounded D1 endpoint scan |
| `strategy_signal_epsilon` | 1e-12 | sign/tie boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale repair only |
| `strategy_max_spread_points` | 3000 | XNG entry-cost guard |
| `qm_friday_close_enabled` | false | preserve monthly hold |

No sweep, fallback, month selection, endpoint, direction, sample bound, stop,
spread, or lifecycle change is authorized.

## Runtime Data Dependencies

Native `XNGUSD.DWX` D1 OHLC/timestamps, broker time, current quotes, symbol
contract properties, positions, deals, and terminal-global attempt state only.
No futures chain, curve, roll map, storage or inventory release, weather,
volume, open interest, event feed, API, CSV, optimizer artifact, trained
output, or manual signal input.

## Source-Defined Rules And QM Interpretations

The paper defines recurring same-calendar-month return information, includes
natural gas in its commodity universe, requires at least five years, and
renews monthly. It uses arithmetic means and cross-sectional portfolios; it
does not define this median, single-XNG sign, CFD implementation, stop, or
lifecycle.

QM locks the uniform energy-label normalization, ten-year cap, exact endpoints,
ordinary even/odd sample median, sign epsilon, direct XNG carrier, persistent
attempt, fixed risk, ATR stop, spread ceiling, monthly renewal, and stale
repair as pre-result falsification choices.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. First observed D1 boundary in a later broker month is the ordinary exit.
4. The 35-day close repairs only a survivor.

## Falsification And Requalification

Q02 retires on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, wrong endpoints,
current-month leakage, fewer than five valid observations, wrong even/odd
median arithmetic, estimator fallback, wrong sign, late/repeated entry, wrong
monthly lifecycle, nondeterminism, invalid risk mode, or insufficient local
history. Any estimator, endpoint, sample, direction, carrier, stop, spread,
or hold change creates a new identity. Q09 alone may establish realized book
correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, month boundary, attempt, history, median, side, spread, ATR | trade entry | `Strategy_EntrySignal` and deterministic helpers |
| malformed, later-month, and stale repair | trade management | `Strategy_ManageOpenPosition` and lifecycle helper |
| monthly renewal and survivor repair | trade close | lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | framework no-trade | standard V5 orchestration |
| news OFF | news hook | return false; both current axes and legacy mode OFF |

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label conventions select only the exact normalized
   month boundary, and exact years `Y-1..Y-10` use completed endpoints with
   December/January wrapping and no substitution;
2. five-to-ten sample bounds, odd/even median arithmetic, tie tolerance, and
   direction are exact, including fixtures that disagree with the mean and
   sign-score siblings;
3. no current-month OHLC, volume, or tick price enters the signal;
4. persistent `yyyymm` attempts prevent same-month retry after failure and
   restart;
5. fixed-risk sizing uses a frozen completed-bar ATR stop;
6. next-month close, malformed repair, stale guard, and disabled Friday close
   remain reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone measures density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-30 | initial XNG robust median same-calendar card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-30 | APPROVED_SOURCE | `decisions/2026-08-30_xng_median_same_calendar_source_approval.md` |
| G0 Research Intake | 2026-08-30 | APPROVED | `decisions/2026-08-30_qm5_41225_xng_median_same_calendar_g0.md` |
| Q01 Build Validation | 2026-08-30 | NOT_BUILT | pending |
| Q02 Baseline Screening | 2026-08-30 | NOT_ENQUEUED_Q01_PENDING | pending |

## Safety Boundary

This card authorizes one branch-only non-live EA build, exact slot-0 magic
allocation, strict compile/Q01 validation, one `RISK_FIXED` D1 backtest
setfile, and one paced target-only Q02 enqueue if capacity permits. It
authorizes no manual backtest, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate mutation, portfolio admission, decorrelation claim, or
correlation waiver.
