# QM5_41214_xng-samecal-signscore - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41214

- EA ID: `QM5_41214`
- slug: `xng-samecal-signscore`
- strategy ID: `KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026_S01`
- source ID: `KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026`
- approved source packet:
  `strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026/source.md`
- source approval:
  `decisions/2026-08-30_xng_same_calendar_sign_score_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41214_xng-samecal-signscore_card.md`
- G0 decision:
  `decisions/2026-08-30_qm5_41214_xng_same_calendar_sign_score_g0.md`
- host and traded symbol: exact `XNGUSD.DWX`, D1, slot 0
- deterministic magic: `412140000`

## 1. Strategy Logic

On the first executable D1 tick after a genuine normalized broker-month
transition into month `(Y,M)`, reconstruct the completed XNG log return for
calendar month `M` in exact years `Y-1..Y-10`. Missing years are skipped and
never replaced; at least five valid observations are required.

Map each finite return to one when it is nonnegative and zero when it is
negative. For `x` successes among `n` observations, use the fixed null
`p0=0.5` without continuity correction:

```text
denominator = sqrt(n*p0*(1-p0))
score       = (x-n*p0)/denominator = (2*x-n)/sqrt(n)
```

Buy only when `score > 1.0 + 1e-10`; sell only when
`score < -1.0 - 1e-10`; equality and the inclusive band are flat. Invalid
counts, denominator, score, endpoint, or sample consume flat. No current-month
price enters the signal and no fallback estimator is allowed.

Persist the normalized broker `yyyymm` attempt before history, signal, news,
spread, quote, ATR, sizing, margin, or submission gates. Every outcome consumes
the month. An accepted position holds to the next broker month behind a frozen
hard stop, subject only to malformed-position and 40-day stale repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum exact prior years |
| `strategy_min_observations` | 5 | valid same-calendar return floor |
| `strategy_null_probability` | 0.5 | Bernoulli null |
| `strategy_score_threshold` | 1.0 | strict absolute score gate |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded completed-bar scan |
| `strategy_entry_grace_minutes` | 180 | normalized month-open window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale survivor repair |
| `strategy_max_spread_points` | 3000 | nonnegative entry spread ceiling |

Q02 has exactly one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX` only.
- Symbol slot: `0`; deterministic magic: `412140000`.
- The strategy has one direct XNG leg and no hedge, proxy, conversion, or
  external runtime data feed.

This monthly binary-seasonal clock is mechanically different from the
certified daily cumulative-RSI pullback on the same XNG carrier. It does not
establish low realized correlation; unchanged Q09 remains the only portfolio
authority.

## 4. Timeframe

Execution, endpoint reconstruction, ATR, and the structural clock are D1.
Entry is attempted at most once per broker month and only in the first 180
minutes of the normalized first D1 session. Formation uses five through ten
disjoint observations of the upcoming calendar month in exact prior years.
Ordinary exit is the first processed D1 bar of the next normalized month;
40 elapsed calendar days is only a stale-state guard.

## 5. Expected Behaviour

The pre-result cadence prior is approximately five to eight completed
positions per full post-warm-up year because months inside the score band stay
flat. Q02 retires the identity below five completed positions in any full
scored year, on zero trades, or on nonpositive governed economics; it does not
tune the score gate.

The canonical dedup receipt
`artifacts/qm5_xng_samecal_signscore_preallocation_dedup_20260830.json`
found no exact identity. The information object is a null-standardized binary
sign count, not a return-magnitude mean, magnitude t-score, rank statistic,
robust location, residual momentum, or always-in hit rule.

Fixed disagreements are load-bearing:

- `[0.09,-0.01,-0.01,-0.01,-0.01]`: raw mean buys; this rule sells.
- three nonnegative returns in six: a 40-percent hit rule buys; this rule is
  flat.
- `[0.001,0.001,0.001,0.001,-0.100]`: this rule buys; the magnitude t-score
  remains inside its band.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, supply recurring same-calendar
commodity information, explicit natural-gas membership, monthly renewal, and a
five-year floor. Papailias, Liu, and Thomakos (2021), *Return Signal Momentum*,
*Journal of Banking & Finance* 124, DOI `10.1016/j.jbankfin.2021.106063`,
supply the nonnegative-return binary map, equal weighting, XNG membership, and
monthly lifecycle. The R Core Team `stats::prop.test` implementation pinned
at `wch/r-source` commit
`9deb2ebef8d0a2fe5cae965697ee4751af857bd1` supplies the one-sample null,
expected-count, and uncorrected Pearson score arithmetic.

No source tests this exact Darwinex XNG CFD translation, strict
`abs(score)>1` gate, spread limit, fixed-risk sizing, ATR stop, or current
portfolio. The threshold is a falsification choice, not a conventional
significance claim, and runtime computes no p-value.

## 7. Risk Model

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Every entry receives one frozen
`3.5*ATR(20,D1)` hard stop and no target. Both news axes and legacy news are
OFF; Friday close is OFF so the monthly structural hold can span weekends.

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
| missing-year skip, sign count, null denominator, strict score band | `Strategy_LoadBernoulliSignScoreSignal` and `Strategy_BernoulliSignScoreSignal` |
| durable one-attempt ledger before fallible gates | `Strategy_PrepareDecisionSignal` |
| grace window, sign-only side, quote/spread, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native sizing, orders, kill switch, telemetry, owned-position isolation | V5 framework wiring |

## Validation Contract

Q01 must pass independent native and `+1` label fixtures, year rollover,
completed-endpoint reconstruction, missing-year skip, five-to-ten sample
bounds, exact nonnegative count/null-denominator/score arithmetic, strict gate
boundaries, all fixed sibling-disagreement vectors, one-attempt persistence,
zero-spread reachability, crossed/excessive-spread rejection, fixed-risk stop,
monthly and stale lifecycle, approved-card/schema checks, registry/resolver
checks, SPEC validation, strict compile with zero errors and warnings, setfile
validation, and static build checks.

Wrong month, endpoint, sample membership, sign map, null, denominator, score,
side, attempt, risk, stop, spread, lifecycle, identity, or nondeterminism
retires the edge rather than tuning it. A different sample, map, estimator,
threshold, direction, carrier, stop, spread, or lifecycle requires a new card
and dedup decision.

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue after prerequisites and a nonbinding
CPU check. It creates no live, demo, shadow, stress, or optimization preset;
does not change `T_Live`, any deploy manifest, portfolio gate, or admission;
and never toggles AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-30 | G0-approved XNG same-calendar Bernoulli sign-score build |


