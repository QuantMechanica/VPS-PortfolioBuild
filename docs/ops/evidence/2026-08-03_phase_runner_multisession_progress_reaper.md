# Phase-runner multi-session progress reaper repair

Date: 2026-08-03  
Router task: `90f6e5e7-cb67-4227-a951-4ec123ae978f`  
Canonical runtime branch: `agents/board-advisor`  
Q07 code commit: `840dcbcd3eddad323092fdebee72e8e701514111`
Q08 canonical-progress commit: `874ca33ca950d46c9cff96f5b68f5be0ed975bda`
Q07 canonical evidence commit: `acb5de147`
Q07 registered `main` publication commit: `4ab55bec8`
Verdict: **FIXED; 26 focused tests PASS; serial Q07 reruns PASS; serial Q08
canaries complete without ACTIVE_TIMEOUT**

## Result

The `ACTIVE_TIMEOUT` detector no longer mistakes a healthy multi-session phase
runner for a stalled single tester session. For phases in
`REAL_PHASE_RUNNER_PHASES`, progress now aggregates:

1. work-item-bound MT5 tester-session launch markers;
2. bounded report-root growth (`tester.ini`, `report.htm`, `summary.json`,
   `aggregate.json`, and timestamped run directories); and
3. the existing MT5 `AutoTesting processing N %` evidence.

The change is phase-runner-only. Single-session Q02/Q03 behavior remains on the
existing percentage-based contract. A phase runner with no new launch marker
and no canonical report artifact for at least the 20-minute stall window is
still reaped: its work-item claim is the fail-closed activity baseline.
Arbitrarily growing logs do not count as progress.

## Root cause from the killed row

Victim: `1ccc92e5-0198-49b3-9d2a-fbf063344101`, Q07,
`QM5_11422` / `USDCAD.DWX`, T7.

The exact terminal log read by the pre-fix probe was:

`D:\QM\mt5\T7\logs\20260803.log`

The row payload recorded:

- claimed: `2026-08-03T12:22:05Z`;
- runner started: `2026-08-03T12:22:14Z`;
- reaped: `2026-08-03T12:47:02Z`;
- old evidence: `progress_pct=0`,
  `progress_at=2026-08-03T12:22:14Z`, `stalled_min=24.81`;
- resulting disposition: `failed / INFRA_FAIL / ACTIVE_TIMEOUT`,
  `reap_reason=NO_FORWARD_PROGRESS`.

The log did **not** go silent. It recorded five successive tester sessions for
the same work-item UUID:

| Seed-session directory | Terminal launch (UTC) | Evidence present at reap |
|---|---:|---|
| `20260803_122215` | 12:22:18 | `summary.json` complete |
| `20260803_122718` | 12:27:20 | `summary.json` complete |
| `20260803_123310` | 12:34:17 | `summary.json` complete |
| `20260803_123910` | 12:39:13 | `summary.json` complete |
| `20260803_124403` | 12:44:06 | `tester.ini` created; seed five running |

The report root independently shows four completed summaries through
`12:44:02Z` and the fifth `tester.ini` at `12:44:04Z`:

`D:\QM\reports\work_items\1ccc92e5-0198-49b3-9d2a-fbf063344101`

The pre-fix function found every UUID marker but then selected only
`marker_indexes[-1]` and searched **after** that last marker solely for a
strictly increasing `AutoTesting processing N %` line. It did not treat the
marker timestamp itself or report-root growth as activity. Each short seed
could finish before MT5 emitted its periodic percentage line, and seed five
had run for only about three minutes. With no qualifying percentage after the
last marker, `latest_at` remained the original claim time and produced the
false 24.81-minute stall.

## Historical replay through the repaired detector

The exact victim was replayed read-only at its historical kill timestamp
(`2026-08-03T12:47:02Z`) against its retained T7 log and report root. The new
aggregate returned:

```json
{
  "activity_source": "mt5_session_launch",
  "latest_session_at": "2026-08-03T12:44:06+00:00",
  "progress_at": "2026-08-03T12:44:06+00:00",
  "progress_contract": "phase_runner_multisession_v1",
  "session_marker_count": 10,
  "stalled_min": 2.93,
  "report_progress": {
    "artifact_count": 18,
    "session_dir_count": 5,
    "progress_at": "2026-08-03T12:44:04+00:00",
    "stalled_min": 2.96
  }
}
```

