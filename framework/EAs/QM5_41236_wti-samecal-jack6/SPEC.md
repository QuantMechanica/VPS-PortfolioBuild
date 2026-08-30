# QM5_41236_wti-samecal-jack6 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 PENDING`

## Identity

**EA ID:** QM5_41236

- EA ID: `QM5_41236`
- slug: `wti-samecal-jack6`
- strategy ID: `KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026_S01`
- source ID: `KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-NIST-WTI-SAMECAL-JACK6-2026/source.md`
- source approval:
  `decisions/2026-08-31_wti_same_calendar_jackknife_sign_stability_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41236_wti-samecal-jack6_card.md`
- G0 decision:
  `decisions/2026-08-31_qm5_41236_wti_same_calendar_jackknife_sign_stability_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412360000`

## 1. Strategy Logic

At the first genuine normalized broker-month transition into `(Y,M)`, load
the exact completed WTI return for calendar month `M` in years `Y-6..Y-1`.
All six observations are mandatory. Each uses the prior calendar month's
final completed close and the target month's final completed close, with a
following-month bar confirming completion.

For each index `k=0..5`, omit only `r[k]`, sum the other five observations,
and divide by exactly five:

```text
loo[k] = sum(r[i] for i=0..5 and i!=k) / 5
all loo[k] > +1e-12 => BUY
all loo[k] < -1e-12 => SELL
otherwise           => FLAT
```

Every input, partial sum, final sum, and mean must be finite. The inclusive
epsilon band is flat. There is no full-sample fallback, selected deletion,
majority vote, confidence interval, or signal-magnitude sizing.

Persist the month attempt before every fallible history or entry gate. An
accepted position holds to the next broker month behind one frozen hard stop,
subject to malformed-state and 40-day repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 6 | exact prior matching-calendar years |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_delete_count` | 1 | exactly one omitted observation |
| `strategy_subset_size` | 5 | exact divisor and subset membership |
| `strategy_signal_epsilon` | 1e-12 | strict sign / inclusive flat band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Slot 0, deterministic magic `412360000`.
- Direct WTI is outside the certified XAU/SP500/NDX/XNG carrier set; only
  unchanged Q09 may establish realized decorrelation.
- No proxy, basket, external feed, or second traded symbol.

## 4. Timeframe

Execution, endpoint reconstruction, risk range, and structural clock are D1.
The EA consumes at most one attempt per normalized broker month. Formation
uses the same named month across six separate prior years; ordinary renewal is
at the next genuine broker-month boundary.

## 5. Expected Behaviour

After six-year warm-up, the cadence prior is approximately five to ten
positions per year because any sign disagreement or epsilon touch stays flat.
Q02 retires below five completed positions in any full scored year or on
nonpositive governed economics. It does not tune any rule.

For `[-.020,-.010,.001,.002,.003,.050]`, the six delete-one means are
`[.0092,.0072,.0050,.0048,.0046,-.0048]`, so this EA is flat while the
newest-five raw mean, newest-five median, and QM5_41227 block median buy.
`[-.001,.002,.003,.004,.005,.006]` makes all six means positive and buys;
sign reflection sells. The exact sixth year and all-six conjunction therefore
change participation rather than rename another same-calendar estimator.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, support recurring same-calendar
commodity information, explicit crude-oil membership, monthly renewal, and a
five-year floor. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`, support explicit WTI membership, own-return
direction, and monthly renewal. Heckert and Filliben (2003), NIST Handbook
148, document recomputing a mean after deleting each observation.

No source tests this exact six-year unanimous-sign conjunction, continuous WTI
CFD, stop, spread, activity, economics, or portfolio correlation. Those are
disclosed pre-result QM choices; no source or sibling result transfers.

## 7. Risk Model

The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each entry receives one frozen
`3.5*ATR(20,D1)` broker hard stop and no target. Both news axes and legacy
news are OFF; Friday close is OFF so the monthly structural hold may span
weekends.

The EA owns at most one exact-symbol, exact-magic position. It has no scale-in,
grid, martingale, pyramid, trail, break-even, partial close, target,
stop-and-reverse, or signal-magnitude sizing.

## 8. Framework Alignment

| Card obligation | V5 implementation |
|---|---|
| exact identity, host, risk, modes, and inputs | `Strategy_NoTradeFilter` |
| normalized month and completed endpoints | calendar and endpoint helpers |
| six exact samples and six delete-one means | `Strategy_LoadDeleteOneSignal` and `Strategy_DeleteOneSignal` |
| durable attempt before fallible gates | `Strategy_PrepareDecisionSignal` |
| side, spread, quote, ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, stale repair | `Strategy_CloseExpiredPositions` |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify label normalization, endpoint completion, exact
years, every omitted index, five-member subsets, divisor five, partial-sum
finiteness, epsilon and unanimity, disagreement fixtures, durable attempts,
spread boundaries, lifecycle, registry resolution, card identity, sole
setfile, static guardrails, and strict zero-error/zero-warning compilation.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-31 | G0-approved WTI delete-one sign-stability build | Q01 pending |

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue only after Q01 and capacity checks.
It creates no live, demo, shadow, stress, or optimization preset; does not
change `T_Live`, a deploy manifest, the portfolio gate, admission, or a
correlation decision; and never toggles AutoTrading.
