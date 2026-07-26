# QM5_20110 zero-trade recovery

Date: 2026-07-26  
Branch: `agents/board-advisor`

## Outcome

The two valid Q02 runs for `QM5_20110_xti-xng-fri-rv` produced zero trades
because the entry hook compared the card's broker-calendar Friday decision to
the Darwinex energy D1 bar label. The synchronized XTI/XNG D1 bars are labelled
with the prior calendar date, while the genuine first tradable tick of the new
session occurs on the current broker day. The Friday condition was therefore
unreachable.

This is an implementation repair under the approved card, not a mechanics
change. The EA still opens only the jointly sized long-XTI/short-XNG package on
the genuine new D1 session tick, uses the same directions, equal-notional and
combined `RISK_FIXED` sizing, ATR stops, Friday close, and one-attempt guard.

## Bound failed runs

- `88ce3d68-f207-4c9c-97d4-860bec13505f`:
  `D:/QM/reports/work_items/88ce3d68-f207-4c9c-97d4-860bec13505f/QM5_20110/20260725_081906/summary.json`
- `2e5c12d3-b741-4d38-83bc-5e641fa6574b`:
  `D:/QM/reports/work_items/2e5c12d3-b741-4d38-83bc-5e641fa6574b/QM5_20110/20260726_074028/summary.json`

Both runs used real ticks from 2018-07-02 through 2024-12-31, matched source
and deployed EX5/setfile hashes, initialized successfully, synchronized both
symbols, and emitted 322 `FRIDAY_CLOSE` events but no entry-attempt or order
events.

## Minimal repair

- Prime `QM_IsNewBar()` during initialization. A late attach on an already-open
  Friday session can no longer manufacture a new-bar event.
- On a genuine new-bar tick, evaluate the broker weekday and weekly attempt key
  from `TimeCurrent()` rather than the prior-date D1 session label.
- Keep the synchronized XTI/XNG bar timestamps as the history/alignment anchor.

No threshold, weekday, direction, signal, sizing, stop, exit, or market was
changed.

## Validation and paced-fleet stop

- Strict compile:
  `C:/QM/repo/framework/build/compile/20260726_084827/QM5_20110_xti-xng-fri-rv.compile.log`
- Verdict: `PASS`, zero errors, zero warnings.
- Recovery smoke: not launched.
- Reason: the pre-run process scan found eight active factory terminals
  (`T1`, `T2`, `T3`, `T4`, `T6`, `T7`, `T9`, and `T10`), above the
  seven-terminal CPU ceiling. The separate `T_Live` process was observed and
  untouched.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_20110 | two Q02 real-tick runs above | prior-date D1 label made Friday entry unreachable | broker-day decision on primed genuine new bar | PASS | proof deferred | proof deferred | one trade-capability smoke and same-bound Q02 rerun |

The prior Q02 enqueue contract was satisfied; both queue items completed as
`DRAFT_DEFECT`. A repaired Q02 retry was not enqueued because doing so at the
observed fleet ceiling would violate paced execution discipline.

## Safety

No tester was launched, no terminal was stopped, and no live setfile,
AutoTrading state, `T_Live` manifest, portfolio gate, or portfolio-admission
artifact was changed.
