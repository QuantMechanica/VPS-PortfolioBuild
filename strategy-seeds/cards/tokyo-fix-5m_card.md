---
strategy_id: SRCCEO-ANOMALY-SLATE-2026-07-03_S07
source_id: CEO-ANOMALY-SLATE-2026-07-03
ea_id: QM5_13122
slug: tokyo-fix-5m
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
approved: 2026-07-10
approved_by: "OWNER decision after Quality-Business review"
ea_id_allocated_by: "Development through the deterministic registry under OWNER authorization"
g0_approval_reasoning: "R1 PASS peer-reviewed Ito/Yamada source; R2 PASS exact 09:50/09:55/10:00 JST lifecycle; R3 PASS native USDJPY.DWX M1/M5 real ticks; R4 PASS no ML/grid/martingale. Fixed non-optimized risk and execution controls are governance constraints, not fitted parameters."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
source_citations:
  - type: peer_reviewed_paper
    citation: "Ito, Takatoshi; and Yamada, Masahiro (2017). Puzzles in the Tokyo fixing in the forex market: Order imbalances and Bank pricing. Journal of International Economics 109, 214-234. DOI 10.1016/j.jinteco.2017.09.005."
    location: "Section 5.2 and Figure 6; working-paper pages 23-24 and 43; published pages TBD"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Ito, Takatoshi; and Yamada, Masahiro (2016). Puzzles in the Forex Tokyo Fixing: Order Imbalances and Biased Pricing by Banks. NBER Working Paper 22820."
    location: "Complete 48-page paper; especially Sections 3, 5.1, 5.2, Figure 6, and Tables 2-4"
    quality_tier: A
    role: supplement
  - type: official_calendar
    citation: "Bank of Japan. Holiday Schedule of the Bank."
    location: "https://www.boj.or.jp/en/about/outline/holi.htm"
    quality_tier: A
    role: implementation_calendar
  - type: official_calendar
    citation: "Cabinet Office, Government of Japan. National Holidays CSV, 1955-2027."
    location: "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv; retrieved 2026-07-10; SHA-256 BCAF48AF959CFA536C21A492F23BA52EEA954D64D872BF9E06F9ACE746F7C4A3"
    quality_tier: A
    role: implementation_calendar_data
sources:
  - "[[sources/CEO-ANOMALY-SLATE-2026-07-03]]"
concepts:
  - "[[concepts/tokyo-fix-nakane]]"
  - "[[concepts/fix-flow-reversal]]"
indicators: []
strategy_type_flags: [intraday-session-pattern, intraday-day-of-month, time-stop, scalping]
target_symbols: [USDJPY.DWX]
primary_target_symbols: [USDJPY.DWX]
markets: [forex]
single_symbol_only: true
period: M1
timeframes: [M1, M5]
expected_trade_frequency: "One long/short cycle per eligible Japanese business day; about 240-255 cycles/year in the all-days source baseline."
expected_trades_per_year_per_symbol: 250
expected_pf: TBD
expected_dd_pct: TBD
risk_class: high
ml_required: false
pipeline_phase: Q02_FAIL
research_verdict: RETIRED_NO_PARAMETER_RESCUE
review_focus: "Cost and latency survival of the source's exact five-minute long/five-minute short Tokyo-fix cycle; no inference from the existing broad Gotobi EA."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [model4_every_real_tick, scalping_p5b_latency, news_pause_default, risk_mode_dual, kill_switch_coverage]
---

# Tokyo Fix Five-Minute Long/Short Cycle

## Source Boundary

The complete 48-page NBER working paper was read, including the empirical
methods, robustness discussion, figures, tables, conclusion, and references.
The local approved-source copy is:

`D:\QM\strategy_farm\sources\CEO-ANOMALY-SLATE-2026-07-03\Ito_Yamada_NBER_w22820.pdf`

SHA-256:
`5E86CBA5B82F18D2881E5A6CABF7BB4A85BE007DCB6F59E7B191E59B70D6CDB2`.

This is a distinct extraction from `QM5_12969`. That EA buys near 02:00 JST
on Gotobi days and holds for roughly seven and a half hours. This card follows
the paper's explicit five-minute-before/five-minute-after experiment around
09:55 JST and therefore has a different entry, reversal, exit, density, cost
surface, and falsification test.

