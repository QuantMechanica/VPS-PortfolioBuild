---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-WINSIDE-BODY-MOM-2026_S01
variant_id: MOP-WTI-WINSIDE-BODY-MOM-2026_S01
source_id: MOP-WTI-WINSIDE-BODY-MOM-2026
ea_id: QM5_41091
slug: wti-winside-body-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41091_wti-winside-body-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41091_wti_weekly_inside_body_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_inside_body_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-WINSIDE-BODY-MOM-2026/source.md"
    quality_tier: A
    role: own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-week-boundary-wti-two-consecutive-completed-weekly-ohlc-packages-newest-strictly-inside-parent-range-newest-own-open-close-body-sign-continuation-one-week-hold
sources:
  - "[[sources/MOP-WTI-WINSIDE-BODY-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-inside-week]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-week-ohlc]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-inside-week, own-week-body-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410910000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 6-15 completed WTI positions per full post-warm-up year after exact weekly history, strict containment, body inequality, and execution gates; Q02 must prove the binding activity floor or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_INSIDE_BODY_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
q01_build_report: D:/QM/reports/framework/21/build_check_20260821_132505.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41091/P1/P1_QM5_41091_result.json
review_focus: "Falsify a direct-WTI completed inside-week body continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, two consecutive completed weekly OHLC packages, three-to-five sessions each, strict full containment, contained-week own-body direction, all equality/non-inside states flat, one attempt, fixed risk, and next-week exit. Q09 alone may measure realized correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_weekly_ohlc, bounded_week_session_counts, strict_full_containment, contained_week_own_body_sign, equality_and_noninside_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete-read peer-reviewed WTI source with weekly inside-body translation risk disclosed; R2 exact labels, weeks, strict containment, body side, attempt, risk, and lifecycle; R3 registered native WTI D1; R4 deterministic one-position price arithmetic; canonical dedup CLEAN"
---

# QM5_41091 WTI Completed Inside-Week Body Momentum

## Hypothesis

When a completed WTI weekly auction is strictly contained within its parent
week but still closes directionally away from its own opening price, that
direction may represent pressure accumulating during compression. Following
the contained week's own body direction for the next broker week may capture a
low-frequency structural crude-oil continuation effect.

The direct WTI carrier is economically different from the certified
XAU/SP500/NDX/XNG book. That observation does not establish profitability,
neutrality, or decorrelation. Q02 owns frequency and baseline economics; Q09
alone may measure realized correlation; Q11 alone owns portfolio admission.

## Source Traceability And Claim Boundary

The sole source of record is
`strategy-seeds/sources/MOP-WTI-WINSIDE-BODY-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-21_wti_weekly_inside_body_momentum_source_approval.md` at
commit `9f47d0a0d`. The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons and include NYMEX WTI in their futures universe. They do not test a
weekly inside range, a contained-week candle body, a continuous CFD,
fixed-dollar ATR risk, or the QM book. Every weekly clock, range-state,
execution, and risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical fail-closed pre-allocation checker used the complete author and
mechanic fields plus the actual Company Reference Wiki root. It scanned 4,580
registry identities, 1,253 repository cards, and 45 Wiki strategy nodes and
returned `CLEAN`, with no exact or fuzzy match. Manual semantic review fixes
the load-bearing boundaries:

- `QM5_13075_xti-inweek-brk` freezes an inside week, then waits for a
  current-week D1 close beyond an extreme and adds SMA, ATR-range,
  close-location, target, and failed-breakout rules. This card consumes no
  current-week signal price and enters only at the next-week boundary from the
  completed inside week's own body.
- `QM5_41061_wti-week-nr7-brk` ranks seven weekly ranges and waits for a
  current-week breakout. This card has no range rank and no breakout.
- `QM5_41073_wti-woutside-settle` requires the opposite geometry plus
  settlement beyond a parent extreme and close-location confirmation.
- `QM5_41089_wti-wrange-migrate-mom` requires both range endpoints to migrate
  in the same direction and explicitly leaves inside geometry flat.
- `QM5_41090_wti-wmid-overlap-mom` accepts any positive overlap, compares only
  high/low midpoints, and excludes all opens and closes. This card requires
  strict full containment and derives side only from the contained week's own
  open and close.
- `QM5_41080_wti-wclose-location-mom` uses parent-close to newest-close return
  plus an outer-fifth close-location threshold. This card reads no parent close
  and has no close-location threshold.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG cumulative-RSI2
  pullback under a slow trend filter on a different carrier.

