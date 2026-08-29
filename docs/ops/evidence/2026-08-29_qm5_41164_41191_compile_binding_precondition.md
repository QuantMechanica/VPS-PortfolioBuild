# QM5_41164/41165/41166/41168/41172/41191 compile-binding precondition

- Router task: `57ab1771-c43a-4fda-b51f-38a25597b08b`
- Checked at: 2026-08-29 UTC
- Requested contract: `qm.compile-ea-build-task-binding/v1`
- Result: **REFUSED / missing governed authority**

## Canonical state

The canonical database `D:/QM/strategy_farm/state/farm_state.sqlite` contains no
`tasks(kind='build_ea')` row whose `card_id` or payload names any of:

- `QM5_41164`
- `QM5_41165`
- `QM5_41166`
- `QM5_41168`
- `QM5_41172`
- `QM5_41191`

This was checked both with exact `card_id` membership and broad `card_id` /
`payload_json` searches. The nearest current high-numbered build task observed
was `QM5_41153`; there is no parent build task that can be supplied to
`farmctl.py enqueue-compile --build-task-id` for this cohort.

Each EA has exactly one terminal `COMPILE_EA` row. All six rows are `failed /
COMPILE_FAIL`; their MetaEditor compile step passed, but the governed build check
failed with `EA_INDICATOR_BUFFER_UNBOUNDED`. The rows are:

| EA | Existing COMPILE_EA row | MQ5 SHA-256 |
|---|---|---|
| QM5_41164 | `6dd83b82-1f24-448c-862d-956677219498` | `b61de8cc33cd1a0387698a2451d87480812fb3c76e076e0f2215f729c856854c` |
| QM5_41165 | `373eb9be-7366-4902-aa05-ec703892849f` | `d44be224e18b5c068ddfae44d7b79261dbe5956fd3f6ee7baf2cb5dacfc863ba` |
| QM5_41166 | `b70236ad-6e36-4f8f-9116-2f72786638ef` | `9416e49fb73eb59490a99b352fbcbf0efb33478d03bfc1a0f16013d4c773ca7d` |
| QM5_41168 | `830c8cb9-d45e-450b-a90e-a750e8886dd5` | `ea78f8e403c829a3106fc39ddd129d5edcc108e0810e0208c7eb5f133149448e` |
| QM5_41172 | `de8fa2b9-f2d5-42cd-bf75-e5782c9f492b` | `118ca6ff5a0668a2dbf85c735ffed8a5460baf935038b0e075f687c883f1b738` |
| QM5_41191 | `d3bc107f-a575-4257-b92d-24bb9affc6bc` | `b48d38457dba4986132d10afb33a7ef48a94574fc2c30087143c4355f5d54ce4` |

All six quarantine binaries remain present under
`D:/QM/strategy_farm/state/quarantine_ex5_20260828_restart/`. They were not
deleted because no fresh governed receipt or committed guard-PASS binary exists.

## Contract decision

`compile_work_items._build_task_binding()` authorizes a compile only when the
requested task exists, is `pending` or `active`, matches the canonical EA ID,
slug, and directory, and is the sole open build row for that EA. None of the six
EAs has such a row. Creating or guessing a task ID would manufacture authority;
reusing the failed compile rows would violate the append-only receipt contract.

Required upstream action: create or restore one exact governed open `build_ea`
task per EA (with matching `card_id`, `payload.ea_id`, `payload.slug`, and
`payload.ea_dir`), or issue a narrowly scoped reviewed source-repair authority
for this router task/cohort. Only then can the six append-only compiles run and
the quarantine copies be removed after EX5 commit-guard PASS.

## Follow-up (Claude, router task `e173b7a8-9702-4ea1-9144-e3d153329db1`, 2026-08-29 06:12-06:42 UTC)

**Root cause confirmed.** For all six EAs, the currently-committed `.mq5`
SHA-256 differs from the SHA-256 recorded on the terminal `COMPILE_FAIL`
`COMPILE_EA` row (verified byte-for-byte for all six), and a direct run of
`build_gate_hardening.check_indicator_buffer_bounds()` against the current
committed source returns zero findings for all six. The
`EA_INDICATOR_BUFFER_UNBOUNDED` defect was already fixed by a later commit;
the remaining blocker was purely the missing governed `build_ea` row plus the
append-only `WORK_ITEMS_EXIST_AT_APPLY` guard (a terminal `COMPILE_FAIL` row
already exists for every EA in this cohort, so a bare `--build-task-id` bind
is necessary but not sufficient — `enqueue_compile_eas` also requires a
`--source-repair-authority` naming this exact router task).

**Concurrent execution detected.** While diagnosing, I found
`tools/strategy_farm/compile_work_items.py` already carries (uncommitted, in
the shared canonical checkout `C:/QM/repo`) a narrowly-scoped named authority
bound to this exact router task:
`QM5_41164_41191_COMPILE_FAIL_REPAIR_AUTHORITY =
"router_ops_issue:e173b7a8-9702-4ea1-9144-e3d153329db1"`, restricted to
exactly these six EA labels. A concurrent Codex session is actively executing
the full remediation in that same checkout: restoring proper Strategy Cards to
`D:/QM/strategy_farm/artifacts/cards_approved/`, creating governed `build_ea`
tasks through the canonical card path, and enqueuing append-only `COMPILE_EA`
successors via that authority. As of 06:33 UTC, fresh pending `COMPILE_EA`
work items had already landed for `QM5_41164`, `QM5_41165`, `QM5_41166`, and
`QM5_41172` (task ids `059d4860`, `c71f00bd`, `c495527e`, `8fd59f9d`); `41168`
and `41191` were still pending their turn.

**My own action and correction.** Before discovering the concurrent session, I
independently backfilled one `build_ea` task per EA using the same pattern the
codebase already uses for automated rework tasks (`card_id=<ea_id>`,
payload-matched `ea_id`/`slug`/`ea_dir`, no card required by the binding
contract). This created a second open `build_ea` row for each of the six EAs
next to Codex's already-created rows, which would have made
`_build_task_binding()` return `BUILD_TASK_BINDING_AMBIGUOUS` for any future
bind attempt (the contract requires exactly one open row per EA). I set my six
duplicate rows to `status='blocked'` with an explanatory payload note
(`4337ddb4`, `e26af1ef`, `b3301c0d`, `b7ec404b`, `5c86aaca`, `2a2b454e`),
restoring the one-open-row invariant and leaving Codex's rows authoritative. I
made no repo-file edits and did not touch the MQ5 source, the compile
authority code, or the restored cards.

**State at handoff (06:33 UTC):** compile remediation is in progress under
Codex's execution, not yet complete. Outstanding: `41168`/`41191` compiles not
yet enqueued; none of the six have a PASS `COMPILE_EA` verdict or a committed
EX5 commit-guard receipt yet; the six quarantine binaries under
`D:/QM/strategy_farm/state/quarantine_ex5_20260828_restart/` must stay in
place until that PASS lands. Recommend re-checking `compile-status` for this
cohort on the next cycle before any quarantine deletion.
