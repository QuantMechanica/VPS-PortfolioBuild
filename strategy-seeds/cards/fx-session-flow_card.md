---
strategy_id: SRC09_S01
source_id: SRC09
ea_id: 4006
slug: fx-session-flow
status: APPROVED
created: 2026-07-17
created_by: Research
last_updated: 2026-07-17
approval_basis: "OWNER delegated the terminal technical release on 2026-07-17 with: 'mach weiter, gib du frei, wir brauchen ein komplettes Buch!'. Independent Quality-Business changes were resolved and the CEO/CTO build contract was frozen before implementation."
strategy_type_flags:
  - intraday-session-pattern
  - atr-hard-stop
  - symmetric-long-short
  - news-blackout
review_state: APPROVED_OWNER_DELEGATED_CEO_CTO_QB_2026_07_17
---

# Strategy Card — EURUSD Session Flow

## 1. Source

source_citations:

- type: paper
  citation: "Breedon, Francis and Angelo Ranaldo. 2013. Intraday Patterns in FX Returns and Order Flow. Journal of Money, Credit and Banking 45(5), 953-965. DOI 10.1111/jmcb.12032."
  location: "Working-paper pages 4-9, especially Table 1 on page 5 and Table 2 plus strategy discussion on pages 8-9; mechanism on pages 10-15."
  quality_tier: A
  role: primary

Full working paper: https://www.econstor.eu/bitstream/10419/97343/1/690223323.pdf

## 2. Concept

Local investors, banks, and funds tend to transact foreign exchange during their own business hours and tend to be net sellers of their local currency. The resulting predictable order-flow imbalance is associated with local-currency depreciation during the local session. EURUSD is the only pair in the paper whose simple two-leg implementation remained profitable after the source's firm bid/ask costs.

The implementation trades the return pattern only. It does not ingest or predict proprietary order flow.

## 3. Markets and timeframes

markets:

- forex

timeframes:

- M15 execution and pipeline timeframe

primary_target_symbols:

- EURUSD.DWX

cross_sectional_falsification_only:

- USDJPY.DWX
- GBPUSD.DWX
- EURJPY.DWX if registered and validated
- USDCHF.DWX
- AUDUSD.DWX

The source uses hourly EBS data. M15 or M5 bars do not create the signal; they only provide a deterministic event loop around exact clock boundaries.

## 4. Entry rules

Authoritative clocks:

- European centre: Europe/London civil time, including UK daylight saving.
- US centre: America/New_York civil time, including US daylight saving.
- Broker time is never treated as UTC. Each boundary is converted independently from its authoritative civil clock to UTC and then to broker time.
- The initial build is explicitly approved to use an EA-local UK helper implementing the last-Sunday-in-March 01:00 UTC to last-Sunday-in-October 01:00 UTC rule, matching the reviewed pattern already used by QM5_10014, QM5_11020, and QM5_11021. It must expose unambiguous local/UTC/broker conversions and may later be centralized without changing strategy behavior.
- Fixture tests must cover every UK and US transition plus both mismatch-week directions for 2017-2026. Any unresolved or duplicated civil instant fails closed.

Authoritative day state:

- `strategy_day_key` is the Europe/London civil date at the scheduled 07:00 entry. The New-York boundaries for that run must resolve to the same civil date or the whole day is suppressed.
- On initialization, reconstruct the day state from the open position plus this EA's deal history for magic and symbol. Never trust volatile in-memory flags after a VPS or terminal restart.
- If a matching position exists, resume exit management only. If its scheduled exit boundary has passed, enter emergency-flatten state immediately.
- If no position exists after an entry deadline, do not catch up. A leg already present in deal history is never entered again.

Daily state machine for a valid FX business day:

    1. EU_LEG_ARMED before 07:00 Europe/London.
    2. At the first executable tick at or after 07:00 Europe/London, and no later than entry_delay_max_seconds, SELL EURUSD at market.
    3. At 08:00 America/New_York, close the EU short. Do not open the next leg until the close is confirmed and the symbol is flat.
    4. After confirmed flat state, at the first executable tick at or after 08:00 America/New_York, and no later than entry_delay_max_seconds, BUY EURUSD at market.
    5. At 16:00 America/New_York, close the US long.
    6. Mark the date complete after confirmed flat. Never retry a missed, rejected, or late entry leg.

Entry permissions:

- EURUSD.DWX only for the first build.
- At most one position for this EA and symbol.
- EU short and US long can be independently disabled for ablation, but both default enabled for the source replication.
- A failed EU close suppresses the US entry.
- No entry when the clock mapping is ambiguous, required bars are missing, no executable quote is available, or spread exceeds the predeclared execution-contract ceiling.
- No grid, averaging, pyramiding, martingale, loss progression, or re-entry.

