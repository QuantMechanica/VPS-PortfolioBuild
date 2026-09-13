# QM5_41466 WTI Summer Lower-CLV Reversion — Q01 CPU Stop

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; Q02 not enqueued
because the binding CPU ceiling was hit.

## Edge

`QM5_41466_wti-summer-lclv-fade` is a low-frequency WTI seasonal-reversion
sleeve. At the first tradable D1 bar of each June-through-October normalized
broker week, it reconstructs exactly the immediately completed three-to-five-
session week and buys only when the final close is strictly below one third
of that week's full range. It has no return-sign, range-rank, candle-body,
wick, stretch, or moving-average predicate and no short side.

The decision week is consumed before fallible gates. The position exits in
the next normalized week, with ten-calendar-day stale repair and one frozen
`3.5*ATR(20,D1)` hard stop. The WTI carrier, structural summer clock, weekly
close-location state, and fixed lifecycle differ from certified
`QM5_12567`, which is an all-year XNG long-only two-day cumulative-RSI
pullback. Realized portfolio correlation is unclaimed and remains a later
Q09 measurement.

## Source And Identity

The complete-read packet combines peer-reviewed WTI June-October seasonality,
governed reputable completed-week/close-location lineage, and Yang, Goncu,
and Pantelous commodity-reversal lineage. The buy direction is explicitly
counter to the regime's average negative drift, and the exact Darwinex-CFD
conjunction is an untested QM translation.

The canonical scan covered 4,947 registry rows and 1,556 repository cards. It
found no exact collision and four fuzzy family matches. Manual review
separated two range/body-conditioned two-week siblings, the disjoint upper-
tercile summer short, the lower-tercile winter long, and the opposite-
direction summer lower-tercile continuation. The external Strategy Wiki
mount was unavailable and that limitation remains explicit.

## Q01 Evidence

- EA ID/magic: `QM5_41466`, slot 0, `414660000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Framework RNG, news, and Friday-close inputs are not equality-pinned; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `b6ccc50f-af38-4f28-b0b9-76ec087b87eb`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `d6fcf407682de3a130e5f189cbbd025bf447c57cb5e9b71ccd019a10f00d55f7`.
- EX5 SHA-256:
  `16d07662bf03bd08333e4ccd0d933f9e989fa43d0e0fcaf22ce1f629cf72f789`.
- Final setfile SHA-256:
  `c04d0b35a446c465677c52d94bc9f2a54b1992e2dae732db20ae2f3b2b5f1611`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings and
zero failures.

## Q02 Admission And CPU Stop

Read-only first-Q02 intake returned `eligible=true` and
`would_enqueue=true` for exactly one `XTIUSD.DWX` D1 set. The first apply
attempt was refused before mutation because the required governed SQLite
backup exceeded its timeout:
`GOVERNED_STATE_BACKUP_TIMEOUT:elapsed_seconds=63.671:remaining_pages=0:total_pages=309102`.
The command exited nonzero. A subsequent read-only intake again returned
eligible, proving that no Q02 row had been created.

Before another attempt, the required five-sample CPU admission measured
`[64.8, 60.7, 67.4, 61.4, 98.6]`; average `70.58%`, maximum `98.6%`, threshold
`97.0%`. The maximum hit the binding ceiling, so no further apply command was
run and no Q02 work item exists for this EA.

No backtest, fanout, rerun, downstream phase, manual dispatch, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, terminal
control, or live operation was touched.
