# FACTORY_MUTATION.lock stale-reap and dead-holder alarm

Date: 2026-07-31

Router task: `e7d6ffc6-7462-4e5d-821e-76f6914c6e00`

Reviewer: Claude

Disposition: **READY FOR REVIEW**

## Result

The global factory mutation lock now self-heals on the next ordinary acquire
only when all of the following are true:

1. the complete lock record is readable and structurally valid;
2. its `created_at` is at least 120 seconds old;
3. Windows process inspection proves that the recorded process is dead, or
   that the PID has been reused by a process created after the lock record;
4. a second no-sharing open succeeds, proving that no live exclusive handle is
   still attached; and
5. the complete bytes still match immediately before an identity-bound delete.

The winning reaper appends a durable JSON line to
`D:\QM\reports\state\mutation_lock_reaps.jsonl` before retrying the atomic
create-new acquisition. A live PID, unreadable file, young record, invalid
record, unknown PID state, changed content, lost race, or unwritable audit
journal all remain fail-closed. No admission timeout was shortened and the
behavior of a live holder was not changed.

`farmctl health` now contains `factory_mutation_lock` as a filesystem check:

- a readable dead/reused-PID record aged at least 120 seconds is `FAIL` with an
  action hint pointing to the normal audited reap path;
- a live, unknown, or actively no-sharing record aged at least 10 minutes is
  `WARN`, never an automatic reap; and
- an unreadable record whose age cannot even be inspected warns immediately.

Implementation anchors:

- `tools/strategy_farm/factory_mutation_lock.py:30` — 120-second default;
- `tools/strategy_farm/factory_mutation_lock.py:233` — no-signal PID and
  process-creation-time identity probe;
- `tools/strategy_farm/factory_mutation_lock.py:312` — read-only health
  snapshot;
- `tools/strategy_farm/factory_mutation_lock.py:363` — no-sharing full-content
  CAS deletion; and
- `tools/strategy_farm/factory_mutation_lock.py:464` — guarded reap, audit
  append, and acquire retry.

## Reap evidence schema

Each successful line is `qm.factory-mutation-lock-reap/v1` and binds:

- `reaped_at_utc`, `reaper_pid`, and `reaper_owner`;
- the complete original `lock_record` (`pid`, `owner`, `nonce`, `created_at`);
- lock age and configured stale threshold;
- `pid_state` and the explicit `owner_pid_dead` or `owner_pid_reused` reason;
- the lock path; and
- SHA-256 of the exact bytes compared by the delete CAS.

Two concurrent reapers can read the same candidate, but only one can obtain the
second no-sharing handle. Only that winner marks the exact open file object for
deletion and appends evidence. The loser returns busy/absent/changed without an
audit line.

## PID 15308 forensic reconstruction

Authoritative incident record:

- `D:\QM\reports\state\stale_mutation_lock_reaped_20260731T2033Z.json`
- SHA-256
  `d5f3e57c8e0f8de3cd6d52a3d76244cfde0d3a59a903035010e341b884ada67a`
- lock identity: PID `15308`, owner `terminal_worker.claim_atomic:T5`, nonce
  `1d702200beb54098a932aebffc51482e`, created
  `2026-07-31T19:20:06.214307Z`;
- manual identity-checked reap: `2026-07-31T20:35:27.011922Z`.

The T5 append log provides the process sequence but not per-line timestamps:

- line 1107 starts PID 15308;
- lines 1108–1122 show repeated commit-headroom pauses;
- lines 1123–1126 show two completed claim/run cycles;
- lines 1127–1132 return to commit-headroom pauses;
- there is no `worker_exit` for PID 15308; and
- lines 1133–1134 start successor PIDs 19012 and 2732.

The requested watchdog window does **not** support the brief's proposed
“cohort recycle around 19:30Z” cause. Raw
`D:\QM\reports\state\factory_watchdog.jsonl` entries 394–403 say:

| UTC | Workers | Watchdog action | Destructive action? |
|---|---:|---|---|
| 19:15:05 | 10 | `realstall_guarded` | No — reset explicitly suppressed |
| 19:20:06 | 9 | `noop_factory_off` | No — OWNER OFF, “leaving alone” |
| 19:25:03 | 10 | `realstall_guarded` | No — reset explicitly suppressed |
| 19:30:03 | 10 | `noop_healthy` | No |
| 19:35:03 | 10 | `realstall_guarded` | No — reset explicitly suppressed |

