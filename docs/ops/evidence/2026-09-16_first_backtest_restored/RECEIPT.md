# FIRST_BACKTEST_RESTORED — Factory Economic Validation Resumed

**Timestamp (first claim):** 2026-09-16T05:52:03–05:52:38Z
**Classification path:** Q08_DSR_CONTEXT_UNAVAILABLE holds released via governed repair (agent-17, Kimi interim delegation) → canonical selector rows became truly-claimable → workers claimed autonomously within seconds.

## Restored work items (verified native)

| work_item_id | EA | Symbol | Gate | Worker | Terminal PID | Evidence path |
|---|---|---|---|---|---|---|
| d02a1128… (QM5_13137) | QM5_13137 | XAUUSD.DWX | Q08 | T10 | terminal64 PID 16668 | D:\QM\reports\pipeline\QM5_13137\Q08\_baseline |
| fa6f023c9… (QM5_11121) | QM5_11121 | XAUUSD.DWX | Q08 | T4 | terminal64 PID 8804 | D:\QM\reports\pipeline\QM5_11121\Q08\_baseline |

## Native verification checklist (all observed)

- [x] worker claims valid work item (T4/T10 claim events in terminal_worker logs, claimed_by set)
- [x] terminal process starts (2 NEW terminal64: 8804, 16668; pre-existing 9288/10836 untouched = live/demo terminals)
- [x] 2 × metatester64.exe executing (real Strategy Tester agents)
- [x] correct worker owns it (claimed_by T4/T10 matches new terminal PIDs' worker dirs)
- [x] correct EA/symbol/gate (payload artifact_identity: ex5/mq5/setfile sha256-bound for 11121/13137 XAUUSD Q08)
- [x] RAM guard respected (45.7 GB free; Q08 XAUUSD class within measured reservation)
- [x] report output begun (pipeline/QM5_*/Q08/_baseline dirs created 05:5xZ, actively written)
- [x] work-item heartbeat updating (updated_at advancing on both active rows)
- [x] no duplicate claim (exactly one claimant each; claim_class_ledger atomic)
- [x] no T_Live interaction (T_Live terminal not among claimants; reservations respected)

## Path legitimacy

- Holds released: `Q08_DSR_CONTEXT_UNAVAILABLE` on both rows, released_at 2026-09-16T05:51:42Z / 05:52:03Z via the governed repair path (no hold was force-deleted; release followed context reconstruction — agent-17 full receipt pending its completion).
- No verdicts rewritten, no fabricated declarations, no manual DB row creation, no raw terminal launches — workers claimed through the canonical claim path.

## Health-contract state

RUNNABLE_WORK_EXISTS = true · active_economic_backtests = 2 · FACTORY_IDLE_WITH_RUNNABLE_WORK = not raised.
Watchdog v2 expected record: `no_runnable_work=false`.

## Next

- Agent-17 continues through the remaining Q08 population (21 rows classified CANONICALLY_RECONSTRUCTABLE vs REQUIRES_DECISION vs MISSING_EVIDENCE).
- Fill capacity from further released rows as they become claimable (owner expectation #9).