## Hypothesis

Predictable importer dollar demand and bank pre-hedging create upward USDJPY
pressure into the Tokyo fix. The source tests a paired intraday cycle that is
long for five minutes before the fix and short for the following five minutes,
so the second leg attempts to capture dissipation of the temporary order-flow
pressure rather than a general pre/post-fix correlation rule.

The source explicitly finds no stable negative pre/post-fix return correlation
across the broader one-to-thirty-minute tests. The exact five-plus-five-minute
cycle is the source-backed mechanism; broadening its windows or adding an
arbitrary volatility/October filter requires another card.

## Markets And Timeframes

- Primary carrier: `USDJPY.DWX`.
- Research timeframe: M1, with M5 as an exact-clock implementation cross-check.
- Fix time: 09:55 JST, derived from broker time through the validated DST-aware
  conversion layer.
- Baseline calendar: every eligible Japanese business day.
- Predeclared calendar ablations: Gotobi settlement days and final Japanese
  business day of month, reported separately and never selected in-sample.
- The paper's empirical sample is January 1999 through December 2013; no claim
  is made that the effect survives the current DWX period or realistic costs.

## Rules

The source-backed lifecycle is split into the following entry, exit, filter,
and management rules so each implementation boundary can be reviewed and
tested independently.

## 4. Entry Rules

```text
- On a valid Japanese business day, remain flat before 09:50 JST.
- At the first tradable tick of 09:50 JST, BUY USDJPY at market.
- Attach the reviewer-approved catastrophic stop; no take profit.
- At the first tradable tick of 09:55 JST, enter the short only after the long
  has been closed completely and that closure has been confirmed.
- Attach the same risk-normalized catastrophic stop; no take profit.
- Do not retry either leg that day after a rejection, stop, or close failure.
```

## 5. Exit Rules

```text
- At the first tradable tick of 09:55 JST, close the long completely.
- At the first tradable tick of 10:00 JST, close the short completely.
```

The long and short legs are separate positions under one daily lifecycle, not
simultaneous hedge exposure. A failed long close must block the short entry.

## 6. Filters (No-Trade Module)

- Fail closed on invalid JST conversion, missing M1/M5 history, stale calendar,
  invalid stop sizing, excessive spread, or an existing owned position.
- Japanese weekends and Bank of Japan closure days are ineligible. The build
  embeds the Cabinet Office national-holiday dates for 2017-2027 and adds the
  Bank of Japan closures from December 31 through January 3. Dates outside
  that audited range fail closed until the table is refreshed and reviewed.
- Framework kill switch remains authoritative throughout both legs.
- News handling remains the V5 default pending P8. The source distinguishes
  temporary fixing pressure from macro-news price discovery, so a high-impact
  Japanese release overlapping the cycle is a required P8 slice.

## 7. Trade Management Rules

- No grid, martingale, pyramiding, partial close, scale-in, trailing stop,
  break-even rule, adaptive parameter, external runtime feed, or ML.