Windows Task Scheduler Operational events independently show only normal
`QM_StrategyFarm_FactoryWatchdog_15min` starts/completions at 19:15, 19:20,
19:25, 19:30, and 19:35 UTC, and no
`QM_StrategyFarm_FactoryON_AtLogon` event in that interval.

There is a later plausible watchdog kill point, but the retained evidence does
not bind it to PID 15308:

- watchdog entry 408 at 19:50:03Z changes to `healed_via_factoryon` for a
  dispatch stall (`active=0`, `pending=2168`, `term64=0`);
- Task Scheduler starts `FactoryON_AtLogon` at 19:50:15Z;
- entry 411 and a second task start repeat the full recovery at 19:55Z; and
- `Factory_ON.ps1` is the clean-slate path that replaces factory workers.

Therefore the defensible finding is: **no watchdog recycle occurred in the
specified 19:15–19:35Z window; if watchdog recovery killed PID 15308, the first
supported opportunity is the later 19:50Z full reset.** The missing per-PID
termination event prevents claiming more.

The selected policy is to leave watchdog reset semantics unchanged and make a
dead owner benign through audited reap. A pre-kill wait is not added because
the only supported reset happened after the lock had already existed for about
30 minutes during a fleet-wide dispatch stall. New workers after that reset
will see an old record and can immediately reap once the PID is proven dead.
The 10-minute live-holder warning separately exposes a still-living hung owner
without ever stealing its lock.

## Verification

Focused regression command:

```text
$healthTests = Get-ChildItem tools/strategy_farm/tests -Filter 'test_health*.py'
python -m pytest -q $healthTests \
  tools/strategy_farm/tests/test_factory_mutation_lock.py \
  tools/strategy_farm/tests/test_q09_news_migration_v2.py

86 passed in 5.17s
```

The focused lock cases prove:

- old dead-owner record -> one audited reap -> successor acquisition;
- actual open no-sharing live holder -> busy/wait path, no reap, no evidence;
- two synchronized reapers -> exactly one delete and one evidence line;
- current process probes live and a terminated subprocess probes dead/reused;
- nonce-bound normal release and replacement-record protection remain intact;
- the shared PowerShell identity protocol still passes; and
- synthetic old orphan -> health `FAIL`; old live owner -> `WARN`; absent lock
  -> `OK`; unknown unreadable age -> fail-closed `WARN`.

Additional verification:

```text
python -m py_compile \
  tools/strategy_farm/factory_mutation_lock.py \
  tools/strategy_farm/health.py \
  tools/strategy_farm/tests/test_factory_mutation_lock.py \
  tools/strategy_farm/tests/test_health_factory_mutation_lock.py
PASS

git diff --check -- <changed paths>
PASS
```

At `2026-07-31T23:21:20.468Z`, a read-only call to the new health check found
an unrelated live-state example: owner `codex_fleet_pacer_spawn`, PID 16236
proved dead, record age 449 seconds, status `FAIL`, threshold 120 seconds. This
was detection evidence only; this task did not manually reap it or cycle the
factory.

Final implementation hashes before commit:

| File | SHA-256 |
|---|---|
| `factory_mutation_lock.py` | `a974406a8b4f37b18ab652192353e13dbdb2abf8e8e8f83fc9f1ff43af0946c5` |
| `health.py` | `c2fe8d1e134c8226b090e9ec5c23386f608a91442aa8f75431c8772fc25dafaa` |
| `test_factory_mutation_lock.py` | `f9e824f075067ade8990435310d879595eafc1647557b6df3a85339420e0d9e9` |
| `test_health_factory_mutation_lock.py` | `6f5ce9ff085c95aeba8e186d2c4da7f0312181c4e2d7e0b84b56acb5c1720a21` |

`ruff` was not installed in the pinned Python environment, so no linter result
is claimed. Syntax compilation, the targeted regression set, and whitespace
validation all passed.

No factory cycle, terminal launch, T_Live/AutoTrading change, manual lock
delete, work-item mutation, or backtest interruption was performed by this
implementation task.
