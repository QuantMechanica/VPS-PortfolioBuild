# Decision: FTMO governor — target-before-day-4 completion = Option A (supervised manual)

- Date: 2026-07-26
- Status: accepted (OWNER: „Punkt 8: A, diese Gefahr laufen wir mit unseren EAs und Buch eh
  nie!", midday chat)
- Relation: WS-G′ §6.3 (`D:/QM/reports/ultracode_20260726/wsg/target_before_day4_design.md`,
  BLOCKER_INVENTORY.md §6.3); governor spec QM5_13206.

## The rule

When the governor latches „target reached, opening days < 4" (fail-safe already built:
flat, entries locked, `QM_FTMO_GOVERNOR_TARGET_MIN_DAYS_PENDING`), the remaining opening
days are produced **manually under supervision**: one micro-position per required day
(minimum lot, immediately managed flat), executed by OWNER/Claude per runbook step. **No
automated re-open path is built or armed** (Option B rejected — automated trading logic on
the money guard is not justified for a tail scenario; OWNER: with this book the scenario
practically never occurs, the sealed model's 30-day mean ending is ~$99.8k).

## Guard rails

- The latch itself stays fully automatic; only day-completion is manual.
- If trial-phase availability ever makes Option B necessary, it requires a new dated
  decision plus its own golden tests — never a silent addition.