There are ten marker lines because each of the five sessions writes both a
`Startup ... initialized from ... tester.ini` line and a `Terminal launched
with ... tester.ini` line. Both are bound by the unique work-item UUID.

At the same timestamp the row would remain active: `2.93 < 20` minutes.

## Implementation contract

Changed files:

- `tools/strategy_farm/farmctl.py`
- `tools/strategy_farm/tests/test_progress_aware_reaper.py`

The runtime evidence object is additive and self-identifying:

- `progress_contract=phase_runner_multisession_v1`
- `phase_runner_aggregate=true`
- `activity_source=mt5_percentage | mt5_session_launch | report_artifact |
  work_item_claim`
- bound session counts, latest session timestamp/log, and bounded report
  evidence are persisted if a runner is reaped.

Backward compatibility is explicit:

- the existing `progress_at` / `stalled_min` semantics remain unchanged for
  non-phase-runner rows;
- aggregation is invoked only when `phase in REAL_PHASE_RUNNER_PHASES`;
- missing progress remains fail-open inside the inner budget for existing
  single-session phases;
- phase runners fail closed after 20 minutes with no session/report activity;
- the absolute outer ceiling and `INFRA_FAIL / ACTIVE_TIMEOUT` taxonomy are
  unchanged.

## Focused verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_progress_aware_reaper.py \
  tools/strategy_farm/tests/test_basket_work_items.py -q

23 passed in 3.03s
```

The regression cases prove:

- a healthy Q07 runner survives past 20 minutes when a new tester session
  launches;
- a fresh timestamped report directory also counts as activity;
- a Q07 runner with no new session/log/artifact is still reaped;
- Q02 ignores phase-runner report aggregation and retains its prior behavior;
- the existing recent-progress, stalled-progress, missing-signal fail-open,
  and inner/outer-budget tests still pass.

Additional checks:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_progress_aware_reaper.py
# PASS

git diff --check -- tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_progress_aware_reaper.py
# PASS (only the checkout's existing LF-to-CRLF warning)
```

Committed source identities:

- farmctl Git blob: `47d33ddee593c40767089c3c9908fe0c582e3ecd`
- farmctl SHA-256:
  `d275b79d1395688f72a825f4ec7997d63d4f6c4e2a5e3ba197d38900f7ea73b7`

## Required append-only Q07 reruns (serial)

The two reruns were created through `farmctl enqueue-backtest`, pinned to the
current EX5 SHA-256, and run one at a time. Historical failed rows were not
rewritten.

| Order | EA / symbol | Fresh Q06 PASS predecessor | Append-only rerun of | New Q07 row | Terminal interval | Verdict | Pipeline evidence |
|---:|---|---|---|---|---|---|---|
| 1 | `QM5_11422` / `USDCAD.DWX` | `6262e5b1-274e-4b55-aad5-9081d3c8f7b1` | `1ccc92e5-0198-49b3-9d2a-fbf063344101` | `474ba0d0-00c1-4672-a14d-a465d635405f` | active 13:17:15Z; done 13:41:15Z | **PASS** — `variance_pct=7.11<20.0:min_pf=1.210` | `D:\QM\reports\work_items\474ba0d0-00c1-4672-a14d-a465d635405f\QM5_11422\Q07\USDCAD_DWX\aggregate.json` |
| 2 | `QM5_13036` / `GDAXI.DWX` | `3c6c43cd-151a-4e91-9cc8-a5e893867e12` | `47db3c85-467e-493d-8779-cf1e4e81979a` | `0b27a3bc-b1a0-4335-bf1f-39727472d467` | active 13:41:55Z; done 14:02:24Z | **PASS** — `variance_pct=2.91<20.0:min_pf=1.020` | `D:\QM\reports\work_items\0b27a3bc-b1a0-4335-bf1f-39727472d467\QM5_13036\Q07\GDAXI_DWX\aggregate.json` |

Artifact SHA-256:

- 11422 aggregate:
  `968ff9af5aba390df63be72cacc11b39c228e00cfe22c05111da706362037df7`
- 13036 aggregate:
  `e86244790db6b60fdf49c828fdff7134459202444eaeacb24d2a33f946cc7ae4`

Seriality is row-bound: the second row was created at `13:41:37Z`, after the
first row reached `done/PASS` at `13:41:15Z`. No second target row existed while
the first was active.

The set/risk contract remained `RISK_FIXED=1000.0`, `RISK_PERCENT=0.0` in both
work-item payloads. No `T_Live` path, AutoTrading setting, terminal process, or
active non-target test was modified or interrupted.

