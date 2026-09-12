# QM5_41461 WTI Summer Lower-CLV Continuation — Q02 Handoff

Date: 2026-09-12
Branch: `agents/board-advisor`
Outcome: new source-grounded card and EA built; Q01 PASS; exactly one Q02 row enqueued.

## Edge

`QM5_41461_wti-summer-lclv-cont` is a low-frequency direct-WTI sleeve. At the first
tradable D1 bar of a June-through-October normalized week, it reconstructs exactly the
immediately completed week and shorts only when that week's close-location value is strictly
below one third. There is no weekly range-rank comparison and no open-to-close body-sign gate.
The position exits in the next normalized week or after ten calendar days, with one frozen
`3.5*ATR(20,D1)` hard stop.

This is distinct from certified `QM5_12567`, an XNG two-day oscillator pullback, and from the
two-week range/body conjunctions in `QM5_41459` and `QM5_41460`. Realized portfolio correlation
remains a later Q09 measurement; no decorrelation result is claimed here.

## Source, Identity, And G0

The complete-read source packet combines Burakov, Freidin, and Solovyev's peer-reviewed WTI
June-October seasonal leg, Moskowitz, Ooi, and Pedersen's peer-reviewed commodity continuation
evidence, and governed Crabel completed-week/close-location lineage. The exact Darwinex CFD
conjunction is explicitly an untested QM translation.

The canonical pre-allocation scan covered 4,942 registry rows, 1,551 repository cards, and 45
external Strategy Wiki nodes. It found no exact duplicate. Manual review separated the two fuzzy
siblings: both require two completed weeks, a range comparison, and a body sign, while this rule
uses one week and CLV only. Card schema and G0 lints passed.

## Build Evidence

- EA ID/magic: `QM5_41461`, slot 0, `414610000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- The guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and backtest
  `RISK_FIXED>0` / `RISK_PERCENT=0`.
- RNG, news, and Friday-close inputs are not equality-compared; stress rejection has only finite
  inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `c43db5ca-c6a6-42f8-93b7-e3636160d967`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings; strict build check PASS.
- MQ5 SHA-256: `882328895af3a7aec33c4e2e1e5ecf5faccd3b5552bfb819bf3bcfc1df515bc1`.
- EX5 SHA-256: `395d0cb29a62fc14223cb8ea31ab1a21669a6aff47b74d0e04112e658973df0a`.
- Final Q02-bound setfile SHA-256:
  `34660f76e93fdbdc27c382cd5f0f1f07a9b3c5bc7b95e8677f4cdcde91177608`.
- Set contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings (loss-limit,
broker-time window, and pending-order fields undecidable) and zero failures. The approved card
and SPEC explicitly lock fixed-dollar risk, the normalized broker-week clock, and market orders.

## Q02 And CPU Admission

Read-only first-Q02 intake returned `eligible=true` and `would_enqueue=true` for exactly one
`XTIUSD.DWX` D1 set. The first mutation attempt made no change because the shared factory lock was
busy. The immediately preceding successful-intake CPU window was `[51.2, 52.8, 57.5, 61.3,
54.3]`; average `55.42%` and maximum `61.3%`, both below the strict `97.0%` ceiling.

Exactly one Q02 row was appended:

- work item: `17693447-ad67-424d-8b8c-085989669975`;
- phase/symbol/timeframe: `Q02` / `XTIUSD.DWX` / D1;
- intake receipt SHA-256:
  `b3ab9801d647696943e91d1787be87571aa70e81658549c2e06172cd4197551e`;
- risk binding: fixed 1000, percent 0;
- priority boost: false; deferred symbols: none.

The resident worker observed the row and claimed it on T2 after intake. Its result was deliberately
not awaited because the mission ended at Q02 enqueue. No fanout, rerun, downstream phase, manual
dispatch, portfolio gate, portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or
live operation was touched.
