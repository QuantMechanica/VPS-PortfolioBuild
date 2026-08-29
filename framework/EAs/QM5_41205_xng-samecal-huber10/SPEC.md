# QM5_41205_xng-samecal-huber10 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41205

- EA ID: `QM5_41205`
- slug: `xng-samecal-huber10`
- strategy ID: `KELOHARJU-HUBER-XNG-SAMECAL10-2026_S01`
- source ID: `KELOHARJU-HUBER-XNG-SAMECAL10-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-HUBER-XNG-SAMECAL10-2026/source.md`
- source approval:
  `decisions/2026-08-29_xng_same_calendar_huber10_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41205_xng-samecal-huber10_card.md`
- G0 decision:
  `decisions/2026-08-29_qm5_41205_xng_same_calendar_huber10_g0.md`
- host/traded symbol: exact `XNGUSD.DWX`, D1, slot 0
- deterministic magic: `412050000`

## 1. Strategy Logic

At the first genuine normalized D1 broker-month boundary in `(Y,M)`, load
the completed XNG log return for calendar month `M` in every exact year
`Y-1..Y-10`. All ten observations are mandatory.

Sort the ten returns and set the initial location to the even median
`(s[4]+s[5])/2`. Sort their absolute deviations from that location and
compute the raw even MAD `(a[4]+a[5])/2`. Freeze
`scale=1.4826*MAD` and `delta=1.5*scale`. Starting at the median, perform
exactly 32 updates with weight 1 inside `delta` and
`delta/abs(r_i-mu)` outside it. Follow the sign of the final location beyond
the inclusive `1e-12` flat band until the next month.

Persist `yyyymm` before every fallible gate. A failure consumes the month.
No current-month price enters the signal, no historical year is substituted,
and no alternate estimator is a fallback.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | exact historical years |
| `strategy_required_observations` | 10 | exact raw-return count |
| `strategy_mad_normalizer` | 1.4826 | frozen robust scale constant |
| `strategy_huber_tuning` | 1.5 | bounded-influence threshold |
| `strategy_huber_steps` | 32 | exact reweight updates |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance |
| `strategy_max_hold_days` | 35 | survivor repair |
| `strategy_max_spread_points` | 3000 | XNG entry cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`.
- Symbol slot: `0`; deterministic magic: `412050000`.
- One direct XNG leg only; no hedge, companion, conversion, or external feed.

## 4. Timeframe

Execution and structural clock are D1. Entry is at most once per broker month.
Formation uses ten disjoint observations of the upcoming calendar month in
the exact prior ten years. Ordinary exit is the next broker-month boundary.

## 5. Expected Behaviour

The pre-result cadence prior is roughly ten to twelve completed positions per
full post-warm-up year. An invalid label convention, missing year,
nonpositive MAD/scale, invalid update, risk failure, cost gate, or rejected
submission may consume a month flat. Q02 retires below five completed
positions in any full scored year. Q09 alone may establish realized
correlation with the current book.

### Duplicate Boundary

Canonical preallocation dedup scanned 4,704 registry identities, 1,350 cards,
and 45 Strategy Wiki nodes. It found no exact identity and the expected fuzzy
neighbors `QM5_20100` (raw XNG same-calendar mean) and `QM5_41204` (same Huber
statistic on WTI). The candidate is an explicit governed carrier/statistic
conjunction, not a globally new estimator family. Its approved disagreement
vector makes the XNG Huber rule SELL while the raw XNG mean and signed rank
BUY; QM5_12567 observes a trend-filtered cumulative-RSI2 pullback instead.
Receipt:
`artifacts/qm5_xng_samecal_huber10_preallocation_dedup_20260829.json`.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, supply the same-calendar return object, explicit natural-gas
membership, monthly renewal, and history floor. Huber (1964), *Annals of
Mathematical Statistics* 35(1), 73-101, supplies the bounded-influence
location family. The governed arithmetic packet fixes the estimator details
without transferring its WTI carrier claims. The exact XNG conjunction is a
transparent QM translation; no source performance or decorrelation result
transfers.

## 7. Risk Model

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A valid position receives one frozen
`3.5*ATR(20,D1)` hard stop and no target. Both news axes, legacy news, and
framework Friday close are OFF.

The EA owns at most one position. It closes malformed, duplicate, wrong-side,
missing-stop, cross-month, or 35-day stale exposure. No scale-in, grid,
martingale, hedge, pyramid, trail, break-even, partial exit, target, or
reversal is authorized.

## Framework Alignment

| Card rule | Implementation |
|---|---|
| exact host, identity, fixed risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| uniform label normalization and genuine month boundary | decision-clock helpers |
| exact historical endpoints | completed-month helper |
| even median/MAD, frozen scale, weights, and exact 32 updates | Huber signal helpers |
| durable consumed month and history recovery | attempt helpers and `Strategy_PrepareDecisionSignal` |
| strict sign, spread, quote, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, later-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native order, sizing, kill switch, and telemetry | V5 framework wiring |

## Validation Contract

Q01 must pass independent calendar, exact-year, median, MAD, fixed-scale,
weight, exact-update-count, fixed-vector, attempt, and lifecycle fixtures;
approved-card schema lint; registry/resolver checks; symbol scope; spec
validation; strict compile with zero errors and warnings; setfile validation;
and static build checks.

Zero trades, fewer than five completed positions in any full scored year,
nonpositive governed economics, label or endpoint drift, missing year, wrong
median, MAD, scale, weight, update count, or side, retry, missing stop, late
exit, nondeterminism, or fixed-risk drift retires rather than tunes this
identity.

## Safety Boundary

This is a non-live branch build. It creates no live/demo/shadow/stress preset,
deployment manifest, execution-contract registry row, portfolio-gate change,
portfolio admission, or promotion entitlement. Agents never toggle
AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-29 | G0-approved XNG exact-ten-year same-calendar fixed-scale Huber build |
