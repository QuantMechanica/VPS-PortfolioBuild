# QM5_41464 WTI Winter Lower-CLV Reversion — Q01 CPU Stop

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; Q02 not enqueued because the binding CPU ceiling was hit.

## Edge

`QM5_41464_wti-winter-lclv-fade` is a low-frequency direct-WTI sleeve. At
the first tradable D1 bar of each November-through-May normalized broker week,
it reconstructs exactly the immediately completed three-to-five-session week
and buys only when the final close is strictly below one third of that week's
full range. It has no range-rank or candle-body predicate, no short side, and
exits in the next normalized week with a frozen `3.5*ATR(20,D1)` hard stop.

The rule differs from certified `QM5_12567` (XNG two-day cumulative-RSI
pullback) and from `QM5_41442`/`QM5_41456` (two-week range-state symmetric
fades). Realized portfolio correlation is unclaimed and remains a later Q09
measurement.

## Source And Identity

The complete-read source packet combines Burakov, Freidin, and Solovyev's
peer-reviewed November-May WTI seasonality, governed Crabel completed-week and
close-location construction, and Yang, Goncu, and Pantelous commodity-reversal
lineage. The exact Darwinex-CFD conjunction is explicitly an untested QM
translation.

The canonical scan covered 4,945 registry rows and 1,554 repository cards. It
found no exact collision and four expected fuzzy family matches. Manual review
separated those two-week range-state variants from this one-week, no-range-rank,
winter-premium long-only rule. The external Strategy Wiki mount was unavailable
and that limitation remains explicit.

## Q01 Evidence

- EA ID/magic: `QM5_41464`, slot 0, `414640000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Framework RNG, news, and Friday-close inputs are not equality-pinned; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `dcf47ab2-34a3-4d51-b159-444c00f8c9ac`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `f19e910c6044e1eb9cb4c9c9bd83ef63ef03c1e6aee847e55a7d3cab22041bf8`.
- EX5 SHA-256:
  `3b5b48d785060f3cea0f249b3feabfd04570635e77559a43e15a59d87618c677`.
- Final setfile SHA-256:
  `1cb139a0f949dee46270d9e46dc336e1f975b7a0b5507873d40db9737c21ecdf`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings and
zero failures.

## Q02 CPU Stop

Read-only first-Q02 intake returned `eligible=true` and
`would_enqueue=true` for exactly one `XTIUSD.DWX` D1 set. The immediately
following CPU admission samples were `[100.0, 97.1, 91.8, 90.4, 89.3]`;
average `93.72%`, maximum `100.0%`, threshold `97.0%`. Because the maximum
hit the binding ceiling, no `intake-first-q02 --apply` command was run and no
Q02 work item exists for this EA.

No backtest, fanout, rerun, downstream phase, manual dispatch, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, terminal
control, or live operation was touched.

