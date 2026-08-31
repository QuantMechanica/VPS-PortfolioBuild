# Dirty build-guard recovery — task `7d0efff4`

Date: 2026-08-31 UTC

Lane: `codex` / `agents/board-advisor`

Scope: recover the two stale tracked modifications named by the router, prove the
build lane can dispatch again, and propose a recurrence guard. This note does
not change any build, review, or pipeline criterion.

## Result

The two stale tracked modifications were owned, verified, and committed with
explicit pathspecs. The repository reached a clean checkpoint, after which the
normal pump dispatched Codex build jobs again at 03:05 UTC. Files created after
that checkpoint are fresh outputs of those live build jobs, not the abandoned
files that caused this incident.

No terminal was launched, no running tester was interrupted, no pipeline
verdict was inferred, and no stale-news or risk guard was weakened.

## Ownership and recovery

### `QM5_41229_wti-samecal-trimean5.mq5`

The owning build is `e2c648cc-791b-4677-89fe-02af6cad2504`. Its rework came
from failed review `0c39bc3c-df80-41fd-9ec1-5b7be49129dd`, which required the
hand-rolled monthly clock to use the framework calendar helpers. The abandoned
source already contained that repair. Its SHA-256 is
`5304c186598d04e50d5d53a1794656cee935fc14a8cf33aea13725831e6aa718`, exactly
the MQ5 hash bound to governed compile work item
`585e59be-5f44-415b-bc23-403e9f360413` (`COMPILE_OK`; compile and build-check
PASS). The static reference test was stale, so it was updated to require
`QM_IsNewCalendarPeriod(PERIOD_MN1, g_symbol)` and
`QM_CalendarPeriodKey(PERIOD_MN1, g_symbol, 0)` and to ban the removed local
month-key helpers.

The checked-out EX5 is deliberately not presented as current acceptance
evidence: its hash is the earlier `8ed16319...`, while the latest compile receipt
binds `e7eb71c2...`. The existing governed build/review flow must restore that
binary binding. This recovery did not invoke a compiler or enqueue an
unauthorized successor.

### `tools/strategy_farm/compile_work_items.py`

The modification was the exact review-authority binding for the same repair:

`QM5_41229 -> router_review_ea:0c39bc3c-df80-41fd-9ec1-5b7be49129dd`

The corresponding exact-map test fixture was updated. This is a narrow
authorization record, not a generic compile bypass.

### Concurrent news-calendar refresh

While the recovery was in progress, the scheduled calendar refresher updated
`framework/registry/dxz23_execution_contracts.json`. The primary and
FILE_COMMON seed hashes matched the registry, and
`news_calendar_repin.py verify` passed with coverage through 2026-09-04. That
independent tracked refresh was committed separately; `qm_news_stale_max_hours`
was not changed.

## Commits and verification

- `47f276cc63` — `fix(41229): persist reviewed calendar rework`
  - exact paths: the QM5_41229 MQ5, its static reference test,
    `compile_work_items.py`, and its test
- `f048aba907` — `ops(news): bind refreshed calendar seed hashes`
  - exact path: `framework/registry/dxz23_execution_contracts.json`

Focused verification:

```text
python -m pytest \
  framework/EAs/QM5_41229_wti-samecal-trimean5/docs/test_same_calendar_trimean5_reference.py \
  tools/strategy_farm/tests/test_compile_work_items.py -q
56 passed in 8.14s

python tools/strategy_farm/news_calendar_repin.py verify
PASS; registry_pin_matches=true; coverage_end=2026-09-04

git diff --check
PASS
```

The normal pump subsequently recorded fresh Codex build dispatch heartbeats:

| Started UTC | Build task | EA |
|---|---|---|
| 03:05:13 | `b8761494-8807-41d8-b4a0-f1d4141588c4` | `QM5_1538` |
| 03:05:32 | `ca498dcb-0f31-4d64-8ff6-4de3d4e459e7` | `QM5_41223` |
| 03:05:41 | `1dcf4bb6-7684-4531-b77b-e36c91b6d063` | `QM5_41238` |

This is direct database evidence that the Codex build bridge resumed after the
clean checkpoint. It is not a claim that any of those builds passed review or a
pipeline phase.

## Root cause

The workers finished ticket-scoped edits but did not leave a durable commit
receipt before their sessions ended. The pump's existing auto-commit behavior
correctly handles allowlisted generated factory artifacts; it intentionally
does not sweep modified MQ5 source or control-plane Python into a generic
commit. Consequently, one uncommitted source repair and its authorization-map
edit survived for more than six hours. The fail-closed repository guard then
blocked all later build dispatches, turning two abandoned files into a global
head-of-line block.

The guard worked as designed. The missing contract is between successful
ticket work and worker release.

## Durable-fix proposal (no implementation in this task)

Adopt a path-bound post-ticket commit contract for source and control-plane
workers, while retaining the current generated-artifact auto-commit allowlist.

1. Before editing, the worker records a ticket manifest containing task ID,
   build generation or review authority, base commit, and the exact expected
   path list.
2. Before success/release, it runs the ticket's focused checks and commits only
   that manifest's paths. The task/event row records the commit SHA and final
   per-path hashes.
3. Dispatch completion and compile-hold release require that receipt and a clean
   status for the declared paths. Unrelated paths remain untouched and visible.
4. If the worker terminates without a receipt, the pump may self-heal only when
   the task is terminal, its exact manifest and hashes are durable, and no live
   process owns the paths. It may then make the same explicit-path commit or
   emit a patch artifact and a recovery ticket. It must never broad-stage the
   repository, reset user work, infer ownership from age alone, or commit a
   mismatched path.
5. Add fail-closed tests for mixed-ticket dirt, manifest/hash mismatch, a live
   owner, binary/source mismatch, and the successful exact-path case.

This closes the lifecycle gap without weakening the dirty-tree guard, compile
authority, review separation, or pipeline evidence rules.
