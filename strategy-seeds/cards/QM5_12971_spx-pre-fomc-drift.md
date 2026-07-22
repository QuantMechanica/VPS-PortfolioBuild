---
strategy_id: SRCCEO-ANOMALY-SLATE-2026-07-03_S03
source_id: CEO-ANOMALY-SLATE-2026-07-03
ea_id: QM5_12971
slug: spx-pre-fomc-drift
status: APPROVED
base_lineage_status: APPROVED
research_amendment_version: _v2
created: 2026-07-10
created_by: Research
last_updated: 2026-07-11

strategy_type_flags:
  - session-close-seasonality
  - time-stop
  - atr-hard-stop
  - news-blackout
  - long-only

source_citations:
  - type: paper
    citation: "Lucca, David O., and Emanuel Moench. (2015). The Pre-FOMC Announcement Drift. The Journal of Finance 70(1), 329-371. DOI: 10.1111/jofi.12196. New York Fed Staff Report 512, revised August 2013."
    location: "Staff Report pp. 2-11, especially pp. 3 and 10-11; Table 2"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Kurov, Alexander, Marketa Halova Wolfe, and Thomas Gilbert. (2021). The Disappearing Pre-FOMC Announcement Drift. Finance Research Letters 40, 101781. DOI: 10.1016/j.frl.2020.101781."
    location: "Abstract; Analysis; Table 1; Table 2; Conclusion"
    quality_tier: A
    role: supplement
  - type: other
    citation: "Board of Governors of the Federal Reserve System. FOMC meeting calendars and historical meeting materials."
    location: "Regular meeting decision dates for 2018-2025; unscheduled meetings, notation votes, and cancelled meetings excluded"
    quality_tier: A
    role: supplement

sources:
  - "[[sources/lucca-moench-prefomc-2015]]"
  - "[[sources/kurov-prefomc-decay-2021]]"
  - "[[sources/fed-fomc-calendar]]"
concepts:
  - "[[concepts/pre-fomc-drift]]"
  - "[[concepts/news-trade]]"
indicators:
  - "[[indicators/economic-calendar]]"
  - "[[indicators/atr-stop]]"

markets: [indices]
timeframes: [H1]
primary_target_symbols: [SP500.DWX]
target_symbols: [SP500.DWX]
single_symbol_only: true
period: H1

expected_pf: 1.10
expected_dd_pct: 3.0
expected_trade_frequency: "approximately 8 scheduled regular FOMC decisions per year"
risk_class: medium
gridding: false
scalping: false
ml_required: false

g0_status: APPROVED
pipeline_phase: Q07_FAIL
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS

modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk:
  - model4_every_real_tick
  - risk_mode_dual
  - news_pause_default
  - darwinex_native_data_only
  - enhancement_doctrine
target_modules:
  - Strategy_NoTrade
  - Strategy_EntrySignal
  - Strategy_ManageOpenPosition
  - Strategy_ExitSignal
---

# Strategy Card Amendment — QM5_12971 Pre-FOMC Drift, Event-Flat

> **Lineage decision:** this is an approved-for-testing `_v2` amendment to the already
> registered and G0-approved `QM5_12971_spx-pre-fomc-drift`, not a new strategy and not a
> request for a new EA ID. The source, directional thesis, market, and event window are the
> same. The amendment freezes the exact `.DWX` realization tested during the 2026-07-10 secret
> research mission. Its independent FTMO pipeline stopped at Q07 on 2026-07-11.

> **OWNER approval (2026-07-11):** the `_v2` amendment is approved for implementation and
> independent FTMO pipeline testing under the existing EA ID. This approval does not authorize
> live deployment.

## 1. Source

The primary source is Lucca and Moench's full 63-page New York Fed Staff Report 512 and its
published Journal of Finance version. Kurov, Wolfe, and Gilbert is a mandatory counter-source:
it extends the evidence through 2019 and reports material post-2015 decay. Official Federal
Reserve calendars define the eligible events; P&L must never determine which dates are included.

## 2. Concept

The strategy seeks the anticipatory U.S.-equity return before a scheduled FOMC decision while
remaining flat for the announcement shock. It holds `SP500.DWX` long from the prior day's
approximately 14:00 ET point until approximately 13:00 ET on the decision day, with a volatility-
scaled stop used only as catastrophic protection and sizing anchor.

