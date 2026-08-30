# QM5_41211_wti-samecal-tstat - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41211

- EA ID: `QM5_41211`
- slug: `wti-samecal-tstat`
- strategy ID: `KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026_S01`
- source ID: `KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026`
- approved source packet:
  `strategy-seeds/sources/KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026/source.md`
- source approval:
  `decisions/2026-08-30_wti_same_calendar_tscore_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41211_wti-samecal-tstat_card.md`
- G0 decision:
  `decisions/2026-08-30_qm5_41211_wti_same_calendar_tscore_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412110000`

## 1. Strategy Logic

On the first executable D1 tick after a genuine normalized broker-month
transition into month `(Y,M)`, reconstruct the completed WTI log return for
calendar month `M` in exact years `Y-1..Y-10`. Missing years are skipped and
never replaced; at least five valid observations are required.

For the `n` valid returns, compute the arithmetic mean, sample variance with
denominator `n-1`, standard error `sqrt(variance/n)`, and `t=mean/se`. Buy only
when `t > 1.0 + 1e-10`; sell only when `t < -1.0 - 1e-10`; equality and the
inclusive band are flat. Non-finite arithmetic or nonpositive variance/SE is
flat. No current-month price enters the signal and no fallback estimator is
allowed.

Persist the broker `yyyymm` attempt before history, signal, news, spread,
quote, ATR, sizing, margin, or submission gates. Every outcome consumes the
month. An accepted position holds to the next broker month behind a frozen
hard stop, subject only to malformed-position and stale repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum exact prior years |
| `strategy_min_observations` | 5 | valid same-calendar return floor |
| `strategy_t_threshold` | 1.0 | strict absolute score gate |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded completed-bar scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale survivor repair |
| `strategy_max_spread_points` | 1500 | nonnegative entry spread ceiling |

Q02 has exactly one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Symbol slot: `0`; deterministic magic: `412110000`.
- The strategy has one direct WTI leg. It has no companion, hedge, conversion,
  proxy, or external data feed.

This crude-oil carrier and monthly structural clock are intended to add
exposure different from the XAU/SP500/NDX/XNG book. They do not prove low
realized correlation; unchanged Q09 remains the only portfolio authority.

## 4. Timeframe

Execution, endpoint reconstruction, ATR, and the structural clock are D1.
Entry is attempted at most once per broker month. Formation uses five through
ten disjoint observations of the upcoming calendar month in exact prior years.
Ordinary exit is the first processed D1 bar of the next normalized month; 40
elapsed calendar days is only a stale-state guard.

## 5. Expected Behaviour

The pre-result cadence prior is approximately six to ten completed positions
per full post-warm-up year because months inside the score band remain flat.
Q02 retires the identity below five completed positions in any full scored
year, on zero trades, or on nonpositive governed economics; it does not tune
the score gate.

Canonical dedup receipt
`artifacts/qm5_wti_samecal_tstat_preallocation_dedup_20260830.json` found no
exact identity. `QM5_20099_wti-samecal` follows a nonzero raw mean, while this
EA abstains unless the mean exceeds one estimated standard error. On the fixed
vector `[0.020, 0.015, 0.010, 0.005, 0.001, -0.040]`, the raw mean is positive
but this rule remains flat. Robust-location, rank, residual-momentum, and the
paired-metals `QM5_41210` rule also have different statistics, carriers, or
position topology.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply recurring
same-calendar commodity-return information, explicit crude-oil membership,
monthly renewal, and a five-year floor. The R Core Team `stats::t.test`
implementation pinned at `wch/r-source` commit
`bac583951b728e97b9786804d3b4081f0fe18df5` supplies arithmetic mean, sample
variance, standard error, and one-sample score arithmetic.

Neither source tests this exact Darwinex WTI CFD translation, strict `abs(t)>1`
gate, spread limit, fixed-risk sizing, ATR stop, or current portfolio. No
source performance or correlation result transfers, and the locked threshold
is a falsification choice rather than a conventional significance claim.

## 7. Risk Model

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Every entry receives one frozen `3.5*ATR(20,D1)` hard
stop and no target. Both news axes and legacy news are OFF; Friday close is
OFF so the monthly structural hold can span weekends.

The EA owns at most one exact-symbol, exact-magic position. It repairs
duplicate, wrong-symbol, wrong-magic, invalid-side, stopless, invalid-volume,
cross-month, or 40-day stale exposure before any entry-only gate. There is no
scale-in, grid, martingale, pyramid, trail, break-even, partial close, target,
stop-and-reverse, or signal-magnitude sizing.

## Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact host, identity, fixed risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| normalized month transition and exact completed endpoints | deterministic calendar helpers |
| missing-year skip, mean, `n-1` variance, SE, strict score band | `Strategy_LoadTStatisticSignal` and `Strategy_TStatisticSignal` |
| durable one-attempt ledger before fallible gates | `Strategy_PrepareDecisionSignal` |
| sign-only side, spread, quote, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native sizing, orders, kill switch, telemetry, owned-position isolation | V5 framework wiring |

## Validation Contract

Q01 must pass independent native and `+1` label fixtures, year rollover,
completed-endpoint reconstruction, missing-year skip, five-to-ten sample
bounds, exact mean/variance/SE/score arithmetic, strict gate boundaries, the
fixed raw-mean disagreement vector, one-attempt persistence, zero-spread
reachability, spread rejection, fixed-risk stop, monthly and stale lifecycle,
approved-card/schema checks, registry/resolver checks, SPEC validation, strict
compile with zero errors and warnings, setfile validation, and static build
checks.

Wrong month, endpoint, sample membership, variance denominator, score, side,
attempt, risk, stop, spread, lifecycle, identity, or nondeterminism retires the
edge rather than tuning it. A different sample, estimator, threshold,
direction, carrier, stop, spread, or lifecycle requires a new card and dedup
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
| v1 | 2026-08-30 | G0-approved WTI same-calendar one-standard-error build |
