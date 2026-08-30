# QM5_41223_wti-samecal-expw4 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41223

- EA ID: `QM5_41223`
- slug: `wti-samecal-expw4`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026`
- approved source packet:
  `strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026/source.md`
- source approval:
  `decisions/2026-08-30_wti_same_calendar_exponential_weight_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41223_wti-samecal-expw4_card.md`
- G0 decision:
  `decisions/2026-08-30_qm5_41223_wti_same_calendar_exponential_weight_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412230000`

## 1. Strategy Logic

On the first executable D1 tick after a genuine normalized broker-month
transition into `(Y,M)`, reconstruct the completed WTI log return for calendar
month `M` in exact years `Y-1..Y-10`. Missing years are skipped and never
replaced; at least five valid observations are required. Lag `k` always keeps
calendar age `k-1`, including when a newer year is absent.

For every retained return `r_k`, compute the fixed four-year half-life weight:

```text
age_k         = k - 1
w_k           = 2 ^ (-age_k / 4.0)
weighted_sum  = sum(w_k * r_k)
weighted_mean = weighted_sum / sum(w_k)
```

Buy only when `weighted_mean > +1e-12`; sell only when
`weighted_mean < -1e-12`. Equality and invalid states consume flat. No current-
month price enters the signal, missing years never compress older weights, and
there is no fitted half-life or fallback estimator.

Persist the normalized broker `yyyymm` attempt before history, signal, news,
spread, quote, ATR, sizing, margin, or submission gates. Every outcome consumes
the month. An accepted position holds to the next broker month behind a frozen
hard stop, subject only to malformed-position and 40-day stale repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum exact prior years |
| `strategy_min_observations` | 5 | valid same-calendar return floor |
| `strategy_half_life_years` | 4.0 | fixed base-two calendar-year decay |
| `strategy_signal_epsilon` | 1e-12 | strict sign/tie boundary |
| `strategy_history_bars_d1` | 3000 | bounded completed-bar scan |
| `strategy_entry_grace_minutes` | 180 | normalized month-open window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale survivor repair |
| `strategy_max_spread_points` | 1500 | nonnegative entry spread ceiling |

Q02 has exactly one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Symbol slot: `0`; deterministic magic: `412230000`.
- The strategy has one direct WTI leg and no hedge, proxy, conversion, or
  external runtime data feed.

WTI adds a crude-oil carrier outside the certified XAU/SP500/NDX/XNG carrier
set. Carrier and clock difference do not establish low realized correlation;
unchanged Q09 remains the only portfolio authority.

## 4. Timeframe

Execution, endpoint reconstruction, ATR, and the structural clock are D1.
Entry is attempted at most once per broker month and only in the first 180
minutes of the normalized first D1 session. Formation uses five through ten
disjoint observations of the upcoming calendar month in exact prior years.
Ordinary exit is the first processed D1 bar of the next normalized month;
40 elapsed calendar days is only a stale-state guard.

## 5. Expected Behaviour

The pre-result cadence prior is approximately ten to twelve completed
positions per full post-warm-up year because only exact-zero or invalid
weighted states stay flat. Q02 retires the identity below five completed
positions in any full scored year, on zero trades, or on nonpositive governed
economics; it does not tune the half-life or sign boundary.

The canonical dedup receipt
`artifacts/qm5_wti_samecal_expw4_preallocation_dedup_20260830.json` found no
exact identity. The information object is a metric return mean whose influence
decays by exact calendar-year age, not an equal-weight same-calendar mean,
contiguous-month exponential trend, robust location, variance confidence
score, or binary sign score.

The load-bearing disagreement uses recent-to-old returns
`[-0.04,-0.04,-0.04,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03]`.
Their equal-weight mean is `+0.009`, so `QM5_20099_wti-samecal` buys. The
locked four-year-half-life weighted sum is negative, so this EA sells.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, supply recurring same-calendar
commodity information, explicit crude-oil membership, monthly renewal, and a
five-year floor. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`, supply explicit WTI membership, own-return
direction, and monthly renewal.

The approved governed packet fixes the base-two kernel and records its claim
boundary. Neither paper tests this exact same-calendar/year-decay conjunction,
four-year half-life, Darwinex WTI CFD translation, spread limit, fixed-risk
sizing, ATR stop, or current portfolio. The half-life is a pre-result QM
falsification choice, not a fitted or source-claimed optimum.

## 7. Risk Model

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Every entry receives one frozen
`3.5*ATR(20,D1)` hard stop and no target. Both news axes and legacy news are
OFF; Friday close is OFF so the monthly structural hold can span weekends.

The EA owns at most one exact-symbol, exact-magic position. It repairs
duplicate, invalid-side, stopless, invalid-volume, cross-month, or 40-day stale
exposure before any entry-only gate. There is no scale-in, grid, martingale,
pyramid, trail, break-even, partial close, target, stop-and-reverse, or signal-
magnitude sizing.

## Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact host, identity, fixed risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| normalized month transition and exact completed endpoints | deterministic calendar helpers |
| missing-year skip, uncompressed ages, fixed weights, normalized sign | `Strategy_LoadExponentialYearWeightSignal` and `Strategy_ExponentialYearWeightSignal` |
| durable one-attempt ledger before fallible gates | `Strategy_PrepareDecisionSignal` |
| grace window, sign-only side, quote/spread, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native sizing, orders, kill switch, telemetry, owned-position isolation | V5 framework wiring |

## Validation Contract

Q01 must pass independent native and `+1` label fixtures, year rollover,
completed-endpoint reconstruction, missing-year skip with uncompressed ages,
five-to-ten sample bounds, exact weights at ages zero/four/eight, normalized
arithmetic, strict epsilon boundaries, the equal-weight disagreement vector,
one-attempt persistence, zero-spread reachability, crossed/excessive-spread
rejection, fixed-risk stop, monthly and stale lifecycle, approved-card/schema
checks, registry/resolver checks, SPEC validation, strict compile with zero
errors and warnings, setfile validation, and static build checks.

Wrong month, endpoint, sample membership, age, base, half-life, weight,
normalization, side, attempt, risk, stop, spread, lifecycle, identity, or
nondeterminism retires the edge rather than tuning it. Any changed sample,
kernel, carrier, stop, spread, or lifecycle requires a new card and dedup
decision.

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue after prerequisites and a nonbinding
CPU check. It creates no live, demo, shadow, stress, or optimization preset;
does not change `T_Live`, any deploy manifest, portfolio gate, or admission;
and never toggles AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-30 | G0-approved WTI same-calendar exponential-year-weight build |