This is not an event-direction forecast. It does not infer whether the Fed will hike, cut, or hold,
and it never opens or retains a position through the statement.

## Hypothesis

Regular, pre-announced FOMC decisions concentrate attention and uncertainty-resolution flows in
the preceding session, creating a positive equity-index drift before the statement. Because later
published evidence finds substantial decay, the forward hypothesis is deliberately weak: the edge
may persist intermittently, but must survive modern `.DWX`, cost, timing-neighborhood, and
Model-4 validation before it can advance.

## 3. Markets & Timeframes

```yaml
markets:
  - indices
timeframes:
  - H1
primary_target_symbols:
  - SP500.DWX
```

- Signal and execution clock: `SP500.DWX` H1 broker time.
- Calendar: regular FOMC policy-decision dates only.
- Emergency/unscheduled meetings, notation votes, and cancelled meetings are excluded.
- The partial 2018 research sample used only the two press-conference decisions available after
  local `.DWX` history began. From 2019 onward, all regular decisions are included.

## Rules

Long one `SP500.DWX` position at the frozen pre-event clock, close it one hour before the
scheduled statement, and use a prior-D1 ATR stop only as an emergency backstop. No directional
event bet, discretionary filter, or post-event re-entry is permitted.

## 4. Entry Rules

```text
- Load a versioned calendar of official regular FOMC decision dates.
- Evaluate the signal once per new SP500.DWX H1 bar in broker time.
- Let D be an eligible decision date.
- At broker 21:00 on calendar day D-1, BUY SP500.DWX at market.
- If no broker-21:00 H1 opportunity exists on D-1, skip D; do not use a make-up entry.
- Before entry, read ATR(14) from the prior completed D1 bar.
- Place a fixed emergency stop at entry_price - 2.0 * prior_completed_D1_ATR(14).
- Size from actual entry-to-stop loss using the active V5 risk mode.
- Require no existing position for this EA magic and symbol.
- Mark D consumed on successful entry; never re-enter for the same decision.
```

The entry is approximately 14:00 ET under the validated NY-close broker convention. Clock
conversion must be verified against broker DST behavior; the rule is not a hard-coded UTC hour.

## 5. Exit Rules

```text
- At broker 20:00 on decision date D, close the full position at market.
- The emergency ATR stop may close the position earlier.
- If the stop fires, do not re-enter for D.
- No take-profit, trailing stop, break-even move, partial close, or opposite signal.
- Never hold through the scheduled FOMC statement.
- Framework Friday Close remains enabled; regular FOMC decisions do not require a weekend hold.
```

## 6. Filters (No-Trade Module)

```text
- Permit SP500.DWX H1 only; reject unsuffixed or broker-native aliases in research/backtest.
- Fail closed when the official event calendar is absent, stale, unversioned, or outside coverage.
- Exclude emergency/unscheduled meetings, notation votes, and cancelled meetings.
- Skip when the prior completed D1 ATR(14) is unavailable or invalid.
- Skip when the exact broker-21:00 H1 entry opportunity is absent.
- Skip when another position exists for the same magic/symbol.
- Remain flat during the FOMC release and the framework's restricted event window.
- Retain framework kill-switch and execution checks.
```

## 7. Trade Management Rules

```text
- one position per magic/symbol
- long only
- no pyramiding
- no gridding or martingale
- no averaging or recovery orders
- no scaling or partial close
- no trailing or break-even logic
- no post-announcement re-entry
```

## 8. Parameters To Test (P3 Sweep)

These are robustness neighborhoods, not a mandate to select the best historical cell. The frozen
center remains the approved test default and any selection rule must be pre-registered before
results.

```yaml
- name: strategy_entry_hour_broker
  default: 21
  sweep_range: [20, 21, 22]
- name: strategy_exit_hour_broker
  default: 20
  sweep_range: [19, 20]
- name: strategy_atr_period_d1
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_emergency_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 3.0]
- name: strategy_event_scope
  default: regular_all
  sweep_range: [regular_all, press_conference_only]
```

Risk amount is not an optimization axis. Calendar-date inclusion is never a sweep axis.

## 9. Author Claims (verbatim)

> "the S&P500 index has on average increased 49 basis points in the 24 hours before scheduled FOMC announcements."
> — Lucca and Moench, Staff Report p. 3.

