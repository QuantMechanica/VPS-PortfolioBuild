# QM5_41224 WTI same-calendar regime-shift build — CPU ceiling stop

Date: 2026-08-30 UTC

Branch: `agents/board-advisor`

Farm build task: `ff4d22ef-de6d-49f1-83ac-80d62b4b810b`

Outcome: **SOURCE AND GOVERNANCE PREFLIGHT PASS; COMPILE AND Q02 NOT
ENQUEUED BECAUSE THE 97% CPU STOP WALL FIRED**

## Diversity selection

The canonical strategy-priority scorer ranked
`QM5_41224_wti-samecal-regimeshift` first among the eligible build backlog
(`forced_score=1010.39`). It adds direct WTI exposure on `XTIUSD.DWX`, beyond
the certified book's index/metal/XNG concentration, and is a structural D1
calendar edge with an expected five to eight completed positions per full
post-warm-up year.

The durable approved card has `g0_status: APPROVED`, execution-contract status
`APPROVED`, informational R1 tier C, and strict R2-R4 PASS. The cited source
lineage is Keloharju, Linnainmaa, and Nyberg (2016), *Return Seasonalities*,
plus Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*. The exact
chronological recent-five versus older-five opposite-sign conjunction remains
an explicitly labeled QM hypothesis rather than a claimed source result.

The source tree was already clean at governed build commit
`86b5852ee4eea4a84167cd65af2a6242fb8e0ecf` (`feat(energy): build QM5 41224
WTI regime-shift edge`). This unit did not duplicate or rewrite that source.

## Collision control and reclaimable handoff

An atomic pre-claim check found exactly one open build task, no other live
claim, and no work item for this EA. The task was claimed under
`build:QM5_41224:ff4d22ef-de6d-49f1-83ac-80d62b4b810b` by
`codex:agents/board-advisor` at `2026-08-30T09:10:44.234932+00:00`.

The protected pre-claim online database backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41224_build_claim_20260830T091044Z_274b4880.sqlite`

Its SHA-256 is
`e9d7cfc83b5a93de7898348623896955c57a5e2128e562eba388976ac966069`, and
SQLite `integrity_check` returned `ok` before the claim mutation.

After the CPU stop, the exact claim was CAS-released at
`2026-08-30T09:15:14.394900+00:00`. The build task is again `pending`, carries
the historical non-blocking reason
`BACKTEST_CPU_CEILING:max=97.0>=97.0;compile_and_q02_not_enqueued`, and has no
`claimed_by`, `claim_key`, active block marker, or in-flight work item. The
standard farm claim guard reports `eligible`; the next paced worker can safely
reclaim it after a fresh capacity check.

## Deterministic build preflight

The existing implementation and its single fixed-risk baseline passed all
non-terminal checks run in this unit:

- exact same-calendar reference fixture: 11 tests PASS;
- `skill_build_ea_guard.py --ea-id 41224`: registry, magic registry, and EA
  directory PASS;
- `validate_spec_doc.py`: 1/1 PASS;
- `validate_build_guardrails.py`: PASS with zero findings;
- `build_gate_hardening.py`: PASS with zero failures or warnings;
- farm build-task claim guard: eligible (R1 informational tier C; R2-R4 PASS).

Identity and risk bindings are:

| Artifact | SHA-256 / value |
|---|---|
| Approved card | `a3bdbf819f5acd9d22550b2703ad87655fc202280d4498087bd91356b138c9c9` |
| MQ5 | `fede16790ec29627b6c38415f6db95ec0146c9a312789ff5645240014769b2d5` |
| SPEC | `575f674b73486a3e674f8cb0a07371d7412d031fe20fa1a72399c6dcfd2631a4` |
| Backtest setfile | `d63212d34f8fd376095b1a036932fdb3147711f45101f7ef4a7f1e9c0ed28fc3` |
| EA registry | active ID `41224`, slug `wti-samecal-regimeshift` |
| Magic registry | active slot 0, `XTIUSD.DWX`, magic `412240000` |
| Backtest risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

No EX5 exists, the setfile `build_hash` remains `pending`, and read-only
`farmctl compile-status` reports `NOT_ENQUEUED`. There is no Q02 row.

## Binding CPU stop

Five fresh whole-host samples at `2026-08-30T09:13:57.1300575Z` through
`2026-08-30T09:14:04.2325681Z` were:

`61%, 62%, 69%, 96%, 97%`

The average was 77% and the maximum was exactly 97%. The paced-fleet rule stops
when either measure reaches the 97% ceiling, so the maximum triggered the
immediate stop before governed compile enqueue.

The supported slot scan showed four active research terminals: T1, T2, T5,
and T10. The observed `T_Live` and unrelated FTMO processes were excluded from
that count and were not controlled.

## Resume point and safety boundary

A future paced worker must first obtain a fresh five-sample CPU window whose
average and maximum are both below 97%, atomically reclaim the same build task,
and repeat duplicate/work-item checks. It can then use the supported command:

`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41224_wti-samecal-regimeshift --build-task-id ff4d22ef-de6d-49f1-83ac-80d62b4b810b`

The worker must require source-bound governed compile PASS before any Q02
handoff and must retain the fixed-risk setfile. No ad-hoc compiler, tester, or
terminal was launched; no terminal was stopped or reaped; AutoTrading was not
toggled; and neither `T_Live`, the deploy manifest, the portfolio gate, nor a
certification state was touched.

Machine-readable receipt:
`artifacts/qm5_41224_wti_samecal_build_cpu_stop_20260830T091404Z_board_advisor.json`.
