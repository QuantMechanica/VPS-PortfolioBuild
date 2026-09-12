# QM5_41462 WTI Summer Upper-CLV Reversion — Q02 Handoff

Date: 2026-09-12  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; exactly one Q02 row enqueued.

## Edge

`QM5_41462_wti-summer-hclv-fade` is a low-frequency direct-WTI sleeve. At the
first tradable D1 bar of a June-through-October normalized week, it
reconstructs exactly the immediately completed week and shorts only when that
week's close-location value is strictly above two thirds. There is no weekly
range-rank comparison and no open-to-close body-sign gate. The position exits
in the next normalized week or after ten calendar days, with one frozen
`3.5*ATR(20,D1)` hard stop.

This is distinct from certified `QM5_12567`, an XNG two-day oscillator
pullback, and from `QM5_41457`/`QM5_41458`, which require two weeks plus range
state and body sign. `QM5_41461` uses the disjoint lower tercile under
continuation lineage. Realized portfolio correlation remains a later Q09
measurement; no decorrelation result is claimed here.

## Source, Identity, And G0

The complete-read source packet combines Burakov, Freidin, and Solovyev's
peer-reviewed WTI June-October seasonal leg, Yang, Goncu, and Pantelous's
academic commodity-reversal lineage, and governed Crabel completed-week/
close-location lineage. The exact Darwinex CFD conjunction is explicitly an
untested QM translation.

The canonical pre-allocation scan covered 4,943 registry rows and 1,552
repository cards. It found no exact duplicate and preserved the unavailable
external Strategy Wiki mount as a limitation. Manual review separated the two
fuzzy siblings by their two-week range/body predicates. Card schema lint
passed.

## Build Evidence

- EA ID/magic: `QM5_41462`, slot 0, `414620000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- The guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and
  backtest `RISK_FIXED>0` / `RISK_PERCENT=0`.
- RNG, news, and Friday-close inputs are not equality-compared; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `49ee8a59-75e6-44d6-a55e-469437808f4c`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `1e9b3623eee0f99b4e9fdc99abd142bed35cd20e5e2b47cc0faab9e45c8e3741`.
- EX5 SHA-256:
  `23606938b1ab2fd2dade3896492f88e098ca74384e5a2ef5d53f0294885bd64c`.
- Final Q02-bound setfile SHA-256:
  `88d36e89be4a8803fbae4d95fbf8190d38c607b48f8bb41ec764de65c15bb1ee`.
- Set contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings
(loss-limit, broker-time window, and pending-order fields undecidable) and
zero failures. The approved card and SPEC explicitly lock fixed-dollar risk,
the normalized broker-week clock, and market orders.

## Q02 And CPU Admission

Read-only first-Q02 intake returned `eligible=true` and `would_enqueue=true`
for exactly one `XTIUSD.DWX` D1 set. The immediately preceding CPU samples
were `[96.7, 94.6, 87.3, 81.6, 71.2]`; average `86.28%` and maximum `96.7%`,
strictly below the `97.0%` ceiling.

Exactly one Q02 row was appended:

- work item: `8e71be6c-790a-48d3-ac3e-265acba7fd95`;
- phase/symbol/timeframe: `Q02` / `XTIUSD.DWX` / D1;
- intake receipt SHA-256:
  `066b7b6f1de38e065058951674e225dcd2454cf8fd1975b6205c9fcc119e169b`;
- risk binding: fixed 1000, percent 0;
- priority boost: false; deferred symbols: none.

The result was deliberately not awaited because the mission ends at Q02
enqueue. No fanout, rerun, downstream phase, manual dispatch, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live
operation was touched.

