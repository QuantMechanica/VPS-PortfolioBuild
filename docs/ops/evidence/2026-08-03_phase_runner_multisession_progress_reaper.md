# Phase-runner multi-session progress reaper repair

Date: 2026-08-03  
Router task: `90f6e5e7-cb67-4227-a951-4ec123ae978f`  
Canonical runtime branch: `agents/board-advisor`  
Code commit: `840dcbcd3eddad323092fdebee72e8e701514111`  
Canonical evidence commit: `acb5de147`  
Registered `main` publication commit: `4ab55bec8`  
Verdict: **FIXED; 23 focused tests PASS; both required serial Q07 reruns PASS**

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