The exact WTI carrier, two consecutive completed weekly OHLC packages,
three-to-five-session contract, strict full containment, contained-week
own-body sign, boundary entry, durable attempt, and one-week hold are jointly
load-bearing.

## Markets And Timeframe

- Target symbol: exact `XTIUSD.DWX`; no alias fallback.
- Host chart: exact `XTIUSD.DWX`, D1.
- Symbol slot: zero; planned magic `410910000`.
- Decision cadence: once at the first tradable D1 bar of a normalized new
  Monday-anchored broker week.
- Runtime inputs: native MT5 D1 OHLC, ATR, quote/spread, calendar timestamps,
  owned positions, deal history, and terminal persistent state only.
- Expected frequency: approximately 6-15 trades/year before Q02 measurement.
- Hold: first tick of the next normalized broker week, normally one week.

## Rules

### Week normalization and packages

1. Apply `strategy_label_offset_seconds` uniformly to the current raw D1 bar
   and every copied historical D1 timestamp before deriving Monday anchors.
2. Evaluate only when the normalized current anchor differs from the last
   processed anchor. The current decision-week bar supplies timing only; none
   of its OHLC values may enter the signal.
3. Reconstruct exactly the immediately completed week and its parent. Their
   Monday anchors must be seven calendar days apart and must equal current
   anchor minus seven and fourteen days.
4. Each completed week must contain three to five unique, strictly increasing
   D1 sessions. Require positive finite OHLC and valid per-bar geometry.
5. Aggregate each package using the chronologically earliest session open,
   maximum high, minimum low, and chronologically final session close. Require
   aggregate high strictly above aggregate low.

### Signal

For newest completed week zero and parent week one:

```text
inside = high0 < high1 && low0 > low1
body0  = close0 - open0

inside && body0 > 0  => BUY
inside && body0 < 0  => SELL
otherwise            => FLAT
```

Every comparison is strict. Equal highs, equal lows, or equal open and close
stay flat. No minimum containment width, body magnitude, range ratio, or
signal-strength sizing exists.

### Entry Rules

1. Persist the exact normalized current-week attempt before any history,
   signal, news, spread, quote, ATR, sizing, or order gate that can fail.
2. If attachment occurs more than `strategy_entry_lateness_minutes` after the
   raw current D1 bar open, consume the week flat.
3. Stay flat unless symbol, period, magic slot, parameters, history, session
   counts, anchors, OHLC geometry, strict containment, and strict body sign all
   pass.
4. Stay flat when an owned position is open or an entry deal already exists
   for the same normalized week.
5. Stay flat when spread exceeds `strategy_max_spread_points`, the quote is
   invalid, completed-bar ATR is invalid, or fixed-risk sizing fails.
6. Freeze stop distance as `strategy_atr_stop_mult * ATR(strategy_atr_period,
   D1)` from completed bars. Enter one market position in the signal direction
   with no take-profit.

There is no retry within the week. A rejected or otherwise failed entry remains
a consumed attempt.

### Exit Rules

- Exit an owned position on the first tick whose normalized Monday anchor is
  later than the persisted entry-week anchor.
- Exit when position age reaches `strategy_stale_calendar_days`; this is a
  repair guard only, not the intended hold.
- The broker-held hard stop remains active from entry.
- There is no take-profit, signal reversal, trailing stop, break-even move,
  partial close, or discretionary exit.

## No-Trade Filters

- Exact host symbol and D1 period only.
- Exact magic slot zero only.
- Invalid or missing state fails closed.
- Both news axes are OFF because the signal uses native prices only and the
  authorized baseline must not add an external calendar gate.
- Framework Friday close is OFF so the position completes the authorized full
  weekly hold.
- Framework kill switch, weekend entry protection, broker disconnect guard,
  and one-position-per-magic protections remain active.

## Trade Management Rules

- One position for magic `410910000`; no second entry while exposed.
- Symmetric long/short mapping.
- One frozen hard stop; no target.
- No scale-in, grid, martingale, pyramid, partial close, trail, or break-even
  rule.
- Persistent attempt and entry-week state must survive restart.
- Exit failures may retry on later ticks; entry failures may not retry within
  the consumed week.

## Parameters To Test

The Q02 baseline is frozen before results. Q03 may test only the declared
bounded surface; it may not change the signal identity.

