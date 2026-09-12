# QM5_41463 WTI Winter Upper-CLV Continuation — Q02 Handoff

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; exactly one Q02 row enqueued.

## Edge

`QM5_41463_wti-winter-hclv-cont` is a low-frequency direct-WTI sleeve. At the
first tradable D1 bar of a November-through-May normalized week, it
reconstructs exactly the immediately completed week and buys only when that
week's close-location value is strictly above two thirds. There is no weekly
range-rank comparison and no open-to-close body-sign gate. The position exits
in the next normalized week or after ten calendar days, with one frozen
`3.5*ATR(20,D1)` hard stop.

This is distinct from certified `QM5_12567`, an XNG two-day oscillator
pullback, and from `QM5_41440`/`QM5_41447`, which require two completed weeks
and a strict newest-versus-prior range state. `QM5_20209/20218` use
calendar-month return signs instead of weekly close location. Realized
portfolio correlation remains a later Q09 measurement; no decorrelation
result is claimed here.

## Source, Identity, And G0

The complete-read source packet combines Burakov, Freidin, and Solovyev's
peer-reviewed WTI November-May seasonal leg, Moskowitz, Ooi, and Pedersen's
peer-reviewed commodity-continuation lineage, and governed Crabel completed-
week/close-location lineage. The exact Darwinex CFD conjunction is explicitly
an untested QM translation.

The canonical pre-allocation scan covered 4,944 registry rows and 1,553
repository cards. It found no exact or fuzzy repository match. Its external
Strategy Wiki root was unavailable, so the checker failed closed and the
limitation was preserved; OWNER-authorized manual repository review separated
the two-week range-state and monthly-sign families before allocation. Card
schema lint passed.

## Build Evidence

- EA ID/magic: `QM5_41463`, slot 0, `414630000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- The guard pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and
  backtest `RISK_FIXED>0` / `RISK_PERCENT=0`.
- RNG, news, and Friday-close inputs are not equality-compared; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `cb0cdcec-952d-458e-8ecc-02b3376538ad`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `c5d7b9ca2a6f9eb0aa821979c6ed6461010fe1729e1637e2416262ceca5d2360`.
- EX5 SHA-256:
  `dce8d45c06f56fe41df571af2ab558c97f0fecd62aecc264b5b2b0a860e84954`.
- Final Q02-bound setfile SHA-256:
  `970f6575d65f3df6989d070d635483969f622eb2d5d748af3e5b4ee2b77281a1`.
- Set contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings
(loss-limit, broker-time window, and pending-order fields undecidable) and
zero failures. The approved card and SPEC explicitly lock fixed-dollar risk,
the normalized broker-week clock, and market orders.

## Q02 And CPU Admission

Read-only first-Q02 intake returned `eligible=true` and `would_enqueue=true`
for exactly one `XTIUSD.DWX` D1 set. The immediately preceding CPU samples
were `[76.9, 82.0, 78.6, 78.0, 77.1]`; average `78.52%` and maximum `82.0%`,
strictly below the `97.0%` ceiling.

Exactly one Q02 row was appended:

- work item: `808bf133-94f2-4aaf-8edf-f0cbbae9840f`;
- phase/symbol/timeframe: `Q02` / `XTIUSD.DWX` / D1;
- intake receipt SHA-256:
  `af0d2fab64b7bab2f1d981471c5db38ad62474c11cce6037750c234012523c2d`;
- risk binding: fixed 1000, percent 0;
- priority boost: false; deferred symbols: none.

The result was deliberately not awaited because the mission ends at Q02
enqueue. No fanout, rerun, downstream phase, manual dispatch, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live
operation was touched.

