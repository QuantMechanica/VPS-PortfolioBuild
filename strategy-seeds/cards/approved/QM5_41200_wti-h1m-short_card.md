---
card_schema_version: 2
type: strategy
strategy_id: BOROWSKI-WTI-H1M-2026_S01
variant_id: BOROWSKI-WTI-H1M-2026_S01
source_id: BOROWSKI-WTI-H1M-2026
ea_id: QM5_41200
slug: wti-h1m-short
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41200_wti-h1m-short_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41200_wti_first_half_month_short_g0.md
source_approval: decisions/2026-08-29_wti_first_half_month_short_source_approval.md
source_approval_amendment: decisions/2026-08-29_wti_first_half_month_short_source_approval_amendment_1.md
source_author: "Krzysztof Borowski"
source_authors: "Krzysztof Borowski"
source_citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.4 and Table 2, pp. 37-38; complete-read record strategy-seeds/sources/BOROWSKI-WTI-H2M-2016/source.md"
    quality_tier: B
    role: direct_wti_calendar_days_1_to_15_return_sign_and_half_month_partition
  - type: governed_translation_packet
    citation: "QuantMechanica bounded WTI first-half-of-month short extraction."
    location: "strategy-seeds/sources/BOROWSKI-WTI-H1M-2026/source.md"
    quality_tier: internal_governed
    role: exact_cfd_host_boundary_attempt_risk_exit_and_safety_contract
strategy_mechanic: first-genuine-broker-month-d1-boundary-wti-short-through-first-subsequent-session-day-ge-16
sources:
  - "[[sources/BOROWSKI-WTI-H1M-2026]]"
concepts:
  - "[[concepts/calendar-seasonality]]"
  - "[[concepts/within-month-return-asymmetry]]"
  - "[[concepts/monthly-renewal]]"
indicators:
  - "[[indicators/broker-calendar-boundary]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, within-month, first-half-month, short-only, monthly-renewal, atr-hard-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 412000000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: short_only
expected_trade_frequency: "Approximately 10-12 completed XTI first-half-month positions per full year; a late attach, invalid D1 label, invalid risk input, or blocked execution consumes the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_NONSIGNIFICANCE_AND_CFD_TRANSLATION_RISK
r1_reasoning: "A named-author peer-reviewed complete-read Tier-B paper directly reports the negative WTI days-1-through-15 return sign and calendar partition; the result is non-significant and predates the Darwinex CFD carrier."
r2_mechanical: PASS
r2_reasoning: "Exact host, uniform D1-date normalization, genuine month boundary, 180-minute attachment ceiling, entry-day ceiling, short side, consumed monthly attempt, fixed risk, frozen stop, first day-ge-16 exit, and stale repair are deterministic and locked."
r3_data_available: PASS
r3_qualification: SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply every runtime field; D1 label mapping, rolls, financing, and futures/CFD basis remain explicit Q02 risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only broker-calendar comparisons, bounded completed-bar ATR risk plumbing, quotes, contract metadata, positions, deals, and persistent attempt state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: normalized first genuine D1 month boundary; attach within 180 minutes; normalized entry day <=5; short only; exit day >=16; ATR(20)*2.75 frozen stop; 20-day stale repair; 2500-point positive-spread ceiling; Friday close OFF."
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
review_focus: "Falsify a direct-WTI first-half calendar sleeve outside the directional XAU/SP500/NDX/XNG book. Verify uniform energy D1-label normalization, genuine new-month detection, bounded first-session attachment, day<=5 entry, short-only side, consumed month, fixed cash risk, frozen stop, no Friday truncation, and first subsequent day>=16 close. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, d1_only, uniform_energy_label_normalization, genuine_month_boundary, boundary_attach_ceiling, entry_day_ceiling, short_only, monthly_attempt_state, fixed_risk_backtest, hard_stop_present, no_target, first_day_ge_16_exit, stale_repair_only, friday_close_disabled, q02_frequency_floor, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29 and decisions/2026-08-29_qm5_41200_wti_first_half_month_short_g0.md: R1 passes with disclosed non-significance and CFD translation risk; R2 locks boundary, attachment, side, attempt, risk, stop, exit, and repair; R3 uses registered native XTI D1 with session/CFD risks explicit; R4 is deterministic native arithmetic only. Canonical dedup found only expected Borowski source-family neighbors, and manual lifecycle comparison establishes non-equivalence."
---

# QM5_41200 WTI First-Half-of-Month Short

## Hypothesis

WTI supply, refinery, inventory, hedging, financing, and contract-cycle flows
may create a recurring within-month return asymmetry. Borowski reports a
negative average NYMEX crude-oil return for calendar days 1-15. This card tests
the literal first-half sign on `XTIUSD.DWX`: sell at the first genuine broker-
month D1 boundary and flatten at the first later session dated 16 or beyond.

