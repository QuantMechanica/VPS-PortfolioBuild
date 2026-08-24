# rb-hygiene-burn evidence — 2026-08-24

Ticket: `rb-hygiene-burn`

Worktree: `C:\QM\worktrees\rb-hygiene-burn`

Runtime: `D:\QM\strategy_farm`

## Status and safety boundary

The OEM-codepage fixture failure is fixed, all post-`rb-411xx-build-gate`
`QM5_411xx` buffer violations are mechanically guarded, `QM5_41136` has a new
append-only governed `COMPILE_EA` row, and the 20+1 compile cohort was audited
read-only. No gate threshold or criterion changed. No backtest was enqueued or
deleted, no verdict row was overwritten, the factory was not toggled, and
`C:/QM/mt5/T_Live` was not touched.

## A — OEM-codepage-safe supervisor fixture

Root cause was the batch fixture's redirected output: `cmd.exe` writes the
captured resume arguments using the inherited console output code page. The
test always decoded that file as UTF-8, so CP437 emitted byte `0x84` for `ä`
and raised before the existing assertions ran.

The test now obtains `GetConsoleOutputCP()` and decodes the fixture output with
that exact codec (`tools/strategy_farm/tests/test_codex_session_supervisor.py:16-19`,
`:57`). The assertions are unchanged: exit code 130, `resume --last` prefix,
and the continuation marker `automatisch` are still required.

Verification:

- `cmd /d /c "chcp 437>nul && python -m pytest -q tools/strategy_farm/tests/test_codex_session_supervisor.py::test_supervisor_resumes_after_unexpected_child_exit"`
  — `1 passed in 3.95s`.
- `cmd /d /c "chcp 65001>nul && python -m pytest -q tools/strategy_farm/tests/test_codex_session_supervisor.py::test_supervisor_resumes_after_unexpected_child_exit"`
  — `1 passed in 4.37s`.

## B — post-wave EA buffer repair and governed re-enqueue

The build-gate merge point is `1ee81b213` at 2026-08-23 21:20 +02:00.
Creation-history plus the real D10 checker identified eight successively
surfaced unbounded accesses across five later EAs; `QM5_41137` was clean.
Repairs are standalone fail-fast `ArraySize` proofs only:

- `QM5_41134`: retained-return indices guarded
  (`framework/EAs/QM5_41134_wti-mdaily-iqrmean-mom/QM5_41134_wti-mdaily-iqrmean-mom.mq5:596-599`).
- `QM5_41135`: sorted-return loop index guarded
  (`framework/EAs/QM5_41135_xauxag-mdaily-iqrmean-rv/QM5_41135_xauxag-mdaily-iqrmean-rv.mq5:824-825`).
- `QM5_41136`: retained-return indices guarded
  (`framework/EAs/QM5_41136_xng-mdaily-iqrmean-mom/QM5_41136_xng-mdaily-iqrmean-mom.mq5:596-599`).
- `QM5_41138`: both daily-return loop indices, sorted pair index, and median
  indices guarded
  (`framework/EAs/QM5_41138_xauxag-mdaily-hl-rv/QM5_41138_xauxag-mdaily-hl-rv.mq5:826-832`,
  `:858-859`, `:870-873`).
- `QM5_41139`: left/right daily-return indices and pair-write index split into
  standalone guards
  (`framework/EAs/QM5_41139_wti-mdaily-hl-mom/QM5_41139_wti-mdaily-hl-mom.mq5:574-584`).

The `QM5_41136` durable failure also contained 14 compiler errors rooted at a
missing semicolon on its `QM_LogEvent` call (`C:\QM\repo\framework\build\compile\20260824_013322\QM5_41136_xng-mdaily-iqrmean-mom.compile.log`).
The identical template defect was corrected in `QM5_41134` and `QM5_41136`
(`framework/EAs/QM5_41134_wti-mdaily-iqrmean-mom/QM5_41134_wti-mdaily-iqrmean-mom.mq5:717`,
`framework/EAs/QM5_41136_xng-mdaily-iqrmean-mom/QM5_41136_xng-mdaily-iqrmean-mom.mq5:717`)
so the requested retry is not knowingly sent back with the same syntax
cascade. Strategy mechanics and thresholds are unchanged.

The existing census already globs every `QM5_411*/*.mq5`
(`tools/strategy_farm/tests/test_build_gate_hardening.py:390-404`); it now
passes. A broader checker-function scan covered 134 `QM5_41*` sources. Its only
remaining findings were `QM5_41010` and `QM5_41055`, created on 2026-08-21 and
2026-08-18 respectively, before the wave; no post-wave source remains failing.
Those two legacy sources were not changed by this ticket.

