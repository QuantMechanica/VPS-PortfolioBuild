# Q09 REQUAL-8 serial execution — pair 1 review block

- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
- Manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Serial pair: `QM5_13128 -> QM5_41215`, `NDX.DWX`, `H1`
- Recorded at: `2026-08-30T10:34Z`
- Verdict: **BLOCKED AT MANDATORY BUILD REVIEW; NO Q02 SEED; HOLD NOT RELEASED**

## Governed build result

The recovery EA was implemented as the manifest-authorized new identity and compiled only through the `COMPILE_EA` queue.

| Item | Evidence |
|---|---|
| Build task | `471b4139-415d-41dc-833d-5bae378e6ced` |
| Compile work item | `1e748215-fa24-4a0a-9216-f443d5b3ade4` |
| Compile terminal | normal worker claim on `T8` |
| Compile verdict | `COMPILE_OK` |
| Compile errors / warnings | `0 / 0` |
| Build check | `PASS` |
| MQ5 SHA-256 | `2d71477c309689649df9036e4890b8260f7506c75d4a15636bf507aa1c2cdd7f` |
| EX5 SHA-256 | `bbef2fb82ab20d216ce6f44f87d810168ff945069c9642379a5d16970ed547a5` |
| Bound set SHA-256 | `6b032b6e118c66c0338fa3520c7f90d39cc6df14d1038b48a113afdac251b970` |
| Compile evidence | `D:/QM/reports/work_items/1e748215-fa24-4a0a-9216-f443d5b3ade4/QM5_41215/COMPILE_EA/compile_evidence.json` |

The canonical paths are:

- `framework/EAs/QM5_41215_pre-fomc-drift-ndx-requal8/QM5_41215_pre-fomc-drift-ndx-requal8.mq5`
- `framework/EAs/QM5_41215_pre-fomc-drift-ndx-requal8/QM5_41215_pre-fomc-drift-ndx-requal8.ex5`
- `framework/EAs/QM5_41215_pre-fomc-drift-ndx-requal8/sets/requal8_repair_1b57e398_r2/QM5_41215_pre-fomc-drift-ndx-requal8_NDX.DWX_H1_backtest.set`

The set binds `RISK_FIXED=1000` and `RISK_PERCENT=0`; the EA's fail-closed `qm_news_stale_max_hours` default remains `336`.

## Review gate

The scheduled pump created mechanical Codex review `06caffcf-84d4-47f4-a487-d69534db1a73`. It returned `FAIL`, not approval:

- `smoke_sanity=UNKNOWN`
- `build_result=FAIL`
- finding: the build result used `deferred_p2_smoke` without durable tester-fleet saturation evidence
- advisory: the EA's `OnTick` news gate precedes Friday-close and position-management/exit handling

The build task therefore became `blocked` with `blocked_reason=codex_review_fail`. The earlier rendered final-review task `597bdc4b-4fb8-4cd5-b5f6-307d6b963d4e` remains `pending`; no Claude process claimed it and no final-review verdict exists. It is not treated as approval.

A single governed smoke dispatch was then attempted exactly as the build contract prescribes:

```text
run_smoke.ps1 -EALabel QM5_41215_pre-fomc-drift-ndx-requal8 -Symbol NDX.DWX -Year 2024 -Terminal any -Period H1 -SetFile ...requal8_repair_1b57e398_r2...set -MinTrades 1 -SmokeMode
```

The dispatcher refused before an EA smoke launch:

```text
Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.
```

The follow-up `farmctl.py mt5-slots` census at `2026-08-30T10:31:39+00:00` showed workers on all `T1`-`T10` and active tester processes. No active test was interrupted. A subsequent census showed `T9` actively owned by work item `40ff1e14-1d07-44c0-afe9-7ebf8dd08e37` (`QM5_10403`); its reservation/process was left untouched.

The normal rework preparer also left the build blocked because the canonical checkout's global dirty-build guard contains unrelated operator changes. Task-local paths and the manifest-authority control-plane repair are clean and committed, but unrelated dirty paths were not committed, reset, or modified.

## Control-plane repair and verification

The reservation-only recovery cards intentionally obtain authority from the exact hash-bound manifest. `record-build` originally reapplied the ordinary R-gate and rejected that already-approved authority. Commit `3c4f556fb` makes the build claim/record guard reuse the exact manifest authority while leaving ordinary cards unchanged.

Focused verification:

- `pytest tools/strategy_farm/tests/test_build_q02_exclusion_preflight.py`: `4 passed`
- real build claim guard: `eligible_q09_requal8_manifest_authority`
- `PRAGMA quick_check`: `ok`
- task-local `git status --short`: clean

The compile artifact and risk-bound set are committed in `1871e28d3`. The build-authority repair is committed in `3c4f556fb`.

## Append-only and serial invariants

At the final database census:

- Q02 rows for `QM5_41215` through `QM5_41222`: `0`
- all eight manifest holds: `status=pending`, `claimed_by=NULL`, `verdict=NULL`
- pair-1 hold `aa80274f-fb46-4432-b47e-6fb2bf28c9a2`: still pending; not released
- protected `QM5_41162` `OPT_CENSUS`: `1085` rows (`183 done`, `902 pending`), matching the manifest row count
- pairs `QM5_41216` through `QM5_41222`: not started, preserving serial discipline

The scheduled pump continued to refresh pending-hold metadata while attempting its own Q09 autoseal checks; no hold status changed and this cycle did not directly edit any historical row. No Q02 seed or hold release was attempted because the required review approval does not exist.

## Required continuation

Do not start pair 2. Resume pair 1 only after the global dirty-build guard permits the bounded review retry. Bind the measured `no_capacity` smoke waiver to the new build generation, obtain mechanical review PASS and independent final review approval, then enqueue exactly one manifest-bound Q02 row and verify it before releasing `aa80274f-fb46-4432-b47e-6fb2bf28c9a2` with the decision-bound note.

## Scheduled continuation check — 2026-08-30T11:06Z

The next single-pass Codex cycle re-ran the one governed pair-1 smoke command
against the committed `requal8_repair_1b57e398_r2` setfile. The dispatcher again
refused before an EA launch:

```text
Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.
```

The immediately preceding `farmctl.py mt5-slots` census showed all ten normal
workers alive and five active tester-owned terminals (`T6` through `T10`). No
terminal, worker, reservation, or active test was stopped or altered. The
canonical checkout still contains unrelated operator changes, so the global
dirty-build guard cannot safely be cleared by this task. Task-local build and
control-plane paths remain clean.

The mandatory mechanical review therefore remains `FAIL/UNKNOWN` rather than
PASS. Pair 2 was not started; no Q02 row was appended; no Q09 hold was released;
and the protected `QM5_41162` program was not touched. This is a transient
capacity/coordination block, not a pipeline verdict.
