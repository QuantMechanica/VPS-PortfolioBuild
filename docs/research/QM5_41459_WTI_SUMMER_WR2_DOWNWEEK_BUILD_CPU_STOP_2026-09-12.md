# QM5_41459 WTI Summer WR2 Down-Week Continuation — Build And CPU Stop

Date: 2026-09-12  
Branch: `agents/board-advisor`  
EA: `QM5_41459_wti-summer-wr2-downweek-cont`

## Outcome

Built and Q01-certified one new low-frequency WTI candidate. During June through October it
requires the newest of two completed broker weeks to have a strictly wider range than its
predecessor and a strictly negative open-to-close body, then shorts for one normalized week with
a frozen `3.5*ATR(20,D1)` stop. Q02 was not enqueued because the mandatory fresh CPU admission
window reached the hard ceiling.

## Source And Non-Duplicate Evidence

The approved packet combines the peer-reviewed Burakov, Freidin, and Solovyev WTI summer-season
result, the peer-reviewed Moskowitz, Ooi, and Pedersen time-series-momentum lineage, and governed
Crabel completed-week/range construction. No source claims this exact CFD conjunction.

The pre-allocation scan found no exact identity across 4,940 registry rows and 1,549 cards,
reported four fuzzy family matches, and could not inspect the unavailable external Strategy Wiki.
Manual review separates the candidate from unconditional and two-sign summer rules, symmetric
winter WR2 continuation, and especially `QM5_41458`: that sibling requires a positive body and
fades it, while 41459 requires a negative body and continues it. Those predicates are mutually
exclusive.

## Build Evidence

- Research/card approval commit: `e361190e4e`.
- EA-ID allocation commit: `69a191c5c9`.
- Magic/resolver allocation commit: `98c026de85`; slot 0 / magic `414590000` verified after
  regeneration.
- Source build commit: `f68d0ad7ff`.
- Card lint: PASS; deterministic reference tests: `10 passed`.
- Mandatory post-source/pre-compile PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- The guard locks only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and fixed-risk mode;
  RNG, news, and Friday-close inputs are not equality compared; stress rejection has only finite
  inclusive `0..1` validation.
- Compile work item: `4c2c1185-84f0-42df-9ba3-9c9fcc4c8ef9`, claimed by T4.
- Compile verdict: `COMPILE_OK`; zero compiler errors/warnings; strict build check PASS.
- MQ5 SHA-256: `ad60c4776b9ee4d39a0e20e88aa9172845344db7d5e6f46e3976f7926d5ead4b`.
- EX5 SHA-256: `ed978ce1e2b3557a6b0fd79a580744c45879544dae1462474c794219afacd26b`.
- Read-only first-Q02 intake: `eligible=true`, `would_enqueue=true`, one XTIUSD.DWX D1 set,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Binding CPU Stop

Fresh whole-host samples were `[99.0, 97.7, 86.7, 79.6, 76.6]`; average `87.92%`, maximum
`99.0%`, ceiling `97.0%`. Because at least one sample reached the ceiling, no
`intake-first-q02 --apply` command was run and no Q02 row or backtest was created.

## Handoff And Safety

When CPU is below the governed ceiling, rerun the read-only `intake-first-q02` check against
compile item `4c2c1185-84f0-42df-9ba3-9c9fcc4c8ef9`, take a fresh CPU window, and apply exactly
one first-Q02 intake only if eligible and below ceiling. No manual backtest, optimization,
portfolio-gate edit or admission, terminal control, deploy/live manifest, `T_Live`, AutoTrading,
or live operation occurred.