| Input | Baseline | Q03 bounded surface | Meaning |
|---|---:|---:|---|
| `strategy_label_offset_seconds` | 86400 | [0, 86400] | uniform raw-to-session label offset |
| `strategy_entry_lateness_minutes` | 180 | [120, 180, 240] | maximum elapsed minutes after the first raw week bar opens |
| `strategy_atr_period` | 20 | [14, 20, 30] | completed D1 ATR period for risk stop only |
| `strategy_atr_stop_mult` | 3.5 | [2.5, 3.5, 4.5] | frozen hard-stop distance multiplier |
| `strategy_max_spread_points` | 1500 | [1000, 1500, 2000] | entry spread ceiling |
| `strategy_stale_calendar_days` | 10 | [8, 10, 12] | repair-only maximum position age |

The strict containment relation, body-side mapping, two-week package count,
three-to-five-session bounds, boundary entry, one-attempt rule, and next-week
exit are not parameters.

## Risk

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1.0`.
- Backtest initial deposit and leverage remain the canonical tester defaults.
- Sizing uses the V5 fixed-cash risk helper and the frozen stop distance.
- The hard stop is mandatory; invalid size, tick value, quote, or stop geometry
  stays flat.
- Overnight, weekend-gap, continuous-CFD basis, energy-session-label, and
  sparse-signal risks are deliberately exposed to Q02 and later unchanged
  gates.
- No live preset is authorized or created by this card.

## Author Claims And Falsification

This card claims only that the rule is deterministic, non-duplicate by its
joint mechanic, and worth an unchanged Q02 test. Expected PF `1.01`, expected
drawdown `30%`, and frequency `6-15/year` are conservative ordering priors,
not evidence or promises.

Kill the baseline if Q02 misses the binding activity floor, lacks valid
history/fills after setup defects are excluded, or fails the unchanged
economic thresholds. Do not rescue it by relaxing strict containment, adding
current-week breakout confirmation, changing the body side, changing the
weekly hold, or adding a threshold, rank, close-location, midpoint,
moving-average, volatility-regime, inventory, event, or external-data filter.

## Strategy Allowability Check

- R1: `PASS_WITH_WEEKLY_INSIDE_BODY_TRANSLATION_RISK`. One source ID traces to
  a complete-read peer-reviewed paper with DOI and explicit WTI membership;
  the weekly inside-body translation is disclosed as untested.
- R2: `PASS`. Exact labels, anchors, OHLC aggregation, containment, body side,
  attempt, risk, stop, spread, and lifecycle are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 and native MT5 state provide all runtime data.
- R4: `PASS`. Fixed deterministic arithmetic and one-position-per-magic only;
  no trained output, adaptive PnL rule, external feed, or unbounded position
  structure.

## Framework Alignment

- no_trade: framework defaults plus exact symbol/period, slot, parameter,
  late-attachment, spread, owned-position, and same-week-entry guards.
- trade_entry: normalized week clock, two completed weekly OHLC packages,
  strict containment, own-body direction, durable attempt, ATR, quote, fixed
  risk sizing, and market order.
- trade_management: no discretionary or dynamic management; broker hard stop
  remains frozen.
- trade_close: next-week boundary exit and ten-calendar-day stale repair.
- news hook: explicit OFF/OFF axes; no external calendar read.

## Build Acceptance Contract

The build must prove exact identity, deterministic weekly aggregation, all
strict containment and equality cases, both body directions, malformed and
nonconsecutive history rejection, no current-week OHLC leakage, durable
attempt timing, fixed-risk stop sizing, next-week/stale exits, card lint,
strict compile/build checks, setfile schema, resolver identity, and a static or
reference test suite before Q02 handoff.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1-card | 2026-08-21 | new OWNER-authorized WTI structural sleeve | Q00 | APPROVED |
| v1-build | 2026-08-21 | first governed V5 implementation and fixed-risk preset | Q01 | PASS |
| v1-q02-capacity | 2026-08-21 | exact target was unqueued; whole-host CPU reached the 97% hard ceiling during paced preflight | Q02 | NOT_ENQUEUED_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Q00 Research Intake | 2026-08-21 | APPROVED | this card plus declared decision record |
| Q01 Build and Spec | 2026-08-21 | PASS | `D:/QM/reports/framework/21/build_check_20260821_132505.json`; `D:/QM/reports/pipeline/QM5_41091/P1/P1_QM5_41091_result.json` |
| Q02 Baseline | 2026-08-21 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-21_qm5_41091_wti_weekly_inside_body_q01_q02_cpu_ceiling_stop.md` |

No Q11 portfolio or live decision is made by this card.
