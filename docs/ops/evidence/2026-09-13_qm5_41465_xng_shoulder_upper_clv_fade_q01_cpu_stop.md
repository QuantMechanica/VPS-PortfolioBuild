# QM5_41465 XNG Shoulder Upper-CLV Fade — Q01 CPU Stop

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; Q02 not enqueued
because the binding CPU ceiling was hit.

## Edge

`QM5_41465_xng-shoulder-hclv-fade` is a low-frequency direct-natural-gas
sleeve. At the first tradable D1 bar of each April, May, September, or October
normalized broker week, it reconstructs exactly the immediately completed
three-to-five-session week and sells only when the final close is strictly
above two thirds of that week's full range. It has no return-sign, range-rank,
candle-body, wick, stretch, or moving-average predicate and no long side.

The decision week is consumed before fallible gates. The position exits in the
next normalized week, with ten-calendar-day stale repair and one frozen
`3.5*ATR(20,D1)` hard stop. The mechanism differs from certified `QM5_12567`,
which is an all-year long-only two-day cumulative-RSI pullback. Realized
portfolio correlation is unclaimed and remains a later Q09 measurement.

## Source And Identity

The complete-read source packet combines official EIA natural-gas shoulder-
season context, governed peer-reviewed XNG completed-week/close-location
lineage, and Yang, Goncu, and Pantelous commodity-reversal lineage. The exact
Darwinex-CFD conjunction is explicitly an untested QM translation.

The canonical scan covered 4,946 registry rows and 1,555 repository cards. It
found no exact collision and one expected WTI upper-CLV fuzzy family match.
Manual review separated that WTI summer carrier/calendar from this XNG
shoulder-season implementation and separately checked the XNG neighbors. The
external Strategy Wiki mount was unavailable and that limitation remains
explicit.

## Q01 Evidence

- EA ID/magic: `QM5_41465`, slot 0, `414650000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Framework RNG, news, and Friday-close inputs are not equality-pinned; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `48887c1a-6006-4692-860e-618eee2f3dcb`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `cebef52fb042244b69685e982e6ebcf8fdd28039e2da967a997eccf36d5736a2`.
- EX5 SHA-256:
  `46e97ba5bbb5430d0606e35ace29f026b385a2ed65dd1434901820dea13f2163`.
- Final setfile SHA-256:
  `c63af3444f89eca642bbafd320ad878bb7804ee6428360b90314fb4d630f3608`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings and
zero failures.

## Q02 Admission And CPU Stop

Read-only first-Q02 intake returned `eligible=true` and
`would_enqueue=true` for exactly one `XNGUSD.DWX` D1 set. Two apply attempts
were then refused before mutation because the required governed SQLite backup
exceeded its 60-second timeout. Both commands exited nonzero, and inspection
confirmed that no Q02 row had been created.

Before another attempt, the required five-sample CPU admission measured
`[71.6, 69.8, 88.5, 99.4, 92.4]`; average `84.34%`, maximum `99.4%`, threshold
`97.0%`. The maximum hit the binding ceiling, so no further apply command was
run and no Q02 work item exists for this EA.

No backtest, fanout, rerun, downstream phase, manual dispatch, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, terminal
control, or live operation was touched.
