# QM5_20171 Brent 3M TSMOM — Q01 PASS / Q02 CPU-Ceiling Handoff

**Date:** 2026-07-26  
**Branch:** `agents/board-advisor`  
**Scope:** one new structural low-frequency commodity/energy card and V5 build

## Outcome

`QM5_20171_brent-tsmom3m` mechanizes a monthly Brent trend carrier: direction
is the sign of the completed 63-D1 log return, with monthly renewal, a frozen
`3.5 * ATR(20)` hard stop, and a 31-day stale close. It is distinct from
`QM5_12849_brent-tsmom12m` (252-D1 horizon) and
`QM5_12859_brent-52w-anchor` (annual-extreme anchor plus confirmation).

The reputable source lineage is Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics*, preserved at
`strategy-seeds/sources/MOP-TSMOM-2012/`.

## Deterministic evidence

- Card schema lint: PASS, no ML hits or missing sections.
- Spec validation: PASS.
- Registry: EA 20171, magic slot 0, `XBRUSD.DWX`, magic `201710000`.
- Final strict build check:
  `D:\QM\reports\framework\21\build_check_20260726_061001.json`.
- Compile summary:
  `D:\QM\reports\compile\20260726_061001\summary.csv`.
- Compile result: PASS, 0 errors, 0 warnings.
- Binary SHA256:
  `F13E3E3EE5CCEBFD96AB1E9BF9AE51AF88254089C60B1DD7754F57ED9502A7CD`.
- Canonical backtest setfile:
  `framework/EAs/QM5_20171_brent-tsmom3m/sets/QM5_20171_brent-tsmom3m_XBRUSD.DWX_D1_backtest.set`.
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## CPU-ceiling stop

At `2026-07-26T06:11:05Z`, `farmctl.py mt5-slots` reported exactly seven
active factory pipeline terminals, the paced-fleet ceiling:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T1 | QM5_1260 | Q04 | EURJPY.DWX |
| T4 | QM5_10582 | Q07 | XAUUSD.DWX |
| T6 | QM5_1567 | Q07 | GBPJPY.DWX |
| T7 | QM5_1567 | Q07 | XAGUSD.DWX |
| T8 | QM5_1567 | Q07 | USDJPY.DWX |
| T9 | QM5_12834 | Q03 | logical XTI/USDJPY spread |
| T10 | QM5_1567 | Q07 | GBPNZD.DWX |

`T_Live` and the FTMO terminal were separately observed as non-pipeline
processes and were untouched. Per the mission stop rule, no smoke test,
record-build auto-enqueue, Q02 work-item insertion, dispatch, portfolio gate,
deploy/T_Live manifest, live setfile, AutoTrading state, or live terminal was
changed.

## Handoff

When active factory usage is below seven, verify that no pending or active
QM5_20171 Q02 row exists, then record the existing build task
`ae153e65-ea95-4c39-9950-5130cdbf7490` with a deferred-smoke build result so
the supported farm path enqueues exactly one `XBRUSD.DWX` D1 Q02 row.
