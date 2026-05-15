# QUA-1607: QM5_1006 entry-gate root cause and v2 adjustment (2026-05-15)

## Scope
- Issue: `QUA-1607`
- EA lineage: `QM5_1006_davey-eu-day` -> `QM5_1006_davey-eu-day_v2`
- Change class: **entry-only** (Enhancement Doctrine compliant)

## Root-cause note (strategy-level)
Validated P2 evidence showed zero trades on EURUSD.DWX (`MIN_TRADES_NOT_MET`).

Entry suppression chain in v1 was:
1. `g_trade_taken_today` reset at 13:00 bar only.
2. Time gate required `Hhmm(bar_t) < 1500`, which on H1 leaves only two eligible decision bars/day (13:00 and 14:00 closed bars).
3. Within that narrow window, entry still required simultaneous extremum + momentum conditions (`h1 >= HighestHigh(xb)` with `c1 < close[xb2]`, or symmetric long condition).

Result: practical entry opportunity density was too low for the validated window, producing zero entries/fills.

## v2 decision and patch path
- Decision: implement **minimal v2 entry-gate relaxation**.
- Patch path:
  - `framework/EAs/QM5_1006_davey-eu-day_v2/QM5_1006_davey-eu-day_v2.mq5`
  - `framework/EAs/QM5_1006_davey-eu-day_v2/sets/QM5_1006_davey-eu-day_v2.set`
  - `framework/EAs/QM5_1006_davey-eu-day_v2/sets/QM5_1006_davey-eu-day_v2_EURUSD.DWX_H1_backtest.set`

Entry-only delta:
- `strategy_time_cutoff_hhmm`: `1500` -> `2000`

No changes to:
- risk plumbing / magic resolution / news / Friday close framework hooks
- stop/target math
- exit logic (`Strategy_ExitSignal`, `Strategy_ManageOpenPosition`)

## Next pipeline action (for dispatcher)
Use v2 EA + v2 EURUSD H1 setfile for next P2 attempt.

Suggested invocation shape:
`python framework/scripts/p2_baseline.py --ea QM5_1006_davey-eu-day_v2 --period H1 --year 2024 --runs 2 --symbols EURUSD.DWX`

## Notes
- This issue used repository evidence + code inspection only; no PASS/FAIL claim is made here.
- CTO review required before Pipeline-Operator run.
