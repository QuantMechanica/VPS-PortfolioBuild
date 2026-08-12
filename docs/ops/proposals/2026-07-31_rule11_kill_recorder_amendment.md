# Proposal — Rule 11 manual-kill evidence recorder

Date: 2026-07-31

Status: **RATIFIED BY OWNER 2026-07-31 — merged into OPERATING_RULES_2026-07-03.md Rule 11**

The recorder implementation and tests remain available, but the following
amendment is not part of the ratified Operating Rules unless OWNER explicitly
approves it and that decision is recorded durably.

## Proposed Rule 11 addition

Before every OWNER-authorized manual terminal or worker kill, write a
non-destructive identity snapshot:

```text
python tools/strategy_farm/manual_process_kill_evidence.py \
  --pid <PID> \
  --target-type terminal|worker \
  --actor <who> \
  --reason <why> \
  --authority-ref <OWNER-or-task-evidence>
```

Exit 0 and the returned `event_id` should be cited in the operations evidence.
The recorder does not kill a process. It rejects `T_Live` and targets without a
canonical path anchor, then appends to
`D:\QM\reports\state\manual_process_kills.jsonl`.

## Rationale and disposition

The proposal would make the already implemented evidence recorder mandatory
for authorized manual kills, strengthening the existing path-anchored and
`T_Live`-excluded Rule 11. The 2026-07-31 convergence ledger contains no OWNER
ratification note for this amendment as of this ticket. Therefore the binding
Operating Rules were restored to their previously ratified text, while this
proposal preserves the exact policy question for OWNER decision. The recorder
tool and its tests are unchanged.
