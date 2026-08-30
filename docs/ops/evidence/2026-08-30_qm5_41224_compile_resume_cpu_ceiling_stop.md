# QM5_41224 governed compile resume — CPU ceiling stop

Date: 2026-08-30 UTC

Branch: `agents/board-advisor`

Farm build task: `ff4d22ef-de6d-49f1-83ac-80d62b4b810b`

Outcome: **HIGHEST-DIVERSITY BACKLOG ITEM RECLAIMED AND SAFELY RELEASED;
COMPILE AND Q02 NOT ENQUEUED BECAUSE THE 97% CPU STOP WALL FIRED**

## Deterministic selection

The canonical `strategy_priority` scorer ranked
`QM5_41224_wti-samecal-regimeshift` first among pending build tasks with
`score=1010.39` and `priority_track=true`. The shared farm claim guard returned
`eligible`, the task had no live dispatch evidence, and the EA had no work-item
rows. This is the same direct-WTI structural D1 candidate identified by the
prior handoff, not a second card or a duplicate build.

The approved card retains `g0_status: APPROVED`,
`execution_contract_status: APPROVED`, informational R1 tier C, and strict
R2-R4 PASS. Its carrier is `XTIUSD.DWX`, outside the certified
index/metal/XNG concentration. The mechanic is the exact recent-five versus
older-five same-calendar-month sign-reversal rule described in the card; no
strategy source or parameter was changed in this continuation.

## Claim and collision control

Two admission windows were initially clear:

- `2026-08-30T10:02:00.9901018Z`: samples
  `81.36, 75.54, 70.22, 68.66, 72.76`; average `73.71%`, maximum `81.36%`.
- `2026-08-30T10:08:27.9841972Z`: samples
  `87.52, 89.45, 87.13, 84.47, 87.41`; average `87.20%`, maximum `89.45%`.

Before mutation, an online SQLite backup was completed and passed
`integrity_check=ok`:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41224_compile_claim_20260830T100925Z_ddd5b0f7.sqlite`

SHA-256:
`a0bcfcef41d73237e5fdbc79539aa4f3956a783cf861328d4a602be2971b0997`.

The exact task was CAS-claimed as
`build:QM5_41224:ff4d22ef-de6d-49f1-83ac-80d62b4b810b` by
`codex:agents/board-advisor`. No competing claim or work item appeared during
the transaction.

## Binding CPU stop

The next mandatory five-sample whole-host window ended at
`2026-08-30T10:12:08.3402809Z`:

`82.06%, 84.12%, 93.27%, 97.29%, 94.15%`

Average was `90.18%`; maximum was `97.29%`. The paced-fleet contract stops
when either value reaches the `97%` ceiling, so the maximum triggered an
immediate stop before `farmctl enqueue-compile`.

The claim was then CAS-released at
`2026-08-30T10:12:52.936399+00:00`. Readback shows the build task is again
`pending`, with no `claimed_by`, `claim_key`, active block marker, compile
work item, or Q02 row. Its historical resume note is now
`BACKTEST_CPU_CEILING:max=97.29>=97.0;compile_and_q02_not_enqueued`.

## Artifact state and resume point

The clean governed source remains commit
`86b5852ee4eea4a84167cd65af2a6242fb8e0ecf`:

| Artifact | SHA-256 / state |
|---|---|
| Approved card | `a3bdbf819f5acd9d22550b2703ad87655fc202280d4498087bd91356b138c9c9` |
| MQ5 | `fede16790ec29627b6c38415f6db95ec0146c9a312789ff5645240014769b2d5` |
| SPEC | `575f674b73486a3e674f8cb0a07371d7412d031fe20fa1a72399c6dcfd2631a4` |
| Fixed-risk setfile | `d63212d34f8fd376095b1a036932fdb3147711f45101f7ef4a7f1e9c0ed28fc3` |
| EX5 | absent |
| Governed compile | `NOT_ENQUEUED` |
| Q02 work items | zero |

A future paced worker must obtain a fresh five-sample window whose average
and maximum are both below `97%`, atomically reclaim this same task, and repeat
the duplicate/readback checks. The supported continuation remains:

`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41224_wti-samecal-regimeshift --build-task-id ff4d22ef-de6d-49f1-83ac-80d62b4b810b`

It must wait for a source-bound `COMPILE_OK` before recording the build and
letting `record-build` create the single fixed-risk Q02 row.

No compiler, tester, dispatcher, terminal reservation, terminal start/stop,
AutoTrading toggle, portfolio gate, `T_Live` path, deploy manifest,
certification state, or strategy artifact was touched.

Machine-readable receipt:
`artifacts/qm5_41224_compile_resume_cpu_stop_20260830T101208Z_board_advisor.json`.
