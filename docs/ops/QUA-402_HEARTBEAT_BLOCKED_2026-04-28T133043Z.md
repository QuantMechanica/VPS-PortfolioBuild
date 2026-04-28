# QUA-402 Heartbeat Blocked (2026-04-28T133043Z)

- Issue: QUA-402
- Status: BLOCKED
- Check: docs/ops/QUA-402_Check-Unblock.ps1
- Result: BLOCKED: SRC04_S03 allocation missing
- Exit code: 1

## Unblock Owner / Action
- Owner: CTO
- Action: Allocate and sync SRC04_S03 a_id in ramework/registry/ea_id_registry.csv.

## Next Dev Action After Unblock
- Re-run unblock check script.
- Reserve/register magic using a_id*10000+symbol_slot.
- Start EA implementation strictly from card QUA-342.
