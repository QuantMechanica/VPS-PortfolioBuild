# QM5_41460 WTI Summer NR2 Negative-Week Continuation — Q02 Handoff

Date: 2026-09-12
Branch: `agents/board-advisor`
Outcome: new card and EA built; Q01 PASS; exactly one Q02 row enqueued and completed FAIL.

## Edge

`QM5_41460_wti-summer-nr2-downweek-cont` is a low-frequency structural WTI sleeve. At the
first tradable D1 bar of a June-through-October normalized week, it reconstructs the two
immediately completed weeks. It shorts only when the newest week has a strictly narrower full
range than its predecessor and a strictly negative open-to-close body. The position exits in the
next normalized week or after ten calendar days, with one frozen `3.5*ATR(20,D1)` hard stop.

This is not the certified `QM5_12567` XNG two-day oscillator pullback. It is also distinct from
`QM5_41459`, whose strict range-expansion state is mutually exclusive, and `QM5_41457`, which
requires a positive week and fades it. Realized portfolio correlation remains solely a later Q09
measurement; no decorrelation result is claimed here.

## Source And G0

The bounded source packet combines completely read records for Burakov, Freidin, and Solovyev's
peer-reviewed WTI June-October seasonal leg, Moskowitz, Ooi, and Pedersen's peer-reviewed
commodity time-series momentum, and governed Crabel weekly range-state construction. The exact
Darwinex CFD conjunction is explicitly an untested QM translation.

The canonical pre-allocation scan found no exact identity across 4,941 registry rows and 1,550
cards, returned seven fuzzy matches, and reported the external Strategy Wiki root unavailable.
Manual predicate review resolved the family matches as nonidentical. Card lint passed with no ML
hits or missing sections.

## Build Evidence

- EA ID/magic: `QM5_41460`, slot 0, `414600000`.
- Mandatory final-source PACER audit: `ok=true`, `EA_FRAMEWORK_INPUT_PINNED`,
  `hit_count=0`.
- The source pins only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and backtest
  `RISK_FIXED>0` / `RISK_PERCENT=0`.
- RNG, news, and Friday-close inputs are not equality-compared; stress rejection has only finite
  inclusive `0..1` validation.
- Reference tests: 10 passed.
- SPEC validator: PASS.
- Build guardrails: PASS; single-symbol scope: `SINGLE_SYMBOL_OK`.
- Compile item: `ff9f513f-bef0-4fff-9053-0b267b98b5ba`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings; strict build check PASS.
- MQ5 SHA-256: `7ffd9860c7826259299ac4e459823372810214373656b1b35f8c03f0d50973e5`.
- EX5 SHA-256: `b5cf35747c904f4693e190395eb0b387ba9bdeeb37ab1423711bdba0573cdb4d`.
- Setfile SHA-256: `d704c4470cb9fc7a673082dba57d3669fd9fdd43e32240ca08ad44cca1b8c890`.
- Set contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`; no live set exists.

The integrated build check emitted three nonfatal card-inference warnings (loss-limit, broker-time
window, and pending-order fields undecidable) and zero failures. The explicit approved card and
SPEC lock fixed-dollar risk, the weekly broker clock, and market orders only.

## Q02 And CPU Admission

Read-only first-Q02 intake returned `eligible=true` and `would_enqueue=true` for exactly one
`XTIUSD.DWX` D1 set. Fresh whole-host CPU samples were
`[87.0, 73.9, 74.0, 80.6, 85.1]`; maximum `87.0%`, below the strict `97.0%` ceiling.

Exactly one Q02 row was appended:

- work item: `dba9a0cb-f6b8-417a-a8fb-69595fa8288f`;
- phase/symbol/timeframe: `Q02` / `XTIUSD.DWX` / D1;
- intake receipt SHA-256: `77be8a6921274623307981c9666f34b3fa1c07b56974871955664cdd36e969f1`;
- terminal state: FAIL, `MIN_TRADES_NOT_MET`, attempt 0;
- result: 23 trades against the 25-trade floor, PF 1.24, net profit 647.68, and 1.90% drawdown;
- evidence: `D:\QM\reports\work_items\dba9a0cb-f6b8-417a-a8fb-69595fa8288f\QM5_41460\20260912_174552\summary.json`.

No rerun or downstream phase was launched. No manual dispatch was used. No portfolio gate, portfolio admission, deploy/live
manifest, `T_Live`, AutoTrading, or live operation was touched.