> "the pre-FOMC drift essentially disappeared after 2015"
> — Kurov, Wolfe, and Gilbert, Abstract.

These claims refer to different samples and must be presented together. Neither source reports the
specific Darwinex CFD result below.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.10
expected_dd_pct: 3.0
expected_trade_frequency: approximately 8/year
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## Risk

- Source-prescribed risk: silent.
- Required V5 backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Provisional live convention if the full pipeline and portfolio process later approve it:
  `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- The secret-mission evidence used fixed USD 250 risk. It is exploratory evidence and cannot be
  relabeled as a V5 pipeline run.
- The emergency stop is fixed at entry and never widened.
- No live deployment, AutoTrading change, or production authorization follows from this card.

## 11. Strategy Allowability Check (V5 framework)

- [x] Fully mechanical concept and clock rules.
- [x] No Machine Learning, adaptive fitting, grid, or martingale.
- [x] One position per magic/symbol.
- [x] Friday Close compatible; no weekend hold is required.
- [x] Precise source, section, page, DOI, and official-calendar citations.
- [x] Duplicate resolved as `_v2` amendment of existing `QM5_12971`, not a new card lineage.
- [x] Model 4 Every Real Tick confirmed over 2018-07-02 through 2025-12-31.
- [x] Exact broker-hour schedule and frozen 57-date calendar confirmed, including month-end dates.
- [x] V5 `RISK_FIXED=1000` baseline rerun completed deterministically.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "SP500.DWX H1 only; regular-event calendar provenance; exact-entry-bar, ATR, position, news-flat, and kill-switch gates."
  trade_entry:
    used: true
    notes: "Long at broker 21:00 on D-1 for an eligible regular FOMC decision date D."
  trade_management:
    used: false
    notes: "No active management beyond the fixed emergency SL."
  trade_close:
    used: true
    notes: "Full market exit at broker 20:00 on D, before the statement."

hard_rules_at_risk:
  - model4_every_real_tick
  - risk_mode_dual
  - news_pause_default
  - darwinex_native_data_only
  - enhancement_doctrine
at_risk_explanation: |
  The exploratory T_Export evidence used HCC/Model 1 because no custom real-tick database was
  available, so Model 4 is unproven. It used USD 250 rather than the V5 USD 1,000 fixed-risk
  baseline. The FOMC calendar is an audited local static input, not a runtime web call, but its
  provenance, freshness, and fail-closed behavior must be reviewed. The event is a signal while
  the position must still be flat for the restricted release window. The changed entry clock and
  emergency stop are entry-side `_v2` changes, so prior pipeline evidence cannot be inherited.
```

