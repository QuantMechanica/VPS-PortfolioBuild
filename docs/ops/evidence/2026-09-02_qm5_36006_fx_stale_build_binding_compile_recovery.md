# QM5_36006 FX stale-build-binding compile recovery

Date: 2026-09-02
Branch: `agents/board-advisor`

## Selection

`QM5_36006_nnfx-halftrend-jurik-coppock-engine` was selected as the clean,
approved low-frequency diversity candidate already built but stranded before
Q02. Its OWNER-approved card is `g0_status: APPROVED`, targets
`EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX` on D1, and carries approved R1-R4
and Tier-A source evidence. The card's HalfTrend/Jurik/Coppock/CMF mechanics do
not use ML or an indicator on the NNFX Dirty Dozen ban list. No strategy
mechanics were changed during this recovery.

The EA's three backtest setfiles remain fixed-risk:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1`

Current source SHA-256:
`014dc6e0c3d8e466a2947ae0ac1e6590ac0c491b17a67c37cbae748cc665dfb6`.
There is no current `.ex5`, so Q02 must not be enqueued yet.

## Root cause

The immutable predecessor COMPILE_EA work item
`ec88e76e-30a4-4f5a-a091-da380e06a7c8` failed before build-check or compile.
Its only refusal was `BUILD_TASK_BINDING_NOT_OPEN` under failure class
`CANDIDATE_RECHECK_REFUSED`: the source-bound build task had been closed while
compile workers were still under rollout hold. The evidence shows no compile
result, no build-check result, no `.ex5` hash, and zero bound setfiles. This is
an infrastructure/binding failure, not a strategy or compiler failure.

## Recovery

A new governed build task was opened for the same approved card:
`5fbafbb8-c8c6-4480-8157-b2577c229a1b` (`pending`). A new fail-closed,
append-only recovery path now permits an unchanged-source successor only when:

- the predecessor is an immutable, evidence-authenticated pre-compiler failure
  with exactly `BUILD_TASK_BINDING_NOT_OPEN`;
- the source hash, EA identity, fixed-risk contract, and failure evidence still
  match;
- a different, sole-open build task is bound to the same EA; and
- no `.ex5`, bound setfile hash, competing work item, or prior supersession is
  present.

It created successor `d445db75-f0c0-422b-9517-622028203c7b` and preserved the
failed predecessor through an explicit supersedes edge. The successor is
currently `pending`, unclaimed, attempt 0, with active
`COMPILE_EA_WORKER_ROLLOUT_PENDING` hold and `release_on_restart=1`.

The bounded release utility was also hardened to take the global factory
mutation lock, reserve a writer transaction before backup, write backups via a
`.partial` file, and roll back/clean up on a configurable timeout.

## Verification and stopping condition

- `python -m pytest -q tools/strategy_farm/tests/test_compile_work_items.py tools/strategy_farm/tests/test_release_compile_wave.py`
  -> `71 passed`
- Python syntax compilation passed for all changed scripts.
- `git diff --check` passed (line-ending warnings only).
- Dry-run release classified the exact successor as source-fresh and eligible.

The guarded production release was intentionally not completed. The live farm
database backup exceeded the bounded resource window and raised
`COMPILE_WAVE_BACKUP_TIMEOUT` after 62.016 seconds with 160956 of 179388 pages
still remaining. The transaction rolled back, the target `.partial` snapshot
was removed, and the global mutation lock was released. No compile or backtest
was launched and no Q02 row was created.

When farm database backup throughput recovers, release only this exact item:

```powershell
python tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id d445db75-f0c0-422b-9517-622028203c7b --backup-timeout-seconds 60 --release-note "QM5_36006 stale build-binding recovery canary" --apply
```

Then allow the normal worker to compile and smoke-check it. Only after a
compile-PASS `.ex5` and finalized setfile hashes should the build result be
recorded and Q02 be enqueued. Do not reopen the source or create another
COMPILE_EA item. No portfolio-gate, T_Live, manifest, or AutoTrading state was
touched.