## 5. Exit rules

Primary exits are clock-only:

- EU short: mandatory market close at 08:00 America/New_York.
- US long: mandatory market close at 16:00 America/New_York.
- No take-profit in the source.
- No trailing stop, break-even move, or partial close in the source.
- News, entry-spread, holiday, and no-trade gates may never block a required exit.
- Entry attempts are one-shot. Exit attempts are not: beginning at the scheduled boundary, retry a rejected or unconfirmed close no more than once per five seconds until the position is confirmed flat.
- After 60 seconds without confirmed flat, latch a strategy-day kill state, block every new entry, emit an operator alert, and continue close retries. A retry counter may escalate telemetry but may never abandon an open position. The latch remains active through the affected London strategy date and while any position remains; only after confirmed flat and advance to a later valid London business date may it release automatically. Account-level kill switches remain independently latched under their own policy.
- The generic Friday 21:00-broker guard would cut the Friday US leg before the source's 16:00-New-York exit. Research parity therefore requires a CTO-reviewed per-EA exception: disable that generic entry/flatten cutoff for this EA and use the independently converted Friday 16:00-New-York mandatory exit plus the retry/escalation rule above.
- Any position surviving its New-York civil date is flattened immediately on restart/tick before all other strategy actions.

Protective stop:

- Source silent. The approved non-alpha catastrophic stop is 1.0 times prior closed D1 ATR(20), frozen at entry, so the V5 risk engine can size a bounded loss.
- The sole Q03 axis is `strategy_stop_atr_mult = [0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00]`; all clock, direction, delay, spread, risk-weight, and holiday settings remain locked. The plateau median is selected before any holdout.
- The diagnostic no-stop shadow must use the same virtual ATR stop for volume sizing; it is never deployment-eligible.
- OWNER-delegated CEO/CTO and independent Quality-Business review ratified the implementation-only safety overlay, pre-holdout plateau rule, and family risk budget on 2026-07-17.

## 6. Filters (No-Trade module)

Framework defaults:

- kill switch and account-level risk governor always active,
- one position per magic and symbol,
- broker disconnect and invalid-quote fail closed,
- generic Friday 21:00-broker guard requires the documented per-EA exception above; the strategy-specific Friday 16:00-New-York exit is mandatory,
- no external runtime market data.

Strategy-specific gates:

- exact civil-clock and DST mapping must resolve uniquely,
- skip the affected leg if no executable quote occurs within entry_delay_max_seconds,
- source-faithful holiday mode uses tradable FX quote days and no external calendar. A conservative centre-holiday ablation is allowed only after a versioned static calendar is reviewed and bound as a build artifact; no network or implicit runtime calendar is permitted,
- P2 execution contract is frozen ex ante: native Model-4 bid/ask ticks, entry-only maximum spread 30 points on five-digit EURUSD, FTMO snapshot dated 2026-07-17 with USD 5 per lot round trip, swap long -9.36 points and swap short +0.22 points, plus post-test 2x commission/spread/slippage stress. No spread ceiling may block an exit and no value may be selected on strategy outcome,
- baseline news mode is OFF for source replication; P8 must measure OFF, FTMO Swing-compatible, and conservative pause variants. News filtering never blocks exits.

## 7. Trade Management Rules

- No discretionary management.
- No position additions.
- No direction flip until the first leg is confirmed closed.
- If an emergency protective stop closes a leg, that leg is complete and is not retried.
- Phase 1 uses 0.25 percent planned risk per leg and no more than 0.50 percent planned family risk per strategy day. Phase 2 applies the target-book 0.70 multiplier; funded sizing follows the lower funded band. Backtests use RISK_FIXED 1000 per leg only for comparable research metrics.
- The US leg is suppressed when same-day realized family P/L is at or below minus one planned leg-risk budget, when adding it would exceed the 0.50-percent planned family budget, or when a daily/cluster governor is locked. Slippage can exceed planned risk, so the account governor remains authoritative. Both legs are one strategy family and never receive independent portfolio budgets.
- Restart recovery, mandatory-exit retries, kill-state escalation, and date-rollover flattening apply exactly as specified in sections 4 and 5.
- Structured events must record authoritative local time, UTC time, broker time, DST state, scheduled boundary, actual fill time, delay, spread, and exit reason.

## 8. Parameters to test

Source-locked parameters:

