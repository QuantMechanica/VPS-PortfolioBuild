# Q09 REQUAL-8 pair 7 Q02 admission block

- Recorded: `2026-09-02T00:12Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR7_Q02_BLOCKED_SMOKE_WAIVER_BINDING`

## Outcome

The fresh pair-7 EA review exists as
`58882906-5836-4ea5-9395-ea973cbe3c31`, is `done`, records
`APPROVE_FOR_BACKTEST`, and binds build task
`0f36f1bb-924b-4126-b682-c30ba1edfa41`. The approved manifest's exact
append-only command was therefore attempted once:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id 58882906-5836-4ea5-9395-ea973cbe3c31 --phase Q02
```

The canonical controller refused before insertion:

```json
{
  "build_task_id": "0f36f1bb-924b-4126-b682-c30ba1edfa41",
  "detail": "deferred_p2_smoke is valid only with durable tester-fleet saturation evidence",
  "ea_id": "QM5_41221",
  "enqueued": false,
  "reason": "q01_smoke_waiver_missing_capacity_evidence"
}
```

No dispatcher hint was run. No Q02 parent task or work item was created, the
pair-7 manifest hold was not released, and pair 8 was not started.

## Fail-closed admission finding

Pair 7's sealed build result records `smoke_result=deferred_p2_smoke`. Its
stored reason says that the 2026-09-01 census saw seven `terminal64` processes,
active tester-owned work on T1/T4/T6/T8/T9, and resident workers T1-T10. That
is a process/occupancy observation, but it does not establish that the tester
fleet was saturated or that the governed smoke resolver returned
`status=no_capacity`.

`farmctl._q01_smoke_admission()` admits a deferred smoke only when the same
durable build record contains explicit saturation evidence. The current
generation-0 build record does not meet that predicate, so the refusal is the
correct fail-closed result. Retrofitting capacity text into the sealed build
task or artifact would mutate historical reviewed evidence and was not done.
A real smoke was also not launched: the pair-7 build prompt prohibits direct
smoke/terminal invocation, and this orchestration cycle never starts terminals
or interrupts factory tests.

## Sealed artifact revalidation

The prior pair-7 artifact bindings remain unchanged:

| Artifact | SHA-256 |
|---|---|
| Build result | `4468cb8c2028bbd6480b6df043cf1564dadab32af58cad446a0d2607a8800268` |
| MQ5 | `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f` |
| EX5 | `3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1` |
| SPEC | `ecd2934dfdb42576f01d5ade15f481603df6a2ba8278832ac62d2ceea770490b` |
| EURUSD.DWX D1 backtest set | `ee72ead97a1a8cf2bb1998ad064c52a4a9128c052e365117062b4771666e3bf6` |

Focused checks:

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; only the three expected warnings
  caused by the approved recovery card residing in runtime `cards_review`.
- Exact symbol matrix and active magic slot 0 for `EURUSD.DWX`: `PASS`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

No compile or pipeline phase was run, and no pipeline verdict is asserted.

## Serial-state and no-touch proof

- Pair-7 Q02 work-item count after the refused command: zero.
- Pair-7 manifest hold
  `30584122-b7b3-41eb-8e1a-b03517554d4d`: `pending`, unclaimed, no verdict,
  `Q09_AWAITING_SEALED_PLAN`, active, with no release note.
- Pair-8 `QM5_41222`: zero farm tasks, zero work items, and only
  `docs/strategy_card.md` exists in its EA directory.
- Protected `QM5_41162 / OPT_CENSUS`: 1,161 terminal rows (237
  `done/MEASURED`, 924 `done/SKIPPED_EXCLUDED`) with canonical ordered-row
  SHA-256 `fdc02350a0acc2351d9b4beb9efac94866af3dbd1ae7a7a14278cb301d128d4c`,
  unchanged from the preceding pair-7 checkpoint.

No historical work item, review, build result, EA artifact, setfile, protected
program row, terminal, AutoTrading setting, `T_Live` setting, main branch, or
`C:/QM/worktrees/cto_main` state was changed.

## Required continuation

Preserve the generation-0 build and reviews. Use the normal bounded rework
path to mint a new build generation that binds either a genuine governed smoke
PASS or task-bound durable saturation evidence. Require fresh generation-
matched mechanical and independent review before retrying the manifest's exact
Q02 command. Only after exactly one pair-7 Q02 row is read back may the exact
pair-7 hold receive the manifest's verbatim release note. Pair 8 remains
strictly downstream of that boundary.

## Verdict

`PAIR7_Q02_BLOCKED_SMOKE_WAIVER_BINDING`: the only authorized enqueue path
failed closed, with zero seed, zero release, zero historical mutation, and zero
protected-program interruption.
