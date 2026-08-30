# QM5_41224_wti-samecal-regimeshift - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41224

- EA ID: `QM5_41224`
- slug: `wti-samecal-regimeshift`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026`
- approved source packet:
  `strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026/source.md`
- source approval:
  `decisions/2026-08-30_wti_same_calendar_regime_shift_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41224_wti-samecal-regimeshift_card.md`
- G0 decision:
  `decisions/2026-08-30_qm5_41224_wti_same_calendar_regime_shift_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412240000`

## 1. Strategy Logic

On the first executable D1 tick after a genuine normalized broker-month
transition into `(Y,M)`, reconstruct the completed WTI log return for calendar
month `M` in every exact year `Y-1..Y-10`. All ten returns are mandatory;
missing, malformed, or nonfinite years consume the decision flat and are never
substituted or compressed.

Split the ordered sample into two fixed chronological blocks:

```text
recent_mean = (r_1 + r_2 + r_3 + r_4 + r_5) / 5
older_mean  = (r_6 + r_7 + r_8 + r_9 + r_10) / 5

BUY  iff recent_mean > +1e-12 and older_mean < -1e-12
SELL iff recent_mean < -1e-12 and older_mean > +1e-12
FLAT otherwise
```

The signal follows only the recent block when the recent and older blocks
strictly disagree. Equality, stable-sign histories, incomplete endpoints, and
invalid arithmetic consume flat. No current-month price enters the signal;
there is no weighting, sorting, clipping, fit, or fallback estimator.

Persist the normalized broker `yyyymm` attempt before history, signal, news,
spread, quote, ATR, sizing, margin, or submission gates. Every outcome consumes
the month. An accepted position holds to the next broker month behind a frozen
hard stop, subject only to malformed-position and 40-day stale repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | exact prior-year window; all mandatory |
| `strategy_block_years` | 5 | exact divisor and size of both blocks |
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
- Symbol slot: `0`; deterministic magic: `412240000`.
- The strategy has one direct WTI leg and no hedge, proxy, conversion, or
  external runtime data feed.

WTI adds a crude-oil carrier outside the certified XAU/SP500/NDX/XNG carrier
set. Carrier and clock difference do not establish low realized correlation;
unchanged Q09 remains the only portfolio authority.

## 4. Timeframe

Execution, endpoint reconstruction, ATR, and the structural clock are D1.
Entry is attempted at most once per broker month and only in the first 180
minutes of the normalized first D1 session. Formation uses ten exact,
completed, same-calendar-month observations ordered from `Y-1` through `Y-10`.
Ordinary exit is the first processed D1 bar of the next normalized month;
40 elapsed calendar days is only a stale-state guard.

## 5. Expected Behaviour

The pre-result cadence prior is approximately five to eight completed
positions per full post-warm-up year because stable-sign histories remain flat.
Q02 retires the identity below five completed positions in any full scored
year, on zero trades, or on nonpositive governed economics. It does not tune
the window, split, epsilon, side, or lifecycle.

The canonical dedup receipt
`artifacts/qm5_wti_samecal_regimeshift_preallocation_dedup_20260830.json`
found no exact identity. The information object is a chronological state
transition between two disjoint five-year same-calendar blocks, not a
full-sample mean, robust location, continuous age decay, variance confidence
score, sign count, or intramonth change point.

The load-bearing disagreement uses recent-to-old returns
`[+0.01,+0.01,+0.01,+0.01,+0.01,-0.03,-0.03,-0.03,-0.03,-0.03]`.
Their full equal-weight mean is `-0.01`, so `QM5_20099_wti-samecal` sells.
This EA has `recent_mean=+0.01`, `older_mean=-0.03`, and buys. All-positive or
all-negative histories force this EA flat while raw and decay rules can trade.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, supply recurring same-calendar
commodity information, explicit crude-oil membership, monthly renewal, and a
five-year floor. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`, supply explicit WTI membership, own-return
direction, and monthly renewal.

The approved governed packet fixes the chronological five/five conjunction
and records its claim boundary. Neither paper tests this exact regime-shift
rule, Darwinex WTI CFD translation, spread limit, fixed-risk sizing, ATR stop,
or current portfolio. The split is a pre-result QM falsification choice, not a
fitted or source-claimed optimum.

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
| ten-of-ten ordered membership, five/five means, strict disagreement | `Strategy_LoadRegimeShiftSignal` and `Strategy_RegimeShiftSignal` |
| durable one-attempt ledger before fallible gates | `Strategy_PrepareDecisionSignal` |
| grace window, recent-block side, quote/spread, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native sizing, orders, kill switch, telemetry, owned-position isolation | V5 framework wiring |

## Validation Contract

Q01 must pass independent native and `+1` label fixtures, year rollover,
completed-endpoint reconstruction, mandatory exact ten-year membership,
ordered block assignment, arithmetic divisors, strict two-sided epsilon
boundaries, BUY and SELL reversals, stable-sign flat states, the raw-mean
opposite-side fixture, one-attempt persistence, zero-spread reachability,
crossed/excessive-spread rejection, fixed-risk stop, monthly and stale
lifecycle, approved-card/schema checks, registry/resolver checks, SPEC
validation, strict compile with zero errors and warnings, setfile validation,
and static build checks.

Wrong month, endpoint, sample membership, ordering, block, divisor, sign,
side, attempt, risk, stop, spread, lifecycle, identity, or nondeterminism
retires the edge rather than tuning it. Any changed sample, split, carrier,
stop, spread, or lifecycle requires a new card and dedup decision.

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue after prerequisites and a nonbinding
CPU check. It creates no live, demo, shadow, stress, or optimization preset;
does not change `T_Live`, any deploy manifest, portfolio gate, or admission;
and never toggles AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-30 | G0-approved WTI same-calendar chronological regime-shift build |
