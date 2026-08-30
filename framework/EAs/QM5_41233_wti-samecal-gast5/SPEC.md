# QM5_41233_wti-samecal-gast5 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 NOT STARTED; Q02 NOT ENQUEUED`

## Identity

**EA ID:** QM5_41233

- EA ID: `QM5_41233`
- slug: `wti-samecal-gast5`
- strategy ID: `KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026_S01`
- source ID: `KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026/source.md`
- source approval:
  `decisions/2026-08-30_wti_same_calendar_gastwirth5_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41233_wti-samecal-gast5_card.md`
- G0 decision:
  `decisions/2026-08-30_qm5_41233_wti_same_calendar_gastwirth5_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412330000`

## 1. Strategy Logic

At the first genuine normalized broker-month transition into `(Y,M)`, load
the exact completed WTI log return for calendar month `M` in years `Y-5..Y-1`.
All five observations are mandatory. Each return uses the immediately prior
calendar month's final completed close and the target month's final completed
close, with a following-month D1 bar confirming completion.

Keep the returns in chronological order and sort only a copy as
`s[0] <= ... <= s[4]`. For each fraction `f`, use the GSL-linear convention
`h=4*f`, `i=floor(h)`, and
`Q(f)=(1-(h-i))*s[i]+(h-i)*s[i+1]`. The locked location is:

```text
Q1 = Q(1/3) = (2*s[1] + s[2]) / 3
Q2 = Q(1/2) = s[2]
Q3 = Q(2/3) = (s[2] + 2*s[3]) / 3
location = 0.3*Q1 + 0.4*Q2 + 0.3*Q3
invariant = 0.2*s[1] + 0.6*s[2] + 0.2*s[3]
```

The direct location and invariant must agree within `1e-12`. Buy only when
`location > +1e-12`, sell only when `location < -1e-12`, and consume flat in
the inclusive band or on any invalid state. Persist the month attempt before
every fallible history or entry gate. An accepted position holds to the next
broker month behind one frozen hard stop, subject to malformed-state and
40-day survivor repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_gastwirth_lower_weight` | 0.3 | one-third quantile weight |
| `strategy_gastwirth_median_weight` | 0.4 | median weight |
| `strategy_gastwirth_upper_weight` | 0.3 | two-third quantile weight |
| `strategy_signal_epsilon` | 1e-12 | flat band and invariant tolerance |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Slot 0, deterministic magic `412330000`.
- Direct WTI is outside the certified XAU/SP500/NDX/XNG carrier set; only
  unchanged Q09 may establish realized decorrelation.
- No proxy, basket, external feed, or second traded symbol.

## 4. Timeframe

Execution, endpoint reconstruction, risk range, and the structural clock are
D1. The EA attempts entry at most once per normalized broker month. Formation
uses the same named month across five separate prior years; ordinary renewal
is at the next genuine broker-month boundary.

## 5. Expected Behaviour

After the five-year warm-up, the cadence prior is approximately ten to twelve
positions per year. Q02 retires the strategy on zero trades, fewer than five
completed positions in any full scored year, or nonpositive governed
economics. It does not tune any rule.

The locked fixtures prevent substitution by existing estimators:

- `[-.30,-.28,+.02,+.24,+.26]` gives `+.004` and BUY while the raw mean,
  middle-three trim, and inactive three-MAD cap SELL and the trimean is flat.
- `[-.20,-.15,+.04,+.05,+.06]` gives `+.004` and BUY while trim, trimean,
  midhinge, and endpoint-Winsor siblings SELL.
- `[-.25,-.20,+.01,+.04,+.05]` gives `-.026` and SELL while the median BUYs.

Sign reflection reverses every strict mapping.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, support recurring same-calendar
commodity information, crude-oil membership, monthly renewal, and a five-year
floor. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal
of Financial Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`, support
WTI membership, own-return direction, and monthly renewal. Gastwirth (1966),
*On Robust Procedures*, JASA 61(316), DOI
`10.1080/01621459.1966.10482185`, supplies the named robust-procedure lineage;
GNU Scientific Library 2.8 statistics documentation fixes the quantile
interpolation and `0.3/0.4/0.3` aggregation.

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
| exact sample, GSL quantiles, Gastwirth sum, invariant | `Strategy_LoadGastwirthSignal` and `Strategy_GastwirthSignal` |
| durable attempt before fallible gates | `Strategy_PrepareDecisionSignal` |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_CloseExpiredPositions` |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, endpoint completion, exact
years, ascending sort, GSL interpolation, all three quantiles, Gastwirth
weights, the simplified invariant, epsilon, disagreement fixtures, durable
attempts, spread boundaries, lifecycle, registry resolution, card identity,
sole setfile, static guardrails, and strict zero-error/zero-warning compilation.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-30 | G0-approved WTI same-calendar Gastwirth build | Implementation prepared for Q01 and paced Q02 capacity check |

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue only after Q01 and capacity checks.
It creates no live, demo, shadow, stress, or optimization preset; does not
change `T_Live`, a deploy manifest, the portfolio gate, admission, or a
correlation decision; and never toggles AutoTrading.