## Runtime-decision-bound flag and activation behavior

`farmctl.py` is one of the 12 `SOURCE_BINDING_PATHS` in
`factory_runtime_activation.py`. The currently signed activation decision is
bound to the predecessor farmctl identity:

- commit `30a70203460543d7ca8fb35077560759aee40f91`
- Git blob `d6bcd5e86bd213b1f7a90e5217e6d31aac9a1daa`
- SHA-256 `739dd0afe996f2ad7cff14d4f11dd03d7ad013f05f2ab6294995f1c1bd4e97f3`

This repair changes that bound source. **A fresh OWNER runtime-decision rebind
is mandatory before the next Factory_ON/restart-hold release.** This cycle did
not run Factory_OFF/Factory_ON, restart a worker, toggle AutoTrading, or touch
`T_Live`.

The active-timeout detector itself runs in the scheduled pump, not in the
long-lived terminal worker. The installed task invokes:

`C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe
"C:\QM\repo\tools\strategy_farm\run_pump_task.py"`

`run_pump_task.py` starts a fresh subprocess for
`C:\QM\repo\tools\strategy_farm\farmctl.py pump` on each invocation. The
repair therefore took effect on the next pump invocation without a worker
reload. Post-commit pump logs `pump_task_20260803T132659Z.log`,
`pump_task_20260803T133619Z.log`, and `pump_task_20260803T135423Z.log` all
record `active_timeouts: []` while the governed target sequences were active.

Pipeline verdicts above come only from the two Q07 aggregate artifacts and the
corresponding terminal work-item rows.

## Recycled-task Q08 closure

The router recycled this task after accepting the Q07 repair because Q08's
support runners publish required progress outside the work-item report root.
In particular, Q08.5 creates canonical tester sessions, bounded neighborhood
setfiles, `perturbations.json`, and PBO inputs below
`D:\QM\reports\pipeline\<EA>\Q08\...`. A healthy Q08 row could therefore still
appear idle after its row-root baseline evidence stopped changing.

Commit `874ca33ca950d46c9cff96f5b68f5be0ed975bda` extends the same
`phase_runner_multisession_v1` contract to those canonical Q08 artifacts. The
probe is deliberately bounded to:

- the normalized EA's canonical pipeline root;
- Q08 baseline tester sessions whose `tester.ini` binds the target EA, symbol,
  and governed setfile;
- the target symbol's Q08 neighborhood setfiles and `perturbations.json`; and
- the target symbol's Q08 PBO score artifacts.

Matching canonical `tester.ini` paths are also supplied as terminal-log binding
markers, so their subsequent MT5 percentage lines count for the correct row.
Generic log growth and unrelated pipeline files remain ineligible.

### Q08-focused verification

```text
python -m pytest tools/strategy_farm/tests/test_progress_aware_reaper.py -q
11 passed

python -m pytest \
  tools/strategy_farm/tests/test_progress_aware_reaper.py \
  tools/strategy_farm/tests/test_basket_work_items.py -q
26 passed in 2.82s

python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_progress_aware_reaper.py
PASS

git diff --check 840dcbcd3eddad323092fdebee72e8e701514111 \
  874ca33ca950d46c9cff96f5b68f5be0ed975bda -- \
  tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_progress_aware_reaper.py
PASS
```

The new regressions prove that a canonical Q08 neighborhood artifact is
accepted, a canonical Q08 tester session binds its later percentage progress,
and a hung Q08 row with no eligible canonical artifact is still reaped with
`NO_FORWARD_PROGRESS`.

Q08 source identities:

- farmctl Git blob: `6e2c6cf81b091164ec826cd170c8b6f6fe14f72d`
- farmctl SHA-256:
  `4878c393944affa93ba8b3d04ea95d028b382f29895e1545765badc0112697b9`

### Required serial Q08 canaries

Both canaries were governed Q08 work items. The second was enqueued only after
the first had reached a terminal state; neither historical failure row was
rewritten.

