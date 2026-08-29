# QM5_41199_wti-samecal-trim5 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41199

- EA ID: `QM5_41199`
- slug: `wti-samecal-trim5`
- strategy ID: `KELOHARJU-TRIM-WTI-SAMECAL5-2026_S01`
- source ID: `KELOHARJU-TRIM-WTI-SAMECAL5-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-TRIM-WTI-SAMECAL5-2026/source.md`
- source approval:
  `decisions/2026-08-29_wti_same_calendar_trimmed_mean_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41199_wti-samecal-trim5_card.md`
- G0 decision:
  `decisions/2026-08-29_qm5_41199_wti_same_calendar_trimmed_mean_g0.md`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `411990000`

## 1. Strategy Logic

At the first executable D1 bar of each genuine normalized broker month,
reconstruct the completed `XTIUSD.DWX` log return for that same target
calendar month in every exact year `Y-1..Y-5`. All five observations are
mandatory; no skipped year or older substitute is valid.

Sort the five finite returns ascending, delete exact indexes 0 and 4, sum
indexes 1 through 3, and divide by exactly three. A middle-three mean above
`+1e-12` buys WTI; one below `-1e-12` sells WTI; the inclusive tie band
consumes the month flat. Signal magnitude never changes risk.

Only native same-day D1 labels or one uniform `+1` calendar-day energy offset
are valid. Historical endpoints must be completed, bounded to 3,000 D1 bars,
and surrounded by bars in the exact adjacent calendar months. The signal may
not use current-month prices, the full-sample mean, median, hit rate, ranks,
Winsorization, recent-return confirmation, fixed month selection, inventory,
curve, events, volume, or an external feed.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior years |
| `strategy_required_observations` | 5 | all-or-nothing sample size |
| `strategy_trim_each_tail` | 1 | delete exact minimum and maximum |
| `strategy_retained_observations` | 3 | middle-three divisor |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard stop |
| `strategy_max_hold_days` | 35 | stale repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Symbol slot: `0`; deterministic magic: `411990000`.
- Single-symbol only. There is no companion, hedge, conversion, ratio, or
  external runtime symbol.

## 4. Timeframe

Execution and signal timeframe are D1. The decision clock runs only on the
first normalized D1 bar after a genuine broker-month transition. Formation
uses completed D1 endpoints for the target calendar month in exact years
`Y-1..Y-5`; the position ordinarily renews at the next month boundary.

## 5. Expected Behaviour

The pre-result cadence prior is ten to twelve completed positions per full
post-warm-up year; missing exact history, invalid endpoints, or a tie may
consume a month flat. Q02 retires below five completed positions in any full
post-warm-up year. Q09 alone may establish realized correlation with the
current book.

### Duplicate Boundary

Canonical preallocation dedup scanned 4,698 EA identities, 1,344 cards, and
45 Strategy Wiki nodes. Expected fuzzy neighbor `QM5_20099_wti-samecal` was
reviewed and resolved. The executable distinctions are:

- `QM5_20099` averages the complete same-calendar sample;
- `QM5_41055` uses the ordinary same-calendar median;
- `QM5_41059` counts favorable same-calendar observations;
- `QM5_41191` uses centered signed absolute ranks; and
- `QM5_20270` trims a contiguous twelve-return recent path, deletes two per
  tail, and retains eight rather than exact same-calendar `Y-1..Y-5`.

Independent fixtures lock observations on which this middle-three rule
opposes the mean, median, hit-rate, and signed-rank neighbors. Receipt:
`artifacts/qm5_wti_samecal_trim5_preallocation_dedup_20260829.json`.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), “Return Seasonalities,” *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supplies the
same-calendar return object, crude-oil membership, and five-year history
floor. Moskowitz, Ooi, and Pedersen (2012), “Time Series Momentum,” *Journal
of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supplies WTI lineage; the governed parent
packet fixes bounded fixed-tail trim arithmetic. The bounded composite is
`strategy-seeds/sources/KELOHARJU-TRIM-WTI-SAMECAL5-2026/source.md`.
Neither source tests this exact direct-CFD conjunction or transfers a result.

## 7. Risk Model

The backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A valid signal receives one frozen
`3.5*ATR(20,D1)` hard stop and no target. Both news axes, legacy news, and
framework Friday close are OFF.

The normalized broker `yyyymm` is persisted before history, statistic, news,
spread, quote, ATR, sizing, margin, or submission. A failure never retries in
that month. The EA owns at most one position, closes it at the first observed
D1 bar in a later broker month, and applies a 35-day stale guard. No scale-in,
grid, martingale, hedge, pyramid, trail, break-even, partial exit, or reversal
is authorized.

## Framework Alignment

| Card rule | Implementation |
|---|---|
| exact host, identity, fixed risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| normalized month edge and durable once-per-month attempt | decision-clock and attempt helpers |
| exact completed `Y-1..Y-5` endpoints | `Strategy_CompletedMonthReturn` and loader |
| sort, exact tail deletion, retained sum/divisor, sign | `Strategy_TrimmedMeanSignal` |
| side, spread, quote, ATR, and frozen stop | `Strategy_EntrySignal` |
| malformed, later-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native framework order, sizing, kill switch, and telemetry | V5 framework wiring |

## Validation Contract

Q01 must pass the independent reference fixtures, approved-card schema lint,
registry/resolver validation, symbol scope, spec validation, strict compile
with zero errors and warnings, setfile validation, and static build checks.
Q02 alone may measure density and economics; Q09 alone may establish realized
portfolio correlation. Fewer than five completed positions in any full post-
warm-up year, zero trades, nonpositive governed economics, endpoint leakage,
missing exact history, wrong sort/trim/arithmetic, retry, or risk/lifecycle
drift retires rather than tunes the identity.

## Safety Boundary

This is a non-live branch build. It creates no live/demo/shadow/stress preset,
deployment manifest, execution-contract registry row, portfolio-gate change,
or promotion entitlement. Agents never toggle AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-29 | G0-approved WTI exact-five-year same-calendar trimmed-mean build |
