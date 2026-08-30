# QM5_41227_wti-samecal-blockmed - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 PASS; Q02 CAPACITY CHECK PENDING`

## Identity

**EA ID:** QM5_41227

- EA ID: `QM5_41227`
- slug: `wti-samecal-blockmed`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026/source.md`
- source approval:
  `decisions/2026-08-30_wti_same_calendar_block_median_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41227_wti-samecal-blockmed_card.md`
- G0 decision:
  `decisions/2026-08-30_qm5_41227_wti_same_calendar_block_median_g0.md`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412270000`

## 1. Strategy Logic

At the first genuine normalized broker-month transition into `(Y,M)`, load
the exact completed WTI return for calendar month `M` in years `Y-5..Y-1`.
All five observations are mandatory and ordered oldest to newest. Each return
uses the prior calendar month's final completed close and the target month's
final completed close, with a following-month bar confirming completion.

Compute four overlapping chronological two-year means and their even median:

```text
b0 = (r0 + r1) / 2
b1 = (r1 + r2) / 2
b2 = (r2 + r3) / 2
b3 = (r3 + r4) / 2
s  = sort_ascending([b0,b1,b2,b3])
location = (s1 + s2) / 2
```

Buy only above `+1e-12`, sell only below `-1e-12`, and consume flat inside
the inclusive epsilon band. Persist the month attempt before every fallible
history or entry gate. An accepted position holds to the next broker month
behind one frozen hard stop, subject to malformed-state and 40-day repair.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact prior matching-calendar years |
| `strategy_rolling_years` | 2 | observations per chronological mean |
| `strategy_rolling_count` | 4 | exact overlapping mean count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one locked baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Slot 0, deterministic magic `412270000`.
- Direct WTI is a different carrier from the certified XAU/SP500/NDX/XNG
  carrier set; only unchanged Q09 may establish realized decorrelation.
- No proxy, basket, external feed, or second traded symbol.

## 4. Timeframe

Execution, endpoint reconstruction, risk range, and structural clock are D1.
The EA attempts entry at most once per normalized broker month. Formation uses
the same named month across five separate prior years; ordinary renewal is at
the next genuine broker-month boundary.

## 5. Expected Behaviour

After five-year warm-up, the cadence prior is approximately ten to twelve
positions per year because only invalid history and an exact epsilon tie stay
flat. Q02 retires the edge on zero trades, below five completed positions in
any full scored year, or nonpositive governed economics. It does not tune the
sample, statistic, direction, stop, spread, or lifecycle.

The canonical dedup receipt found no exact identity. On chronological returns
`[-0.10,-0.10,+0.001,+0.10,+0.001]`, this statistic buys at `+0.0005` while
the full-sample mean sells at `-0.0196`. On
`[-0.10,-0.10,+0.001,+0.001,+0.001]`, it sells at `-0.02425` while the
individual-return median buys at `+0.001`.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*, *Journal of
Finance* 71(4), DOI `10.1111/jofi.12398`, support recurring same-calendar
commodity information, explicit crude-oil membership, monthly renewal, and a
five-year history floor. Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`, support explicit WTI membership, own-return
direction, and monthly renewal.

Neither paper tests this rolling two-year block median, Darwinex continuous
WTI CFD translation, stop, spread, or portfolio. Those are disclosed,
pre-result QM falsification choices; no published performance transfers.

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
| exact identity, host, risk, modes, and locked inputs | `Strategy_NoTradeFilter` |
| normalized month transition and exact completed endpoints | calendar and endpoint helpers |
| exact five-return chronology, rolling means, even median | `Strategy_LoadRollingBlockMedianSignal` and `Strategy_RollingBlockMedianSignal` |
| durable attempt before fallible gates | `Strategy_PrepareDecisionSignal` |
| sign side, spread, quote, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, next-month, and stale repair | `Strategy_CloseExpiredPositions` |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native sizing, execution, kill switch, telemetry | V5 framework wiring |

Q01 must independently verify native and `+1` labels, endpoint completion,
exact year membership, chronology, pair divisors, even-median indexes, epsilon
boundaries, disagreement fixtures, durable attempts, spread boundaries,
monthly/stale lifecycle, registry resolution, card identity, sole setfile,
static guardrails, and strict zero-error/zero-warning compilation.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-30 | G0-approved WTI same-calendar rolling block-median build | Q01 PASS: strict compiler 0 errors/0 warnings; build check PASS |

## Safety Boundary

This is a branch-only non-live build. It authorizes one `RISK_FIXED` D1
backtest preset and one paced Q02 enqueue only after Q01 and capacity checks.
It creates no live, demo, shadow, stress, or optimization preset; does not
change `T_Live`, a deploy manifest, the portfolio gate, admission, or a
correlation decision; and never toggles AutoTrading.