The reported half-to-half difference is not statistically significant. The
card is therefore a deliberately weak, predeclared falsification candidate,
not evidence of profitability. Direct WTI supplies crude-oil exposure absent
from the stated XAU/SP500/NDX/XNG book, but Q09 alone may establish realized
portfolio overlap.

## Source Traceability And Claim Boundary

The bounded packet is
`strategy-seeds/sources/BOROWSKI-WTI-H1M-2026/source.md`, SHA-256
`56958E78F5514C2C8E4A42AF8D8995E0234C32512465F597BC40EFE8A99CDCF9`.
Its durable approval was committed as `bcea29578`; amendment `878a92250`
disabled Friday close before card extraction so Q02 tests the complete approved
half-month interval.

Borowski supplies the negative first-half WTI return sign and calendar days
1-15 partition. The first available CFD session, uniform D1-label convention,
180-minute attachment limit, entry-day ceiling, persistent attempt, fixed
cash risk, ATR stop, spread ceiling, and stale repair are QM interpretations.
No source return, significance, cost, density, drawdown, futures/CFD
equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The pre-allocation receipt
`artifacts/qm5_wti_h1m_short_preallocation_dedup_20260829.json` scanned 4,699
registry identities, 1,345 cards, and all 45 current Strategy Wiki nodes. It
found no exact collision and surfaced only Borowski source-family fuzzy
neighbors.

- `QM5_20021_wti-h2m-short` enters on actual day 16 and holds the
  complementary second-half interval until the next month. This card enters
  at the month boundary and exits before that existing interval begins.
- `QM5_20028_wti-dom1-long` buys only an actual day-1 session and exits on the
  next D1 boundary. This card sells the first available opening session and
  owns the entire first half.
- `QM5_20027_wti-dom26-short` owns one later session outside this card's
  holding interval.
- surfaced XNG and weekday cards use different carriers or clocks.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_FIRST_GENUINE_MONTH_BOUNDARY_SHORT_TO_FIRST_DAY_GE_16`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Exact chart period and signal period: D1.
- EA ID / slot / intended magic: `41200 / 0 / 412000000`.
- Entry cadence: at most one consumed decision per broker `yyyymm`.
- Expected completed positions: approximately 10-12 per full year; Q02 must
  prove at least five in each full scored year or retire.
- Ordinary holding interval: first month session through the first subsequent
  session whose normalized calendar day is at least 16.

## Formula

For a current D1 bar label `T0`, previous D1 bar label `T1`, and current broker
date `B`:

```text
choose one offset o in {0,+1 calendar day} such that date(T0+o) == date(B)
current_date  = date(T0+o)
previous_date = date(T1+o)

genuine_month_boundary = yyyymm(current_date) != yyyymm(previous_date)
entry_eligible = genuine_month_boundary
                 and day(current_date) <= 5
                 and broker_time - (T0+o) <= 180 minutes

entry_eligible => SELL one fixed-risk XTI position
first later D1 bar with day(current_date) >= 16 => flatten
```

If neither allowed offset maps the current D1 label to the current broker date,
the date convention is invalid and the month is consumed flat. The same offset
must be applied to the previous label and all lifecycle comparisons. There is
no price-return, trend, magnitude, or direction calculation.

## Rules

These rules are the complete locked baseline. No alternate day, shifted
boundary, weekday, fixed favorable month, recent return, trend, mean,
oscillator, inventory, event, curve, volume, volatility signal, or external
data filter is authorized.

## 4. Entry Rules

1. Evaluate only while attached to exact `XTIUSD.DWX`, D1, EA ID 41200, slot
   0, with the registered magic.
2. Process malformed, duplicate, wrong-side, or stale owned exposure before
   every entry-only gate. Do not open while any owned exposure remains.
3. Act only on a new D1 bar. Select exactly one native or `+1` calendar-day
   label convention by matching the current normalized D1 date to the broker
   date. Reject any other offset or ambiguous/malformed state.
4. Require the previous normalized D1 bar to belong to a different broker
   `yyyymm`, proving a genuine month boundary. A mid-month attach or ordinary
   later D1 bar is not an entry clock.
5. Require the normalized entry day to be 5 or earlier and the current broker
   time to be no more than 180 minutes after the normalized current D1 open.
   A late attach consumes the month flat.
6. Derive the attempt key from the decision month's broker `yyyymm`. Recover
   it from owned positions/deals when necessary, then persist it before news,
   spread, quote, ATR, sizing, margin, or order gates. Never retry that month.
7. Direction is always SELL. No price observation changes or suppresses the
   side except invalid execution/risk plumbing.
8. Require valid completed-bar ATR(20,D1). Place one frozen broker hard stop
   exactly `2.75*ATR` above the sell entry reference; use no take-profit.
9. Require a valid quote and no genuinely positive spread above 2,500 points.
   Modeled zero `.DWX` spread is valid.
10. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, companion leg, or reversal exists.

## 5. Exit Rules

1. On the first observed later D1 bar whose normalized broker day is 16 or
   greater, close all owned exposure before any entry logic.
2. Close after 20 elapsed calendar days as a final survivor repair only.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, non-SELL,
   invalid-volume, invalid-open-time, or missing-stop owned exposure.
4. The frozen broker hard stop and framework kill switch remain authoritative.
5. Framework Friday close is disabled so it cannot truncate the approved
   half-month information object.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41200, slot 0, and registered magic.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal is a completed broker-calendar boundary.
- Uniform native/`+1` label normalization, genuine month boundary, attach
  age, entry day, monthly attempt, quote, spread, ATR, sizing, and stop
  geometry must be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own at most one position under magic `412000000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed, first-day-ge-16, and stale repair before entry logic on every
  tick/new-bar transition as applicable.
