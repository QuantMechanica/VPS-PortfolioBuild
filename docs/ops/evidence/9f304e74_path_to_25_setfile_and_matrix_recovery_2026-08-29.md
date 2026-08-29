# PATH-TO-25 setfile and Q12 matrix recovery

- Router task: `9f304e74-5be4-4a6b-8921-d1b65875e241`
- Date: 2026-08-29
- Branch: `agents/board-advisor`
- Repair commit: `5df5a18da`
- Disposition: **SETFILE DEFECT REPAIRED; APPEND-ONLY COMPILE HELD BY SQLITE
  CONTENTION; FIVE NEW Q12 ROWS PRECISELY DEFERRED FOR MISSING MEASUREMENT
  SIBLINGS**

No pipeline, economic, portfolio, or live verdict is asserted.

## QM5_41163 compile failure diagnosis

The immutable failed compile row
`7ac8261a-97e0-41f6-a1a4-bd789a1b3bcf` recorded
`SETFILE_GENERATION_FAILED:USDCAD.DWX`. Its evidence artifact is
`D:/QM/reports/work_items/7ac8261a-97e0-41f6-a1a4-bd789a1b3bcf/QM5_41163/COMPILE_EA/compile_evidence.json`
(SHA-256
`b9ab3cd4a58cf6f9103f42364a187748101caa4fef06e4fc47a3c88086414d1a`).
The exact generator result was:

- exit code `1`;
- the fixed-risk setfile was created and existed;
- the scheduled Windows PowerShell process could not resolve `Get-FileHash`;
- therefore the generator failed while calculating its output receipt SHA-256,
  before `build_check.ps1` or the governed compile could run.

This was not a card, parameter, risk, news, MQ5, or compiler failure. The
generated setfile remained `RISK_FIXED=1000`, `RISK_PERCENT=0`, with SHA-256
`69f44ce366b0b79f603ab561a498e082b95d9c96d84be076a5d1eeb9ebd3c2dd`.

## Bounded repair

`gen_setfile.ps1` now calculates its output receipt with
`System.Security.Cryptography.SHA256` directly. It no longer depends on
PowerShell module autoload after writing the file, and it preserves the exact
lowercase 64-hex digest contract. Both normal generation and live provenance
template repair use the same helper.

The compile writer gate gained one exact authority:

`router_ops_issue:9f304e74-5be4-4a6b-8921-d1b65875e241`

It is bound only to
`QM5_41163_williams-18ma-outside-bar-entry-d1-opt` and grants only an
append-only, source-hash-bound compile successor. It grants no Q02, Q12, gate,
pipeline, other-EA, overwrite, or live authority.

Verification:

- PowerShell parser: PASS.
- New module-independent hash regression: PASS.
- Exact generator run with `PSModulePath` empty: PASS, same setfile SHA-256
  `69f44c...c2dd`.
- `test_compile_work_items.py`: **31 passed**.
- Scoped build guardrails: PASS, two files, zero findings,
  `max_news_stale_hours=336`.
- Setfile risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Governed compile continuation

The repair authority admitted append-only successor
`2361ac93-a55b-4e32-a020-db5417d22dba`. Its queued/current MQ5 SHA-256 is an
exact match:
`337aa718eab729ec7c4e7c55e66145898f779064a8618bcfb02be8289916ef36`.
The exact release dry run selected one row and no other EA.

Two bounded apply attempts then waited through their busy retry windows and
failed atomically at `BEGIN IMMEDIATE` with
`sqlite3.OperationalError: database is locked` while the scheduled farm pump
and tick held the writer transaction. The successor therefore remains
`pending`, unclaimed, behind `COMPILE_EA_WORKER_ROLLOUT_PENDING`, with no
compile evidence or `COMPILE_OK` receipt. No terminal, worker, active test, or
historical row was stopped or edited to force it through.

Until that exact successor is released and produces a source-matched
`COMPILE_OK` receipt, the governed Q12 service correctly reports
`COMPILE_OK binary hash drift for QM5_41163` for the parent
`QM5_11422/USDCAD.DWX` declaration
`f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5`. Its cell count remains zero.

## Five fresh Q12 declarations

The normal pump has applied the governed DL-089 service to all five fresh rows:
each now has an active `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` hold with
`release_on_restart=1`. Exact service dry runs reproduce a more fundamental
precondition failure before materialization: no approved `_opt` measurement
sibling exists for any pair.

| Subject pair | Q12 work item | OPT_CENSUS total / pending | Exact defer reason |
|---|---|---:|---|
| `QM5_13054 / XTIUSD.DWX` | `a5b90e08-cf49-51ac-be59-1d4926da2363` | 0 / 0 | expected one approved `_opt` sibling, found 0 |
| `QM5_1537 / XAGUSD.DWX` | `c41e2606-3af1-5766-9bb7-18de8a763a18` | 0 / 0 | expected one approved `_opt` sibling, found 0 |
| `QM5_21507 / XAUUSD.DWX` | `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` | 0 / 0 | expected one approved `_opt` sibling, found 0 |
| `QM5_11881 / GBPUSD.DWX` | `d824e8cb-8397-5aa3-b6fa-fec9b0c375eb` | 0 / 0 | expected one approved `_opt` sibling, found 0 |
| `QM5_20266 / XTIUSD.DWX` | `d8739ae2-1ce4-553a-9b59-1335e582614c` | 0 / 0 | expected one approved `_opt` sibling, found 0 |

The governed-evaluator wiring is therefore functioning: the service recognizes
the declarations, installs the rollout safety hold, and fails closed at the
missing executable measurement package. Creating five new Strategy Cards,
allocating identities/magics, building/reviewing siblings, or weakening that
precondition is outside this task's bounded repair authority. No cells were
manufactured.

## Deterministic continuation

1. After the scheduled writer transaction clears, release only compile row
   `2361ac93-a55b-4e32-a020-db5417d22dba` through
   `release_compile_wave.py`.
2. Let a resident worker produce the governed compile receipt. Only a
   source-matched `COMPILE_OK`, zero-error, zero-warning receipt may unblock the
   `QM5_11422/USDCAD.DWX` prerequisite and cell materialization.
3. Route separate upstream build work for the five missing approved `_opt`
   siblings. The present Q12 declarations and zero-cell state must remain
   immutable until those prerequisites exist.

The task acceptance target of pending cells greater than zero is not claimed:
the evidence above identifies the exact, pair-specific blockers without
inventing work, bypassing the deterministic router, or weakening any gate.
