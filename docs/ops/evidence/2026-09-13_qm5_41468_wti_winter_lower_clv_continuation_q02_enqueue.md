# QM5_41468 WTI Winter Lower-CLV Continuation — Q02 Enqueue

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; exactly one Q02
canary enqueued below the binding CPU ceiling.

## Edge

`QM5_41468_wti-winter-lclv-cont` is a low-frequency WTI downside-continuation
sleeve. At the first tradable D1 bar of each November-through-May normalized
broker week, it reconstructs exactly the immediately completed three-to-five-
session week and sells only when the final close is strictly below one third
of that week's full range. It has no return-sign, range-rank, candle-body,
wick, stretch, or moving-average predicate and no long side.

The decision week is consumed before fallible gates. The position exits in
the next normalized week, with ten-calendar-day stale repair and one frozen
`3.5*ATR(20,D1)` hard stop. The WTI carrier and downside shock-persistence
logic differ from certified `QM5_12567`, an all-year XNG long-only two-day
cumulative-RSI pullback. Realized portfolio correlation is unclaimed and
remains an unchanged later Q09 measurement.

## Source And Identity

The complete-read packet combines peer-reviewed WTI November-May regime
evidence, governed reputable completed-week/close-location lineage, and the
Moskowitz-Ooi-Pedersen commodity-continuation lineage. The short direction is
explicitly counter to the regime's positive average drift, and the exact
Darwinex-CFD conjunction is an untested QM translation.

The canonical scan covered 4,949 registry rows and 1,558 repository cards. It
found no exact collision and two fuzzy family matches. Manual review separated
the disjoint summer lower-tercile short, winter upper-tercile long, and winter
lower-tercile long-reversion siblings. The external Strategy Wiki mount was
unavailable and that limitation remains explicit.

## Q01 Evidence

- EA ID/magic: `QM5_41468`, slot 0, `414680000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Framework RNG, news, and Friday-close inputs are not equality-pinned; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `c149230f-10c0-40e5-ac34-c1ab6addaad6`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `088c277162cc8e5cc43d14aae307c57d6897184cdbb44ebd2cc4664a7561888c`.
- EX5 SHA-256:
  `9dfdfc28579b00549ee4911d6c6216538f9f75926ab76cc53b241cd7f1649e93`.
- Final setfile SHA-256:
  `1aa85724ad3f574d29ae4833557298965475f9390bc307fb3908d07aac17729e`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings and
zero failures.

## Q02 Admission

Read-only first-Q02 intake returned `eligible=true` and `would_enqueue=true`
for exactly one `XTIUSD.DWX` D1 set. The governed intake verified all 18
nonempty strategy parameters, active magic, fixed-risk mode, current EX5, and
final setfile hash.

The first five-sample CPU admission measured maximum `70.4%`; the associated
apply process ended before append. A second fresh sample measured maximum
`85.6%`, but the apply refused on a transient SQLite lock while scheduled
pump/health writers were active. No row was created by either attempt, and a
subsequent dry run remained eligible. The writers were allowed to finish
naturally. The final five-sample admission measured
`[71.4, 70.2, 75.8, 77.4, 77.7]`; average `74.5%`, maximum `77.7%`, threshold
`97.0%`. Exactly one Q02 item was then appended:
`621253f5-6ca8-4d5e-ae4c-610d0b55c28c` and was claimed by T6 after enqueue.
Receipt:
`D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/c149230f-10c0-40e5-ac34-c1ab6addaad6_621253f5-6ca8-4d5e-ae4c-610d0b55c28c.json`, SHA-256
`6ae961a9b20d8682aade8187ce653268d6386fd0950441a6bd1141831de8175f`.

No manual backtest, fanout, rerun, downstream phase, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, terminal
control, or live operation was touched.