- Persist the last attempted broker `yyyymm` in terminal global state; recover
  an attempt from current-month owned position/deal history after state loss.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `2.75*ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, quote, or price consumes the month.
- Aggregate open risk is one fixed cash budget because the EA owns one leg.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_exit_calendar_day` | 16 | first ordinary exit day |
| `strategy_entry_latest_day` | 5 | opening-session lateness ceiling |
| `strategy_boundary_attach_max_minutes` | 180 | first-bar attachment ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 2.75 | frozen hard-stop distance |
| `strategy_max_hold_days` | 20 | survivor repair only |
| `strategy_max_spread_points` | 2500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve half-month hold |

No sweep, alternate entry day, side, exit day, stop, spread, Friday rule, or
lifecycle change is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and timestamps from the registered factory route.
- Broker clock, symbol quotes/properties, positions, deal history, and terminal
  global variables.
- No continuous-futures file, roll map, inventory, volume, open interest,
  curve, event calendar, API, CSV, optimizer artifact, or manual signal input.

## Source-Defined Rules

The paper defines the WTI calendar days 1-15 population and reports its
negative average-return sign. It does not define the CFD host, first-session
entry, D1-label normalization, attach ceiling, risk, stop, attempt, or exit
repair.

## QM Interpretations

QM fixes the registered continuous-CFD carrier, first genuine month boundary,
uniform energy label convention, late-entry ceiling, persistent attempt,
short-only side, fixed cash risk, ATR stop, spread ceiling, first day-ge-16
exit, disabled Friday close, and stale repair. They are pre-result choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and order handling remain authoritative. Both news axes
and framework Friday close are OFF. This non-live card creates no live mapping,
deployment manifest, execution-contract registry row, or promotion entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. The first later D1 bar dated 16 or greater is the ordinary exit.
4. The 20-day close repairs only a survivor.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and terminal-global attempt
state. It has no external feed, fitted artifact, trained output, optimizer
artifact, or manual signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
in any full post-warm-up year, nonpositive governed economics, wrong label
convention, non-boundary/late entry, wrong side, repeated attempt, missing
fixed stop, Friday truncation, late ordinary exit, nondeterminism, invalid risk
mode, or insufficient local history. Any change to carrier, entry/exit dates,
side, attempt, risk, stop, or hold creates a new identity. Q09 alone may
establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, normalized month boundary, attach/day gates, attempt, short side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus bounded helpers |
| malformed, day-ge-16, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| hard stop and lifecycle close reason | Trade Close | `Strategy_ExitSignal` and framework close services |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full year;
zero trades; nonpositive governed economics; wrong label/month boundary;
entry after day 5 or attachment ceiling; wrong side; retry; missing stop;
failure to exit at the first later day-ge-16 bar; Friday truncation;
nondeterminism; or registry/risk mismatch.

No weak result may be rescued by changing date bounds, adding a price filter,
switching direction, enabling Friday close, changing stop/risk/hold, or adding
inventory, event, trend, curve, volume, or external data.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label fixtures detect only a genuine month boundary,
   including weekend month starts, and reject malformed conventions;
2. day 1-5 plus 180-minute attachment rules accept only the opening segment;
3. the attempt is persisted before every fallible gate and recovered from
   same-month positions/deals after terminal-state loss;
4. entry is SELL only and fixed-risk sizing uses a frozen completed-bar ATR
   hard stop with no target;
5. the first later D1 bar dated 16 or beyond closes exposure, including a
   weekend where no bar is dated exactly 16;
6. malformed and 20-day survivor repairs remain reachable while Friday close
   stays disabled; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-29 | initial WTI first-half-of-month short card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-29 | APPROVED; R1-R4 PASS | `decisions/2026-08-29_qm5_41200_wti_first_half_month_short_g0.md` |
| Q01 Build Validation | 2026-08-29 | NOT_BUILT | pending governed build |
| Q02 Baseline Screening | 2026-08-29 | NOT_ENQUEUED_Q01_PENDING | no work item yet |

## Safety Boundary

This card authorizes only one non-live V5 build, one exact D1 `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue if capacity permits. It
does not authorize a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate mutation, portfolio admission, or a correlation waiver.
