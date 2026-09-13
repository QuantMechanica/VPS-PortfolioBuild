# QM5_41467 WTI Winter Upper-CLV Reversion — Q02 Enqueue

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; exactly one Q02
canary enqueued below the binding CPU ceiling.

## Edge

`QM5_41467_wti-winter-hclv-fade` is a low-frequency WTI seasonal-reversion
sleeve. At the first tradable D1 bar of each November-through-May normalized
broker week, it reconstructs exactly the immediately completed three-to-five-
session week and sells only when the final close is strictly above two thirds
of that week's full range. It has no return-sign, range-rank, candle-body,
wick, stretch, or moving-average predicate and no long side.

The decision week is consumed before fallible gates. The position exits in
the next normalized week, with ten-calendar-day stale repair and one frozen
`3.5*ATR(20,D1)` hard stop. The WTI carrier, structural winter clock, weekly
close-location state, and fixed lifecycle differ from certified `QM5_12567`,
which is an all-year XNG long-only two-day cumulative-RSI pullback. Realized
portfolio correlation is unclaimed and remains a later Q09 measurement.

## Source And Identity

The complete-read packet combines peer-reviewed WTI November-May seasonality,
governed reputable completed-week/close-location lineage, and Yang, Goncu,
and Pantelous commodity-reversal lineage. The short direction is explicitly
counter to the regime's average positive drift, and the exact Darwinex-CFD
conjunction is an untested QM translation.

The canonical scan covered 4,948 registry rows and 1,557 repository cards. It
found no exact collision and five fuzzy family matches. Manual review
separated four range/body-conditioned two-week siblings, the disjoint summer
upper-tercile short, and the opposite-direction winter continuation sibling.
The external Strategy Wiki mount was unavailable and that limitation remains
explicit.

## Q01 Evidence

- EA ID/magic: `QM5_41467`, slot 0, `414670000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Framework RNG, news, and Friday-close inputs are not equality-pinned; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `b07f0f25-7314-442b-8cf0-62fec8204889`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `44218af8a69dcb7bf8f1b5b8d7fe11e0bb2d2f9e9ed13dfc19342373c90f7b7a`.
- EX5 SHA-256:
  `72e39cf1be887d17caec399ebc56441a8230cdc722d62dc28a662d03fff166e7`.
- Final setfile SHA-256:
  `ae72cc7660f22a52cc4e742ce086d81b34d24af03dc0c7e81f1f8be773f8c8d4`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings and
zero failures.

## Q02 Admission

Read-only first-Q02 intake returned `eligible=true` and
`would_enqueue=true` for exactly one `XTIUSD.DWX` D1 set. The generated
setfile initially had an empty input-bound `strategy_symbol`; this was
corrected to `XTIUSD.DWX`, after which the governed intake verified 18
nonempty strategy parameters, active magic, fixed-risk mode, current EX5,
and final setfile hash.

The required five-sample CPU admission measured
`[74.1, 74.5, 76.4, 73.0, 76.0]`; average `74.8%`, maximum `76.4%`, threshold
`97.0%`. Exactly one Q02 item was then appended:
`7d7009b9-861e-4bde-887d-6e3e317bda8a`, status `pending`. Receipt:
`D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/b07f0f25-7314-442b-8cf0-62fec8204889_7d7009b9-861e-4bde-887d-6e3e317bda8a.json`, SHA-256
`450dbf6dd8790282638d2fafecf8740e420e14e44d23604c58fad894aaa4d06b`.

No manual backtest, fanout, rerun, downstream phase, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, terminal
control, or live operation was touched.
