# QM5_41237_wti-samecal-cauchy5 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 PENDING`

## Identity

- EA ID: `QM5_41237`
- slug: `wti-samecal-cauchy5`
- strategy ID: `KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026_S01`
- source ID: `KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026/source.md`
- source approval:
  `decisions/2026-08-31_wti_same_calendar_cauchy5_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41237_wti-samecal-cauchy5_card.md`
- G0 decision:
  `decisions/2026-08-31_qm5_41237_wti_same_calendar_cauchy5_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412370000`

## 1. Strategy Logic

At the first genuine normalized broker-month transition into `(Y,M)`, load
the exact completed WTI return for calendar month `M` in years `Y-5..Y-1`.
All five observations are mandatory. Each uses the prior calendar month's
final completed close and the target month's final completed close, with a
following-month bar confirming completion.

Keep the returns in chronological year order and sort only copies. The locked
location is:

```text
s      = sort_ascending(copy(r))
median = s[2]
d[i]   = abs(r[i] - median)
a      = sort_ascending(copy(d))
MAD    = a[2]
scale  = 1.4826 * MAD
mu[0]  = median
for j = 0..31:
  u[i]      = (r[i] - mu[j]) / scale
  weight[i] = 1 / (1 + u[i]^2)
  mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])
```

Buy only when `mu[32] > +1e-12`, sell only when
`mu[32] < -1e-12`, and consume flat inside the inclusive epsilon band or on
any invalid state. Persist the month attempt before every fallible history or
entry gate. An accepted position holds to the next broker month behind one
frozen hard stop, subject to malformed-state and 40-day repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_scale_multiplier` | 1.4826 | frozen raw-MAD scale |
| `strategy_cauchy_iterations` | 32 | exact reweighting count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Slot 0, deterministic magic `412370000`.
- Direct WTI is outside the certified XAU/SP500/NDX/XNG carrier set; only
  unchanged Q09 may establish realized decorrelation.
- No proxy, basket, external feed, or second traded symbol.

## 4. Timeframe

Execution, endpoint reconstruction, risk range, and structural clock are D1.
The EA attempts entry at most once per normalized broker month. Formation uses
the same named month across five separate prior years; ordinary renewal is at
the next genuine broker-month boundary.

## 5. Expected Behaviour

After five-year warm-up, cadence prior is approximately ten to twelve
positions per year because only invalid history, nonpositive MAD/weight, and
an epsilon tie stay flat. Q02 retires on zero trades, below five completed
positions in a full scored year, or nonpositive governed economics. It does
not tune any rule.

The canonical receipt found no exact identity. Sorted returns
`[-0.080,-0.050,-0.001,+0.005,+0.010]` make the locked Cauchy statistic buy
at approximately `+0.001385877861`, while raw mean, median, trim, Winsor,
trimean, midhinge, bisquare, and Hampel peers sell. Sign reflection reverses
the mapping. The strictly positive rational tail weighting therefore commits
to a different signal path rather than renaming another same-calendar rule.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, support recurring same-calendar
commodity information, explicit crude-oil membership, monthly renewal, and a
five-year floor. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`, support explicit WTI membership, own-return
direction, and monthly renewal. Official SciPy `least_squares` documentation
fixes the Cauchy loss `rho(z)=ln(1+z)` and its scale convention. QM fixes the
derivative weight, raw-MAD multiplier, median start, frozen scale, and exact
32-update convention before testing.

No source tests this exact five-sample trading conjunction, continuous WTI
CFD, stop, spread, or portfolio. Those are disclosed pre-result QM choices;
no source performance or correlation result transfers.

## 7. Risk Model

The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each entry receives one frozen `3.5*ATR(20,D1)` broker
hard stop and no target. Both news axes and legacy news are OFF; Friday close
is OFF so the monthly structural hold may span weekends.

The EA owns at most one exact-symbol, exact-magic position. It has no scale-in,
grid, martingale, pyramid, trail, break-even, partial close, target,
stop-and-reverse, or signal-magnitude sizing.

## 8. Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact identity, host, risk, modes, and inputs | `Strategy_NoTradeFilter` |
| normalized month and completed endpoints | calendar and endpoint helpers |
| exact sample, median/MAD, fixed-step Cauchy | `Strategy_LoadCauchySignal` and `Strategy_CauchySignal` |
| durable attempt before fallible gates | `Strategy_PrepareDecisionSignal` |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_CloseExpiredPositions` |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, endpoint completion,
exact years, median/MAD indexes, frozen scale, rational weights, exact update
count, epsilon, disagreement fixtures, durable attempts, spread boundaries,
lifecycle, registry resolution, card identity, sole setfile, static
guardrails, and strict zero-error/zero-warning compilation.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-31 | G0-approved WTI same-calendar Cauchy build | Q01 pending |

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue only after Q01 and capacity checks.
It creates no live, demo, shadow, stress, or optimization preset; does not
change `T_Live`, a deploy manifest, the portfolio gate, admission, or a
correlation decision; and never toggles AutoTrading.