| name | default | authorized test |
|---|---|---|
| symbol | EURUSD.DWX | EURUSD primary only; other source pairs P3.5 falsification |
| eu_timezone | Europe/London | fixed |
| eu_entry_local | 07:00 | fixed; no hour search |
| eu_direction | short | fixed |
| eu_exit_clock | 08:00 America/New_York | fixed |
| us_timezone | America/New_York | fixed |
| us_entry_local | 08:00 | fixed; no hour search |
| us_direction | long | fixed |
| us_exit_local | 16:00 | fixed |
| enable_eu_leg | true | true and false ablation |
| enable_us_leg | true | true and false ablation |
| execution_period | M15 | fixed |

Implementation-safety parameters, not source claims:

| name | proposed default | authorized test |
|---|---:|---|
| entry_delay_max_seconds | 300 | 60, 120, 300 as execution stress, not alpha optimization |
| exit_retry_interval_seconds | 5 | fixed |
| exit_escalation_seconds | 60 | fixed |
| protective_stop_atr_period_d1 | 20 | fixed if ratified |
| protective_stop_atr_mult | 1.0 | sole Q03 axis: 0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00; plateau median |
| max_spread_points_by_boundary | 30 | fixed; entry-only; 2x execution-cost stress after baseline |
| entry_slippage_pips_per_side | 0.25 | 0.00, 0.25, 0.50, 1.00 stress |
| holiday_mode | source_replication | source_replication; static-calendar ablation only after artifact review |

Current official FTMO EUR/USD snapshot for cost-model seeding, not a substitute for the pre-P2 boundary capture: 2026-07-17, contract size 100,000, flat USD 5 commission per lot round trip, swap long -9.36 points, swap short +0.22 points, five digits. Source: `https://ftmo.com/wp-json/ftmo/symbols` (`EUR/USD`).

## 9. Author claims

- "local currencies tend to depreciate during their own trading hours" — working-paper page 3.
- "Sharpe Ratios of 1.3 and 0.9 respectively" — EURUSD morning short and afternoon long, working-paper page 9.

The paper also reports that most simple pair implementations were not profitable after costs. The positive EURUSD result covers 1997-2007 EBS conditions and is not a current FTMO performance claim.

## 10. Initial risk profile

expected_pf: TBD

expected_dd_pct: TBD

expected_trade_frequency: approximately two legs per valid FX business day; about 38-42 raw legs per 20 trading days before skips

risk_class: medium-high because session holds cross scheduled macro-release times and the source gives no stop-loss study

gridding: false

scalping: false

ml_required: false

Source risk statement: silent. Use V5 RISK_FIXED 1000 per leg for backtests, with the ratified real or virtual protective stop supplying the sizing distance. The FTMO target-book proposal is 0.25 percent per leg and no more than 0.50 percent realized family loss per strategy day after all portfolio gates; it is not a card-level deployment authorization.

## 11. Strategy allowability check

- [x] Mechanical concept and deterministic entry/exit clocks.
- [x] No machine learning.
- [x] No grid, martingale, averaging, or pyramiding.
- [x] Friday-close exception and strategy-specific Friday exit ratified by OWNER-delegated CTO; transition fixtures are a P1/Q02 hard gate.
- [x] Darwinex-native price and time data only.
- [x] Primary source citation is reproducible to table and page.
- [x] Near-duplicate audit completed against QM5_10012 and fx-early-asia-drift.
- [x] EA-local UK civil-time helper pattern reviewed; 2017-2026 transition fixtures required in OnInit.
- [x] Protective stop overlay, virtual-shadow sizing, and family daily-loss contract ratified by independent Quality-Business review plus OWNER-delegated CEO/CTO.
- [x] Pre-P2 execution-cost contract frozen ex ante from native Model-4 ticks and the dated FTMO snapshot.
- [x] SRC09 and sequential production EA ID 4006 confirmed in the local canonical registries; OWNER authorization is recorded in the repository.
- [x] Card receives terminal APPROVED verdict under OWNER-delegated CEO/CTO after independent Quality-Business changes were resolved.

## 12. Framework alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Civil-clock/DST validity, quote validity, entry delay, entry-only spread contract, reconstructed day state, one-position state, kill switch, and daily/family/cluster governors."
  trade_entry:
    used: true
    notes: "Two-stage day state machine; EU market short and, only after confirmed close, US market long. Entry attempts are one-shot."
  trade_management:
    used: false
    notes: "No source-authorized trailing, break-even, partial close, grid, pyramid, or discretionary action."
  trade_close:
    used: true
    notes: "Mandatory clock exits at 08:00 and 16:00 New York, repeated-until-flat close recovery, protective stop, rollover recovery, and framework emergency exits."