## 13. Implementation Notes (Development fills for an OWNER-approved build)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: medium
estimated_test_runtime: TBD
data_requirements: custom_news
```

Prototype implementation requirements already demonstrated but not accepted as V5 code:

- `MQL_TESTER` hard guard.
- Frozen regular-event calendar through 2025.
- `SP500.DWX` and H1 initialization guards.
- Prior completed D1 ATR(14), 2.0 multiple, fixed risk sizing.
- Exact scheduled close and per-event consumption.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-07-03 | initial local-calendar/pre-blackout build | G0 / build | APPROVED base lineage |
| _v2 | 2026-07-10 | enhancement: exact event-flat clock plus prior-D1 ATR emergency stop | Q07 | FAIL: PF variance 32.75% |

## 15. Pipeline Phase Status (current `_v2`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED amendment | this card |
| Q01 Build Validation | 2026-07-11 | PASS, 0 errors / 0 warnings | `artifacts/qm5_12971_ftmo_v2_build_result_2026-07-11.json` |
| Q02 Baseline Screening | 2026-07-11 | PASS, current-cost PF 1.730 | `artifacts/ftmo_12971_sp500_cost_reconciliation_2026-07-11.json` |
| Q03 Parameter Sweep | 2026-07-11 | N/A, frozen source realization | this card |
| Q04 Walk-Forward + Commission | 2026-07-11 | PASS | `D:\QM\reports\pipeline_ftmo_secret\12971_prefomc_v2_q04\QM5_12971\Q04\SP500.DWX\aggregate.json` |
| Q05 Stress MEDIUM | 2026-07-11 | PASS, PF 1.54 | `D:\QM\reports\pipeline_ftmo_secret\12971_prefomc_v2_q05\QM5_12971\Q05\SP500_DWX\aggregate.json` |
| Q06 Stress HARSH | 2026-07-11 | PASS, PF 1.38 | `D:\QM\reports\pipeline_ftmo_secret\12971_prefomc_v2_q06\QM5_12971\Q06\SP500_DWX\aggregate.json` |
| Q07 Multi-Seed | 2026-07-11 | **FAIL**, PF variance 32.75% | `D:\QM\reports\pipeline_ftmo_secret\12971_prefomc_v2_q07\QM5_12971\Q07\SP500_DWX\aggregate.json` |
| Q08 Statistical Validation | 2026-07-11 | STOPPED after Q07 | Q07 hard gate |
| Q09 News Mode | 2026-07-11 | STOPPED after Q07 | Q07 hard gate |
| Q10 Full-History Confirmation | 2026-07-11 | STOPPED after Q07 | Q07 hard gate |
| Q11 Portfolio | 2026-07-11 | REJECTED | not admitted after Q07 |
| Q12 Operational Readiness | 2026-07-11 | NOT RUN | no portfolio admission |
| Q13 Live Burn-In | 2026-07-11 | NOT RUN | no deployment permission |

### Independent Model-4 result

- Frozen expert SHA256: `C51887E09C3C5A8F118EB163E9DDCFB3B220E26E090822EFD3C29F3874E16EFC`.
- Full 2018-07-02 to 2025-12-31: two identical runs, 56 trades, PF 1.50,
  net +9,485.06, equity drawdown 6.05%.
- Full-year current-cost gate, 2019-2025: 54 trades, FTMO PF 1.730277,
  net +12,228.32, at least seven trades in every year.
- Q04 fold PFs: 2.646 (2023), 1.932 (2024), 1.028 (2025).
- Q07 seed PFs: 1.38, 1.47, 1.71, 1.90, 1.48. All remain profitable, but the
  32.75% PF variance exceeds the 20% hard limit. The amendment is rejected for the FTMO book.

## Secret-Mission `.DWX` Evidence (exploratory, non-pipeline)

All valid runs used `D:\QM\mt5\T_Export`, `SP500.DWX` H1, the same tester-only binary,
Model 1, and fixed USD 250 risk. No T1-T10 or T_Live evidence is used.

| Window | Trades | Net USD | PF | Win rate | Equity DD |
|---|---:|---:|---:|---:|---:|
| DEV 2018-07 to 2021 | 25 | +53.10 | 1.1048 | 56.00% | 0.29% |
| Validation 2022-2023 | 15 | +442.40 | 5.64 | 80.00% | 0.14% |
| Untouched OOS 2024-2025 | 16 | +292.94 | 2.03 | 68.75% | 0.22% |
| Descriptive full 2018-2025 | 56 | +788.44 | 1.89 | 66.07% | 0.29% |

Full-run cost columns include commission `-7.60` USD and swap `-151.21` USD. The event array
contains 57 dates, but the test history exposed only 56 exact broker-21:00 opportunities; the
2023-12-13 decision produced no entry. That discrepancy must be resolved as a data/session audit,
not silently imputed.

Evidence receipt:

- Source SHA256: `DB8ACA87DF6A5569AC22CE6338CA98EF97F15DF89A94B137CA4F69E82DCA6166`
- EX5 SHA256: `189ECBBC3D19BDEFFA55F57706D9B35B5CCFBC37786357218B6DB6BA48E6DEA7`
- Compile: 0 errors, 0 warnings, T_Export MetaEditor build 5833.
- Research report: `.private/secret_strategy_lab/MISSION_REPORT_2026-07-10.md`.
- Full report: `.private/secret_strategy_lab/pre_fomc_flat/runs/full2018_2025/report.htm`.

## 16. Lessons Captured

- 2026-07-10: Local modern `.DWX` results contradict the published decay narrative enough to
  justify review, but 56 events and Model 1 are not promotion-grade evidence.
- 2026-07-10: Event calendars are executable data; provenance, missing clock bars, exclusions,
  and version hashes must be tested like price history.
- 2026-07-10: Closing before the statement isolates anticipatory drift from announcement risk and
  makes the strategy compatible with a strict news-flat requirement.
