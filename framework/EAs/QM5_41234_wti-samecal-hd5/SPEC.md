# QM5_41234_wti-samecal-hd5 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 PENDING`

## Identity

**EA ID:** QM5_41234

- EA ID: `QM5_41234`
- slug: `wti-samecal-hd5`
- strategy ID: `KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026_S01`
- source ID: `KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026`
- source packet: `strategy-seeds/sources/KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026/source.md`
- source approval: `decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md`
- approved card: `strategy-seeds/cards/approved/QM5_41234_wti-samecal-hd5_card.md`
- G0 decision: `decisions/2026-08-30_qm5_41234_wti_same_calendar_harrell_davis5_g0.md`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412340000`

## 1. Strategy Logic

At the first genuine normalized broker-month transition into `(Y,M)`, load
the exact completed WTI log return for calendar month `M` in years `Y-5..Y-1`.
All five observations are mandatory. Each return uses the immediately prior
calendar month's final completed close and the target month's final completed
close, with a following-month D1 bar confirming completion.

Keep the returns in chronological order and sort only a copy as
`s[0] <= ... <= s[4]`. For `n=5`, median target `p=0.5`, and `m=n+1=6`, the
Harrell-Davis beta parameters are `(3,3)`. The locked interval-mass weights
and signal are:

```text
w = [181, 811, 1141, 811, 181] / 3125
hd_rational = (181*s[0] + 811*s[1] + 1141*s[2]
               + 811*s[3] + 181*s[4]) / 3125
hd_decimal = 0.05792*s[0] + 0.25952*s[1] + 0.36512*s[2]
             + 0.25952*s[3] + 0.05792*s[4]
```

Both representations must be finite and agree within `1e-12`. Buy only when
`hd_rational > +1e-12`, sell only when it is `< -1e-12`, and consume flat in
the inclusive band or on any invalid state. Persist the month attempt before
every fallible history or entry gate. An accepted position holds to the next
broker month behind one frozen hard stop, subject to malformed-state and
40-day survivor repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_invariant_tolerance` | 1e-12 | rational/decimal equality |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |
| `strategy_deviation_points` | 20 | framework market-order deviation |

Q02 has one locked baseline and no optimization surface. The weights are
literal implementation constants, not tunable inputs.

## 3. Symbol Universe

The host and traded symbol is exact `XTIUSD.DWX` only. Slot 0 resolves to
magic `412340000`. Direct WTI is outside the certified XAU/SP500/NDX/XNG
carrier set, but only unchanged Q09 may establish realized decorrelation.
There is no proxy, basket, external feed, or second traded symbol.

## 4. Timeframe

Execution, endpoint reconstruction, risk range, and structural clock are D1.
The EA attempts entry at most once per normalized broker month. Formation uses
the same named month across five separate prior years; ordinary renewal is at
the next genuine broker-month boundary.

## 5. Expected Behaviour

After the five-year warm-up, cadence prior is approximately 10-12 completed
positions per year. Q02 retires on zero trades, fewer than five completed
positions in any full scored year, or nonpositive governed economics.

The locked fixtures prove the estimator is not a relabelled sibling:

- `[-.30,-.30,+.05,+.25,+.25]` gives `+.002384` and BUY while raw mean
  and endpoint Winsor SELL, the middle-three trim is flat, and midhinge sells.
- `[-.30,-.20,-.05,+.30,+.30]` gives `+.007696` and BUY while ordinary
  median and Gastwirth sell and trimean is flat.
- `[-.30,-.30,+.05,+.20,+.20]` gives `-.013488` and SELL while ordinary
  median and Gastwirth buy.

Sign reflection reverses every strict mapping.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, supports
recurring same-calendar commodity information, crude-oil membership, monthly
renewal, and a five-year floor. Moskowitz, Ooi, and Pedersen (2012), *Time
Series Momentum*, supports WTI membership, own-return direction, and monthly
renewal. Harrell and Davis (1982), *A New Distribution-Free Quantile
Estimator*, supplies the named estimator; Frank Harrell's maintained `Hmisc`
implementation fixes the `(n+1)p` beta parameters and interval-mass sum.

No source tests this exact five-sample trading conjunction, continuous WTI
CFD, stop, spread, or portfolio. Those are disclosed pre-result QM choices;
no source performance or correlation result transfers.

## 7. Risk Model

The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each entry receives one frozen `3.5*ATR(20,D1)` broker
hard stop and no target. Both news axes and legacy news are OFF; Friday close
is OFF so the structural monthly hold may span weekends.

The EA owns at most one exact-symbol, exact-magic position. It has no scale-in,
grid, martingale, pyramid, trail, break-even, partial close, target,
stop-and-reverse, or signal-magnitude sizing.

## 8. Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact identity, host, risk, modes, and inputs | `Strategy_NoTradeFilter` |
| normalized month and completed endpoints | calendar and endpoint helpers |
| exact sample, sort, fixed beta weights, invariant | `Strategy_LoadHarrellDavisSignal` and `Strategy_HarrellDavisSignal` |
| durable attempt before fallible gates | `Strategy_PrepareDecisionSignal` |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_CloseExpiredPositions` |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, endpoint completion, exact
years, ascending sort, beta(3,3) interval weights, both representations,
epsilon, disagreement fixtures, durable attempts, spread boundaries,
lifecycle, registry resolution, sole setfile, static guardrails, and strict
zero-error/zero-warning compilation.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-30 | G0-approved WTI same-calendar Harrell-Davis build | Q01 pending |

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue only after Q01 and capacity checks.
It creates no live, demo, shadow, stress, or optimization preset; does not
change `T_Live`, a deploy manifest, the portfolio gate, admission, or a
correlation decision; and never toggles AutoTrading.
