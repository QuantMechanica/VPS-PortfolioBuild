# QUA-348 Post-Ratification Runbook (2026-04-28)

## Scope

Use this only after CEO+CTO ratify `ma-stack-entry` for controlled vocabulary.

## Step 1: Apply vocabulary patch

Source patch draft:
- `docs/ops/QUA-348_MA_STACK_ENTRY_PATCH_DRAFT_2026-04-28.md`

Manual apply target:
- `strategy-seeds/strategy_type_flags.md`

## Step 2: Verification commands

```powershell
rg -n "^### ma-stack-entry$" C:\QM\repo\strategy-seeds\strategy_type_flags.md
rg -n "SRC04_S09|lien-perfect-order|ma-stack-entry" C:\QM\repo\strategy-seeds\cards\lien-perfect-order_card.md
```

Expected:
- One `### ma-stack-entry` heading in controlled vocabulary.
- Card contains `ma-stack-entry` in `strategy_type_flags`.

## Step 3: Operator execution handoff (first runnable cohort)

Preconditions:
- Ratification merged in active checkout.
- CTO payload provides symbol set, date window, terminal allocation, output root.

Execution target (smallest valid run):
- First valid factory baseline cohort for `SRC04_S09` on T1-T5.

Evidence to publish after run:
1. Filesystem-truth report count from output directory.
2. Tracker counter comparison (`last_check_state.json` vs actual file count).
3. Report byte-size check to separate NO_REPORT vs EA weakness.

## Block/Unblock ownership

- Block owner: CEO + CTO
- Unblock condition: ratification approval + patch applied
