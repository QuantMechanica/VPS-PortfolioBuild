# Multi-symbol step 2 (satellite 10145:XAUUSD) — GATE STOP

Date: 2026-07-27
EA under test: `QM5_20181_ftmo-joint-multisym-timer`
Satellite requested: `10145:XAUUSD` (own symbol input, own magic, own state)
Verdict: **STOP AT GATE — step 1 is not resolved. No satellite was enabled, no
terminal was reserved, no measurement was run.**

## Gate

The step-2 protocol opens with a hard gate:

> if step 1's diff (a) — joint (runner-only) vs same-vintage standalone — did not
> reach `match_rate == 1.0`, STOP and report that step 1 must be resolved first. Do
> not stack a satellite on an unproven scaffold.

The instruction is to read `docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md`
first and evaluate that gate before touching a terminal. That file does not exist,
and the underlying step-1 measurement was never completed. The gate is therefore not
merely unmet — its input diff was never produced. Step 2 stops here.

## Why the gate fails — evidence

### 1. The named step-1 EXECUTED artifact does not exist

`ls docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md` →
`ABSENT: 2026-07-27_multisym_step1_EXECUTED.md`.

The step-1 worklist confirms it was never written: task **#10 "Diff with
compare_joint_replay.py; write step1 evidence doc"** is still `pending`, and task
**#9 "Reserve terminal, run both EAs sequentially, harvest Q08 streams"** is still
`in_progress`. Step 1 has not produced its admission diff.

### 2. No completed step-1 stream for the repaired QM5_20181 exists on disk

The step-1 report tree for the repaired EA, `D:/QM/reports/joint_20181/`, was
scaffolded but is empty of results:

- `joint_20181/s0_runner/` — empty (no runner-only joint replay stream).
- `joint_20181/harvest/` — empty (no harvested trade stream).
- `joint_20181/control_9936/QM5_9936/20260727_171318/raw/run_01/` — contains only
  `tester.ini` (473 bytes). No `report.htm`, no `summary.json`, no
  `9936_USDJPY_DWX.jsonl`. The same-vintage standalone control was launched
  (INI generated 2026-07-27 17:13) but produced no completed backtest.

There is no runner-only joint stream and no same-vintage standalone stream, so diff
(a) has no operands. `match_rate` for joint-vs-same-vintage-standalone is
**NOT ESTABLISHED**.

### 3. The same-vintage standalone control has failed to complete twice, on record

- `docs/ops/evidence/2026-07-27_evidence_vintage_check.md:54-58`: the current-tree
  9936 control on reserved T2 reached only 19% progress, then
  `"some error after pass finished"`, produced no report and no durable trade stream,
  and the T2 worker immediately reclaimed the lane for work item
  `ef0303b5-cebd-45d3-948b-5b53201a3798`. Verdict there:
  **NOT ESTABLISHED — current-tree functional equivalence was not measured**.
- `docs/ops/evidence/2026-07-27_timer_fidelity_curve.md:39-51`: same failure — control
  reached 19% at 20:45:22, `"some error after pass finished"`, no report, T2 reclaimed
  at 20:48:10. Verdict: **NOT ESTABLISHED — no admissible curve was produced**.

### 4. The only completed joint-vs-reference diff FAILED, and against the wrong control

The one completed sleeve-0 replay is the pre-repair EA **QM5_20180**, not the
repaired QM5_20181, and it was diffed against the **archived** gated stream, not a
same-vintage standalone. `docs/ops/evidence/2026-07-27_joint_backtest_run_EXECUTED.md:13-27`:

```json
{ "joint_trades": 1255, "gated_trades": 1252, "matched": 1148,
  "unmatched_joint": 107, "unmatched_gated": 104, "match_rate": 0.914741 }
```

`match_rate = 0.914741` against required `1.0` — a 8.53 pp shortfall — and execution
stopped after sleeve 0. Moreover, per the vintage lesson, the reference used
(`9936_USDJPY_DWX.jsonl`) is the 2026-07-14-vintage archived EX5
(`docs/ops/evidence/2026-07-27_evidence_vintage_check.md:19-23`), while the current
build is 2026-07-27
(`.../2026-07-27_evidence_vintage_check.md:35-42`, EX5 SHA-256
`7ea6234d...4bed0929f`). This is precisely the "same-vintage standalone as the true
control" requirement that step 1 was supposed to satisfy and did not. So even the one
completed number is not diff (a); it is joint-vs-stale-archive, and it failed anyway.

## Conclusion

Diff (a) — joint (runner-only) vs same-vintage standalone — has no value: the
runner-only joint stream was never harvested and the same-vintage standalone control
never completed a backtest. It therefore did not reach `match_rate == 1.0`. The gate
condition to proceed is not met.

Stacking the 10145:XAUUSD satellite now would measure isolation and correlation on top
of a scaffold whose base fidelity is unproven — exactly what the gate forbids. The
runner sleeve (9936) must first be shown bit-faithful in the joint EA against a
same-vintage standalone control before a second symbol is added; otherwise any step-2
result cannot be attributed (a satellite perturbation would be indistinguishable from
a pre-existing runner-fidelity gap).

## Actions taken this step (none that touch state)

- Read the step-1 evidence set and confirmed the gate input is absent/incomplete.
- Inspected `D:/QM/reports/joint_20181/` — empty results, only a stray control
  `tester.ini`.
- Did **not** enable sleeve 10145 in QM5_20181.
- Did **not** reserve or run any terminal; no `terminal64.exe` was started; T_Live,
  AutoTrading, Factory OFF/ON, and `.DWX` history were untouched.
- Every step-2 measurement is consequently **NOT ESTABLISHED / NOT RUN**:
  - satellite 10145 match rate vs archived gated 10145_XAUUSD: NOT RUN
  - same-vintage standalone 10145 control: NOT RUN
  - runner-trade invariance (run B vs run D, bit-equal): NOT RUN
  - shared equity path: NOT ESTABLISHED
  - realised daily P&L correlation between sleeves: NOT ESTABLISHED
  - OnTimer thesis on a non-host symbol: NOT ESTABLISHED

## The OnTimer thesis — plain answer

Whether OWNER's OnTimer thesis holds on a genuinely non-host symbol (XAUUSD via the
timer-driven satellite path) is **NOT ESTABLISHED by this step**, and cannot be, until
step 1 proves the runner sleeve is bit-faithful in the joint EA against a same-vintage
standalone control. This is a complete, correct outcome under the protocol: the
scaffold must be proven before a satellite is stacked on it.

## Required next step (for whoever resolves step 1)

Obtain a terminal whose reservation is actually honored at claim time by its persistent
worker (the two documented control attempts both died to immediate reclaim at 19%), run
to completion: (i) the runner-only joint QM5_20181 replay and (ii) a same-vintage
standalone 9936 control, then diff (a) with
`tools/strategy_farm/compare_joint_replay.py`. Only if `match_rate == 1.0` does step 2
become admissible.
