# QM5_41191_wti-samecal-srank - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41191

- EA ID: `QM5_41191`
- slug: `wti-samecal-srank`
- strategy ID: `KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026_S01`
- source ID: `KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md`
- source approval:
  `decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41191_wti-samecal-srank_card.md`
- G0 decision:
  `decisions/2026-08-28_qm5_41191_wti_same_calendar_signed_rank_g0.md`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `411910000`

## 1. Strategy Logic

At the first executable D1 bar of each genuine normalized broker month,
reconstruct the completed `XTIUSD.DWX` log return for the same target calendar
month in exact years `Y-1..Y-10`. Require five to ten valid observations.

Reject the complete monthly sample if any return is nonfinite or within
`1e-12` of zero, or if any two absolute returns are within `1e-12`. Rank the
absolute returns strictly from 1 through `n`, sum the ranks attached to
positive returns as `V_plus`, require the rank total `T=n(n+1)/2`, and compute
`S=2*V_plus-T`. Positive `S` buys WTI, negative `S` sells WTI, and exact zero
consumes the month flat. Score magnitude never changes risk.

Only native same-day D1 labels or one uniform `+1` calendar-day energy offset
are valid. Historical endpoints must be completed, bounded to 3,000 D1 bars,
and surrounded by bars in the exact adjacent calendar months. The signal may
not use current-month prices, average ranks, a p-value, an arithmetic mean,
median, hit rate, recent-trend confirmation, fixed month list, inventory,
curve, event, or external feed.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | valid-sample floor |
| `strategy_signal_epsilon` | 1e-12 | zero and absolute-tie boundary |
| `strategy_history_bars_d1` | 3000 | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard stop |
| `strategy_max_hold_days` | 35 | stale repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Symbol slot: `0`; deterministic magic: `411910000`.
- Single-symbol only. There is no companion, hedge, conversion, ratio, or
  external runtime symbol.

## 4. Timeframe

Execution and signal timeframe are D1. The decision clock runs only on the
first normalized D1 bar after a genuine broker-month transition. Formation
uses completed D1 endpoints for the same target calendar month in exact years
`Y-1..Y-10`; the position ordinarily renews at the next month boundary.

## 5. Expected Behaviour

The pre-result cadence prior is ten to twelve completed positions per full
post-warm-up year; exact score-zero and invalid zero/tie samples consume a
month flat. Q02 retires below five completed positions in any full post-
warm-up year. Q09 alone may establish realized correlation with the current
book.

### Duplicate Boundary

Canonical preallocation dedup scanned 4,690 EA identities, 1,341 cards, and
45 Strategy Wiki nodes. Expected fuzzy neighbors were reviewed and resolved:

- `QM5_20099_wti-samecal` uses the arithmetic mean;
- `QM5_41055_wti-medcal` uses the ordinary median;
- `QM5_41059_wti-samecal-hit` counts positive observations; and
- recent WTI rank/statistic variants use contiguous recent endpoints, not
  disjoint same-calendar returns from prior years.

The independent fixtures lock observations for which this signed-rank rule
opposes each neighbor. Receipt:
`artifacts/qm5_wti_samecal_srank_preallocation_dedup_20260828.json`.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), “Return Seasonalities,” *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supplies the
same-calendar return object and crude-oil membership. R Core Team
`stats::wilcox.test`, pinned at public `wch/r-source` commit
`bac583951b728e97b9786804d3b4081f0fe18df5`, supplies the one-sample signed
absolute-rank arithmetic. The governed composite packet is
`strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md`.
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
| exact completed same-calendar endpoints, strict ranks, invariants, score | `Strategy_LoadSignedRankSignal` and helpers |
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
wrong ranks/score, retry, or risk/lifecycle drift retires rather than tunes the
identity.

## Safety Boundary

This is a non-live branch build. It creates no live/demo/shadow/stress preset,
deployment manifest, execution-contract registry row, portfolio-gate change,
or promotion entitlement. Agents never toggle AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-28 | G0-approved WTI same-calendar signed-rank build |
