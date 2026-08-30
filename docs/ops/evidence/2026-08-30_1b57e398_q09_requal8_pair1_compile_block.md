# Q09 REQUAL-8 serial execution: pair 1 compile-block receipt

Date: 2026-08-30

Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`

OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`

Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
(`0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`)

## Outcome

`BLOCKED_RESIDENT_WORKER_CODE_RELOAD_REQUIRED`.

Serial execution stopped at pair 1. No later pair was started. No Q02 row was
created and no Q09 hold was released. All eight decision-bound holds remain
active. This is deliberately not a Q01 or pipeline verdict.

## Pair 1 durable build state

- Parent: `QM5_13128_pre-fomc-drift-ndx`
- Successor: `QM5_41215_pre-fomc-drift-ndx-requal8`
- Symbol/timeframe: `NDX.DWX` / `H1`
- Governed build task: `471b4139-415d-41dc-833d-5bae378e6ced`
- Current MQ5 SHA-256: `2d71477c309689649df9036e4890b8260f7506c75d4a15636bf507aa1c2cdd7f`
- SPEC SHA-256: `fe18ad478bf6df472912ad59e5b3890b4969eae08d82effecb422e9710252e63`
- Historical first-attempt setfile SHA-256: `6b032b6e118c66c0338fa3520c7f90d39cc6df14d1038b48a113afdac251b970`
- Historical first-attempt setfile build hash:
  `b4cea12b487810a1edb26b7c04c0bb82cc7ca67eaa5fe45383eb9758126d8206`
- Fresh retry setfiles remain unbound (`build_hash: pending`) and both enforce
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- No current EX5 exists; neither failed receipt is represented as a successful
  build.

The source is a faithful identity port plus only the current mechanical Q01
repairs requested by the ticket: the structural `Bars` readiness call is
reviewer-marked, `OnTick` directly samples MAE, and `QM_EntryRequest` is zeroed
before use. `validate_build_guardrails.py` passed the current MQ5 and retry
setfile, including `qm_news_stale_max_hours <= 336`. The focused
`build_gate_hardening.py` scan reported zero failures.

## Immutable compile receipts

| Work item | Terminal | Result | Durable evidence |
|---|---|---|---|
| `906add85-36bd-4af3-85e5-450b887617fa` | T6 | `COMPILE_FAIL`; compiler itself 0 errors/0 warnings; current Q01 checks found raw series, MAE-hook, and request-init defects | `D:/QM/reports/work_items/906add85-36bd-4af3-85e5-450b887617fa/QM5_41215/COMPILE_EA/compile_evidence.json` |
| `b838f751-14e0-452a-b49f-8ba7b904bca4` | T4 | `COMPILE_FAIL`; MQL5 rejected aggregate struct initialization and the PowerShell sibling authority was not yet mapped | `D:/QM/reports/work_items/b838f751-14e0-452a-b49f-8ba7b904bca4/QM5_41215/COMPILE_EA/compile_evidence.json` |
| `9691858b-f73f-4a4f-a221-8e0b8e28b45a` | T1 | `COMPILE_FAIL` / `CANDIDATE_RECHECK_REFUSED`; no compile was attempted | `D:/QM/reports/work_items/9691858b-f73f-4a4f-a221-8e0b8e28b45a/QM5_41215/COMPILE_EA/compile_evidence.json` |

The third receipt is the blocker proof. T1 had loaded the older resident
`compile_work_items` module and refused the exact new authority as
`SOURCE_REPAIR_AUTHORITY_INVALID`. The canonical source now contains the
hash/task-bound authority and `build_check.ps1` contains the matching directory
mapping, but active resident workers must naturally recycle before they can
consume it. Restarting T1-T10 was not attempted because multiple terminals
were running active backtests/OPT_CENSUS work, including the protected
QM5_41162 program.

## Append-only and protected-state verification

- The first setfile was not overwritten after its build hash became bound.
- Each source-changing retry used a fresh nested setfile directory.
- Historical compile rows and evidence files were not edited or deleted.
- Q02 rows for `QM5_41215..QM5_41222`: `0`.
- Active decision-bound Q09 holds: `8/8`; releases: `0`.
- The QM5_41162 OPT_CENSUS row count remains `1085`, matching the manifest.
  Its full row hash has legitimately advanced because its already-running
  program continued completing/claiming cells; this task did not mutate,
  cancel, reprioritize, supersede, reuse, or interrupt any QM5_41162 row.

## Safe continuation

After resident workers naturally recycle and load the committed authority:

1. generate a new append-only COMPILE_EA successor for QM5_41215 using the
   exact `governed_compile_fail:b838f751-14e0-452a-b49f-8ba7b904bca4`
   authority and the untouched `requal8_repair_1b57e398_r2` setfile;
2. require `COMPILE_OK` before recording the build;
3. create and wait for the normal Claude `ea_review` approval;
4. only then enqueue the one manifest-bound Q02 and release pair 1's hold;
5. continue serially to pair 2.

Verdict: `BLOCKED_RESIDENT_WORKER_CODE_RELOAD_REQUIRED`; partial pair-1
artifacts retained, zero seeds, zero hold releases, and zero protected-program
interruption.
