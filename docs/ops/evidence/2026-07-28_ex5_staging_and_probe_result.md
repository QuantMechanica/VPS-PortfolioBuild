# Immutable EX5 staging and `f0301ecf` probe status

Date: 2026-07-28  
Router task: `ab474bb0-1509-4f3f-b6e6-d629cfaf92b8`

## Verdict

**STAGING IMPLEMENTED AND VERIFIED; PARENT PROBE GOVERNED-QUEUED, RESULT NOT YET
ESTABLISHED.**

The immutable work-item contract landed on the canonical board-advisor branch in
commits `da0183209` and `41372ec98`. The worker now:

1. accepts `staged_ex5_path` only together with `staged_ex5_sha256`;
2. after claim, verifies the source SHA-256, copies through a task-local temporary
   file, atomically replaces the claimed terminal copy, and verifies it again;
3. tells `run_smoke.ps1` not to overwrite that terminal copy from the canonical
   EA directory;
4. binds the staged SHA into the normal run-evidence expectation;
5. verifies the deployed binary after the run and persists required, pre-run and
   post-run hashes in `summary.json`;
6. fails closed on any missing input, malformed hash, copy mismatch, or post-run
   mismatch.

Items without staging retain the existing canonical deployment path.

## Verification

`python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py -q`:

`55 passed`

Python compilation, PowerShell parsing, and `git diff --check` also passed before
the canonical merge.

## Serial historical builds

Both arms compiled with `compile_one.ps1 -Strict`, with 0 errors and 0 warnings,
from detached checkouts. The working tree and canonical EA binary were not used
as staging:

| arm | commit | staged path | SHA-256 |
|---|---|---|---|
| parent | `c0918247cfe554f9727be9e810524ec4b557cb15` | `D:/QM/strategy_farm/artifacts/ex5_staging/ab474bb0-1509-4f3f-b6e6-d629cfaf92b8/parent_c0918247.ex5` | `f46b73c754bb0d8340fcc9aaa299f44e816ae5362123eb171d3e389197ee6bad` |
| child | `f0301ecf78a989730b3b4338a161cd4210417912` | `D:/QM/strategy_farm/artifacts/ex5_staging/ab474bb0-1509-4f3f-b6e6-d629cfaf92b8/child_f0301ecf.ex5` | `a5e96eece0911870ebdf15083c537a0e96ce898583bb80e86cbd4a1f7d23cb6b` |

After the serial compiles, terminal include targets were restored from the
current canonical `framework/include`.

## Governed probe

The parent arm is queued as work item
`9f79065c-87ed-4f00-97e5-70c32e2d55f1`, using:

- `QM5_9936`, `USDJPY.DWX`, H1 canonical setfile;
- Model 4;
- `2018.07.02` through `2025.12.31`;
- current news-calendar seed;
- the immutable parent EX5 and required SHA above.

It remains `pending` because the governed per-symbol lock is held by active Q06
work item `7baad181-4a30-4dbc-b27d-f5f8d90d0a5d` on T6. That active test was not
interrupted and the lock was not bypassed. T1 was idle and its worker alone was
reloaded to pick up the staging contract. T5 and T_Live were not touched.

The child is intentionally not queued until the parent completes. Therefore the
72 shifted exits have not yet been tested across this boundary, and their
mechanism remains **NOT ESTABLISHED**. Static content at the boundary adds
`QM_PropFirm.mqh`, cap/init calls around
`QM5_9936_ff-range-breakout-gmt3-h1.mq5:452`, and the per-tick prop entry gate
around line 503 in the child checkout, but those lines are a probe hypothesis,
not pipeline evidence.

