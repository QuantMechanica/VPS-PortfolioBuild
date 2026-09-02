# Q09 REQUAL-8 pair 7 reserved-smoke isolation refusal at 05:45Z

- Recorded: `2026-09-02T05:49Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR7_SMOKE_REFUSED_CUSTOM_HISTORY_WORK_ITEM_BINDING`

## Outcome

The router recycled this task at `2026-09-02T05:19:54+00:00` with an exact
continuation: reserve the terminal whose current cell would finish first, wait
for that cell, run the reviewed pair-7 smoke on the reserved slot, and release
the reservation afterward. T10's prior governed cell had completed, and the
pre-reservation census showed no T10 tester process, so its remaining runtime
was zero.

The canonical control plane created this reservation:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py reserve-terminal T10 --by run_smoke_pair7 --minutes 45 --reason "REQUAL-8 pair-7 deferred smoke"
created_at_utc=2026-09-02T05:44:50.141383+00:00
until_utc=2026-09-02T06:29:50.141383+00:00
```

A second slot census confirmed T10 had no tester process, the expected resident
worker was present, and the exact `run_smoke_pair7` reservation was active. The
reviewed hash-pinned smoke then resolved T10 but failed closed before tester
launch:

```text
run_smoke.stage=resolved_terminal terminal=T10
Exception: C:\QM\repo\framework\scripts\run_smoke.ps1:704
Custom-history gate/reservation refused terminal 'T10': {"reason": "active Custom-history isolation requires a worker-bound work item whose archives were privatized before run_smoke", "status": "REFUSED"}
```

The command exited `1`. This is not a strategy or pipeline verdict. It is an
exact infrastructure admission refusal: a direct reserved-terminal smoke does
not satisfy the active isolation gate's worker-bound-work-item and privatized-
archive requirements.

The reservation was then released through the canonical control plane:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py release-terminal T10
released=true
```

The post-release census at `2026-09-02T05:47:31+00:00` showed zero T10 tester
processes and zero T10 reservations. No terminal was manually started or
stopped, and no active farm test was interrupted.

## Exact governed smoke command

```text
pwsh -NoProfile -File C:/QM/repo/framework/scripts/run_smoke.ps1 -EALabel QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8 -Symbol EURUSD.DWX -Year 2024 -Terminal T10 -Period D1 -SetFile C:/QM/repo/framework/EAs/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8/sets/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8_EURUSD.DWX_D1_backtest.set -MinTrades 1 -SmokeMode -ExpectedExpertSha256 3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1
```

## Sealed artifact verification

| Artifact | SHA-256 |
|---|---|
| MQ5 | `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f` |
| EX5 | `3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1` |
| EURUSD.DWX D1 backtest set | `ee72ead97a1a8cf2bb1998ad064c52a4a9128c052e365117062b4771666e3bf6` |

Focused post-refusal verification:

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`;
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  maximum news staleness `336` hours;
- the set remains `RISK_FIXED=1000` and `RISK_PERCENT=0`;
- scoped EA-directory `git diff --check`: `PASS`.

## Serial-state verification

Read-only canonical database checks after release found:

- pair-7 `QM5_41221 / Q02` work-item count: zero;
- pair-7 hold `30584122-b7b3-41eb-8e1a-b03517554d4d`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`;
- pair-8 `QM5_41222`: zero farm work items, including zero Q02 rows;
- pair-8 hold `08fe4173-07d9-47e1-97e9-a76b1159ad94`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`;
- protected `QM5_41162 / OPT_CENSUS`: exactly 1,161 terminal rows, comprising
  237 `done/MEASURED` and 924 `done/SKIPPED_EXCLUDED`.

Because no genuine smoke result exists, this continuation did not write a
build-generation successor, enqueue Q02, release either hold, or begin pair 8.
It did not mutate historical work items, reviews, build results, registry rows,
terminal policy, `T_Live`, AutoTrading, main, or `C:/QM/worktrees/cto_main`.
No pipeline phase ran and no pipeline verdict is asserted.

## Required continuation

The reservation route requested by the review is now proven incompatible with
the active custom-history isolation admission contract. A later reviewed
continuation must name and authorize the governed worker-bound smoke-work-item
path that performs archive privatization; a direct reservation retry would
repeat the same fail-closed gate and must not be used as a bypass.

Only a genuine smoke result may support an append-only generation successor,
fresh generation-matched reviews, the manifest's single Q02 enqueue, and
pair-7 hold release. Pair 8 remains strictly downstream.

## Verdict

`PAIR7_SMOKE_REFUSED_CUSTOM_HISTORY_WORK_ITEM_BINDING`: the explicitly
authorized T10 reservation succeeded, but the active isolation gate refused
the smoke before launch because it was not a worker-bound work item with
privatized archives; T10 was released, and zero Q02/hold/protected-program
mutation occurred.