- Friday close is immaterial because the complete cycle ends at 10:00 JST.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_long_entry_jst_hhmm` | `0950` | [`0950`] | locked source five-minute pre-fix entry |
| `strategy_switch_jst_hhmm` | `0955` | [`0955`] | locked Tokyo fix and direction switch |
| `strategy_short_exit_jst_hhmm` | `1000` | [`1000`] | locked five-minute post-fix exit |
| `strategy_calendar_mode` | `all_business_days` | [`all_business_days`] | locked all-days source baseline; ablations require separate out-of-sample evidence |
| `strategy_risk_stop_pips` | `30` | [`30`] | fixed non-optimized catastrophic stop absent from source |
| `strategy_max_spread_points` | `10` | [`10`] | fixed one-pip USDJPY entry-spread ceiling on a three-digit quote |
| `strategy_deviation_points` | `20` | [`20`] | fixed two-pip maximum order deviation |

The three clock values and five-minute leg durations are locked. The M1/M5
cross-check is a data-resolution test, not a parameter sweep.

## Author Claim

"For 15 years of this simple strategy, if the switching time is at the moment
of the Tokyo fixing (00:55GMT), the average return becomes 1.8bp." (working-paper
page 24)

Figure 6 states that transaction costs were not deducted. The paper describes
the gross result as only slightly above the bid-ask spread, so no net edge,
profit factor, or drawdown claim is imported into this card.

## Risk

- `expected_pf` and `expected_dd_pct` remain `TBD`; no net performance is
  inferred from the paper's gross basis-point average. The 30-pip stop,
  10-point spread cap, and 20-point deviation are fixed reviewer controls and
  may not be optimized to rescue a failed baseline.
- Risk class is high because two market orders and two market exits occur in a
  ten-minute window and the claimed gross edge is thin.
- Q02 must use model 4 real ticks and actual configured commission. A gross-PF
  or zero-commission PASS is invalid evidence.
- P5b must use measured VPS latency, spread, commission, and adverse slippage.
- Retire on net PF at or below the locked gate, insufficient annual cycles,
  missed-clock execution, nondeterminism, or a cost-cushion failure.
- Do not rescue a failure by shifting 09:50/09:55/10:00, selecting the best
  day-of-month subset, removing the short leg, or adding a fitted regime filter.

## Allowability Check

- [x] Approved primary source read completely.
- [x] Mechanical entry, direction switch, and close times.
- [x] Native DWX tick data; no external runtime market feed.
- [x] No ML, grid, martingale, pyramiding, or ambiguous discretionary signal.
- [x] Distinct from the broad Gotobi/Nakane-fix EA.
- [x] OWNER + Quality-Business review of the new extraction.
- [x] Development registry allocation under OWNER authorization: `QM5_13122`.
- [x] OWNER decision for catastrophic stop, spread ceiling, and holiday source.
- [ ] P5b latency calibration plan accepted before any build promotion.

## Framework Alignment

- no_trade: exact symbol/timeframe, Japanese business-day state, DST-aware JST
  clock, spread, calendar freshness, one-cycle-per-day, and flat-before-entry
  guards.
- trade_entry: market long at 09:50 JST and market short only after confirmed
  long closure at 09:55 JST, both under standard fixed-risk sizing.
- trade_management: deterministic daily state machine with rejection and
  close-failure lockout; no price-based management.
- trade_close: long at 09:55 JST, short at 10:00 JST, plus catastrophic stops.

Hard-rule risks are model-4 tick fidelity, P5b latency, news behavior around
the fix, dual risk-mode correctness, and kill-switch visibility across the
same-day direction reversal.

## Implementation Notes

```yaml
target_modules:
  no_trade: Strategy_NoTradeFilter plus entry-only calendar/history/spread gates
  entry: Strategy_EntrySignal
  management: Strategy_ManageOpenPosition
  close: Strategy_ExitSignal plus close-result state transition
estimated_complexity: medium
estimated_test_runtime: 30-90 minutes for Q02 on one T1-T5 terminal
data_requirements: native USDJPY.DWX M1 real ticks plus embedded audited 2017-2027 Bank of Japan closure calendar
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source extraction | G0 | DRAFT |
| v2 | 2026-07-10 | OWNER-delegated G0 review, controls, and ID allocation | G0 | APPROVED |
| v3 | 2026-07-10 | deterministic real-tick yearly screen at FTMO USDJPY costs | Q02 | FAIL / RETIRED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `framework/build/compile/20260710_192449/QM5_13122_tokyo-fix-5m.compile.log` |
| Q02 Baseline Screening | 2026-07-10 | FAIL | `docs/ops/evidence/FTMO_TOKYO_FIX_Q02_SCREEN_2026-07-10.md` |
| Q03 Parameter Sweep | TBD | TBD | TBD |
| Q04 Walk-Forward | TBD | TBD | TBD |
| Q05 Stress MEDIUM | TBD | TBD | TBD |
| Q06 Stress HARSH | TBD | TBD | TBD |
| Q07 Multi-Seed | TBD | TBD | TBD |
| Q08 Davey Validation | TBD | TBD | TBD |
| Q10 Full-History Confirmation | TBD | TBD | TBD |

## Lessons Captured

- 2026-07-10: The source's tested rule is a ten-minute long/short cycle; the
  existing early-Tokyo Gotobi long is a separate extraction.
- 2026-07-10: Valid 2019/2020/2021/2024 model-4 reports pooled to 1,792
  trades, PF 0.927, and -USD 7,796.79 at approximately USD 5/lot round-trip.
  The fixed source rule is retired; no parameter rescue is allowed.