| Order | EA / symbol | Required lineage | New Q08 row | Terminal interval | Pipeline verdict | Pipeline evidence |
|---:|---|---|---|---|---|---|
| 1 | `QM5_10582` / `XAUUSD.DWX` | recovery from `e196d30b-e4d4-40b6-961a-4e5391eae918`; lineage source `95015420-11d0-4c11-bb98-25fa2a361048` | `4b890848-fa36-4f5a-8a39-14dfb30ba065` | active 17:42:28Z; done 21:41:19Z | **INFRA_FAIL** | `D:\QM\reports\work_items\4b890848-fa36-4f5a-8a39-14dfb30ba065\QM5_10582\Q08\XAUUSD_DWX\aggregate.json` |
| 2 | `QM5_10145` / `XAUUSD.DWX` | Q07 PASS `096bfd3b-9f67-4d86-bf91-197bf983f64d`; append-only rerun of `d4895758-2910-4cdf-ba6a-f944088e7633` | `eace82bf-c01d-4d14-b0ed-e2bf1f669f21` | active 22:04:51Z; done 23:15:22Z | **PASS** | `D:\QM\reports\work_items\eace82bf-c01d-4d14-b0ed-e2bf1f669f21\QM5_10145\Q08\XAUUSD_DWX\aggregate.json` |

Artifact SHA-256:

- 10582 aggregate:
  `ec2d83a32c82e929bb08bc7d079f1b9c6bfe6ff51bbcaa0f6fe958372564530f`
- 10145 aggregate:
  `b88bca8fb94d506ddebe1151e8fb6b775fe75a7bdce914142b7a0d502bbbb0ac`

The first verdict is pipeline-derived and is not an `ACTIVE_TIMEOUT`. Its
aggregate records 5 PASS, 4 FAIL, and 2 INVALID subgates. In particular, Q08.5
is INVALID with
`neighborhood_evidence_lineage_invalid:evidence_status_missing_or_invalid`,
and Q08.7 is INVALID with
`insufficient_distinct_configs:got=0:need>=2`. This task did not reinterpret or
repair those separate pipeline findings.

The second row was created at `21:42:47Z`, after the first completed at
`21:41:19Z`. An unrelated active XAUUSD work item legitimately held the symbol
lock until `22:04:41Z`; it was not interrupted or bypassed. The Q08 canary was
then claimed on T5 at `22:04:51Z`. Production observations included:

- baseline progress at 31% (`22:10:00Z`) and 81% (`22:15:00Z`);
- canonical Q08 neighborhood setfile creation at `22:17:05Z`;
- neighborhood session launches at `22:17:08Z`, `22:28:32Z`, `22:40:19Z`,
  `22:52:19Z`, and `23:03:38Z`; and
- bound neighborhood percentage progress at 32% (`22:22:13Z`) and 88%
  (`22:27:13Z`).

The row remained active for more than 70 minutes, crossed all six tester
sessions with 12 bound launch markers, and reached `done/PASS` without an
`ACTIVE_TIMEOUT`. Its aggregate was generated at `23:15:11Z` and records 9
PASS, 2 FAIL, and 0 INVALID raw subgate statuses. The aggregate's governed
classification maps Q08.4 and Q08.6 to `EDGE_SOFT`; all four Q08.5
perturbations pass the plateau check and Q08.7 passes with PBO 28.571% across
35 splits. The `PASS` reported here is the artifact and work-item verdict, not
an orchestration reinterpretation.

Both dispatches were pinned to their current EX5 SHA-256 values. The 10145
append-only row used EX5
`c3f5476eff34ce65b25acf8bd967b5d0b349ce8e05bd492f82316f899a38db86`
and governed setfile
`3623ea13d65d96dc2676405080beb783958edc006041a1f7cfa023c81714ae52`.
The target setfiles retained `RISK_FIXED=1000` and `RISK_PERCENT=0`. No
`T_Live` path or AutoTrading setting was changed, no terminal was started
manually, and no active backtest was interrupted.

### Runtime activation binding after Q08 repair

Read-only runtime-decision validation correctly failed closed because the
signed activation decision still expects farmctl SHA-256
`739dd0afe996f2ad7cff14d4f11dd03d7ad013f05f2ab6294995f1c1bd4e97f3`,
while the Q08 repair's runtime source is
`4878c393944affa93ba8b3d04ea95d028b382f29895e1545765badc0112697b9`.
A fresh OWNER runtime-decision rebind remains mandatory before any future
Factory_ON or restart-hold release. This cycle did not perform either action.

The active-timeout detector is evaluated by a fresh scheduled pump process, so
the committed repair became effective on the next pump tick without reloading
a worker. Production pump records repeatedly reported `active_timeouts: []`
while both Q08 canaries advanced across their canonical tester sessions.

The Q08 verdicts above come only from the terminal work-item rows and their
aggregate artifacts.