```

hard_rules_at_risk:

- friday_close
- risk_mode_dual
- model4_every_real_tick
- enhancement_doctrine
- kill_switch_coverage
- news_pause_default

at_risk_explanation:

- Risk sizing needs a ratified protective stop because the source is silent.
- Real-tick ordering is load-bearing at the 08:00 close-then-open boundary.
- The source's Friday 16:00-New-York exit is later than the generic Friday 21:00-broker cutoff and requires a reviewed exception plus mandatory custom flattening.
- Session hours, directions, and clock zones are entry logic; changing them invalidates prior evidence.
- Both legs must aggregate to one strategy-family risk budget.
- Major releases occur inside both holding windows; P8 must measure the impact without allowing a news gate to block exits.

## 13. Implementation notes

target_modules:

- no_trade: civil-clock/DST validity, reconstructed day state, entry-delay/spread gates, one-position state, daily-family lock
- entry: source-locked two-leg state machine with prior-D1 ATR catastrophic stop and V5 risk sizing
- management: none beyond framework defaults
- close: mandatory New-York clock exits, retry-until-flat escalation, restart/date-rollover recovery

estimated_complexity: large

estimated_test_runtime: 2-4 hours per full two-run baseline cell, depending on real-tick synchronization

data_requirements: standard Darwinex EURUSD.DWX real ticks; reviewed UK/US civil-time conversion; blind pre-P2 FTMO boundary-cost capture; optional versioned static holiday calendar only if separately approved; no runtime network data

Implementation must reuse reviewed central time-conversion helpers. It may not copy the rejected broker-wallclock-as-UTC assumption from fx-early-asia-drift.

## 14. Pipeline history

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-07-17 | initial extraction | G0 | CHANGES_REQUIRED |
| _v2 | 2026-07-17 | resolved Quality-Business changes; froze safety, time, risk, cost, and Q03 contracts | G0 | APPROVED |

## 15. Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-17 | APPROVED | canonical `skill_g0_card_lint.py` PASS; independent Quality-Business changes resolved; OWNER-delegated terminal verdict recorded in v2 |
| P1 Build Validation | 2026-07-17 | PASS | EA ID 4006/magic 40060000; strict compile/build check 0 errors and 0 warnings; build report `D:\\QM\\reports\\framework\\21\\build_check_20260717_100152.json` |
| P2 Baseline Screening | 2026-07-17 | INFRA_FAIL_UNDECIDABLE | T1/T2/T3/T4 all failed before valid bars with `EURUSD.DWX: history synchronization error`; final T4 evidence `D:\\QM\\reports\\pipeline\\QM5_4006_fx-session-flow\\Q02_recovery_T4\\QM5_4006\\20260717_102256\\summary.json`; no strategy metrics and no promotion |
| P3 Parameter Sweep | TBD | NOT_STARTED | no session-hour mining authorized |
| P3.5 CSR | TBD | NOT_STARTED | source-pair falsification only |
| P4 Walk-Forward | TBD | NOT_STARTED | TBD |
| P5 Stress | TBD | NOT_STARTED | current FTMO costs plus 2x stress |
| P5b Calibrated Noise | TBD | NOT_STARTED | entry delay and close/open ordering |
| P5c Crisis Slices | TBD | NOT_STARTED | macro releases, holidays, DST mismatch weeks |
| P6 Multi-Seed | TBD | NOT_STARTED | TBD |
| P7 Statistical Validation | TBD | NOT_STARTED | TBD |
| P8 News Impact | TBD | NOT_STARTED | OFF versus conservative variants |
| P9 Portfolio Construction | TBD | NOT_STARTED | same family as QM5_10012 unless independence proven |
| P9b Operational Readiness | TBD | NOT_STARTED | FTMO 2-Step Swing only in target-book proposal |
| P10 Shadow Deploy | TBD | NOT_STARTED | OWNER manifest required |
| Live Promotion | TBD | PROHIBITED | no deployment approval |

## 16. Lessons captured

- 2026-07-17: A fixed two-session rule from a primary paper is mechanically distinct from selecting the best M30 slot in-sample.
- 2026-07-17: Broker-wallclock reconstruction and Europe/US DST mismatch weeks are pre-Q02 hard gates because an earlier early-Asia candidate was a rollover-time artifact.
- 2026-07-17: Quality-Business review found that the generic Friday 21:00-broker flatten would truncate the source's Friday US leg; the card now requires a reviewed exception and an independently converted 16:00-New-York mandatory exit.
- 2026-07-17: Entry retry and exit recovery are different contracts: entries are one-shot, while exits retry and escalate until confirmed flat, including after restart.
- 2026-07-17: Revised card passes the canonical G0 template linter; the legacy schema linter still demands obsolete `Hypothesis/Rules/Risk` headings and must be reconciled at process level.