The governed append-only authority is exact-token and exact-label bound
(`tools/strategy_farm/compile_work_items.py:71-74`, `:213-214`) and its negative
tests are at `tools/strategy_farm/tests/test_compile_work_items.py:213-228`.
Command:

```powershell
$env:QM_ALLOW_NONCANONICAL='1'
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-compile QM5_41136_xng-mdaily-iqrmean-mom --source-repair-authority ticket:rb-hygiene-burn
```

Result: `ok=true`, `enqueued_count=1`, `refused_count=0`, new work item
`979e7903-d28b-46fc-89cb-5b8a721f2e27`. A post-write read-only URI query shows
it pending, verdict-free, actively held under the governed worker-rollout hold,
and payload-bound to repaired MQ5 SHA-256
`9f5ed2fc702632ad01fd1b9bac8a078175fd66ec3f15e0b9b40c10215e4aa5b3`.
Its predecessor list contains failed row
`77d52009-3434-4c70-a93b-29471832c3cd`; that row remains `failed / COMPILE_FAIL`
with its original evidence path and hash.

## C — 20+1 compile proof audit

The state DB was opened only through
`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`. The reproducible
cohort query selected the 20 exact IDs listed in
`2026-08-23_rb-411xx-build-gate.md` plus `QM5_41133` row
`1fb58c79-e46f-4d72-9af1-26eb4656e0d5` and counted status/verdict/active holds.
Result: `rows=21`, `COMPILE_OK=1`, `pending=20`, `active=0`,
`active_holds=20`.

`QM5_41109` row `cc09145c-a6d6-4cb0-88a4-e10ef58cc58d` is the successful
governed compile. Durable artifacts:

- `D:\QM\reports\work_items\cc09145c-a6d6-4cb0-88a4-e10ef58cc58d\QM5_41109\COMPILE_EA\compile_evidence.json`;
- `D:\QM\reports\framework\21\build_check_20260823_221618.json`;
- `C:\QM\repo\framework\build\compile\20260823_221622\QM5_41109_xauxag-mmean-median-rv.compile.log`;
- `D:\QM\reports\compile\20260823_221622\summary.csv`.

The evidence records compile PASS, build-check PASS, zero errors/warnings, and
EX5 SHA-256 `269058afe6b11abab89286ee9a8d3efe535c5298b2eee0001e0fe27da867d16c`.
The prior blanket deferral is closed for this row in
`docs/ops/evidence/2026-08-23_rb-411xx-build-gate.md`.

Two integrity risks remain explicit:

1. The canonical EX5 path currently hashes to the earlier binary
   `e6acd7a248f836fd2b916dcd211c8393975d22dc3da24645df52bb0bed420a00`,
   so the successful row's exact EX5 bytes are not retained at that mutable
   path even though its evidence/report/log/summary are durable.
2. `QM5_41133`'s pending row is bound to pre-repair MQ5 hash
   `7c8aeb3382bf3d8b84325661dfb699458bd115c84455e04c9a0c5a34f08ded04`;
   current repaired source hash is
   `9d7f41c8db3991e626c9577512be267699574ce6df08fd95f327c3013e761ff5`.
   It was left pending as directed and is not current-hash proof.

## Test evidence

- Full touched strategy-farm suite:
  `python -m pytest -q tools/strategy_farm/tests/test_codex_session_supervisor.py tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_compile_work_items.py`
  — `49 passed in 438.06s`.
- The five EA-local reference suites were run in separate pytest processes
  because their duplicated module basenames collide under combined collection:
  `QM5_41134` 16 passed, `QM5_41135` 9 passed, `QM5_41136` 16 passed,
  `QM5_41138` 9 passed, `QM5_41139` 13 passed.
- Focused `QM5_411*` D10 census — `1 passed in 1.60s`.
- Broader D10 checker scan — 134 `QM5_41*` sources; zero post-wave failures,
  two disclosed pre-wave findings.

## Rollback

Revert this ticket commit with `git revert <commit>`; do not reset the branch.
That restores the prior Python tests/tool contract and EA source bytes. The
runtime work item `979e7903-d28b-46fc-89cb-5b8a721f2e27` is append-only
evidence: do not delete it and do not overwrite its verdict. If source code is
reverted before it runs, its source-hash recheck must fail closed; disposition
requires a separately authorized governed action. Pending cohort rows and holds
remain untouched.
